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

### Arka Plan Katman Sistemi (Stack sırası)
1. `bgbos.png` — sabit arka plan (her zaman görünür)
2. `biri.png` — kapı gölgesi (müşteri yokken, AnimatedOpacity)
3. Müşteri karakter görseli (masa layer'ının ALTINDA, AnimatedBuilder ile kayarak girer)
4. Masa layer (`AnimatedSwitcher`):
   - Gün < 3: `bgbosmasa.png`
   - Gün >= 3 ve iMac yok: `bg1.png`
   - iMac alındı: `bg2.png`
5. SafeArea → header + sahne + alt bar
6. Dükkan kiralama butonu (sadece gün >= 3'te görünür)

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
`device_preview` paketi `kDebugMode`'da aktif. Release build'de otomatik devre dışı kalır.

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
