# MUTerm betik komutları

Bu belge, `Send` alanındaki `:KOMUT(...)` satır dili için geçerlidir.
Tam PascalScript (`program ... begin ... end.`) sekmesi bundan ayrıdır; orada
`if`, `var`, `POS` gibi tüm Pascal olanakları zaten vardır.

Komutlar satırın başındaki `:` token'ı ile eşleştirilir. Büyük/küçük harf
fark etmez.

## Komut listesi

| Komut | Açıklama |
| --- | --- |
| `:WAIT 0.5` | Saniye cinsinden bekler. |
| `:WAIT_COMM 1.0` | Seri veri gelene kadar bekler. |
| `:WAIT_TCP 1.0` | TCP verisi gelene kadar bekler. |
| `:COMM_SETUP(,9600,8,None,1)` | Seri port ayarları. Boş port adı mevcut seçimi korur. |
| `:COMM_OPEN_CLOSE` | Port açıksa kapatır, kapalıysa açar. |
| `:COM_CLEAR_RCV_BUF` | Seri alım tamponunu temizler. |
| `:COM_WAIT_FOR_TEXT(!)` | Tamponda metin görünene kadar bekler. |
| `:COM_WAIT_FOR_TEXT(!,3.0)` | En fazla 3 sn bekler; süre dolarsa devam eder. |
| `:COM_WAIT_FOR_HEX(01 03)` | Hex metin görünene kadar bekler. |
| `:COM_RECV_TEXT(str)` | Seri tamponu `str` değişkenine kopyalar. |
| `:COM_RECV_TEXT(str,1.0)` | Tampon dolana kadar en fazla 1 sn bekler, sonra kopyalar. |
| `:SEND_TEXT(...)` | Metin gönderir. `#013#010`, `$0D$0A` kaçışları geçerlidir. |
| `:SEND_HEX(01 03 00 01)` | Hex baytları gönderir. |
| `:SEND_HEX_CRC(01 03 00 01)` | Hex baytları ve ardından CRC16 gönderir. |
| `:TCP_SETUP(host,port)` | TCP hedefini ayarlar. |
| `:TCP_OPEN_CLOSE` | TCP bağlantısını açar/kapatır. |
| `:TCP_SEND_TEXT(...)`, `:TCP_SEND_HEX(...)` | TCP verisi gönderir. |
| `:TCP_WAIT_FOR_TEXT(...)`, `:TCP_WAIT_FOR_HEX(...)` | TCP tamponunda bekler. |
| `:TCP_RECV_TEXT(var)` | TCP tamponunu değişkene kopyalar. |
| `:SRV_SETUP(8080)` | Sunucu portunu ayarlar. |
| `:SRV_LISTEN`, `:SRV_DISCONNECT` | Sunucuyu dinletir / kapatır. |
| `:SRV_SEND_TEXT(...)`, `:SRV_SEND_HEX(...)` | Sunucudan veri gönderir. |
| `:SRV_WAIT_FOR_TEXT(...)`, `:SRV_WAIT_FOR_HEX(...)` | Sunucu tamponunda bekler. |
| `:SRV_RECV_TEXT(var)` | Sunucu tamponunu değişkene kopyalar. |
| `:SET(name,value)` | Değişken tanımlar/atar. |
| `:LABEL name` | Etiket tanımlar. |
| `:GOTO name` / `:GOTO 5` | Etikete veya satır indeksine atlar. |
| `:IF(ifade) GOTO label` | Tek satırlık koşullu atlama. |
| `:IF(ifade)` ... `:ELSE` ... `:END IF` | Blok koşul. |
| `:END` | Betiği bitirir. |

## Değişkenler

Değişkenler string'dir. İsim kuralı: `[A-Za-z_][A-Za-z0-9_]*`, büyük/küçük
harf duyarsız. Her betik çalışmasının başında sıfırlanır.

```text
:SET(isim,Ahmet)
:SET(mesaj,MERHABA {isim}!#013#010)
:SEND_TEXT({mesaj})
```

- Metin komutlarında `{name}` genişletilir.
- `{{` literal `{` üretir.
- Tanımsız değişken boş string olur ve `General` log'una bir kez uyarı yazılır.
- `TIMEOUT` değişkeni zaman aşımı olan komutlar tarafından yönetilir:
  başarıda `0`, zaman aşımında `1`.

## Etiketler ve GOTO

```text
:LABEL BASLA
:WAIT 1.0
:GOTO BASLA
```

