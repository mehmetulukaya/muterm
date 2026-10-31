# Yardımcı araçlar

Bu dizin, MUTerm'i gerçek donanım olmadan denemek için kullanılan araçları
içerir. MUTerm'in kendisi gibi bu araçlar da üçüncü taraf `components/`
koduna dokunmaz.

`Send` alanındaki `:KOMUT(...)` betik dili, değişkenler, etiketler, `:IF`
blokları ve `:COM_RECV_TEXT` için [`docs/script-commands.md`](../docs/script-commands.md)
dosyasına bakın.

## mu_sim.py — sanal seri cihaz

`tools/mu_sim.py`, Modbus RTU (FC3/FC4/FC6/FC16) konuşan bir köle cihazı
taklit eder. İki şekilde çalışır:

* `--pty` ile kendi pseudo-terminal çiftini oluşturur; root gerekmez.
* Bir seri aygıt yolu (`/dev/tnt1`, `/dev/ttyUSB0`, ...) verilerek kullanılır.

### Hızlı başlangıç (root gerekmez)

```bash
./tools/mu_sim.py --pty --pty-link /tmp/muterm-pty --baud 9600
```

Komut çıktısındaki yolu MUTerm'de port olarak seçin:

```text
PTY ready: /dev/pts/5
PTY link : /tmp/muterm-pty
```

Ardından MUTerm'de `Open` düğmesine basıp şu betiği çalıştırın:

```text
:COMM_SETUP(,9600,8,None,1)
:COMM_OPEN_CLOSE
:COM_CLEAR_RCV_BUF
:SEND_HEX_CRC(01 03 00 01 00 02)
:COM_WAIT_FOR_HEX(01 03 04 04 D2 16 2E)
:END
```

Simülatörün cevabı:

```text
01 03 04 04 D2 16 2E D5 46
```

`04 D2` = 1234, `16 2E` = 5678 (varsayılan kayıt haritası).

Hazır betik: `tools/modbus_demo.scp` (FC3 okuma, FC6 yazma ve geri okuma).

> PTY'lerde RTS/DTR/CTS/DSR ioctl'leri desteklenmez. El sıkışma hatlarını
> denemek için tty0tty (aşağıda) veya gerçek bir UART kullanın.

### tty0tty ile kullanım

```bash
./tools/mu_sim.py /dev/tnt1 --baud 9600 --rts on --dtr on --poll-lines 0.5
```

MUTerm'de `/dev/tnt0` portunu açın. tty0tty eşlemesi:

| MUTerm | Simülatör |
| ------ | --------- |
| tnt0   | tnt1      |
| tnt2   | tnt3      |
| tnt4   | tnt5      |
| tnt6   | tnt7      |

tty0tty'de RTS karşı tarafın CTS'sine, DTR ise DSR/CD'sine bağlanır.
Simülatör `--rts on --dtr on` ile bu hatları sürer ve `--poll-lines` ile
CTS/DSR/CD/RI değişimlerini loglar.

### Önemli seçenekler

| Seçenek | Açıklama |
| ------- | -------- |
| `--baud`, `--databits`, `--parity`, `--stopbits` | Hat çerçevelemesi |
| `--unit` | Modbus köle adresi (varsayılan 1) |
| `--regs 1=1234,2=5678` | Holding register haritası |
| `--input-regs 0=42` | Input register haritası |
| `--response-delay MS` | Cevaptan önce sabit gecikme |
| `--emulate-timing` | Cevabı baud hızına göre geciktirir |
| `--rts on/off/keep`, `--dtr on/off/keep` | Başlangıç çıkış seviyeleri |
| `--poll-lines SEC` | Hat durumunu bu aralıkla yokla (0 = kapalı) |
| `--hex` | Ham RX/TX çerçevelerini logla |
| `--pty-link PATH` | PTY için sabit bir sembolik bağ oluşturur |

Tam liste: `./tools/mu_sim.py --help`

