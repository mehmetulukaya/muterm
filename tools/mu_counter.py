#!/usr/bin/env python3
"""MUTerm IEC 62056-21 electricity meter simulator.

IEC 62056-21 (formerly IEC 61107) uyumlu elektrik sayacı simülatörü.
MUTerm'in :COMMAND(...) script dilini donanım olmadan test etmek için
pseudo-terminal (PTY) veya gerçek seri port açar.

Protokol (Mode C - normal readout)
----------------------------------
1. Master:  /?!<CR><LF>                    @ sign-on baud (genelde 300)
2. Sayaç:   /MMMZ<ID><CR><LF>              @ sign-on baud
              MMM = üretici (3 char)
              Z   = baud identification char ('0'..'6')
              ID  = seri numara (8 veya 9 hane)
3. Master:  <ACK>0<mode><baud><CR><LF>     @ sign-on baud
4. Sayaç:   <STX>? data ! <CR><LF><ETX><BCC>  @ data baud (örn. 9600)

Varsayılanlar MUTerm script'iyle birebir uyumludur:
    :COMM_SETUP(,300,7,Even,1)   →  sign-on 300 baud, 7E1
    :COMM_SETUP(,9600,7,Even,1)  →  data    9600 baud, 7E1

Örnek kullanım
--------------
    ./mu_counter.py --pty --pty-link /tmp/muterm-counter \
        --signon-baud 300 --baud 9600 --id 12345678 \
        --data-delay 250 --reset-delay 1000

Sonra MUTerm'de /tmp/muterm-counter aygıtını açıp script'i çalıştırın.
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
from dataclasses import dataclass
from typing import List, Optional, Sequence

# Modbus simülatöründeki seri-port yardımcılarını yeniden kullan.
from mu_sim import configure_port, format_hex, write_all

LOG = logging.getLogger("mu_counter")

EOL_CHOICES = {
    "crlf": b"\r\n",
    "lf": b"\n",
    "cr": b"\r",
}

STX = 0x02
ETX = 0x03
ACK = 0x06

# IEC 62056-21 seri numara: 8 veya 9 hane (sadece rakam).
DEFAULT_ID = "12345678"

DEFAULT_TELEGRAM = [
    "1-0:1.8.1(001234.56*kWh)",
    "1-0:1.8.2(000567.89*kWh)",
    "1-0:21.7.0(001.23*kW)",
    "1-0:31.7.0(005.45*A)",
    "1-0:51.7.0(230.5*V)",
]

# IEC 62056-21 baud-rate identification character.
# Standart: '0'=300, '1'=600, '2'=1200, '3'=2400, '4'=4800,
#           '5'=9600, '6'=19200.
BAUD_CHARS = {
    300: "0",
    600: "1",
    1200: "2",
    2400: "3",
    4800: "4",
    9600: "5",
    19200: "6",
}

# Sign-on için izin verilen baud'lar (standart genelde 300, bazen 2400).
SIGNON_BAUDS = (300, 600, 1200, 2400, 4800, 9600, 19200)


@dataclass
class Reply:
    """Gönderilecek byte'lar ve veri hızına geçilip geçilmeyeceği."""

    data: bytes
    switch_to_data: bool = False


@dataclass
class Stats:
    signons: int = 0
    data_blocks: int = 0
    bytes_in: int = 0
    bytes_out: int = 0


def xor_bytes(data: bytes) -> int:
    value = 0
    for byte in data:
        value ^= byte
    return value


# ---------------------------------------------------------------------------
# Argüman doğrulayıcıları
# ---------------------------------------------------------------------------

def validate_id(value: str) -> str:
    """Seri numara 8 veya 9 hane olmalı (IEC 62056-21)."""
    if not value.isdigit():
        raise argparse.ArgumentTypeError(
            "--id sadece rakamlardan oluşmalıdır"
        )
    if len(value) not in (8, 9):
        raise argparse.ArgumentTypeError(
            f"--id 8 veya 9 hane olmalı, {len(value)} hane verildi"
        )
    return value


