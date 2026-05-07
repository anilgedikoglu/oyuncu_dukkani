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

### ⚠️ KRİTİK: Görsel Katman Sistemi ve Konumlar — DOKUNMA!

#### Outer Stack Z-order (arkadan öne):
1. `bgbos.png` — sabit dükkan arkaplanı (Positioned.fill)
2. `biri.png` — kapı gölgesi (müşteri yokken AnimatedOpacity ile görünür)
3. **MÜŞTERİ görseli** — masanın ALTINDA (bu katmanda olmalı!)
4. **Masa layer** (`AnimatedSwitcher`) — müşterinin ÜZERİNDE:
   - Gün < 3: `bgbosmasa.png`
   - Gün >= 3 ve iMac yok: `bg1.png`
   - iMac alındı: `bg2.png`
   - Tüm masalar: `scale: 1.4, alignment: Alignment.bottomCenter`
5. **SafeArea** → header + `_buildSahne()` + altbar
6. Dükkan kiralama butonu (gün >= 3'te görünür)

#### ⚠️ MÜŞTERİ BOYUTU VE KONUMU (Outer Stack — katman 3):
```
width:  513px  ← DOKUNMA! Ekranı dolduruyor, alt kısmı masanın arkasına gizleniyor
height: 513px  ← DOKUNMA!
hedef = (screenW - 513) / 2   ← ortalanmış, ekrandan taşması intentional
dx    = hedef + (screenW - hedef) * slideAnim   ← sağdan kayarak giriş animasyonu
musteriTop = statusBar + 48.0 + screenH * 0.14 + 34
             ↑ status bar    ↑ header   ↑ %14   ↑ ince ayar
```
- `_buildSahne()` içindeki placeholder da **513×513 SizedBox** olmalı (Z-order korunur)
- `musteriTop` (_buildSahne içi) = `screenH * 0.14 + 34` (status bar yok, SafeArea içinde)

#### ⚠️ ÜRÜN KONUMU (_buildSahne() içinde — masa katmanının ÜSTÜNDEKİ katmanda):
```
width:  144px, height: 144px
productLeft = dx + 306
              ↑ müşteri animasyonunu takip eder  ↑ müşteri sol kenarından +306px sağa
productTop  = screenH * 0.57 - productSize - st - hh + 22
              ↑ ekranın %57'si  ↑ 144px   ↑ statusBar  ↑ 48 header  ↑ ince ayar
              → ürün ALT kenarı ekranın %57'sinde (masa yüzeyi hizası)
st = viewPadding.top (status bar), hh = 48.0 (header height)
```
- Ürün `_buildSahne()` Stack'inde **ayrı AnimatedBuilder** olarak render edilir
- İç müşteri Stack'ine (Positioned right/bottom) KOYMA — absolute koordinat kullan

### Önemli Oyun Mekanikleri
- **Gün sistemi**: Her gün N müşteri, gün sonunda kira düşülür
- **Pazarlık**: Müşteri teklif verir, oyuncu kabul/reddeder
- **Envanter slot sistemi**: Ürün alım/satım
- **Dükkan seviyeleri**: Kira ödeyerek büyütme
- **Özel müşteriler**: Hırsız, polis, vergici
- **iMac satın alma**: 3. günden sonra görünür buton, alındıktan sonra masa değişir
- **Bilgisayar Geldi popup**: 3. günde tetiklenir (tek seferlik, `_bilgisayarGeldiGosterildi` flag'i)
- **Oyun sonu**: Para bitti + envanter boş → iflas popup

### Kayıt Sistemi
SharedPreferences ile JSON serialize edilen `GameState`. `AnaMenuEkrani`'nda "Devam Et" butonu varsa kayıt mevcut demektir.

## Android Yapılandırması
- **Paket adı**: `com.oyuncudukkani.app` (eski: `com.example.oyuncu_dukkani`)
- **Uygulama ikonu**: `flutter_launcher_icons` ile `oyuncu_dukkani_icon.png`'den üretildi, adaptive icon destekli
- **Splash**: Android native splash kaldırıldı, Flutter tarafında `SplashScreen` widget'ı kullanılıyor

## DevicePreview
`device_preview` paketi şu an **disabled** (`enabled: false`). Test sırasında ekranı küçülttüğü için kapatıldı. Açmak için `enabled: kDebugMode` yap.

## Versiyon Geçmişi (son)
| Commit | Açıklama |
|--------|----------|
| v66 | Yeni arka plan sistemi, splash screen, uygulama ikonu, paket adı değişikliği, 3 yeni müşteri |
| v65 | Pazarlık popup yenilendi, kabul mesajları, sürüm 1.0.1+2 |
| v64 | Kayıt sistemi, ses, browser, market, iMac, background animasyonları |
| v63 | Özel müşteriler, envanter slot sistemi, dükkan seviyeleri |

## Dikkat Edilecekler
- `main.dart` tek ve büyük bir dosya — refactor önerilmez, performans yeterli
- Müşteri görseli **masa layer'ının altında** olmalı (Z-order kritik)
- `_bilgisayarGeldiGosterildi` flag'i state'de değil widget'ta — her oyun başında sıfırlanır, bu intentional
- Eski arka plan dosyaları (`dukkan_bg*.png`) silindi, referans kalmadığını doğrula
