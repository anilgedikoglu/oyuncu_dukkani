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

## Versiyon Geçmişi (son)
| Commit | Açıklama |
|--------|----------|
| v69 | Kapsamlı kod açıklamaları, CLAUDE.md tam güncelleme |
| v68 | Konum/boyut ince ayarları, konuşma balonu ürün görseli layout |
| v67 | Özel müşteri isim konumu düzeltildi, Devam Et butonu kayıt kontrolü |
| v66 | Yeni arka plan sistemi, splash screen, uygulama ikonu, paket adı |
| v65 | Pazarlık popup yenilendi, kabul mesajları, sürüm 1.0.1+2 |

## Dikkat Edilecekler
- `main.dart` tek ve büyük bir dosya — refactor önerilmez, performans yeterli
- Müşteri görseli **masa layer'ının altında** olmalı (Z-order kritik)
- `_bilgisayarGeldiGosterildi` flag'i state'de değil widget'ta — her oyun başında sıfırlanır, intentional
- `konsol_3.png` ve `oyuncudireksiyonu.png` ürünleri %15 küçük gösterilir — intentional
- Tüm "SON DEĞER — DOKUNMA!" yorumları uzun iterasyonlar sonucu bulunmuştur, değiştirmeden önce mutlaka test et