def validate_sign_on_baud(value: str) -> int:
    try:
        baud = int(value)
    except ValueError:
        raise argparse.ArgumentTypeError(
            f"--signon-baud bir tamsayı olmalı: {value!r}"
        )
    if baud not in SIGNON_BAUDS:
        raise argparse.ArgumentTypeError(
            f"--signon-baud {SIGNON_BAUDS} değerlerinden biri olmalı"
        )
    return baud


def validate_baud(value: str) -> int:
    try:
        baud = int(value)
    except ValueError:
        raise argparse.ArgumentTypeError(
            f"--baud bir tamsayı olmalı: {value!r}"
        )
    if baud <= 0:
        raise argparse.ArgumentTypeError("--baud pozitif olmalı")
    return baud


def validate_manufacturer(value: str) -> str:
    if len(value) != 3:
        raise argparse.ArgumentTypeError(
            "--manufacturer tam olarak üç karakter olmalı"
        )
    return value


def validate_baud_char(value: str) -> str:
    if len(value) != 1:
        raise argparse.ArgumentTypeError(
            "--baud-char tek bir karakter olmalı"
        )
    return value


# ---------------------------------------------------------------------------
# Sayaç durum makinesi
# ---------------------------------------------------------------------------

class IecMeter:
    """Bir IEC 62056-21 sayacı için durum makinesi."""

    def __init__(self, args: argparse.Namespace) -> None:
        self.args = args
        self.eol = EOL_CHOICES[args.eol]
        self.lines = load_telegram(args.telegram)
        self.identification = build_identification(args)
        self.state = "signon"
        self.stats = Stats()

    def handle(self, buffer: bytearray) -> Optional[Reply]:
        """Buffer'daki bir isteği işle ve sayaç yanıtını döndür."""
        if self.state == "signon":
            return self._handle_sign_on(buffer)
        return self._handle_ack(buffer)

    # -- sign-on ---------------------------------------------------------
    def _handle_sign_on(self, buffer: bytearray) -> Optional[Reply]:
        end = find_line_end(buffer)
        if end < 0:
            return None

        terminator = buffer[end]
        raw = bytes(buffer[:end]).strip(b"\x00 \t")
        del buffer[: end + 1]

        # CR LF çiftinin LF'ini de tüket.
        if terminator == 0x0D and buffer[:1] == b"\n":
            del buffer[:1]

        if not raw.startswith(b"/?"):
            LOG.debug("beklenmeyen sign-on girdisi yok sayıldı: %r", raw)
            return None

        self.stats.signons += 1
        self.state = "ack"
        LOG.info("sign-on request: %r", raw)
        data = self.identification + self.eol
        return Reply(data)

    # -- ACK / veri okuma ------------------------------------------------
    def _handle_ack(self, buffer: bytearray) -> Optional[Reply]:
        index = buffer.find(ACK)
        if index < 0:
            # Hoşgörülü ol: master yeni bir sign-on göndermiş olabilir.
            if b"/?" in buffer:
                self.state = "signon"
            return None

        if index:
            LOG.debug("ACK öncesi %d byte atıldı", index)
            del buffer[:index]

        # IEC 62056-21 ACK dizisi: <ACK> 0 <mode> <baud> [<CR><LF>]
        # En az 4 byte gerekli (ACK + "050"); CR LF varsa tüket.
        if len(buffer) < 4:
            return None

        ack = bytes(buffer[:4])
        del buffer[:4]

        # ACK sonrası CR LF (veya tek CR/LF) tüket — veri bloğuna karışmasın.
        self._consume_eol(buffer)

        self.state = "signon"
        self.stats.data_blocks += 1
        LOG.info("acknowledgement: %r", ack)

        # Master'ın istediği baud char (ACK[3]) ile bizimki uyumlu mu?
        requested = ack[3:4]
        expected = (
            self.args.baud_char or BAUD_CHARS.get(self.args.baud, "")
        ).encode("latin-1")
        if requested and expected and requested != expected:
            LOG.warning(
                "master farklı baud istedi: %r (biz %r kullanıyoruz)",
                requested, expected,
            )

        return Reply(self.telegram(), switch_to_data=True)

    def _consume_eol(self, buffer: bytearray) -> None:
        """Buffer başındaki CR ve/veya LF baytlarını temizle."""
        while buffer[:1] in (b"\r", b"\n"):
            del buffer[:1]

    def telegram(self) -> bytes:
        """Veri telegramını ``!``, ETX ve BCC ile bitirerek oluştur."""
        body = bytearray()
        if self.args.stx:
            body.append(STX)
        for line in self.lines:
            body.extend(line.encode("latin-1", "replace"))
            body.extend(self.eol)
        body.extend(b"!")
        body.extend(self.eol)
        body.append(ETX)

        if self.args.bcc == "none":
            bcc = b""
        else:
            checksum = xor_bytes(bytes(body))
            bcc = bytes((checksum,))
            LOG.info("data BCC: 0x%02X (XOR of %d byte(s) through ETX)",
                     checksum, len(body))

        return bytes(body) + bcc


