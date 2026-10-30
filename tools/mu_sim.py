#!/usr/bin/env python3
"""MUTerm serial device simulator.

The simulator speaks Modbus RTU (function codes 3, 4, 6 and 16) on a real
serial device or on a pseudo-terminal it creates itself.  It can drive the
RTS/DTR outputs, report CTS/DSR/CD/RI transitions and emulate transmission
timing derived from the configured baud rate.

Examples
--------
Create a PTY pair and print the path to open in MUTerm:

    ./tools/mu_sim.py --pty --pty-link /tmp/muterm-pty --baud 9600

Use one side of a tty0tty null-modem pair:

    ./tools/mu_sim.py /dev/tnt1 --baud 9600 --regs 1=1234,2=5678

Use a real serial port and drive the handshake lines:

    ./tools/mu_sim.py /dev/ttyUSB0 --baud 19200 --rts on --dtr on \
        --poll-lines 0.5 --emulate-timing

The default register map answers the example script shipped with MUTerm:
``:COMM_SETUP(,9600,8,None,1)``, ``:SEND_HEX(01 03 00 01 00 02 95 CB)``
and ``:WAIT_COMM 1.0``.
"""

from __future__ import annotations

import argparse
import errno
import fcntl
import logging
import os
import pty
import select
import signal
import struct
import sys
import termios
import time
from typing import Dict, Iterable, List, Optional, Tuple

LOG = logging.getLogger("mu_sim")

# Linux modem-control ioctls and bits (termios may not export all of them).
TIOCMGET = getattr(termios, "TIOCMGET", 0x5415)
TIOCMBIS = getattr(termios, "TIOCMBIS", 0x5416)
TIOCMBIC = getattr(termios, "TIOCMBIC", 0x5417)
TIOCM_LE = 0x0001
TIOCM_DTR = 0x0002
TIOCM_RTS = 0x0004
TIOCM_CTS = 0x0020
TIOCM_CD = 0x0040
TIOCM_DSR = 0x0100
TIOCM_RI = 0x0400

# TIOCM_CD is TIOCM_CAR on some headers; the bit value is the same.
LINE_BITS = {
    "CTS": TIOCM_CTS,
    "DSR": TIOCM_DSR,
    "CD": TIOCM_CD,
    "RI": TIOCM_RI,
}

OUTPUT_BITS = {
    "RTS": TIOCM_RTS,
    "DTR": TIOCM_DTR,
}

# Modbus exception codes.
ILLEGAL_FUNCTION = 0x01
ILLEGAL_DATA_ADDRESS = 0x02
ILLEGAL_DATA_VALUE = 0x03


def format_hex(data: bytes) -> str:
    return " ".join(f"{byte:02X}" for byte in data)


def crc16(data: bytes) -> bytes:
    """Return the Modbus RTU CRC16 (low byte first)."""
    value = 0xFFFF
    for byte in data:
        value ^= byte
        for _ in range(8):
            if value & 0x0001:
                value = (value >> 1) ^ 0xA001
            else:
                value >>= 1
    return struct.pack("<H", value)


def with_crc(payload: bytes) -> bytes:
    return payload + crc16(payload)


class RegisterFile:
    """Sparse 16-bit register map; unset addresses read as zero."""

    def __init__(self, values: Optional[Dict[int, int]] = None) -> None:
        self._values: Dict[int, int] = dict(values or {})

    def read(self, address: int, quantity: int) -> List[int]:
        return [self._values.get(address + offset, 0) for offset in range(quantity)]

    def write(self, address: int, values: Iterable[int]) -> None:
        for offset, value in enumerate(values):
            self._values[address + offset] = value & 0xFFFF


