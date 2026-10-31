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

## mu_counter.py — sayaç simülatörü

`tools/mu_counter.py`, satır tabanlı ASCII komutlarla konuşan küçük bir sayaç
cihazıdır. `:IF`, `:LABEL`, değişkenler, `:COM_RECV_TEXT` ve `TIMEOUT`
davranışlarını gerçek donanım olmadan denemek için tasarlandı. Seri port
yardımcılarını `mu_sim.py`'den alır; iki dosyayı aynı dizinde tutun.

### Hızlı başlangıç (root gerekmez)

```bash
./tools/mu_counter.py --pty --pty-link /tmp/muterm-counter --baud 9600
```

Çıktıdaki yolu MUTerm'de port olarak seçin:

```text
PTY ready: /dev/pts/7
PTY link : /tmp/muterm-counter
```

Ardından `Send` alanında şu betiği çalıştırın:

```text
:COMM_SETUP(,9600,8,None,1)
:COMM_OPEN_CLOSE
:WAIT 0.2
:LABEL BASLA
:COM_CLEAR_RCV_BUF
:SEND_TEXT(/?!#013#010)
:COM_RECV_TEXT(cevap,1.0)
:IF(not CONTAINS(cevap,'/')) GOTO HATA
:COM_CLEAR_RCV_BUF
:SEND_TEXT(INC#013#010)
:COM_RECV_TEXT(deger,1.0)
:IF(TIMEOUT = 1) GOTO HATA
:SEND_TEXT(Sayac: {deger}#013#010)
:WAIT 1.0
:GOTO BASLA
:LABEL HATA
:SEND_TEXT(El sikisma basarisiz#013#010)
:END
```

### Protokol

İstekler CR ve/veya LF ile ayrılır; büyük/küçük harf fark etmez.

| Giriş | Cevap | Sayaç |
| ----- | ----- | ----- |
| `/?!`, `?`, `PING` | `/OK` + satır sonu | değişmez |
| `GET`, `GET?`, `COUNT?`, `READ` | `COUNT=<n>!` | değişmez |
| `RESET`, `CLR`, `CLEAR` | `COUNT=0!` | sıfırlanır |
| `SET <sayı>` | `COUNT=<n>!` | verilen değer |
| `INC`, `+`, `NEXT` | `COUNT=<n>!` | `--step` kadar artar |
| diğer her şey | `COUNT=<n>!` | `--step` kadar artar |

Varsayılan cevap biçimi `COUNT={count}!`; sondaki `!` sayesinde
`:COM_WAIT_FOR_TEXT(!)` kolayca test edilir. El sıkışma cevabı bilerek `!`
içermez, böylece eski bir `!` beklemesini yanlışlıkla karşılamaz.

### Önemli seçenekler

| Seçenek | Açıklama |
| ------- | -------- |
| `--start N`, `--step N` | Başlangıç değeri ve artış miktarı |
| `--format METIN` | Cevap biçimi; `{count}` ile sayaç yazılır |
| `--eol crlf/lf/cr` | Cevap satır sonu (varsayılan `crlf`) |
| `--interval SEC` | Her aralıkta otomatik sayım yayınlar (0 = kapalı) |
| `--response-delay MS` | Cevaptan önce sabit gecikme |
| `--baud`, `--databits`, `--parity`, `--stopbits` | Hat çerçevelemesi |
| `--hex` | Ham RX/TX baytlarını hex olarak loglar |
| `--pty-link PATH` | PTY için sabit bir sembolik bağ oluşturur |

Tam liste: `./tools/mu_counter.py --help`

Otomatik sayım örneği:

```bash
./tools/mu_counter.py --pty --pty-link /tmp/muterm-counter \
    --start 0 --step 1 --interval 1.0 --eol crlf
```

Bu modda cihaz saniyede bir `COUNT=1!`, `COUNT=2!`, ... satırları gönderir;
`--hex` ile bayt düzeyinde inceleyebilirsiniz.

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
