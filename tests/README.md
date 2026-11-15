# MuTerm unit tests

Bu dizin, LCL'den bağımsız MuTerm birimleri için **headless FPCUnit**
testlerini içerir. Amaç, SOLID refactor'ına başlamadan önce mevcut
davranışı karakterize etmek ve her refactor adımında aynı davranışın
korunduğunu kanıtlayabilmek.

## Kapsam

| Test birimi | Kapsanan modül |
| --- | --- |
| `MuLibsTests.pas` | Hex/metin dönüşümleri, CRC16, FCS, bit yardımcıları |
| `MuExprTests.pas` | `:IF` / `:SET` ifade değerlendiricisi |
| `MuCommandsTests.pas` | Komut motoru, `:IF` / `:GOTO` / `:SET`, TCP/seri/sunucu komutları |

`MuTestContext.pas`, `ICommandContext` için donanım ve UI olmadan çalışan
bir test double'ı sağlar. Testler seri port veya ağ erişimi gerektirmez.

## Çalıştırma

```bash
./tests/run-tests.sh
```

Farklı bir FPC kullanmak için:

```bash
FPC=/path/to/fpc ./tests/run-tests.sh
```

Script, derleme çıktısını `$TMPDIR/muterm-tests` altında tutar; depoyu
kirletmez. FPCUnit, FPC'nin `fcl-fpcunit` paketiyle birlikte gelir.

Lazarus IDE'den çalıştırmak isterseniz `tests/MuTests.lpr` dosyasını
açıp normal bir konsol projesi gibi derleyebilirsiniz.

## Test yazma kuralları

- Testler **mevcut davranışı** belgeler. Bir davranış hatalıysa önce
  hatayı düzelten ayrı bir commit atılır, test de yeni doğru davranışı
  doğrular.
- Donanım, saat veya ağ üzerinden gerçek bekleme yapılmaz. Zaman aşımı
  gibi durumlar kısa ve kontrollü `Sleep` ile sınanır.
- Yeni bir taşıma (ör. WebSocket) eklendiğinde, `ICommandContext` yerine
  rol arayüzleri kullanılmaya başlanacağı için test double'ı da küçülecek.

## CI

`.github/workflows/ci.yml` içindeki `test` işi bu paketi Linux üzerinde
çalıştırır. Derleme işinden (`build`) bağımsızdır ve yaklaşık 1 dakika
sürer.
