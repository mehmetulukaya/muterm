#!/usr/bin/env python3
"""MUTerm counter device simulator.

A small line-oriented ASCII device for exercising the MUTerm ``:COMMAND(...)``
script language: variables, labels, ``:IF`` blocks, ``:COM_RECV_TEXT`` and the
``TIMEOUT`` variable.  It creates a pseudo-terminal (or opens a real serial
port) and answers a few simple text commands.

Protocol
--------
Requests are split on CR and/or LF.  Matching is case-insensitive.

``/?!``, ``?``, ``PING``
    Handshake.  Replies ``/OK`` followed by the configured end-of-line.
``GET``, ``GET?``, ``COUNT?``, ``READ``
    Replies with the current count, without changing it.
``RESET``, ``CLR``, ``CLEAR``
    Sets the count to zero.
``SET <number>``
    Sets the count to the given number (decimal or ``0x`` hex).
``INC``, ``+``, ``NEXT``
    Adds ``--step`` to the count.
Anything else
    Counts as a pulse: adds ``--step`` and replies with the new count.

The default reply format is ``COUNT=<n>!``; the trailing ``!`` makes it easy to
test ``:COM_WAIT_FOR_TEXT(!)``.  The handshake reply deliberately does not
contain ``!`` so it cannot satisfy such a wait by accident.

Examples
--------
Create a PTY pair and print the path to open in MUTerm:

    ./tools/mu_counter.py --pty --pty-link /tmp/muterm-counter

Then run a script such as:

    :COMM_SETUP(,9600,8,None,1)
    :COMM_OPEN_CLOSE
    :COM_CLEAR_RCV_BUF
    :SEND_TEXT(/?!#013#010)
    :COM_RECV_TEXT(reply,1.0)
    :SEND_TEXT(INC#013#010)
    :COM_RECV_TEXT(value,1.0)
    :SEND_TEXT([{value}]#013#010)
    :END

Enable ``--interval 1.0`` to make the simulator emit a new count every second.
"""

from __future__ import annotations

import argparse
import errno
import logging
import os
import pty
import select
import signal
import sys
import termios
import time
from typing import List, Optional

# Reuse the serial-port helpers from the Modbus simulator.
from mu_sim import configure_port, format_hex, write_all

LOG = logging.getLogger("mu_counter")

EOL_CHOICES = {
    "crlf": b"\r\n",
    "lf": b"\n",
    "cr": b"\r",
}

HANDSHAKE_COMMANDS = {"/?!", "?", "PING"}
READ_COMMANDS = {"GET", "GET?", "COUNT?", "READ", "READ?"}
RESET_COMMANDS = {"RESET", "CLR", "CLEAR"}
INC_COMMANDS = {"INC", "+", "NEXT"}


class CounterDevice:
    """Tiny counter with a text command protocol."""

    def __init__(
        self,
        start: int = 0,
        step: int = 1,
        reply_format: str = "COUNT={count}!",
        eol: bytes = b"\r\n",
    ) -> None:
        self.count = start
        self.step = step
        self.reply_format = reply_format
        self.eol = eol

    def reply(self) -> bytes:
        text = self.reply_format.format(count=self.count)
        return text.encode("latin-1", "replace") + self.eol

    def handle(self, raw: bytes) -> Optional[bytes]:
        text = raw.decode("latin-1", "replace").strip()
        command = text.upper()

        if not command:
            return None
        if command in HANDSHAKE_COMMANDS:
            return b"/OK" + self.eol
        if command in READ_COMMANDS:
            return self.reply()
        if command in RESET_COMMANDS:
            self.count = 0
            return self.reply()
        if command in INC_COMMANDS:
            self.count += self.step
            return self.reply()

        parts = command.split(None, 1)
        if parts[0] == "SET":
            if len(parts) < 2:
                return b"ERR bad number" + self.eol
            value_text = parts[1].strip()
            base = 16 if value_text.lower().lstrip("+-").startswith("0x") else 10
            try:
                self.count = int(value_text, base)
            except ValueError:
                return b"ERR bad number" + self.eol
            return self.reply()

        # Any other input is treated as one pulse.
        self.count += self.step
        return self.reply()


