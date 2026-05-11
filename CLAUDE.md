# Oyuncu Dükkanı — Claude Bağlamı

## Proje Özeti
Flutter ile geliştirilmiş bir mobil oyun. Oyuncu bir oyun dükkanı yönetir: müşteri kabul eder, pazarlık yapar, envanter yönetir, dükkanını büyütür.

## Teknik Yığın
- **Flutter** (Dart) — tek dosya mimarisi: `lib/main.dart`
- **Android** — paket adı: `com.oyuncudukkani.app`
- **pubspec.yaml** — versiyon: `1.0.0+11`
- Paketler: `audioplayers`, `shared_preferences`, `device_preview` (dev), `flutter_launcher_icons` (dev)

## Dosya Yapısı
```
lib/main.dart          — tüm oyun mantığı tek dosyada
assets/                — görseller ve sesler
  bg1.png              — masa (bilgisayarsız)
  bg2.png              — masa (bilgisayarlı / iMac alındıktan sonra)
  bgbos.png            — sabit arka plan
  bgbosmasa.png        — masa (3. günden önce)
  biri.png             — kapı gölgesi (müşteri yokken görünür)
  musteri_1..11.png    — müşteri karakterleri
  hirsiz/polis/vergici/kurye.png — özel müşteri karakterleri
  CD_1..14.png         — 14 farklı CD ürünü
  konsol_1..7.png      — konsol ürünleri (PlayStatyon, Ninetendo, Ateri, El Konsolu x3, son sistem)
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

## ⚠️ KRİTİK: Görsel Katman Sistemi ve Tüm Konumlar — DOKUNMA!

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
width:  564 px  ← DOKUNMA!
height: 564 px  ← DOKUNMA!

hedef     = (screenW - 564) / 2
dx        = hedef + (screenW - hedef) * slideAnim.value   ← sağdan giriş
musteriTop = statusBar + 48.0 + screenH * 0.14 + 44
              └─ statusBar = mq.padding.top
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
  bottom: 306,   // ← DOKUNMA! (SON DEĞER)
  left: 0, right: 0,
  child: Center(child: ...isim container...),
)
```

Özel müşteri — `_buildOzelMusteriWidget()` içinde **AYNI** yapı:
```dart
Positioned(
  bottom: 306,   // ← DOKUNMA! Normal müşteriyle eşleşmeli
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
screenH * 0.57 - productSize - st - hh + 32
  └─ 0.57       = ürün ALT kenarı ekranın %57'sinde (masa yüzeyi hizası)
  └─ productSize = 151 / 128 / 121 (ürüne göre)
  └─ st         = viewPadding.top (status bar)
  └─ hh         = 48.0 (header yüksekliği)
  └─ +32        = ince ayar ← DOKUNMA! (SON DEĞER)
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
→ Sadece TypewriterText (metin, renkli border)
```

**Müşteri ALICI ise** (`musteriSatiyor == false`):
```
→ Row layout:
   Sol : Image.asset(item.gorsel, width:100, height:100)  ← ürün görseli
   Ara : SizedBox(width: 8)
   Sağ : Expanded
           └─ Transform.translate(offset: Offset(-15, 0))  ← -15px sola ← DOKUNMA!
                └─ Center
                     └─ TypewriterText(textAlign: center)
```

---

## Önemli Oyun Mekanikleri
- **Gün sistemi**: Her gün N müşteri, gün sonunda kira düşülür
- **Pazarlık**: Müşteri teklif verir, oyuncu kabul/reddeder
- **Envanter slot sistemi**: Ürün alım/satım
- **Dükkan seviyeleri**: Kira ödeyerek büyütme
- **Özel müşteriler**: Hırsız, polis, vergici, **kurye** (YeSekSepeti)
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

## Android Yapılandırması
- **Paket adı**: `com.oyuncudukkani.app` (eski: `com.example.oyuncu_dukkani`)
- **Uygulama ikonu**: `flutter_launcher_icons` ile `oyuncu_dukkani_icon.png`'den üretildi, adaptive icon destekli
- **Splash**: Android native splash kaldırıldı, Flutter tarafında `SplashScreen` widget'ı kullanılıyor

### ⚠️ EnableImpeller=false (Skia)

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
`_oyunButon()` → `GestureDetector` + `CustomPaint(painter: _PixelButonPainter(...))`.
Yükseklik: 50px. Yazılar `FittedBox(fit: BoxFit.scaleDown)` ile taşmaz.

---

## Pazarlık Popup — Tıklanabilir Teklif Balonu

Müşteri ALICIYSA (`!musteriSatiyor && !anlasildi && !gitti && !_bitti`):
```
_dialogMesaj Container → GestureDetector
  borderRadius: 24 (oval)
  border: Color(0xFF4caf50), width: 1.8  ← yeşil
  boxShadow: yeşil parlama
  onTap: widget.state.teklifVer(musteriTeklif) → Navigator.pop()
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
| cd | cd1..14 | KARMAGEDDON, CİMRİCİTY, ..., TENİS OYUNU, DALAKKÜREK, ŞAHMAT, TOTORACER, GAMLIBAYKUŞ, KISPET, UÇARSOKAR, DÜTTÜRÜ | CD_1..14.png | 80-175 |
| konsol | konsol1 | PlayStatyon | konsol_1.png | 900 |
| konsol | konsol2 | Ninetendo | konsol_2.png | 750 |
| konsol | konsol3 | Ateri | konsol_3.png | 500 |
| konsol | konsol4/5/6 | El Konsolu (3 versiyon) | konsol_4/5/6.png | 380-560 |
| konsol | konsol7 | son sistem oyun konsolu | konsol_7.png | 3200 |
| aksesuar | aksesuar1..N | Direksiyon, Joypad, vs. | ... | ... |
| aksesuar | kolonya | Kolonya (slot dışı, +1 ilave) | kolonya.png | 120 |

---

## Versiyon Geçmişi (son)
| Commit | Açıklama |
|--------|----------|
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
