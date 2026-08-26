---
# Oyuncu Dükkanı — Claude Bağlamı

## 🚨 MARKET BUILD ÖNCESİ ZORUNLU KONTROL (KULLANICI KURALI)
**Herhangi bir market çıktısı (AAB / IPA / appbundle / App Store / Play Store build) hazırlamadan ÖNCE:**
1. Kodda Google TEST reklam ID'si (`ca-app-pub-3940256099942544/...`) kaldı mı KONTROL ET
   - `grep "3940256099942544" lib/main.dart` ile bak
2. Test ID kaldıysa → **MARKET BUILD VERME**, önce kullanıcıdan gerçek (prod) AdMob ID'lerini iste ve değiştir
3. Bu kural TÜM uygulamalar için geçerli (oyuncu_dukkani, snapiq, matematikcik, magnus...)

**Mevcut PROD reklam ID'leri (oyuncu_dukkani):**
- iOS geçiş: `ca-app-pub-6470338276121414/1436676062`
- Android geçiş: `ca-app-pub-6470338276121414/4138047986`
- iOS ödüllü (henüz kullanılmıyor): `ca-app-pub-6470338276121414/2648809677`

---

## Proje Özeti
Flutter ile geliştirilmiş bir mobil oyun. Oyuncu bir oyun dükkanı yönetir: müşteri kabul eder, pazarlık yapar, envanter yönetir, dükkanını büyütür.

## Teknik Yığın
- **Flutter** (Dart) — tek dosya mimarisi: `lib/main.dart`
- **Android** — paket adı: `com.oyuncudukkani.app`
- **pubspec.yaml** — versiyon: `1.0.2+13`
- Paketler: `audioplayers`, `shared_preferences`, `google_mobile_ads`, `device_info_plus`, `app_tracking_transparency`, `device_preview` (dev), `flutter_launcher_icons` (dev)
- **Kotlin**: 2.1.0 (Android `settings.gradle.kts`)
- **App Store**: YAYINDA → https://apps.apple.com/us/app/oyuncu-dükkanı/id6778437262

## Dosya Yapısı
```
lib/main.dart          — oyun mantığının tamamı
lib/kirgec_oyunu.dart  — KIRGEÇ mini oyunu (breakout, oynanabilir CD)
lib/itele_oyunu.dart   — İTELE mini oyunu (pong, oynanabilir CD)
lib/tisss_oyunu.dart   — TISSS mini oyunu (yılan, oynanabilir CD)
assets/                — görseller ve sesler
  bg1.png              — masa (bilgisayarsız)
  bg2.png              — masa (bilgisayarlı / iMac alındıktan sonra)
  bgbos.png            — dükkan arka planı (seviye 1)
  bgbos_2/3/4.jpg      — seviye 2/3/4-5 arka planları (JPEG: opak, PNG'de 6.5MB olurdu)
  bgbosmasa.png        — masa (3. günden önce)
  kapidaki.png         — kapıda bekleyen silüet (müşteri yokken; dükkana göre konumlanır)
  musteri_1..46.png    — müşteri karakterleri (46 adet, yaş/cinsiyet musteriHavuzu içinde)
                         musteri_43/44/45 SABİT adlı (Recai Carlos, Kahraman Memo, Şakir Oneyıl)
  hirsiz/polis/vergici/kurye/toptanci/falci/guvenlik.png — özel müşteri karakterleri
  hande.png            — Rehber Hande (oyunun başındaki tanıtım karakteri)
  dukkan_<ad>.jpg      — dükkan arka planı (bodrum/mahalle/cadde/carsi/avm + satilik1..5)
  dukkan_<ad>_guv.jpg  — aynı dükkanın GÜVENLİKLİ sürümü (kapıda güvenlik durur)
  CD_1..46.png         — 46 CD ürünü (CD_15/16/17 = KIRGEÇ, İTELE, TISSS: oynanabilir)
  konsol_1..19.png     — 19 konsol ürünü (PlayStatyon, Ninetendo, Ateri, El Konsolu ×12,
                         Masaüstü Konsol ×3, son sistem)
  joystick.png         — arcade joystick (v110 aksesuarı)
  vrgozluk / kulaklik_1-2 / kumanda_2 / direksiyon_2 / oyuncumausu — v109 aksesuarları
  durum.png            — kurye'nin getirdiği yemek görseli
  kolonya.png          — kolonya görseli (envanter + buton ikonu)
  oyuncu_dukkani_icon.png  — uygulama ikonu kaynağı
  anamenu.png          — ana menü arka planı
  oyuncudireksiyonu, joypad, gamepad, lokum, browser, zarf, 3dgozluk — aksesuar/CD
android/               — native Android yapılandırması
```

## Oyun Mimarisi (main.dart)

### Akış
```
SplashScreen (6 sn yasal metin)
  → AnaMenuEkrani (başla / devam)
    → GameScreen (ana oyun döngüsü)
```

### Temel Sınıflar
- `GameState` — tüm oyun durumu (ChangeNotifier), SharedPreferences ile kayıt
- `GameScreen` / `_GameScreenState` — UI ve animasyonlar
- `Musteri` / `OzelMusteri` — müşteri modeli
- `DukkanSeviye` — dükkan seviyeleri (1-5, farklı kira ve müşteri sayısı)

---

## 👥 KARAKTER HAVUZU (v103)

**46 müşteri görseli** (11 eski + 17 v103 + 6 v110 + 8 v112 + 4 v113). Dağılım: **24 erkek, 22 kadın**.

> ⚠️ **Sabit adlı karakterler**: `musteriHavuzu` satırında `'ad'` alanı doluysa
> rastgele isim havuzundan isim ÇEKİLMEZ. `musteri_43` = Recai Carlos,
> `musteri_44` = Kahraman Memo, `musteri_45` = Şakir Oneyıl. Bu kişiler her
> gelişlerinde aynı adla tanınır.
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
---

---

## 📚 v117 — KOLEKSİYON ARTIK KAZANILIYOR

Eskiden koleksiyon **otomatik** doluyordu: satılan her ürün kendiliğinden
açılıyordu (`satilanUrunIdleri`). Karar yoktu, dolayısıyla değeri de yoktu.
Artık koleksiyona girmenin **tek yolu** bir ürünü satmak yerine oraya koymak.

| | Eski | Yeni |
|---|---|---|
| Dolma | satılan ürün otomatik açılır | envanterden elle taşınır |
| Kutu sayısı | ürün sayısı kadar (58) | sabit **60** (6×10) |
| Sütun | 8 (küçük kutu) | **6** (büyük kutu) |
| Yer | Hedefler listesinin sonunda bir panel | ayrı **KOLEKSİYON sekmesi** |

```dart
const int kKoleksiyonSutun = 6;
const int kKoleksiyonKutuSayisi = 60;

Set<String> koleksiyondakiler;      // ürün id'leri (Set: aynı üründen 2. kopya şişirmesin)
Set<String> koleksiyonOdulAlinan;   // ödülü ödenmiş hedefler
bool koleksiyonaTasi(GameItem);     // slottan çıkarır, kutuya koyar
bool koleksiyonaKonabilir(GameItem);
int  koleksiyonOdulleriTopla();     // tamamlanan hedeflerin ödülünü öder, toplamı döner
```

- Envanterdeki ürüne dokununca çıkan büyütmede **"📚 Koleksiyona Taşı"**,
  Çöpe At / Kapat satırının **üstünde**, tam genişlikte.
- Onay isteniyor — geri dönüşü yok, ürün bir daha satılamaz.
- Taşıma sonrası `koleksiyonOdulleriTopla()` çağrılıyor; hedef tamamlandıysa
  para toast'ta duyuruluyor.

> ⚠️ `satilanUrunIdleri` **silinmedi**: "koleksiyoncu" rozeti (10 farklı ürün
> sat) hâlâ ona bakıyor. Sadece koleksiyon tablosuyla bağı kesildi.

### 🎯 Koleksiyon hedefleri
`class KoleksiyonHedefi` — 12 hedef, tablonun altında ilerleme çubuğuyla.
Ödüller 150-6000 lira; her hedef **bir kez** ödenir (`koleksiyonOdulAlinan`).
İlerleme `int Function(GameState)` ile hesaplanıyor, sayaç tutulmuyor —
koleksiyon değişince hedefler kendiliğinden güncel.

### ⚠️ `_hedefSekme` widget'ta duramaz
Browser gövdesi her karede baştan çalışıyor (banka sayfasıyla aynı sebep).
Sekme durumu `_GameScreenState._hedefSekme`'de; sekme butonu dialogun kendi
`setDlg`'ini çağırıyor, `setState` değil.

---

## 🚗 v118 — GALERİCİ GÜRBÜZ + ARAÇLAR

Yeni özel müşteri: **Galerici Gürbüz** (`galerici.png`, Gürbüz Oto Galeri).
**4. günden itibaren 3 günde bir** (4, 7, 10…) günün 2. müşterisi olarak gelir;
rotasyona GİRMEZ (Rıza gibi kendi programı var).

> "Selamın Aleyküm, ben Gürbüz, Gürbüz Oto Galeri'nin sahibi. Araç lazım mı?
> Ne verelim abime?"

Alt barda EVET/HAYIR yerine **"Araç Seç" / "Vazgeç"** çıkar. Araç Seç →
tezgâh popup'ı (5 araç, fiyat + geçiş süresi). Araca tıklanınca
`GameState.galericiAracSec`: özel müşteri **sıradan bir SATICI müşteriye
dönüşür** ve normal pazarlık başlar — ayrı satın alma yolu yok. Alınan araç
envantere girer.

```dart
class Arac { GameItem item; int gecisSaniye; static List<Arac> tumu; }
enum ItemCategory { cd, konsol, aksesuar, arac }   // arac EKLENDİ
```

| id | Ad | Görsel | Fiyat | Geçiş |
|---|---|---|---|---|
| arac1 | Kızıl Şimşek | arac_1 (kırmızı hatchback) | 9000 | 35 sn |
| arac2 | Amiral 500 | arac_2 (lacivert sedan) | 14000 | 30 sn |
| arac3 | Sarı Melek | arac_3 (bej klasik) | 6000 | 45 sn |
| arac4 | Vınn Motor | arac_4 (turkuaz scooter) | 3000 | 120 sn |
| arac5 | Yol Kartalı | arac_5 (touring motosiklet) | 11000 | 75 sn |

- Araçlar `_baslangicUrunler`'de DEĞİL: müşteriler araç almaz/satmaz,
  toptancı/kutudan çıkmaz, **koleksiyona konamaz** (`koleksiyonaKonabilir`).
- `_rotasyonDisi` seti: toptanci, guvenlik, galerici, hande — rotasyon
  migrasyonu artık bu kümeden okunuyor (hande sızması da böylece kapandı).
- Kırmızı araba beyaz zeminli geldi → `arkaplan_sil.ps1` + köşedeki leke
  elle temizlendi; 5'i de `ekipman_hat.ps1` (500px, 0.90 doluluk) hattından.

## 🏠 v118 — KONUM DEĞİŞTİR + EV + YAZLIK

Browser menüsünde **"Konum Değiştir"** — envanterde ARAÇ yoksa kilitli
("Envanterde 1 araç olması gerekmekte."). Market'e **Ev (10000)** ve
**Yazlık (12000)** kartları eklendi; satın alınca "artık konum
değiştirebilirsin" bildirimi.

### Geçiş (yolculuk)
- "Hangi konuma gitmek istersin?" → Ev / Yazlık kutuları (alınmamış pasif).
- Süre envanterdeki **en hızlı** aracın `gecisSaniye`'si. Toast: "Geçiş başladı..."
- Sahnenin solunda küçük araç görseli + **saat yönünün TERSİNE** dönen halka
  (`_GecisHalkaPainter`, negatif açı) + kalan saniye. Halkanın yay uzunluğu
  ilerlemeyle büyür.