class Simulator:
    def __init__(self, args: argparse.Namespace) -> None:
        self.args = args
        self.running = True
        self.fd: Optional[int] = None
        self.extra_fds: List[int] = []
        self.pty_path: Optional[str] = None
        self.pty_link: Optional[str] = None
        self.buffer = bytearray()
        self.device = CounterDevice(
            start=args.start,
            step=args.step,
            reply_format=args.format,
            eol=EOL_CHOICES[args.eol],
        )
        self.bytes_in = 0
        self.bytes_out = 0
        self.lines_in = 0
        self.replies = 0

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
            self.fd = os.open(
                self.args.port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK
            )
            configure_fd = self.fd
            LOG.info("opened %s", self.args.port)

        assert self.fd is not None
        configure_port(configure_fd, self.args)

    def close(self) -> None:
        for fd in self.extra_fds:
            try:
                os.close(fd)
            except OSError:
                pass
        if self.fd is not None:
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
            "stopped: count=%d, %d line(s) in, %d replies, "
            "%d byte(s) in, %d byte(s) out",
            self.device.count,
            self.lines_in,
            self.replies,
            self.bytes_in,
            self.bytes_out,
        )

    # -- main loop --------------------------------------------------------
    def stop(self, _signum: int, _frame: object) -> None:
        self.running = False

    def run(self) -> int:
        assert self.fd is not None
        next_tick: Optional[float] = None
        if self.args.interval > 0:
            next_tick = time.monotonic() + self.args.interval

        while self.running:
            now = time.monotonic()
            if next_tick is not None and now >= next_tick:
                self.device.count += self.device.step
                self._transmit(self.device.reply(), automatic=True)
                next_tick = now + self.args.interval
                continue

            if next_tick is None:
                timeout = 0.1
            else:
                timeout = min(0.1, max(0.0, next_tick - now))

            try:
                readable, _, _ = select.select([self.fd], [], [], timeout)
            except InterruptedError:
                continue

            if readable:
                self._read_available()

        return 0

    def _read_available(self) -> None:
        assert self.fd is not None
        while True:
            try:
                chunk = os.read(self.fd, 4096)
            except BlockingIOError:
                return
            except OSError as exc:
                if exc.errno in (errno.EIO, errno.EAGAIN):
                    # No peer is reading/writing the other side of a PTY.
                    time.sleep(0.02)
                    return
                raise

            if not chunk:
                time.sleep(0.02)
                return

            self.bytes_in += len(chunk)
            self.buffer.extend(chunk)
            self._process_buffer()

    def _process_buffer(self) -> None:
        while True:
            index = self._find_line_end()
            if index < 0:
                break

            raw = bytes(self.buffer[:index])
            del self.buffer[: index + 1]
            if not raw:
                continue

            self.lines_in += 1
            self._log_data("RX", raw)
            response = self.device.handle(raw)
            if response is not None:
                self._transmit(response)

        if len(self.buffer) > 4096:
            LOG.warning("receive buffer overflow, dropping incomplete line")
            self.buffer.clear()

    def _find_line_end(self) -> int:
        for index, byte in enumerate(self.buffer):
            if byte in (0x0A, 0x0D):
                return index
        return -1

    def _transmit(self, response: bytes, automatic: bool = False) -> None:
        assert self.fd is not None
        delay = self.args.response_delay / 1000.0
        if delay > 0:
            time.sleep(delay)

        write_all(self.fd, response)
        self.bytes_out += len(response)
        self.replies += 1
        self._log_data("TX", response, automatic=automatic)

    def _log_data(self, direction: str, data: bytes, automatic: bool = False) -> None:
        suffix = " (auto)" if automatic else ""
        if self.args.hex:
            LOG.info("%s%s %s", direction, suffix, format_hex(data))
        else:
            LOG.info("%s%s %r", direction, suffix, data.decode("latin-1", "replace"))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="MUTerm counter device simulator (line-oriented ASCII).",
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
    parser.add_argument("--start", type=int, default=0, help="initial counter value")
    parser.add_argument(
        "--step", type=int, default=1, help="amount added for INC and unknown input"
    )
    parser.add_argument(
        "--format",
        default="COUNT={count}!",
        help="reply text; {count} is replaced with the counter value",
    )
    parser.add_argument(
        "--eol",
        choices=tuple(EOL_CHOICES),
        default="crlf",
        help="end-of-line sequence appended to every reply",
    )
    parser.add_argument(
        "--interval",
        type=float,
        default=0.0,
        metavar="SECONDS",
        help="emit an incrementing count this often (0 disables)",
    )
    parser.add_argument(
        "--response-delay",
        type=float,
        default=0.0,
        metavar="MS",
        help="extra delay before every reply in milliseconds",
    )
    parser.add_argument("--hex", action="store_true", help="log every byte in hex")
    parser.add_argument("--debug", action="store_true", help="enable debug logging")
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
    if args.interval < 0:
        parser.error("--interval cannot be negative")
    if args.response_delay < 0:
        parser.error("--response-delay cannot be negative")
    if args.eol not in EOL_CHOICES:
        parser.error(f"unknown --eol value: {args.eol}")
    try:
        args.format.format(count=0)
    except (KeyError, IndexError, ValueError) as exc:
        parser.error(f"invalid --format: {exc}")

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
