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
  hirsiz/polis/vergici.png — özel müşteri karakterleri
  oyuncu_dukkani_icon.png  — uygulama ikonu kaynağı
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

Sadece `musteriSatiyor == true` durumunda gösterilir.

**Boyut:**
```
Standart ürünler      : productSize = 151.0 px
konsol_3.png          : productSize = 151.0 * 0.85 ≈ 128px  (%15 küçük)
oyuncudireksiyonu.png : productSize = 151.0 * 0.85 ≈ 128px  (%15 küçük)
```

**Yatay (productLeft):**
```
Tüm ürünler           : dx + 306
oyuncudireksiyonu.png : dx + 306 + 7 = dx + 313   (özel +7px sağa)
```

**Dikey (productTop):**
```
screenH * 0.57 - productSize - st - hh + 32
  └─ 0.57       = ürün ALT kenarı ekranın %57'sinde (masa yüzeyi hizası)
  └─ productSize = 151 veya 128 (ürüne göre)
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
- **Özel müşteriler**: Hırsız, polis, vergici
- **iMac satın alma**: 3. günden sonra görünür buton, alındıktan sonra masa değişir
- **Bilgisayar Geldi popup**: 3. günde tetiklenir (tek seferlik, `_bilgisayarGeldiGosterildi` flag'i)
- **Oyun sonu**: Para bitti + envanter boş → iflas popup
- **Devam Et butonu**: `_kayitVar` flag'i ile kontrol edilir — kayıt yoksa pasif

## Android Yapılandırması
- **Paket adı**: `com.oyuncudukkani.app` (eski: `com.example.oyuncu_dukkani`)
- **Uygulama ikonu**: `flutter_launcher_icons` ile `oyuncu_dukkani_icon.png`'den üretildi, adaptive icon destekli
- **Splash**: Android native splash kaldırıldı, Flutter tarafında `SplashScreen` widget'ı kullanılıyor

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
Butonlar: sadece "Vazgeç" (kırmızı) + "Fiyat Ver" (altın) — "Kabul Et" yok.

---

## Envanter Kompaksiyon

`urunCikar()` → ürün çıktıktan sonra dolu slotlar öne çekilir, boşluklar sona itilir:
```dart
final dolu = slotlar.sublist(0, acikSlotSayisi).whereType<GameItem>().toList();
for (int j = 0; j < acikSlotSayisi; j++) slotlar[j] = j < dolu.length ? dolu[j] : null;
```

---

## Versiyon Geçmişi (son)
| Commit | Açıklama |
|--------|----------|
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

## Dikkat Edilecekler
- `main.dart` tek ve büyük bir dosya — refactor önerilmez, performans yeterli
- Müşteri görseli **masa layer'ının altında** olmalı (Z-order kritik)
- `_bilgisayarGeldiGosterildi` flag'i state'de değil widget'ta — her oyun başında sıfırlanır, intentional
- `konsol_3.png` ve `oyuncudireksiyonu.png` ürünleri %15 küçük gösterilir — intentional
- Tüm "SON DEĞER — DOKUNMA!" yorumları uzun iterasyonlar sonucu bulunmuştur, değiştirmeden önce mutlaka test et
- Worktree'den değil her zaman **main repo'dan** (`C:\src\oyuncu_dukkani`) derle — worktree dalı eski commit'ten başlayabilir