# ---------------------------------------------------------------------------
# Yardımcılar
# ---------------------------------------------------------------------------

def load_telegram(path: Optional[str]) -> List[str]:
    if not path:
        return list(DEFAULT_TELEGRAM)

    with open(path, "r", encoding="latin-1") as handle:
        lines = handle.read().splitlines()

    # Sondaki boş satırı at, ama kasıtlı boş satırları koru.
    while lines and lines[-1] == "":
        lines.pop()
    if not lines:
        raise ValueError(f"telegram file is empty: {path}")
    return lines


def build_identification(args: argparse.Namespace) -> bytes:
    baud_char = args.baud_char
    if not baud_char:
        baud_char = BAUD_CHARS.get(args.baud, "")
        if not baud_char:
            raise ValueError(
                f"{args.baud} için IEC baud karakteri yok; --baud-char kullanın"
            )
    # Format: /MMMZ<ID>  (ID 8 veya 9 hane)
    text = "/" + args.manufacturer + baud_char + args.id
    return text.encode("latin-1", "replace")


def find_line_end(buffer: bytearray) -> int:
    for index, byte in enumerate(buffer):
        if byte in (0x0A, 0x0D):
            return index
    return -1


# ---------------------------------------------------------------------------
# Simülatör ana döngüsü
# ---------------------------------------------------------------------------

