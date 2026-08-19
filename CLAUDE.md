# Oyuncu DÃ¼kkanÄ± â€” Claude BaÄŸlamÄ±

## ğŸš¨ MARKET BUILD Ã–NCESÄ° ZORUNLU KONTROL (KULLANICI KURALI)
**Herhangi bir market Ã§Ä±ktÄ±sÄ± (AAB / IPA / appbundle / App Store / Play Store build) hazÄ±rlamadan Ã–NCE:**
1. Kodda Google TEST reklam ID'si (`ca-app-pub-3940256099942544/...`) kaldÄ± mÄ± KONTROL ET
   - `grep "3940256099942544" lib/main.dart` ile bak
2. Test ID kaldÄ±ysa â†’ **MARKET BUILD VERME**, Ã¶nce kullanÄ±cÄ±dan gerÃ§ek (prod) AdMob ID'lerini iste ve deÄŸiÅŸtir
3. Bu kural TÃœM uygulamalar iÃ§in geÃ§erli (oyuncu_dukkani, snapiq, matematikcik, magnus...)

**Mevcut PROD reklam ID'leri (oyuncu_dukkani):**
- iOS geÃ§iÅŸ: `ca-app-pub-6470338276121414/1436676062`
- Android geÃ§iÅŸ: `ca-app-pub-6470338276121414/4138047986`
- iOS Ã¶dÃ¼llÃ¼ (henÃ¼z kullanÄ±lmÄ±yor): `ca-app-pub-6470338276121414/2648809677`

---

## Proje Ã–zeti
Flutter ile geliÅŸtirilmiÅŸ bir mobil oyun. Oyuncu bir oyun dÃ¼kkanÄ± yÃ¶netir: mÃ¼ÅŸteri kabul eder, pazarlÄ±k yapar, envanter yÃ¶netir, dÃ¼kkanÄ±nÄ± bÃ¼yÃ¼tÃ¼r.

## Teknik YÄ±ÄŸÄ±n
- **Flutter** (Dart) â€” tek dosya mimarisi: `lib/main.dart`
- **Android** â€” paket adÄ±: `com.oyuncudukkani.app`
- **pubspec.yaml** â€” versiyon: `1.0.2+13`
- Paketler: `audioplayers`, `shared_preferences`, `google_mobile_ads`, `device_info_plus`, `app_tracking_transparency`, `device_preview` (dev), `flutter_launcher_icons` (dev)
- **Kotlin**: 2.1.0 (Android `settings.gradle.kts`)
- **App Store**: YAYINDA â†’ https://apps.apple.com/us/app/oyuncu-dÃ¼kkanÄ±/id6778437262

## Dosya YapÄ±sÄ±
```
lib/main.dart          — oyun mantığının tamamı
lib/kirgec_oyunu.dart  — KIRGEÇ mini oyunu (breakout, oynanabilir CD)
lib/itele_oyunu.dart   — İTELE mini oyunu (pong, oynanabilir CD)
assets/                â€” gÃ¶rseller ve sesler
  bg1.png              â€” masa (bilgisayarsÄ±z)
  bg2.png              â€” masa (bilgisayarlÄ± / iMac alÄ±ndÄ±ktan sonra)
  bgbos.png            — dükkan arka planı (seviye 1)
  bgbos_2/3/4.jpg      — seviye 2/3/4-5 arka planları (JPEG: opak, PNG'de 6.5MB olurdu)
  bgbosmasa.png        — masa (3. günden önce)
  kapidaki.png         — kapıda bekleyen silüet (müşteri yokken; dükkana göre konumlanır)
  musteri_1..28.png    — müşteri karakterleri (28 adet, yaş/cinsiyet musteriHavuzu içinde)
  hirsiz/polis/vergici/kurye/toptanci/falci.png — özel müşteri karakterleri
  CD_1..16.png         — 16 CD ürünü (CD_15 KIRGEÇ, CD_16 İTELE = oynanabilir)
  konsol_1..7.png      â€” konsol Ã¼rÃ¼nleri (PlayStatyon, Ninetendo, Ateri, El Konsolu x3, son sistem)
  durum.png            â€” kurye'nin getirdiÄŸi yemek gÃ¶rseli
  kolonya.png          â€” kolonya gÃ¶rseli (envanter + buton ikonu)
  oyuncu_dukkani_icon.png  â€” uygulama ikonu kaynaÄŸÄ±
  anamenu.png          â€” ana menÃ¼ arka planÄ±
  oyuncudireksiyonu, joypad, gamepad, lokum, browser, zarf, 3dgozluk â€” aksesuar/CD
android/               â€” native Android yapÄ±landÄ±rmasÄ±
```

## Oyun Mimarisi (main.dart)

### AkÄ±ÅŸ
```
SplashScreen (6 sn yasal metin)
  â†’ AnaMenuEkrani (baÅŸla / devam)
    â†’ GameScreen (ana oyun dÃ¶ngÃ¼sÃ¼)
```

### Temel SÄ±nÄ±flar
- `GameState` â€” tÃ¼m oyun durumu (ChangeNotifier), SharedPreferences ile kayÄ±t
- `GameScreen` / `_GameScreenState` â€” UI ve animasyonlar
- `Musteri` / `OzelMusteri` â€” mÃ¼ÅŸteri modeli
- `DukkanSeviye` â€” dÃ¼kkan seviyeleri (1-5, farklÄ± kira ve mÃ¼ÅŸteri sayÄ±sÄ±)

---

## 👥 KARAKTER HAVUZU (v103)

**28 müşteri görseli** (11 eski + 17 yeni). Dağılım: **14 erkek, 14 kadın**.
İsim havuzu: **150 erkek + 150 kadın**, hepsi benzersiz (tekrar kontrolü yapıldı).

Her karakterin `musteriHavuzu` satırında **`cinsiyet` + `yas`** alanı ve yanında
kim olduğu yorum olarak yazılı. Örn: `musteri_22` = punk, mor mohawk, K, genc.