### Desteklenen Modbus işlevleri

| Kod | İşlev | Davranış |
| --- | ----- | -------- |
| 3 | Read Holding Registers | `--regs` haritasından okur |
| 4 | Read Input Registers | `--input-regs` haritasından okur |
| 6 | Write Single Register | Değeri yazar ve isteği yankılar |
| 16 | Write Multiple Registers | Değerleri yazar, adet döndürür |
| diğer | — | Exception 01 (illegal function) |

CRC hatalı çerçeveler loglanır ve bayt bayt yeniden senkronize edilir.
Birim adresi eşleşmeyen istekler sessizce yok sayılır. `0` birim adresi
(yayın) yazma isteklerini uygular ama cevap vermez.

## setup_tty0tty.sh — sanal null-modem sürücüsü

tty0tty, `/dev/tnt0` ... `/dev/tnt7` arasında çiftler oluşturan bir Linux
kernel modülüdür. RTS/DTR/CTS/DSR hatlarını desteklediği için MUTerm'in el
sıkışma testlerinde kullanılabilir; baud hızı raporlanır ancak gerçek
zamanlama uygulanmaz.

```bash
# Derle ve kur (sudo şifresi ister)
./tools/setup_tty0tty.sh

# Kaldır
./tools/setup_tty0tty.sh --uninstall
```

Betik, `/tmp/opencode/tty0tty` kaynağı varsa onu kullanır; yoksa depoyu
geçici bir dizine klonlar. Farklı bir kaynak için:

```bash
TTY0TTY_SRC=/yol/tty0tty ./tools/setup_tty0tty.sh
```

Kurulumdan sonra doğrulama:

```bash
ls -l /dev/tnt*
# crw-rw---- 1 root dialout ... /dev/tnt0
groups   # dialout grubunda olmalı
```

Grup üyeliği yeni oturumda etkinleşir. Secure Boot açıksa imzasız kernel
modülü yüklenmeyebilir; `mokutil --sb-state` ile kontrol edin.

### Elle kurulum

Araç betiğini kullanmak istemezseniz:

```bash
git clone --depth 1 https://github.com/lcgamboa/tty0tty.git /tmp/tty0tty
make -C /tmp/tty0tty/module
sudo make -C /tmp/tty0tty/module install
ls -l /dev/tnt*
```

## install_desktop.sh — masaüstü girişi ve ikon

MUTerm'in uygulama menüsünde görünmesi ve görev çubuğunda doğru ikonla
eşleşmesi için kişisel dizine bir `.desktop` dosyası ve PNG ikon kurar:

```bash
./tools/install_desktop.sh              # kur
./tools/install_desktop.sh --uninstall  # kaldır
```

Kurulum `~/.local/share/applications/muterm.desktop` dosyasını,
`~/.local/share/icons/hicolor/48x48/apps/muterm.png` ikonunu oluşturur.
`StartupWMClass=MUTerm` sayesinde pencere, çalışan uygulamayla eşleştirilir.

> Linux/GTK2'de LCL'in `.ico` kaynağını `GdkPixbuf`'a çevirirken alfa
> kanalını kaybetmesi ikonun siyah zeminli görünmesine yol açıyordu.
> MUTerm artık açılışta `MUTerm.png` dosyasını GTK'ya doğrudan yükleyerek
> `_NET_WM_ICON` özelliğini doğru alpha değerleriyle ayarlar. PNG dosyası
> çalıştırılabilir dosyanın yanında, bir üst dizinde veya çalışma
> dizininde aranır.

## Sınırlamalar

* tty0tty gerçek zamanlama uygulamaz; `--emulate-timing` yalnızca cevap
  gecikmesini taklit eder.
* PTY'lerde modem hatları yoktur; `TIOCMGET`/`TIOCMSET` `ENOTTY` döner.
* tty0tty RI ve break sinyalini desteklemez, CTS tabanlı akış kontrolünü
  uygulamaz.
