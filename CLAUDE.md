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
  └─ st         = viewPadding.top (status bar)
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

## 🆕 Toptancı / Çürük-Tamir / Kapalı Kutu / Hedefler / Gün Olayları (v97)

Dört yeni sistem eklendi. **Hepsi mevcut mekanikleri KİLİTLEMEZ, sadece ekler** — bu bilinçli bir tasarım kararı (eski akış hiç bozulmadı).

### Erişim noktası
Hepsi **browser popup'ı** (`_browserPopup`, 🖥️ butonu, `gun >= 2`) üzerinden. Alt bara hiç dokunulmadı → layout riski sıfır.
```
🖥️ Browser → 🏠 Kiralık Dükkanlar / 🏦 Banka / 🚚 Toptancı Rıza / 🏆 Hedefler / 🛒 Market / ⚙️ Ayarlar
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
- Görsel: `assets/toptanci.png` (400×400, kullanıcı üretti)

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
2. **+** (Add) → App IDs → App
3. Description: `Oyuncu Dukkani` (ASCII), Bundle ID: `com.oyuncudukkani.app` (Explicit)
4. Capabilities: hiçbir şey işaretleme
5. Register

### App Store Connect Setup (BİR KEZ)
1. https://appstoreconnect.apple.com → My Apps → **"+"** → New App
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

# YA Codemagic UI'dan manuel: Applications → oyuncu_dukkani → Start new build → main → ios-testflight
```

### Codemagic UI Kurulum (BİR KEZ tamamlandı)

**1. Repo bağlantısı**
- https://codemagic.io → Sign in with GitHub → "Add application" → oyuncu_dukkani repo

**2. App Store Connect API Key entegrasyonu**
- Codemagic UI → Personal Account → **Settings** → Integrations → **Developer Portal** → "Connect"
- App Store Connect → Users and Access → Integrations / Keys → "+" → App Manager rolünde key oluştur
- Key ID, Issuer ID, .p8 dosyasını Codemagic'e gir
- Name: **`Codemagic`** (YAML'da `integrations.app_store_connect: Codemagic` ile referans veriliyor)
- **Mevcut Key ID:** `2M84B256CL` (Magnus ile paylaşımlı)

**3. iOS Distribution Certificate (Code signing identity)**
- Personal Account → **Settings** → "Code signing identities" → "iOS certificates"
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
- Codemagic Personal Account → Settings → Global vars **deprecated** → Applications → oyuncu_dukkani → **Environment variables**
- `CERTIFICATE_PRIVATE_KEY` (Secret ✅, group: `signing_credentials`)
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
4. Group → Testers → kendi Apple ID'ni ekle
5. Group → Builds → "+ Add Build" → son build seç
6. iPhone'a mail gelir (5-15 dk) veya doğrudan TestFlight uygulamasında belirir

### App Privacy Formu (NSUserTrackingUsageDescription kullanılırsa)
App Store Connect → Oyuncu Dükkanı → **App Privacy** → Get Started:

**Data Types collected** (AdMob için):
- **Identifiers → Device ID**: Linked=Yes, Tracking=Yes, Purpose=Third-Party Advertising
- **Diagnostics → Crash Data**: Linked=No, Tracking=No, Purpose=App Functionality
- **Diagnostics → Performance Data**: Linked=No, Tracking=No, Purpose=App Functionality

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
- Domain: `anilgedikoglu.github.io` → app-ads.txt orada mevcut ✅

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
| v97 | **Büyük oynanış güncellemesi**: Toptancı Rıza (günlük stok, ucuz ürün), çürük ürün + CD tamir seti ekonomisi, kapalı kutu (lootbox), 8 rozetli Hedefler ekranı, 10 rastgele gün olayı. Tümü browser menüsünden erişilir — alt bar/sahne layout'una dokunulmadı |
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