- Bitince: dükkanda müşteri VARSA popup bekletilir (700ms'de bir yoklanır);
  boşken "Geçiş işlemleri gerçekleşti. Eve geçmek istiyor musun?" → Evet =
  konuma geçilir. Evden dükkana dönünce süreç baştan işler.
- ⚠️ `aktifKonum` kayıtta `dukkan`a ZORLANIR — evde kapatılan oyun dükkanda
  açılır, yolculuk oturum içi bir durumdur.

### Ev / Yazlık sahnesi
`_buildEvEkrani()`: header (para+gün animasyonlarıyla) AYNEN korunur, altta
**Eşya Al / Çıkış**. Eşyalar arka planın `BoxFit.cover` kutusuna oranla
çizilir (sabit piksel yok).

**İki yerleştirme biçimi** (`EvEsyasi.tamKatman`):
- **Ev** (`Ev1` klasörü): eşya PNG'leri alfa kutusuna kırpıldı
  (`tools/kirp.ps1`), konumlar `doluev.png` üzerinden %5 ızgarayla ölçülüp
  `tools/evkompozit.ps1` ile bosev üstüne çizdirilerek doğrulandı. 9 eşya
  (vazo, tv, lambader, 2 tekli, orta sehpa, 2 yan sehpa, ikili koltuk;
  `EvEsyasi.tumu` sırası = ÇİZİM sırası, arkadakiler önce).
- **Yazlık** (`yazlik_ev_katmanli.ora`): OpenRaster; 13 katman TAM TUVAL
  (942×1669) → konum hesabı yok, katman arka plana `BoxFit.fill` ile birebir
  serilir. 12 eşya `yazlik_01..12.png` (719px), tezgâh önizlemesi için ayrıca
  kırpılmış `yazlik_XX_k.png` kopyaları var (`EvEsyasi.ikon`) — tam tuval
  küçük kutuda görünmezdi. Sıra stack.xml'in TERSİ (üstteki katman en sonda).

> ⚠️ PowerShell tuzağı: değişken adları büyük/küçük harf DUYARSIZ —
> `evkompozit.ps1`'de içteki `$w` dıştaki `$W`'yi ezip tüm eşyaları 0
> boyuta düşürmüştü. İç değişkenler `$px/$py/$pw/$ph` yapıldı.

`test/arac_ev_test.dart` — 20 test (araçlar, Gürbüz dönüşümü, rotasyon
temizliği, ev/yazlık satın alma, eşya konum aralıkları, kayıt turları).
Emülatörde uçtan uca doğrulandı (galerici pazarlığı, yolculuk halkası,
ev + yazlık döşemesi).

---

## 🩹 v117 — DİĞER DÜZELTMELER

### Süreli bildirim müşteriyi tutuyor
Seri/hedef toast'ı okunurken müşteri kayıp gidiyordu. Artık çıkış toast'ı
**bekliyor**; toast kapanır kapanmaz gitmeye başlıyor.

```dart
VoidCallback? _toastSonrasiIs;
void _toastBitinceCalistir(VoidCallback is_);   // toast yoksa hemen çalışır
```

Bağlandığı üç çıkış: anlaşma sonrası (`_pazarlikGoster`), ana ekrandaki
`_kabulEt`, ve tüm özel müşteriler (`_ozelMusteriGonder`).
Toast süresi **2400 → 4200 ms** (günün hedefi bildirimi çok kısa kalıyordu).

### Masadaki oynanabilir oyun belli oluyor
Ürün büyütmesinde (`_urunGorseliBuyut(gorsel, oynanabilir: ...)`) görselin
altında **"⭐ Oynanabilir Oyun!"** ve *"Bu oyun satın alındığında Oyuncu
Dükkanı'nda başlatılıp oynanabilir."* Satın almadan önce görünsün diye —
hem masadaki üründe hem Toptancı Rıza'nın tezgâhında.

### Yeniden Başlat → ANA MENÜ
Eskiden `pushReplacement` ile doğrudan yeni oyunu açıyordu. Artık
`pushAndRemoveUntil` ile ana menüye dönülüyor; oyuncu "Başla"ya kendisi
basıyor. Butonlar da `dialogButonlari()` diline geçti.

### Banka
- **3. günden önce kilitli** (menüde "3. günde açılır" altyazısı).
- Max taksit **3/6/9 → 6/8/10** ("3 çok az").

### Browser menü sırası
Hedefler en üste alındı (altyazısı rozet + koleksiyon sayısını gösteriyor).
Satılık Dükkanlar ikonu 🔑 → **🏡** (anahtar kiralıkla karışıyordu).

---

## 👩‍🏫 v114 — REHBER HANDE (açılış tanıtımı)

Oyunun **en başında**, "Müşteri Çağır"a basılmadan kendiliğinden gelen tanıtım
karakteri. Alış/satış yapmaz; dört repliği sırayla anlatıp gider.

- Tetikleyici: `initState` içinde `widget.yeniOyun && !handeGosterildi`
  (700ms gecikme — sahne otursun, kapı sesi üst üste binmesin).
- Alt barda **tek ve geniş "Tamam"** butonu çıkar; EVET/HAYIR, pazarlık ve
  Müşteri Çağır/Envanter satırı gizlenir (`_state.handeAktif`).
- Her "Tamam" `handeIlerle()` çağırır; `false` dönerse (replikler bitti)
  `_ozelMusteriGonder()` ile sağdan çıkar ve normal akış başlar.
- **Müşteri sayacına dokunmaz** — Hande bir ziyaret değil, oyunun girişi;
  günlük müşteri hakkını yemesi haksızlık olur.
- `handeGosterildi` kayıtta saklanır. ⚠️ Eski kayıtlarda alan yoksa
  **`true`** kabul edilir: yıllardır oynayan birine tanıtım açılmasın.

Replikler `OzelMusteri.handeReplikleri` içinde (4 adet); `OzelMusteri.hande()`
fabrikası ilk repliği başlangıç mesajı yapar.

> `guvenlik` gibi `hande` de özel müşteri ROTASYONUNA girmez — rotasyon
> `_ozelTipSirasi`'ndan geliyor, oraya hiç eklenmiyor.

---

## 💰 v114 — PARA SAYACI ANİMASYONU

Satış/alım anı gözden kaçmasın diye bakiye kutusu canlanıyor:

| Aşama | Görünüm |
|---|---|
| Sayım (%0–72) | Kutu büyür, **yeşil** (giriş) / **kırmızı** (çıkış) olur, rakamlar eski değerden yenisine SAYARAK ilerler |
| Dönüş (%72–100) | Renk ve boyut normale solar, değer hedefte kalır |

Toplam süre **2.2 sn**. Renkler referanstaki gibi: `0xFF3CC850` yeşil,
`0xFFF84C4C` kırmızı; vurgu sırasında yazı siyaha döner (renkli zeminde
okunur kalsın).

```dart
int get _gosterilenPara { ... }        // sayım sırasında ara değer
void _paraDegisimKontrol() { ... }     // _state listener'ı
```

- Kutu `AnimatedBuilder(animation: _paraController)` ile sarılı — sadece o
  parça yeniden çiziliyor, tüm header değil.
- ⚠️ Animasyon ortasında yeni bir para değişimi gelirse sayım **ekrandaki
  değerden** devam eder (`_paraBaslangic = _gosterilenPara`); yoksa sayı geri
  sıçrardı.
- Ölçek `1 + 0.16 * sin(pi * t)` — tek tepe, kendiliğinden normale döner.

### 🗓️ Gün sayacı da aynı dilde (v115)
Yeni güne geçişte gün kutusu da büyüyor, **yeşile** dönüyor ve sayı değişip
normale soluyor — para kutusuyla aynı zamanlama (`_paraSayimOrani`, 2.2 sn).

> ⚠️ Fark: gün hep **+1** arttığı için "sayma" işe yaramaz, arada
> gösterilecek ara değer yok. Onun yerine **odometre dönüşü**: eski gün
> yukarı çıkıp kaybolurken yeni gün alttan geliyor (`_gunYazisi`,
> `ClipRect` + iki `Text`, biri `-yuk*d` diğeri `+yuk*(1-d)` ofsetli).

### Tamir Et butonu koyu maviye alındı
`0xFF58a6ff` → `0xFF1E63C8`, yazı beyaz. 🔧 emojisi gri olduğu için açık mavi
zeminde kayboluyordu.

---
---

## 🛡️ v113 — YAKIŞIKLI GÜVENLİK

Yeni özel müşteri. **3. günde bir kez** gelir (günün 3. müşterisi olarak);
HAYIR denirse 3'ün katlarında (6, 9, 12…) tekrar dener. Kabul edilirse bir
daha teklif gelmez.

> "Merhaba, ben Yakışıklı Güvenlik. Günde 50 liraya senin için çalışırsam,
> bu dükkana hırsız giremez. İster misin?"

| Durum | Sonuç |
|---|---|
| **EVET** | Arka plan `arkaplanGuv` sürümüne geçer, **hırsız bir daha gelmez** |
| **HAYIR** | Küsmeden gider, 3'ün katlarında tekrar sorar |
| Ücret ödenemezse | Gün sonunda işi bırakır (`guvenlikIsiBirakti` bayrağı) |

Ücret (`guvenlikGunlukUcret` = 50) her gün kirayla birlikte kesilir.

### Hırsız engelleme — üç ayrı yol kapatıldı
1. **Rotasyon**: sıra hırsıza gelirse rotasyonda ilerlenip başka tip seçilir.
2. **Falcı kehaneti**: "hırsız gelecek" kehaneti tüketilir ama hırsız gelmez.
3. **Rotasyona sızma**: `guvenlik` tipi `_ozelTipSirasi`'na hiç eklenmez
   (Rıza gibi kendi programı var). Eski kayıtlardan sızmışsa temizlenir.

### 🪤 İki güvenlik tuzağı
Güvenliğe dokununca müşteri gibi öne gelir ve *"İşi bırakmamı ister misin?"*
diye sorar. Ama güvenlik **arka planın parçası** — öne gelirken arka plan
güvenlikli kalırsa ekranda AYNI ANDA İKİ güvenlik olur.

Çözüm: `_guvenlikOnde` bayrağı. `aktifArkaplan` bu bayrak doluyken güvenliksiz
sürümü döndürür; `musteriAnimasyonBitti()` bayrağı sıfırlar.

```dart
String get aktifArkaplan =>
    (guvenlikVar && !_guvenlikOnde) ? aktifDukkan.arkaplanGuv : aktifDukkan.arkaplan;
```

### Geliş/gidiş animasyonu — güvenlik sağdan KAYMAZ
Güvenlik dükkanın içinde zaten duruyor; normal müşteriler gibi sağdan kayıp
gelmesi/gitmesi yanlış olurdu. Tek controller (`_guvenlikBelirmeController`,
480ms) iki yönde çalışıyor — gidiş, gelişin birebir tersi:

| Yön | Görünüm |
|---|---|
| `forward` (dokununca) | Yukarıdan belirir, aşağı iner, **büyüyerek** tezgâha gelir |
| `reverse` (HAYIR) | Aynı hareketin tersi: küçülerek yukarı süzülüp kaybolur |

```dart
// 0 = kapıdaki yerinde (görünmez), 1 = tezgâhta (tam görünür)
final t = Curves.easeOutCubic.transform(_guvenlikBelirmeController.value);
Opacity(opacity: t,
  child: Transform.translate(offset: Offset(0, -130 * (1 - t)),
    child: Transform.scale(scale: 0.78 + 0.22 * t, child: child)));
```

- Dönüşüm **sadece** güvenlik öndeyken uygulanır (`om.istifaSorusu`); diğer
  müşteriler etkilenmez, yoksa hepsi `t == 0`'da görünmez olurdu.
- `_guvenligeDokun` yatay konumu `_slideController.value = 1.0` ile doğrudan
  "ortalanmış"a atlatır (animasyonsuz). Değeri set etmek yine de şart: **EVET**
  (istifa) seçilirse güvenlik gerçekten gidiyor ve çıkış o controller'ın
  `reverse`ıyla sağa doğru oynatılıyor.
- HAYIR'da kaybolduğu anda arka plan güvenlikli sürüme döndüğü için yerine
  geçmiş gibi görünüyor. Replik okunabilsin diye 900ms beklenip başlıyor.

### 🪤 Dokunma alanı Stack'in EN SONUNDA olmalı
Güvenlik ayrı bir sprite değil, arka planın içinde. Dokunmak için görünmez bir
kutu, kapı silüetiyle **aynı cover matematiğiyle** konumlanıyor.

> ⚠️ Kutu arka planın hemen üstüne konunca dokunuş HİÇ ULAŞMIYOR: Stack'te
> **sonra gelen çocuk önce hit-test edilir**, yani masa katmanı ve SafeArea
> dokunuşu yutuyordu. Katman Stack'in en sonuna alınınca çalıştı.
> (Kutu küçük ve sahnenin üstünde; alt bar/header/browser düğmesiyle çakışmıyor.)

```dart
static const kGuvenlikSol = 0.45, kGuvenlikUst = 0.11;
static const kGuvenlikGen = 0.21, kGuvenlikYuk = 0.34;
```

---

## 🔑 v113 — SATILIK DÜKKANLAR

Browser menüsünde yeni bölüm. **5. günden önce kilitli** (soluk + kilit ikonu,
tıklanamaz). Kiralıklardan farkı: dükkan **satın alınır**, günlük kira YOK.

| Dosya | Oyundaki ad | Fiyat |
|---|---|---|
| `satilik1` | Fakir Dükkan | 5000 |
| `satilik2` | Derme Çatma Dükkan | 7000 |
| `satilik3` | Lüks Dükkan | 10000 |
| `satilik4` | Klas Dükkan | 13000 |
| `satilik5` | Rezidans Dükkanı | 20000 |

- Satın alınca **otomatik taşınılmaz** — dükkan senin olur, geçiş ayrı karar.
- Sahip olunan dükkana tekrar tıklanınca: *"Bu dükkana geçmek mi kiraya vermek
  mi istiyorsun?"*
- **Kiraya verme geliri**: bedelin %1'i / gün (Fakir 50, Rezidans 200).
  `gunuBitir()` içinde kasaya eklenir.
- Oturulan dükkan kiraya verilemez; kiradaki bir dükkana taşınınca kira biter.

### ⚠️ Dükkan artık İSİMLE saklanıyor
Satılık dükkanlar kiralıklarla aynı `seviye` değerini paylaşabildiği için
seviye indeksi tek başına yetmiyor. `toJson`/`fromJson` `aktifDukkanIsim`
kullanıyor; eski kayıtlarda sadece `aktifDukkanSeviye` olduğu için ona düşülür.

---

## 🏠 v113 — DÜKKAN GÖRSELLERİ DOSYA ADIYLA EŞLEŞTİ

Eski `bgbos*.png/jpg` isimleri kaldırıldı. Artık her dükkanın adıyla eşleşen
iki dosyası var: `dukkan_<ad>.jpg` ve `dukkan_<ad>_guv.jpg`.

**Sanat eşleşmesi görsel imza karşılaştırmasıyla doğrulandı** — ölçüleri
yeniden ölçmek yerine taşımak için:

| Yeni dosya | Eski karşılığı | Kapı ölçüsü |
|---|---|---|
| `dukkan_bodrum` | `bgbos.png` | aynen korundu |
| `dukkan_mahalle` | `bgbos_2.jpg` | korundu (+ v113'te %10 aşağı) |
| `dukkan_cadde` | **`bgbos_4.jpg`** | bgbos_4'ün ölçüleri taşındı |
| `dukkan_avm` | **`bgbos_3.jpg`** | bgbos_3'ün ölçüleri taşındı |
| `dukkan_carsi` | YENİ sanat | yeniden ölçüldü |

> ⚠️ Eşleşme KAYDI: v111'de "seviye 3"e yapılan %15 genişletme artık **AVM**'ye
> ait; Cadde eski bgbos_4 ölçüleriyle gidiyor. Karıştırma.

### 🪤 Güvenlikli görselin kapısı kayabilir — `kapi*GuvFark`
Güvenlikli sürüm aynı dükkanın **yeniden çizimi**; kapı camı bir miktar
kayabiliyor. Tek kapı ölçüsü ikisine birden dayatılınca silüet güvenlik
açıkken camdan taşıyor.

`DukkanSeviye.kapiSolGuvFark` / `kapiUstGuvFark` bu farkı tutuyor (varsayılan
0). `_buildKapidaki` ekranda hangi arka plan varsa ona göre ekliyor:

```dart
final guv = _state.guvenlikVar;
final kapiSol = d.kapiSol + (guv ? d.kapiSolGuvFark : 0);
final kapiUst = d.kapiUst + (guv ? d.kapiUstGuvFark : 0);
```

> İki değerin ORTALAMASINI almak yerine fark tutuluyor — ortalama, iki
> görselde de yanlış olurdu. Şu an sadece **Mahalle** kullanıyor
> (-0.010 / -0.006); güvenlikli çizimi yenilendiği için camı kaymıştı.

Çarşı + 5 satılık dükkanın kapı camı tek tek ölçüldü: her görsel **tek başına**
900px panelde %1'lik ızgarayla okundu, sonra dikdörtgen görselin üstüne
çizdirilip gözle doğrulandı. (Otomatik parlaklık tabanlı ölçüm yine duvarı cam
sandı — CLAUDE.md'deki uyarı hâlâ geçerli, tek başına güvenme.)

> Arka planlar **JPEG q92, 719px genişlik**. 20 dosya toplam ~4.8MB; PNG
> bırakılsa ~42MB olurdu.

---

## 🎨 v113 — DİĞER DEĞİŞİKLİKLER

### Toptancı Rıza renkleri
Tezgâhtaki kartlar tipe göre mavi/mor/kırmızı/sarı çerçeve ve buton
kullanıyordu, tezgâh rengarenk görünüyordu. Artık **hepsi sarı**
(`tezgahRenk` = `0xFFd29922`) — çerçeve ve buton. `renk` değişkeni hâlâ tipe
özel ama sadece alt bilgi yazısında (ör. çürükte kırmızı "Tamir edilebilir").

Envanter kartlarının çerçevesi **turkuaz** (`0xFF40E0D0`) — hangi listeye
bakıldığı bir bakışta belli olsun. ÇÜRÜK kırmızı, oynanabilir camgöbeği kalır
(ikisi de bilgi taşıyor).

### Çürük ürün ekranı
Sağlam üründeki büyütmeyle aynı dile getirildi: büyük görsel (soluk) + ÇÜRÜK
rozeti + fiyat karşılaştırması, altında **Çöpe At / Tamir Et** yan yana, en
altta iki butonun genişliğinde **Kapat**.

### İTELE topu %30 daha hızlı
İki turda hızlandı: önce %20 (46→55.2), sonra %30 daha (→71.8). Üçü de aynı
oranla büyütüldü ki denge bozulmasın: başlangıç 71.8, vuruş başı artış 1.87,
tavan 137.3.

### 9 yeni ekipman + 4 yeni karakter
Ekipman: 3 masaüstü konsol (`konsol_20..22`), `SikstenDo GaMboy`
(`konsol_23`), `SkeymDeck` (`konsol_24`), `Cicitech Mouse`,
`Gavrak Oyuncu Tutgacı`, `Şahan Oyuncu Seti`, `Sonya Kulaklık`.
Adlar kullanıcı tarafından verildi — büyük/küçük harfler bilerek böyle.

Karakter: `musteri_43..46` (üçü sabit adlı) + `guvenlik.png`.

> `YeniGames` klasöründe eklenmemiş oyun KALMADI (16 kaynak da oyunda).
> Ekipman hattı deterministik olduğu için md5 ile hangi kaynağın işlendiği
> tespit edilebiliyor; CD hattı değil, orada görsel karşılaştırma gerekiyor.

---

## 🐛 v112 — PAZARLIĞI DONDURAN clamp HATASI (EN ÖNEMLİSİ)

**Belirti (kullanıcı bildirimi):** "Teklif ver'e tıklayınca ne yazı değişiyor ne
yeni fiyat teklifi geliyor. Artırıp tekrar basıyorum, hiçbir şey olmuyor, ta ki
kabul edene kadar." Hem alırken hem satarken, genelde 4-5. turdan sonra.

**Kök neden:** `PazarlikSeans.oyuncuTeklifVer` adım 5'te karşı teklifi
hesaplarken:

```dart
// ESKİ — HATALI
yeniMusteriTeklif = (musteriTeklif - move)
    .clamp(_reservationPrice.ceil(), musteriTeklif - 1).toInt();
```

Müşterinin teklifi kendi rezervasyon sınırına dayandığında
`musteriTeklif - 1 < _reservationPrice.ceil()` oluyor. **Dart'ın `clamp`'i alt
sınır > üst sınır olduğunda `ArgumentError` ATAR.** İstisna `teklifVer`den yukarı
kaçıyor; pazarlık dialogu `finally` sayesinde kapanıyor (v105'te eklenmişti) ama
ne `mesaj` ne `musteriTeklif` güncelleniyor. `durum` da `devamEdiyor` kaldığı
için UI "Teklif Ver / Reddet"i tekrar gösteriyor → oyuncu aynı ekranı görüyor.
Teklifi müşterininkini geçince adım 1 (`_kabul`) clamp'e hiç ulaşmadan
devreye girdiği için "birden bire tamam deyip gidiyor".

**Düzeltme:** clamp'i çağırmadan ÖNCE kıpırdayacak yer var mı diye bak; yoksa
zaten sınırdayız demektir, `atFloor` dalına düşsün (orada kabul/git kararı var).

```dart
final rezervAlt = _reservationPrice.ceil();   // satıcı müşterinin tabanı
final rezervUst = _reservationPrice.floor();  // alıcı müşterinin tavanı
final yerKaldi = musteriSatiyor
    ? (musteriTeklif - 1) >= rezervAlt
    : (musteriTeklif + 1) <= rezervUst;
// yerKaldi false → yeniMusteriTeklif = musteriTeklif, atFloor = true
```

> ⚠️ **Aynı sınıftaki diğer iki clamp GÜVENLİ, dokunma:** sıkıştırma dalındaki
> `ortaNokta.clamp(oyuncuTeklif + 1, musteriTeklif)` (ve simetriği) adım 1'in
> `return`'ü sayesinde `oyuncuTeklif < musteriTeklif` garantisiyle çalışıyor.

**Regresyon testi:** `test/pazarlik_test.dart` (6 test). Düzeltme geri alınınca
testler `ArgumentError:<Invalid argument(s): 101>` ile patlıyor — teşhis böyle
doğrulandı.

```bash
C:\src\flutter\bin\flutter.bat test test/pazarlik_test.dart
```

---

## 🩹 v112 — DİĞER DÜZELTMELER

### 1. "Yeterli paran yok"ta ürün yine de alınmış gibi kayıyordu
`_anlasmayiTamamla` fiyat üzerinde anlaşıldığında `PazarlikDurum.anlasildi`
döndürüyor; para yetmezse (veya envanter doluysa) alım GERÇEKLEŞMİYOR ama
widget yine de "ürün masadan aşağı kayıp kaybolur" efektini oynatıyordu — mal
alınmış gibi görünüyordu.

`GameState.sonAnlasmaBasarisiz` bayrağı eklendi; `_pazarlikGoster`'in
`anlasildi` dalı artık `&& !_state.sonAnlasmaBasarisiz` kontrolü yapıyor.
Bayrak `musteriAnimasyonBitti()` içinde sıfırlanıyor. Sonuç: ürün masada
kalıyor, müşteriyle birlikte normal şekilde sağdan çıkıyor.

### 2. 🪤 Ürün büyütme, Toptancı Rıza penceresinin ALTINDA kalıyordu
Büyütme önizlemeleri ana `Stack`'e katman olarak çiziliyordu
(`_buyukUrunGorseli` / `_envanterBuyukUrun` bayrakları). Ama `showDialog` ile
açılan Rıza penceresi sayfanın TAMAMININ üstünde ayrı bir **route**; sayfa
Stack'indeki hiçbir katman onun üstüne çıkamaz. Büyütülen CD arkada kalıyor,
ancak Rıza kapanınca görülüyordu.

**Çözüm:** iki bayrak ve iki Stack katmanı kaldırıldı; büyütme artık
`showDialog` ile açılıyor (`_urunGorseliBuyut`, `_envanterUrunBuyut`). Dialog
route'u her zaman en son push edilen olduğu için Rıza'nın da envanterin de
üstünde çıkar. Ayrıca **Rıza'nın tezgâhındaki ürünlere de tıkla-büyüt eklendi**
(`t.item != null` olanlara; tamir seti/kapalı kutu emoji olduğu için hariç).

> "Çöpe At" akışı iki pencere kapatıyor: onay dialogu + büyütme dialogu.
> Bu yüzden `_envanterUrunCopeAtOnay` artık büyütme context'ini de alıyor.

### 3. Bodrum Kat Dükkan kapı silüeti sağa taşıyordu
`kapiGen` %10 kısaltıldı: `0.1330 → 0.1197`. Sol kenar ve dikey ölçüler SABİT
kaldı (v111'de seviye 2/3 sağa **genişletilmişti**, burada tersi gerekti).

### 4. İçerik: 16 CD + 8 karakter
- **5 CD görseli yenilendi**: CİMRİCİTY, SOKAKSOCCER, ZOOMDAY, GTR 7,
  DALAKKÜREK (`CD_2/3/4/5/8.png` üzerine yazıldı).
- **16 yeni CD** → `CD_31..46`: ÇATAPAT, KOKOŞ, METRİS, BOMBERCAN, DOBROVSKİ,
  İPİMLE KUŞAĞIM, RECAİ MUMUDİK, RUHİ KANTER, SATAN SATANA, ZIMBALA, KEVGİR,
  PELTE, SEMSEK, NÖRÜN, ÇAYYNİİZ, CUMBURLOP. Toplam CD **30 → 46**.
- **8 yeni karakter** → `musteri_35..42`. Ölçüldü: 500×500, doluluk 0.914-0.976
  → mevcut kadroyla uyumlu, **yeniden ölçekleme yapılmadan** kopyalandı.
  Roster **34 → 42** (20 E / 22 K).

> CD görselleri `tools/`teki 0.83 doluluk hattından geçirildi (392×512 tuval,
> alfa sınır kutusu, en-boy korunur) — v108'in birebir aynısı.
> Fiyatlar **85-210**; ortalama korunacak şekilde dağıtıldı ki "oynanabilir =
> normal CD ortalamasının 2 katı" dengesi ve `kirgec_test.dart` bozulmasın.

---

## 🩹 v111 — 16 MADDELİK DÜZELTME LİSTESİ

### 1. Ürün müşteriden yarım saniye geç giriyordu
Sahnede ürün, müşteriyle **aynı** `_slideAnim`'i dinleyip konumunu ondan
türetiyordu ama `AnimatedPositioned` ile sarılıydı. `AnimatedPositioned` her
karede DEĞİŞEN bir `left` değerini (slideAnim her karede ilerlediği için)
650ms'lik kendi geçişiyle kovalamaya çalışıyordu — hareketli bir hedefi
kovalayan bir animasyon, sürekli geriden geliyordu.

**Çözüm:** giriş konumu artık `Positioned` (animasyonsuz) — müşteriyle
birebir aynı karede hareket ediyor. "Anlaşma sonrası masadan aşağı kayıp
gitme" efekti konumdan bağımsız, ayrı bir `_urunKayipController`
(`AnimationController`, 650ms) ile uygulanıyor.

### 2. Yeni oyunda envanterde oynanabilir ürün OLMAMALI
`GameState()` constructor'ında üç slotu `cd15`/`cd16`/`cd17` (KIRGEÇ/İTELE/
TISSS) ile eziyordu — `// GECICI` yorumlu, geliştirme sırasında test
kolaylığı için bırakılmış kod. Kaldırıldı; `slotlar` alanının kendi
initializer'ı zaten sıradan `cd1`/`cd3`/`cd5` kullanıyor.

### 3. Envanterdeki sağlam ürüne tıkla → büyüt + Çöpe At
Masadaki ürüne tıklayınca açılan büyütme (`_buyukUrunGorseli`) sadece kapanan
bir önizlemeydi. Envanterdeki **sağlam, oynanamaz** ürünler için aynı görsel
dilde ama "Çöpe At" seçeneği olan ayrı bir overlay eklendi:
`_envanterBuyukUrun` (GameItem?) → `_buildEnvanterBuyukOverlay()`. Çöpe At
"emin misin?" onayı ister, onaylanırsa `urunCikarOrnek()` ile slottan silinir.
Çürük ve oynanabilir ürünlerin kendi tıklama davranışı (tamir/oyun) değişmedi.

### 4 & 12. Tamir popup buton stilleri + sırası
"Vazgeç" arkaplansız `TextButton`'dı, "Tamir Et" ise gri arkaplan/soluk yazı.
İkisi de artık eşit genişlikte, dolu arkaplanlı `ElevatedButton`; **Tamir Et
solda** (asıl eylem), **Vazgeç sağda** — kırmızı/tehlike vurgusu yok, sade gri.

### 5. Browser sabit boyut + her sayfada Geri/Kapat
Eskiden `ConstrainedBox(maxHeight:)` + `Column(mainAxisSize.min)`
kullanıyordu — içerik kısaysa (Banka gibi) pencere küçülüyordu. Artık dış
kutu `SizedBox(height: sabit)`, `Column(mainAxisSize.max)` o yüksekliği
dolduruyor, ortadaki `SingleChildScrollView` `Expanded` ile HER sayfada aynı
alanı kaplıyor. Alt buton çubuğu kaydırma alanının DIŞINA, sabit bir
`Container`'a taşındı: menüde sadece **Kapat**, alt sayfalarda (Kiralık
Dükkanlar / Banka / Hedefler / Market) **Geri + Kapat**. `_browserMenuGovdesi`
içindeki eski gömülü Kapat butonu kaldırıldı (tekrar olmasın diye).

Ayarlar da (bilerek ayrı popup) aynı dile kavuştu: **Geri** sadece Ayarlar'ı
kapatır (Browser altta açık kalır), **Kapat** hem Ayarlar'ı hem Browser'ı
birlikte kapatır (`Navigator.pop(ctx); Navigator.pop(context);`).

### 6. Ayarlar'daki ses düğmesi gerçek switch gibi görünsün
Tek kelimelik "AÇIK"/"KAPALI" butonu neyin ne olduğunu belli etmiyordu.
Artık iki segmentli bir switch: **Açık** ve **Kapalı** yan yana, aktif olan
renkli (yeşil/kırmızı) dolu, diğeri soluk — hangisine dokunulursa o aktif olur.

### 7. Sarı mouse (Oyuncu Mausu) konuşma balonunda çok büyüktü
Balondaki ürün görseli sabit 100×100'dü. `oyuncumausu.png` için özel olarak
70×70'e (%30 küçük) düşürüldü; diğer ürünler etkilenmedi.

### 8 & 15. Kapı silüetinde sağda boşluk (Mahalle Köşe Dükkanı, Cadde Dükkanı)
`kapiGen` (kapı camı kutusunun genişliği) iki seviyede de gerçek camdan dar
ölçülmüştü. Sol kenar ve dikey ölçüler SABİT tutulup genişlik sadece sağa
doğru **%15** uzatıldı: seviye 2 `0.1224→0.1408`, seviye 3 `0.1113→0.1280`.

### 9 & 11 (kısmen). Mini oyun bitiş ekranında buton/başlık metni bölünüyordu
Dar konsol kasası ekranında sabit fontla "TOPLAR BİTTİ" ve "DÜKKANA DÖN" tek
satıra sığmıyordu. Kırgeç ve İtele'nin bitiş panelinde: kenar boşlukları
daraltıldı (24→16), başlık ve buton metni `FittedBox(fit: scaleDown,
maxLines: 1)` ile sarıldı — taşarsa küçülür, asla ikinci satıra düşmez.

### 10. "X'lik seri!" bildirimi ekranın merkezine alındı
`_buildToast()` eskiden `Positioned(left:24,right:24,bottom: %26)` ile alt
üçte birdeydi ve dardı. Artık `Positioned.fill` + `Center` ile tam ekran
ortasında, rozet-kazandın popup'ıyla aynı dilde; kutu `minWidth: 260` ve daha
geniş padding ile "rahat rahat" gözüküyor.

### 11. İtele oyunu — dört ayrı düzeltme
- **Başlangıç yazısı konumu**: `_buildBaslaYazisi()` tam ortada çubukların
  üstüne biniyordu. Artık `Positioned(top: boy/2, height: boy/2) + Center`
  ile SADECE alt yarının (oyuncunun kendi sahası) dikey ortasında.
- **Top hızı %20 arttı**: başlangıç 46→55.2, vuruş başı artış 1.2→1.44,
  tavan 88→105.6 (üçü orantılı büyütüldü, denge bozulmasın diye).
- **Kırmızı X kapatma düğmesi**: "İTELE" yazısının hemen solunda, daire
  içinde kırmızı X. Tıklanınca `_cik()` (skor ne olursa olsun anında dükkana
  döner).
- **"DÜKKANA DÖN" metni**: Kırgeç'teki aynı FittedBox düzeltmesi.

### 13. Falcı Faloya — 25 yeni "sadece hikâye" fal metni
Kullanıcının verdiği örnek üsluba (harf + kişi + gelecek kehaneti) uygun 25
yeni metin `Fal.havuz`'a eklendi (klasik kahve falı tonu: fincan, telve,
yıldız, kavşak — dükkan ekonomisiyle ilgisi yok, `FalEtki.yok`). Havuz
**50 → 75** metne çıktı; `test/fal_test.dart`'taki sayı testi güncellendi.

### 14. TISSS — başlangıç yazısı üst 1/3'e taşındı
`_buildBaslaYazisi()` tam ortada yılanın başlangıç konumuyla çakışıyordu.
`Positioned(top:0, height: boy/3) + Center` ile oyun alanının (tüm ekranın
değil) üst üçte birinde.

### 16. 🐛 Kolonya "zombi müşteri" hatası
**Belirti:** Müşteri reddedildikten (`HAYIR`) sonra ~600ms'lik çıkış
animasyonu boyunca `aktifMusteri` hâlâ doluyken, `musteriKabulBekliyor` zaten
`false` oluyordu. Bu dar pencerede Kolonya Tut'a basılırsa: alıcı için "tekrar
sorar" mesajı üretiliyor (`_kolonyaIkramEt`'in reask dalı) ama ne EVET/HAYIR
ne Teklif Ver/Reddet gösteriliyordu — müşteri ekranda donup kalıyordu.

**Kök neden:** Kolonya Tut butonunun `aktif` koşulu sadece `hasMusteri &&
!kolonyaIkramEdildi`e bakıyordu; müşterinin GERÇEKTEN etkileşimde olup
olmadığını kontrol etmiyordu.

**Düzeltme:** normal müşteride buton artık sadece `musteriKabulBekliyor ||
_pazarlikBekleniyor` iken aktif (özel müşteride davranış değişmedi — onların
akışı zaten kolonyayı her an kabul edecek şekilde tasarlı).

---

## 🌐 BROWSER TEK PENCERE NAVİGASYONU (v110)

Eskiden browser menüsündeki her satır **kendi popup'ını** açıyordu: browser
kapanıyor, üstüne ayrı bir dialog geliyordu. Artık dört bölüm de **aynı
pencerenin içinde** açılıyor; adres çubuğu değişiyor, sarı geri oku menüye
döndürüyor.

```dart
enum _BrowserSayfa { menu, dukkanlar, hedefler, market, banka }
```

| Sayfa | Adres çubuğu | Gövde |
|---|---|---|
| `menu` | `oyuncu_dukkani` | `_browserMenuGovdesi(ctx, git)` |
| `dukkanlar` | `kiralik_dukkanlar` | `_dukkanlarGovdesi(onKirala)` |
| `hedefler` | `hedefler` | `_hedeflerGovdesi()` |
| `market` | `market` | `_marketGovdesi(ctx)` |
| `banka` | `banka_kredisi` | `_bankaGovdesi(ctx, setDlg)` |

- `_browserPopup()` bir `StatefulBuilder`; `git(sayfa)` yalnızca dialogu
  yeniden çizer, `Navigator` yığınına dokunmaz.
- `browser.png`'de adres yazısı ve oklar **çizili**. Sayfaya göre
  değişebilmesi için beyaz bir kutuyla örtülüp üstüne yenisi yazılıyor.
  Geri oku menüde gri, alt sayfada sarı (`0xFFE6A800`).
- İçerik tek bir `SingleChildScrollView` içinde. **Sayfa gövdeleri kendi
  `ListView`'ünü kullanmaz** — iç içe iki kaydırma alanı istemiyoruz.
  `_hedeflerPopup`'ın `ListView.separated`'ı bu yüzden
  `...List.generate(...)` + `Padding` hâline çevrildi.

### ⚠️ Banka sayfasının state'i widget'ta duramaz
`_bankaGovdesi` her karede baştan çalıştığı için tutar/taksit seçimi
`_GameScreenState` alanlarında tutuluyor:

```dart
int _krediTutar, _krediTaksit;              // seçim
int get _krediCarpan / _krediMaxTutar / _krediMaxTaksit;   // türetilmiş
void _bankaSayfasiHazirla();                // sayfaya girerken bir kez
```

Rastgele başlangıç tutarı yalnız `_bankaSayfasiHazirla()` içinde üretilir —
`build` içinde üretilseydi her ok basışında tutar zıplardı. Menüdeki satırın
`onTap`'i bu yüzden `{ _bankaSayfasiHazirla(); git(banka); }`.

> Ayarlar ve Yeniden Başlat **bilerek** ayrı popup olarak kaldı: ikisi de
> browser'ı kapatması gereken işler (Yeniden Başlat oyunu sıfırlıyor).

---

## 🆕 v110 EK İÇERİK — 6 KARAKTER + 10 EKİPMAN

Kaynak klasörlerde (`YeniChars`, `YeniEkipman`) işlenmemiş kalan dosyalar
md5 karşılaştırmasıyla bulundu ve eklendi.

### 6 yeni karakter → `musteri_29..34`
Ölçüldü: hepsi **500×500**, doluluk 0.95-0.966, alt boşluk 10-15px → mevcut
kadroyla birebir uyumlu. **Yeniden ölçekleme YAPILMADI**, olduğu gibi
kopyalandı (v103'teki kural). `md5sum | uniq -d` ile tekrar kontrolü yapıldı,
tekrar yok. Roster 28 → **34** (15 E / 19 K).

### 10 yeni ekipman → `konsol_11..19` + `joystick`
9 retro el/masaüstü konsolu + 1 arcade joystick. `tools/`teki 0.90 doluluk
boru hattından geçirildi (500×500 şeffaf tuval, alfa sınır kutusu, en-boy
korunur) — v109'un birebir aynısı, dolayısıyla `kucukGorseller` kümesine
(%85) eklendiler. Emülatörde doğrulandı: Masaüstü Konsol masaya oturuyor,
boyut mevcut konsollarla uyumlu.

Fiyatlar **290-700**, mevcut konsol aralığının (380-620) içinde/yakınında.

> ⚠️ CD fiyat ortalamasına dokunulmadı. "Oynanabilir = normal CD
> ortalamasının 2 katı" dengesi ve onu koruyan `kirgec_test.dart` testi
> yalnız CD'lere bakıyor; konsol/aksesuar eklemek onu etkilemiyor.

Toplam ürün **49 → 59** (kolonya hariç koleksiyonda 58 hücre).

---

## 🕹️ OYNANABİLİR ÜRÜNLER — MİNİ OYUNLAR (v106)

Bazı CD'ler gerçekten **oynanabilir**. Envanterde köşelerinde ⭐ vardır,
tıklanınca "oynamak ister misin?" çıkar, EVET denince tam ekran mini oyun açılır.
Toplanan **puan birebir paraya çevrilip** ana oyundaki bakiyeye eklenir.

| Ürün | Oyun | Dosya | Kazanç |
|---|---|---|---|
| `cd15` KIRGEÇ | breakout | `lib/kirgec_oyunu.dart` | tam temizlik ≈ 386 lira |
| `cd16` İTELE | pong (tek kişilik) | `lib/itele_oyunu.dart` | galibiyet = 100 lira |
| `cd17` TISSS | yılan | `lib/tisss_oyunu.dart` | yem başına 5 lira |

### Kurallar
- **GÜNDE 1 KEZ.** `GameState.bugunOynananOyunlar` (Set), `gunuBitir()` içinde
  temizlenir, kayıtta saklanır. İkinci denemede *"Bugün X oyunu oynandı.
  Bir sonraki oyun için yarın gel."* çıkar.
  > Hak, oyuna **girer girmez** yanar — yoksa oyuncu kötü skoru görüp geri
  > çıkar, tekrar girerdi.
- **Para tavanı** `GameState.oyunPuanTavani` = 1000 (oyun başına).
- **NADİR gelir**: satıcı müşteride %10 ihtimalle oynanabilir havuzdan seçilir
  (`yeniMusteriGonder`). Toptancıdan ve kapalı kutudan **hiç çıkmaz**.
- **Fiyat**: oynanabilir oyunlar normal CD ortalamasının (~134) **2 katı** = 270.
- Çürük CD oynanmaz — önce tamir edilmeli.

### Kontrol şeması
| Oyun | Kontrol |
|---|---|
| KIRGEÇ / İTELE | Sağ yarıya **basılı tut** → sağa, sol yarıya → sola (sürekli hareket) |
| TISSS | Sağ yarıya **her dokunuş** → 90° sağa, sol yarıya → 90° sola (göreceli dönüş) |

Kırgeç/İtele `Listener` + `onPointerDown/Move/Up` kullanır; `GestureDetector`
tek dokunuş verdiği için çubuk topa yetişemiyordu. TISSS'te ise dokunuş zaten
tek seferlik olduğu için `onTapDown` yeterli.

> TISSS'te dönüşler kuyruğa alınır (`_bekleyenDonusler`, en fazla 2) ve adım
> başına biri uygulanır. Doğrudan uygulansa aynı adım içindeki iki dokunuş
> yılanı kendi üstüne katlayabiliyordu.

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

## 🎨 POPUP TASARIM DİLİ (v116) — TEK KAYNAK

Popup renkleri dağılmıştı: **6 farklı panel zemini**, kimi butonda çerçeve var
kimide yok, ana eylem bazen solda bazen sağda. Artık tek kaynak var — yeni bir
popup yazarken `Panel` sabitlerini ve `dialogButonlari()` yardımcısını kullan,
**elle renk verme**.

```dart
class Panel {
  static const zemin        = Color(0xFF1a1008); // TÜM popup gövdeleri
  static const yazi         = Color(0xFFF0DFC4);
  static const yaziSoluk    = Color(0xFFB9A88E);
  static const ikincilZemin = Color(0xFF33271A); // Vazgeç/Kapat/Dursun
  static const ikincilKenar = Color(0xFF6B5540);
}
```

### Buton kuralı
**Ana eylem SOLDA, vazgeçme SAĞDA.** İkisi de dolu zeminli, çerçeveli ve eşit
genişlikte — biri düz metin biri dolu buton olduğunda hangisinin tıklanabilir
olduğu belirsiz kalıyordu.

```dart
dialogButonlari(
  anaEtiket: 'Aç!', anaRenk: ..., anaOnTap: ...,
  ikincilEtiket: 'Dursun', ikincilOnTap: ...,
  // ikincil YIKICI bir alternatifse (ör. "Çöpe At") kendi kimliğini korur:
  ikincilZemin: ..., ikincilKenar: ..., ikincilYazi: ...,
)
```

> `anaOnTap: null` verilirse ana buton pasifleşir (ör. tamir seti yokken
> "Tamir Et").

---

## 🐛 v116 — BALONDAKİ YAZI İKİ KEZ YAZILIYORDU

**Belirti:** Satış/işlem popup'ı kapanır kapanmaz balondaki yazı bir kez
yazılıyor, sonra AYNI yazı baştan bir daha yazılıyordu.

**İki ayrı sebep vardı, ikisi de düzeltildi:**

1. **İki ayrı `TypewriterText`**: alıcı müşteri için Row'lu, diğer hallerde düz
   bir dal vardı ve her dalın kendi TypewriterText'i bulunuyordu. Müşteri
   gidince (`aktifMusteri` null) dal değişiyor, Flutter widget'ı atıp yenisini
   yaratıyor, State sıfırlanıyor ve yazı baştan oynuyordu.
   → Tek TypewriterText'e indirildi. Ürün görseli ayrı dal değil: yeri hep
   duruyor, gösterilmeyeceği zaman genişliği 0'a iniyor. Böylece widget ağaçta
   hep aynı konumda kalıyor.

2. **`mesajSayaci` aynı metinde de artıyordu**: sayaç balonun `key`'i; artınca
   State sıfırlanıp yazı baştan yazılıyor. Bazı akışlarda mesaj aynı içerikle
   iki kez atanıyordu.
   → Setter artık `if (v == _mesaj) return;` ile GERÇEK değişimi sayıyor.

> `TypewriterText` zaten `didUpdateWidget`'te metin değişince kendini yeniden
> başlatıyor; `key` sadece "aynı metin YENİ bir müşteriden gelirse tekrar
> oynasın" içindi. O nadir incelik, üst üste yazma hatasına değmiyordu.

---

## 🔊 SES SİSTEMİ (v101)

### Dosya ekleme — pubspec'e DOKUNMA
`pubspec.yaml` klasörü toptan listeliyor: `- assets/sounds/`
Yani **klasöre atılan her dosya otomatik pakete girer**, tek tek eklemek gerekmez.
`SesServisi._cal` try/catch'li → **dosya yoksa sessizce geçer, çökmez.**
Bu sayede tüm tetikleyiciler önceden bağlandı; dosyalar sonradan doldurulabilir.

### Beklenen dosyalar (`assets/sounds/`)
| Dosya | Tetikleyici | Durum |
|---|---|---|
| `kapi.mp3` | müşteri geldi | ✅ var |
| `paragirdi.mp3` | para değişti | ✅ var |
| `anlasma.mp3` | pazarlık anlaşmayla bitti | ⬜ |
| `basarisiz.mp3` | müşteri kızıp gitti | ⬜ |
| `rozet.mp3` | rozet kazanıldı | ⬜ |
| `seri.mp3` | kombo bonusu | â¬œ |
| `hedef.mp3` | günlük hedef tamam | ⬜ |
| `kutu.mp3` | kapalı kutu açıldı | ⬜ |
| `tamir.mp3` | çürük ürün tamir edildi | ⬜ |
| `gunsonu.mp3` | gün bitti | ⬜ |
| `hata.mp3` | yetersiz para / envanter dolu | â¬œ |
| `envanter.mp3` | envanter açıldı | ⬜ |
| `tik.mp3` | genel buton (seyrek kullanılıyor) | ⬜ |

### Dokunsal geri bildirim (haptik) — ses dosyası gerektirmez
`import 'package:flutter/services.dart' show HapticFeedback;` **açıkça gerekli** —
`material.dart` bunu re-export etmiyor, eklemezsen `undefined_identifier` hatası alırsın.

Her ses metodu uygun titreşimle eşleştirildi: anlaşma→medium, rozet→heavy,
hata→heavy, kapı/seri/tamir→light, envanter/tık→selectionClick.

> ⚠️ **v115'te ayrıldı**: titreşim artık `sesAcik`e DEĞİL, kendi ayarına
> (`SesServisi.titresimAcik`) bakıyor. Sessiz oynayan biri titreşimi
> isteyebilir — ikisi farklı beklenti.

### Buton dokunuşunda haptik (v115)
`SesServisi.dokun()` — **ses yok**, sadece `selectionClick`. Her tıklamada ses
çalmak gürültü olurdu.

Ana ekrandaki bütün önemli butonlar `_oyunButon` widget'ından geçtiği için
haptik **tek yerden** veriliyor:

```dart
onTap: aktif ? () { SesServisi.dokun(); onTap(); } : null,
```

- Müşteri Çağır, Envanter, EVET/HAYIR, Teklif Ver, Reddet, Kabul Et, Tamam,
  alkol testi şıkları… hepsi otomatik kapsanıyor.
- **Pasif butonda titreşim YOK** — dokunuşun karşılığı yoksa titretmek
  yanıltıcı olur.
- Kolonya Tut kendi `CustomPaint`'ini kullandığı için haptiği elle veriliyor.

### Ayarlar kalıcı — `AyarServisi`
Ses/titreşim tercihleri `SharedPreferences`'ta, **oyun kaydından ayrı**
anahtarlarda (`ses_acik`, `titresim_acik`). Oyunu sıfırlamak ya da silmek
tercihleri kaybettirmemeli. `main()` içinde `AyarServisi.yukle()` ile açılışta
geri yükleniyor.

> Ayarlar hem ana menüde hem oyun içi browser'da; ikisi de aynı iki segmentli
> Açık/Kapalı switch dilinde (`_ayarSatiri`). Titreşim açılırken örnek bir
> titreşim veriliyor ki ayarın ne yaptığı anlaşılsın.

### Ücretsiz ses kaynakları
`freesound.org` (CC0 filtresi) Â· `pixabay.com/sound-effects` Â· `opengameart.org` Â·
`kenney.nl/assets` (oyun UI ses paketleri, tamamen CC0)

> Arka plan müziği henüz YOK. Eklenirse ayrı bir `muzikAcik` ayarı ve
> `ReleaseMode.loop`'lu kalıcı bir AudioPlayer gerekir — SFX'ten ayrı toggle şart.

---

## 🤝 PAZARLIK MOTORU — Hamle Okuma (v100)

Eskiden motor oyuncunun **ne yaptığını** okumuyordu: 500'den 900'e çıksan da,
500'de ısrar etsen de, hatta geri gitsen de müşteri aynı tepkiyi veriyordu.
Artık her turda hamle sınıflandırılıp ona göre davranılıyor.

### `enum Hamle { geri, ayni, kucuk, orta, buyuk }`
`hamleOran = (bu tur verilen taviz) / piyasaFiyati`

| Hamle | Eşik | Müşterinin tepkisi |
|---|---|---|
| `geri` | < −0.5% | **Fiyatını KIRMAZ**, frustration +0.30, %22-50 çekip gider, kızgın replik |
| `ayni` | ±0.5% | frustration +0.14, konsesyon ×0.25, "inatçısın" repliği |
| `kucuk` | < 5% | normal |
| `orta` | < 14% | normal |
| `buyuk` | ≥ 14% | frustration −0.10, **%35-55 anında kabul** (teklif yakınsa), takdir repliği |

### Dört yeni davranış

**1. Kaprisli evet (%5)** — Mantıken kabul etmemesi gereken teklifi kabul eder.
Sınırlı: rezervasyonu en fazla %25 aşan teklifler. *"Ya boşver, kafam iyi bugün. Kabul!"*
Amaç: unutulmaz "vay be" anları.

**2. Bir kez daha sıkıştırma (%30)** — Teklif kabul edilebilir olsa bile pazarcı refleksiyle
"az daha gayret" der, orta noktaya çekilir. **Anlaşmayı kaybettirmez:** oyuncu aynı teklifi
tekrarlarsa kabul edilir (`_sikistirmaKullanildi` bir kez). Tur limiti güvenliği:
sadece `turSayisi <= maxTur - 2` iken. Sabırsız müşteride (maxTur=2) hiç tetiklenmez.

**3. Son teklif uyarısı** — `turSayisi >= maxTur - 1` olunca açıkça
*"SON TEKLİFİM: X. Ya alırsın ya küserim."* der. Oyuncu son şansı bilir, pazarlığa doruk katar.

**4. Büyük jest kabulü** — Ciddi bir sıçrama yapıldıysa ve teklif ulaşılabilirse
(`rezervAsim < 0.10`) jesti onurlandırıp kabul eder.

### Tepki replik havuzları (`PazarlikSeans`)
`_tepkiGeri` (8) Â· `_tepkiAyni` (7) Â· `_tepkiBuyuk` (8) Â· `_tepkiSikistirma` (6) Â·
`_sonTeklifMesajlari` (6) Â· `_kaprisliKabul` (10) Â· `_jestKabul` (6)

> ⚠️ Sıkıştırma clamp'i yön duyarlıdır: satıcı müşteride `clamp(oyuncuTeklif+1, musteriTeklif)`,
> alıcı müşteride `clamp(musteriTeklif, oyuncuTeklif-1)`. Ters çevirme, clamp hatası verir.

---

## 💬 DİYALOG HAVUZLARI (v99)

Tüm replikler genişletildi. Tekrar hissi kalmasın diye her havuz 18-26 satır.

| Havuz | Sınıf | Not |
|---|---|---|
| `_saticiSelam` / `_aliciSelam` | `Customer` | 20'şer selamlama, rol ayrı |
| `_kolonyaSelam` | `Customer` | 5 kolonyacı repliği |
| `_saticiKarsiTeklif` / `_aliciKarsiTeklif` | `PazarlikSeans` | 25'er karşı teklif, **rol ayrı** |
| `_kabulSablonlari` | `PazarlikSeans` | 26 kabul repliği |
| `_gitOfkeli` / `_gitTurBitti` / `_gitErken` | `PazarlikSeans` | 18 / 18 / 12 — ruh haline göre |

### ⚠️ PLACEHOLDER KURALI — TEK HARF KULLANMA
Şablonlarda `{AD}` ve `{URUN}` kullanılır. **Tek harfli placeholder (A, U) ASLA kullanma** —
`replaceAll('A', ...)` "**A**rkadaşlar" kelimesindeki büyük A'yı da değiştirir ve cümleyi bozar.
Fiyat için `X` güvenli (Türkçe'de büyük X geçen kelime yok) ama yeni şablon yazarken kontrol et.

### Rol ayrımı neden önemli
Malı **satan** müşteri "o para bu malı almaz" der, **alan** müşteri "o kadar para vermem" der.
Aynı cümleyi ikisine de söyletmek karakteri bozuyordu.

---

## ✨ TOAST BİLDİRİMİ (v99)

Seri ve günlük hedef bildirimleri Material SnackBar değil, oyunun kendi temasında
özel bir kart. `_toastGoster(metin, altYazi:, emoji:, renk:)`.

- Ana `Stack`'in en üstünde `_buildToast()` olarak render edilir
- `TweenAnimationBuilder` + `Curves.elasticOut` → aşağıdan süzülüp hafif zıplar
- Koyu gradient zemin (#241a10→#120c06), 2px renkli çerçeve, renkli glow gölge
- Başlık accent renkte, alt yazı beyaz — ikisinde de siyah text shadow (okunabilirlik)
- `_toastId` her gösterimde artar → animasyon baştan başlar
- 2.4 sn sonra otomatik kaybolur, `IgnorePointer` ile dokunuşu engellemez

> Material SnackBar kullanma — kahverengi zemin/okunmayan yazı sorunu bu yüzden çıkmıştı.

---

## 🎣 BAĞLILIK MEKANİKLERİ (v98)

Dört farklı zaman ölçeğinde tutundurma. Birbirini besleyecek şekilde tasarlandı.

| Ölçek | Mekanik | Alan / Sınıf |
|---|---|---|
| **An** | 🔥 Seri (kombo) | `kombo`, `enUzunSeri`, `sonKomboBonusu` |
| **Gün** | 🎯 Günlük hedef | `GunlukHedef`, `gunlukHedef` |
| **Sonraki gün** | ☀️ Yarının önizlemesi | `yarinkiOlayId` |
| **Uzun vade** | 📚 Koleksiyon | `satilanUrunIdleri` + `koleksiyonUrunleri` |

### 🔥 Seri (kombo)
- Üst üste **anlaşmayla biten** pazarlık sayısı. 3'ten itibaren her anlaşmada `kombo × 15` lira bonus.
- **Sıfırlanma:** sadece müşteri kızıp giderse (`PazarlikDurum.gitti`).
  Oyuncunun kendi reddi seriyi BOZMAZ — kötü teklifi reddetmek meşru strateji, cezalandırılmamalı.
- Günler arası devam eder (seri değerli hissettirsin).
- Bildirim: SnackBar (popup değil, akışı kesmesin).

### 🎯 Günlük hedef
`GunlukHedef.uret(dukkanSeviye)` her gün başında üretir. 6 tip:
`satisAdedi`, `gelir`, `tamir`, `kutu`, `toptanciAlim`, `tekSatis`
- Hedef büyüklüğü dükkan seviyesiyle ölçeklenir
- İlerleme `_hedefIlerlet(tip, miktar)` ile ilgili noktalardan beslenir
  (`_anlasmayiTamamla`, `tamirEt`, `kutuAc`, `toptanciSatinAl`)
- `tekSatis` için `mutlak: true` → en yüksek tek satış tutulur
- Tamamlanınca anında ödül + SnackBar; gün sonu popup'ında sonuç gösterilir

### ☀️ Yarının önizlemesi — "bir gün daha" kancası
Olaylar artık **bir gün önceden** belirlenir:
```
gunuBitir(): gunlukOlayId = yarinkiOlayId   (dün belirlenen olay bugün uygulanır)
             yarinkiOlayId = yeni zar        (gün sonu popup'ında duyurulur)
```
- Gün sonu popup'ında "YARIN" bölümü: emoji, başlık, açıklama + etki çipleri
- **Sabah olay popup'ı KALDIRILDI** — çift bildirim olmasın, popup yorgunluğu yaratmasın
- Aktif olay Hedefler ekranındaki "bugün paneli"nde görünür

### 📚 Koleksiyon
- Hedefler ekranının altında tüm ürünlerin ızgarası (kolonya hariç; v108'den beri 29 CD + konsol/aksesuar)
- Satılan ürün açılır (gerçek görsel), satılmayan "?" görünür
- Yüzde göstergesi; `satilanUrunIdleri` zaten takip ediliyordu, ek maliyet yok

### Hedefler ekranı yapısı
`ListView` → `[bugün paneli] + [8 rozet] + [koleksiyon paneli]`
- **Bugün paneli:** gün no, aktif seri, günlük hedef + ilerleme çubuğu, aktif olay + etki çipleri

---

## 🎯 SAHNE METRİĞİ — Çözünürlükten Bağımsız Konumlandırma (v97)

**Artık sahnede SABİT PİKSEL DEĞERİ YOK.** Ürün, isim etiketi ve müşteri, masa
görselinin ekrandaki kutusuna kilitlidir. Her çözünürlük/en-boy oranında masa
nereye giderse onlar da oraya gider.

### Neden gerekti
Eskiden masa görseli ekran **genişliğine** göre ölçekleniyordu (`fitWidth` + `scale 1.4`),
ürün ise ekran **yüksekliğine** göre konumlanıyordu (`screenH * 0.57 + sabit`). En-boy
oranı değişince ikisi ayrışıyordu → her cihazda elle ayar → sonsuz yama döngüsü.

### Nasıl çalışıyor
`SahneMetrik` sınıfı, masa görselinin render zincirini birebir modelleyip ekrandaki
kutusunu (üst kenar + yükseklik) hesaplar:
```
Align(bottomCenter) â†’ translate(0, 6) â†’ scale(1.4, bottomCenter) â†’ fitWidth
```
Konumlar görselin içindeki **0..1 oranlarıyla** ifade edilir:

| Sabit | Değer | Anlamı |
|---|---|---|
| `kMasaYuzeyi` | 0.4833 | Masa arka kenarı — **sanat eserinden ölçüldü** (bg1.png y=522/1080) |
| `kUrunTabani` | 0.5680 | Ürünün oturduğu çizgi (mousepad/klavye derinliği) |
| `kUrunBoyu` | 0.1745 | Ürün yüksekliği (masa boyuna oranla) |
| `kUrunSagKaydir` | 0.3537 | Ürünün müşteriye göre yatay kayması |
| `kIsimAlti` | 0.4920 | İsim etiketi alt kenarı (masa çizgisinin hemen altı) |
| `kMusteriUstu` | 0.2183 | Müşteri görseli üst kenarı |
| `kMusteriBoyu` | 0.6519 | Müşteri görseli boyu |

Kullanım: `m.y(oran)` → ekranda mutlak y, `m.u(oran)` → dp uzunluk (boyutlar da ölçeklenir).

> `_buildSahne()` içindeki konumlar yerel koordinatta olduğu için
> `ofs = mq.padding.top + 48.0` çıkarılır.

### Masa görselleri (üçü de aynı — doğrulandı)
`bgbosmasa.png` / `bg1.png` / `bg2.png` → hepsi **719×1080**, masa kenarı y=522/523.
Bilgisayar alınınca veya dükkan değişince ürün kaymaz.

### Test edildi (gerçek cihaz ölçümüyle)
| Çözünürlük | Oran | Sonuç |
|---|---|---|
| 1080×2400 | 20:9 | ✅ ürün mousepad hizasında, isim masada |
| 1080×1920 | 16:9 | ✅ birebir aynı bağıl konum |
| 1200×1600 | 4:3 | ✅ birebir aynı bağıl konum |

**Yeni bir konum ayarlamak gerekirse:** sabit px ekleme — yukarıdaki oran sabitlerini
değiştir. Ölçüm için: `adb shell screencap` ile ekran görüntüsü al, masa kenarını bul,
`(hedefY - m.ust) / m.boy` ile oranı hesapla.

---

## ⚠️ Görsel Katman Sistemi (Z-order)

### Stack Z-order (arkadan öne) — GameScreen build()

| # | Widget | Açıklama |
|---|--------|----------|
| 1 | `bgbos.png` | Sabit dükkan arkaplanı (Positioned.fill) |
| 2 | `biri.png` | Kapı gölgesi — müşteri yokken AnimatedOpacity ile görünür |
| 3 | **MÜŞTERİ görseli** | Masanın ALTINDA — bu katmanda olmalı! |
| 4 | **Masa layer** | AnimatedSwitcher: bgbosmasa/bg1/bg2, scale:1.4 bottomCenter |
| 5 | **SafeArea** | header + `_buildSahne()` + altbar |
| 6 | Dükkan butonu | gun >= 3'te sol altta görünür |

---

### MÜŞTERİ BOYUTU VE KONUMU (Outer Stack — katman 3)

```
width:  564 px  â† DOKUNMA!
height: 564 px  â† DOKUNMA!

hedef     = (screenW - 564) / 2
dx        = hedef + (screenW - hedef) * slideAnim.value   ← sağdan giriş
musteriTop = statusBar + 48.0 + screenH * 0.14 + 44
              â””â”€ statusBar = mq.padding.top
              └─ 48.0      = header yüksekliği
              └─ 0.14      = ekranın %14'ü
              └─ 44        = ince ayar ← DOKUNMA! (SON DEĞER)
```

---

### _buildSahne() — MÜŞTERİ PLACEHOLDER

`_buildSahne()` Stack'indeki müşteri widget'ı gerçek görseli değil, Z-order'ı korumak için **boş 564×564 SizedBox** içerir. Gerçek görsel dış Stack katman 3'tedir.

```
hedef     = (screenW - 564) / 2
dx        = hedef + (screenW - hedef) * slideAnim.value
musteriTop = screenH * 0.14 + 44   ← SafeArea içi (statusBar yok)
              └─ 44 = ince ayar ← DOKUNMA! (SON DEĞER)
```

---

### İSİM ETİKETİ KONUMU

Normal müşteri (Stack içi Positioned):
```dart
Positioned(
  bottom: 338,   // ← SON DEĞER (306→318→328→338, toplam 32px yukarı çekildi)
  left: 0, right: 0,
  child: Center(child: ...isim container...),
)
```

Özel müşteri — `_buildOzelMusteriWidget()` içinde **AYNI** yapı:
```dart
Positioned(
  bottom: 338,   // ← SON DEĞER, normal müşteriyle eşleşmeli
  left: 0, right: 0,
  child: Center(child: ...isim container...),
)
```

> **Neden left:0/right:0 + Center?** dx negatif değer alabilir (geniş müşteri görseli ekrandan taşar). Eğer Stack içinde dx'e göre Positioned konulsaydı isim ekran dışına çıkardı.

---

### ÜRÜN KONUMU (_buildSahne içi AnimatedBuilder)

Gösterilme koşulu (alıcı müşteri ürün almak istediğinde **değil**, satıcı veya kurye iken):
```dart
if (_state.aktifMusteri != null && _state.aktifMusteri!.musteriSatiyor ||
    _state.aktifOzelMusteri?.tip == OzelMusteriTip.kurye)
```

**Görsel seçimi:**
- Kurye ise `assets/durum.png` (dürüm/yemek)
- Normal satıcı ise `_state.aktifMusteri!.item.gorsel`

**Boyut:**
```
Standart ürünler              : productSize = 151.0 px
konsol_3/4/5/6.png + joypad   : productSize = 151.0 * 0.85 ≈ 128px  (%15 küçük)
oyuncudireksiyonu.png         : productSize = 151.0 * 0.85 ≈ 128px  (%15 küçük)
durum.png (kurye)             : productSize = 151.0 * 0.80 ≈ 121px  (%20 küçük)
```

**Yatay (productLeft):**
```
Tüm ürünler           : dx + 306
oyuncudireksiyonu.png : dx + 313 (+7 sağa)
konsol_2.png          : dx + 311 (+5 sağa)
konsol_3.png          : dx + 311 (+5 sağa)
```

**Dikey (productTop):**
```
screenH * 0.57 - productSize - st - hh - 20
  └─ 0.57       = ürün ALT kenarı ekranın %57'sinde (masa yüzeyi hizası)
  └─ productSize = 151 / 128 / 121 (ürüne göre)
  â””â”€ st         = viewPadding.top (status bar)
  └─ hh         = 48.0 (header yüksekliği)
  └─ -20        = ince ayar ← SON DEĞER (+32→+20→0→-20, toplam 52px yukarı çekildi)
```

> Koordinatlar `_buildSahne()` Stack'ine göreli — SafeArea içinde, header altında başlar.

---

### KONUŞMA BALONU (mesaj kutusu)

```dart
Positioned(top: 6, left: 6, right: 6)   // ← dış kenar boşlukları (SON DEĞER)
Container(padding: EdgeInsets.all(6))    // ← iç dolgu (SON DEĞER)
```

**Müşteri SATICI ise** (`musteriSatiyor == true`):
```
â†’ Sadece TypewriterText (metin, renkli border)
```

**Müşteri ALICI ise** (`musteriSatiyor == false`):
```
â†’ Row layout:
   Sol : Image.asset(item.gorsel, width:100, height:100)  ← ürün görseli
   Ara : SizedBox(width: 8)
   Sağ : Expanded
           â””â”€ Transform.translate(offset: Offset(-15, 0))  â† -15px sola â† DOKUNMA!
                â””â”€ Center
                     â””â”€ TypewriterText(textAlign: center)
```

---

## 🆕 Toptancı / Çürük-Tamir / Kapalı Kutu / Hedefler / Gün Olayları (v97)

Dört yeni sistem eklendi. **Hepsi mevcut mekanikleri KİLİTLEMEZ, sadece ekler** — bu bilinçli bir tasarım kararı (eski akış hiç bozulmadı).

### Erişim noktası
Hepsi **browser popup'ı** (`_browserPopup`, 🖥️ butonu, `gun >= 2`) üzerinden. Alt bara hiç dokunulmadı → layout riski sıfır.
```
🖥️ Browser → 🏠 Kiralık Dükkanlar / 🏦 Banka / 🏆 Hedefler / 🛒 Market / ⚙️ Ayarlar
(Toptancı Rıza v105'te menüden ÇIKARILDI — sadece kapıya geldiğinde alışveriş)
```

### 1. Çürük ürün (`GameItem.curuk`)
- `etkinFiyat` getter: `curuk ? basePrice * 0.35 : basePrice`
- **Tüm pazarlık hesapları `etkinFiyat` kullanır** (`basePrice` DEĞİL): `yeniMusteriGonder`, `musteriKabul`, `PazarlikSeans.piyasaFiyati`, envanter kartı, pazarlık dialogu
- Kaynakları: toptancı, kapalı kutu, fare olayı. **Müşteriler çürük ürün satmaz** (mesaj tutarlılığı için bilinçli)
- Envanterde: kırmızı çerçeve + `ÇÜRÜK` rozeti + %50 opaklık, tıklanınca tamir popup'ı

### 2. Tamir Seti (`tamirSetiAdet`)
- Kolonyanın **birebir aynı deseni**: slot işgal etmez, sayaç, envanterde ek kart
- Toptancıdan 450'ye alınır → **5 kullanım** (≈90/kullanım)
- `tamirEt(slotIndex)`: `curuk=false`, kondisyon 4-5 rastgele
- Ekonomi: pahalı ürünü tamir kârlı (2.3-3.2x), ucuz CD'yi tamir zararlı — **kasıtlı karar noktası**

### 3. Kapalı Kutu (`GameItem.kapaliKutu`)
- `GameState.kapaliKutuUret()` — görseli `assets/zarf.png`, slot işgal EDER
- Toptancıdan 300'e, envanterde tıkla → onay → `kutuAc()` → aynı slota rastgele ürün
- %25 çürük çıkma şansı (kutu_avcisi rozetiyle %12.5)
- **Alıcı müşteriler açılmamış kutuyu isteyemez** (`!u.kapaliKutu` filtresi) — kilitlenme yok, kutu açmak bedava

### 4. Toptancı (`ToptanciUrun`, `ToptanciTip`)
- Stok **günlük**, `toptanciStokGunu != gun` ise yeniden üretilir (`gunuBitir` içinde 0'lanır)
- 5 tezgâh (tuccar rozetiyle 6): 1 tamir seti + %70 kapalı kutu + kalanı ürün
- Fiyatlar: sağlam %55-75, çürük %28-40 (piyasa fiyatının)
- İndirimler toplanır: günlük olay + `zengin` rozeti (%10) + `pazarlikci` rozeti (çürükte %20)
- Görsel: `assets/toptanci.png` (470×470, kullanıcı üretti — v103'te yüksek çözünürlüklü kesimle değişti)

### 5. Hedefler & Rozetler (`Rozet`)
8 rozet. `_rozetleriDenetle()` **`notifyListeners()` içinde** çalışır (kendisi notify çağırmaz → döngü yok).
Kazanılanlar `yeniKazanilanRozetler` kuyruğuna girer, UI `_rozetKuyrugunuIsle()` ile **ekran müsaitken** gösterir (müşteri/pazarlık/envanter/gün-sonu yokken → dialog çakışması olmaz).

| Rozet | Hedef | Ödül (sadece yeni sistemleri etkiler) |
|---|---|---|
| 🏪 İlk Satış | 1 satış | +100 lira |
| 💼 Tüccar | 10 satış | Toptancıda 6. tezgâh |
| 🔧 Tamirci | 5 tamir | Tamir seti %30 indirimli |
| 🎁 Kutu Avcısı | 10 kutu | Kutuda çürük şansı yarıya iner |
| 💎 Koleksiyoncu | 10 farklı ürün sat | Toptancı ürünleri iyi kondisyonda |
| 💰 Zengin | 10.000 lira | Toptancıda kalıcı %10 indirim |
| 🤝 Pazarlık Ustası | 30 anlaşma | Çürükler %20 daha ucuz |
| 📅 Emektar | 15. gün | Her gün +200 lira destek |

### 6. Gün Olayları (`GunOlayi`)
- `gunuBitir()` içinde, **3. günden itibaren %55 ihtimalle** biri seçilir
- Etkiler: `musteriDelta`, `piyasaCarpani`, `paraDelta`, `toptanciIndirim`, `fareIstilasi`
- `piyasaCarpani` `_piyasaEtkisi()` ile uygulanır: **alıcı daha çok öder, satıcı daha az ister** (`musteriSatiyor ? reserv/c : reserv*c`)
- 10 olay: TikTok viral, elektrik kesintisi, retro fuar, ekonomik kriz, kaldırım kazısı, sürpriz zarf, fare istilası, toptancı kampanyası, sağanak yağmur, gazete övgüsü
- Reklamdan sonra popup ile tanıtılır

### Kritik uygulama notları
- **`urunCikarOrnek(GameItem)`** eklendi: aynı id'den çürük + sağlam iki kopya varsa `identical` ile doğru örneği çıkarır (eski `urunCikar(id)` yanlışını satabilirdi)
- `GameItem.kopyaWith()` — alan bazlı kopya (final alanlar için)
- `_slotaKoy()` sessiz ekleme (çift kayıt önler), `_slotlariSikistir()` ortak sıkıştırma
- Tüm yeni alanlar `toJson`/`fromJson`'da **null-safe default** → eski kayıtlar bozulmaz

---

## Önemli Oyun Mekanikleri
- **Gün sistemi**: Her gün N müşteri, gün sonunda kira düşülür
- **Pazarlık**: Müşteri teklif verir, oyuncu kabul/reddeder
- **Envanter slot sistemi**: Ürün alım/satım
- **Dükkan seviyeleri**: Kira ödeyerek büyütme
- **Özel müşteriler**: Hırsız, polis, vergici, kurye (YeSekSepeti), Toptancı Rıza, **Falcı Faloya**
- **iMac satın alma**: 3. günden sonra görünür buton, alındıktan sonra masa değişir
- **Bilgisayar Geldi popup**: 3. günde tetiklenir (tek seferlik, `_bilgisayarGeldiGosterildi` flag'i)
- **Oyun sonu**: Para bitti + envanter boş → iflas popup
- **Devam Et butonu**: `_kayitVar` flag'i ile kontrol edilir — kayıt yoksa pasif
- **Başlangıç parası**: 1000 (eskiden 500)
- **Ardışık aynı ürün engeli**: `_sonUrunId` field'ı; bir önceki müşterinin ürünü havuzdan çıkarılır (birden fazla seçenek varsa)

---

## Kolonya Sistemi (v78 → v90 sürümleri)

### Kolonya Özellikleri
- Satıcı müşteri 1. günden itibaren kolonya satabilir (10 kullanım, slot dışı tutulur — +1 ilave)
- `kolonyaKullanim`: 0-10 arası, müşteriye ikram başına 1 düşer
- `kolonyaIkramEdildi`: aynı müşteriye 2 kez ikram engellenir
- `_kolonyaPendingBonus`: pazarlık başlamadan ikram edilirse bekleyen bonus
- Özel müşteriye kolonya: parasız gönderir (hırsız/polis/vergici/kurye)

### "Kolonya Tut" Butonu (_buildAltBar) — v89

Eski yerleşik kolonya görseli (Stack içinde Positioned) **kaldırıldı**. Yerine `_buildAltBar`'da Müşteri Çağır/Envanter satırının altında:

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
          // İkon (Image.asset 'kolonya.png' 22×22) + "Kolonya Tut" (white w900) + "X/10" (white70)
        ),
      ),
    );
  }),
],
```

- Renk: `0xFFE6A800` (parlak amber)
- Yazı: beyaz (önceki siyah/altın değildi)
- Müşteri yokken pasif (white38/white24 + opacity 0.35)
- `kolonyaKullanim == 0` ise buton tamamen kaybolur

### Kolonya Sonrası Alıcı Mesajı (v90)

Alıcı müşteriye (`!musteriSatiyor`) kolonya tutulunca:
1. 3 sn "Kolonya ikramın için teşekkürler! :)" gösterilir
2. Sonra `_state.mesaj` 6 random mesajdan biriyle güncellenir
3. Önceki mesaj tekrar gelmez — `_kolonyaSonrasiSonIdx` field'ı

```
1) "Ne diyorduk? Elinde X olduğunu duydum, bana satar mısın?"
2) "En son X cd'sini bana satmanı rica ediyordum. Mümkün mü?"
3) "Nerede kalmıştık... Evet. X cd'ni bana satar mısın?"
4) "Hah ne diyordum; X cd'ni alabilir miyim mümkünse?"
5) "X cd'n hala duruyorsa ben alabilir miyim?"
6) "Ferahladığıma göre tekrar sorayım, X satılık mı halen?"
```
X = `_state.aktifMusteri!.item.name` (orijinal balondaki ürün)

---

## iOS Yapılandırması

### Temel Bilgiler
- **Bundle ID**: `com.oyuncudukkani.app` (Android ile aynı)
- **Display Name**: `Oyuncu Dükkanı` (Info.plist `CFBundleDisplayName`)
- **Deployment Target**: 13.0 (AdMob için minimum)
- **Team ID**: `SN5Y726ZKF` (FUTURASTIC TEKNOLOJI URUNLERI VE DANISMANLIGI ORGANIZASYON TICARET LIMITED SIRKETI)
- **AdMob iOS App ID**: `ca-app-pub-6470338276121414~7413384913` (Info.plist `GADApplicationIdentifier`)
- **AdMob iOS Interstitial Unit ID**: `ca-app-pub-6470338276121414/1436676062` (oyuncudukkanigecis, PROD)
- **AdMob iOS Ödüllü (Rewarded) Unit ID**: `ca-app-pub-6470338276121414/2648809677` (oyuncudukkaniodullu, OLUŞTURULDU ama oyunda henüz KULLANILMIYOR)
- **AdMob Android Interstitial Unit ID**: `ca-app-pub-6470338276121414/4138047986` (PROD)
- **App Store Connect App ID** (numerik): `6778437262`
- **NSUserTrackingUsageDescription**: ATT (App Tracking Transparency) izni için
- **SKAdNetworkItems**: AdMob 12.x için Google'ın güncel SKAN ID listesi (43 ağ)
- **ITSAppUsesNonExemptEncryption**: `false` (sadece HTTPS, custom crypto yok — Apple muaf)
- **iOS App Icon**: `flutter_launcher_icons` ile `assets/oyuncu_dukkani_icon.png`'den üretildi
  - `ios: true`, `remove_alpha_ios: true` (Apple alpha kanal kabul etmiyor)

### Apple Developer Portal Setup (BİR KEZ)
1. https://developer.apple.com/account/resources/identifiers/list
2. **+** (Add) â†’ App IDs â†’ App
3. Description: `Oyuncu Dukkani` (ASCII), Bundle ID: `com.oyuncudukkani.app` (Explicit)
4. Capabilities: hiçbir şey işaretleme
5. Register

### App Store Connect Setup (BİR KEZ)
1. https://appstoreconnect.apple.com â†’ My Apps â†’ **"+"** â†’ New App
2. Platforms: iOS, Name: **Oyuncu Dükkanı**, Bundle ID: dropdown'dan seç
3. SKU: **OYUNCUDUKKANI001**, User Access: **Full Access**
4. Create → URL'deki numerik App ID'yi al (örn. `6778437262`)

---

## 🚀 Codemagic CI/CD — iOS TestFlight Pipeline

`codemagic.yaml` git tag `v*` push edilince tetiklenir, otomatik TestFlight yükleme yapar.

### Workflow tetikleme
```bash
# YA git tag ile (otomatik)
git tag v1.0.x-iosN
git push origin v1.0.x-iosN