class ModbusDevice:
    """Minimal Modbus RTU slave."""

    def __init__(self, unit: int, holding: RegisterFile, inputs: RegisterFile) -> None:
        self.unit = unit
        self.holding = holding
        self.inputs = inputs

    def handle_adu(self, frame: bytes) -> Optional[bytes]:
        """Handle one complete request.  Returns a response ADU or ``None``."""
        unit = frame[0]
        pdu = frame[1:-2]

        if unit != self.unit and unit != 0:
            LOG.debug("ignored request for unit %d", unit)
            return None

        function = pdu[0]
        try:
            response_pdu = self._dispatch(function, pdu)
        except ModbusException as exc:
            LOG.info(
                "unit %d function %d -> exception %d (%s)",
                unit,
                function,
                exc.code,
                exc.message,
            )
            response_pdu = bytes([function | 0x80, exc.code])
        except (IndexError, struct.error):
            LOG.warning("malformed request: %s", format_hex(frame))
            response_pdu = bytes([function | 0x80, ILLEGAL_DATA_VALUE])

        if unit == 0:
            LOG.info("broadcast function %d applied", function)
            return None

        return with_crc(bytes([unit]) + response_pdu)

    def _dispatch(self, function: int, pdu: bytes) -> bytes:
        if function in (3, 4):
            return self._read_registers(function, pdu)
        if function == 6:
            return self._write_single_register(pdu)
        if function == 16:
            return self._write_multiple_registers(pdu)
        raise ModbusException(ILLEGAL_FUNCTION, "unsupported function")

    def _read_registers(self, function: int, pdu: bytes) -> bytes:
        address, quantity = struct.unpack(">HH", pdu[1:5])
        if not 1 <= quantity <= 125:
            raise ModbusException(ILLEGAL_DATA_VALUE, "quantity out of range")
        if address + quantity > 0x10000:
            raise ModbusException(ILLEGAL_DATA_ADDRESS, "address out of range")

        registers = self.holding if function == 3 else self.inputs
        values = registers.read(address, quantity)
        payload = b"".join(struct.pack(">H", value) for value in values)
        LOG.info(
            "FC%d read %d register(s) at %d -> [%s]",
            function,
            quantity,
            address,
            ", ".join(str(value) for value in values),
        )
        return bytes([function, len(payload)]) + payload

    def _write_single_register(self, pdu: bytes) -> bytes:
        address, value = struct.unpack(">HH", pdu[1:5])
        self.holding.write(address, [value])
        LOG.info("FC6 write register %d = %d", address, value)
        return pdu[:5]

    def _write_multiple_registers(self, pdu: bytes) -> bytes:
        address, quantity, byte_count = struct.unpack(">HHB", pdu[1:6])
        if not 1 <= quantity <= 123:
            raise ModbusException(ILLEGAL_DATA_VALUE, "quantity out of range")
        if byte_count != quantity * 2 or len(pdu) < 6 + byte_count:
            raise ModbusException(ILLEGAL_DATA_VALUE, "byte count mismatch")

        raw = pdu[6 : 6 + byte_count]
        values = list(struct.unpack(f">{quantity}H", raw))
        self.holding.write(address, values)
        LOG.info(
            "FC16 write %d register(s) at %d -> [%s]",
            quantity,
            address,
            ", ".join(str(value) for value in values),
        )
        return pdu[:5]