### v103: görseller kullanıcının kendi kesimi — İŞLENMEDİ
Kullanıcı `tools/arkaplan_sil.ps1` çıktısını beğenmedi, arka planları kendisi
temizledi (`removebg`). Yeni dosyalar `assets/`e **olduğu gibi** kopyalandı —
yeniden ölçekleme/çerçeveleme YOK. Zaten 500×500 ARGB geldiler ve içerik
kutuları mevcut 11 karakterle uyumluydu (yükseklik 419–490, alt boşluk 5–38;
eski 11'de 454–488 / 0–17). Emülatörde doğrulandı: hale yok, masa hizası doğru.

> ⚠️ **28'e düştü:** kaynak klasörde bir dosya md5 olarak tekrardı ve eski
> `musteri_19` (kot ceket / hardal etek, K) karşılığı yoktu. `musteri_29.png`
> silindi, `pubspec.yaml`'dan da çıkarıldı. Yeni bir görsel gelirse
> `musteri_29` olarak eklenip `musteriHavuzu`'na bir satır yazmak yeterli.

> ⚠️ Yeni görsel geldiğinde **her zaman** `md5sum *.png | sort | uniq -d` ile
> tekrar kontrolü yap — bu tuzağa iki kez düşüldü.

### 🚨 KARAKTER GÖRSELİ KARE OLMALI
Sahnede müşteri **kare bir kutuya** `BoxFit.contain` ile çiziliyor
(`width: boy, height: boy`, `boy = m.u(kMusteriBoyu)`). Kare olmayan bir görsel
letterbox olur → karakter küçülür ve masadan yukarı kalkar.

Elde kare olmayan bir kesim varsa, **yeniden ölçekleme yapmadan** kare tuvale
taşı: alfa sınır kutusunu bul, içeriği 1:1 kopyala, tuval boyutunu
`icerikYuksekligi / doluluk` ile seç. v103'te `toptanci.png` böyle yapıldı
(456×547 → 470×470, içerik 196×454 native piksel, üst 4 / alt 12).
Oranlar: **doluluk 0.95–0.965, alt boşluk ~0.025** (mevcut kadroyla uyumlu).

### Arka plan silme aracı — `tools/arkaplan_sil.ps1` (şu an KULLANILMIYOR)
Beyaz zeminli görseli oyunun formatına çeviren araç. v103'te devre dışı ama
duruyor: elde ham (beyaz zeminli) bir görsel kalırsa hâlâ çalışır.

```powershell
Set-Location C:\src\oyuncu_dukkani\tools
. .\arkaplan_sil.ps1                       # C# helper'i derler
[BgKiller]::Process($kaynak, $hedef, 500, 640, 232, 0.95, 5)
# parametreler: cikisBoyut, calismaCozunurlugu, beyazEsigi, doluluk, altBosluk
```
Toplu iş + kontak sayfası için: `tools/toplu_isle.ps1`

**Nasıl çalışıyor (ve neden böyle):**
1. **Kenardan flood-fill** — "tüm beyazları sil" DEĞİL. Öyle yapılsa beyaz gömlek/
   pantolon da silinirdi. Sadece dış kenara bağlı beyaz temizlenir.
2. **Hale yumuşatma** — şeffaf komşusu olan çok açık pikseller kısmi alfa alır,
   beyaz kontur kalmaz.
3. **PASS 2: alt bölge kapalı leke temizliği** — bacak arasında kalan ve dışarıya
   bağlanamayan beyaz bloklar (yer gölgesi bunları mühürlüyor) siliniyor.
4. **Çerçeve normalize** — içerik kutusu bulunup 500×500 tuvale, yüksekliğin
   %95'i olacak şekilde, yatay ortalı, altta 5px boşlukla yerleştirilir.

> ⚠️ PowerShell 5.1, BOM'suz UTF-8 `.ps1` dosyasını ANSI okur → Türkçe yol bozulur.
> Script ASCII-only tutuldu, yollar `Get-ChildItem` ile dosya sisteminden alınıyor.
> Saf PowerShell piksel döngüsü çok yavaş; iş **Add-Type ile C#'a** verildi.

> ℹ️ Ayak altındaki küçük gölge izleri **önemsiz** — müşteri masanın arkasında
> göğsünden kesiliyor (`kMusteriUstu` 0.2183 → masa 0.4833), ayaklar hiç görünmüyor.

---

## 🕹️ OYNANABİLİR ÜRÜNLER — MİNİ OYUNLAR (v106)

Bazı CD'ler gerçekten **oynanabilir**. Envanterde köşelerinde ⭐ vardır,
tıklanınca "oynamak ister misin?" çıkar, EVET denince tam ekran mini oyun açılır.
Toplanan **puan birebir paraya çevrilip** ana oyundaki bakiyeye eklenir.

| Ürün | Oyun | Dosya | Kazanç |
|---|---|---|---|
| `cd15` KIRGEÇ | breakout | `lib/kirgec_oyunu.dart` | tam temizlik ≈ 386 lira |
| `cd16` İTELE | pong (tek kişilik) | `lib/itele_oyunu.dart` | galibiyet = 100 lira |

### Kurallar
- **GÜNDE 1 KEZ.** `GameState.bugunOynananOyunlar` (Set), `gunuBitir()` içinde
  temizlenir, kayıtta saklanır. İkinci denemede *"Bugün X oyunu oynandı.
  Bir sonraki oyun için yarın gel."* çıkar.
  > Hak, oyuna **girer girmez** yanar — yoksa oyuncu kötü skoru görüp geri
  > çıkar, tekrar girerdi.
- **Para tavanı** `GameState.oyunPuanTavani` = 1000 (oyun başına).
- **NADİR gelir**: satıcı müşteride %5 ihtimalle oynanabilir havuzdan seçilir
  (`yeniMusteriGonder`). Toptancıdan ve kapalı kutudan **hiç çıkmaz**.
- **Fiyat**: oynanabilir oyunlar normal CD ortalamasının (~134) **2 katı** = 270.
- Çürük CD oynanmaz — önce tamir edilmeli.

### Kontrol şeması (iki oyunda da aynı)
Ekranın **sağ yarısına basılı tut** → sağa, **sol yarısına** → sola.
`Listener` + `onPointerDown/Move/Up` ile; `GestureDetector` tek dokunuş verir,
çubuk topa yetişemezdi.

### Teknik
- Her oyun `Navigator.push` ile açılır, `Navigator.pop(context, puan)` ile
  puanı döner. Ana oyun state'i bozulmaz, kalınan yere dönülür.
- `PopScope(canPop: false)` — geri tuşuyla çıkılsa da puan kaybolmaz.
- Oyun alanı mantıksal **100×140 birim**; `LayoutBuilder` + ölçek ile ekrana
  sığdırılır. Sabit piksel yok, `CustomPaint` ile çizilir.
- `Ticker` tabanlı döngü; `dt` `1/30` ile sınırlı (kare atlarsa fizik patlamasın).

### Yeni oynanabilir ürün eklerken
1. `GameItem(... oynanabilir: true)` — fiyat: normal ortalamanın 2 katı
2. `_oyunEkrani(urunId)` switch'ine bir satır
3. Oyun dosyasını `lib/` altına yaz, puanı `pop` ile döndür

---

## 🛠️ OYNANIŞ DÜZELTMELERİ VE EKLERİ (v105)

### 🐛 Pazarlıkta "teklif ver çalışmıyor" hataları
İki ayrı hata vardı, ikisi de `_PazarlikDialogState`'te:

1. **Buton basılınca hiçbir şey olmuyordu** — `_teklifGonder` geçersiz girdide
   (boş kutu, 0, harf) sessizce `return` ediyordu. Kullanıcıya hiçbir geri
   bildirim yok.
2. **Popup kapanmıyor, sadece arkadaki balon değişiyordu** — `teklifVer()` bir
   hata atarsa `Navigator.pop()` satırına hiç ulaşılmıyordu. Model güncellendiği
   için balon değişiyor ama dialog ekranda kalıyordu.

```dart
try {
  widget.state.teklifVer(teklif!);
} finally {
  if (mounted) Navigator.of(context).pop();   // kapanma HER KOŞULDA garanti
}
```
Ayrıca `_bitti` bayrağı çift dokunuşu engelliyor.

### Teklif geçerlilik kuralı — SINIR bazlı, yön bazlı DEĞİL
Müşteri bir fiyatı reddettikten sonra o rakamın ötesine geçmek anlamsız.
Kural tek yönlü bir **sınır** koyar, oyuncu sınırın beri tarafında serbesttir:

| Oyuncu | `_minTeklif` | `_maxTeklif` |
|---|---|---|
| ALIYOR (müşteri satıyor) | `oyuncuTeklif + 1` | — |
| SATIYOR (müşteri alıyor) | 1 | `oyuncuTeklif - 1` |

- İlk turda (`turSayisi == 0`) sınır yok, oyuncu istediği yerden başlasın.
- `_okAktif()` mevcut kutu değerine bakar: `azalt ? val > min : val < max`.
- `_okAdim()` sınırın ötesine geçmez, `clamp` ile sınıra yapışır.
- Geçersizken "Teklif Ver" `onPressed: null` + soluk renk.
- `TextField`'a `onChanged: (_) => setState(...)` — yoksa elle yazınca ok ve
  buton durumları güncellenmiyor.

> ⚠️ İlk yazılışında ok'lar **yön bazlıydı** (`alıyorsa ▼ hep pasif`). O zaman
> oyuncu ▲ ile 273→303'e çıksa bile aşağı inemiyordu. Ok'lar mevcut değere
> göre hesaplanmalı: 303'te ▼ açık, 274'e inince kapanır.

### 👮 Polis alkol testi
`OzelMusteri.olustur(polis)` **%50 ihtimalle** ceza yerine matematik sorar:
*"Alkol var mı? Anlamak için sana soru soracağım. 8 x 4 kaç eder?"*

- `sikSol` / `sikSag` / `dogruCevap` alanları (null ise klasik cezalı polis)
- İşlem her seferinde üretilir: çarpma / toplama / çıkarma (sonuç hep pozitif)
- Yanlış şık doğruya yakın (±1..9), doğruyla aynı veya negatif olamaz
- Doğru şıkkın yeri **rastgele** — hep solda olsa ezberlenirdi
- Alt barda EVET/HAYIR yerine iki sayı butonu çıkar (`_alkolTestiCevapla`)
- Doğru → *"Tamam, iyisin. Ceza kesmekten vazgeçtim!"*, yanlış → 40-250 lira ceza

### 🍽️ "Yemeği Ye"
Kuryeden yemek alınınca `yemekVar = true` → alt barın **en altında** turuncu
buton belirir, diğer butonlar yukarı kayar. Basılınca `GameState.yemegiYe()`:
envanterdeki **tüm** çürük ürünler `curuk = false` olur, kondisyon 4-5'e çekilir,
`etkinFiyat` otomatik olarak tam piyasa fiyatına döner. Buton kaybolur.
`yemekVar` kayıtta saklanıyor.

### 🔨 Müşteriler artık hasarlı ürün de satıyor
Satıcı müşterinin malı **1/3 ihtimalle** hasarlı gelir (kolonya hariç).

> ⚠️ Toptancı hurdası ile müşteri malı **aynı çarpanı kullanmaz**.
> `GameItem.curukOran` (ürün başına, 0..1) eklendi:
> `etkinFiyat => curuk ? basePrice * (curukOran ?? curukCarpani) : basePrice`
> - toptancı / kapalı kutu / fare olayı → `curukCarpani` = **%35**
> - müşterinin getirdiği hasarlı mal → **%50-75** (rastgele)
>
> Böylece müşteri malı hurdadan değerli. `curukOran` `toJson`/`fromJson`'da var.

Envanterdeki çürük ürün satılırken piyasa fiyatı zaten `etkinFiyat` üzerinden
düşük görünüyor — ek koda gerek yok.

### 🚚 Toptancı Rıza
- **Browser menüsünden KALDIRILDI.** Alışveriş yalnız Rıza kapıya geldiğinde.
  Menüden istediği an açılabilmesi ziyaretini anlamsızlaştırıyordu.
- **Kolonya ikram edilirse GİTMEZ.** Diğer özel müşteriler ikramdan sonra
  gider; Rıza gitseydi tepsi hiç açılmadan kaybolurdu.
- Popup'ta **Kapat butonu scroll alanının dışında**, hep görünür. Eskiden
  listenin sonundaydı, stok uzun olunca aşağı kaydırmak gerekiyordu.

### 🚪 "Müşteri Çağır" kilidi
```dart
final musteriCagirAktif = !musteriKabulBekliyor && aktifPazarlik == null &&
    aktifMusteri == null && aktifOzelMusteri == null && !gunBitmeli;
```
Eskiden sadece `musteriKabulBekliyor`'a bakılıyordu. Toptancı tepsiyi kapatıp
çıkış animasyonu oynarken buton aktif kalıyor, basılınca **Rıza yeniden
geliyordu**. Aynı hata normal müşteri çıkarken de mümkündü.

### 🏆 Ana menüde rekor kazanç
`en_yuksek_para` SharedPreferences anahtarı — `KayitServisi.kaydet` her yazışta
günceller, yani oyun silinse de rekor kalır.

> Geriye dönük: anahtar yoksa `enYuksekParaYukle()` mevcut oyun kaydındaki
> `enYuksekPara` alanına düşer. Yoksa eski oyuncular rekorlarını ilk kayda
> kadar göremezdi.

### Test — `test/oynanis_test.dart`
9 test: alkol testi şıkları geçerli mi, doğru şık iki tarafa da düşüyor mu,
klasik polis hâlâ üretiliyor mu, `curukOran` fiyat etkisi, müşteri malı
hurdadan pahalı mı, `curukOran` kayıt turu, `yemegiYe` tüm çürükleri onarıyor
mu, hasarlı yokken çökmüyor mu, `yemekVar` kayıtta duruyor mu.

---

## 🔮 FALCI FALOYA (v104)

Yeni özel müşteri. Gelince *"Ben falcıyım, X liraya falına bakayım mı?"* der
(ücret 40-140 lira, selamlama metninde açıkça yazar — oyuncu ne ödeyeceğini bilir).

| Seçim | Ne olur |
|---|---|
| **EVET** | Ücret düşer → 50 fal metninden biri popup'ta çıkar → etki uygulanır |
| **HAYIR** | Küsüp gider, para gitmez |
| **Parası yetmiyorsa** | Ücret ALINMAZ, *"Cebinde o kadar yok evladım"* der ve gider |

> ⚠️ Hırsız/polis zorla para alır, **falcı almaz**. Fal isteğe bağlı bir
> harcama; oyuncuyu buradan iflasa sürüklemek adil değil.

### Model
```dart
enum FalEtki { yok, paraKazanc, paraKayip, dukkanBuyut, kolonyaHediye,
               tamirSeti, kapaliKutu, urunCuruk, kuryeSansi,
               vergiciGelecek, hirsizGelecek, polisGelecek,
               kuryeGelecek, toptanciGelecek }
class Fal { String metin; FalEtki etki; int min, max; }   // Fal.havuz = 50 metin
class FalSonuc { String? satir; int miktar; }             // satir null → sadece hikâye
GameState.falUygula(Fal) → FalSonuc
```

- `{X}` placeholder → gerçek tutarla doldurulur (`metniDoldur`). **Tek harf
  placeholder YASAK** — eski kural burada da geçerli.
- `falUygula` **`notifyListeners()` ÇAĞIRMAZ**; popup açıkken ekran zıplamasın
  diye bildirimi çağıran taraf tek seferde yapar.

### Etkiler ve emniyet kuralları
| Etki | Not |
|---|---|
| `paraKazanc` / `paraKayip` | Kayıp **parayı eksiye düşürmez** (`miktar` kasayla sınırlanır) |
| `dukkanBuyut` | Bir üst dükkana bedava geçiş. **Son seviyedeyse** patlamaz, 500 lira verir |
| `*Gelecek` (5 tip) | `zorunluOzelTip` alanını set eder → falcı gidince O müşteri gelir |
| `kapaliKutu` | Envanter doluysa kutu geri alınır, sessiz kaybolma yok |
| `urunCuruk` | Çürütecek sağlam ürün yoksa "kehanet boşa çıktı" der |

**Kehanet fallarında sonuç şeridi GÖSTERİLMEZ** (`satir == null`) — sürpriz
bozulmasın, vergici kapıyı kendisi çalsın.

### `zorunluOzelTip`
`GameState`'te public alan, `yeniMusteriGonder` başında tüketilir. Sayaç
beklemez, araya girer, rotasyonu bozmaz. `toJson`/`fromJson`'da saklanıyor —
fal bakıldıktan sonra oyun kapatılırsa kehanet kaybolmuyor.

> Eski kayıtlar: `fromJson`'daki mevcut migrasyon döngüsü `OzelMusteriTip.values`
> üzerinden gittiği için `falci` rotasyona **otomatik** ekleniyor, ek kod yok.

### Test — `test/fal_test.dart`
11 test: 50 metin benzersiz mi, placeholder kaldı mı, 2-3 cümle sınırı,
para aralıkları, her etki havuzda temsil ediliyor mu, para kaybı tabanı,
dükkan büyütme son seviye davranışı, kehanet eşleşmesi, ücret aralığı.

---

## 🏠 DÜKKANA GÖRE ARKA PLAN + KAPI SİLÜETİ (v104)

Her dükkan seviyesinin kendi arka planı var; kiralanınca sahne arkası
`AnimatedSwitcher` ile çapraz solarak değişir.

| Seviye | Arka plan | Görünüm |
|---|---|---|
| 1 | `bgbos.png` (719×1080) | ahşap, mütevazı |
| 2 | `bgbos_2.jpg` (719×1278) | terrazzo zemin, ahşap vitrin |
| 3 | `bgbos_3.jpg` | koyu + neon RGB |
| 4, 5 | `bgbos_4.jpg` | parlak beyaz, modern perakende |

> Elde **3 yeni görsel** vardı, 5 seviye → 4 ve 5 aynı mağazayı paylaşıyor.
> 5. seviye için ayrı görsel gelirse tek satır değiştirmek yeterli.

> ℹ️ Arka planlar **JPEG** (q92). Opak oldukları için alfa gereksiz; PNG'de
> 3 dosya 6.5MB tutuyordu, JPEG'de 0.84MB. APK 41.2 → 42.3MB.

### 🚪 Kapı silüeti artık dükkana göre konumlanıyor
**Eski hâli bozuluyordu:** `biri.png` tam ekran `BoxFit.cover` ile basılıyordu,
yani kapının yeri görsele gömülüydü. Farklı arka plan gelince silüet kapının
yanına düştü (en-boy oranı da farklı olduğu için `cover` kırpması değişiyor).

**Yeni hâli:** `biri.png`'in alfa kutusu kesilip `kapidaki.png` sprite'ı
yapıldı. `_buildKapidaki()` arka planın ekrandaki `cover` kutusunu hesaplayıp
sprite'ı o dükkanın kapı oranlarına yerleştiriyor:

```dart
// DukkanSeviye alanları
arkaplanOrani                            // en/boy — cover kutusu icin
kapiSol, kapiUst, kapiGen, kapiYuk       // KAPI CAMININ arka plan İÇİNDEKİ yeri (0..1)
```

Silüet bu kutuya `BoxFit.fill` ile gerilir → camı boşluksuz doldurur.

> ⚠️ **Yüksekliği sprite oranından türetme.** Bir ara `kapiYuk` kaldırılıp
> yükseklik `genislik / spriteOrani` ile hesaplandı; camlar sprite'tan daha
> uzun olduğu için altta gözle görülür boşluk kaldı. Cam dikdörtgeninin dört
> kenarı da elle verilmeli.

### Ölçüm kuralı: kutu = KAPI CAMI dikdörtgeni
Ölçülecek şey kapı çerçevesi değil, **camın kendisi** — dışarısının göründüğü
parlak alan.

**Yeni arka plan eklerken:**
1. Görseli TEK BAŞINA, büyük bir panele (≥900px) `%1`'lik ızgarayla bas.
2. Kapı **camının** sol / üst / genişlik / yükseklik oranını oku.
3. Bulduğun dikdörtgeni görselin üstüne ÇİZDİR ve bak — okuma hatası ancak
   böyle yakalanıyor.
4. Emülatörde dükkanı gerçekten kirala ve bak.

> ⚠️ **Kısayol yok, üç kez yanıldım:**
> - 4 görseli tek kontak sayfasında yan yana ölçtüm → panel başına 420px
>   düştü, okuma 0.06 hata verdi, silüetler kapının yanına düştü.
> - Parlaklık projeksiyonuyla otomatik ölçüm sv2/sv3'te camı tam yakaladı ama
>   **sv1'de açık ahşap çerçeveyi, sv4'te kapı üstündeki beyaz duvarı** cam
>   sandı. Otomatik ölçüme tek başına güvenme, mutlaka çizdirip doğrula.

| Seviye | kapiSol | kapiUst | kapiGen | kapiYuk |
|---|---|---|---|---|
| 1 | 0.3157 | 0.0880 | 0.1330 | 0.1593 |
| 2 | 0.3380 | 0.1228 | 0.1224 | 0.1667 |
| 3 | 0.3588 | 0.1385 | 0.1113 | 0.1541 |
| 4, 5 | 0.3350 | 0.1517 | 0.1160 | 0.1582 |

Dördü de emülatörde tek tek açılıp doğrulandı.

> ⚠️ Sabit piksel YOK — sahne metriği felsefesiyle aynı: her şey arka planın
> ekrandaki kutusuna oranla veriliyor, çözünürlük/en-boy değişse de kaymıyor.

### 🪤 TUZAK: AnimatedSwitcher çocuğu ekranı KAPLAMAZ
Arka plana çapraz solma eklerken silüet kapının soluna kaydı. Sebep:

```dart
// AnimatedSwitcher'in VARSAYILAN layoutBuilder'i:
Stack(alignment: Alignment.center, children: [...])   // fit: StackFit.LOOSE
```

`Positioned.fill` dıştaki AnimatedSwitcher'a **tight** kısıt verir ama içteki
Stack loose olduğu için `Image` kendi doğal boyutuna küçülür → arka plan ekranı
kaplamaz, uzaklaşmış gibi görünür. Kapı silüeti tam ekran kutuya göre
konumlandığı için ikisi ayrışır.

**Çözüm** — layoutBuilder'ı `StackFit.expand` ile ez:
```dart
AnimatedSwitcher(
  layoutBuilder: (current, previous) => Stack(
    fit: StackFit.expand, alignment: Alignment.center,
    children: [...previous, if (current != null) current],
  ),
  child: Image.asset(..., fit: BoxFit.cover),
)
```

> Masa katmanındaki AnimatedSwitcher bu tuzağa düşmüyor çünkü çocukları zaten
> `Align`+`Transform` ile sarılı — oraya DOKUNMA.

---

## 🎂 YAŞ / CİNSİYET DUYARLI REPLİK SİSTEMİ (v103) — TAMAMLANDI

### Çözülen sorun
Replikler yaşa/cinsiyete bakmadan seçiliyordu: *"Anneme sormadan CD satmaya
geldim"* repliği 75 yaşındaki ak sakallı amcaya denk gelebiliyordu. Artık her
karakterin kuşağı var ve replikler ona göre filtreleniyor.

### Model — 3 parça
```dart
enum YasGrubu { cocuk, genc, yetiskin, yasli }     // sayısal yaş YOK, kuşak yeterli
class Replik { String metin; List<YasGrubu>? yas; String? cinsiyet; }
String replikSec(havuz, yas, cinsiyet)             // filtrele → seç
```
- `yas == null` → her yaşa uyar, `cinsiyet == null` → her cinsiyete uyar.
  Böylece **eski düz satırlar hiç etiketlenmeden nötr havuzda kaldı** — hiçbir
  replik kaybolmadı.
- Kısayol sabitler: `kYasGenc` (cocuk+genc), `kYasBuyuk` (yetiskin+yasli),
  `kYasYetiskin` (genc+yetiskin).

### Güvenlik zinciri (ÖNEMLİ)
`replikSec` asla boş dönmez: **uyan replik → yoksa nötrler → o da yoksa tüm havuz.**
Filtre ne kadar dar yazılırsa yazılsın oyun boş balon göstermez.

### Dokunulan yerler
| Yer | Ne oldu |
|---|---|
| `GameState.musteriHavuzu` | her satıra `'yas'` alanı |
| `Customer` | `yas` + `cinsiyet` alanları, `selamMesaji` filtreli |
| `GameState.yeniMusteriGonder` | yaş/cinsiyeti `Customer`'a geçirir |
| `PazarlikSeans` | `yas`/`cinsiyet` alanları + `_sec()` yardımcısı |
| Tüm replik havuzları | `List<String>` → `List<Replik>` |

`PazarlikSeans.yas`/`cinsiyet` **varsayılanlı** (yetiskin/'E') — özel müşteride
pazarlık yok, oradan gelen çağrılar bozulmasın diye.

### Genişletilen havuzlar (v99'un üstüne)
| Havuz | Önce | Sonra |
|---|---|---|
| `_saticiSelam` / `_aliciSelam` | 20 / 20 | 39 / 39 |
| `_saticiKarsiTeklif` / `_aliciKarsiTeklif` | 25 / 25 | 48 / 46 |
| `_kabulSablonlari` | 26 | 42 |
| `_gitOfkeli` / `_gitTurBitti` / `_gitErken` | 18 / 18 / 12 | 27 / 26 / 19 |
| `_kolonyaSelam` | 5 | 9 |
| `_tepki*` + `_sonTeklifMesajlari` + `_kaprisliKabul` + `_jestKabul` | — | hepsine yaş satırı |

Her yaş+cinsiyet+rol kombinasyonunda **en az 20 farklı selamlama** üretilebiliyor
(test bunu doğruluyor).

### Regresyon testi — `test/yas_replik_test.dart`
6 test. Kritik olanlar:
- çocuk/genç lafları ("Anneme sormadan", "harçlığımı biriktirdim", "Kumbaramı")
  yetişkin/yaşlıya **düşmüyor**
- yaşlı lafları ("Torunum", "Emekli", "Çocukluğumdan beri") çocuk/gence **düşmüyor**
- cinsiyet etiketli replikler karşı cinse düşmüyor
- `{AD}`/`{URUN}` placeholder'ları **tamamen doldurulmuş** (tuzak testi)
- `replikSec` boş dönmüyor

```bash
C:\src\flutter\bin\flutter.bat test test/yas_replik_test.dart
```

> ⚠️ `test/widget_test.dart` **eskiden beri kırık** (splash ekranı yüzünden
> "OYUNCU DÜKKANI" metnini hemen bulamıyor). Yaş sistemiyle ilgisi yok.

### Yeni replik yazarken
- **Tek harf placeholder YASAK**: `{AD}` / `{URUN}` kullan. `replaceAll('A', ...)`
  "**A**rkadaşlar"ı bozar. Fiyat için `X` güvenli (Türkçede büyük X geçen kelime yok).
- Rol ayrımını koru: malı **satan** müşteri "o para bu malı almaz", **alan**
  müşteri "o kadar para vermem" der.
- Etiketlemekte kararsızsan **etiketleme** — nötr satır her yaşa gider, zararsız.

---

## ğŸ”Š SES SÄ°STEMÄ° (v101)

### Dosya ekleme â€” pubspec'e DOKUNMA
`pubspec.yaml` klasÃ¶rÃ¼ toptan listeliyor: `- assets/sounds/`
Yani **klasÃ¶re atÄ±lan her dosya otomatik pakete girer**, tek tek eklemek gerekmez.
`SesServisi._cal` try/catch'li â†’ **dosya yoksa sessizce geÃ§er, Ã§Ã¶kmez.**
Bu sayede tÃ¼m tetikleyiciler Ã¶nceden baÄŸlandÄ±; dosyalar sonradan doldurulabilir.

### Beklenen dosyalar (`assets/sounds/`)
| Dosya | Tetikleyici | Durum |
|---|---|---|
| `kapi.mp3` | mÃ¼ÅŸteri geldi | âœ… var |
| `paragirdi.mp3` | para deÄŸiÅŸti | âœ… var |
| `anlasma.mp3` | pazarlÄ±k anlaÅŸmayla bitti | â¬œ |
| `basarisiz.mp3` | mÃ¼ÅŸteri kÄ±zÄ±p gitti | â¬œ |
| `rozet.mp3` | rozet kazanÄ±ldÄ± | â¬œ |
| `seri.mp3` | kombo bonusu | â¬œ |
| `hedef.mp3` | gÃ¼nlÃ¼k hedef tamam | â¬œ |
| `kutu.mp3` | kapalÄ± kutu aÃ§Ä±ldÄ± | â¬œ |
| `tamir.mp3` | Ã§Ã¼rÃ¼k Ã¼rÃ¼n tamir edildi | â¬œ |
| `gunsonu.mp3` | gÃ¼n bitti | â¬œ |
| `hata.mp3` | yetersiz para / envanter dolu | â¬œ |
| `envanter.mp3` | envanter aÃ§Ä±ldÄ± | â¬œ |
| `tik.mp3` | genel buton (seyrek kullanÄ±lÄ±yor) | â¬œ |

### Dokunsal geri bildirim (haptik) â€” ses dosyasÄ± gerektirmez
`import 'package:flutter/services.dart' show HapticFeedback;` **aÃ§Ä±kÃ§a gerekli** â€”
`material.dart` bunu re-export etmiyor, eklemezsen `undefined_identifier` hatasÄ± alÄ±rsÄ±n.

Her ses metodu uygun titreÅŸimle eÅŸleÅŸtirildi: anlaÅŸmaâ†’medium, rozetâ†’heavy,
hataâ†’heavy, kapÄ±/seri/tamirâ†’light, envanter/tÄ±kâ†’selectionClick.
`sesAcik` kapalÄ±ysa titreÅŸim de kapanÄ±r (tek ayar, tek beklenti).

### Ãœcretsiz ses kaynaklarÄ±
`freesound.org` (CC0 filtresi) Â· `pixabay.com/sound-effects` Â· `opengameart.org` Â·
`kenney.nl/assets` (oyun UI ses paketleri, tamamen CC0)

> Arka plan mÃ¼ziÄŸi henÃ¼z YOK. Eklenirse ayrÄ± bir `muzikAcik` ayarÄ± ve
> `ReleaseMode.loop`'lu kalÄ±cÄ± bir AudioPlayer gerekir â€” SFX'ten ayrÄ± toggle ÅŸart.

---

## ğŸ¤ PAZARLIK MOTORU â€” Hamle Okuma (v100)

Eskiden motor oyuncunun **ne yaptÄ±ÄŸÄ±nÄ±** okumuyordu: 500'den 900'e Ã§Ä±ksan da,
500'de Ä±srar etsen de, hatta geri gitsen de mÃ¼ÅŸteri aynÄ± tepkiyi veriyordu.
ArtÄ±k her turda hamle sÄ±nÄ±flandÄ±rÄ±lÄ±p ona gÃ¶re davranÄ±lÄ±yor.

### `enum Hamle { geri, ayni, kucuk, orta, buyuk }`
`hamleOran = (bu tur verilen taviz) / piyasaFiyati`

| Hamle | EÅŸik | MÃ¼ÅŸterinin tepkisi |
|---|---|---|
| `geri` | < âˆ’0.5% | **FiyatÄ±nÄ± KIRMAZ**, frustration +0.30, %22-50 Ã§ekip gider, kÄ±zgÄ±n replik |
| `ayni` | Â±0.5% | frustration +0.14, konsesyon Ã—0.25, "inatÃ§Ä±sÄ±n" repliÄŸi |
| `kucuk` | < 5% | normal |
| `orta` | < 14% | normal |
| `buyuk` | â‰¥ 14% | frustration âˆ’0.10, **%35-55 anÄ±nda kabul** (teklif yakÄ±nsa), takdir repliÄŸi |

### DÃ¶rt yeni davranÄ±ÅŸ

**1. Kaprisli evet (%5)** â€” MantÄ±ken kabul etmemesi gereken teklifi kabul eder.
SÄ±nÄ±rlÄ±: rezervasyonu en fazla %25 aÅŸan teklifler. *"Ya boÅŸver, kafam iyi bugÃ¼n. Kabul!"*
AmaÃ§: unutulmaz "vay be" anlarÄ±.

**2. Bir kez daha sÄ±kÄ±ÅŸtÄ±rma (%30)** â€” Teklif kabul edilebilir olsa bile pazarcÄ± refleksiyle
"az daha gayret" der, orta noktaya Ã§ekilir. **AnlaÅŸmayÄ± kaybettirmez:** oyuncu aynÄ± teklifi
tekrarlarsa kabul edilir (`_sikistirmaKullanildi` bir kez). Tur limiti gÃ¼venliÄŸi:
sadece `turSayisi <= maxTur - 2` iken. SabÄ±rsÄ±z mÃ¼ÅŸteride (maxTur=2) hiÃ§ tetiklenmez.

**3. Son teklif uyarÄ±sÄ±** â€” `turSayisi >= maxTur - 1` olunca aÃ§Ä±kÃ§a
*"SON TEKLÄ°FÄ°M: X. Ya alÄ±rsÄ±n ya kÃ¼serim."* der. Oyuncu son ÅŸansÄ± bilir, pazarlÄ±ÄŸa doruk katar.

**4. BÃ¼yÃ¼k jest kabulÃ¼** â€” Ciddi bir sÄ±Ã§rama yapÄ±ldÄ±ysa ve teklif ulaÅŸÄ±labilirse
(`rezervAsim < 0.10`) jesti onurlandÄ±rÄ±p kabul eder.

### Tepki replik havuzlarÄ± (`PazarlikSeans`)
`_tepkiGeri` (8) Â· `_tepkiAyni` (7) Â· `_tepkiBuyuk` (8) Â· `_tepkiSikistirma` (6) Â·
`_sonTeklifMesajlari` (6) Â· `_kaprisliKabul` (10) Â· `_jestKabul` (6)

> âš ï¸ SÄ±kÄ±ÅŸtÄ±rma clamp'i yÃ¶n duyarlÄ±dÄ±r: satÄ±cÄ± mÃ¼ÅŸteride `clamp(oyuncuTeklif+1, musteriTeklif)`,
> alÄ±cÄ± mÃ¼ÅŸteride `clamp(musteriTeklif, oyuncuTeklif-1)`. Ters Ã§evirme, clamp hatasÄ± verir.

---

## ğŸ’¬ DÄ°YALOG HAVUZLARI (v99)

TÃ¼m replikler geniÅŸletildi. Tekrar hissi kalmasÄ±n diye her havuz 18-26 satÄ±r.

| Havuz | SÄ±nÄ±f | Not |
|---|---|---|
| `_saticiSelam` / `_aliciSelam` | `Customer` | 20'ÅŸer selamlama, rol ayrÄ± |
| `_kolonyaSelam` | `Customer` | 5 kolonyacÄ± repliÄŸi |
| `_saticiKarsiTeklif` / `_aliciKarsiTeklif` | `PazarlikSeans` | 25'er karÅŸÄ± teklif, **rol ayrÄ±** |
| `_kabulSablonlari` | `PazarlikSeans` | 26 kabul repliÄŸi |
| `_gitOfkeli` / `_gitTurBitti` / `_gitErken` | `PazarlikSeans` | 18 / 18 / 12 â€” ruh haline gÃ¶re |

### âš ï¸ PLACEHOLDER KURALI â€” TEK HARF KULLANMA
Åablonlarda `{AD}` ve `{URUN}` kullanÄ±lÄ±r. **Tek harfli placeholder (A, U) ASLA kullanma** â€”
`replaceAll('A', ...)` "**A**rkadaÅŸlar" kelimesindeki bÃ¼yÃ¼k A'yÄ± da deÄŸiÅŸtirir ve cÃ¼mleyi bozar.
Fiyat iÃ§in `X` gÃ¼venli (TÃ¼rkÃ§e'de bÃ¼yÃ¼k X geÃ§en kelime yok) ama yeni ÅŸablon yazarken kontrol et.

### Rol ayrÄ±mÄ± neden Ã¶nemli
MalÄ± **satan** mÃ¼ÅŸteri "o para bu malÄ± almaz" der, **alan** mÃ¼ÅŸteri "o kadar para vermem" der.
AynÄ± cÃ¼mleyi ikisine de sÃ¶yletmek karakteri bozuyordu.

---

## âœ¨ TOAST BÄ°LDÄ°RÄ°MÄ° (v99)

Seri ve gÃ¼nlÃ¼k hedef bildirimleri Material SnackBar deÄŸil, oyunun kendi temasÄ±nda
Ã¶zel bir kart. `_toastGoster(metin, altYazi:, emoji:, renk:)`.

- Ana `Stack`'in en Ã¼stÃ¼nde `_buildToast()` olarak render edilir
- `TweenAnimationBuilder` + `Curves.elasticOut` â†’ aÅŸaÄŸÄ±dan sÃ¼zÃ¼lÃ¼p hafif zÄ±plar
- Koyu gradient zemin (#241a10â†’#120c06), 2px renkli Ã§erÃ§eve, renkli glow gÃ¶lge
- BaÅŸlÄ±k accent renkte, alt yazÄ± beyaz â€” ikisinde de siyah text shadow (okunabilirlik)
- `_toastId` her gÃ¶sterimde artar â†’ animasyon baÅŸtan baÅŸlar
- 2.4 sn sonra otomatik kaybolur, `IgnorePointer` ile dokunuÅŸu engellemez

> Material SnackBar kullanma â€” kahverengi zemin/okunmayan yazÄ± sorunu bu yÃ¼zden Ã§Ä±kmÄ±ÅŸtÄ±.

---

## ğŸ£ BAÄLILIK MEKANÄ°KLERÄ° (v98)

DÃ¶rt farklÄ± zaman Ã¶lÃ§eÄŸinde tutundurma. Birbirini besleyecek ÅŸekilde tasarlandÄ±.

| Ã–lÃ§ek | Mekanik | Alan / SÄ±nÄ±f |
|---|---|---|
| **An** | ğŸ”¥ Seri (kombo) | `kombo`, `enUzunSeri`, `sonKomboBonusu` |
| **GÃ¼n** | ğŸ¯ GÃ¼nlÃ¼k hedef | `GunlukHedef`, `gunlukHedef` |
| **Sonraki gÃ¼n** | â˜€ï¸ YarÄ±nÄ±n Ã¶nizlemesi | `yarinkiOlayId` |
| **Uzun vade** | ğŸ“š Koleksiyon | `satilanUrunIdleri` + `koleksiyonUrunleri` |

### ğŸ”¥ Seri (kombo)
- Ãœst Ã¼ste **anlaÅŸmayla biten** pazarlÄ±k sayÄ±sÄ±. 3'ten itibaren her anlaÅŸmada `kombo Ã— 15` lira bonus.
- **SÄ±fÄ±rlanma:** sadece mÃ¼ÅŸteri kÄ±zÄ±p giderse (`PazarlikDurum.gitti`).
  Oyuncunun kendi reddi seriyi BOZMAZ â€” kÃ¶tÃ¼ teklifi reddetmek meÅŸru strateji, cezalandÄ±rÄ±lmamalÄ±.
- GÃ¼nler arasÄ± devam eder (seri deÄŸerli hissettirsin).
- Bildirim: SnackBar (popup deÄŸil, akÄ±ÅŸÄ± kesmesin).

### ğŸ¯ GÃ¼nlÃ¼k hedef
`GunlukHedef.uret(dukkanSeviye)` her gÃ¼n baÅŸÄ±nda Ã¼retir. 6 tip:
`satisAdedi`, `gelir`, `tamir`, `kutu`, `toptanciAlim`, `tekSatis`
- Hedef bÃ¼yÃ¼klÃ¼ÄŸÃ¼ dÃ¼kkan seviyesiyle Ã¶lÃ§eklenir
- Ä°lerleme `_hedefIlerlet(tip, miktar)` ile ilgili noktalardan beslenir
  (`_anlasmayiTamamla`, `tamirEt`, `kutuAc`, `toptanciSatinAl`)
- `tekSatis` iÃ§in `mutlak: true` â†’ en yÃ¼ksek tek satÄ±ÅŸ tutulur
- TamamlanÄ±nca anÄ±nda Ã¶dÃ¼l + SnackBar; gÃ¼n sonu popup'Ä±nda sonuÃ§ gÃ¶sterilir

### â˜€ï¸ YarÄ±nÄ±n Ã¶nizlemesi â€” "bir gÃ¼n daha" kancasÄ±
Olaylar artÄ±k **bir gÃ¼n Ã¶nceden** belirlenir:
```
gunuBitir(): gunlukOlayId = yarinkiOlayId   (dÃ¼n belirlenen olay bugÃ¼n uygulanÄ±r)
             yarinkiOlayId = yeni zar        (gÃ¼n sonu popup'Ä±nda duyurulur)
```
- GÃ¼n sonu popup'Ä±nda "YARIN" bÃ¶lÃ¼mÃ¼: emoji, baÅŸlÄ±k, aÃ§Ä±klama + etki Ã§ipleri
- **Sabah olay popup'Ä± KALDIRILDI** â€” Ã§ift bildirim olmasÄ±n, popup yorgunluÄŸu yaratmasÄ±n
- Aktif olay Hedefler ekranÄ±ndaki "bugÃ¼n paneli"nde gÃ¶rÃ¼nÃ¼r

### ğŸ“š Koleksiyon
- Hedefler ekranÄ±nÄ±n altÄ±nda 23 Ã¼rÃ¼nlÃ¼k Ä±zgara (kolonya hariÃ§)
- SatÄ±lan Ã¼rÃ¼n aÃ§Ä±lÄ±r (gerÃ§ek gÃ¶rsel), satÄ±lmayan "?" gÃ¶rÃ¼nÃ¼r
- YÃ¼zde gÃ¶stergesi; `satilanUrunIdleri` zaten takip ediliyordu, ek maliyet yok

### Hedefler ekranÄ± yapÄ±sÄ±
`ListView` â†’ `[bugÃ¼n paneli] + [8 rozet] + [koleksiyon paneli]`
- **BugÃ¼n paneli:** gÃ¼n no, aktif seri, gÃ¼nlÃ¼k hedef + ilerleme Ã§ubuÄŸu, aktif olay + etki Ã§ipleri

---

## ğŸ¯ SAHNE METRÄ°ÄÄ° â€” Ã‡Ã¶zÃ¼nÃ¼rlÃ¼kten BaÄŸÄ±msÄ±z KonumlandÄ±rma (v97)

**ArtÄ±k sahnede SABÄ°T PÄ°KSEL DEÄERÄ° YOK.** ÃœrÃ¼n, isim etiketi ve mÃ¼ÅŸteri, masa
gÃ¶rselinin ekrandaki kutusuna kilitlidir. Her Ã§Ã¶zÃ¼nÃ¼rlÃ¼k/en-boy oranÄ±nda masa
nereye giderse onlar da oraya gider.

### Neden gerekti
Eskiden masa gÃ¶rseli ekran **geniÅŸliÄŸine** gÃ¶re Ã¶lÃ§ekleniyordu (`fitWidth` + `scale 1.4`),
Ã¼rÃ¼n ise ekran **yÃ¼ksekliÄŸine** gÃ¶re konumlanÄ±yordu (`screenH * 0.57 + sabit`). En-boy
oranÄ± deÄŸiÅŸince ikisi ayrÄ±ÅŸÄ±yordu â†’ her cihazda elle ayar â†’ sonsuz yama dÃ¶ngÃ¼sÃ¼.

### NasÄ±l Ã§alÄ±ÅŸÄ±yor
`SahneMetrik` sÄ±nÄ±fÄ±, masa gÃ¶rselinin render zincirini birebir modelleyip ekrandaki
kutusunu (Ã¼st kenar + yÃ¼kseklik) hesaplar:
```
Align(bottomCenter) â†’ translate(0, 6) â†’ scale(1.4, bottomCenter) â†’ fitWidth
```
Konumlar gÃ¶rselin iÃ§indeki **0..1 oranlarÄ±yla** ifade edilir:

| Sabit | DeÄŸer | AnlamÄ± |
|---|---|---|
| `kMasaYuzeyi` | 0.4833 | Masa arka kenarÄ± â€” **sanat eserinden Ã¶lÃ§Ã¼ldÃ¼** (bg1.png y=522/1080) |
| `kUrunTabani` | 0.5680 | ÃœrÃ¼nÃ¼n oturduÄŸu Ã§izgi (mousepad/klavye derinliÄŸi) |
| `kUrunBoyu` | 0.1745 | ÃœrÃ¼n yÃ¼ksekliÄŸi (masa boyuna oranla) |
| `kUrunSagKaydir` | 0.3537 | ÃœrÃ¼nÃ¼n mÃ¼ÅŸteriye gÃ¶re yatay kaymasÄ± |
| `kIsimAlti` | 0.4920 | Ä°sim etiketi alt kenarÄ± (masa Ã§izgisinin hemen altÄ±) |
| `kMusteriUstu` | 0.2183 | MÃ¼ÅŸteri gÃ¶rseli Ã¼st kenarÄ± |
| `kMusteriBoyu` | 0.6519 | MÃ¼ÅŸteri gÃ¶rseli boyu |

KullanÄ±m: `m.y(oran)` â†’ ekranda mutlak y, `m.u(oran)` â†’ dp uzunluk (boyutlar da Ã¶lÃ§eklenir).

> `_buildSahne()` iÃ§indeki konumlar yerel koordinatta olduÄŸu iÃ§in
> `ofs = mq.padding.top + 48.0` Ã§Ä±karÄ±lÄ±r.

### Masa gÃ¶rselleri (Ã¼Ã§Ã¼ de aynÄ± â€” doÄŸrulandÄ±)
`bgbosmasa.png` / `bg1.png` / `bg2.png` â†’ hepsi **719Ã—1080**, masa kenarÄ± y=522/523.
Bilgisayar alÄ±nÄ±nca veya dÃ¼kkan deÄŸiÅŸince Ã¼rÃ¼n kaymaz.

### Test edildi (gerÃ§ek cihaz Ã¶lÃ§Ã¼mÃ¼yle)
| Ã‡Ã¶zÃ¼nÃ¼rlÃ¼k | Oran | SonuÃ§ |
|---|---|---|
| 1080Ã—2400 | 20:9 | âœ… Ã¼rÃ¼n mousepad hizasÄ±nda, isim masada |
| 1080Ã—1920 | 16:9 | âœ… birebir aynÄ± baÄŸÄ±l konum |
| 1200Ã—1600 | 4:3 | âœ… birebir aynÄ± baÄŸÄ±l konum |

**Yeni bir konum ayarlamak gerekirse:** sabit px ekleme â€” yukarÄ±daki oran sabitlerini
deÄŸiÅŸtir. Ã–lÃ§Ã¼m iÃ§in: `adb shell screencap` ile ekran gÃ¶rÃ¼ntÃ¼sÃ¼ al, masa kenarÄ±nÄ± bul,
`(hedefY - m.ust) / m.boy` ile oranÄ± hesapla.

---

## âš ï¸ GÃ¶rsel Katman Sistemi (Z-order)

### Stack Z-order (arkadan Ã¶ne) â€” GameScreen build()

| # | Widget | AÃ§Ä±klama |
|---|--------|----------|
| 1 | `bgbos.png` | Sabit dÃ¼kkan arkaplanÄ± (Positioned.fill) |
| 2 | `biri.png` | KapÄ± gÃ¶lgesi â€” mÃ¼ÅŸteri yokken AnimatedOpacity ile gÃ¶rÃ¼nÃ¼r |
| 3 | **MÃœÅTERÄ° gÃ¶rseli** | MasanÄ±n ALTINDA â€” bu katmanda olmalÄ±! |
| 4 | **Masa layer** | AnimatedSwitcher: bgbosmasa/bg1/bg2, scale:1.4 bottomCenter |
| 5 | **SafeArea** | header + `_buildSahne()` + altbar |
| 6 | DÃ¼kkan butonu | gun >= 3'te sol altta gÃ¶rÃ¼nÃ¼r |

---

### MÃœÅTERÄ° BOYUTU VE KONUMU (Outer Stack â€” katman 3)

```
width:  564 px  â† DOKUNMA!
height: 564 px  â† DOKUNMA!

hedef     = (screenW - 564) / 2
dx        = hedef + (screenW - hedef) * slideAnim.value   â† saÄŸdan giriÅŸ
musteriTop = statusBar + 48.0 + screenH * 0.14 + 44
              â””â”€ statusBar = mq.padding.top
              â””â”€ 48.0      = header yÃ¼ksekliÄŸi
              â””â”€ 0.14      = ekranÄ±n %14'Ã¼
              â””â”€ 44        = ince ayar â† DOKUNMA! (SON DEÄER)
```

---

### _buildSahne() â€” MÃœÅTERÄ° PLACEHOLDER

`_buildSahne()` Stack'indeki mÃ¼ÅŸteri widget'Ä± gerÃ§ek gÃ¶rseli deÄŸil, Z-order'Ä± korumak iÃ§in **boÅŸ 564Ã—564 SizedBox** iÃ§erir. GerÃ§ek gÃ¶rsel dÄ±ÅŸ Stack katman 3'tedir.

```
hedef     = (screenW - 564) / 2
dx        = hedef + (screenW - hedef) * slideAnim.value
musteriTop = screenH * 0.14 + 44   â† SafeArea iÃ§i (statusBar yok)
              â””â”€ 44 = ince ayar â† DOKUNMA! (SON DEÄER)
```

---

### Ä°SÄ°M ETÄ°KETÄ° KONUMU

Normal mÃ¼ÅŸteri (Stack iÃ§i Positioned):
```dart
Positioned(
  bottom: 338,   // â† SON DEÄER (306â†’318â†’328â†’338, toplam 32px yukarÄ± Ã§ekildi)
  left: 0, right: 0,
  child: Center(child: ...isim container...),
)
```

Ã–zel mÃ¼ÅŸteri â€” `_buildOzelMusteriWidget()` iÃ§inde **AYNI** yapÄ±:
```dart
Positioned(
  bottom: 338,   // â† SON DEÄER, normal mÃ¼ÅŸteriyle eÅŸleÅŸmeli
  left: 0, right: 0,
  child: Center(child: ...isim container...),
)
```

> **Neden left:0/right:0 + Center?** dx negatif deÄŸer alabilir (geniÅŸ mÃ¼ÅŸteri gÃ¶rseli ekrandan taÅŸar). EÄŸer Stack iÃ§inde dx'e gÃ¶re Positioned konulsaydÄ± isim ekran dÄ±ÅŸÄ±na Ã§Ä±kardÄ±.

---

### ÃœRÃœN KONUMU (_buildSahne iÃ§i AnimatedBuilder)

GÃ¶sterilme koÅŸulu (alÄ±cÄ± mÃ¼ÅŸteri Ã¼rÃ¼n almak istediÄŸinde **deÄŸil**, satÄ±cÄ± veya kurye iken):
```dart
if (_state.aktifMusteri != null && _state.aktifMusteri!.musteriSatiyor ||
    _state.aktifOzelMusteri?.tip == OzelMusteriTip.kurye)
```

**GÃ¶rsel seÃ§imi:**
- Kurye ise `assets/durum.png` (dÃ¼rÃ¼m/yemek)
- Normal satÄ±cÄ± ise `_state.aktifMusteri!.item.gorsel`

**Boyut:**
```
Standart Ã¼rÃ¼nler              : productSize = 151.0 px
konsol_3/4/5/6.png + joypad   : productSize = 151.0 * 0.85 â‰ˆ 128px  (%15 kÃ¼Ã§Ã¼k)
oyuncudireksiyonu.png         : productSize = 151.0 * 0.85 â‰ˆ 128px  (%15 kÃ¼Ã§Ã¼k)
durum.png (kurye)             : productSize = 151.0 * 0.80 â‰ˆ 121px  (%20 kÃ¼Ã§Ã¼k)
```

**Yatay (productLeft):**
```
TÃ¼m Ã¼rÃ¼nler           : dx + 306
oyuncudireksiyonu.png : dx + 313 (+7 saÄŸa)
konsol_2.png          : dx + 311 (+5 saÄŸa)
konsol_3.png          : dx + 311 (+5 saÄŸa)
```

**Dikey (productTop):**
```
screenH * 0.57 - productSize - st - hh - 20
  â””â”€ 0.57       = Ã¼rÃ¼n ALT kenarÄ± ekranÄ±n %57'sinde (masa yÃ¼zeyi hizasÄ±)
  â””â”€ productSize = 151 / 128 / 121 (Ã¼rÃ¼ne gÃ¶re)
  â””â”€ st         = viewPadding.top (status bar)
  â””â”€ hh         = 48.0 (header yÃ¼ksekliÄŸi)
  â””â”€ -20        = ince ayar â† SON DEÄER (+32â†’+20â†’0â†’-20, toplam 52px yukarÄ± Ã§ekildi)
```

> Koordinatlar `_buildSahne()` Stack'ine gÃ¶reli â€” SafeArea iÃ§inde, header altÄ±nda baÅŸlar.

---

### KONUÅMA BALONU (mesaj kutusu)

```dart
Positioned(top: 6, left: 6, right: 6)   // â† dÄ±ÅŸ kenar boÅŸluklarÄ± (SON DEÄER)
Container(padding: EdgeInsets.all(6))    // â† iÃ§ dolgu (SON DEÄER)
```

**MÃ¼ÅŸteri SATICI ise** (`musteriSatiyor == true`):
```
â†’ Sadece TypewriterText (metin, renkli border)
```

**MÃ¼ÅŸteri ALICI ise** (`musteriSatiyor == false`):
```
â†’ Row layout:
   Sol : Image.asset(item.gorsel, width:100, height:100)  â† Ã¼rÃ¼n gÃ¶rseli
   Ara : SizedBox(width: 8)
   SaÄŸ : Expanded
           â””â”€ Transform.translate(offset: Offset(-15, 0))  â† -15px sola â† DOKUNMA!
                â””â”€ Center
                     â””â”€ TypewriterText(textAlign: center)
```

---

## ğŸ†• ToptancÄ± / Ã‡Ã¼rÃ¼k-Tamir / KapalÄ± Kutu / Hedefler / GÃ¼n OlaylarÄ± (v97)

DÃ¶rt yeni sistem eklendi. **Hepsi mevcut mekanikleri KÄ°LÄ°TLEMEZ, sadece ekler** â€” bu bilinÃ§li bir tasarÄ±m kararÄ± (eski akÄ±ÅŸ hiÃ§ bozulmadÄ±).

### EriÅŸim noktasÄ±
Hepsi **browser popup'Ä±** (`_browserPopup`, ğŸ–¥ï¸ butonu, `gun >= 2`) Ã¼zerinden. Alt bara hiÃ§ dokunulmadÄ± â†’ layout riski sÄ±fÄ±r.
```
🖥️ Browser → 🏠 Kiralık Dükkanlar / 🏦 Banka / 🏆 Hedefler / 🛒 Market / ⚙️ Ayarlar
(Toptancı Rıza v105'te menüden ÇIKARILDI — sadece kapıya geldiğinde alışveriş)
```

### 1. Ã‡Ã¼rÃ¼k Ã¼rÃ¼n (`GameItem.curuk`)
- `etkinFiyat` getter: `curuk ? basePrice * 0.35 : basePrice`
- **TÃ¼m pazarlÄ±k hesaplarÄ± `etkinFiyat` kullanÄ±r** (`basePrice` DEÄÄ°L): `yeniMusteriGonder`, `musteriKabul`, `PazarlikSeans.piyasaFiyati`, envanter kartÄ±, pazarlÄ±k dialogu
- KaynaklarÄ±: toptancÄ±, kapalÄ± kutu, fare olayÄ±. **MÃ¼ÅŸteriler Ã§Ã¼rÃ¼k Ã¼rÃ¼n satmaz** (mesaj tutarlÄ±lÄ±ÄŸÄ± iÃ§in bilinÃ§li)
- Envanterde: kÄ±rmÄ±zÄ± Ã§erÃ§eve + `Ã‡ÃœRÃœK` rozeti + %50 opaklÄ±k, tÄ±klanÄ±nca tamir popup'Ä±

### 2. Tamir Seti (`tamirSetiAdet`)
- KolonyanÄ±n **birebir aynÄ± deseni**: slot iÅŸgal etmez, sayaÃ§, envanterde ek kart
- ToptancÄ±dan 450'ye alÄ±nÄ±r â†’ **5 kullanÄ±m** (â‰ˆ90/kullanÄ±m)
- `tamirEt(slotIndex)`: `curuk=false`, kondisyon 4-5 rastgele
- Ekonomi: pahalÄ± Ã¼rÃ¼nÃ¼ tamir kÃ¢rlÄ± (2.3-3.2x), ucuz CD'yi tamir zararlÄ± â€” **kasÄ±tlÄ± karar noktasÄ±**

### 3. KapalÄ± Kutu (`GameItem.kapaliKutu`)
- `GameState.kapaliKutuUret()` â€” gÃ¶rseli `assets/zarf.png`, slot iÅŸgal EDER
- ToptancÄ±dan 300'e, envanterde tÄ±kla â†’ onay â†’ `kutuAc()` â†’ aynÄ± slota rastgele Ã¼rÃ¼n
- %25 Ã§Ã¼rÃ¼k Ã§Ä±kma ÅŸansÄ± (kutu_avcisi rozetiyle %12.5)
- **AlÄ±cÄ± mÃ¼ÅŸteriler aÃ§Ä±lmamÄ±ÅŸ kutuyu isteyemez** (`!u.kapaliKutu` filtresi) â€” kilitlenme yok, kutu aÃ§mak bedava

### 4. ToptancÄ± (`ToptanciUrun`, `ToptanciTip`)
- Stok **gÃ¼nlÃ¼k**, `toptanciStokGunu != gun` ise yeniden Ã¼retilir (`gunuBitir` iÃ§inde 0'lanÄ±r)
- 5 tezgÃ¢h (tuccar rozetiyle 6): 1 tamir seti + %70 kapalÄ± kutu + kalanÄ± Ã¼rÃ¼n
- Fiyatlar: saÄŸlam %55-75, Ã§Ã¼rÃ¼k %28-40 (piyasa fiyatÄ±nÄ±n)
- Ä°ndirimler toplanÄ±r: gÃ¼nlÃ¼k olay + `zengin` rozeti (%10) + `pazarlikci` rozeti (Ã§Ã¼rÃ¼kte %20)
- Görsel: `assets/toptanci.png` (470×470, kullanıcı üretti — v103'te yüksek çözünürlüklü kesimle değişti)

### 5. Hedefler & Rozetler (`Rozet`)
8 rozet. `_rozetleriDenetle()` **`notifyListeners()` iÃ§inde** Ã§alÄ±ÅŸÄ±r (kendisi notify Ã§aÄŸÄ±rmaz â†’ dÃ¶ngÃ¼ yok).
KazanÄ±lanlar `yeniKazanilanRozetler` kuyruÄŸuna girer, UI `_rozetKuyrugunuIsle()` ile **ekran mÃ¼saitken** gÃ¶sterir (mÃ¼ÅŸteri/pazarlÄ±k/envanter/gÃ¼n-sonu yokken â†’ dialog Ã§akÄ±ÅŸmasÄ± olmaz).

| Rozet | Hedef | Ã–dÃ¼l (sadece yeni sistemleri etkiler) |
|---|---|---|
| ğŸª Ä°lk SatÄ±ÅŸ | 1 satÄ±ÅŸ | +100 lira |
| ğŸ’¼ TÃ¼ccar | 10 satÄ±ÅŸ | ToptancÄ±da 6. tezgÃ¢h |
| ğŸ”§ Tamirci | 5 tamir | Tamir seti %30 indirimli |
| ğŸ Kutu AvcÄ±sÄ± | 10 kutu | Kutuda Ã§Ã¼rÃ¼k ÅŸansÄ± yarÄ±ya iner |
| ğŸ’ Koleksiyoncu | 10 farklÄ± Ã¼rÃ¼n sat | ToptancÄ± Ã¼rÃ¼nleri iyi kondisyonda |
| ğŸ’° Zengin | 10.000 lira | ToptancÄ±da kalÄ±cÄ± %10 indirim |
| ğŸ¤ PazarlÄ±k UstasÄ± | 30 anlaÅŸma | Ã‡Ã¼rÃ¼kler %20 daha ucuz |
| ğŸ“… Emektar | 15. gÃ¼n | Her gÃ¼n +200 lira destek |

### 6. GÃ¼n OlaylarÄ± (`GunOlayi`)
- `gunuBitir()` iÃ§inde, **3. gÃ¼nden itibaren %55 ihtimalle** biri seÃ§ilir
- Etkiler: `musteriDelta`, `piyasaCarpani`, `paraDelta`, `toptanciIndirim`, `fareIstilasi`
- `piyasaCarpani` `_piyasaEtkisi()` ile uygulanÄ±r: **alÄ±cÄ± daha Ã§ok Ã¶der, satÄ±cÄ± daha az ister** (`musteriSatiyor ? reserv/c : reserv*c`)
- 10 olay: TikTok viral, elektrik kesintisi, retro fuar, ekonomik kriz, kaldÄ±rÄ±m kazÄ±sÄ±, sÃ¼rpriz zarf, fare istilasÄ±, toptancÄ± kampanyasÄ±, saÄŸanak yaÄŸmur, gazete Ã¶vgÃ¼sÃ¼
- Reklamdan sonra popup ile tanÄ±tÄ±lÄ±r

### Kritik uygulama notlarÄ±
- **`urunCikarOrnek(GameItem)`** eklendi: aynÄ± id'den Ã§Ã¼rÃ¼k + saÄŸlam iki kopya varsa `identical` ile doÄŸru Ã¶rneÄŸi Ã§Ä±karÄ±r (eski `urunCikar(id)` yanlÄ±ÅŸÄ±nÄ± satabilirdi)
- `GameItem.kopyaWith()` â€” alan bazlÄ± kopya (final alanlar iÃ§in)
- `_slotaKoy()` sessiz ekleme (Ã§ift kayÄ±t Ã¶nler), `_slotlariSikistir()` ortak sÄ±kÄ±ÅŸtÄ±rma
- TÃ¼m yeni alanlar `toJson`/`fromJson`'da **null-safe default** â†’ eski kayÄ±tlar bozulmaz

---

## Ã–nemli Oyun Mekanikleri
- **GÃ¼n sistemi**: Her gÃ¼n N mÃ¼ÅŸteri, gÃ¼n sonunda kira dÃ¼ÅŸÃ¼lÃ¼r
- **PazarlÄ±k**: MÃ¼ÅŸteri teklif verir, oyuncu kabul/reddeder
- **Envanter slot sistemi**: ÃœrÃ¼n alÄ±m/satÄ±m
- **DÃ¼kkan seviyeleri**: Kira Ã¶deyerek bÃ¼yÃ¼tme
- **Özel müşteriler**: Hırsız, polis, vergici, kurye (YeSekSepeti), Toptancı Rıza, **Falcı Faloya**
- **iMac satÄ±n alma**: 3. gÃ¼nden sonra gÃ¶rÃ¼nÃ¼r buton, alÄ±ndÄ±ktan sonra masa deÄŸiÅŸir
- **Bilgisayar Geldi popup**: 3. gÃ¼nde tetiklenir (tek seferlik, `_bilgisayarGeldiGosterildi` flag'i)
- **Oyun sonu**: Para bitti + envanter boÅŸ â†’ iflas popup
- **Devam Et butonu**: `_kayitVar` flag'i ile kontrol edilir â€” kayÄ±t yoksa pasif
- **BaÅŸlangÄ±Ã§ parasÄ±**: 1000 (eskiden 500)
- **ArdÄ±ÅŸÄ±k aynÄ± Ã¼rÃ¼n engeli**: `_sonUrunId` field'Ä±; bir Ã¶nceki mÃ¼ÅŸterinin Ã¼rÃ¼nÃ¼ havuzdan Ã§Ä±karÄ±lÄ±r (birden fazla seÃ§enek varsa)

---

## Kolonya Sistemi (v78 â†’ v90 sÃ¼rÃ¼mleri)

### Kolonya Ã–zellikleri
- SatÄ±cÄ± mÃ¼ÅŸteri 1. gÃ¼nden itibaren kolonya satabilir (10 kullanÄ±m, slot dÄ±ÅŸÄ± tutulur â€” +1 ilave)
- `kolonyaKullanim`: 0-10 arasÄ±, mÃ¼ÅŸteriye ikram baÅŸÄ±na 1 dÃ¼ÅŸer
- `kolonyaIkramEdildi`: aynÄ± mÃ¼ÅŸteriye 2 kez ikram engellenir
- `_kolonyaPendingBonus`: pazarlÄ±k baÅŸlamadan ikram edilirse bekleyen bonus
- Ã–zel mÃ¼ÅŸteriye kolonya: parasÄ±z gÃ¶nderir (hÄ±rsÄ±z/polis/vergici/kurye)

### "Kolonya Tut" Butonu (_buildAltBar) â€” v89

Eski yerleÅŸik kolonya gÃ¶rseli (Stack iÃ§inde Positioned) **kaldÄ±rÄ±ldÄ±**. Yerine `_buildAltBar`'da MÃ¼ÅŸteri Ã‡aÄŸÄ±r/Envanter satÄ±rÄ±nÄ±n altÄ±nda:

```dart
if (_state.kolonyaKullanim > 0) ...[
  const SizedBox(height: 8),
  Builder(builder: (_) {
    final hasMusteri = _state.aktifMusteri != null || _state.aktifOzelMusteri != null;
    final aktif = hasMusteri && !_state.kolonyaIkramEdildi;
    return GestureDetector(
      onTap: aktif ? _kolonyaIkramEt : null,
      child: CustomPaint(
        painter: _PixelButonPainter(renk: const Color(0xFFE6A800), aktif: aktif),
        child: SizedBox(
          height: 50,
          ...
          // Ä°kon (Image.asset 'kolonya.png' 22Ã—22) + "Kolonya Tut" (white w900) + "X/10" (white70)
        ),
      ),
    );
  }),
],
```

- Renk: `0xFFE6A800` (parlak amber)
- YazÄ±: beyaz (Ã¶nceki siyah/altÄ±n deÄŸildi)
- MÃ¼ÅŸteri yokken pasif (white38/white24 + opacity 0.35)
- `kolonyaKullanim == 0` ise buton tamamen kaybolur

### Kolonya SonrasÄ± AlÄ±cÄ± MesajÄ± (v90)

AlÄ±cÄ± mÃ¼ÅŸteriye (`!musteriSatiyor`) kolonya tutulunca:
1. 3 sn "Kolonya ikramÄ±n iÃ§in teÅŸekkÃ¼rler! :)" gÃ¶sterilir
2. Sonra `_state.mesaj` 6 random mesajdan biriyle gÃ¼ncellenir
3. Ã–nceki mesaj tekrar gelmez â€” `_kolonyaSonrasiSonIdx` field'Ä±

```
1) "Ne diyorduk? Elinde X olduÄŸunu duydum, bana satar mÄ±sÄ±n?"
2) "En son X cd'sini bana satmanÄ± rica ediyordum. MÃ¼mkÃ¼n mÃ¼?"
3) "Nerede kalmÄ±ÅŸtÄ±k... Evet. X cd'ni bana satar mÄ±sÄ±n?"
4) "Hah ne diyordum; X cd'ni alabilir miyim mÃ¼mkÃ¼nse?"
5) "X cd'n hala duruyorsa ben alabilir miyim?"
6) "FerahladÄ±ÄŸÄ±ma gÃ¶re tekrar sorayÄ±m, X satÄ±lÄ±k mÄ± halen?"
```
X = `_state.aktifMusteri!.item.name` (orijinal balondaki Ã¼rÃ¼n)

---

## iOS YapÄ±landÄ±rmasÄ±

### Temel Bilgiler
- **Bundle ID**: `com.oyuncudukkani.app` (Android ile aynÄ±)
- **Display Name**: `Oyuncu DÃ¼kkanÄ±` (Info.plist `CFBundleDisplayName`)
- **Deployment Target**: 13.0 (AdMob iÃ§in minimum)
- **Team ID**: `SN5Y726ZKF` (FUTURASTIC TEKNOLOJI URUNLERI VE DANISMANLIGI ORGANIZASYON TICARET LIMITED SIRKETI)
- **AdMob iOS App ID**: `ca-app-pub-6470338276121414~7413384913` (Info.plist `GADApplicationIdentifier`)
- **AdMob iOS Interstitial Unit ID**: `ca-app-pub-6470338276121414/1436676062` (oyuncudukkanigecis, PROD)
- **AdMob iOS Ã–dÃ¼llÃ¼ (Rewarded) Unit ID**: `ca-app-pub-6470338276121414/2648809677` (oyuncudukkaniodullu, OLUÅTURULDU ama oyunda henÃ¼z KULLANILMIYOR)
- **AdMob Android Interstitial Unit ID**: `ca-app-pub-6470338276121414/4138047986` (PROD)
- **App Store Connect App ID** (numerik): `6778437262`
- **NSUserTrackingUsageDescription**: ATT (App Tracking Transparency) izni iÃ§in
- **SKAdNetworkItems**: AdMob 12.x iÃ§in Google'Ä±n gÃ¼ncel SKAN ID listesi (43 aÄŸ)
- **ITSAppUsesNonExemptEncryption**: `false` (sadece HTTPS, custom crypto yok â€” Apple muaf)
- **iOS App Icon**: `flutter_launcher_icons` ile `assets/oyuncu_dukkani_icon.png`'den Ã¼retildi
  - `ios: true`, `remove_alpha_ios: true` (Apple alpha kanal kabul etmiyor)

### Apple Developer Portal Setup (BÄ°R KEZ)
1. https://developer.apple.com/account/resources/identifiers/list
2. **+** (Add) â†’ App IDs â†’ App
3. Description: `Oyuncu Dukkani` (ASCII), Bundle ID: `com.oyuncudukkani.app` (Explicit)
4. Capabilities: hiÃ§bir ÅŸey iÅŸaretleme
5. Register

### App Store Connect Setup (BÄ°R KEZ)
1. https://appstoreconnect.apple.com â†’ My Apps â†’ **"+"** â†’ New App
2. Platforms: iOS, Name: **Oyuncu DÃ¼kkanÄ±**, Bundle ID: dropdown'dan seÃ§
3. SKU: **OYUNCUDUKKANI001**, User Access: **Full Access**
4. Create â†’ URL'deki numerik App ID'yi al (Ã¶rn. `6778437262`)

---

## ğŸš€ Codemagic CI/CD â€” iOS TestFlight Pipeline

`codemagic.yaml` git tag `v*` push edilince tetiklenir, otomatik TestFlight yÃ¼kleme yapar.

### Workflow tetikleme
```bash
# YA git tag ile (otomatik)
git tag v1.0.x-iosN
git push origin v1.0.x-iosN

# YA Codemagic UI'dan manuel: Applications â†’ oyuncu_dukkani â†’ Start new build â†’ main â†’ ios-testflight
```

### Codemagic UI Kurulum (BÄ°R KEZ tamamlandÄ±)

**1. Repo baÄŸlantÄ±sÄ±**
- https://codemagic.io â†’ Sign in with GitHub â†’ "Add application" â†’ oyuncu_dukkani repo

**2. App Store Connect API Key entegrasyonu**
- Codemagic UI â†’ Personal Account â†’ **Settings** â†’ Integrations â†’ **Developer Portal** â†’ "Connect"
- App Store Connect â†’ Users and Access â†’ Integrations / Keys â†’ "+" â†’ App Manager rolÃ¼nde key oluÅŸtur
- Key ID, Issuer ID, .p8 dosyasÄ±nÄ± Codemagic'e gir
- Name: **`Codemagic`** (YAML'da `integrations.app_store_connect: Codemagic` ile referans veriliyor)
- **Mevcut Key ID:** `2M84B256CL` (Magnus ile paylaÅŸÄ±mlÄ±)

**3. iOS Distribution Certificate (Code signing identity)**
- Personal Account â†’ **Settings** â†’ "Code signing identities" â†’ "iOS certificates"
- **Upload a certificate file**: `.p12` dosyasÄ± sÃ¼rÃ¼kle
- Åifre boÅŸ olabilmesi iÃ§in yerel olarak yeniden Ã¼retildi:
  ```bash
  openssl pkcs12 -export -legacy \
    -out ios_distribution_nopass.p12 \
    -inkey C:/src/magnus_app/ios_certs/ios_distribution.key \
    -in   C:/src/magnus_app/ios_certs/distribution.pem \
    -passout pass:
  ```
- Reference name: `ios_distribution`
- âš ï¸ NOT: Magnus iÃ§in yapÄ±lmÄ±ÅŸ cert'ten tÃ¼retildi, **aynÄ± Apple Developer Team** olduÄŸu iÃ§in oyuncu_dukkani iÃ§in de geÃ§erli

**4. Private Key Environment Variable**
- Codemagic Personal Account â†’ Settings â†’ Global vars **deprecated** â†’ Applications â†’ oyuncu_dukkani â†’ **Environment variables**
- `CERTIFICATE_PRIVATE_KEY` (Secret âœ…, group: `signing_credentials`)
- DeÄŸer: `ios_distribution.key`'in **base64 encoded** iÃ§eriÄŸi:
  ```bash
  cat ios_distribution.key | base64 -w 0 > cert_key_base64.txt
  ```
- YAML'da `signing_credentials` group referansÄ± zorunlu

### codemagic.yaml YapÄ±sÄ±

```yaml
workflows:
  ios-testflight:
    name: iOS TestFlight (Otomatik)
    instance_type: mac_mini_m2
    integrations:
      app_store_connect: Codemagic   # UI'daki integration adÄ±
    environment:
      flutter: stable
      xcode: latest
      cocoapods: default
      groups:
        - signing_credentials         # CERTIFICATE_PRIVATE_KEY burada
      vars:
        APP_STORE_APP_ID: "6778437262"
        BUNDLE_ID: "com.oyuncudukkani.app"
    triggering:
      events: [tag]
      tag_patterns:
        - pattern: 'v*'
    scripts:
      - name: Initialize keychain
        script: keychain initialize
      - name: Fetch signing files (auto-create profile if missing)
        script: |
          echo "$CERTIFICATE_PRIVATE_KEY" | base64 --decode > /tmp/cert_key.pem
          app-store-connect fetch-signing-files "$BUNDLE_ID" \
            --type IOS_APP_STORE --platform IOS \
            --certificate-key=@file:/tmp/cert_key.pem --create
      - name: Add certificates to keychain
        script: keychain add-certificates
      - name: Set up Xcode profiles
        script: xcode-project use-profiles
      - name: Flutter packages + disable SwiftPM
        script: |
          # google_mobile_ads CocoaPods, webview_flutter SwiftPM â€” Ã§akÄ±ÅŸÄ±yor
          flutter config --no-enable-swift-package-manager
          flutter packages pub get
      - name: Pod install
        script: find . -name "Podfile" -execdir pod install \;
      - name: Flutter build ipa
        script: |
          # Build number: latest+1, hata olursa timestamp (uniqlik garantili)
          LATEST_BUILD=$(app-store-connect get-latest-app-store-build-number "$APP_STORE_APP_ID" 2>/dev/null || echo "0")
          if [ -z "$LATEST_BUILD" ] || [ "$LATEST_BUILD" = "0" ]; then
            BUILD_NUMBER=$(date +%s | tail -c 7)
          else
            BUILD_NUMBER=$((LATEST_BUILD + 1))
          fi
          flutter build ipa --release \
            --build-name=1.0.1 \
            --build-number=$BUILD_NUMBER \
            --export-options-plist=/Users/builder/export_options.plist
    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: true
        submit_to_app_store: false
```

### âš ï¸ Ã‡Ã¶zÃ¼len Codemagic SorunlarÄ± (referans)

| Hata | Sebep | Ã‡Ã¶zÃ¼m |
|------|-------|-------|
| `auth: integration requires workflow â†’ integrations â†’ app_store_connect` | YAML'da integrations bloÄŸu eksik | `integrations.app_store_connect: Codemagic` eklendi |
| `No matching profiles found for bundle identifier` | `ios_signing` env block profil yoksa hata fÄ±rlatÄ±r | Env block kaldÄ±rÄ±ldÄ±, script ile `--create` |
| `Cannot save Signing Certificates without certificate private key` | Cert auto-create iÃ§in private key gerekli | `CERTIFICATE_PRIVATE_KEY` env var + `--certificate-key=@file:` |
| `Provided value "" is not valid` (cert key) | Env var boÅŸ veya group baÄŸlanmamÄ±ÅŸ | YAML'a `groups: [signing_credentials]` eklendi |
| `google_mobile_ads uses CocoaPods while webview_flutter_wkwebview uses Swift Package Manager` | SDK Ã§akÄ±ÅŸmasÄ± | `flutter config --no-enable-swift-package-manager` |
| `The bundle version must be higher than the previously uploaded version` | Build number unique olmuyor | Timestamp fallback (`date +%s | tail -c 7`) |
| Mavi Flutter Ã¼Ã§geni ikon | `flutter_launcher_icons` ios:false | `ios: true` + `flutter pub run flutter_launcher_icons` |
| Encryption sorusu her build'de soruluyor | Info.plist'te bildirim yok | `ITSAppUsesNonExemptEncryption=false` eklendi |
| App Privacy formu doldurulmamÄ±ÅŸ | NSUserTrackingUsageDescription ATT istiyor | App Privacy â†’ Publish â†’ Tracking yapÄ±landÄ±r |

### TestFlight Test Etme
1. iPhone'a **TestFlight** uygulamasÄ±nÄ± App Store'dan kur
2. App Store Connect'teki Apple ID ile giriÅŸ yap
3. App Store Connect â†’ Oyuncu DÃ¼kkanÄ± â†’ TestFlight â†’ **Internal Testing** â†’ "+" Group oluÅŸtur
4. Group â†’ Testers â†’ kendi Apple ID'ni ekle
5. Group â†’ Builds â†’ "+ Add Build" â†’ son build seÃ§
6. iPhone'a mail gelir (5-15 dk) veya doÄŸrudan TestFlight uygulamasÄ±nda belirir

### App Privacy Formu (NSUserTrackingUsageDescription kullanÄ±lÄ±rsa)
App Store Connect â†’ Oyuncu DÃ¼kkanÄ± â†’ **App Privacy** â†’ Get Started:

**Data Types collected** (AdMob iÃ§in):
- **Identifiers â†’ Device ID**: Linked=Yes, Tracking=Yes, Purpose=Third-Party Advertising
- **Diagnostics â†’ Crash Data**: Linked=No, Tracking=No, Purpose=App Functionality
- **Diagnostics â†’ Performance Data**: Linked=No, Tracking=No, Purpose=App Functionality

**Privacy Policy URL**: `https://anilgedikoglu.github.io/oyuncu_dukkani/privacy-policy.html`

âš ï¸ Form doldurulunca **"Publish"** butonuna tÄ±klamak ZORUNLU (Save yetmiyor).

### Versiyon KontrolÃ¼
- pubspec.yaml: `1.0.2+13`
- iOS build number Codemagic tarafÄ±ndan OTOMATÄ°K timestamp ile atanÄ±yor, pubspec'teki +13 ile Ã§akÄ±ÅŸmaz
- Android AAB: pubspec'teki versionCode kullanÄ±lÄ±r â†’ Play'e her yÃ¼klemede ARTTIR (12â†’13â†’14...)
- Yeni release iÃ§in: `pubspec.yaml` version arttÄ±r â†’ commit + push â†’ Codemagic UI'dan manuel build baÅŸlat veya `git tag v1.0.x-iosN`

---

## app-ads.txt (AdMob DoÄŸrulama)

AdMob'un yetkisiz reklam envanteri satÄ±ÅŸÄ±nÄ± Ã¶nlemek iÃ§in kullandÄ±ÄŸÄ± doÄŸrulama dosyasÄ±.

**Dosya konumu (KRÄ°TÄ°K):** Domain KÃ–KÃœNDE olmalÄ±, alt-path'te DEÄÄ°L.
- âœ… DoÄŸru: `anilgedikoglu.github.io/app-ads.txt` (ayrÄ± `anilgedikoglu.github.io` repo'sunda)
- âŒ YanlÄ±ÅŸ: `anilgedikoglu.github.io/oyuncu_dukkani/app-ads.txt` (proje alt-path'i â€” AdMob bakmaz)

**Ä°Ã§erik (tÃ¼m app'ler iÃ§in ortak, aynÄ± pub ID):**
```
google.com, pub-6470338276121414, DIRECT, f08c47fec0942fa0
```

**AdMob doÄŸrulama zinciri:** AdMob app kaydÄ± â†’ baÄŸlÄ± App Store/Play URL â†’ store'daki "Developer Website" domaini â†’ o domainin kÃ¶kÃ¼ndeki app-ads.txt â†’ pub ID eÅŸleÅŸmesi.

**Oyuncu DÃ¼kkanÄ± iÃ§in zincir (hepsi doÄŸru):**
- App Store Developer Website: `https://anilgedikoglu.github.io/oyuncu_dukkani/marketing.html`
- Domain: `anilgedikoglu.github.io` â†’ app-ads.txt orada mevcut âœ…

**"DoÄŸrulanamadÄ±" hatasÄ± Ã§Ã¶zÃ¼mÃ¼:**
1. Dosya/iÃ§erik genelde DOÄRUDUR â€” panik yapma, Ã¶nce zinciri kontrol et
2. AdMob'daki app kaydÄ± App Store/Play'e BAÄLI olmalÄ± (manuel oluÅŸturulduysa baÄŸlanmamÄ±ÅŸ olabilir)
3. AdMob tarama gÃ¼nde ~1 kez â†’ "yeniden tara" deyip 24 saat bekle
4. DoÄŸrulama hatasÄ± reklam gelirini ENGELLEMEZ, reklamlar yine gÃ¶sterilir â€” acil deÄŸil

âš ï¸ App Store/Play'de "Marketing/Developer Website" alanÄ± domaini `anilgedikoglu.github.io` olmalÄ± (app-ads.txt orada).

---

## Android YapÄ±landÄ±rmasÄ±
- **Paket adÄ±**: `com.oyuncudukkani.app` (eski: `com.example.oyuncu_dukkani`)
- **Uygulama ikonu**: `flutter_launcher_icons` ile `oyuncu_dukkani_icon.png`'den Ã¼retildi, adaptive icon destekli
- **Splash**: Android native splash kaldÄ±rÄ±ldÄ±, Flutter tarafÄ±nda `SplashScreen` widget'Ä± kullanÄ±lÄ±yor

### âš ï¸ EnableImpeller=false (Skia)

**AndroidManifest.xml**'de:
```xml
<meta-data
    android:name="io.flutter.embedding.android.EnableImpeller"
    android:value="false" />
```

**Neden:** Impeller emÃ¼latÃ¶rÃ¼n yazÄ±lÄ±msal GPU'sunu (`ranchu`/SwiftShader) boÄŸuyor â€” raster thread %92 CPU + %90 kernel, composer3 %100, surfaceflinger %48 â†’ ANR ("Application does not have a focused window"). Skia ile composer3 %100 â†’ %3.4. GerÃ§ek cihazda Impeller (Vulkan) hÄ±zlÄ±, sorun yok, ama emÃ¼latÃ¶r test iÃ§in Skia zorunlu.

Bu flag deprecated uyarÄ±sÄ± verir ama hÃ¢lÃ¢ Ã§alÄ±ÅŸÄ±r.

---

## âš ï¸ ANR SorunlarÄ± & EmÃ¼latÃ¶r YÃ¶netimi

### Tetikleyiciler
1. **Impeller + software GPU**: YukarÄ±daki Skia Ã§Ã¶zÃ¼mÃ¼
2. **EmÃ¼latÃ¶r state degradation**: Uzun sÃ¼reli install/uninstall/force-stop dÃ¶ngÃ¼leri Android system_server'Ä± bozar. Belirtisi: "Process system isn't responding" + Windows tarafÄ±nda "YanÄ±t Vermiyor"
3. **BÃ¼yÃ¼k APK + AOT cold start**: Ä°lk install + ART derleme Ã¶nbelleÄŸi oluÅŸturma >5 sn â†’ startup ANR

### GeliÅŸtirme AkÄ±ÅŸÄ±
- **Yeni APK kurarken** her zaman: `adb install -r` (kaldÄ±rmadan Ã¼stÃ¼ne) â€” ART Ã¶nbelleÄŸi korunur
- **Ä°mza deÄŸiÅŸikliÄŸinde** (debugâ†”release): mecbur uninstall
- **EmÃ¼latÃ¶r sÄ±kÄ±ÅŸÄ±rsa**: Tamamen kapat â†’ Cold Boot (`-wipe-data` veya AVD Manager'dan "Wipe Data")
- **GerÃ§ek cihazda** ANR olmaz; emÃ¼latÃ¶r spesifik

### ⚠️ Git Bash + adb: `/sdcard/` yolu bozulur
Git Bash, argümandaki POSIX yolunu Windows yoluna çevirir → `adb shell screencap -p /sdcard/e.png`
`C:/Program Files/Git/sdcard/e.png` olur ve **screencap usage hatası** verir.
Başına `MSYS_NO_PATHCONV=1` koy:

```bash
MSYS_NO_PATHCONV=1 adb shell screencap -p /sdcard/e.png && MSYS_NO_PATHCONV=1 adb pull /sdcard/e.png
```

Aynı sebeple `adb shell 'sleep 5'` tırnak içinde yazılmalı (Bash tool ön planda
`sleep` çalıştırmayı engelliyor; beklemeyi cihaza yaptır).

### Build Ã‡Ä±ktÄ±larÄ± (post-optimizasyon)
```
app-armeabi-v7a-release.apk : 32.4MB
app-arm64-v8a-release.apk    : 34.7MB
app-x86_64-release.apk       : 36.1MB
```
v87 fat APK 70.8MB idi â€” assets optimizasyonu ile dramatik azalma.

---

## Asset Optimizasyonu (v88)

### Optimize Edilen (PowerShell + System.Drawing ile resize + recompress)

| Dosya | Ã–nce | Sonra | YÃ¶ntem |
|-------|------|-------|--------|
| bgbos.png | 7.1 MB | 2.1 MB | 1684Ã—2528 â†’ 719Ã—1080 |
| anamenu.png | 7.3 MB | 1.3 MB | 1408Ã—3062 â†’ 497Ã—1080 |
| bg1.png | 3.6 MB | 1.1 MB | 1684Ã—2528 â†’ 719Ã—1080 |
| bg2.png | 3.6 MB | 1.2 MB | 1684Ã—2528 â†’ 719Ã—1080 |
| bgbosmasa.png | 3.2 MB | 1.1 MB | 1684Ã—2528 â†’ 719Ã—1080 |
| browser.png | 0.9 MB | 0.15 MB | 775Ã—1298 â†’ 306Ã—512 |
| biri.png | 7 MB (eskiden) | 11 KB | 1684Ã—2528 â†’ 341Ã—512 |
| CD_1..6 | ~440KB her | ~390KB her | 437Ã—571 â†’ 392Ã—512 |
| konsol_1..5 | ~200KB | ~190KB | re-encode |
| kurye.png | 185KB | 144KB | 408Ã—612 â†’ 341Ã—512 |

### pubspec.yaml â€” Asset Listesi (Wildcard â†’ Explicit)

Ã–nceden `assets/` wildcard tÃ¼m dosyalarÄ± paketliyordu. Åimdi explicit liste:
- HariÃ§ tutulanlar: `anamenu1.png` (7.1MB), `anamenu2.png` (7.2MB), `oyuncu_dukkani_market.png` (7.4MB) â†’ 21MB kazanÃ§
- Her CD ve mÃ¼ÅŸteri ayrÄ± satÄ±r

---

## DevicePreview
`device_preview` paketi ÅŸu an **disabled** (`enabled: false`). Test sÄ±rasÄ±nda ekranÄ± kÃ¼Ã§Ã¼lttÃ¼ÄŸÃ¼ iÃ§in kapatÄ±ldÄ±. AÃ§mak iÃ§in `enabled: kDebugMode` yap.

## Header â€” Daire SayaÃ§ Animasyonu

GÃ¼n/para kutularÄ± eÅŸit geniÅŸlik. AralarÄ±nda sarÄ± daire (Ticker tabanlÄ± sÃ¼rekli animasyon):

```dart
// _GameScreenState alanlarÄ±:
late Ticker _daireTicker;
Duration _dairePrevTick = Duration.zero;
double _daireGosterilen = 0.0;  // 0.0..1.0 ekranda gÃ¶rÃ¼nen
double _daireHedef     = 0.0;   // mÃ¼ÅŸteri sayÄ±sÄ±na gÃ¶re hedef
double _daireHiz       = 0.3;   // rassal hÄ±z (bazen hÄ±zlanÄ±r/yavaÅŸlar)
final _daireRng = Random();
```

`_DairePainter` â†’ sarÄ± dolmuÅŸ dilim (clockwise), siyah ince Ã§erÃ§eve, beyaz yarÄ± ÅŸeffaf arka plan.

---

## Butonlar â€” Pixel Art Ã‡erÃ§eve

`_PixelButonPainter` (CustomPainter): metalik siyah gradient Ã§erÃ§eve, renkli gradient iÃ§, L-ÅŸekli kÃ¶ÅŸe sÃ¼sleri (7 piksel/kÃ¶ÅŸe), Ã¼st parlama ÅŸeridi.
`_oyunButon()` â†’ `GestureDetector` + `CustomPaint(painter: _PixelButonPainter(...))`.
YÃ¼kseklik: 50px. YazÄ±lar `FittedBox(fit: BoxFit.scaleDown)` ile taÅŸmaz.

---

## PazarlÄ±k Popup â€” TÄ±klanabilir Teklif Balonu

MÃ¼ÅŸteri ALICIYSA (`!musteriSatiyor && !anlasildi && !gitti && !_bitti`):
```
_dialogMesaj Container â†’ GestureDetector
  borderRadius: 24 (oval)
  border: Color(0xFF4caf50), width: 1.8  â† yeÅŸil
  boxShadow: yeÅŸil parlama
  onTap: widget.state.teklifVer(musteriTeklif) â†’ Navigator.pop()
```
TÄ±klanÄ±nca oyuncu mÃ¼ÅŸterinin teklifini kabul etmiÅŸ olur.
Butonlar: sadece "Reddet" (kÄ±rmÄ±zÄ±) + "Fiyat Ver" (altÄ±n) â€” "Kabul Et" yok.

**Piyasa/Maliyet bilgisi (v90 ile aynÄ± font):**
```dart
Piyasa : fontSize 14, white60, w600 + basePrice (blue 0xFF64B5F6, bold)
Maliyet: fontSize 14, white60, w600 + value     (orangeAccent, bold)
```

---

## Envanter Kompaksiyon

`urunCikar()` â†’ Ã¼rÃ¼n Ã§Ä±ktÄ±ktan sonra dolu slotlar Ã¶ne Ã§ekilir, boÅŸluklar sona itilir:
```dart
final dolu = slotlar.sublist(0, acikSlotSayisi).whereType<GameItem>().toList();
for (int j = 0; j < acikSlotSayisi; j++) slotlar[j] = j < dolu.length ? dolu[j] : null;
```

---

## ÃœrÃ¼n Listesi (`_baslangicUrunler`)

| Kategori | ID | Ad | GÃ¶rsel | basePrice |
|----------|----|----|--------|-----------|
| cd | cd1..14 | KARMAGEDDON, CÄ°MRÄ°CÄ°TY, ..., TENÄ°S OYUNU, DALAKKÃœREK, ÅAHMAT, TOTORACER, GAMLIBAYKUÅ, KISPET, UÃ‡ARSOKAR, DÃœTTÃœRÃœ | CD_1..14.png | 80-175 |
| konsol | konsol1 | PlayStatyon | konsol_1.png | 900 |
| konsol | konsol2 | Ninetendo | konsol_2.png | 750 |
| konsol | konsol3 | Ateri | konsol_3.png | 500 |
| konsol | konsol4/5/6 | El Konsolu (3 versiyon) | konsol_4/5/6.png | 380-560 |
| konsol | konsol7 | son sistem oyun konsolu | konsol_7.png | 3200 |
| aksesuar | aksesuar1..N | Direksiyon, Joypad, vs. | ... | ... |
| aksesuar | kolonya | Kolonya (slot dÄ±ÅŸÄ±, +1 ilave) | kolonya.png | 120 |

---

## AdMob Reklam Sistemi (v91-v92)

Her yeni gÃ¼nÃ¼n baÅŸÄ±na interstitial (geÃ§iÅŸ) reklamÄ±, game over deÄŸilse. **EmÃ¼latÃ¶rde reklam Ã§Ä±kmaz** (politika gÃ¼venliÄŸi).

### AdMob Kimlikleri (PROD)
- **App ID** (AndroidManifest): `ca-app-pub-6470338276121414~9391747814`
- **Interstitial Unit ID**: `ca-app-pub-6470338276121414/4138047986`

### AkÄ±ÅŸ
```
GÃ¼n Bitti popup â†’ "Yeni GÃ¼ne BaÅŸla" â†’ ReklamServisi.goster()
  â†“ (emÃ¼latÃ¶rse / reklam yoksa: anÄ±nda)
  â†“ (gerÃ§ek cihaz + reklam varsa: tam ekran geÃ§iÅŸ reklamÄ±)
onClosed: _state.gunuBitir() â†’ Yeni gÃ¼n
```

Ä°flas durumunda reklam GÃ–STERÄ°LMEZ (`paraOncesi - toplamKesinti < 0` dalÄ±).

### EmÃ¼latÃ¶r AlgÄ±lama
`main()` baÅŸÄ±nda `ReklamServisi.emulatorAlgila()` `device_info_plus` ile `androidInfo.isPhysicalDevice` okur. EmÃ¼latÃ¶rde:
- `MobileAds.instance.initialize()` ATLANIR
- `yukle()` no-op olur
- `goster()` direkt `onClosed()` Ã§aÄŸÄ±rÄ±r

Bu sayede emÃ¼latÃ¶rde AdMob hiÃ§ baÅŸlamaz, sahte gÃ¶sterim olmaz.

### Kod YapÄ±sÄ±
```dart
class ReklamServisi {
  static const String _adUnitId = 'ca-app-pub-6470338276121414/4138047986';
  static InterstitialAd? _interstitial;
  static bool emulator = false;
  static Future<void> emulatorAlgila();
  static void yukle();
  static void goster({required VoidCallback onClosed});
}
```

`main()`:
```dart
WidgetsFlutterBinding.ensureInitialized();
await ReklamServisi.emulatorAlgila();
if (!ReklamServisi.emulator) {
  MobileAds.instance.initialize();
  ReklamServisi.yukle();
}
```

---

## PazarlÄ±k Ã‡eÅŸitliliÄŸi (v92)

KarÅŸÄ± tarafÄ±n hareketi her zaman gÄ±dÄ±m gÄ±dÄ±m deÄŸil â€” sÃ¼rpriz bÃ¼yÃ¼k adÄ±mlar var. Bazen alÄ±cÄ± maliyetin Ã§ok Ã¼stÃ¼ne, hatta piyasa fiyatÄ±nÄ±n Ã¼stÃ¼ne Ã§Ä±kabilir.

### Rezervasyon FiyatÄ± SÃ¼rprizi (`MusteriOzellik.reservationPrice`)
| OlasÄ±lÄ±k | Ã‡arpan | Anlam |
|----------|--------|-------|
| %6 | 1.55â€“2.10Ã— | Zengin/aceleci alÄ±cÄ± (veya dar satÄ±cÄ±) â€” Ã§ok yÃ¼ksek tavan |
| %14 | 1.18â€“1.45Ã— | CÃ¶mert |
| %80 | 1.00Ã— | Normal (eski davranÄ±ÅŸ) |

- AlÄ±cÄ± tavanÄ±: `marketPrice * 0.50 ... 2.30` (eskiden max 1.20)
- SatÄ±cÄ± tabanÄ±: `marketPrice * 0.40 ... 1.55` (eskiden min 0.65)

### Tur BaÅŸÄ±na AdÄ±m BÃ¼yÃ¼klÃ¼ÄŸÃ¼ (`oyuncuTeklifVer` â†’ `concessionRatio`)
| OlasÄ±lÄ±k | Ã‡arpan | Anlam |
|----------|--------|-------|
| %10 | 2.5â€“4Ã— | BÃœYÃœK sÄ±Ã§rama â€” "anlaÅŸtÄ±k gibi" |
| %20 | 1.4â€“2.2Ã— | Orta sÄ±Ã§rama |
| %70 | 0.5â€“1.3Ã— | Normal/kÃ¼Ã§Ã¼k â€” gÄ±dÄ±m deÄŸil ama makul |

Base ratio hÃ¢lÃ¢ `_clamp(0.18 - progress * 0.15, 0.02, 0.18)`.

---

## Versiyon GeÃ§miÅŸi (son)
| Commit | AÃ§Ä±klama |
|--------|----------|
| v106 | **Oynanabilir ürünler**: bazı CD'ler gerçekten oynanıyor. `KIRGEÇ` (breakout, `lib/kirgec_oyunu.dart`) ve `İTELE` (tek kişilik pong, `lib/itele_oyunu.dart`). Envanterde köşede ⭐, tıkla → "oynamak ister misin?" → tam ekran oyun; toplanan puan birebir paraya çevrilip bakiyeye eklenir. **Günde 1 kez** (`bugunOynananOyunlar`, `gunuBitir`'de temizlenir, oyuna girer girmez hak yanar), para tavanı 1000, %5 nadirlik, toptancı/kutudan çıkmaz, fiyat normal CD ortalamasının 2 katı (270). Kontrol iki oyunda da aynı: ekranın sağ/sol yarısına basılı tut. `test/kirgec_test.dart` (10 test) |
| v105 | **Pazarlık hataları düzeltildi**: geçersiz girdide sessiz `return` (buton artık pasif+soluk), `teklifVer` hata atınca popup kapanmıyordu (`pop` artık `finally` içinde). **Teklif yön kuralı**: müşteri reddettikten sonra oyuncu alıyorsa ▼, satıyorsa ▲ pasif; ilk turda serbest. **Polis alkol testi** (%50): rastgele işlem + 2 şık, doğruysa ceza yok, yanlışsa 40-250 ceza. **"Yemeği Ye"** butonu (kuryeden yemek alınca alt barın en altında): envanterdeki tüm hasarlı ürünleri onarır. **Müşteriler 1/3 ihtimalle hasarlı ürün satıyor** — `GameItem.curukOran` ile müşteri malı %50-75 (toptancı hurdası %35). **Toptancı**: browser menüsünden kaldırıldı, kolonya ikramında gitmiyor, Kapat butonu sabit. **Müşteri Çağır** ekranda biri varken kilitli (Rıza'nın tekrar gelme bug'ı). Ana menüde **en yüksek kazanç** rekoru. `test/oynanis_test.dart` (9 test) |
| v104 | **Falcı Faloya** özel müşterisi: 40-140 liraya fal bakar, 50 fal metni, 14 etki türü (para kazanç/kayıp, bedava dükkan büyütme, "benden sonra vergici gelecek" kehanetleri, kolonya/tamir seti/kutu hediyesi, ürün çürütme, cömert müşteri şansı); parası yetmezse ücret alınmaz. **Dükkana göre arka plan**: 3 yeni görsel (JPEG, +1.1MB APK), seviye 2/3/4-5'e atandı, AnimatedSwitcher ile çapraz solma. **Kapı silüeti yeniden yazıldı**: `biri.png` tam ekran cover yerine `kapidaki.png` sprite'ı, arka planın cover kutusuna göre dükkan başına konumlanıyor (seviye 1 birebir aynı kaldı). `test/fal_test.dart` (11 test) |
| v103 | **Yaş/cinsiyet duyarlı replik sistemi**: `enum YasGrubu` (cocuk/genc/yetiskin/yasli) + `Replik{metin,yas,cinsiyet}` kaydı + `replikSec` filtresi (uyan→nötr→tüm havuz güvenlik zinciri); 28 karakterin hepsine yaş etiketi; TÜM replik havuzları `List<String>`→`List<Replik>`; selamlama 20→39, karşı teklif 25→48/46, kabul 26→42, gitme 18/18/12→27/26/19; `test/yas_replik_test.dart` regresyon testi (6 test). Ayrıca: 17 yeni karakter görseli kullanıcının kendi kesimiyle değiştirildi (işlenmeden kopyalandı), kaynakta md5 tekrarı ve bir eksik karakter yüzünden roster 29→28, `musteri_29.png` silindi |
| v97 | **BÃ¼yÃ¼k oynanÄ±ÅŸ gÃ¼ncellemesi**: ToptancÄ± RÄ±za (gÃ¼nlÃ¼k stok, ucuz Ã¼rÃ¼n), Ã§Ã¼rÃ¼k Ã¼rÃ¼n + CD tamir seti ekonomisi, kapalÄ± kutu (lootbox), 8 rozetli Hedefler ekranÄ±, 10 rastgele gÃ¼n olayÄ±. TÃ¼mÃ¼ browser menÃ¼sÃ¼nden eriÅŸilir â€” alt bar/sahne layout'una dokunulmadÄ± |
| v102 | 18 yeni müşteri karakteri (toplam 29: 14E/15K); beyaz zemin C# flood-fill ile temizlendi, oyunun 500×500 çerçevesine normalize edildi; tools/arkaplan_sil.ps1 yeniden kullanılabilir araç; isim havuzu 150+150 (hepsi benzersiz); SIRADAKİ İŞ: yaş sistemi |
| v101 | Ses sistemi: 11 yeni tetikleyici bağlandı (dosyalar eksik olsa da çökmez), HapticFeedback ile dokunsal geri bildirim |
| v100 | **PazarlÄ±k motoru hamle okuma**: `enum Hamle` ile oyuncunun tavizi sÄ±nÄ±flandÄ±rÄ±lÄ±yor (geri/aynÄ±/kÃ¼Ã§Ã¼k/orta/bÃ¼yÃ¼k); geri adÄ±mda mÃ¼ÅŸteri fiyat kÄ±rmaz + gidebilir, Ä±srar yorar, bÃ¼yÃ¼k jest Ã¶dÃ¼llendirilir; kaprisli evet (%5), bir kez sÄ±kÄ±ÅŸtÄ±rma (%30), son teklif uyarÄ±sÄ±, jest kabulÃ¼ |
| v99 | Diyalog havuzlarÄ± 5-10 katÄ±na Ã§Ä±karÄ±ldÄ± (selamlama 20+20, karÅŸÄ± teklif 25+25 **rol ayrÄ±**, kabul 26, gitme 18/18/12); toast bildirimi Material SnackBar'dan oyun temasÄ±na uygun animasyonlu karta Ã§evrildi (elasticOut, glow, okunabilir kontrast) |
| v98 | BaÄŸlÄ±lÄ±k mekanikleri: ğŸ”¥ seri/kombo (3+ anlaÅŸmada bonus, kÄ±zgÄ±n mÃ¼ÅŸteride sÄ±fÄ±rlanÄ±r), ğŸ¯ gÃ¼nlÃ¼k hedef (6 tip, dÃ¼kkan seviyesiyle Ã¶lÃ§eklenir), â˜€ï¸ yarÄ±nÄ±n olayÄ± gÃ¼n sonunda duyurulur ("bir gÃ¼n daha" kancasÄ±, sabah popup'Ä± kaldÄ±rÄ±ldÄ±), ğŸ“š koleksiyon paneli (23 Ã¼rÃ¼n, % tamamlanma) |
| v97 | **Ã‡Ã¶zÃ¼nÃ¼rlÃ¼kten baÄŸÄ±msÄ±z sahne** â€” `SahneMetrik` ile Ã¼rÃ¼n/isim/mÃ¼ÅŸteri masa gÃ¶rseline kilitlendi; sabit piksel kaldÄ±rÄ±ldÄ±; 20:9 / 16:9 / 4:3'te doÄŸrulandÄ± |
| v96 | App Store'da YAYINDA (id6778437262); iOS reklam ID TESTâ†’PROD (1436676062); ATT dialog (Guideline 2.1 dÃ¼zeltmesi, app_tracking_transparency); Ã¼rÃ¼n/isim konumu yukarÄ± (Ã¼rÃ¼n -20, isim 338); sÃ¼rÃ¼m 1.0.2+13 (AAB v13); MARKET BUILD Ã–NCESÄ° test-ID kontrol kuralÄ±; app-ads.txt doÄŸrulama notlarÄ± |
| v95 | iOS TestFlight aktif: Codemagic pipeline tam Ã§alÄ±ÅŸÄ±r durumda (10+ iterasyon sonrasÄ± signing/SwiftPM/build-number/icon hatalarÄ± Ã§Ã¶zÃ¼ldÃ¼); Magnus'tan paylaÅŸÄ±mlÄ± .p12 cert; CERTIFICATE_PRIVATE_KEY env var; iOS app icon (mavi Flutter Ã¼Ã§geni â†’ gerÃ§ek ikon); ITSAppUsesNonExemptEncryption=false; App Privacy formu dolduruldu; support.html + marketing.html (TR/EN) GitHub Pages'te yayÄ±nda; store/appstore_description_tr.txt yedeÄŸi |
| v94 | iOS App Store hazÄ±rlÄ±ÄŸÄ±: Bundle ID `com.oyuncudukkani.app`, deployment target 13.0, Info.plist'e AdMob iOS App ID + ATT izni + 43 SKAdNetwork ID, codemagic.yaml ile TestFlight'a otomatik gÃ¶nderim |
| v93 | Versiyon 1.0.1+12 â€” Google Play Store iÃ§in AAB yayÄ±nÄ± (app-release.aab 61.9MB) |
| v92 | Prod AdMob ID (ca-app-pub-6470338276121414/...); device_info_plus ile emÃ¼latÃ¶r algÄ±lama (emÃ¼latÃ¶rde reklam yok); pazarlÄ±k Ã§eÅŸitliliÄŸi: %6 zengin/%14 cÃ¶mert mÃ¼ÅŸteri rezervasyon sÃ¼rprizi, %10 bÃ¼yÃ¼k + %20 orta + %70 normal adÄ±m sÄ±Ã§ramasÄ± |
| v91 | AdMob interstitial reklam: her yeni gÃ¼n baÅŸÄ±na geÃ§iÅŸ reklamÄ± (game over deÄŸilse). ReklamServisi sÄ±nÄ±fÄ±, Kotlin 2.1.0'a yÃ¼kseltildi (transitive webview_flutter baÄŸÄ±mlÄ±lÄ±ÄŸÄ± iÃ§in) |
| v90 | "VazgeÃ§" â†’ "Reddet" (altbar + popup); Maliyet fontu Piyasa ile eÅŸitlendi (RichText, fontSize 14, w600); "el konsolu" â†’ "El Konsolu"; alÄ±cÄ±ya kolonya sonrasÄ± 6 random mesaj (tekrar engelli, X = orijinal Ã¼rÃ¼n adÄ±) |
| v89 | Asset optimizasyonu: bgbos/bg1/bg2/bgbosmasa/anamenu/browser/biri resize+recompress (APK 70.8MB â†’ 36.1MB); pubspec wildcard â†’ explicit list; Skia rendering (EnableImpeller=false) â€” emÃ¼latÃ¶r ANR Ã§Ã¶zÃ¼mÃ¼; Kolonya Tut butonu altbar'a taÅŸÄ±ndÄ± (parlak amber, beyaz yazÄ±), eski yerleÅŸik widget kaldÄ±rÄ±ldÄ± |
| v88 | Kolonya butonu tasarÄ±m: 0xFFE6A800 (parlak amber), beyaz yazÄ±; gun=3 sonrasÄ± gÃ¶sterilir; aktif/pasif state |
| v87 | Kurye Ã¶zel mÃ¼ÅŸteri: YeSekSepeti kuryesi, 3 farklÄ± selamlama, EVET/HAYIR, 3sn gecikme, kurye bonusu; durum.png Ã¼rÃ¼n gÃ¶rseli |
| v86 | Krediyi Al â†’ Tebrikler popup (3 sn otomatik kapanÄ±r) |
| v85 | Banka kredisi popup yeniden yazÄ±ldÄ±: gÃ¼n Ã§arpanÄ±, ok butonlarÄ±, faiz hesabÄ±, kredi geÃ§miÅŸi taksit limiti |
| v84 | Kabul Et butonu alÄ±cÄ± mÃ¼ÅŸteriler iÃ§in de Ã§alÄ±ÅŸÄ±r hale getirildi |
| v83 | DÃ¼kkan kiralama gÃ¼n koÅŸullarÄ±, kilitli dÃ¼kkan %50 opaklÄ±k + ğŸ”’, otomatik kapanan popup |
| v82 | Kolonya widget %15 kÃ¼Ã§Ã¼ltÃ¼ldÃ¼, yarÄ±m kolonya boyu aÅŸaÄŸÄ± |
| v81 | Kolonya envanter slotu kullanmaz, +1 Ã¶zel kart olarak gÃ¶sterilir |
| v80 | Kolonya 2x bÃ¼yÃ¼k 1.5x yukarÄ±; Ã¶zel mÃ¼ÅŸterilere kolonya ikramÄ± Ã¶zel mesaj+gÃ¶nder |
| v79 | 1. gÃ¼nde iflas: bilgisayar popup gelmez, arka plan deÄŸiÅŸmez |
| v78 | Kolonya Ã¼rÃ¼nÃ¼: satÄ±cÄ± mÃ¼ÅŸteri, 10 kullanÄ±m, saÄŸ widget, pazarlÄ±k bonusu |
| v77 | Bilgisayar Geldi popup: emoji Ã¼ste, 6 rastgele mesaj |
| v76 | Kabul Et butonu pazarlÄ±k popup dÄ±ÅŸÄ±na taÅŸÄ±ndÄ± |
| v70 | Envanter kompaksiyon, daire sayaÃ§, pixel butonlar, balon gÃ¶rseli, yeÅŸil tÄ±klanabilir balon |

## Yeni Eklenen Alanlar (_GameScreenState / GameState)

```dart
// _GameScreenState
String? _kolonyaGeciciMesaj;   // 3 sn gÃ¶sterilen Ã¶zel mesaj (teÅŸekkÃ¼rler)
Timer? _kolonyaMesajTimer;
Timer? _kuryeTimer;
int _kolonyaSonrasiSonIdx = -1; // alÄ±cÄ±+kolonya sonrasÄ± random mesaj tekrar engeli

// GameState
int para = 1000;                  // baÅŸlangÄ±Ã§ parasÄ± (eskiden 500)
String? _sonUrunId;               // ardÄ±ÅŸÄ±k aynÄ± Ã¼rÃ¼n engeli
bool kuryeBonusuAktif = false;    // bir sonraki mÃ¼ÅŸteri Ã§ok avantajlÄ± olacak
int kolonyaKullanim = 0;          // 0-10
bool kolonyaIkramEdildi = false;
double _kolonyaPendingBonus = 0.0;
List<OzelMusteriTip> _ozelTipSirasi; // [hirsiz, polis, vergici, kurye]
```

## KayÄ±t Migrasyonu (fromJson)

Eski kayÄ±tlar iÃ§in gÃ¼venli yÃ¼kleme:
- `ozelTipSirasi` yoksa default sÄ±ra atanÄ±r
- Eksik tipler (kurye gibi yeni eklenen) otomatik sÄ±raya eklenir
- `firstWhere` `orElse` ile crash Ã¶nlenir
- `_devamEt()` iÃ§inde try/catch + bozuk kayÄ±t iÃ§in "KayÄ±t OkunamadÄ±" popup'Ä±

## Dikkat Edilecekler
- `main.dart` tek ve bÃ¼yÃ¼k bir dosya â€” refactor Ã¶nerilmez, performans yeterli
- MÃ¼ÅŸteri gÃ¶rseli **masa layer'Ä±nÄ±n altÄ±nda** olmalÄ± (Z-order kritik)
- `_bilgisayarGeldiGosterildi` flag'i state'de deÄŸil widget'ta â€” her oyun baÅŸÄ±nda sÄ±fÄ±rlanÄ±r, intentional
- `konsol_3/4/5/6.png`, `oyuncudireksiyonu.png`, `joypad.png` Ã¼rÃ¼nleri %15 kÃ¼Ã§Ã¼k gÃ¶sterilir â€” intentional
- `durum.png` (kurye dÃ¼rÃ¼mÃ¼) %20 kÃ¼Ã§Ã¼k â€” intentional
- TÃ¼m "SON DEÄER â€” DOKUNMA!" yorumlarÄ± uzun iterasyonlar sonucu bulunmuÅŸtur, deÄŸiÅŸtirmeden Ã¶nce mutlaka test et
- Worktree'den deÄŸil her zaman **main repo'dan** (`C:\src\oyuncu_dukkani`) derle â€” worktree dalÄ± eski commit'ten baÅŸlayabilir
- Kolonya butonu iÃ§in `kolonyaKullanim > 0` koÅŸulu â€” buton sadece kolonyacÄ±dan kolonya alÄ±ndÄ±ktan sonra gÃ¶rÃ¼nÃ¼r
- Asset deÄŸiÅŸikliÄŸi sonrasÄ± **build clean** gerekmez ama install iÃ§in `-r` flag'ini unutma
- EmÃ¼latÃ¶r tÄ±kanÄ±rsa Cold Boot â€” saatlerce install/uninstall yapÄ±ldÄ±ysa system_server kÃ¶tÃ¼leÅŸir