# YA Codemagic UI'dan manuel: Applications â†’ oyuncu_dukkani â†’ Start new build â†’ main â†’ ios-testflight
```

### Codemagic UI Kurulum (BİR KEZ tamamlandı)

**1. Repo bağlantısı**
- https://codemagic.io â†’ Sign in with GitHub â†’ "Add application" â†’ oyuncu_dukkani repo

**2. App Store Connect API Key entegrasyonu**
- Codemagic UI â†’ Personal Account â†’ **Settings** â†’ Integrations â†’ **Developer Portal** â†’ "Connect"
- App Store Connect → Users and Access → Integrations / Keys → "+" → App Manager rolünde key oluştur
- Key ID, Issuer ID, .p8 dosyasını Codemagic'e gir
- Name: **`Codemagic`** (YAML'da `integrations.app_store_connect: Codemagic` ile referans veriliyor)
- **Mevcut Key ID:** `2M84B256CL` (Magnus ile paylaşımlı)

**3. iOS Distribution Certificate (Code signing identity)**
- Personal Account â†’ **Settings** â†’ "Code signing identities" â†’ "iOS certificates"
- **Upload a certificate file**: `.p12` dosyası sürükle
- Şifre boş olabilmesi için yerel olarak yeniden üretildi:
  ```bash
  openssl pkcs12 -export -legacy \
    -out ios_distribution_nopass.p12 \
    -inkey C:/src/magnus_app/ios_certs/ios_distribution.key \
    -in   C:/src/magnus_app/ios_certs/distribution.pem \
    -passout pass:
  ```
- Reference name: `ios_distribution`
- ⚠️ NOT: Magnus için yapılmış cert'ten türetildi, **aynı Apple Developer Team** olduğu için oyuncu_dukkani için de geçerli

**4. Private Key Environment Variable**
- Codemagic Personal Account â†’ Settings â†’ Global vars **deprecated** â†’ Applications â†’ oyuncu_dukkani â†’ **Environment variables**
- `CERTIFICATE_PRIVATE_KEY` (Secret âœ…, group: `signing_credentials`)
- Değer: `ios_distribution.key`'in **base64 encoded** içeriği:
  ```bash
  cat ios_distribution.key | base64 -w 0 > cert_key_base64.txt
  ```
- YAML'da `signing_credentials` group referansı zorunlu

### codemagic.yaml Yapısı

```yaml
workflows:
  ios-testflight:
    name: iOS TestFlight (Otomatik)
    instance_type: mac_mini_m2
    integrations:
      app_store_connect: Codemagic   # UI'daki integration adı
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
          # google_mobile_ads CocoaPods, webview_flutter SwiftPM — çakışıyor
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