class ModbusException(Exception):
    def __init__(self, code: int, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


class ModemLines:
    """Best-effort modem-line access; PTYs do not support the ioctls."""

    def __init__(self, fd: int, supported: bool = True) -> None:
        self.fd = fd
        self.supported = supported
        self._warned: set[str] = set()
        self._last_state: Optional[Dict[str, bool]] = None

    def _warn_once(self, key: str, message: str) -> None:
        if key not in self._warned:
            self._warned.add(key)
            LOG.warning(message)

    def _read_bits(self) -> Optional[int]:
        if not self.supported:
            return None
        try:
            return struct.unpack("i", fcntl.ioctl(self.fd, TIOCMGET, b"\0" * 4))[0]
        except OSError as exc:
            self._warn_once(
                "TIOCMGET",
                f"line status is not supported by this device ({exc.strerror})",
            )
            self.supported = False
            return None

    def set_output(self, name: str, enabled: bool) -> bool:
        if not self.supported:
            return False
        bit = OUTPUT_BITS[name]
        request = TIOCMBIS if enabled else TIOCMBIC
        try:
            fcntl.ioctl(self.fd, request, struct.pack("i", bit))
        except OSError as exc:
            self._warn_once(
                name,
                f"{name} control is not supported by this device ({exc.strerror}); "
                "use tty0tty or a real UART for handshake lines",
            )
            return False
        LOG.info("%s -> %s", name, "on" if enabled else "off")
        return True

    def read_output(self, name: str) -> Optional[bool]:
        bits = self._read_bits()
        if bits is None:
            return None
        return bool(bits & OUTPUT_BITS[name])

    def read_state(self) -> Optional[Dict[str, bool]]:
        bits = self._read_bits()
        if bits is None:
            return None
        return {name: bool(bits & bit) for name, bit in LINE_BITS.items()}

    def poll(self, force: bool = False) -> None:
        state = self.read_state()
        if state is None or (state == self._last_state and not force):
            return
        self._last_state = state
        LOG.info(
            "lines %s",
            " ".join(f"{name}={'on' if value else 'off'}" for name, value in state.items()),
        )


def baud_constant(baud: int) -> int:
    name = f"B{baud}"
    value = getattr(termios, name, None)
    if value is None:
        raise ValueError(f"unsupported baud rate: {baud}")
    return value


def configure_port(fd: int, args: argparse.Namespace) -> None:
    """Put the device into raw mode with the requested framing."""
    iflag, oflag, cflag, lflag, _ispeed, _ospeed, cc = termios.tcgetattr(fd)

    iflag &= ~(
        termios.IGNBRK
        | termios.BRKINT
        | termios.PARMRK
        | termios.ISTRIP
        | termios.INLCR
        | termios.IGNCR
        | termios.ICRNL
        | termios.IXON
        | termios.IXOFF
        | termios.IXANY
    )
    oflag &= ~termios.OPOST
    lflag &= ~(
        termios.ECHO
        | termios.ECHONL
        | termios.ICANON
        | termios.ISIG
        | termios.IEXTEN
    )
    cflag &= ~(
        termios.CSIZE
        | termios.PARENB
        | termios.PARODD
        | termios.CSTOPB
        | termios.CRTSCTS
    )

    cflag |= {
        5: termios.CS5,
        6: termios.CS6,
        7: termios.CS7,
        8: termios.CS8,
    }[args.databits]

    if args.parity == "even":
        cflag |= termios.PARENB
    elif args.parity == "odd":
        cflag |= termios.PARENB | termios.PARODD

    if args.stopbits == 2:
        cflag |= termios.CSTOPB

    speed = baud_constant(args.baud)
    cc[termios.VMIN] = 0
    cc[termios.VTIME] = 0
    termios.tcsetattr(
        fd,
        termios.TCSANOW,
        [iflag, oflag, cflag, lflag, speed, speed, cc],
    )


def char_bits(args: argparse.Namespace) -> float:
    """Number of bits on the wire per character, including start/stop."""
    bits = 1 + args.databits + args.stopbits
    if args.parity != "none":
        bits += 1
    return float(bits)


def expected_frame_length(buffer: bytes) -> Optional[int]:
    """Return the full ADU length for the frame at the head of ``buffer``."""
    if len(buffer) < 2:
        return None
    function = buffer[1]
    if function in (1, 2, 3, 4, 5, 6, 8):
        return 8
    if function in (15, 16):
        if len(buffer) < 7:
            return None
        return 9 + buffer[6]
    # Unknown function: assume the shortest request so it can be rejected.
    return 8


def write_all(fd: int, data: bytes) -> None:
    view = memoryview(data)
    while view:
        try:
            written = os.write(fd, view)
        except BlockingIOError:
            select.select([], [fd], [], 0.5)
            continue
        except OSError as exc:
            if exc.errno in (errno.EAGAIN, errno.EIO):
                time.sleep(0.05)
                continue
            raise
        view = view[written:]


def parse_register_map(text: str) -> Dict[int, int]:
    values: Dict[int, int] = {}
    if not text:
        return values
    for item in text.split(","):
        item = item.strip()
        if not item:
            continue
        try:
            address_text, value_text = item.split("=", 1)
            address = int(address_text.strip(), 0)
            value = int(value_text.strip(), 0)
        except ValueError as exc:
            raise argparse.ArgumentTypeError(
                f"invalid register map entry {item!r}; expected ADDRESS=VALUE"
            ) from exc
        if not 0 <= address <= 0xFFFF or not 0 <= value <= 0xFFFF:
            raise argparse.ArgumentTypeError(
                f"register entry {item!r} is outside 0..65535"
            )
        values[address] = value
    return values


def parse_line_level(text: str) -> Optional[bool]:
    normalized = text.strip().lower()
    if normalized in ("on", "1", "true", "high"):
        return True
    if normalized in ("off", "0", "false", "low"):
        return False
    return None


class Simulator:
    def __init__(self, args: argparse.Namespace) -> None:
        self.args = args
        self.running = True
        self.fd: Optional[int] = None
        self.lines: Optional[ModemLines] = None
        self.extra_fds: List[int] = []
        self.pty_path: Optional[str] = None
        self.pty_link: Optional[str] = None
        self.initial_attrs: Optional[List] = None
        self.initial_outputs: Dict[str, bool] = {}
        self.device = ModbusDevice(
            unit=args.unit,
            holding=RegisterFile(parse_register_map(args.regs)),
            inputs=RegisterFile(parse_register_map(args.input_regs)),
        )
        self.buffer = bytearray()
        self.last_rx = 0.0
        self.bytes_in = 0
        self.bytes_out = 0
        self.requests = 0
        self.responses = 0

    # -- setup / teardown -------------------------------------------------
    def open(self) -> None:
        configure_fd: int
        if self.args.pty:
            master, slave = pty.openpty()
            self.pty_path = os.ttyname(slave)
            self.fd = master
            self.extra_fds.append(slave)
            os.set_blocking(master, False)
            os.set_blocking(slave, False)
            configure_fd = slave

            if self.args.pty_link:
                self.pty_link = os.path.abspath(self.args.pty_link)
                try:
                    os.unlink(self.pty_link)
                except FileNotFoundError:
                    pass
                os.symlink(self.pty_path, self.pty_link)

            LOG.info("PTY ready: %s", self.pty_path)
            if self.pty_link:
                LOG.info("PTY link : %s", self.pty_link)
            LOG.info("Open this device in MUTerm now.")
        else:
            self.fd = os.open(self.args.port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
            configure_fd = self.fd
            LOG.info("opened %s", self.args.port)

        assert self.fd is not None
        try:
            self.initial_attrs = termios.tcgetattr(configure_fd)
        except termios.error:
            self.initial_attrs = None
        configure_port(configure_fd, self.args)

        if self.args.pty:
            LOG.debug("modem control lines are not available on a PTY")
        self.lines = ModemLines(self.fd, supported=not self.args.pty)
        self._apply_output("RTS", self.args.rts)
        self._apply_output("DTR", self.args.dtr)
        self.lines.poll(force=True)

    def _apply_output(self, name: str, requested: str) -> None:
        if requested == "keep" or self.lines is None:
            return
        previous = self.lines.read_output(name)
        if previous is not None:
            self.initial_outputs[name] = previous
        self.lines.set_output(name, requested == "on")

    def close(self) -> None:
        if self.lines is not None:
            for name, original in self.initial_outputs.items():
                self.lines.set_output(name, original)
        for fd in self.extra_fds:
            try:
                os.close(fd)
            except OSError:
                pass
        if self.fd is not None:
            if self.initial_attrs is not None and not self.args.pty:
                try:
                    termios.tcsetattr(self.fd, termios.TCSANOW, self.initial_attrs)
                except termios.error:
                    pass
            try:
                os.close(self.fd)
            except OSError:
                pass
        if self.pty_link:
            try:
                os.unlink(self.pty_link)
            except FileNotFoundError:
                pass
        LOG.info(
            "stopped: %d request(s), %d response(s), %d byte(s) in, %d byte(s) out",
            self.requests,
            self.responses,
            self.bytes_in,
            self.bytes_out,
        )

    # -- main loop --------------------------------------------------------
    def stop(self, _signum: int, _frame: object) -> None:
        self.running = False

    def run(self) -> int:
        assert self.fd is not None
        poll_interval = self.args.poll_lines
        next_poll = time.monotonic() + poll_interval if poll_interval > 0 else None

        while self.running:
            try:
                readable, _, _ = select.select([self.fd], [], [], 0.1)
            except InterruptedError:
                continue

            if readable:
                self._read_available()

            now = time.monotonic()
            if self.buffer and now - self.last_rx > self.args.frame_timeout:
                LOG.warning(
                    "discarding incomplete frame after %.2fs: %s",
                    self.args.frame_timeout,
                    format_hex(bytes(self.buffer)),
                )
                self.buffer.clear()

            if next_poll is not None and now >= next_poll:
                self.lines.poll()
                next_poll = now + poll_interval

        return 0

    def _read_available(self) -> None:
        assert self.fd is not None
        try:
            chunk = os.read(self.fd, 4096)
        except BlockingIOError:
            return
        except OSError as exc:
            if exc.errno in (errno.EIO, errno.EAGAIN):
                # No peer is reading/writing the other side of a PTY.
                time.sleep(0.05)
                return
            raise

        if not chunk:
            time.sleep(0.05)
            return

        self.bytes_in += len(chunk)
        if self.args.hex:
            LOG.info("RX %s", format_hex(chunk))
        self.buffer.extend(chunk)
        self.last_rx = time.monotonic()
        self._process_buffer()

    def _process_buffer(self) -> None:
        while True:
            length = expected_frame_length(self.buffer)
            if length is None or len(self.buffer) < length:
                return

            frame = bytes(self.buffer[:length])
            if crc16(frame[:-2]) != frame[-2:]:
                LOG.warning("bad CRC, resynchronising: %s", format_hex(frame))
                del self.buffer[0]
                continue

            del self.buffer[:length]
            self.requests += 1
            if self.args.hex:
                LOG.info("RX frame %s", format_hex(frame))

            response = self.device.handle_adu(frame)
            if response is not None:
                self._transmit(response)

            # A garbled stream can otherwise grow without bound.
            if len(self.buffer) > 4096:
                LOG.warning("receive buffer overflow, dropping data")
                self.buffer.clear()
                return

    def _transmit(self, response: bytes) -> None:
        assert self.fd is not None
        wire_time = len(response) * char_bits(self.args) / self.args.baud
        delay = self.args.response_delay / 1000.0
        if self.args.emulate_timing:
            delay += wire_time

        if delay > 0:
            time.sleep(delay)

        write_all(self.fd, response)
        self.bytes_out += len(response)
        self.responses += 1
        if self.args.hex:
            LOG.info("TX frame %s", format_hex(response))
        else:
            LOG.info("TX %s", format_hex(response))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="MUTerm serial device simulator (Modbus RTU + modem lines).",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "port",
        nargs="?",
        help="serial device to use (e.g. /dev/tnt1); omit with --pty",
    )
    parser.add_argument(
        "--pty",
        action="store_true",
        help="create a pseudo-terminal instead of opening a serial device",
    )
    parser.add_argument(
        "--pty-link",
        metavar="PATH",
        help="create a symlink to the PTY slave (implies --pty)",
    )
    parser.add_argument("--baud", type=int, default=9600, help="line speed")
    parser.add_argument(
        "--databits", type=int, choices=(5, 6, 7, 8), default=8, help="data bits"
    )
    parser.add_argument(
        "--parity",
        choices=("none", "even", "odd"),
        default="none",
        help="parity mode",
    )
    parser.add_argument(
        "--stopbits", type=int, choices=(1, 2), default=1, help="stop bits"
    )
    parser.add_argument(
        "--unit", type=int, default=1, help="Modbus slave address"
    )
    parser.add_argument(
        "--regs",
        default="1=1234,2=5678,3=42,4=100",
        help="holding register map, e.g. 1=1234,2=5678",
    )
    parser.add_argument(
        "--input-regs",
        default="",
        help="input register map (defaults to zero for every address)",
    )
    parser.add_argument(
        "--response-delay",
        type=float,
        default=0.0,
        metavar="MS",
        help="extra delay before every response in milliseconds",
    )
    parser.add_argument(
        "--emulate-timing",
        action="store_true",
        help="delay responses by the time the frame needs on the wire",
    )
    parser.add_argument(
        "--frame-timeout",
        type=float,
        default=0.25,
        metavar="SECONDS",
        help="drop incomplete frames after this much idle time",
    )
    parser.add_argument(
        "--rts",
        choices=("on", "off", "keep"),
        default="on",
        help="RTS level on startup",
    )
    parser.add_argument(
        "--dtr",
        choices=("on", "off", "keep"),
        default="on",
        help="DTR level on startup",
    )
    parser.add_argument(
        "--poll-lines",
        type=float,
        default=0.5,
        metavar="SECONDS",
        help="poll CTS/DSR/CD/RI this often (0 disables)",
    )
    parser.add_argument(
        "--hex", action="store_true", help="log every raw RX/TX frame"
    )
    parser.add_argument(
        "--debug", action="store_true", help="enable debug logging"
    )
    return parser


def main(argv: Optional[List[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.pty_link:
        args.pty = True
    if args.pty and args.port:
        parser.error("--pty cannot be combined with a port")
    if not args.pty and not args.port:
        parser.error("either a port or --pty is required")
    if args.baud <= 0:
        parser.error("--baud must be positive")
    if args.frame_timeout <= 0:
        parser.error("--frame-timeout must be positive")
    if not 0 <= args.unit <= 247:
        parser.error("--unit must be in 0..247")
    if args.poll_lines < 0:
        parser.error("--poll-lines cannot be negative")

    logging.basicConfig(
        level=logging.DEBUG if args.debug else logging.INFO,
        format="%(asctime)s %(levelname)-7s %(message)s",
        datefmt="%H:%M:%S",
    )

    simulator = Simulator(args)
    signal.signal(signal.SIGINT, simulator.stop)
    signal.signal(signal.SIGTERM, simulator.stop)

    try:
        simulator.open()
    except (OSError, ValueError, termios.error) as exc:
        LOG.error("cannot open %s: %s", args.port or "PTY", exc)
        simulator.close()
        return 1

    try:
        return simulator.run()
    finally:
        simulator.close()


if __name__ == "__main__":
    sys.exit(main())