class Simulator:
    def __init__(self, args: argparse.Namespace) -> None:
        self.args = args
        self.running = True
        self.fd: Optional[int] = None
        self.configure_fd: Optional[int] = None
        self.extra_fds: List[int] = []
        self.pty_path: Optional[str] = None
        self.pty_link: Optional[str] = None
        self.buffer = bytearray()
        self.meter = IecMeter(args)
        self.restore_at: Optional[float] = None
        self._in_data_phase = False
        self._processing = False  # rekürsif _process_buffer koruması

    # -- açma / kapama ---------------------------------------------------
    def open(self) -> None:
        if self.args.pty:
            master, slave = pty.openpty()
            self.pty_path = os.ttyname(slave)
            self.fd = master
            self.configure_fd = slave
            self.extra_fds.append(slave)
            os.set_blocking(master, False)
            os.set_blocking(slave, False)

            if self.args.pty_link:
                self.pty_link = os.path.abspath(self.args.pty_link)
                try:
                    os.unlink(self.pty_link)
                except FileNotFoundError:
                    pass
                os.symlink(self.pty_path, self.pty_link)

            LOG.info("PTY hazır: %s", self.pty_path)
            if self.pty_link:
                LOG.info("PTY link : %s", self.pty_link)
            LOG.info("Şimdi MUTerm'de bu aygıtı açın.")
        else:
            self.fd = os.open(
                self.args.port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK
            )
            self.configure_fd = self.fd
            LOG.info("açıldı: %s", self.args.port)

        assert self.fd is not None
        self._configure(self.args.signon_baud)
        LOG.info(
            "port ayarları: sign-on=%d baud, data=%d baud, %d%s%s",
            self.args.signon_baud,
            self.args.baud,
            self.args.databits,
            {1: "N", 2: "E"}.get(
                1 if self.args.parity == "none" else 2, "?"
            ) if False else self.args.parity.upper()[0],
            self.args.stopbits,
        )

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
        stats = self.meter.stats
        LOG.info(
            "durdu: %d sign-on, %d veri bloğu, "
            "%d byte alındı, %d byte gönderildi",
            stats.signons,
            stats.data_blocks,
            stats.bytes_in,
            stats.bytes_out,
        )

    def _configure(self, baud: int) -> None:
        assert self.configure_fd is not None
        values = vars(self.args).copy()
        values["baud"] = baud
        configure_port(self.configure_fd, argparse.Namespace(**values))

    def _switch_to_data(self) -> None:
        delay = self.args.data_delay / 1000.0
        if delay > 0:
            # Master'ın baud değiştirmesi için bekle; bu sırada gelen
            # byte'ları da oku (nadiren olur ama kaybetmeyelim).
            deadline = time.monotonic() + delay
            while self.running:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    break
                try:
                    readable, _, _ = select.select(
                        [self.fd], [], [], remaining
                    )
                except InterruptedError:
                    continue
                if readable:
                    self._read_available()

        LOG.info("veri okuma için %d baud'a geçiliyor", self.args.baud)
        self._configure(self.args.baud)
        self._in_data_phase = True
        if self.args.reset_delay > 0:
            self.restore_at = (
                time.monotonic() + self.args.reset_delay / 1000.0
            )
        else:
            self.restore_at = None

    def _restore_signon_speed(self) -> None:
        LOG.info(
            "sonraki sign-on için %d baud'a geri dönülüyor",
            self.args.signon_baud,
        )
        self._configure(self.args.signon_baud)
        self.restore_at = None
        self._in_data_phase = False

    # -- ana döngü -------------------------------------------------------
    def stop(self, _signum: int, _frame: object) -> None:
        self.running = False

    def run(self) -> int:
        assert self.fd is not None
        while self.running:
            if (
                self.restore_at is not None
                and time.monotonic() >= self.restore_at
            ):
                self._restore_signon_speed()

            try:
                readable, _, _ = select.select([self.fd], [], [], 0.1)
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
                    # PTY'nin diğer ucu okumuyor/yazmıyor.
                    time.sleep(0.02)
                    return
                raise

            if not chunk:
                time.sleep(0.02)
                return

            self.meter.stats.bytes_in += len(chunk)
            self.buffer.extend(chunk)
            self._process_buffer()

    def _process_buffer(self) -> None:
        if self._processing:
            # _switch_to_data içinden rekürsif çağrı; dış döngü hallediyor.
            return
        self._processing = True
        try:
            while self.buffer:
                reply = self.meter.handle(self.buffer)
                if reply is None:
                    break
                if reply.switch_to_data:
                    self._switch_to_data()
                self._transmit(reply.data)

            if len(self.buffer) > 4096:
                LOG.warning(
                    "alım tamponu taştı, biriken veri atılıyor"
                )
                self.buffer.clear()
        finally:
            self._processing = False

    def _transmit(self, response: bytes) -> None:
        assert self.fd is not None
        delay = self.args.response_delay / 1000.0
        if delay > 0:
            time.sleep(delay)

        write_all(self.fd, response)
        self.meter.stats.bytes_out += len(response)
        self._log_data("TX", response)

    def _log_data(self, direction: str, data: bytes) -> None:
        if self.args.hex:
            LOG.info("%s %s", direction, format_hex(data))
        else:
            LOG.info(
                "%s %r",
                direction,
                data.decode("latin-1", "replace"),
            )