### ⚠️ Çözülen Codemagic Sorunları (referans)

| Hata | Sebep | Çözüm |
|------|-------|-------|
| `auth: integration requires workflow → integrations → app_store_connect` | YAML'da integrations bloğu eksik | `integrations.app_store_connect: Codemagic` eklendi |
| `No matching profiles found for bundle identifier` | `ios_signing` env block profil yoksa hata fırlatır | Env block kaldırıldı, script ile `--create` |
| `Cannot save Signing Certificates without certificate private key` | Cert auto-create için private key gerekli | `CERTIFICATE_PRIVATE_KEY` env var + `--certificate-key=@file:` |
| `Provided value "" is not valid` (cert key) | Env var boş veya group bağlanmamış | YAML'a `groups: [signing_credentials]` eklendi |
| `google_mobile_ads uses CocoaPods while webview_flutter_wkwebview uses Swift Package Manager` | SDK çakışması | `flutter config --no-enable-swift-package-manager` |
| `The bundle version must be higher than the previously uploaded version` | Build number unique olmuyor | Timestamp fallback (`date +%s | tail -c 7`) |
| Mavi Flutter üçgeni ikon | `flutter_launcher_icons` ios:false | `ios: true` + `flutter pub run flutter_launcher_icons` |
| Encryption sorusu her build'de soruluyor | Info.plist'te bildirim yok | `ITSAppUsesNonExemptEncryption=false` eklendi |
| App Privacy formu doldurulmamış | NSUserTrackingUsageDescription ATT istiyor | App Privacy → Publish → Tracking yapılandır |