- Etiketler önceden taranır; ileri etiketler de çalışır.
- `:GOTO 5` sayısal hedefi **0 tabanlı satır indeksi** olarak yorumlar. Eski
  betiklerle uyumluluk için değiştirilmedi; etiket kullanımı önerilir.
- Aynı etiket iki kez tanımlanırsa veya hedef bulunamazsa betik durur.

## IF

### Tek satır

```text
:IF((not POS(str,'/')) and (not POS(str,#013#010))) GOTO LETS_END
```

Koşul doğruysa `GOTO` uygulanır, yanlışsa sonraki satıra geçilir.

### Blok

```text
:IF(TIMEOUT = 1)
  :GOTO LETS_END
:ELSE
  :WAIT 0.5
  :SEND_TEXT(!#013#010)
:END IF
```

- `:END IF`, `:ENDIF` ve `:END_IF` aynı anlamdadır.
- İç içe bloklar desteklenir.
- `:ELSE` ve `:END IF` eşleşmeleri betik başlamadan önce hesaplanır.
- Blok içine etiketle atlamak teknik olarak çalışır, ancak etiketleri blok
  sınırlarında kullanmanız önerilir.

## İfade dili

| Öğe | Açıklama |
| --- | --- |
| `'metin'` | String. `''` tek tırnak kaçışıdır. |
| `#013`, `#$0D` | Karakter kodu (ondalık / hex). |
| `degisken` | Değişken değeri. |
| `POS(haystack, needle)` | `needle`'ın `haystack` içindeki 1 tabanlı konumu; yoksa `0`. |
| `POSP(needle, haystack)` | Pascal sırası: `Pos(needle, haystack)`. |
| `CONTAINS(haystack, needle)` | Boolean. |
| `LEN(s)`, `TRIM(s)`, `UPPER(s)`, `LOWER(s)` | String yardımcıları. |
| `=`, `<>`, `<`, `>`, `<=`, `>=` | Karşılaştırma. İki taraf sayıysa sayısal, değilse metin. |
| `not`, `and`, `or`, `( )` | Boolean işlemler. |

Boolean yorumu: `0`, boş string, `false`, `no`, `off` → yanlış; diğerleri →
doğru. `POS` sonucu sayı olduğu için `not POS(...)` beklendiği gibi çalışır.

## Örnek: el sıkışma

```text
:WAIT 0.1
:COMM_SETUP(,300,7,Even,1)
:COM_CLEAR_RCV_BUF
:WAIT 0.1
:COMM_OPEN_CLOSE
:WAIT 0.1
:SEND_TEXT(/?!#013#010)
:COM_RECV_TEXT(str,1.0)
:IF((not POS(str,'/')) and (not POS(str,#013#010))) GOTO LETS_END
:WAIT 0.5
:SEND_TEXT(#006050#013#010)
:WAIT 0.2
:COMM_SETUP(,9600,7,Even,1)
:WAIT 0.2
:COM_WAIT_FOR_TEXT(!,3.0)
:WAIT 0.2
:LABEL LETS_END
:COMM_OPEN_CLOSE
:WAIT 10.0
:GOTO 1
:END
```

Not: `:GOTO 1` ikinci satıra (0 tabanlı indeks 1) gider. Döngünün başına
dönmek için bir etiket kullanmak daha okunaklıdır:

```text
:LABEL BASLA
...
:GOTO BASLA
```

## Test için IEC 62056-21 sayaç simülatörü

`tools/mu_counter.py`, bu komutları gerçek donanım olmadan denemek için
IEC 62056-21 (Mod C) uyumlu bir elektrik sayacı taklit eder. Önce 300 baud
7E1 ile sign-on, ardından 9600 baud 7E1 ile veri okuma yapar:

```bash
./tools/mu_counter.py --pty --pty-link /tmp/muterm-counter
```

Cihaz `/?!` isteğine `/MMMZ<ID>` kimlik yanıtı verir; `<ACK>0<baud><mode>`
dizisinden sonra OBIS satırlarını, `!`, `ETX` ve `BCC` içeren veri bloğunu
gönderir. Ayrıntılar ve örnek betik:
[`tools/README.md`](../tools/README.md#mu_counterpy--iec-62056-21-sayaç-simülatörü).

## Hata davranışı

- Bilinmeyen komut satırları eskisi gibi düz metin olarak gönderilir.
- Tanınan bir komutun argümanı/sözdizimi hatalıysa `General` log'una hata
  yazılır ve betik durur; satır porttan gönderilmez.
- Eşleşmeyen `:ELSE`, eksik `:END IF`, aynı isimde etiket ve geçersiz
  değişken adı betiğin başlamasını engeller.