# ---------------------------------------------------------------------------
# Argüman ayrıştırıcı
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "MUTerm IEC 62056-21 electricity meter simulator. "
            "Defaults match the MUTerm script: 300 7E1 sign-on, "
            "9600 7E1 data readout."
        ),
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "port",
        nargs="?",
        help="kullanılacak seri aygıt (örn. /dev/tnt1); --pty ile atlayın",
    )
    parser.add_argument(
        "--pty",
        action="store_true",
        help="seri aygıt yerine bir pseudo-terminal oluştur",
    )
    parser.add_argument(
        "--pty-link",
        metavar="PATH",
        help="PTY slave'e symlink oluştur (--pty'yi ima eder)",
    )
    parser.add_argument(
        "--signon-baud",
        type=validate_sign_on_baud,
        default=300,
        metavar="BAUD",
        help=f"sign-on/kimlik baud hızı; {SIGNON_BAUDS} içinden biri",
    )
    parser.add_argument(
        "--baud",
        type=validate_baud,
        default=9600,
        metavar="BAUD",
        help="veri okuma fazı için hat hızı",
    )
    parser.add_argument(
        "--databits",
        type=int,
        choices=(5, 6, 7, 8),
        default=7,
        help="veri biti",
    )
    parser.add_argument(
        "--parity",
        choices=("none", "even", "odd"),
        default="even",
        help="parite modu",
    )
    parser.add_argument(
        "--stopbits",
        type=int,
        choices=(1, 2),
        default=1,
        help="stop biti",
    )
    parser.add_argument(
        "--id",
        type=validate_id,
        default=DEFAULT_ID,
        help="sayaç seri numarası (8 veya 9 hane)",
    )
    parser.add_argument(
        "--manufacturer",
        type=validate_manufacturer,
        default="ABC",
        help="üç karakterli üretici kimliği",
    )
    parser.add_argument(
        "--baud-char",
        type=validate_baud_char,
        default=None,
        metavar="CHAR",
        help="baud kimlik karakteri (--baud'dan türetilir)",
    )
    parser.add_argument(
        "--telegram",
        metavar="FILE",
        help="yerleşik telegram yerine FILE'dan OBIS satırları oku",
    )
    parser.add_argument(
        "--stx",
        action="store_true",
        help="veri bloğunun başına STX (0x02) ekle",
    )
    parser.add_argument(
        "--bcc",
        choices=("xor", "none"),
        default="xor",
        help="blok kontrol karakteri: ETX'e kadar XOR veya yok",
    )
    parser.add_argument(
        "--eol",
        choices=tuple(EOL_CHOICES),
        default="crlf",
        help="protokolde kullanılan satır sonu dizisi",
    )
    parser.add_argument(
        "--data-delay",
        type=float,
        default=250.0,
        metavar="MS",
        help=(
            "master'ın hız değiştirebilmesi için veri bloğundan önce "
            "beklenecek süre (ms). MUTerm ACK'den sonra ~200 ms bekler; "
            "250 ms güvenli değerdir"
        ),
    )
    parser.add_argument(
        "--reset-delay",
        type=float,
        default=1000.0,
        metavar="MS",
        help="bu süre sonra sign-on hızına dön (0 = asla)",
    )
    parser.add_argument(
        "--response-delay",
        type=float,
        default=0.0,
        metavar="MS",
        help="her yanıttan önce ek gecikme (ms)",
    )
    parser.add_argument(
        "--hex",
        action="store_true",
        help="her byte'ı hex olarak logla",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="debug loglamayı etkinleştir",
    )
    return parser


# ---------------------------------------------------------------------------
# Giriş noktası
# ---------------------------------------------------------------------------

def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.pty_link:
        args.pty = True
    if args.pty and args.port:
        parser.error("--pty bir port ile birlikte kullanılamaz")
    if not args.pty and not args.port:
        parser.error("ya bir port ya da --pty gerekli")
    if args.data_delay < 0 or args.reset_delay < 0:
        parser.error("gecikmeler negatif olamaz")
    if args.response_delay < 0:
        parser.error("--response-delay negatif olamaz")

    try:
        # Sayaç için gerekli değerleri port açmadan doğrula.
        IecMeter(args)
    except (OSError, ValueError) as exc:
        parser.error(str(exc))

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
        LOG.error(
            "%s açılamadı: %s", args.port or "PTY", exc
        )
        simulator.close()
        return 1

    try:
        return simulator.run()
    finally:
        simulator.close()


if __name__ == "__main__":
    sys.exit(main())