### TestFlight Test Etme
1. iPhone'a **TestFlight** uygulamasını App Store'dan kur
2. App Store Connect'teki Apple ID ile giriş yap
3. App Store Connect → Oyuncu Dükkanı → TestFlight → **Internal Testing** → "+" Group oluştur
4. Group â†’ Testers â†’ kendi Apple ID'ni ekle
5. Group → Builds → "+ Add Build" → son build seç
6. iPhone'a mail gelir (5-15 dk) veya doğrudan TestFlight uygulamasında belirir

### App Privacy Formu (NSUserTrackingUsageDescription kullanılırsa)
App Store Connect → Oyuncu Dükkanı → **App Privacy** → Get Started:

**Data Types collected** (AdMob için):
- **Identifiers â†’ Device ID**: Linked=Yes, Tracking=Yes, Purpose=Third-Party Advertising
- **Diagnostics â†’ Crash Data**: Linked=No, Tracking=No, Purpose=App Functionality
- **Diagnostics â†’ Performance Data**: Linked=No, Tracking=No, Purpose=App Functionality

**Privacy Policy URL**: `https://anilgedikoglu.github.io/oyuncu_dukkani/privacy-policy.html`

⚠️ Form doldurulunca **"Publish"** butonuna tıklamak ZORUNLU (Save yetmiyor).

### Versiyon Kontrolü
- pubspec.yaml: `1.0.2+13`
- iOS build number Codemagic tarafından OTOMATİK timestamp ile atanıyor, pubspec'teki +13 ile çakışmaz
- Android AAB: pubspec'teki versionCode kullanılır → Play'e her yüklemede ARTTIR (12→13→14...)
- Yeni release için: `pubspec.yaml` version arttır → commit + push → Codemagic UI'dan manuel build başlat veya `git tag v1.0.x-iosN`

---

## app-ads.txt (AdMob Doğrulama)

AdMob'un yetkisiz reklam envanteri satışını önlemek için kullandığı doğrulama dosyası.

**Dosya konumu (KRİTİK):** Domain KÖKÜNDE olmalı, alt-path'te DEĞİL.
- ✅ Doğru: `anilgedikoglu.github.io/app-ads.txt` (ayrı `anilgedikoglu.github.io` repo'sunda)
- ❌ Yanlış: `anilgedikoglu.github.io/oyuncu_dukkani/app-ads.txt` (proje alt-path'i — AdMob bakmaz)

**İçerik (tüm app'ler için ortak, aynı pub ID):**
```
google.com, pub-6470338276121414, DIRECT, f08c47fec0942fa0
```

**AdMob doğrulama zinciri:** AdMob app kaydı → bağlı App Store/Play URL → store'daki "Developer Website" domaini → o domainin kökündeki app-ads.txt → pub ID eşleşmesi.

**Oyuncu Dükkanı için zincir (hepsi doğru):**
- App Store Developer Website: `https://anilgedikoglu.github.io/oyuncu_dukkani/marketing.html`
- Domain: `anilgedikoglu.github.io` â†’ app-ads.txt orada mevcut âœ…

**"Doğrulanamadı" hatası çözümü:**
1. Dosya/içerik genelde DOĞRUDUR — panik yapma, önce zinciri kontrol et
2. AdMob'daki app kaydı App Store/Play'e BAĞLI olmalı (manuel oluşturulduysa bağlanmamış olabilir)
3. AdMob tarama günde ~1 kez → "yeniden tara" deyip 24 saat bekle
4. Doğrulama hatası reklam gelirini ENGELLEMEZ, reklamlar yine gösterilir — acil değil

⚠️ App Store/Play'de "Marketing/Developer Website" alanı domaini `anilgedikoglu.github.io` olmalı (app-ads.txt orada).

---

## Android Yapılandırması
- **Paket adı**: `com.oyuncudukkani.app` (eski: `com.example.oyuncu_dukkani`)
- **Uygulama ikonu**: `flutter_launcher_icons` ile `oyuncu_dukkani_icon.png`'den üretildi, adaptive icon destekli
- **Splash**: Android native splash kaldırıldı, Flutter tarafında `SplashScreen` widget'ı kullanılıyor

### âš ï¸ EnableImpeller=false (Skia)

**AndroidManifest.xml**'de:
```xml
<meta-data
    android:name="io.flutter.embedding.android.EnableImpeller"
    android:value="false" />
```

**Neden:** Impeller emülatörün yazılımsal GPU'sunu (`ranchu`/SwiftShader) boğuyor — raster thread %92 CPU + %90 kernel, composer3 %100, surfaceflinger %48 → ANR ("Application does not have a focused window"). Skia ile composer3 %100 → %3.4. Gerçek cihazda Impeller (Vulkan) hızlı, sorun yok, ama emülatör test için Skia zorunlu.

Bu flag deprecated uyarısı verir ama hâlâ çalışır.

---

## ⚠️ ANR Sorunları & Emülatör Yönetimi

### Tetikleyiciler
1. **Impeller + software GPU**: Yukarıdaki Skia çözümü
2. **Emülatör state degradation**: Uzun süreli install/uninstall/force-stop döngüleri Android system_server'ı bozar. Belirtisi: "Process system isn't responding" + Windows tarafında "Yanıt Vermiyor"
3. **Büyük APK + AOT cold start**: İlk install + ART derleme önbelleği oluşturma >5 sn → startup ANR

### Geliştirme Akışı
- **Yeni APK kurarken** her zaman: `adb install -r` (kaldırmadan üstüne) — ART önbelleği korunur
- **İmza değişikliğinde** (debug↔release): mecbur uninstall
- **Emülatör sıkışırsa**: Tamamen kapat → Cold Boot (`-wipe-data` veya AVD Manager'dan "Wipe Data")
- **Gerçek cihazda** ANR olmaz; emülatör spesifik

### ⚠️ Git Bash + adb: `/sdcard/` yolu bozulur
Git Bash, argümandaki POSIX yolunu Windows yoluna çevirir → `adb shell screencap -p /sdcard/e.png`
`C:/Program Files/Git/sdcard/e.png` olur ve **screencap usage hatası** verir.
Başına `MSYS_NO_PATHCONV=1` koy:

```bash
MSYS_NO_PATHCONV=1 adb shell screencap -p /sdcard/e.png && MSYS_NO_PATHCONV=1 adb pull /sdcard/e.png
```

Aynı sebeple `adb shell 'sleep 5'` tırnak içinde yazılmalı (Bash tool ön planda
`sleep` çalıştırmayı engelliyor; beklemeyi cihaza yaptır).

### Build Çıktıları (post-optimizasyon)
```
app-armeabi-v7a-release.apk : 32.4MB
app-arm64-v8a-release.apk    : 34.7MB
app-x86_64-release.apk       : 36.1MB
```
v87 fat APK 70.8MB idi — assets optimizasyonu ile dramatik azalma.

---

## Asset Optimizasyonu (v88)

### Optimize Edilen (PowerShell + System.Drawing ile resize + recompress)

| Dosya | Önce | Sonra | Yöntem |
|-------|------|-------|--------|
| bgbos.png | 7.1 MB | 2.1 MB | 1684×2528 → 719×1080 |
| anamenu.png | 7.3 MB | 1.3 MB | 1408×3062 → 497×1080 |
| bg1.png | 3.6 MB | 1.1 MB | 1684×2528 → 719×1080 |
| bg2.png | 3.6 MB | 1.2 MB | 1684×2528 → 719×1080 |
| bgbosmasa.png | 3.2 MB | 1.1 MB | 1684×2528 → 719×1080 |
| browser.png | 0.9 MB | 0.15 MB | 775×1298 → 306×512 |
| biri.png | 7 MB (eskiden) | 11 KB | 1684×2528 → 341×512 |
| CD_1..6 | ~440KB her | ~390KB her | 437×571 → 392×512 |
| konsol_1..5 | ~200KB | ~190KB | re-encode |
| kurye.png | 185KB | 144KB | 408×612 → 341×512 |

### pubspec.yaml — Asset Listesi (Wildcard → Explicit)

Önceden `assets/` wildcard tüm dosyaları paketliyordu. Şimdi explicit liste:
- Hariç tutulanlar: `anamenu1.png` (7.1MB), `anamenu2.png` (7.2MB), `oyuncu_dukkani_market.png` (7.4MB) → 21MB kazanç
- Her CD ve müşteri ayrı satır

---

## DevicePreview
`device_preview` paketi şu an **disabled** (`enabled: false`). Test sırasında ekranı küçülttüğü için kapatıldı. Açmak için `enabled: kDebugMode` yap.

## Header — Daire Sayaç Animasyonu

Gün/para kutuları eşit genişlik. Aralarında sarı daire (Ticker tabanlı sürekli animasyon):

```dart
// _GameScreenState alanları:
late Ticker _daireTicker;
Duration _dairePrevTick = Duration.zero;
double _daireGosterilen = 0.0;  // 0.0..1.0 ekranda görünen
double _daireHedef     = 0.0;   // müşteri sayısına göre hedef
double _daireHiz       = 0.3;   // rassal hız (bazen hızlanır/yavaşlar)
final _daireRng = Random();
```

`_DairePainter` → sarı dolmuş dilim (clockwise), siyah ince çerçeve, beyaz yarı şeffaf arka plan.

---

## Butonlar — Pixel Art Çerçeve

`_PixelButonPainter` (CustomPainter): metalik siyah gradient çerçeve, renkli gradient iç, L-şekli köşe süsleri (7 piksel/köşe), üst parlama şeridi.
`_oyunButon()` â†’ `GestureDetector` + `CustomPaint(painter: _PixelButonPainter(...))`.
Yükseklik: 50px. Yazılar `FittedBox(fit: BoxFit.scaleDown)` ile taşmaz.

---

## Pazarlık Popup — Tıklanabilir Teklif Balonu

Müşteri ALICIYSA (`!musteriSatiyor && !anlasildi && !gitti && !_bitti`):
```
_dialogMesaj Container â†’ GestureDetector
  borderRadius: 24 (oval)
  border: Color(0xFF4caf50), width: 1.8  ← yeşil
  boxShadow: yeşil parlama
  onTap: widget.state.teklifVer(musteriTeklif) â†’ Navigator.pop()
```
Tıklanınca oyuncu müşterinin teklifini kabul etmiş olur.
Butonlar: sadece "Reddet" (kırmızı) + "Fiyat Ver" (altın) — "Kabul Et" yok.

**Piyasa/Maliyet bilgisi (v90 ile aynı font):**
```dart
Piyasa : fontSize 14, white60, w600 + basePrice (blue 0xFF64B5F6, bold)
Maliyet: fontSize 14, white60, w600 + value     (orangeAccent, bold)
```

---

## Envanter Kompaksiyon

`urunCikar()` → ürün çıktıktan sonra dolu slotlar öne çekilir, boşluklar sona itilir:
```dart
final dolu = slotlar.sublist(0, acikSlotSayisi).whereType<GameItem>().toList();
for (int j = 0; j < acikSlotSayisi; j++) slotlar[j] = j < dolu.length ? dolu[j] : null;
```

---

## Ürün Listesi (`_baslangicUrunler`)

| Kategori | ID | Ad | Görsel | basePrice |
|----------|----|----|--------|-----------|
| cd | cd1..30 | KARMAGEDDON, CİMRİCİTY, ..., KISPET, UÇARSOKAR, DÜTTÜRÜ + v106'da KIRGEÇ/İTELE/TISSS (oynanabilir) + v108'de ŞEHRİŞER, UÇURBENİ, CIPCIP, TANTUNİ, VURKAÇ, BİLEZ, TAHTAKALE, SÜMSÜK, BİLEKZORU, MAHŞER, DİKİZ, TAMTAM, KOKARCA | CD_1..30.png | 80-270 |
| cd | cd31..41 | v112: ÇATAPAT, KOKOŞ, METRİS, BOMBERCAN, DOBROVSKİ, İPİMLE KUŞAĞIM, RECAİ MUMUDİK, RUHİ KANTER, SATAN SATANA, ZIMBALA, KEVGİR | CD_31..41.png | 95-210 |
| cd | cd42..46 | v112: PELTE, SEMSEK, NÖRÜN, ÇAYYNİİZ, CUMBURLOP | CD_42..46.png | 85-160 |
| konsol | konsol1 | PlayStatyon | konsol_1.png | 900 |
| konsol | konsol2 | Ninetendo | konsol_2.png | 750 |
| konsol | konsol3 | Ateri | konsol_3.png | 500 |
| konsol | konsol4/5/6 | El Konsolu (3 versiyon) | konsol_4/5/6.png | 380-560 |
| konsol | konsol7 | son sistem oyun konsolu | konsol_7.png | 3200 |
| konsol | konsol11..14, konsol18/19 | El Konsolu (v110 retro kesim) | konsol_11..14/18/19.png | 290-700 |
| konsol | konsol15..17 | Masaüstü Konsol (v110 tabletop LCD) | konsol_15..17.png | 360-640 |
| aksesuar | aksesuar1..8 | Oyuncu Direksiyonu, Joypad + v109: 3D Gözlük, Oyuncu Kulaklığı, Kulaklık ve Stant, Kablosuz Joypad, Direksiyon Seti, Oyuncu Mausu | 260-850 |
| aksesuar | aksesuar9 | Arcade Joystick (v110) | joystick.png | 470 |
| aksesuar | kolonya | Kolonya (slot dışı, +1 ilave) | kolonya.png | 120 |

---

## AdMob Reklam Sistemi (v91-v92)

Her yeni günün başına interstitial (geçiş) reklamı, game over değilse. **Emülatörde reklam çıkmaz** (politika güvenliği).

### AdMob Kimlikleri (PROD)
- **App ID** (AndroidManifest): `ca-app-pub-6470338276121414~9391747814`
- **Interstitial Unit ID**: `ca-app-pub-6470338276121414/4138047986`

### Akış
```
Gün Bitti popup → "Yeni Güne Başla" → ReklamServisi.goster()
  ↓ (emülatörse / reklam yoksa: anında)
  ↓ (gerçek cihaz + reklam varsa: tam ekran geçiş reklamı)
onClosed: _state.gunuBitir() → Yeni gün
```

İflas durumunda reklam GÖSTERİLMEZ (`paraOncesi - toplamKesinti < 0` dalı).

### Emülatör Algılama
`main()` başında `ReklamServisi.emulatorAlgila()` `device_info_plus` ile `androidInfo.isPhysicalDevice` okur. Emülatörde:
- `MobileAds.instance.initialize()` ATLANIR
- `yukle()` no-op olur
- `goster()` direkt `onClosed()` çağırır

Bu sayede emülatörde AdMob hiç başlamaz, sahte gösterim olmaz.

### Kod Yapısı
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

## Pazarlık Çeşitliliği (v92)

Karşı tarafın hareketi her zaman gıdım gıdım değil — sürpriz büyük adımlar var. Bazen alıcı maliyetin çok üstüne, hatta piyasa fiyatının üstüne çıkabilir.

### Rezervasyon Fiyatı Sürprizi (`MusteriOzellik.reservationPrice`)
| Olasılık | Çarpan | Anlam |
|----------|--------|-------|
| %6 | 1.55–2.10× | Zengin/aceleci alıcı (veya dar satıcı) — çok yüksek tavan |
| %14 | 1.18–1.45× | Cömert |
| %80 | 1.00× | Normal (eski davranış) |

- Alıcı tavanı: `marketPrice * 0.50 ... 2.30` (eskiden max 1.20)
- Satıcı tabanı: `marketPrice * 0.40 ... 1.55` (eskiden min 0.65)

### Tur Başına Adım Büyüklüğü (`oyuncuTeklifVer` → `concessionRatio`)
| Olasılık | Çarpan | Anlam |
|----------|--------|-------|
| %10 | 2.5–4× | BÜYÜK sıçrama — "anlaştık gibi" |
| %20 | 1.4–2.2× | Orta sıçrama |
| %70 | 0.5–1.3× | Normal/küçük — gıdım değil ama makul |

Base ratio hâlâ `_clamp(0.18 - progress * 0.15, 0.02, 0.18)`.

---

## Versiyon Geçmişi (son)
| Commit | Açıklama |
|--------|----------|
| v118 | **🚗 Galerici Gürbüz + araçlar + 🏠 ev/yazlık**: yeni özel müşteri Gürbüz 4. günden itibaren 3 günde bir gelir, "Araç Seç" tezgâhından seçilen araç normal pazarlığa dönüşür, alınan araç envantere girer (5 araç, 3000-14000). Browser'da **Konum Değiştir** (araç yoksa kilitli); Market'te **Ev (10000)** ve **Yazlık (12000)**. Yolculukta solda araç + saat yönünün tersine dönen halka, süre aracın niteliğine göre (30-120 sn); bitince müşteri yokken "Eve geçmek istiyor musun?" popup'ı. Ev sahnesi: eşyalar doluev.png'den ölçülen oranlarla (9 eşya), Yazlık: .ora tam tuval katmanları birebir bindirme (12 eşya, tezgâh için kırpılmış ikonlar). `test/arac_ev_test.dart` 20 test. Rotasyon migrasyonuna `_rotasyonDisi` seti (hande sızması da kapandı) |
| v117 | **📚 Koleksiyon artık kazanılıyor**: satılan ürün otomatik açılmıyor, envanterdeki ürüne dokunup "Koleksiyona Taşı" demek gerekiyor (geri dönüşü yok, ürün bir daha satılamaz). Hedefler sayfası **HEDEFLER / KOLEKSİYON** sekmelerine ayrıldı; tablo 8 değil **6 sütun**, sabit **60 kutu**; altında 12 koleksiyon hedefi ilerleme çubuğuyla, her biri bir kez para ödülü veriyor. **Süreli bildirim müşteriyi tutuyor** — seri/hedef toast'ı okunurken müşteri kayıp gidiyordu, artık toast kapanınca gitmeye başlıyor; toast süresi 2400→4200 ms. **Masadaki oynanabilir oyun belli**: büyütmede "⭐ Oynanabilir Oyun!" + açıklama. **Yeniden Başlat** artık ana menüye dönüyor, doğrudan yeni oyun açmıyor. **Banka** 3. günden önce kilitli, max taksit 3/6/9 → 6/8/10. Browser menüsünde Hedefler en üstte, Satılık Dükkanlar ikonu 🔑 → 🏡 |
| v115 | **📳 Buton dokunuşunda haptik**: ana ekrandaki bütün önemli butonlar `_oyunButon`'dan geçtiği için haptik tek yerden veriliyor (`SesServisi.dokun()` — ses yok, sadece `selectionClick`). Pasif butonda titreşim yok. Kolonya Tut kendi CustomPaint'ini kullandığından haptiği elle veriliyor. **Titreşim artık ayrı ayar**: `sesAcik`e bağlıydı, kendi anahtarına (`titresimAcik`) alındı — sessiz oynayan biri titreşimi isteyebilir. Hem ana menü hem oyun içi Ayarlar'da Açık/Kapalı switch'i var. **Ayarlar kalıcı**: `AyarServisi` ile SharedPreferences'ta, oyun kaydından ayrı anahtarlarda; oyunu sıfırlamak tercihleri kaybettirmiyor. |
| v114 | **👩‍🏫 Rehber Hande**: oyunun en başında, "Müşteri Çağır"a basılmadan gelen tanıtım karakteri; dört repliği tek ve geniş "Tamam" butonuyla anlatıp gidiyor. Müşteri sayacını tüketmiyor, rotasyona girmiyor, bir kez geliyor (`handeGosterildi` kayıtta saklanıyor; eski kayıtlarda `true` sayılıyor ki tanıtım açılmasın). **💰 Para sayacı animasyonu**: satış/alımda bakiye kutusu büyüyor, yeşile (giriş) / kırmızıya (çıkış) dönüyor, rakamlar eski değerden yenisine sayarak ilerliyor, sonra normale soluyor (2.2 sn). Animasyon ortasında yeni değişim gelirse ekrandaki değerden devam ediyor, sayı geri sıçramıyor. Tamir Et butonu koyu maviye alındı (gri anahtar emojisi açık mavide kayboluyordu). `test/guvenlik_test.dart` 28 test. |
| v113 | **🛡️ Yakışıklı Güvenlik**: 3. günde (ve reddedilirse 3'ün katlarında) gelen özel müşteri; günde 50 liraya çalışır, tutulduğu sürece **hırsız hiç gelmez** ve arka plan güvenlikli sürüme geçer. Güvenliğe dokununca müşteri gibi öne gelip "İşi bırakmamı ister misin?" diye sorar — öne gelirken arka plandaki kopyası silinir (`_guvenlikOnde`), yoksa ekranda iki güvenlik olurdu. HAYIR'da sağa kaymaz, yukarı süzülüp kaybolur ve yerine geçmiş gibi görünür. Dokunma katmanı Stack'in EN SONUNDA olmak zorunda (sonra gelen çocuk önce hit-test edilir; masa/SafeArea dokunuşu yutuyordu). **🔑 Satılık Dükkanlar**: 5. günde açılan yeni browser bölümü, 5 dükkan (5000-20000), satın alınınca kira yok; ikinci dükkan kiraya verilip günlük gelir sağlanabilir. Dükkan artık kayıtta İSİMLE saklanıyor. **🏠 Dükkan görselleri dosya adıyla eşleşti** (`dukkan_<ad>.jpg` / `_guv.jpg`, eski `bgbos*` kaldırıldı); Cadde↔AVM sanatı yer değiştirdi, Çarşı ve 5 satılık için kapı camı yeniden ölçüldü. **Diğer**: Toptancı tezgâhı tek renk sarı, envanter turkuaz; çürük ürün ekranı büyütme diline geçti (Çöpe At/Tamir Et + tam genişlik Kapat); İTELE topu %30 hızlandı; 9 yeni ekipman + 4 yeni karakter (3'ü sabit adlı: Recai Carlos, Kahraman Memo, Şakir Oneyıl). `test/guvenlik_test.dart` (21 test). APK 60.9 → 65.8MB |
| v112 | **🐛 Pazarlığı donduran `clamp` hatası düzeltildi**: müşterinin teklifi rezervasyon sınırına dayanınca `clamp(alt, üst)` çağrısının alt sınırı üst sınırını geçiyor, Dart `ArgumentError` atıyordu; istisna `teklifVer`den kaçtığı için ne replik ne yeni fiyat güncelleniyordu — oyuncu "Teklif Ver"e basıp duruyor, hiçbir şey olmuyordu. Artık clamp öncesi "yer kaldı mı" kontrolü var, yer yoksa `atFloor` dalına düşüp kabul/git kararı veriliyor. `test/pazarlik_test.dart` (6 test) eklendi. **Ürün büyütme artık `showDialog`** — Toptancı Rıza penceresi açıkken altında kalmıyordu (Stack katmanı → dialog route); Rıza'nın tezgâhındaki ürünlere de tıkla-büyüt eklendi. **"Yeterli paran yok"** durumunda ürün artık masadan aşağı kaymıyor, müşteriyle birlikte çıkıyor (`sonAnlasmaBasarisiz`). Bodrum Kat kapı silüeti sağdan %10 kısaldı (0.1330→0.1197). **İçerik**: 5 CD görseli yenilendi, 16 yeni CD (`CD_31..46`, toplam 46), 8 yeni karakter (`musteri_35..42`, roster 42). APK 54.0 → 60.9MB |
| v111 | **16 maddelik düzeltme listesi**: ürün artık müşteriyle aynı karede giriyor (ayrı `_urunKayipController`, `AnimatedPositioned` kaldırıldı); yeni oyunda envanterde oynanabilir ürün yok (`// GECICI` kodu silindi); envanterdeki sağlam ürüne tıkla → büyüt + Çöpe At; tamir popup butonları (Tamir Et solda, Vazgeç sağda, ikisi de dolu arkaplan); browser sabit boyut + her sayfada Geri/Kapat, Ayarlar'da da; ses ayarı gerçek switch (Açık/Kapalı segment); sarı mouse balon görseli %30 küçüldü; 2 dükkan kapı silüeti sağa %15 genişledi; Kırgeç/İtele bitiş metinleri FittedBox ile taşmıyor; seri bildirimi ekran merkezinde; İtele: top %20 hızlı + kırmızı X kapatma + başlangıç yazısı alt yarıda; Falcı'ya 25 yeni fal metni (havuz 50→75); TISSS başlangıç yazısı üst 1/3'te; kolonya "zombi müşteri" hatası düzeltildi (reddedilip çıkış animasyonu oynayan müşteriye kolonya verilemez artık) |
| v110 | **Browser tek pencere navigasyonu**: Kiralık Dükkanlar / Hedefler / Market / Banka artık ayrı popup değil, browser'ın içinde sayfa (`_BrowserSayfa` enum'u, adres çubuğu değişiyor, sarı geri oku menüye dönüyor). Banka'nın tutar/taksit seçimi `_GameScreenState` alanlarına taşındı — gövde her karede baştan çalıştığı için widget içinde tutulamıyordu; rastgele başlangıç tutarı yalnız sayfaya girerken üretiliyor. Hedefler'in `ListView`'ü `List.generate` oldu (iç içe kaydırma yok). **6 yeni karakter** (`musteri_29..34`, kaynak klasörde işlenmemiş kalanlar; 500×500 ve doluluk 0.95 geldiği için olduğu gibi kopyalandı) → roster 34. **10 yeni ekipman** (`konsol_11..19` + `joystick.png`; 9 retro el/masaüstü konsolu + arcade joystick, v109'un 0.90 doluluk hattından) → toplam ürün 59. APK 49.9 → 54.0MB |
| v109 | **9 yeni ekipman**: 3 el konsolu (`konsol_8/9/10.png`) + 6 aksesuar (3D Gözlük, Oyuncu Kulaklığı, Kulaklık ve Stant, Kablosuz Joypad, Direksiyon Seti, Oyuncu Mausu). Görseller mevcut ekipman formatına çevrildi (500×500, doluluk 0.90, en-boy korunur). Sahnede fazla büyük durmasınlar diye `kucukGorseller` kümesine eklendiler (%85) — o liste artık `Set` sabiti, uzun `||` zinciri değil. Fiyatlar 260-850, mevcut aralıkla uyumlu. Toplam ürün 49. APK 47.6 → 49.9MB |
| v108 | **13 yeni CD** (normal, oynanamaz): ŞEHRİŞER, UÇURBENİ, CIPCIP, TANTUNİ, VURKAÇ, BİLEZ, TAHTAKALE, SÜMSÜK, BİLEKZORU, MAHŞER, DİKİZ, TAMTAM, KOKARCA → `CD_18..30.png`, toplam CD 17'den 30'a çıktı. Görseller kullanıcının removebg kesimiyle geldi, mevcut CD formatına çevrildi (392×512, doluluk 0.83, içerik ~300×425). **Fiyatlar ortalamayı koruyacak şekilde dağıtıldı** (90-190, ortalama ~136) — yoksa "oynanabilir = normalin 2 katı" dengesi ve onu koruyan test bozulurdu. APK 43.3 → 47.6MB |
| v107 | **TISSS** (yılan) üçüncü oynanabilir oyun olarak eklendi — `lib/tisss_oyunu.dart`, `cd17`. 15×21 ızgara, yem başına 5 puan, her yemde hafif hızlanma, duvara/kendine çarpınca biter. **Kontrol farkı**: Kırgeç/İtele basılı tutmayla sürekli kayarken TISSS'te her dokunuş 90° göreceli dönüş (sağ yarı sağa, sol yarı sola); dönüşler kuyruğa alınıp adım başına biri uygulanıyor ki aynı adımda iki dokunuş yılanı kendi üstüne katlamasın. Aynı gün-sınırı, para tavanı ve nadirlik kuralları geçerli |
| v106 | **Oynanabilir ürünler**: bazı CD'ler gerçekten oynanıyor. `KIRGEÇ` (breakout, `lib/kirgec_oyunu.dart`) ve `İTELE` (tek kişilik pong, `lib/itele_oyunu.dart`). Envanterde köşede ⭐, tıkla → "oynamak ister misin?" → tam ekran oyun; toplanan puan birebir paraya çevrilip bakiyeye eklenir. **Günde 1 kez** (`bugunOynananOyunlar`, `gunuBitir`'de temizlenir, oyuna girer girmez hak yanar), para tavanı 1000, %5 nadirlik, toptancı/kutudan çıkmaz, fiyat normal CD ortalamasının 2 katı (270). Kontrol iki oyunda da aynı: ekranın sağ/sol yarısına basılı tut. `test/kirgec_test.dart` (10 test) |
| v105 | **Pazarlık hataları düzeltildi**: geçersiz girdide sessiz `return` (buton artık pasif+soluk), `teklifVer` hata atınca popup kapanmıyordu (`pop` artık `finally` içinde). **Teklif yön kuralı**: müşteri reddettikten sonra oyuncu alıyorsa ▼, satıyorsa ▲ pasif; ilk turda serbest. **Polis alkol testi** (%50): rastgele işlem + 2 şık, doğruysa ceza yok, yanlışsa 40-250 ceza. **"Yemeği Ye"** butonu (kuryeden yemek alınca alt barın en altında): envanterdeki tüm hasarlı ürünleri onarır. **Müşteriler 1/3 ihtimalle hasarlı ürün satıyor** — `GameItem.curukOran` ile müşteri malı %50-75 (toptancı hurdası %35). **Toptancı**: browser menüsünden kaldırıldı, kolonya ikramında gitmiyor, Kapat butonu sabit. **Müşteri Çağır** ekranda biri varken kilitli (Rıza'nın tekrar gelme bug'ı). Ana menüde **en yüksek kazanç** rekoru. `test/oynanis_test.dart` (9 test) |
| v104 | **Falcı Faloya** özel müşterisi: 40-140 liraya fal bakar, 50 fal metni, 14 etki türü (para kazanç/kayıp, bedava dükkan büyütme, "benden sonra vergici gelecek" kehanetleri, kolonya/tamir seti/kutu hediyesi, ürün çürütme, cömert müşteri şansı); parası yetmezse ücret alınmaz. **Dükkana göre arka plan**: 3 yeni görsel (JPEG, +1.1MB APK), seviye 2/3/4-5'e atandı, AnimatedSwitcher ile çapraz solma. **Kapı silüeti yeniden yazıldı**: `biri.png` tam ekran cover yerine `kapidaki.png` sprite'ı, arka planın cover kutusuna göre dükkan başına konumlanıyor (seviye 1 birebir aynı kaldı). `test/fal_test.dart` (11 test) |
| v103 | **Yaş/cinsiyet duyarlı replik sistemi**: `enum YasGrubu` (cocuk/genc/yetiskin/yasli) + `Replik{metin,yas,cinsiyet}` kaydı + `replikSec` filtresi (uyan→nötr→tüm havuz güvenlik zinciri); 28 karakterin hepsine yaş etiketi; TÜM replik havuzları `List<String>`→`List<Replik>`; selamlama 20→39, karşı teklif 25→48/46, kabul 26→42, gitme 18/18/12→27/26/19; `test/yas_replik_test.dart` regresyon testi (6 test). Ayrıca: 17 yeni karakter görseli kullanıcının kendi kesimiyle değiştirildi (işlenmeden kopyalandı), kaynakta md5 tekrarı ve bir eksik karakter yüzünden roster 29→28, `musteri_29.png` silindi |
| v97 | **Büyük oynanış güncellemesi**: Toptancı Rıza (günlük stok, ucuz ürün), çürük ürün + CD tamir seti ekonomisi, kapalı kutu (lootbox), 8 rozetli Hedefler ekranı, 10 rastgele gün olayı. Tümü browser menüsünden erişilir — alt bar/sahne layout'una dokunulmadı |
| v102 | 18 yeni müşteri karakteri (toplam 29: 14E/15K); beyaz zemin C# flood-fill ile temizlendi, oyunun 500×500 çerçevesine normalize edildi; tools/arkaplan_sil.ps1 yeniden kullanılabilir araç; isim havuzu 150+150 (hepsi benzersiz); SIRADAKİ İŞ: yaş sistemi |
| v101 | Ses sistemi: 11 yeni tetikleyici bağlandı (dosyalar eksik olsa da çökmez), HapticFeedback ile dokunsal geri bildirim |
| v100 | **Pazarlık motoru hamle okuma**: `enum Hamle` ile oyuncunun tavizi sınıflandırılıyor (geri/aynı/küçük/orta/büyük); geri adımda müşteri fiyat kırmaz + gidebilir, ısrar yorar, büyük jest ödüllendirilir; kaprisli evet (%5), bir kez sıkıştırma (%30), son teklif uyarısı, jest kabulü |
| v99 | Diyalog havuzları 5-10 katına çıkarıldı (selamlama 20+20, karşı teklif 25+25 **rol ayrı**, kabul 26, gitme 18/18/12); toast bildirimi Material SnackBar'dan oyun temasına uygun animasyonlu karta çevrildi (elasticOut, glow, okunabilir kontrast) |
| v98 | Bağlılık mekanikleri: 🔥 seri/kombo (3+ anlaşmada bonus, kızgın müşteride sıfırlanır), 🎯 günlük hedef (6 tip, dükkan seviyesiyle ölçeklenir), ☀️ yarının olayı gün sonunda duyurulur ("bir gün daha" kancası, sabah popup'ı kaldırıldı), 📚 koleksiyon paneli (23 ürün, % tamamlanma) |
| v97 | **Çözünürlükten bağımsız sahne** — `SahneMetrik` ile ürün/isim/müşteri masa görseline kilitlendi; sabit piksel kaldırıldı; 20:9 / 16:9 / 4:3'te doğrulandı |
| v96 | App Store'da YAYINDA (id6778437262); iOS reklam ID TEST→PROD (1436676062); ATT dialog (Guideline 2.1 düzeltmesi, app_tracking_transparency); ürün/isim konumu yukarı (ürün -20, isim 338); sürüm 1.0.2+13 (AAB v13); MARKET BUILD ÖNCESİ test-ID kontrol kuralı; app-ads.txt doğrulama notları |
| v95 | iOS TestFlight aktif: Codemagic pipeline tam çalışır durumda (10+ iterasyon sonrası signing/SwiftPM/build-number/icon hataları çözüldü); Magnus'tan paylaşımlı .p12 cert; CERTIFICATE_PRIVATE_KEY env var; iOS app icon (mavi Flutter üçgeni → gerçek ikon); ITSAppUsesNonExemptEncryption=false; App Privacy formu dolduruldu; support.html + marketing.html (TR/EN) GitHub Pages'te yayında; store/appstore_description_tr.txt yedeği |
| v94 | iOS App Store hazırlığı: Bundle ID `com.oyuncudukkani.app`, deployment target 13.0, Info.plist'e AdMob iOS App ID + ATT izni + 43 SKAdNetwork ID, codemagic.yaml ile TestFlight'a otomatik gönderim |
| v93 | Versiyon 1.0.1+12 — Google Play Store için AAB yayını (app-release.aab 61.9MB) |
| v92 | Prod AdMob ID (ca-app-pub-6470338276121414/...); device_info_plus ile emülatör algılama (emülatörde reklam yok); pazarlık çeşitliliği: %6 zengin/%14 cömert müşteri rezervasyon sürprizi, %10 büyük + %20 orta + %70 normal adım sıçraması |
| v91 | AdMob interstitial reklam: her yeni gün başına geçiş reklamı (game over değilse). ReklamServisi sınıfı, Kotlin 2.1.0'a yükseltildi (transitive webview_flutter bağımlılığı için) |
| v90 | "Vazgeç" → "Reddet" (altbar + popup); Maliyet fontu Piyasa ile eşitlendi (RichText, fontSize 14, w600); "el konsolu" → "El Konsolu"; alıcıya kolonya sonrası 6 random mesaj (tekrar engelli, X = orijinal ürün adı) |
| v89 | Asset optimizasyonu: bgbos/bg1/bg2/bgbosmasa/anamenu/browser/biri resize+recompress (APK 70.8MB → 36.1MB); pubspec wildcard → explicit list; Skia rendering (EnableImpeller=false) — emülatör ANR çözümü; Kolonya Tut butonu altbar'a taşındı (parlak amber, beyaz yazı), eski yerleşik widget kaldırıldı |
| v88 | Kolonya butonu tasarım: 0xFFE6A800 (parlak amber), beyaz yazı; gun=3 sonrası gösterilir; aktif/pasif state |
| v87 | Kurye özel müşteri: YeSekSepeti kuryesi, 3 farklı selamlama, EVET/HAYIR, 3sn gecikme, kurye bonusu; durum.png ürün görseli |
| v86 | Krediyi Al → Tebrikler popup (3 sn otomatik kapanır) |
| v85 | Banka kredisi popup yeniden yazıldı: gün çarpanı, ok butonları, faiz hesabı, kredi geçmişi taksit limiti |
| v84 | Kabul Et butonu alıcı müşteriler için de çalışır hale getirildi |
| v83 | Dükkan kiralama gün koşulları, kilitli dükkan %50 opaklık + 🔒, otomatik kapanan popup |
| v82 | Kolonya widget %15 küçültüldü, yarım kolonya boyu aşağı |
| v81 | Kolonya envanter slotu kullanmaz, +1 özel kart olarak gösterilir |
| v80 | Kolonya 2x büyük 1.5x yukarı; özel müşterilere kolonya ikramı özel mesaj+gönder |
| v79 | 1. günde iflas: bilgisayar popup gelmez, arka plan değişmez |
| v78 | Kolonya ürünü: satıcı müşteri, 10 kullanım, sağ widget, pazarlık bonusu |
| v77 | Bilgisayar Geldi popup: emoji üste, 6 rastgele mesaj |
| v76 | Kabul Et butonu pazarlık popup dışına taşındı |
| v70 | Envanter kompaksiyon, daire sayaç, pixel butonlar, balon görseli, yeşil tıklanabilir balon |

## Yeni Eklenen Alanlar (_GameScreenState / GameState)

```dart
// _GameScreenState
String? _kolonyaGeciciMesaj;   // 3 sn gösterilen özel mesaj (teşekkürler)
Timer? _kolonyaMesajTimer;
Timer? _kuryeTimer;
int _kolonyaSonrasiSonIdx = -1; // alıcı+kolonya sonrası random mesaj tekrar engeli

// GameState
int para = 1000;                  // başlangıç parası (eskiden 500)
String? _sonUrunId;               // ardışık aynı ürün engeli
bool kuryeBonusuAktif = false;    // bir sonraki müşteri çok avantajlı olacak
int kolonyaKullanim = 0;          // 0-10
bool kolonyaIkramEdildi = false;
double _kolonyaPendingBonus = 0.0;
List<OzelMusteriTip> _ozelTipSirasi; // [hirsiz, polis, vergici, kurye]
```

## Kayıt Migrasyonu (fromJson)

Eski kayıtlar için güvenli yükleme:
- `ozelTipSirasi` yoksa default sıra atanır
- Eksik tipler (kurye gibi yeni eklenen) otomatik sıraya eklenir
- `firstWhere` `orElse` ile crash önlenir
- `_devamEt()` içinde try/catch + bozuk kayıt için "Kayıt Okunamadı" popup'ı

## Dikkat Edilecekler
- `main.dart` tek ve büyük bir dosya — refactor önerilmez, performans yeterli
- Müşteri görseli **masa layer'ının altında** olmalı (Z-order kritik)
- `_bilgisayarGeldiGosterildi` flag'i state'de değil widget'ta — her oyun başında sıfırlanır, intentional
- `konsol_3/4/5/6.png`, `oyuncudireksiyonu.png`, `joypad.png` ürünleri %15 küçük gösterilir — intentional
- `durum.png` (kurye dürümü) %20 küçük — intentional
- Tüm "SON DEĞER — DOKUNMA!" yorumları uzun iterasyonlar sonucu bulunmuştur, değiştirmeden önce mutlaka test et
- Worktree'den değil her zaman **main repo'dan** (`C:\src\oyuncu_dukkani`) derle — worktree dalı eski commit'ten başlayabilir
- Kolonya butonu için `kolonyaKullanim > 0` koşulu — buton sadece kolonyacıdan kolonya alındıktan sonra görünür
- Asset değişikliği sonrası **build clean** gerekmez ama install için `-r` flag'ini unutma
- Emülatör tıkanırsa Cold Boot — saatlerce install/uninstall yapıldıysa system_server kötüleşir


