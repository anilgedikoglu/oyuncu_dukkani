import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show HapticFeedback; // dokunsal geri bildirim
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'itele_oyunu.dart';
import 'kirgec_oyunu.dart';
import 'tisss_oyunu.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AyarServisi.yukle(); // ses/titreşim tercihleri açılışta geri gelsin
  await ReklamServisi.emulatorAlgila();
  if (!ReklamServisi.emulator) {
    // iOS: AdMob initialize'tan ÖNCE ATT izni iste (Apple zorunluyor — Guideline 2.1)
    // - notDetermined ise sistem dialog gösterir
    // - Daha önce reddedildiyse/onaylandıysa direkt geçer
    if (Platform.isIOS) {
      try {
        final status = await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status == TrackingStatus.notDetermined) {
          // Apple bilgi mesajı için ufak bekleme önerir, ardından sistem dialog'u tetiklenir
          await Future.delayed(const Duration(milliseconds: 200));
          await AppTrackingTransparency.requestTrackingAuthorization();
        }
      } catch (_) {
        // iOS 14 altı veya hata — sessizce devam et, AdMob non-personalized çalışır
      }
    }
    MobileAds.instance.initialize();
    ReklamServisi.yukle(); // ilk interstitial'i yukle
  }
  runApp(
    DevicePreview(
      enabled: false,
      builder: (context) => const OyuncuDukkaniApp(),
    ),
  );
}

// ─── REKLAM SERVİSİ ──────────────────────────────────────────────────────────
// Gün başı interstitial (geçiş reklamı). Prod AdMob unit ID'si kullanıyor.
// Emülatörde reklam çıkmaz (politika ihlali olmasın diye).
class ReklamServisi {
  // Geçiş (interstitial) reklam birimi — her iki platform da PROD
  static String get _adUnitId => Platform.isIOS
      ? 'ca-app-pub-6470338276121414/1436676062' // iOS PROD (oyuncudukkanigecis)
      : 'ca-app-pub-6470338276121414/4138047986'; // Android PROD
  static InterstitialAd? _interstitial;
  static bool _yukleniyor = false;
  static bool emulator = false;

  /// main()'de bir kez çağrılır — emülatör mü gerçek cihaz mı tespit eder.
  static Future<void> emulatorAlgila() async {
    if (!Platform.isAndroid) { emulator = false; return; }
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      emulator = !info.isPhysicalDevice;
    } catch (_) {
      emulator = false; // bilemiyorsak güvenli taraf: gerçek cihaz say
    }
  }

  static void yukle() {
    if (emulator) return;
    if (_yukleniyor || _interstitial != null) return;
    _yukleniyor = true;
    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _yukleniyor = false;
        },
        onAdFailedToLoad: (err) {
          _interstitial = null;
          _yukleniyor = false;
          // Sessizce başarısız ol — sonraki gün tekrar denenir
        },
      ),
    );
  }

  /// Hazırsa reklamı gösterir, sonra bir sonraki için yeniden yükler.
  /// Emülatörde veya reklam yoksa onClosed anında çağrılır.
  static void goster({required VoidCallback onClosed}) {
    if (emulator) { onClosed(); return; }
    final ad = _interstitial;
    if (ad == null) {
      yukle();
      onClosed();
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitial = null;
        yukle();
        onClosed();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _interstitial = null;
        yukle();
        onClosed();
      },
    );
    ad.show();
    _interstitial = null;
  }
}

class OyuncuDukkaniApp extends StatelessWidget {
  const OyuncuDukkaniApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oyuncu Dükkanı',
      debugShowCheckedModeBanner: false,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF1a1008)),
      home: const SplashScreen(),
    );
  }
}

// ─── DÜKKAN SEVİYE SİSTEMİ ───────────────────────────────────────────────────

class DukkanSeviye {
  final int seviye;
  final String isim;
  final int kira;
  final int minGun; // bu dükkana geçmek için gereken minimum gün
  /// Bu dükkanın arka plan görseli. Kiralanınca sahne arkası değişir.
  /// Elde 4 görsel var, 5 seviye — seviye 4 ve 5 aynı mağazayı paylaşır.
  final String arkaplan;
  /// Arka plan görselinin en/boy oranı. `BoxFit.cover` kutusunu hesaplamak
  /// için gerekli — kapı gölgesi bu kutuya göre konumlanır.
  final double arkaplanOrani;
  /// Kapıda bekleyen silüetin (`kapidaki.png`) arka plan görseli İÇİNDEKİ
  /// yeri: sol, üst, genişlik, yükseklik — hepsi 0..1 oranı.
  ///
  /// Bu dörtlü **kapı camının kendisi**. Silüet `BoxFit.fill` ile bu kutuya
  /// gerilir, yani camı boşluk bırakmadan doldurur. Yükseklik sprite oranından
  /// türetilseydi (denendi) camlar sprite'tan uzun olduğu için altta boşluk
  /// kalıyordu.
  final double kapiSol, kapiUst, kapiGen, kapiYuk;

  /// Yakışıklı Güvenlik tutulduğunda kullanılan arka plan — aynı dükkan, ama
  /// kapının yanında güvenlik duruyor. Kapı camının yeri DEĞİŞMEZ, o yüzden
  /// `kapi*` ölçüleri iki görsel için de geçerli.
  final String arkaplanGuv;

  /// Güvenlikli görsel AYNI dükkanın yeniden çizimi olduğu için kapı camı bir
  /// miktar kayabiliyor. Silüet iki sürümde de tam camda dursun diye güvenlikli
  /// sürüme uygulanan fark (0..1 oranı, varsayılan 0 = kayma yok).
  ///
  /// ⚠️ Ortalama bir değerle idare etmek yerine fark tutuluyor: ortalama, iki
  /// görselde de yanlış olurdu.
  final double kapiSolGuvFark, kapiUstGuvFark;

  /// Satılık dükkanlarda satın alma bedeli; kiralıklarda null.
  /// Satın alınan dükkanda **günlük kira ödenmez** (`kira` 0 verilir).
  final int? satinAlmaFiyati;

  bool get satilik => satinAlmaFiyati != null;

  const DukkanSeviye({
    required this.seviye, required this.isim, required this.kira, required this.minGun,
    required this.arkaplan, required this.arkaplanGuv, required this.arkaplanOrani,
    required this.kapiSol, required this.kapiUst, required this.kapiGen, required this.kapiYuk,
    this.satinAlmaFiyati,
    this.kapiSolGuvFark = 0, this.kapiUstGuvFark = 0,
  });

  /// Günlük müşteri sayısını ağırlıklı random ile belirle
  /// Alt sınır daha yüksek olasılıklı, üst sınır daha düşük
  int gunlukMusteriSayisiUret() {
    final rng = Random();
    final min = 10 + (seviye - 1) * 5; // 10, 15, 20, 25, 30
    final max = min + 5;               // 15, 20, 25, 30, 35
    // Ağırlıklı dağılım: 0..4 arası random, küçük değer daha olası
    // Üçgen dağılımı: min(r1,r2)*5 → alt değerlere yığılır
    final r1 = rng.nextDouble();
    final r2 = rng.nextDouble();
    final agirlikli = r1 < r2 ? r1 : r2; // min alarak alt değerlere yığ
    return min + (agirlikli * (max - min + 1)).floor().clamp(0, max - min);
  }

  String get yildizlar => '★' * seviye + '☆' * (5 - seviye);
}

// Kapı oranları = kapı CAMININ dikdörtgeni. Her görsel tek başına, 900px'lik
// panelde %1'lik ızgarayla ölçüldü; ayrıca parlaklık projeksiyonuyla otomatik
// doğrulandı ve dördü de emülatörde tek tek açılıp kontrol edildi.
/// ⚠️ Görsel dosyaları artık DÜKKAN ADIYLA eşleşiyor (`dukkan_<ad>.jpg` /
/// `dukkan_<ad>_guv.jpg`). Eski `bgbos*` isimleri kaldırıldı.
///
/// Sanat eşleşmesi doğrulandı (görsel imza karşılaştırmasıyla):
///   dukkan_bodrum  == eski bgbos.png     → ölçüler aynen korundu
///   dukkan_mahalle == eski bgbos_2.jpg   → ölçüler aynen korundu
///   dukkan_cadde   == eski bgbos_4.jpg   → bgbos_4'ün ölçüleri taşındı
///   dukkan_avm     == eski bgbos_3.jpg   → bgbos_3'ün ölçüleri taşındı
///   dukkan_carsi   = YENİ sanat          → yeniden ölçüldü
/// Yani v111'de sv3'e yapılan %15 genişletme artık AVM'ye ait; Cadde eski
/// bgbos_4 ölçüleriyle gidiyor. Karıştırma.
const List<DukkanSeviye> tumDukkanlar = [
  // kapiGen: sağda ~%10 taşıyordu — sol kenar ve dikey ölçüler SABİT,
  // genişlik sağdan %10 kısaltıldı (0.1330*0.90).
  DukkanSeviye(seviye: 1, isim: 'Bodrum Kat Dükkan',    kira: 300,  minGun: 1,
    arkaplan: 'assets/dukkan_bodrum.jpg',  arkaplanGuv: 'assets/dukkan_bodrum_guv.jpg',  arkaplanOrani: 719 / 1080,
    kapiSol: 0.3157, kapiUst: 0.0880, kapiGen: 0.1197, kapiYuk: 0.1593),
  // kapiGen: sağda boşluk kalıyordu — sol kenar ve dikey ölçüler SABİT,
  // genişlik sadece sağa doğru %15 uzatıldı (0.1224*1.15).
  DukkanSeviye(seviye: 2, isim: 'Mahalle Köşe Dükkanı', kira: 600,  minGun: 3,
    arkaplan: 'assets/dukkan_mahalle.jpg', arkaplanGuv: 'assets/dukkan_mahalle_guv.jpg', arkaplanOrani: 719 / 1278,
    // kapiUst: silüet yukarıda kalıyordu — kendi yüksekliğinin %10'u kadar
    // aşağı indirildi (0.1228 + 0.1667*0.10). Boy ve yatay ölçüler SABİT.
    kapiSol: 0.3380, kapiUst: 0.1395, kapiGen: 0.1408, kapiYuk: 0.1667,
    // Güvenlikli sürüm yeniden çizildi ve kapı camı biraz kaydı: ızgarayla
    // ölçüldü, cam 0.010 sola / 0.006 yukarı gitmiş.
    kapiSolGuvFark: -0.010, kapiUstGuvFark: -0.006),
  DukkanSeviye(seviye: 3, isim: 'Cadde Dükkanı',        kira: 900,  minGun: 5,
    arkaplan: 'assets/dukkan_cadde.jpg',   arkaplanGuv: 'assets/dukkan_cadde_guv.jpg',   arkaplanOrani: 719 / 1278,
    kapiSol: 0.3350, kapiUst: 0.1517, kapiGen: 0.1160, kapiYuk: 0.1582),
  // Yeni sanat — kapı camı 900px panelde %1 ızgarayla ölçüldü, çizdirilip doğrulandı.
  DukkanSeviye(seviye: 4, isim: 'Çarşı Dükkanı',        kira: 1200, minGun: 8,
    arkaplan: 'assets/dukkan_carsi.jpg',   arkaplanGuv: 'assets/dukkan_carsi_guv.jpg',   arkaplanOrani: 719 / 1080,
    kapiSol: 0.3440, kapiUst: 0.1110, kapiGen: 0.1170, kapiYuk: 0.1770),
  DukkanSeviye(seviye: 5, isim: 'AVM Dükkanı',          kira: 1500, minGun: 10,
    arkaplan: 'assets/dukkan_avm.jpg',     arkaplanGuv: 'assets/dukkan_avm_guv.jpg',     arkaplanOrani: 719 / 1278,
    kapiSol: 0.3588, kapiUst: 0.1385, kapiGen: 0.1280, kapiYuk: 0.1541),
];

/// ─── SATILIK DÜKKANLAR ──────────────────────────────────────────────────────
///
/// Kiralık değil, **satın alınır**. Satın alınınca günlük kira ödenmez
/// (`kira: 0`). `seviye` alanı burada slot sayısını belirlemeye devam ediyor —
/// pahalı dükkan daha çok slot açar.
///
/// Kapı camları her biri tek başına 900px panelde %1 ızgarayla ölçüldü,
/// sonra dikdörtgen görselin üstüne çizdirilip gözle doğrulandı.
const List<DukkanSeviye> satilikDukkanlar = [
  DukkanSeviye(seviye: 2, isim: 'Fakir Dükkan',        kira: 0, minGun: 5, satinAlmaFiyati: 5000,
    arkaplan: 'assets/dukkan_satilik1.jpg', arkaplanGuv: 'assets/dukkan_satilik1_guv.jpg', arkaplanOrani: 719 / 1080,
    kapiSol: 0.3550, kapiUst: 0.1630, kapiGen: 0.1100, kapiYuk: 0.1590),
  DukkanSeviye(seviye: 3, isim: 'Derme Çatma Dükkan',  kira: 0, minGun: 5, satinAlmaFiyati: 7000,
    arkaplan: 'assets/dukkan_satilik2.jpg', arkaplanGuv: 'assets/dukkan_satilik2_guv.jpg', arkaplanOrani: 719 / 1080,
    kapiSol: 0.3530, kapiUst: 0.1330, kapiGen: 0.1030, kapiYuk: 0.1590),
  DukkanSeviye(seviye: 4, isim: 'Lüks Dükkan',         kira: 0, minGun: 5, satinAlmaFiyati: 10000,
    arkaplan: 'assets/dukkan_satilik3.jpg', arkaplanGuv: 'assets/dukkan_satilik3_guv.jpg', arkaplanOrani: 719 / 1080,
    kapiSol: 0.3520, kapiUst: 0.1500, kapiGen: 0.1030, kapiYuk: 0.1630),
  DukkanSeviye(seviye: 4, isim: 'Klas Dükkan',         kira: 0, minGun: 5, satinAlmaFiyati: 13000,
    arkaplan: 'assets/dukkan_satilik4.jpg', arkaplanGuv: 'assets/dukkan_satilik4_guv.jpg', arkaplanOrani: 719 / 1080,
    kapiSol: 0.3550, kapiUst: 0.1580, kapiGen: 0.1250, kapiYuk: 0.1870),
  DukkanSeviye(seviye: 5, isim: 'Rezidans Dükkanı',    kira: 0, minGun: 5, satinAlmaFiyati: 20000,
    arkaplan: 'assets/dukkan_satilik5.jpg', arkaplanGuv: 'assets/dukkan_satilik5_guv.jpg', arkaplanOrani: 719 / 1080,
    kapiSol: 0.3530, kapiUst: 0.2500, kapiGen: 0.1040, kapiYuk: 0.1480),
];

/// Kiralık + satılık tüm dükkanlar (kayıt yüklerken isimle arama için).
List<DukkanSeviye> get butunDukkanlar => [...tumDukkanlar, ...satilikDukkanlar];

// ═══════════════════════════════════════════════════════════════════════════
//  SAHNE METRİĞİ — ÇÖZÜNÜRLÜKTEN BAĞIMSIZ KONUMLANDIRMA
// ═══════════════════════════════════════════════════════════════════════════
//
//  SORUN (eskiden): Masa görseli ekran GENİŞLİĞİNE göre ölçekleniyordu
//  (fitWidth + scale 1.4), ürün/isim/müşteri ise ekran YÜKSEKLİĞİNE göre
//  (screenH * 0.57) veya sabit piksellerle (bottom: 338) konumlanıyordu.
//  En-boy oranı değişince ikisi ayrışıyor, her cihazda elle ayar gerekiyordu.
//
//  ÇÖZÜM: Her şey masa görselinin EKRANDAKİ KUTUSUNA kilitlenir. Konumlar
//  görselin kendi içindeki 0..1 oranlarıyla ifade edilir (sanat eserinden
//  ölçülmüştür). Masa nereye giderse ürün, isim ve müşteri de oraya gider.
//  Oyun motorlarındaki "reference canvas / canvas scaler" yaklaşımı budur.
//
//  Masa görselinin render zinciri (build() içinde birebir aynısı):
//    Align(bottomCenter) → translate(0, 6) → scale(1.4, bottomCenter) → fitWidth
//
class SahneMetrik {
  final double ust; // masa görselinin ekrandaki üst kenarı (dp)
  final double boy; // masa görselinin ekrandaki yüksekliği (dp)
  const SahneMetrik(this.ust, this.boy);

  // bgbosmasa/bg1/bg2 — üçü de bu boyutta (doğrulandı)
  static const double gorselW = 719.0;
  static const double gorselH = 1080.0;
  static const double olcek   = 1.4;  // Transform.scale
  static const double kaydir  = 6.0;  // Transform.translate(0, 6)

  factory SahneMetrik.hesapla(Size ekran) {
    // Image(fit: fitWidth) gevşek kısıt altında en-boy koruyarak sığar
    double w = ekran.width;
    double h = w * gorselH / gorselW;
    if (h > ekran.height) { h = ekran.height; w = h * gorselW / gorselH; }
    final b = h * olcek;
    return SahneMetrik((ekran.height + kaydir) - b, b);
  }

  /// Görsel içi oran (0..1) → ekranda mutlak y
  double y(double oran) => ust + boy * oran;

  /// Görsel içi oran → dp uzunluk (boyutlar da masayla ölçeklenir)
  double u(double oran) => boy * oran;
}

// ── Sanat eserinden ölçülen / kalibre edilen oranlar ──
// Masa arka kenarı: bg1.png'de y=522/1080 (üç varyantta da aynı)
const double kMasaYuzeyi   = 0.4833;
// Ürünün masaya oturduğu çizgi (alt kenarı) — mousepad/klavye derinliği
const double kUrunTabani   = 0.5680;
// Ürün yüksekliği (masa boyuna oranla) — 411dp ekranda ~151dp'ye denk gelir
const double kUrunBoyu     = 0.1745;
// Ürünün müşteriye göre yatay kayması
const double kUrunSagKaydir= 0.3537;
// İsim etiketinin alt kenarı — masa çizgisinin hemen altı
const double kIsimAlti     = 0.4920;
// Müşteri görselinin üst kenarı ve boyu
const double kMusteriUstu  = 0.2183;
const double kMusteriBoyu  = 0.6519;

// ─── ANA MENÜ ────────────────────────────────────────────────────────────────

// ─── SPLASH SCREEN ───────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 6), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AnaMenuEkrani()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 340,
                child: Text(
                  'YASAL BİLGİLENDİRME\n\n'
                  '© 2026 Futurastic Tech. Tüm hakları saklıdır.\n\n'
                  'Bu oyun bağımsız bir yapımdır. Oyun içeriğinde yer alan tüm yazılım, tasarım, arayüz, görseller, metinler, sesler, animasyonlar ve oyun içi öğeler (aksine açıkça belirtilmedikçe) geliştiriciye aittir ve telif hakkı ile korunur.\n\n'
                  'ÜÇÜNCÜ TARAF MARKALARI / İSİMLERİ\n\n'
                  'Oyunda yer alabilecek veya oyunda anılabilecek üçüncü taraf marka, ürün, oyun adı, logo ve benzeri unsurlar ilgili sahiplerinin mülkiyetinde olabilir. Bu unsurlar yalnızca referans/temsili amaçlarla kullanılabilir ve herhangi bir sponsorluk, onay veya resmi bağlantıyı ifade etmez.\n\n'
                  'HİZMETİN SUNUMU\n\n'
                  'Oyun "olduğu gibi" ve "mevcut olduğu ölçüde" sunulur. Geliştirici; oyunun kesintisiz, hatasız, güvenli veya belirli bir amaca uygun olacağına dair açık ya da zımni bir garanti vermez. Performans, uyumluluk, veri kaybı veya üçüncü taraf servis kesintileri dahil olmak üzere doğabilecek sonuçlardan, yürürlükteki mevzuatın izin verdiği ölçüde sorumluluk kabul edilmez.\n\n'
                  'ÇEVRİMİÇİ ÖZELLİKLER / ÜÇÜNCÜ TARAF SERVİSLER\n\n'
                  'Oyun, Apple Game Center gibi üçüncü taraf servislerle entegre olabilir. Bu servislerin kullanımı ilgili servis sağlayıcıların şartlarına ve gizlilik politikalarına tabidir. Geliştirici, üçüncü taraf servislerin içerik ve kesintilerinden sorumlu değildir.\n\n'
                  'OYUN İÇİ DENGE VE SANAL İÇERİK\n\n'
                  'Oyundaki fiyatlar, ekonomi, puanlama, ödüller, item değerleri ve denge unsurları zaman içinde güncellenebilir. Oyun içi öğeler sanaldır; gerçek dünyada para veya mülk değeri taşımaz ve platform kuralları dışında iade/geri ödeme garantisi verilmez.\n\n'
                  'GİZLİLİK (ÖZET)\n\n'
                  'Oyun, performansı iyileştirmek ve hataları gidermek amacıyla cihaz/uygulama sürümü, çökme kayıtları ve benzeri teknik verileri işleyebilir. Kişisel veriler, yalnızca gerekli olduğu ölçüde ve ilgili platform kuralları kapsamında ele alınır.\n\n'
                  'Devam ederek Kullanım Şartları ve Gizlilik Politikası\'nı kabul etmiş sayılırsınız.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── ANA MENÜ ────────────────────────────────────────────────────────────────

class AnaMenuEkrani extends StatefulWidget {
  const AnaMenuEkrani({super.key});
  @override
  State<AnaMenuEkrani> createState() => _AnaMenuEkraniState();
}

class _AnaMenuEkraniState extends State<AnaMenuEkrani> {
  // Kayıtlı tercihlerden başlat — açılışta AyarServisi.yukle() zaten çalıştı.
  bool _sesAcik = SesServisi.sesAcik;
  bool _titresimAcik = SesServisi.titresimAcik;
  bool _ayarlarAcik = false;
  bool _yukleniyor = false;
  bool _kayitVar = false;
  int? _enYuksekGun;
  int? _enYuksekPara;

  @override
  void initState() {
    super.initState();
    KayitServisi.enYuksekGunYukle().then((v) { if (mounted) setState(() => _enYuksekGun = v); });
    KayitServisi.enYuksekParaYukle().then((v) { if (mounted) setState(() => _enYuksekPara = v); });
    KayitServisi.kayitVarMi().then((v) { if (mounted) setState(() => _kayitVar = v); });
  }

  void _yeniOyun() {
    KayitServisi.sil(); // fire-and-forget
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const GameScreen(yeniOyun: true)));
  }

  Future<void> _devamEt() async {
    if (_yukleniyor) return;
    setState(() => _yukleniyor = true);
    final varMi = await KayitServisi.kayitVarMi();
    if (!mounted) return;
    if (!varMi) {
      setState(() => _yukleniyor = false);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1a1008),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF8B5E3C), width: 2)),
          title: const Text('Kayıt Bulunamadı', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFF5E6C8), fontSize: 18)),
          content: const Text('Henüz kaydedilmiş bir oyun yok.\nYeni oyun başlatın!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
          actions: [Center(child: ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5E3C), foregroundColor: Colors.white),
            child: const Text('Tamam', style: TextStyle(fontWeight: FontWeight.bold)),
          ))],
        ),
      );
      return;
    }
    final json = await KayitServisi.yukle();
    if (!mounted) return;
    setState(() => _yukleniyor = false);
    try {
      final state = GameState.fromJson(json!);
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => GameScreen(yeniOyun: false, yuklenenState: state)));
    } catch (e) {
      // Kayıt bozuksa sil ve kullanıcıya bildir
      await KayitServisi.sil();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1a1008),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF8B5E3C), width: 2)),
          title: const Text('Kayıt Okunamadı', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFF5E6C8), fontSize: 18)),
          content: const Text('Kayıt dosyası bu sürümle uyumsuz.\nYeni oyun başlatın!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
          actions: [Center(child: ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5E3C), foregroundColor: Colors.white),
            child: const Text('Tamam', style: TextStyle(fontWeight: FontWeight.bold)),
          ))],
        ),
      );
    }
  }

  /// Ana menünün tepesindeki rekor kartı: en yüksek gün + en yüksek kazanç.
  Widget _rekorKutusu() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF241a10).withValues(alpha: 0.94), const Color(0xFF120c06).withValues(alpha: 0.94)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.85), width: 2),
        boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.22), blurRadius: 12)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🏆  REKORLAR',
          style: TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 8),
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (_enYuksekGun != null) _rekorHucre('EN UZUN', '$_enYuksekGun. gün', const Color(0xFFFFD700)),
          if (_enYuksekGun != null && _enYuksekPara != null)
            Container(width: 1, height: 30, margin: const EdgeInsets.symmetric(horizontal: 14),
              color: const Color(0xFFFFD700).withValues(alpha: 0.30)),
          if (_enYuksekPara != null) _rekorHucre('EN ÇOK KAZANÇ', '$_enYuksekPara lira', const Color(0xFF00FF88)),
        ]),
      ]),
    );
  }

  Widget _rekorHucre(String baslik, String deger, Color renk) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(baslik, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
      const SizedBox(height: 2),
      Text(deger, style: TextStyle(color: renk, fontSize: 16, fontWeight: FontWeight.w900,
        shadows: const [Shadow(color: Colors.black, blurRadius: 4)])),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/anamenu.png', fit: BoxFit.cover)),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Rekor kutusu EN ÜSTTE — eskiden butonların altında düz yazıydı,
                // gözden kaçıyordu.
                if (_enYuksekGun != null || _enYuksekPara != null) ...[
                  const SizedBox(height: 10),
                  Center(child: _rekorKutusu()),
                ],
                const Spacer(flex: 3),
                Center(child: _menuButon('Yeni Oyun', _yeniOyun)),
                const SizedBox(height: 12),
                Center(child: _menuButon('Devam Et', (_kayitVar && !_yukleniyor) ? () => _devamEt() : null)),
                const SizedBox(height: 12),
                Center(child: _menuButon('Ayarlar', () => setState(() => _ayarlarAcik = true))),
                const Spacer(flex: 2),
              ],
            ),
          ),
          if (_yukleniyor) const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
          if (_ayarlarAcik) _buildAyarlarOverlay(),
        ],
      ),
    );
  }

  Widget _menuButon(String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5E6C8),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFF8B5E3C), width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(2, 3))],
        ),
        child: Text(label, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3a2000), fontFamily: 'monospace', letterSpacing: 1)),
      ),
    );
  }

  Widget _buildAyarlarOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _ayarlarAcik = false),
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: Center(child: GestureDetector(
          onTap: () {},
          child: Container(
            width: 300, padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFFF5E6C8), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF8B5E3C), width: 2)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('⚙️ AYARLAR', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3a2000), letterSpacing: 1)),
              const SizedBox(height: 24),
              // Ses ve Titreşim ayrı ayarlar (oyun içi Ayarlar ile aynı mantık).
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('🔊 Ses:', style: TextStyle(fontSize: 16, color: Color(0xFF3a2000), fontWeight: FontWeight.bold)),
                GestureDetector(
                  onTap: () => setState(() {
                    _sesAcik = !_sesAcik;
                    SesServisi.sesAcik = _sesAcik;
                    AyarServisi.kaydet();
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: _sesAcik ? const Color(0xFF228B22) : const Color(0xFF8B0000), borderRadius: BorderRadius.circular(8)),
                    child: Text(_sesAcik ? 'AÇIK' : 'KAPALI', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('📳 Titreşim:', style: TextStyle(fontSize: 16, color: Color(0xFF3a2000), fontWeight: FontWeight.bold)),
                GestureDetector(
                  onTap: () => setState(() {
                    _titresimAcik = !_titresimAcik;
                    SesServisi.titresimAcik = _titresimAcik;
                    AyarServisi.kaydet();
                    if (_titresimAcik) SesServisi.dokun(); // örnek titreşim
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: _titresimAcik ? const Color(0xFF228B22) : const Color(0xFF8B0000), borderRadius: BorderRadius.circular(8)),
                    child: Text(_titresimAcik ? 'AÇIK' : 'KAPALI', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => setState(() => _ayarlarAcik = false),
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFF8B5E3C), borderRadius: BorderRadius.circular(10)),
                  child: const Text('Kapat', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ]),
          ),
        )),
      ),
    );
  }
}

// ─── MÜŞTERİ ÖZELLİKLERİ ────────────────────────────────────────────────────

class MusteriOzellik {
  final int sabir;
  final int titizlik;
  final int zeka;

  MusteriOzellik({required this.sabir, required this.titizlik, required this.zeka});

  factory MusteriOzellik.random() {
    final rng = Random();
    return MusteriOzellik(
      sabir:    1 + rng.nextInt(5),
      titizlik: 1 + rng.nextInt(5),
      zeka:     1 + rng.nextInt(5),
    );
  }

  // Normalize 0..1
  double get pat   => (sabir - 1)    / 4.0;
  double get met   => (titizlik - 1) / 4.0;
  double get intel => (zeka - 1)     / 4.0;

  int get maxTur => [2, 4, 5, 7, 9][sabir - 1];

  // perceivedValue: kondisyon + titizlik + zeka appraisal hatası
  double perceivedValue(int kondisyon, int marketPrice) {
    final cond = (kondisyon - 1) / 4.0;
    final conditionFactor = (1 + met * (cond - 0.5) * 1.2).clamp(0.55, 1.45);
    final appraisalNoise  = (1 - intel) * (_rnd(-0.12, 0.12));
    return (marketPrice * conditionFactor * (1 + appraisalNoise))
        .clamp(marketPrice * 0.40, marketPrice * 1.80);
  }

  // reservationPrice: müşterinin geçemeyeceği sınır
  // Sürpriz çarpanı: %6 ihtimalle çok cömert/cimri, %14 ihtimalle hafifçe — pazarlığı renklendirir
  double reservationPrice(double pv, int marketPrice, bool musteriSatiyor) {
    final rng = Random();
    final roll = rng.nextDouble();
    double surpriz = 1.0;
    if (roll < 0.06) {
      surpriz = 1.55 + rng.nextDouble() * 0.55;   // 1.55–2.10x (zengin/aceleci alıcı / dar satıcı)
    } else if (roll < 0.20) {
      surpriz = 1.18 + rng.nextDouble() * 0.27;   // 1.18–1.45x (cömert)
    }
    if (!musteriSatiyor) { // NPC alıyor: maksimum ödeyeceği
      return (pv * (0.75 + pat * 0.20 + met * 0.05) * surpriz)
          .clamp(marketPrice * 0.50, marketPrice * 2.30);
    } else { // NPC satıyor: minimum alacağı
      return (pv * (1.25 - pat * 0.20 - met * 0.05) / surpriz)
          .clamp(marketPrice * 0.40, marketPrice * 1.55);
    }
  }

  // Açılış teklifi
  double openingOffer(double reserv, int marketPrice, bool musteriSatiyor) {
    final agression = 0.15 + intel * 0.10 + pat * 0.08;
    final noise = (1 - intel * 0.8) * _rnd(-0.05, 0.05) * marketPrice;
    if (!musteriSatiyor) { // NPC alıyor: düşük aç
      return (reserv * (1 - agression) + noise)
          .clamp(marketPrice * 0.35, reserv * 0.95);
    } else { // NPC satıyor: yüksek aç
      return (reserv * (1 + agression) + noise)
          .clamp(reserv * 1.05, marketPrice * 1.80);
    }
  }

  static double _rnd(double min, double max) =>
      min + Random().nextDouble() * (max - min);
}


// ─── ÖZEL MÜŞTERİ (HIRSIZ / POLİS / VERGİCİ / KURYE / TOPTANCI / FALCI) ─────

enum OzelMusteriTip { hirsiz, polis, vergici, kurye, toptanci, falci, guvenlik, hande, galerici }

class OzelMusteri {
  final OzelMusteriTip tip;
  final String gorsel;
  final String ad;
  final int ilkMiktar;
  final String ilkMesaj;
  final String? kuryeAd;    // kurye için kurye ismi
  final String? kuryeYemek; // kurye için yemek ismi
  /// Polis "alkol testi" modundaysa dolu olur: iki şık + doğrusu.
  /// Şıkların yeri rastgele — doğru cevap hep solda olmasın.
  final int? sikSol, sikSag, dogruCevap;

  /// Bu polis ceza kesmiyor, matematik sorusu soruyor.
  bool get alkolTesti => sikSol != null && dogruCevap != null;

  /// Güvenlik "işe alalım mı?" değil, "işi bırakayım mı?" diye soruyor.
  /// (Oyuncu dükkanda duran güvenliğe tıklayınca bu hâlde gelir.)
  final bool istifaSorusu;

  OzelMusteri({required this.tip, required this.gorsel, required this.ad, required this.ilkMiktar, required this.ilkMesaj,
    this.kuryeAd, this.kuryeYemek, this.sikSol, this.sikSag, this.dogruCevap,
    this.istifaSorusu = false});

  /// Rehber Hande — oyunun EN BAŞINDA, "Müşteri Çağır"a basılmadan gelir.
  /// Alış/satış yapmaz; sadece `handeRepikleri`'ni sırayla anlatır.
  factory OzelMusteri.hande() => OzelMusteri(
        tip: OzelMusteriTip.hande,
        gorsel: 'assets/hande.png',
        ad: 'Hande',
        ilkMiktar: 0,
        ilkMesaj: handeReplikleri.first,
      );

  /// Hande'nin tanıtım metinleri. Her "Tamam"da sıradakine geçilir; sonuncudan
  /// sonra gider. Sıra `GameState.handeAdim` alanında tutulur.
  static const List<String> handeReplikleri = [
    'Merhaba, ben Hande; senin rehberin ve öğretmeninim. '
        'Yeni dükkanın hayırlı olsun!',
    'Bu oyunda amacın, elindeki oyun CD\'si ve ekipmanları satarak '
        'dükkanını geliştirmek.',
    'İlk günlerde satıp sermaye yapmak için, envanterdeki CD ve '
        'ekipmanları kullanabilirsin.',
    'Yepyeni ekipmanlar, ilginç müşteriler ve oynanabilir oyun sürprizleri '
        'seni bekliyor. Bol şans!',
  ];

  /// 🚗 Galerici Gürbüz — Gürbüz Oto Galeri'nin sahibi. Alt barda EVET/HAYIR
  /// yerine "Araç Seç" / "Vazgeç" çıkar; araç seçilirse sıradan bir satıcı
  /// müşteriye dönüşüp normal pazarlık başlar (`GameState.galericiAracSec`).
  factory OzelMusteri.galerici() => OzelMusteri(
        tip: OzelMusteriTip.galerici,
        gorsel: 'assets/galerici.png',
        ad: 'Galerici Gürbüz',
        ilkMiktar: 0,
        ilkMesaj: 'Selamın Aleyküm, ben Gürbüz, Gürbüz Oto Galeri\'nin sahibi. '
            'Araç lazım mı? Ne verelim abime?',
      );

  /// Dükkandaki güvenliğe tıklanınca müşteri gibi öne gelir ve istifayı sorar.
  factory OzelMusteri.guvenlikIstifa() => OzelMusteri(
        tip: OzelMusteriTip.guvenlik,
        gorsel: 'assets/guvenlik.png',
        ad: 'Yakışıklı Güvenlik',
        ilkMiktar: 0,
        ilkMesaj: 'İşi bırakmamı ister misin?',
        istifaSorusu: true,
      );

  static OzelMusteri olustur(OzelMusteriTip tip) {
    final rng = Random();
    switch (tip) {
      case OzelMusteriTip.hirsiz:
        final x = 50 + rng.nextInt(151);
        return OzelMusteri(tip: tip, gorsel: 'assets/hirsiz.png', ad: 'Hırsız', ilkMiktar: x, ilkMesaj: 'Eller yukarı! Bana acilen $x lira vereceksin!');
      case OzelMusteriTip.polis:
        final x = 30 + rng.nextInt(221);
        // %50: ceza kesmek yerine alkol testi yapar. İşlem her seferinde
        // yeniden üretilir, ezberlenecek sabit soru yok.
        if (rng.nextBool()) {
          final int a, b, dogru;
          final String islem;
          switch (rng.nextInt(3)) {
            case 0: // çarpma
              a = 2 + rng.nextInt(8); b = 2 + rng.nextInt(8);
              dogru = a * b; islem = '$a x $b';
              break;
            case 1: // toplama
              a = 5 + rng.nextInt(46); b = 5 + rng.nextInt(46);
              dogru = a + b; islem = '$a + $b';
              break;
            default: // çıkarma — sonuç hep pozitif
              b = 5 + rng.nextInt(26); a = b + 5 + rng.nextInt(41);
              dogru = a - b; islem = '$a - $b';
          }
          // Yanlış şık: doğruya yakın ama farklı ve pozitif
          int yanlis;
          do {
            final sapma = 1 + rng.nextInt(9);
            yanlis = rng.nextBool() ? dogru + sapma : dogru - sapma;
          } while (yanlis == dogru || yanlis <= 0);
          final dogruSolda = rng.nextBool();
          return OzelMusteri(
            tip: tip, gorsel: 'assets/polis.png', ad: 'Polis', ilkMiktar: x,
            ilkMesaj: 'Alkol var mı? Anlamak için sana soru soracağım. $islem kaç eder?',
            sikSol: dogruSolda ? dogru : yanlis,
            sikSag: dogruSolda ? yanlis : dogru,
            dogruCevap: dogru,
          );
        }
        final mesajlar = [
          'Rafların düzensiz, sana X lira ceza kesiyorum!',
          'Kaşının üzerinde gözün var, X lira cezalısın!',
          'Dükkanın çok tozlu, sana X lira ceza kestim!',
          'Giyim kuşamını beğenmedim. X lira cezalısın!',
          'Dükkanın çok gürültülü. X lira ceza kestim!',
          "Elindeki mallar Arap Faik'den mi? X lira cezalısın!",
          'Dükkanının kokusunu beğenmedim. X lira ceza kestim!',
          'Dükkanında muhalif oyunlar var. X lira cezalısın!',
          'Dükkanın sigara kokuyor. X lira cezalısın!',
          'Dükkanının boyaları dökülüyor. X lira ceza kestim!',
        ];
        final m = mesajlar[rng.nextInt(mesajlar.length)].replaceAll('X', '$x');
        return OzelMusteri(tip: tip, gorsel: 'assets/polis.png', ad: 'Polis', ilkMiktar: x, ilkMesaj: m);
      case OzelMusteriTip.vergici:
        return OzelMusteri(tip: tip, gorsel: 'assets/vergici.png', ad: 'Vergi Memuru', ilkMiktar: 0, ilkMesaj: 'Vergilerini düzenli ödüyor musun?');
      case OzelMusteriTip.kurye:
        final fiyat = 100 + rng.nextInt(201); // 100–300 TL
        const kuryeIsimler = ['Müftü', 'Özerk', 'Tuğberk', 'Kemal', 'Atakan', 'Cafer', 'Şemsi', 'Şinasi', 'Rahman', 'Aytuğ'];
        const yemekler = ['Adana dürüm', 'Urfa dürüm', 'Tavuk şiş dürüm', 'Çöp şiş dürüm', 'Kuzu şiş dürüm', 'Ciğer dürüm'];
        final kAd   = kuryeIsimler[rng.nextInt(kuryeIsimler.length)];
        final yemek = yemekler[rng.nextInt(yemekler.length)];
        final String kuryeMesaj;
        switch (rng.nextInt(3)) {
          case 0:  kuryeMesaj = 'Selam! Ben YeSekSepeti kuryesi $kAd. Bir takipçin sana $yemek gönderdi. Ücreti $fiyat lira. Kabul ediyor musun?'; break;
          case 1:  kuryeMesaj = 'Selam! Ben YeSekSepeti kuryesi $kAd. $yemek siparişi vermişsin, $fiyat lira tutuyor. Doğru muyum?'; break;
          default: kuryeMesaj = 'Merhaba! Ben YeSekSepeti kuryesi $kAd. $yemek siparişini getirdim babacan. $fiyat lira. Alıyor musun?';
        }
        return OzelMusteri(tip: tip, gorsel: 'assets/kurye.png', ad: 'Kurye', ilkMiktar: fiyat, ilkMesaj: kuryeMesaj, kuryeAd: kAd, kuryeYemek: yemek);
      case OzelMusteriTip.toptanci:
        const selamlar = [
          'Selam patron! Tepsimde taze mal var, bir bakar mısın?',
          'Kolay gelsin usta! Bugün elim dolu, ucuza veriyorum. Bakalım mı?',
          'Merhaba komşu! Yeni parti geldi, sana özel fiyat yaparım. Göstereyim mi?',
          'Selamünaleyküm! Mal getirdim, hem de kelepir. Açayım mı tepsiyi?',
          'Patron, ayağına kadar geldim! Stoğa bakmak ister misin?',
        ];
        return OzelMusteri(tip: tip, gorsel: 'assets/toptanci.png', ad: 'Toptancı Rıza',
          ilkMiktar: 0, ilkMesaj: selamlar[rng.nextInt(selamlar.length)]);
      case OzelMusteriTip.falci:
        // Fal ücreti: 40-140 lira. Ucuz tutuldu — sürpriz için oynanmalı,
        // ödeme yapmak riskli bir bahis gibi hissettirmemeli.
        final ucret = 40 + rng.nextInt(101);
        // NOT: switch case'leri aynı kapsamı paylaşır — değişken adı
        // toptancı case'indeki `selamlar` ile çakışmamalı.
        final falSelamlar = [
          'Ben falcıyım. $ucret liraya falına bakayım mı?',
          'Adım Faloya, gaipten haber veririm. $ucret liraya bakayım mı faluna?',
          'Selam evladım, ben falcı Faloya. $ucret lira ver, geleceğini okuyayım.',
          'Elini ver bakayım... Ama önce $ucret lira. Var mısın?',
          'Yıldızlar seni işaret etti. $ucret liraya falına bakayım mı?',
          'Ben Faloya. Kahven yoksa da olur, avucun yeter. $ucret lira. Olur mu?',
        ];
        return OzelMusteri(tip: tip, gorsel: 'assets/falci.png', ad: 'Falcı Faloya',
          ilkMiktar: ucret, ilkMesaj: falSelamlar[rng.nextInt(falSelamlar.length)]);
      case OzelMusteriTip.hande:
        // Rehber; alış/satış yapmaz. `OzelMusteri.hande()` ile de üretilebilir,
        // bu dal `olustur` çağrıları için var.
        return OzelMusteri.hande();
      case OzelMusteriTip.guvenlik:
        // Ücret SABİT (günde 50 lira) — oyuncu neye evet dediğini bilsin.
        // CD alıp satmaz; tek işi hırsızı dükkana sokmamak.
        return OzelMusteri(
          tip: tip, gorsel: 'assets/guvenlik.png', ad: 'Yakışıklı Güvenlik',
          ilkMiktar: GameState.guvenlikGunlukUcret,
          ilkMesaj: 'Merhaba, ben Yakışıklı Güvenlik. Günde '
                    '${GameState.guvenlikGunlukUcret} liraya senin için çalışırsam, '
                    'bu dükkana hırsız giremez. İster misin?');
      case OzelMusteriTip.galerici:
        return OzelMusteri.galerici();
    }
  }
}

// ─── FAL SİSTEMİ ─────────────────────────────────────────────────────────────

/// Falın oyuna dokunuşu. `yok` dışındakiler gerçekten bir şey değiştirir —
/// falcının "gördüğü" şey birazdan başa gelir.
enum FalEtki {
  yok,              // sadece hikâye
  paraKazanc,       // kasaya para girer
  paraKayip,        // kasadan para çıkar
  dukkanBuyut,      // bir üst dükkana bedava geçiş
  kolonyaHediye,    // kolonya kullanım hakkı
  tamirSeti,        // tamir seti
  kapaliKutu,       // envantere kapalı kutu
  urunCuruk,        // envanterdeki bir ürün çürür
  kuryeSansi,       // sıradaki müşteri çok avantajlı (kurye bonusu)
  vergiciGelecek,   // sıradaki özel müşteri vergici
  hirsizGelecek,
  polisGelecek,
  kuryeGelecek,
  toptanciGelecek,
}

/// Falın uygulanmış sonucu: gösterilecek şerit (yoksa null) + çıkan tutar.
class FalSonuc {
  final String? satir;
  final int miktar;
  const FalSonuc(this.satir, this.miktar);
}

/// Tek bir fal metni + etkisi.
/// `{X}` → tutar/sayı ile doldurulur (tek harf placeholder KULLANMA kuralı).
class Fal {
  final String metin;
  final FalEtki etki;
  final int min; // etki miktarı alt sınır (para/adet)
  final int max;
  const Fal(this.metin, {this.etki = FalEtki.yok, this.min = 0, this.max = 0});

  /// Fal metnini oyuncuya gösterilecek hâle getirir: `{X}` → gerçek tutar.
  String metniDoldur(int miktar) => metin.replaceAll('{X}', '$miktar');

  /// 75 fal metni. Yarısı sadece hikâye, yarısı gerçekten bir şey yapıyor.
  /// Etkili olanlar sürprizi bozmasın diye metinde açıkça "göreceksin" demez —
  /// falcı görür, oyuncu sonucu yaşar.
  static const List<Fal> havuz = [
    // ── PARA KAZANCI (8) ──
    Fal('Avucunda bir çatal yol görüyorum, ikisi de altına çıkıyor. Bugün ummadığın bir yerden bereket akacak. Kasan gülecek evladım.',
        etki: FalEtki.paraKazanc, min: 150, max: 450),
    Fal('Kahve telvesi gibi karanlık ama dibinde parıltı var. Eski bir borçlu seni hatırlayacak. Cebine {X} lira girecek.',
        etki: FalEtki.paraKazanc, min: 200, max: 600),
    Fal('Bir kuş görüyorum, gagasında madeni bir şey. Sokakta değil, tam bu dükkânın içinde düşürecek onu. Şansın açık.',
        etki: FalEtki.paraKazanc, min: 100, max: 350),
    Fal('Yıldızlar bugün senin hanende toplanmış. Uzaktaki bir akraban seni anıyor, eli de boş değil. Az sonra anlarsın ne demek istediğimi.',
        etki: FalEtki.paraKazanc, min: 250, max: 700),
    Fal('Elinde tuttuğun eski bir şey, sandığından kıymetli çıkacak. Bir koleksiyoncu peşine düşmüş bile. Bereketli olsun.',
        etki: FalEtki.paraKazanc, min: 180, max: 500),
    Fal('Suyun yüzünde bir hesap defteri beliriyor, rakamlar hep artı. Bu haftanın rüzgârı senden yana esiyor evladım.',
        etki: FalEtki.paraKazanc, min: 120, max: 400),
    Fal('Bir zarf görüyorum, mühürlü ve senin adına. İçindeki kâğıt değil, para. Kapını çalan olursa şaşırma.',
        etki: FalEtki.paraKazanc, min: 300, max: 800),
    Fal('Tezgâhının altında unuttuğun bir kutu var. Yıllardır orada duruyor ve içi boş değil. Git bak istersen, ama zaten kendiliğinden bulunacak.',
        etki: FalEtki.paraKazanc, min: 90, max: 300),

    // ── PARA KAYBI (6) ──
    Fal('Hmm... Bu hiç hoşuma gitmedi. Cebinde bir delik görüyorum evladım, hem de büyük. Kaybedeceğin para geri gelmeyecek.',
        etki: FalEtki.paraKayip, min: 100, max: 350),
    Fal('Fincanın kenarında bir kırık var. Böylesi hep beklenmedik masraf demektir. Bugün elin cebine gidecek, hem de isteksizce.',
        etki: FalEtki.paraKayip, min: 80, max: 300),
    Fal('Bir fatura görüyorum, senin adına ama senin bilmediğin. Ödemek zorunda kalacaksın. Üzülme, sağlık olsun.',
        etki: FalEtki.paraKayip, min: 150, max: 450),
    Fal('Karanlık bir bulut var başının üstünde, para bulutu ama ters yönde yağıyor. Bugün alacağın değil, vereceğin gün.',
        etki: FalEtki.paraKayip, min: 120, max: 400),
    Fal('Elinin çizgisi burada kesiliyor. Bir şey kırılacak ya da kaybolacak, tamiri de sana kalacak. Kızma, kader işte.',
        etki: FalEtki.paraKayip, min: 60, max: 250),
    Fal('Sana kötü bir haberim var: yakın çevrenden biri senden borç isteyecek ve geri vermeyecek. Ben söyledim, sen bilirsin.',
        etki: FalEtki.paraKayip, min: 200, max: 500),

    // ── DÜKKAN BÜYÜTME (2) ──
    Fal('Aaa, bu ne böyle! Duvarların genişliyor evladım, tavanın yükseliyor. Tez zamanda daha büyük bir dükkâna geçeceksin, hem de hiç para vermeden!',
        etki: FalEtki.dukkanBuyut),
    Fal('Bir anahtar görüyorum, seninkinden büyük bir kapının anahtarı. Kısmetin açılmış, mekânın değişiyor. Hayırlı olsun şimdiden!',
        etki: FalEtki.dukkanBuyut),

    // ── SONRAKİ ÖZEL MÜŞTERİ (7) ──
    Fal('Resmî bir şey görüyorum, çantalı ve gözlüklü. Benden sonra sana vergici gelecek evladım. Defterlerini bir gözden geçir derim.',
        etki: FalEtki.vergiciGelecek),
    Fal('Bir mühür, bir damga, bir de ekşi surat... Devlet kapısı senin kapını çalacak birazdan. Hazırlıklı ol.',
        etki: FalEtki.vergiciGelecek),
    Fal('Karanlıkta bir gölge var, yüzü örtülü. Niyeti temiz değil evladım. Benden sonra gelen ilk misafirine dikkat et.',
        etki: FalEtki.hirsizGelecek),
    Fal('Kasanın etrafında dönen bir el görüyorum, senin elin değil. Bugün bir hırsız uğrayacak. Söylemedi deme.',
        etki: FalEtki.hirsizGelecek),
    Fal('Mavi bir üniforma beliriyor telvede. Kanun adamı yolda evladım, hem de senin dükkânına doğru. Rafları bir düzelt bari.',
        etki: FalEtki.polisGelecek),
    Fal('Sıcak bir koku alıyorum... Yemek kokusu bu! Biri sana ikramda bulunacak, kapıdan gelecek. Aç karnına kalmayacaksın.',
        etki: FalEtki.kuryeGelecek),
    Fal('Başında tepsi taşıyan bir adam görüyorum. Malı bol, fiyatı ucuz. Benden sonra sana uğrayacak, kaçırma.',
        etki: FalEtki.toptanciGelecek),

    // ── HEDİYE / EŞYA (6) ──
    Fal('Güzel bir koku sarıyor etrafını, limon gibi ferah. Misafirlerin memnun kalacak bu kokudan. Al bunu benden hediye evladım.',
        etki: FalEtki.kolonyaHediye),
    Fal('Ferahlık görüyorum, hem senin hem müşterinin gönlünde. Elimi cebime attım, sana bir şey çıktı. Kullan, işine yarar.',
        etki: FalEtki.kolonyaHediye),
    Fal('Bozuk bir şey görüyorum ama yanında da onu düzeltecek eli. Usta ellerin var senin evladım. Bu benden olsun.',
        etki: FalEtki.tamirSeti),
    Fal('Tornavida, tutkal, biraz da sabır... Yakında lazım olacak sana bunlar. Şansına ben yanımda getirmişim.',
        etki: FalEtki.tamirSeti),
    Fal('Kapalı bir kutu görüyorum, içinde ne olduğunu ben bile göremiyorum. Bazen bilmemek daha güzeldir. Aç bakalım, kısmetin ne çıkacak.',
        etki: FalEtki.kapaliKutu),
    Fal('Sürpriz var falında evladım, sarılı sarmalı. Ne olduğunu söylemeyeceğim, tadı kaçar. Kendi gözünle gör.',
        etki: FalEtki.kapaliKutu),

    // ── OLUMSUZ EŞYA (2) ──
    Fal('Rafında bir küf lekesi görüyorum... Nem mi bastı, kader mi bilmem. Bir malın elinde bozulacak evladım, üzülme.',
        etki: FalEtki.urunCuruk),
    Fal('Bir çatlak sesi duyuyorum, cam değil, plastik. Mallarından biri artık eskisi gibi olmayacak. Kadere karşı gelinmez.',
        etki: FalEtki.urunCuruk),

    // ── SONRAKİ MÜŞTERİ ÇOK CÖMERT (3) ──
    Fal('Bereketli bir el görüyorum, cebi de gönlü de geniş. Sıradaki müşterin sana çok iyi davranacak evladım. Fırsatı kaçırma.',
        etki: FalEtki.kuryeSansi),
    Fal('Telvede bir gülümseme var. Kapıdan girecek ilk kişi pazarlığı uzatmayacak, cebi de dolu. Şansın açık bugün.',
        etki: FalEtki.kuryeSansi),
    Fal('Yıldızlar hizalanmış, hem de tam senin tezgâhının üstünde. Bir sonraki alışverişin ömrünün en kârlısı olabilir.',
        etki: FalEtki.kuryeSansi),

    // ── SADECE HİKÂYE (41) ──
    Fal('Uzun bir yolculuk görüyorum ama ayakla değil, akılla. Bu dükkân seni çok yere götürecek evladım. Sabret, acele etme.'),
    Fal('Kalbin temiz, o yüzden falın da temiz çıkıyor. Kötü bir şey göremiyorum. Bazen haber yokluğu en iyi haberdir.'),
    Fal('Bir kedi görüyorum, dükkânın önünde dolanıyor. Uğurdur o, kovma sakın. Beslersen bereketi artar derler.'),
    Fal('Geçmişte bıraktığın bir şey var, aklına takılıp duruyor. Bırak gitsin evladım. Yeni gelecek olan daha güzel.'),
    Fal('Kalabalık görüyorum, hem de senin kapının önünde. Ama ne zaman, onu yıldızlar söylemiyor. Sen işini yap, gerisi gelir.'),
    Fal('Suyun içinde bir yüzük var ama kimin bilmiyorum. Belki senin, belki bir müşterinin. Kısmet meselesi.'),
    Fal('Çok konuşan biri girecek dükkânına. Dinle ama her söylediğine inanma. Kulağın açık, cüzdanın kapalı olsun.'),
    Fal('Bir sayı beliriyor: yedi. Ne anlama geldiğini ben de bilmiyorum ama not et bir kenara. Zamanı gelince anlarsın.'),
    Fal('Rüyalarında bir müzik duyuyorsun son zamanlarda. O eski bir oyunun sesi. Geçmişin seni özlemiş evladım.'),
    Fal('İki yol var önünde, biri kısa biri uzun. Uzun olanı seç. Kısa yolların sonu hep aynı yere çıkar: pişmanlığa.'),
    Fal('Elinin çizgisi çok net, hiç dallanmıyor. Bu inatçı olduğunu gösterir. İyi de bir şey, kötü de. Kullanmasını bil.'),
    Fal('Bir mektup görüyorum ama gelmiyor, gidiyor. Birine bir şey söylemen gerekiyor ve söylemiyorsun. Ertelemekle geçiyor ömür.'),
    Fal('Fincanın dibi bomboş. Bu ya çok sakin bir dönem demek, ya da yıldızlar bugün beni ciddiye almıyor. İkisi de olabilir.'),
    Fal('Neşeli bir gün görüyorum, sebebi de küçük bir şey olacak. Büyük mutlulukları bekleyeyim derken küçükleri kaçırma.'),
    Fal('Bir terazi beliriyor, iki kefe de denk. Hayatın dengede evladım. Bunu bozmaya çalışan olursa aldırma.'),
    Fal('Yorgunluk görüyorum omuzlarında ama sırtın dik. Ayakta kalmayı biliyorsun. Bugün de kalacaksın, yarın da.'),

    // ── SADECE HİKÂYE — EK (25) ── klasik kahve falı üslubu, dükkanla ilgisi yok
    Fal('Falımda bir kapı görüyorum, aralık duruyor. Ardından "M" harfli biri geçecek hayatına, ummadığın bir konuda yardımın dokunacak. Bu ay içinde bir haber bekle.'),
    Fal('Avucunun çizgisinde bir kavşak var evladım. Sağ yola sapacaksın ve orada seni tanıyan biriyle karşılaşacaksın. Uzun süredir konuşmadığın biri olabilir bu.'),
    Fal('Suda bir gemi görüyorum, yelkenleri açık. Yakın zamanda bir yolculuk kapına dayanacak, belki de sen çıkacaksın yola. Dönüşün hayırlı olsun şimdiden.'),
    Fal('Fincanın ağzında bir yıldız var, parlak. "S" harfiyle başlayan bir isim aklına gelecek birkaç gün içinde. O kişiyle aranızdaki soğukluk erimeye başlayacak.'),
    Fal('Kirli bir bulut görüyorum ama arkasında güneş var. Önce küçük bir tedirginlik yaşayacaksın, sonrasında rahatlayacaksın. Sabrın işine yarayacak bu sefer.'),
    Fal('Elinde bir mektup tutuyorsun rüyanda, farkında mısın bilmiyorum. O mektup gerçek olacak yakında; içinde beklemediğin bir davet var. Reddetme, kabul et.'),
    Fal('Telvenin dibinde iki figür beliriyor, yan yana duruyorlar. Aranızda küçük bir anlaşmazlık olan biriyle barışacaksın. İlk adımı sen atarsan daha çabuk olur.'),
    Fal('Bir merdiven görüyorum, yukarı çıkıyor ama basamaklar dar. Zorlanacağın birkaç gün olacak ama sonunda ferahlayacaksın. Pes etme, tepe yakın.'),
    Fal('Kahve fincanının kulpu tarafında bir kuş var. "D" harfli biri sana bir haber getirecek, iyi bir haber bu. Kapını çalanı hemen içeri al.'),
    Fal('Gözlerimde uzak bir şehir beliriyor, sisli ama davetkâr. Belki sen gitmeyeceksin ama oradan biri sana ulaşacak. Bekle, sabırlı ol.'),
    Fal('Falımda bir düğüm var, çözülmesi zor görünüyor ama çözülecek. Kafanı kurcalayan bir mesele bu hafta netleşecek. İçin rahat olsun.'),
    Fal('Bir ayna görüyorum, çatlak ama kırılmamış. Geçmişte yaşadığın bir hayal kırıklığı seni hâlâ etkiliyor. Zamanı geldi, bırak artık gitsin.'),
    Fal('Telvede bir el şekli var, açık duruyor. Yakında birine yardım edeceksin ve o kişi bunu asla unutmayacak. Küçük bir iyilik büyük bir dostluk doğuracak.'),
    Fal('Uzaktan gelen bir ses duyuyorum falımda, tanıdık bir ses. "C" harfiyle başlayan biri seni arayacak yakın zamanda. Telefonun çalınca şaşırma.'),
    Fal('Bir çift ayakkabı görüyorum yolun ortasında. Kısa bir seyahate çıkacaksın, planlanmamış ama keyifli olacak. Yanına sıcak bir şeyler almayı unutma.'),
    Fal('Fincanın tam ortasında bir çember var, kapanmış. Bir dönem senin için resmen bitiyor evladım. Yenisi başlarken daha huzurlu olacaksın.'),
    Fal('Karanlık bir oda görüyorum ama kapısı aralık, ışık sızıyor. İçinde bulunduğun sıkıntı sandığından kısa sürecek. Işığa doğru yürü, korkma.'),
    Fal('Telvede bir terazi var ama bir kefesi hafif. Bir konuda haklı olduğunu ispatlaman gerekecek. Sakin kal, zaman seni haklı çıkaracak.'),
    Fal('Bir bahçe görüyorum, çiçekler yeni açmış. Uzun süredir beklediğin bir şey nihayet gerçekleşmek üzere. Sabrının meyvesini vermek üzere evladım.'),
    Fal('Fincanın kenarında bir at var, koşar vaziyette. Hayatında hızlı gelişen bir olay olacak, seni şaşırtacak kadar hızlı. Hazırlıklı ol.'),
    Fal('Bulanık bir su görüyorum, dibi görünmüyor. Şu an net göremediğin bir konu var ama yakında berraklaşacak. Acele etme, cevap kendiliğinden gelecek.'),
    Fal('Telvede bir kelebek şekli beliriyor, hafif ve özgür. Zihnini meşgul eden bir yük kalkacak üzerinden. Nefes alman kolaylaşacak bu hafta.'),
    Fal('Uzak bir akraban rüyana girecek yakında, gerçek hayatta da haber verecek. "B" harfiyle başlayan bir yer adı duyacaksın. Kulak ver, önemli olabilir.'),
    Fal('Fincanın dibinde bir anahtar görüyorum. Kilitli kalmış bir konu açılacak, uzun süredir çözemediğin bir şey. Anahtar sandığından yakınında evladım.'),
    Fal('Bir yol ayrımı görüyorum, ikisi de karanlık ama biri kısa sürede aydınlanıyor. O yolu seç, tereddüt etme. İçindeki ses zaten hangisi olduğunu biliyor.'),
  ];
}

// ─── YAŞ / CİNSİYET DUYARLI REPLİK SİSTEMİ ───────────────────────────────────

/// Karakterin yaş kuşağı. Replik filtrelemesinin tek kaynağı.
/// Sayısal yaş tutmuyoruz — replik yazarken kuşak yeterli, sayı fazladan yük.
enum YasGrubu { cocuk, genc, yetiskin, yasli }

const List<YasGrubu> kYasGenc     = [YasGrubu.cocuk, YasGrubu.genc];
const List<YasGrubu> kYasBuyuk    = [YasGrubu.yetiskin, YasGrubu.yasli];
const List<YasGrubu> kYasYetiskin = [YasGrubu.genc, YasGrubu.yetiskin];

YasGrubu yasGrubuCoz(String? s) {
  switch (s) {
    case 'cocuk':    return YasGrubu.cocuk;
    case 'genc':     return YasGrubu.genc;
    case 'yasli':    return YasGrubu.yasli;
    default:         return YasGrubu.yetiskin;
  }
}

/// Tek bir replik satırı + kime uyduğu.
///
/// `yas == null` → her yaşa uyar. `cinsiyet == null` → her cinsiyete uyar.
/// Böylece eski düz satırlar hiç etiketlenmeden nötr havuzda kalabiliyor.
///
/// ⚠️ Metinde TEK HARFLİ placeholder KULLANMA — `{AD}` / `{URUN}` kullan.
/// `replaceAll('A', ...)` "Arkadaşlar" kelimesindeki A'yı da bozar.
class Replik {
  final String metin;
  final List<YasGrubu>? yas;
  final String? cinsiyet; // 'E' | 'K' | null
  const Replik(this.metin, {this.yas, this.cinsiyet});

  bool uyar(YasGrubu y, String c) =>
      (yas == null || yas!.contains(y)) && (cinsiyet == null || cinsiyet == c);

  bool get notr => yas == null && cinsiyet == null;
}

/// Havuzdan karaktere uygun rastgele replik seçer.
///
/// Güvenlik zinciri: uygun replik yoksa nötr havuza, o da boşsa tüm havuza
/// düşer. Yani filtre ne kadar dar olursa olsun asla boş metin dönmez.
String replikSec(List<Replik> havuz, YasGrubu yas, String cinsiyet, [Random? r]) {
  final rng = r ?? Random();
  final uygun = havuz.where((x) => x.uyar(yas, cinsiyet)).toList();
  if (uygun.isNotEmpty) return uygun[rng.nextInt(uygun.length)].metin;
  final notrler = havuz.where((x) => x.notr).toList();
  if (notrler.isNotEmpty) return notrler[rng.nextInt(notrler.length)].metin;
  return havuz[rng.nextInt(havuz.length)].metin;
}

// ─── PAZARLIK MODELİ ─────────────────────────────────────────────────────────

enum PazarlikDurum { devamEdiyor, anlasildi, gitti }

/// Oyuncunun bir turdaki hamlesinin büyüklüğü/yönü.
/// Müşteri buna göre tepki verir — pazarlığı gerçekçi kılan şey bu okuma.
enum Hamle { geri, ayni, kucuk, orta, buyuk }

class PazarlikSeans {
  final bool musteriSatiyor;
  final int piyasaFiyati;
  final MusteriOzellik ozellik;
  /// Karşı tarafın kuşağı ve cinsiyeti — replik filtrelemesi için.
  /// Özel müşteride pazarlık yok, o yüzden varsayılan nötr bir yetişkin.
  final YasGrubu yas;
  final String cinsiyet;
  double _reservationPrice; // colonya bonusu uygulanabilir, final değil

  int musteriTeklif;
  int oyuncuTeklif;
  int turSayisi;
  int maxTur;
  PazarlikDurum durum;
  String mesaj;
  double _frustration = 0;
  final List<int> _oyuncuGecmisi = [];
  final List<int> _musteriGecmisi = [];
  bool sonTeklifMi = false;        // son tura girildi mi (UI vurgulayabilir)
  bool _sikistirmaKullanildi = false; // "az daha gayret" hamlesi bir kez kullanılır
  bool _ortadaBulusmaKullanildi = false; // "ortada buluşalım mı?" bir kez
  bool _kolonyaIkramEdildi = false;      // kolonya ikramı ortada buluşma şansını artırır

  /// "Ortada buluşalım mı?" replikleri — X yerine orta fiyat gelir.
  static const List<Replik> _ortadaBulusma = [
    Replik('Bak ne diyeceğim, ortada buluşalım mı? X.'),
    Replik('Uzatmayalım, ikimizin ortası: X. Anlaştık mı?'),
    Replik('Sen bir adım, ben bir adım... Tam ortası X olsun.'),
    Replik('Ne senin dediğin ne benim: X. Ortada buluşalım.'),
    Replik('Kes şunu, ortadan bölelim: X. Ne dersin?'),
    Replik('Adil olalım, tam ortası X. Elini ver.'),
    Replik('Ortada buluşalım mı? X diyorum, bitsin bu iş.'),
    Replik('İkimiz de biraz feda edelim: X.'),
    Replik('Ortası X ediyor. Bence ikimiz için de iyi.', yas: kYasBuyuk),
    Replik('Yarı yarıya bölüşelim: X. Olur mu?', yas: kYasGenc),
  ];

  PazarlikSeans({
    required this.musteriSatiyor,
    required this.piyasaFiyati,
    required this.musteriTeklif,
    required this.oyuncuTeklif,
    required this.maxTur,
    required this.ozellik,
    required double reservationPrice,
    this.yas = YasGrubu.yetiskin,
    this.cinsiyet = 'E',
  })  : _reservationPrice = reservationPrice,
        turSayisi = 0,
        durum = PazarlikDurum.devamEdiyor,
        mesaj = '';

  static double _clamp(double v, double lo, double hi) => v < lo ? lo : v > hi ? hi : v;
  static double _rnd(double a, double b) => a + Random().nextDouble() * (b - a);

  // ── HAMLEYE TEPKİ REPLİKLERİ ──────────────────────────────────────────────

  /// Oyuncu geri adım attı (önceki teklifinden daha kötü bir teklif verdi)
  static const List<Replik> _tepkiGeri = [
    Replik('Dur dur! Az önce daha iyi bir rakam söylemiştin, geri mi gidiyorsun?'),
    Replik('Yanlış duymadıysam teklifin kötüleşti. X, ben buradayım.'),
    Replik('Bu ne şimdi? Pazarlık ileri gider, geri değil! X.'),
    Replik('Sen benimle dalga mı geçiyorsun? X diyorum, düşün.'),
    Replik('Geri adım attın diye ben de fiyatımı kırmıyorum: X.'),
    Replik('Ters yöne gidiyorsun dostum. X, aynen duruyor.'),
    Replik('Hop! Cebine geri mi koydun parayı? X.'),
    Replik('Böyle pazarlık olmaz ki. Fiyatım X, sabit.'),
    Replik('Hile yapıyorsun! Böyle olmaz ki, X demiştin.', yas: [YasGrubu.cocuk]),
    Replik('Cidden mi? Geri gitmek diye bir şey yok. X.', yas: kYasGenc),
    Replik('Evladım, verdiğin sözden dönülmez. X.', yas: [YasGrubu.yasli]),
    Replik('Ablan bunu yutmaz, X.', cinsiyet: 'K', yas: kYasBuyuk),
  ];

  /// Oyuncu aynı teklifi tekrarladı
  static const List<Replik> _tepkiAyni = [
    Replik('Aynı rakamı tekrar söyledin. İnatçıymışsın. X.'),
    Replik('Değişen bir şey yok sende, bende de yok pek: X.'),
    Replik('Kaset mi takıldı? X diyorum ben de.'),
    Replik('Sen kımıldamazsan ben de kımıldamam. X.'),
    Replik('Israrcısın, kabul. Ama X.'),
    Replik('Bak ben biraz indirdim, sen hiç. X.'),
    Replik('Aynı yerde sayıyoruz. X, bir adım at.'),
    Replik('Aynı şeyi söyleyip duruyorsun, sıkıldım! X.', yas: [YasGrubu.cocuk]),
    Replik('Kopyala yapıştır mı yapıyorsun? X.', yas: kYasGenc),
    Replik('Benim sabrım var evladım ama vaktim yok. X.', yas: [YasGrubu.yasli]),
  ];

  /// Oyuncu büyük bir jest yaptı (ciddi bir sıçrama)
  static const List<Replik> _tepkiBuyuk = [
    Replik('Ooo, işte bu adamlık! Ben de X diyeyim.'),
    Replik('Büyük adım attın, saygı duydum. X.'),
    Replik('Ciddi olduğunu anladım. Gel X\'te buluşalım.'),
    Replik('Bu jestin karşılıksız kalmaz: X.'),
    Replik('Vay be, hiç beklemiyordum. X olsun.'),
    Replik('Böyle pazarlık severim işte! X.'),
    Replik('Sen adam gibi davrandın, ben de X.'),
    Replik('Yaklaştık! X, neredeyse bitti bu iş.'),
    Replik('Vaaay! Sen çok iyisin. X olsun!', yas: [YasGrubu.cocuk]),
    Replik('Efsanesin! X diyorum ben de.', yas: kYasGenc),
    Replik('Sağ ol evladım, hakkını helal et. X.', yas: [YasGrubu.yasli]),
    Replik('Ablan bu jesti unutmaz. X.', cinsiyet: 'K', yas: kYasBuyuk),
  ];

  /// Bir kereye mahsus "az daha sıkıştırma" (teklif kabul edilebilir olsa bile)
  static const List<Replik> _tepkiSikistirma = [
    Replik('Neredeyse tamam... Bir tık daha, X olsun bitsin.'),
    Replik('Az kaldı! X yaparsan hemen tokalaşırız.'),
    Replik('Elini biraz daha gevşet: X. Sonra anlaştık.'),
    Replik('Buraya kadar geldik, X\'e yuvarlayalım.'),
    Replik('Son bir gayret, X. Sonra çayları ben söylerim.'),
    Replik('X desen, hiç düşünmem. Hadi.'),
    Replik('Napcaz, biraz daha? X olsa süper olur!', yas: kYasGenc),
    Replik('Bir yaşlı hatırı için X, olur mu evladım?', yas: [YasGrubu.yasli]),
  ];

  /// Son tur uyarısı — oyuncu bunun son şans olduğunu bilsin
  static const List<Replik> _sonTeklifMesajlari = [
    Replik('SON TEKLİFİM: X. Ya alırsın ya küserim.'),
    Replik('Bak bu son: X. Ötesi yok, bitti.'),
    Replik('X. Son sözüm bu, düşün taşın karar ver.'),
    Replik('Daha fazla uzatmam: X, ya evet ya hoşça kal.'),
    Replik('Son teklif X. Kabul edersen anlaştık, etmezsen eyvallah.'),
    Replik('Bitiriyorum: X. Kararı sen ver.'),
    Replik('SON: X! Yoksa eve gidiyorum, gerçekten.', yas: [YasGrubu.cocuk]),
    Replik('Son teklifim X, sonrası yok. Ciddiyim.', yas: kYasGenc),
    Replik('Son sözüm X evladım, yorulmayalım artık.', yas: [YasGrubu.yasli]),
  ];

  PazarlikDurum oyuncuTeklifVer(int yeniOyuncuTeklif) {
    oyuncuTeklif = yeniOyuncuTeklif;
    turSayisi++;
    _oyuncuGecmisi.add(oyuncuTeklif);
    _musteriGecmisi.add(musteriTeklif);

    final mp      = piyasaFiyati.toDouble();
    final pat     = ozellik.pat;
    final intel   = ozellik.intel;
    final progress = _clamp(turSayisi / maxTur, 0, 1); // 0..1

    // ── 1. Oyuncu teklifi mevcut müşteri teklifini geçtiyse → kabul ──
    if (musteriSatiyor  && oyuncuTeklif >= musteriTeklif) return _kabul(musteriTeklif.toDouble());
    if (!musteriSatiyor && oyuncuTeklif <= musteriTeklif) return _kabul(musteriTeklif.toDouble());

    final rng = Random();

    // ── 2. Rezervasyon sınırı aşıldıysa → kabul ──
    // AMA: pazarcı refleksi — bir kereye mahsus "az daha gayret" deyip sıkıştırabilir.
    // Anlaşmayı kaybettirmez: oyuncu aynı teklifi tekrarlarsa bu sefer kabul edilir.
    final sinirAsildi = musteriSatiyor
        ? oyuncuTeklif >= _reservationPrice
        : oyuncuTeklif <= _reservationPrice;
    if (sinirAsildi) {
      if (!_sikistirmaKullanildi && turSayisi <= maxTur - 2 && rng.nextDouble() < 0.30) {
        _sikistirmaKullanildi = true;
        // Oyuncunun teklifiyle kendi teklifi arasında ufak bir yere çekil
        final ortaNokta = ((oyuncuTeklif + musteriTeklif) / 2).round();
        musteriTeklif = musteriSatiyor
            ? ortaNokta.clamp(oyuncuTeklif + 1, musteriTeklif)
            : ortaNokta.clamp(musteriTeklif, oyuncuTeklif - 1);
        mesaj = _sec(_tepkiSikistirma)
            .replaceAll('X', '$musteriTeklif');
        durum = PazarlikDurum.devamEdiyor;
        return durum;
      }
      return _kabul(oyuncuTeklif.toDouble());
    }

    // ── 3. HAMLE ANALİZİ: oyuncu bu turda ne yaptı? ──
    // Pazarlığın gerçekçi hissetmesi bu okumaya bağlı. Geri adım atmakla
    // büyük jest yapmak aynı tepkiyi almamalı.
    double myMove = 0;
    if (_oyuncuGecmisi.length >= 2) {
      final prev = _oyuncuGecmisi[_oyuncuGecmisi.length - 2];
      myMove = musteriSatiyor
          ? (oyuncuTeklif - prev).toDouble()   // alıcı olarak daha çok veriyor
          : (prev - oyuncuTeklif).toDouble();  // satıcı olarak daha az istiyor
    }
    final hamleOran = myMove / mp;
    final ilkTur = _oyuncuGecmisi.length < 2;
    final hamle = ilkTur
        ? Hamle.orta
        : (hamleOran < -0.005
            ? Hamle.geri
            : (hamleOran <= 0.005
                ? Hamle.ayni
                : (hamleOran < 0.05 ? Hamle.kucuk : (hamleOran < 0.14 ? Hamle.orta : Hamle.buyuk))));

    double goodwill = _clamp(myMove / (mp * 0.08), 0, 1);

    // Oyuncunun teklifi müşterinin sınırını ne kadar aşıyor (0 = sınırda)
    final rezervAsim = musteriSatiyor
        ? (_reservationPrice - oyuncuTeklif) / mp   // az para veriyor
        : (oyuncuTeklif - _reservationPrice) / mp;  // çok para istiyor

    // ── 3a. GERİ ADIM: müşteri sinirlenir, fiyatını KIRMAZ ──
    if (hamle == Hamle.geri) {
      _frustration = _clamp(_frustration + 0.30, 0, 1);
      if (rng.nextDouble() < 0.22 + (1 - pat) * 0.28) return _git();
      mesaj = _sec(_tepkiGeri).replaceAll('X', '$musteriTeklif');
      durum = PazarlikDurum.devamEdiyor;
      return durum;
    }

    // ── 3b. KAPRİSLİ EVET: nadiren mantıksız bir teklifi bile kabul eder ──
    // Unutulmaz "vay be" anları yaratır. Sınırlı: en fazla %25 aşım.
    if (rezervAsim > 0 && rezervAsim < 0.25 && rng.nextDouble() < 0.05) {
      return _kabulKaprisli(oyuncuTeklif.toDouble());
    }

    // ── 3c. BÜYÜK JEST: ciddi bir adım attıysan karşılıksız kalmasın ──
    if (hamle == Hamle.buyuk) {
      _frustration = _clamp(_frustration - 0.10, 0, 1);
      // Teklif ulaşılabilir mesafedeyse jesti onurlandırıp kabul edebilir
      if (rezervAsim < 0.10 && rng.nextDouble() < 0.35 + pat * 0.20) {
        return _kabulJest(oyuncuTeklif.toDouble());
      }
    }

    // ── 4. Frustration ──
    var frustrationGrowth = (1 - pat) * 0.18 + (1 - intel) * 0.04;
    if (hamle == Hamle.ayni) frustrationGrowth += 0.14; // inatçılık yorar
    _frustration = _clamp(_frustration + frustrationGrowth, 0, 1);

    // ── 5. Müşteri karşı teklif miktarını hesapla ──
    // Erken turda büyük konsesyon, geç turda küçük — ama her zaman en az 1
    // Sürpriz çeşitlilik: %10 büyük sıçrama, %20 orta sıçrama, %70 normal/küçük
    final gapToReserv = musteriSatiyor
        ? (musteriTeklif - _reservationPrice).abs()
        : (_reservationPrice - musteriTeklif).abs();
    final baseRatio = _clamp(0.18 - progress * 0.15, 0.02, 0.18);
    final stepRoll = rng.nextDouble();
    double concessionRatio;
    if (stepRoll < 0.10) {
      // büyük sıçrama: 2.5–4x normal — "anlaştık gibi" hissi
      concessionRatio = baseRatio * (2.5 + rng.nextDouble() * 1.5);
    } else if (stepRoll < 0.30) {
      // orta sıçrama: 1.4–2.2x normal
      concessionRatio = baseRatio * (1.4 + rng.nextDouble() * 0.8);
    } else {
      // normal aralık: 0.5–1.3x — sürekli gıdım olmasın
      concessionRatio = baseRatio * (0.5 + rng.nextDouble() * 0.8);
    }
    // Aynı teklifi tekrarladıysan müşteri de kılını kıpırdatmaz
    if (hamle == Hamle.ayni) concessionRatio *= 0.25;
    final move = (gapToReserv * concessionRatio + goodwill * mp * 0.03)
        .clamp(1, double.infinity)
        .round();

    // ⚠️ 🐛 BURASI PAZARLIĞI DONDURAN HATANIN YERİYDİ.
    // Müşterinin teklifi kendi rezervasyon sınırına dayandığında
    // `musteriTeklif - 1 < _reservationPrice.ceil()` oluyordu (satıcı müşteri;
    // alıcıda simetriği). Dart'ın `clamp`'i alt sınır > üst sınır olduğunda
    // ArgumentError ATAR — istisna `teklifVer`den yukarı kaçıyor, dialog
    // `finally` sayesinde kapanıyor ama `mesaj` da `musteriTeklif` de HİÇ
    // güncellenmiyordu. Oyuncu "Teklif Ver"e basıp duruyor, ne yeni replik ne
    // yeni rakam geliyordu; ancak teklifi müşterininkini geçince (adım 1)
    // anlaşma oluyordu. Tam olarak bildirilen davranış buydu.
    //
    // Çözüm: clamp'i çağırmadan ÖNCE kıpırdayacak yer var mı diye bak.
    // Yer kalmadıysa müşteri zaten sınırındadır → `atFloor` dalına düşsün,
    // orada kabul/git kararı verilsin.
    final rezervAlt = _reservationPrice.ceil();   // satıcı müşterinin tabanı
    final rezervUst = _reservationPrice.floor();  // alıcı müşterinin tavanı
    final yerKaldi = musteriSatiyor
        ? (musteriTeklif - 1) >= rezervAlt
        : (musteriTeklif + 1) <= rezervUst;

    int yeniMusteriTeklif;
    if (!yerKaldi) {
      yeniMusteriTeklif = musteriTeklif; // sınırda, daha fazla kıpırdayamaz
    } else if (musteriSatiyor) {
      yeniMusteriTeklif = (musteriTeklif - move)
          .clamp(rezervAlt, musteriTeklif - 1).toInt();
    } else {
      yeniMusteriTeklif = (musteriTeklif + move)
          .clamp(musteriTeklif + 1, rezervUst).toInt();
    }

    // ── 6. Rezervasyon tavanına dayandıysa: kabul/git kararı ──
    final atFloor = !yerKaldi || (musteriSatiyor
        ? yeniMusteriTeklif <= rezervAlt
        : yeniMusteriTeklif >= rezervUst);

    if (atFloor) {
      // gapToMarket: oyuncunun teklifi piyasa fiyatından ne kadar uzak (oransal, + = uzak, - = geçmiş)
      final gapToMarket = musteriSatiyor
          ? (mp - oyuncuTeklif) / mp
          : (oyuncuTeklif - mp) / mp;
      // Sürekli eğri: gap -0.05'te ~0.85, 0'da ~0.55, 0.30'da ~0.08
      // acceptChance = 0.55 * exp(-3.5 * gapToMarket) — exponential düşüş
      final base = _clamp(0.55 * (1 - gapToMarket * 2.8), 0.05, 0.88);
      final acceptChance = _clamp(base + goodwill * 0.12 + pat * 0.08, 0.04, 0.90);
      if (Random().nextDouble() < acceptChance) {
        return _kabul((_reservationPrice + oyuncuTeklif) / 2);
      } else {
        return _git();
      }
    }

    // ── 7. Tur bitti ──
    if (turSayisi >= maxTur) {
      final currentGap = (musteriTeklif - oyuncuTeklif).abs() / mp;
      // Piyasayı geçip geçmediği ekstra bonus sağlar
      final beyondMarket = musteriSatiyor
          ? _clamp((oyuncuTeklif - mp) / mp, 0, 0.3)   // geçtiyse pozitif
          : _clamp((mp - oyuncuTeklif) / mp, 0, 0.3);
      // Sürekli eğri: gap 0'da ~0.70, 0.30'da ~0.10; piyasa geçilmişse bonus
      final base = _clamp(0.70 - currentGap * 2.0 + beyondMarket * 1.2, 0.05, 0.85);
      final acceptChance = _clamp(base + goodwill * 0.10 + pat * 0.08, 0.04, 0.88);
      if (Random().nextDouble() < acceptChance) {
        return _kabul((musteriTeklif + oyuncuTeklif) / 2);
      }
      return _git();
    }

    // ── 8. Erken gitme şansı (sabırsız müşteri) ──
    final currentGap = (musteriTeklif - oyuncuTeklif).abs() / mp;
    double walkChance = _frustration * 0.15 +
        currentGap * (1 - pat) * 0.20 +
        (turSayisi == 1 ? -0.30 : 0);
    walkChance = _clamp(walkChance, 0, 0.40);
    if (turSayisi > 1 && rng.nextDouble() < walkChance) return _git();

    // ── 8b. "Ortada buluşalım mı?" ──
    // 3. turdan sonra %25 (kolonya ikram edildiyse %50) ihtimalle müşteri iki
    // fiyatın tam ortasını teklif eder. Pazarlığı hızlı ve tatmin edici
    // bitiren bir jest; bir kez kullanılır.
    if (!_ortadaBulusmaKullanildi && turSayisi >= 3) {
      final sans = _kolonyaIkramEdildi ? 0.50 : 0.25;
      if (rng.nextDouble() < sans) {
        _ortadaBulusmaKullanildi = true;
        final orta = ((musteriTeklif + oyuncuTeklif) / 2).round();
        // Ortayı kendi aleyhine kırpma: satıcı rezervin altına inmez,
        // alıcı rezervin üstüne çıkmaz.
        musteriTeklif = musteriSatiyor
            ? max(orta, _reservationPrice.round())
            : min(orta, _reservationPrice.round());
        mesaj = _sec(_ortadaBulusma).replaceAll('X', '$musteriTeklif');
        durum = PazarlikDurum.devamEdiyor;
        return durum;
      }
    }

    // ── 9. Karşı teklifi uygula ──
    musteriTeklif = yeniMusteriTeklif;

    // ── 10. SON TEKLİF UYARISI: son tura girerken açıkça söyle ──
    // Oyuncu "bu son şans" olduğunu bilsin — pazarlığa doruk noktası katar.
    if (turSayisi >= maxTur - 1) {
      sonTeklifMi = true;
      mesaj = _sec(_sonTeklifMesajlari)
          .replaceAll('X', '$musteriTeklif');
      durum = PazarlikDurum.devamEdiyor;
      return durum;
    }

    // ── 11. Hamleye göre tepki mesajı ──
    if (hamle == Hamle.ayni) {
      mesaj = _sec(_tepkiAyni).replaceAll('X', '$musteriTeklif');
    } else if (hamle == Hamle.buyuk) {
      mesaj = _sec(_tepkiBuyuk).replaceAll('X', '$musteriTeklif');
    } else {
      _karsiTeklifMesaj();
    }
    durum = PazarlikDurum.devamEdiyor;
    return durum;
  }

  // Kolonya bonusu: rezervasyon fiyatını ve maxTur'u güncelle
  // bonus: 0.15..0.35 (her oyuncuda farklı rastgele oran)
  /// Kurye bonusu: yemek yendikten sonra bir sonraki müşteriye çok avantajlı koşullar
  void kuryeBonusuUygula() {
    if (musteriSatiyor) {
      // Satıcı: çok düşük fiyata bile satar
      _reservationPrice = (piyasaFiyati * 0.28).clamp(5.0, _reservationPrice);
    } else {
      // Alıcı: çok yüksek fiyatı da öder
      _reservationPrice = (piyasaFiyati * 1.60).clamp(_reservationPrice, double.infinity);
    }
    maxTur += 5;
  }

  void kolonyaUygula(double bonus) {
    _kolonyaIkramEdildi = true; // "ortada buluşalım" şansını %25'ten %50'ye çıkarır
    if (musteriSatiyor) {
      // Satıcı: minimum kabul fiyatı düşer → daha düşük teklifleri kabul eder
      _reservationPrice = (_reservationPrice * (1 - bonus)).clamp(
          piyasaFiyati * 0.35, _reservationPrice);
    } else {
      // Alıcı: maksimum ödeme fiyatı artar → daha yüksek teklifler verir
      _reservationPrice = (_reservationPrice * (1 + bonus)).clamp(
          _reservationPrice, piyasaFiyati * 1.40);
    }
    maxTur += 2; // daha uzun pazarlık olabilir
  }

  // ── KARŞI TEKLİF REPLİKLERİ ──────────────────────────────────────────────
  // X → teklif tutarıyla değiştirilir. Rol ayrımı önemli: malı SATAN ile
  // ALAN aynı cümleyi kuramaz. İkisi için ayrı havuz.

  /// Müşteri malı SATIYOR (oyuncu alıcı) — "bu para bu malı almaz" tonu
  static const List<Replik> _saticiKarsiTeklif = [
    // ── nötr (her yaş, her cinsiyet) ──
    Replik("Yok abi, o para bu malı almaz. X diyelim."),
    Replik("Bu fiyata versem eve dönemem. X olsun, helalleşelim."),
    Replik("Vallahi zarar ederim. X, son sözüm... şimdilik."),
    Replik("Ayıp ya! Bu mala X bile az."),
    Replik("Gönlümden X koptu, gerisi lafıgüzaf."),
    Replik("Bak, X. Bundan aşağısı kul hakkı."),
    Replik("Kalbimi kırdın ama pazarlık bu. X?"),
    Replik("Bu malın hikâyesi var, hikâye de para eder. X."),
    Replik("X. Bak yuvarlak sayı, hesabı kolay olsun."),
    Replik("Böyle giderse akşama kadar buradayız. X."),
    Replik("İnsaf be! X'e razıyım, bitirelim şu işi."),
    Replik("X olur mu? Olmazsa da kırılmam... biraz kırılırım."),
    Replik("X. Üstüne bir çay ısmarlarsan hiç itiraz etmem."),
    Replik("Pazarlıkta ustayımdır ama bugün yorgunum: X."),
    Replik("Sen de bir adım at ya! X."),
    Replik("Anam görse 'satma' derdi. X'e satarım."),
    Replik("X. Bu fiyatı sadece sana söylüyorum, kimseye deme."),
    Replik("Az kaldı az! X de tamam."),
    Replik("Rakamlar konuşsun: X."),
    Replik("Bu fiyatı duysa malın eski sahibi ters döner. X."),
    Replik("X diyorum, gözün arkada kalmasın."),
    Replik("Elimi kolumu bağladın. X, bitti gitti."),
    Replik("Ben buraya pazarlık etmeye geldim, dilenmeye değil. X."),
    Replik("X. Hesap makinesi getireyim mi, beraber bakalım?"),
    Replik("Şu malın tozunu bile X eder. Hadi."),
    // ── çocuk ──
    Replik("Kumbaramı kırdım diye annem kızdı, bari X olsun.", yas: [YasGrubu.cocuk]),
    Replik("Bisiklet için para biriktiriyorum. X yeter bana.", yas: [YasGrubu.cocuk]),
    Replik("Ağabeyim 'X'ten aşağı verme' dedi, sözünden çıkamam.", yas: [YasGrubu.cocuk]),
    Replik("Öğretmenim matematikten iyiyim der. X ediyor bu, hesapladım.", yas: [YasGrubu.cocuk]),
    // ── çocuk + genç ──
    Replik("Kantin borcum var, X desen kurtulurum.", yas: kYasGenc),
    Replik("Arkadaşlar 'bu en az X eder' dedi, onlara güveniyorum.", yas: kYasGenc),
    Replik("Yeni oyun çıktı, ona para lazım. X?", yas: kYasGenc),
    // ── genç ──
    Replik("Öğrenciyim, her kuruş lazım: X.", yas: [YasGrubu.genc]),
    Replik("Konser bileti alacağım, X'e razıyım.", yas: [YasGrubu.genc]),
    Replik("İnternette X'e gidiyor, kargo derdi olmasa satmazdım sana.", yas: [YasGrubu.genc]),
    // ── yetişkin ──
    Replik("Faturalar kapıda dostum, X desen anlaşırız.", yas: [YasGrubu.yetiskin]),
    Replik("Çocuklara oda açıyorum evde, X'e bırakırım.", yas: [YasGrubu.yetiskin]),
    Replik("Ben de esnaflık yaptım, boş konuşmayalım: X.", yas: [YasGrubu.yetiskin]),
    // ── yetişkin + yaşlı ──
    Replik("Benim yaşımda insan boşuna pazarlık etmez. X.", yas: kYasBuyuk),
    Replik("Bunu aldığımda sen daha bu dükkânı hayal etmiyordun. X.", yas: kYasBuyuk),
    // ── yaşlı ──
    Replik("Torunum büyüdü, artık oynamıyor. X desen severek veririm.", yas: [YasGrubu.yasli]),
    Replik("Emekli maaşı yetmiyor evladım, X olsun.", yas: [YasGrubu.yasli]),
    Replik("Bu yaştan sonra pazarlık ikimizi de yormasın: X.", yas: [YasGrubu.yasli]),
    Replik("Gözlerim iyi görmüyor ama rakamdan anlarım: X.", yas: [YasGrubu.yasli]),
    // ── cinsiyet imalı ──
    Replik("Kadın müşteri fiyat bilmez sanma, malın değeri X.", cinsiyet: 'K'),
    Replik("Ablan sana kazık atmaz, X gerçek değeri.", cinsiyet: 'K', yas: kYasBuyuk),
    Replik("Bunu kızıma alacaktım, ona X'lik başka bir şey bakarım. X?", cinsiyet: 'K', yas: kYasBuyuk),
    Replik("Delikanlı adam sözünden dönmez: X dedim, X.", cinsiyet: 'E', yas: kYasYetiskin),
    Replik("Abin sana yanlış yapmaz, X.", cinsiyet: 'E', yas: kYasBuyuk),
  ];

  /// Müşteri malı ALIYOR (oyuncu satıcı) — "o kadar para vermem" tonu
  static const List<Replik> _aliciKarsiTeklif = [
    // ── nötr ──
    Replik("O paraya bu mu? X veririm, fazlası yok."),
    Replik("Cebimde X var, gerisi hayal."),
    Replik("X. Üstüne bir teşekkür de ederim, olur mu?"),
    Replik("Bu fiyata yenisini alırım ben. X."),
    Replik("Gönlüm X diyor, cüzdanım da öyle."),
    Replik("Sen fiyatı söylerken bile utandın. X."),
    Replik("X. Sen de kâr et ama tek başına etme."),
    Replik("X veriyorum, üstüne poşet de isterim."),
    Replik("Şu ekonomide X bile büyük laf."),
    Replik("Bak X diyorum, sonra fikrim değişir ha."),
    Replik("X. Yuvarlıyorum, hesap kolay olsun."),
    Replik("Bu mala X, bir de gülümseme veririm."),
    Replik("Fiyatı duyunca gözüm karardı. X'e gelirim."),
    Replik("X. Anlaşırsak arkadaşlara da tavsiye ederim."),
    Replik("X olsun, ikimiz de kazanalım."),
    Replik("Pazarlık kültürümüzde var, kusura bakma: X."),
    Replik("İndirim yapmayan esnaf, esnaf değildir. X."),
    Replik("Bugün şanslı günün: X kabul."),
    Replik("Son teklifim X... yani şimdilik son."),
    Replik("X diyorum, gerisini hayır dualarımla tamamlarım."),
    Replik("Sen bunu bana X'e verirsen adamsın."),
    Replik("X. Elimi vicdanıma koydum, çıkan rakam bu."),
    // ── çocuk ──
    Replik("Harçlığım tam X, kumbara bomboş kaldı.", yas: [YasGrubu.cocuk]),
    Replik("Annemden X aldım, fazlasını istemeye korkarım.", yas: [YasGrubu.cocuk]),
    Replik("Bayram harçlığım X. Yeter mi abi, yeter değil mi?", yas: [YasGrubu.cocuk]),
    Replik("Karnem iyi geldi diye X verdiler. Hepsi bu.", yas: [YasGrubu.cocuk]),
    // ── çocuk + genç ──
    Replik("Harçlığım X, ötesi yok vallahi.", yas: kYasGenc),
    Replik("X. Bunun üstüne çıkarsam bana evde kızarlar.", yas: kYasGenc),
    Replik("X'ten yukarısı için evden izin almam lazım.", yas: kYasGenc),
    // ── genç ──
    Replik("Öğrenciyim, bütçem X. Biraz anlayış bekliyorum.", yas: [YasGrubu.genc]),
    Replik("Burs yattı, buna X ayırdım. Gerisi yemek parası.", yas: [YasGrubu.genc]),
    Replik("Yurtta herkes bunu konuşuyor ama cebimde X var.", yas: [YasGrubu.genc]),
    // ── yetişkin ──
    Replik("Çocuğun doğum günü yaklaştı, bütçem X.", yas: [YasGrubu.yetiskin]),
    Replik("Eve hesap vereceğim, X'te kalayım.", yas: [YasGrubu.yetiskin]),
    Replik("Kredi kartı dolu, nakit X var. Karar senin.", yas: [YasGrubu.yetiskin]),
    // ── yetişkin + yaşlı ──
    Replik("Çocukluğumdaki fiyatları hatırlıyorum da... neyse, X.", yas: kYasBuyuk),
    Replik("Bizim zamanımızda bunun üçü X ederdi. Yine de X diyorum.", yas: kYasBuyuk),
    // ── yaşlı ──
    Replik("Torunuma alacağım, X'e verirsen arkandan dua ederim.", yas: [YasGrubu.yasli]),
    Replik("Emekliyiz evladım, X'ten fazlasını çıkaramam.", yas: [YasGrubu.yasli]),
    Replik("Maaş üçüne yatıyor, bugün elimde X var.", yas: [YasGrubu.yasli]),
    Replik("Yaşlıyım diye kandırma beni, X eder bu.", yas: [YasGrubu.yasli]),
    // ── cinsiyet imalı ──
    Replik("Kadın müşteriyi kaçırma, X de bitsin bu iş.", cinsiyet: 'K'),
    Replik("Kızlar bunlardan anlamaz derler, bak anlıyorum: X.", cinsiyet: 'K', yas: kYasYetiskin),
    Replik("Teyzeni kırma, X'e ver şunu.", cinsiyet: 'K', yas: [YasGrubu.yasli]),
    Replik("Erkek adamın cebinde X var, artırsam yalan olur.", cinsiyet: 'E', yas: kYasYetiskin),
    Replik("Amcana bu iyiliği yap, X.", cinsiyet: 'E', yas: [YasGrubu.yasli]),
  ];

  /// Karaktere uygun replik seç — yaş/cinsiyet filtresi burada devreye girer.
  String _sec(List<Replik> havuz) => replikSec(havuz, yas, cinsiyet);

  void _karsiTeklifMesaj() {
    final havuz = musteriSatiyor ? _saticiKarsiTeklif : _aliciKarsiTeklif;
    mesaj = _sec(havuz).replaceAll('X', '$musteriTeklif');
  }

  static const List<Replik> _kabulSablonlari = [
    // ── nötr ──
    Replik('Anlaştık! Elini sıkayım, hayırlı olsun.'),
    Replik('Tamamdır! Böyle pazarlık severim işte.'),
    Replik('Oldu bu iş! X lira, helali hoş olsun.'),
    Replik('Kabul! Sen de iyi pazarlıkçısın ha.'),
    Replik('Yaptın yapacağını, X\'e razıyım!'),
    Replik('Anlaştık. Bir dahakine bu kadar kolay olmayacak ama.'),
    Replik('X. Tamam! Vicdanım rahat.'),
    Replik('Hah şöyle! İkimiz de kazandık.'),
    Replik('Kabul ediyorum, ellerine sağlık.'),
    Replik('Oldu! Bu alışverişten memnunum.'),
    Replik('X\'e anlaştık. Bereketli olsun!'),
    Replik('Peki! Zaten seni kıramazdım.'),
    Replik('Tamam, kabul. Sen kazandın bu sefer.'),
    Replik('X! Hemen kapatalım, fikrim değişmeden.'),
    Replik('Anlaştık. Arkadaşlara da senden bahsedeceğim.'),
    Replik('Al benden de o kadar! Kabul.'),
    Replik('Uzattık yeter, X\'e tamam.'),
    Replik('Bak bu güzel oldu. X, anlaştık.'),
    Replik('Eyvallah, X\'e razıyım.'),
    Replik('Şu tokalaşma anı var ya, işte bunun için buradayım!'),
    Replik('Tamam! Gözüm arkada kalmadı.'),
    Replik('X lira. Hesap tamam, gönül tamam.'),
    Replik('Kabul kabul, bitsin de çayımı içeyim.'),
    Replik('Helal olsun sana. X, anlaştık.'),
    Replik('Ooo, sonunda! X. Tokalaşalım.'),
    Replik('Bu fiyata evet demezsem ayıp olur. Kabul!'),
    // ── çocuk ──
    Replik('Tamam! Eve koşa koşa gideceğim, X!', yas: [YasGrubu.cocuk]),
    Replik('Anneme anlatacağım bunu! Anlaştık.', yas: [YasGrubu.cocuk]),
    Replik('Kabul! Sen dünyanın en iyi dükkâncısısın.', yas: [YasGrubu.cocuk]),
    // ── çocuk + genç ──
    Replik('Arkadaşlara hava atacağım, kabul!', yas: kYasGenc),
    Replik('X mi? Tamam tamam, kaçmaz böyle fırsat!', yas: kYasGenc),
    // ── genç ──
    Replik('Efsane! X, anlaştık.', yas: [YasGrubu.genc]),
    Replik('Bunu paylaşacağım, dükkânın reklamı olsun. Kabul!', yas: [YasGrubu.genc]),
    // ── yetişkin ──
    Replik('X. Tamam, işim var benim, kapatalım.', yas: [YasGrubu.yetiskin]),
    Replik('Anlaştık. Bir sonrakinde beni ara, müşterin oldum.', yas: [YasGrubu.yetiskin]),
    // ── yaşlı ──
    Replik('Eline sağlık evladım, X\'e anlaştık.', yas: [YasGrubu.yasli]),
    Replik('Allah bereket versin, kabul.', yas: [YasGrubu.yasli]),
    Replik('Torunum çok sevinecek. Anlaştık!', yas: [YasGrubu.yasli]),
    // ── cinsiyet imalı ──
    Replik('Ablan memnun kaldı, kabul!', cinsiyet: 'K', yas: kYasBuyuk),
    Replik('Kızlar pazarlıktan anlar işte. X, anlaştık!', cinsiyet: 'K', yas: kYasYetiskin),
    Replik('Erkek adam sözünü tutar: kabul, X.', cinsiyet: 'E', yas: kYasYetiskin),
    Replik('Eyvallah evladım, amcanı kırmadın.', cinsiyet: 'E', yas: [YasGrubu.yasli]),
  ];

  PazarlikDurum _kabul(double fiyat) {
    musteriTeklif = fiyat.round();
    durum = PazarlikDurum.anlasildi;
    mesaj = _sec(_kabulSablonlari).replaceAll('X', '$musteriTeklif');
    return durum;
  }

  /// Kaprisli evet: mantıken kabul etmemesi gereken bir teklifi kabul eder.
  /// Nadir (%5) ve sınırlı (en fazla %25 aşım) — "vay be" anı yaratsın diye.
  static const List<Replik> _kaprisliKabul = [
    Replik('Ya boşver, kafam iyi bugün. Kabul!'),
    Replik('Normalde asla vermezdim ama seni sevdim. Tamam!'),
    Replik('Bugün doğum günüm, hediyem olsun. Anlaştık!'),
    Replik('Acelem var, kabul, ver şunu.'),
    Replik('Bu kadar ısrar edene hayır denmez. Oldu!'),
    Replik('İçimden bir ses "ver gitsin" dedi. Kabul!'),
    Replik('Zarar mı ediyorum? Ediyorum. Kabul mü? Kabul!'),
    Replik('Yıldızların dizilimi iyi bugün. Anlaştık!'),
    Replik('Bu hikâyeyi arkadaşlara anlatacağım. Kabul!'),
    Replik('Dur dur, düşünmeyeyim, fikrim değişmeden kabul!'),
    Replik('Tamam tamam! Zaten canım çok istiyordu.', yas: [YasGrubu.cocuk]),
    Replik('Boşver ya, olsun. Kabul!', yas: kYasGenc),
    Replik('Ömrümüzün sonunda pazarlık mı kaldı? Kabul evladım.', yas: [YasGrubu.yasli]),
    Replik('Ablanın bugün keyfi yerinde: kabul!', cinsiyet: 'K', yas: kYasBuyuk),
  ];

  PazarlikDurum _kabulKaprisli(double fiyat) {
    musteriTeklif = fiyat.round();
    durum = PazarlikDurum.anlasildi;
    mesaj = _sec(_kaprisliKabul);
    return durum;
  }

  /// Büyük jesti onurlandıran kabul
  static const List<Replik> _jestKabul = [
    Replik('Bu kadar büyük adım attıktan sonra hayır diyemem. Anlaştık!'),
    Replik('Mertlik bozulmasın, kabul!'),
    Replik('Sen adam gibi davrandın, ben de kabul ediyorum.'),
    Replik('İşte pazarlık böyle biter! Anlaştık.'),
    Replik('Bu jestin hatırına: kabul.'),
    Replik('Elini sıkayım, hak ettin. Anlaştık!'),
    Replik('Çok iyisin sen ya! Kabul!', yas: [YasGrubu.cocuk]),
    Replik('Bu hareketi beklemiyordum, kral adamsın. Kabul!', yas: kYasGenc),
    Replik('Böyle esnaf az kaldı evladım. Anlaştık.', yas: [YasGrubu.yasli]),
    Replik('Ablan bu inceliği unutmaz, kabul!', cinsiyet: 'K', yas: kYasBuyuk),
  ];

  PazarlikDurum _kabulJest(double fiyat) {
    musteriTeklif = fiyat.round();
    durum = PazarlikDurum.anlasildi;
    mesaj = _sec(_jestKabul);
    return durum;
  }

  // ── Çekip gitme replikleri: üç ruh haline göre ayrı havuz ──

  /// Sinirlenip gitti (frustration yüksek)
  static const List<Replik> _gitOfkeli = [
    // ── nötr ──
    Replik('Sen şaşırmışsın, konuşmasak daha iyi!'),
    Replik('Senin piyasadan hiç mi haberin yok!'),
    Replik('Yok artık Lebron James!'),
    Replik('Oldu paşam, Malkara Keşan!'),
    Replik('Sen tok satıcısın, anlaşıldı!...'),
    Replik('Beni aptal yerine koyamazsın!'),
    Replik('Bu ne pazarlık ya, resmen soygun!'),
    Replik('Sinirlerim! Ben gidiyorum.'),
    Replik('Sen bu kafayla dükkânı kapatırsın!'),
    Replik('Vallahi güldüm. Güle güle!'),
    Replik('Buraya bir daha adımımı atarsam...'),
    Replik('Enflasyon senin yüzünden bu kadar!'),
    Replik('Fiyatı duyunca kulaklarım çınladı, kaçtım!'),
    Replik('Yandaki dükkân yarı fiyatına veriyor, hoşça kal!'),
    Replik('Sabrımı taşırdın, gidiyorum!'),
    Replik('Bu pazarlık değil, işkence!'),
    Replik('Kalbim kırıldı, hem de gerçekten.'),
    Replik('Şaka gibisin, valla şaka gibi!'),
    // ── yaşa göre ──
    Replik('Anneme söyleyeceğim seni!', yas: [YasGrubu.cocuk]),
    Replik('Hiç adil değil bu! Küstüm sana.', yas: [YasGrubu.cocuk]),
    Replik('Bu dükkânı kimse takmıyor zaten, hoşça kal!', yas: [YasGrubu.genc]),
    Replik('Yorum yazacağım, bir yıldız bile fazla!', yas: [YasGrubu.genc]),
    Replik('Ayıp ettin evladım, ayıp!', yas: [YasGrubu.yasli]),
    Replik('Benim yaşımdaki birine bu reva mı? Eyvallah!', yas: [YasGrubu.yasli]),
    Replik('Bu yaşa geldim, böyle esnaf görmedim!', yas: kYasBuyuk),
    // ── cinsiyet imalı ──
    Replik('Kadın diye kolay lokma sandın, yanıldın!', cinsiyet: 'K'),
    Replik('Ablanı kızdırdın işte, güle güle!', cinsiyet: 'K', yas: kYasBuyuk),
    Replik('Erkek adam böyle fiyat vermez, eyvallah!', cinsiyet: 'E', yas: kYasYetiskin),
  ];

  /// Tur bitti, anlaşamadılar (kızgın değil, yorgun)
  static const List<Replik> _gitTurBitti = [
    // ── nötr ──
    Replik('Yok ya seninle anlaşamıyoruz...'),
    Replik('Olmadı, olduramadık...'),
    Replik('Pazarlık benim için bitmiştir!...'),
    Replik('Biz bu işi unutalım bence.'),
    Replik("Ne sen Leyla'sın ne de ben Mecnun."),
    Replik('Tekliflerimiz ikimize de makul gelmedi.'),
    Replik('Başka işlerim var, gitmeliyim...'),
    Replik('Güzel pazarlıktı ama olmadı.'),
    Replik('Vakit geçti, ben kaçayım.'),
    Replik('Olmuyor işte olmuyor. Eyvallah.'),
    Replik('İkimiz de haklıyız ama anlaşamıyoruz.'),
    Replik('Bu iş bugünlük burada bitsin.'),
    Replik('Belki başka bahar...'),
    Replik('Yolumuz ayrıldı dostum.'),
    Replik('Kısmet değilmiş, hoşça kal.'),
    Replik('Çok konuştuk, az anlaştık. Gidiyorum.'),
    Replik('Sana da bana da yazık. Görüşürüz.'),
    Replik('Uzadı bu iş, bende o sabır yok.'),
    // ── yaşa göre ──
    Replik('Servis kaçacak, gitmem lazım.', yas: [YasGrubu.cocuk]),
    Replik('Eve geç kalırsam kızarlar, kaçtım.', yas: kYasGenc),
    Replik('Dersim var, bu kadar konuştuğumuz yeter.', yas: [YasGrubu.genc]),
    Replik('Mesaiye yetişeceğim, bir dahakine.', yas: [YasGrubu.yetiskin]),
    Replik('Ayaklarım ağrıdı evladım, oturacak yer arayayım.', yas: [YasGrubu.yasli]),
    Replik('Bu kadar ayakta durdum, kısmet değilmiş.', yas: [YasGrubu.yasli]),
    // ── cinsiyet imalı ──
    Replik('Ablan başka dükkâna bakar artık, görüşürüz.', cinsiyet: 'K', yas: kYasBuyuk),
    Replik('Amcan başka kapı çalsın bari.', cinsiyet: 'E', yas: [YasGrubu.yasli]),
  ];

  /// Erken vazgeçti
  static const List<Replik> _gitErken = [
    // ── nötr ──
    Replik('Dur ya, vazgeçtim!...'),
    Replik('Şu teklifle anında vazgeçtim!'),
    Replik('Dolandırılacağım sanırım, kaçıyorum!...'),
    Replik('Seninle ortayı bulamıyoruz.'),
    Replik('Bir dahaki sefere artık.'),
    Replik('Yok yok, içime sinmedi.'),
    Replik('Aklıma başka iş geldi, kaçtım!'),
    Replik('Şöyle bir düşüneyim... düşündüm, olmadı.'),
    Replik("Cüzdanım 'yürü' diyor."),
    Replik('Vazgeçtim, kusura bakma.'),
    Replik('Bugün alışveriş yıldızım tutmadı.'),
    Replik('Bir tur atıp geleyim... belki.'),
    // ── yaşa göre ──
    Replik('Bu kadar param yok ki benim, vazgeçtim.', yas: [YasGrubu.cocuk]),
    Replik('Önce anneme sorayım, sonra gelirim.', yas: [YasGrubu.cocuk]),
    Replik('İnternetten bakayım bir, belki daha ucuzdur.', yas: kYasGenc),
    Replik('Şimdilik pas, maaş yatınca konuşuruz.', yas: [YasGrubu.yetiskin]),
    Replik('Bir düşüneyim evladım, acelem yok.', yas: [YasGrubu.yasli]),
    // ── cinsiyet imalı ──
    Replik('Eşime bir danışayım, öyle karar vereyim.', yas: kYasBuyuk),
    Replik('Kızıma sorayım bir, o bu işlerden anlar.', cinsiyet: 'K', yas: [YasGrubu.yasli]),
  ];

  PazarlikDurum _git() {
    durum = PazarlikDurum.gitti;
    final havuz = _frustration > 0.6
        ? _gitOfkeli
        : (turSayisi >= maxTur ? _gitTurBitti : _gitErken);
    mesaj = _sec(havuz);
    return durum;
  }
}

// ─── SES SERVİSİ ─────────────────────────────────────────────────────────────

/// Ses + dokunsal geri bildirim.
///
/// DOSYA EKLEME: `assets/sounds/` klasörüne at, yeter. pubspec.yaml klasörü
/// toptan listeliyor (`- assets/sounds/`), tek tek eklemeye gerek YOK.
/// Dosya yoksa `_cal` sessizce geçer — eksik ses çökmeye sebep olmaz.
///
/// Beklenen dosyalar (olmayanlar sessiz kalır):
///   kapi.mp3 ✓, paragirdi.mp3 ✓, anlasma.mp3, basarisiz.mp3, rozet.mp3,
///   seri.mp3, kutu.mp3, tamir.mp3, gunsonu.mp3, hedef.mp3, hata.mp3,
///   envanter.mp3, tik.mp3
class SesServisi {
  static bool sesAcik = true;

  /// Dokunsal geri bildirim ayrı bir ayar. Eskiden `sesAcik`e bağlıydı ama
  /// ikisi farklı beklentiler: sessiz oynayan biri titreşimi isteyebilir.
  static bool titresimAcik = true;

  /// Buton dokunuşu — SES YOK, sadece çok kısa titreşim.
  /// Ana ekrandaki her `_oyunButon` bunu çağırır; ayrı bir ses çalmak
  /// tıklama başına gürültü olurdu.
  static void dokun() => _titre(HapticFeedback.selectionClick);

  // ── Mevcut ──
  static void kapiyiCal()  { _oynat('kapi.mp3');       _titre(HapticFeedback.lightImpact); }
  static void paraGirdi()  { _oynat('paragirdi.mp3'); }

  // ── Yeni tetikleyiciler ──
  /// Pazarlık anlaşmayla bitti — en tatmin edici an
  static void anlasma()    { _oynat('anlasma.mp3');    _titre(HapticFeedback.mediumImpact); }
  /// Müşteri kızıp gitti / pazarlık koptu
  static void basarisiz()  { _oynat('basarisiz.mp3');  _titre(HapticFeedback.lightImpact); }
  /// Rozet kazanıldı — kutlama
  static void rozet()      { _oynat('rozet.mp3');      _titre(HapticFeedback.heavyImpact); }
  /// Seri (kombo) bonusu
  static void seri()       { _oynat('seri.mp3');       _titre(HapticFeedback.lightImpact); }
  /// Günlük hedef tamamlandı
  static void hedefTamam() { _oynat('hedef.mp3');      _titre(HapticFeedback.mediumImpact); }
  /// Kapalı kutu açıldı
  static void kutuAcildi() { _oynat('kutu.mp3');       _titre(HapticFeedback.mediumImpact); }
  /// Çürük ürün tamir edildi
  static void tamir()      { _oynat('tamir.mp3');      _titre(HapticFeedback.lightImpact); }
  /// Gün sonu / kasa kapanışı
  static void gunSonu()    { _oynat('gunsonu.mp3'); }
  /// Hata: yetersiz para, envanter dolu vb.
  static void hata()       { _oynat('hata.mp3');       _titre(HapticFeedback.heavyImpact); }
  /// Envanter açıldı
  static void envanter()   { _oynat('envanter.mp3');   _titre(HapticFeedback.selectionClick); }
  /// Genel buton dokunuşu (seyrek kullan — her butona koyma)
  static void tikla()      { _oynat('tik.mp3');        _titre(HapticFeedback.selectionClick); }

  static void _oynat(String dosya) {
    if (!sesAcik) return;
    _cal('sounds/$dosya');
  }

  /// Dokunsal geri bildirim — ses dosyası gerektirmez, cihaz titreşimi.
  /// ⚠️ Artık `sesAcik`e DEĞİL, kendi ayarına (`titresimAcik`) bakıyor.
  static void _titre(Future<void> Function() f) {
    if (!titresimAcik) return;
    try { f(); } catch (_) {}
  }

  static Future<void> _cal(String asset) async {
    try {
      final player = AudioPlayer();
      await player.play(AssetSource(asset));
      player.onPlayerComplete.first.then((_) => player.dispose());
    } catch (_) {}
  }
}

// ─── KAYIT SERVİSİ ───────────────────────────────────────────────────────────

/// Ses/titreşim tercihleri. Oyun kaydından AYRI tutuluyor: oyunu sıfırlamak
/// ya da silmek bu tercihleri kaybettirmemeli.
class AyarServisi {
  static const _sesKey = 'ses_acik';
  static const _titresimKey = 'titresim_acik';

  static Future<void> yukle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      SesServisi.sesAcik = prefs.getBool(_sesKey) ?? true;
      SesServisi.titresimAcik = prefs.getBool(_titresimKey) ?? true;
    } catch (_) {/* ilk açılış / prefs yoksa varsayılanlar kalsın */}
  }

  static Future<void> kaydet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sesKey, SesServisi.sesAcik);
      await prefs.setBool(_titresimKey, SesServisi.titresimAcik);
    } catch (_) {}
  }
}

// ─── POPUP TASARIM DİLİ ──────────────────────────────────────────────────────
//
// ⚠️ Uygulamada popup renkleri dağılmıştı: her pencere kendi zeminini ve
// butonlarını uyduruyordu (6 farklı panel rengi, kimi butonda çerçeve var
// kimide yok, ana eylem bazen solda bazen sağda). Artık TEK kaynak burası —
// yeni bir popup yazarken `Panel` sabitlerini ve `dialogButonlari()` yardımcısını
// kullan, elle renk verme.

class Panel {
  /// Tüm popup gövdelerinin zemini.
  static const zemin = Color(0xFF1a1008);
  /// Başlık ve gövde yazısı.
  static const yazi = Color(0xFFF0DFC4);
  /// İkincil / açıklama yazısı.
  static const yaziSoluk = Color(0xFFB9A88E);
  /// "Vazgeç / Kapat / Dursun" gibi ikincil butonun zemini ve çerçevesi.
  static const ikincilZemin = Color(0xFF33271A);
  static const ikincilKenar = Color(0xFF6B5540);
}

/// Standart popup buton çifti.
///
/// KURAL: **ana eylem SOLDA**, vazgeçme SAĞDA. İkisi de dolu zeminli, çerçeveli
/// ve eşit genişlikte — biri düz metin biri dolu buton olduğunda hangisinin
/// tıklanabilir olduğu belirsiz kalıyordu.
Widget dialogButonlari({
  required String anaEtiket,
  required VoidCallback? anaOnTap,
  required Color anaRenk,
  required String ikincilEtiket,
  required VoidCallback ikincilOnTap,
  Color anaYazi = Colors.black,
  /// İkincil buton yıkıcı bir alternatifse (ör. "Çöpe At") kendi kimliğini
  /// koruyabilsin diye; verilmezse nötr Panel rengi kullanılır.
  Color? ikincilZemin,
  Color? ikincilKenar,
  Color? ikincilYazi,
}) {
  return Row(children: [
    Expanded(child: ElevatedButton(
      onPressed: anaOnTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: anaRenk,
        foregroundColor: anaYazi,
        disabledBackgroundColor: const Color(0xFF2a2a2a),
        disabledForegroundColor: Colors.white24,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: anaRenk.withValues(alpha: 0.9)),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(anaEtiket, maxLines: 1,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    )),
    const SizedBox(width: 10),
    Expanded(child: ElevatedButton(
      onPressed: ikincilOnTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: ikincilZemin ?? Panel.ikincilZemin,
        foregroundColor: ikincilYazi ?? Panel.yazi,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: ikincilKenar ?? Panel.ikincilKenar),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(ikincilEtiket, maxLines: 1,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    )),
  ]);
}

/// Koleksiyon ızgarası: 6 sütun × 10 satır. Kutular 8'liyken çok küçüktü.
const int kKoleksiyonSutun = 6;
const int kKoleksiyonKutuSayisi = 60;

/// Koleksiyon hedefi — ödülü bir kez alınır.
///
/// `ilerleme` doğrudan koleksiyonun İÇİNE bakar; envantere ya da satışlara
/// değil. Koleksiyon bir vitrin: ürünü oraya koymak satmaktan vazgeçmek demek,
/// hedefler de bu fedakârlığı ödüllendiriyor.
class KoleksiyonHedefi {
  final String id;
  final String baslik;
  final int hedef;
  final int odul;
  final int Function(GameState) ilerleme;

  const KoleksiyonHedefi({
    required this.id, required this.baslik, required this.hedef,
    required this.odul, required this.ilerleme,
  });

  static int _kategoriSay(GameState s, ItemCategory k) =>
      s.koleksiyonNesneleri.where((u) => u.category == k).length;

  static int _adGecen(GameState s, String parca) => s.koleksiyonNesneleri
      .where((u) => u.name.toLowerCase().contains(parca.toLowerCase())).length;

  static final List<KoleksiyonHedefi> tumu = [
    KoleksiyonHedefi(id: 'ilk', baslik: 'İlk parçanı koleksiyona koy',
      hedef: 1, odul: 150, ilerleme: (s) => s.koleksiyondakiler.length),
    KoleksiyonHedefi(id: 'oynanabilir3', baslik: '3 oynanabilir oyun bul',
      hedef: 3, odul: 600,
      ilerleme: (s) => s.koleksiyonNesneleri.where((u) => u.oynanabilir).length),
    KoleksiyonHedefi(id: 'cd10', baslik: '10 CD biriktir',
      hedef: 10, odul: 500, ilerleme: (s) => _kategoriSay(s, ItemCategory.cd)),
    KoleksiyonHedefi(id: 'cd25', baslik: '25 CD biriktir',
      hedef: 25, odul: 1400, ilerleme: (s) => _kategoriSay(s, ItemCategory.cd)),
    KoleksiyonHedefi(id: 'elkonsolu10', baslik: '10 el konsolu biriktir',
      hedef: 10, odul: 900, ilerleme: (s) => _adGecen(s, 'El Konsolu')),
    KoleksiyonHedefi(id: 'konsol5', baslik: '5 oyun konsolu biriktir',
      hedef: 5, odul: 450, ilerleme: (s) => _kategoriSay(s, ItemCategory.konsol)),
    KoleksiyonHedefi(id: 'masaustu3', baslik: '3 masaüstü konsol biriktir',
      hedef: 3, odul: 400, ilerleme: (s) => _adGecen(s, 'Masaüstü Konsol')),
    KoleksiyonHedefi(id: 'direksiyon2', baslik: '2 oyuncu direksiyonu biriktir',
      hedef: 2, odul: 350, ilerleme: (s) => _adGecen(s, 'Direksiyon')),
    KoleksiyonHedefi(id: 'kulaklik2', baslik: '2 kulaklık biriktir',
      hedef: 2, odul: 300, ilerleme: (s) => _adGecen(s, 'Kulaklık')),
    KoleksiyonHedefi(id: 'aksesuar6', baslik: '6 aksesuar biriktir',
      hedef: 6, odul: 550, ilerleme: (s) => _kategoriSay(s, ItemCategory.aksesuar)),
    KoleksiyonHedefi(id: 'yarim', baslik: 'Koleksiyonun yarısını doldur',
      hedef: kKoleksiyonKutuSayisi ~/ 2, odul: 2000,
      ilerleme: (s) => s.koleksiyondakiler.length),
    KoleksiyonHedefi(id: 'tam', baslik: 'Tüm koleksiyonu doldur',
      hedef: kKoleksiyonKutuSayisi, odul: 6000,
      ilerleme: (s) => s.koleksiyondakiler.length),
  ];
}

class KayitServisi {
  static const _key = 'oyun_kayit';
  static const _enYuksekGunKey = 'en_yuksek_gun';
  static const _enYuksekParaKey = 'en_yuksek_para';

  static Future<void> kaydet(GameState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
    // Rekor ayrı anahtarda: oyun silinse de ana menüde kalsın
    final rekor = prefs.getInt(_enYuksekParaKey) ?? 0;
    if (state.enYuksekPara > rekor) await prefs.setInt(_enYuksekParaKey, state.enYuksekPara);
  }

  static Future<Map<String, dynamic>?> yukle() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_key);
    if (str == null) return null;
    return jsonDecode(str) as Map<String, dynamic>;
  }

  static Future<bool> kayitVarMi() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key);
  }

  static Future<void> sil() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> enYuksekGunGuncelle(int gun) async {
    final prefs = await SharedPreferences.getInstance();
    final mevcut = prefs.getInt(_enYuksekGunKey) ?? 0;
    if (gun > mevcut) await prefs.setInt(_enYuksekGunKey, gun);
  }

  static Future<int?> enYuksekGunYukle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_enYuksekGunKey);
  }

  /// Ana menüde gösterilen "ulaşılan en yüksek kazanç" rekoru.
  /// Oyun içindeki `GameState.enYuksekPara` her kayıtla buraya taşınır ki
  /// oyun silinse/yeniden başlasa da rekor kalsın.
  static Future<void> enYuksekParaGuncelle(int para) async {
    final prefs = await SharedPreferences.getInstance();
    final mevcut = prefs.getInt(_enYuksekParaKey) ?? 0;
    if (para > mevcut) await prefs.setInt(_enYuksekParaKey, para);
  }

  static Future<int?> enYuksekParaYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final rekor = prefs.getInt(_enYuksekParaKey);
    if (rekor != null) return rekor;
    // Geriye dönük: rekor anahtarı bu sürümle geldi. Eski oyuncular rekorlarını
    // ilk kayıtta değil HEMEN görsün diye mevcut oyun kaydından türetiyoruz.
    final str = prefs.getString(_key);
    if (str == null) return null;
    try {
      final j = jsonDecode(str) as Map<String, dynamic>;
      return (j['enYuksekPara'] as int?) ?? (j['para'] as int?);
    } catch (_) {
      return null;
    }
  }
}

// ─── VERİ MODELLERİ ──────────────────────────────────────────────────────────

enum ItemCategory { cd, konsol, aksesuar, arac }

/// Oyuncunun bulunduğu yer.
enum Konum { dukkan, ev, yazlik }

/// Ev ve yazlığın arka planı + en-boy oranı. Eşyalar bu kutuya oranla
/// konumlandığı için oran mekân başına verilmeli.
class Mekan {
  final String arkaplan;
  final double oran; // en / boy
  const Mekan(this.arkaplan, this.oran);

  static const ev     = Mekan('assets/ev_bos.jpg', 719 / 1278);
  static const yazlik = Mekan('assets/yazlik_bos.jpg', 719 / 1274);

  static Mekan bul(Konum k) => k == Konum.yazlik ? yazlik : ev;
}

/// 🏠 Ev ve 🏖️ yazlığın satın alınabilir eşyaları.
///
/// İki farklı yerleştirme biçimi var:
/// - **Ev**: eşya PNG'leri alfa kutusuna kırpılmış; konumları `doluev.png`
///   üzerinden ölçülüp arka planın kutusuna oranlandı (0..1).
/// - **Yazlık**: kaynak bir OpenRaster (`.ora`) dosyası; her katman TAM TUVAL
///   boyutunda geldiği için konum hesabına gerek yok — `tamKatman` ile
///   arka planın üstüne birebir bindirilir.
class EvEsyasi {
  final String id, ad, gorsel;
  final int fiyat;
  /// Eşyanın arka plan içindeki yeri: sol kenar, ÜST kenar, genişlik (0..1).
  /// Yükseklik en-boy oranından türetilir (`BoxFit.contain`).
  final double sol, ust, gen;
  final Konum konum;
  /// true → görsel arka planla aynı boyutta, doğrudan üstüne serilir.
  final bool tamKatman;
  /// Tezgâhtaki küçük önizleme. Tam tuval katmanlar küçük bir kutuda
  /// görünmezdi (çoğu şeffaf), onlara ayrı kırpılmış kopya üretildi.
  final String? ikon;
  const EvEsyasi(this.id, this.ad, this.gorsel, this.fiyat, this.sol, this.ust, this.gen,
      {this.konum = Konum.ev, this.tamKatman = false, this.ikon});

  String get onizleme => ikon ?? gorsel;

  /// ⚠️ Sıra ÇİZİM SIRASI: arkadakiler önce. Duvardakiler → yan mobilyalar →
  /// öndeki kanepe. Listeyi karıştırma, öndeki eşya arkadakinin altında kalır.
  ///
  /// Oranlar `doluev.png` üzerinde %5'lik ızgarayla okundu, sonra `bosev`
  /// üstüne çizdirilip gözle doğrulandı (`tools/evkompozit.ps1`).
  static const List<EvEsyasi> tumu = [
    EvEsyasi('vazo',       'Çini Vazo',    'assets/ev_vazo.png',        400, 0.205, 0.235, 0.060),
    EvEsyasi('tv',         'Televizyon',   'assets/ev_tv.png',         2600, 0.365, 0.255, 0.290),
    EvEsyasi('lambader',   'Lambader',     'assets/ev_lambader.png',    900, 0.855, 0.295, 0.110),
    EvEsyasi('teklibir',   'Tekli Koltuk', 'assets/ev_teklibir.png',   1400, 0.030, 0.425, 0.280),
    EvEsyasi('tekliiki',   'Tekli Berjer', 'assets/ev_tekliiki.png',   1500, 0.725, 0.425, 0.260),
    EvEsyasi('ortasehpa',  'Orta Sehpa',   'assets/ev_ortasehpa.png',  1100, 0.345, 0.468, 0.330),
    EvEsyasi('sehpa2',     'Yan Sehpa',    'assets/ev_sehpa2.png',      700, 0.005, 0.535, 0.130),
    EvEsyasi('sehpa1',     'Zigon Sehpa',  'assets/ev_sehpa1.png',      600, 0.865, 0.530, 0.130),
    EvEsyasi('ikilikoltuk','İkili Koltuk', 'assets/ev_ikilikoltuk.png',2400, 0.105, 0.545, 0.790),

    // ── 🏖️ YAZLIK ──
    // Katmanlar `yazlik_ev_katmanli.ora`'dan geliyor; sıra stack.xml'in
    // TERSİ (XML'de üstteki katman en önde, burada en sonda çizilmeli).
    EvEsyasi('y_buzdolabi',  'Buzdolabı',           'assets/yazlik_01.png', 3500, 0, 0, 1,
      konum: Konum.yazlik, tamKatman: true, ikon: 'assets/yazlik_01_k.png'),
    EvEsyasi('y_bulasik',    'Bulaşık Makinesi',    'assets/yazlik_02.png', 2800, 0, 0, 1,
      konum: Konum.yazlik, tamKatman: true, ikon: 'assets/yazlik_02_k.png'),
    EvEsyasi('y_kahve',      'Kahve Makinesi',      'assets/yazlik_03.png',  900, 0, 0, 1,
      konum: Konum.yazlik, tamKatman: true, ikon: 'assets/yazlik_03_k.png'),
    EvEsyasi('y_mikrodalga', 'Mikrodalga Fırın',    'assets/yazlik_04.png', 1200, 0, 0, 1,
      konum: Konum.yazlik, tamKatman: true, ikon: 'assets/yazlik_04_k.png'),
    EvEsyasi('y_bardaklar',  'Bardaklar',           'assets/yazlik_05.png',  300, 0, 0, 1,
      konum: Konum.yazlik, tamKatman: true, ikon: 'assets/yazlik_05_k.png'),
    EvEsyasi('y_tabaklar',   'Tabaklar',            'assets/yazlik_06.png',  350, 0, 0, 1,
      konum: Konum.yazlik, tamKatman: true, ikon: 'assets/yazlik_06_k.png'),
    EvEsyasi('y_sandalye',   'Sandalyeler',         'assets/yazlik_07.png', 1800, 0, 0, 1,
      konum: Konum.yazlik, tamKatman: true, ikon: 'assets/yazlik_07_k.png'),
    EvEsyasi('y_masa',       'Yemek Masası',        'assets/yazlik_08.png', 2600, 0, 0, 1,
      konum: Konum.yazlik, tamKatman: true, ikon: 'assets/yazlik_08_k.png'),
    EvEsyasi('y_tv',         'Ayaklı TV',           'assets/yazlik_09.png', 3200, 0, 0, 1,
      konum: Konum.yazlik, tamKatman: true, ikon: 'assets/yazlik_09_k.png'),
    EvEsyasi('y_sezlong',    'İki Şezlong',         'assets/yazlik_10.png', 2200, 0, 0, 1,
      konum: Konum.yazlik, tamKatman: true, ikon: 'assets/yazlik_10_k.png'),
    EvEsyasi('y_saksi',      'Büyük Çiçekli Saksı', 'assets/yazlik_11.png',  700, 0, 0, 1,
      konum: Konum.yazlik, tamKatman: true, ikon: 'assets/yazlik_11_k.png'),
    EvEsyasi('y_simit',      'Pembe Şişme Simit',   'assets/yazlik_12.png',  250, 0, 0, 1,
      konum: Konum.yazlik, tamKatman: true, ikon: 'assets/yazlik_12_k.png'),
  ];

  static List<EvEsyasi> konumun(Konum k) => tumu.where((e) => e.konum == k).toList();

  /// Ev ve yazlığın kendi bedelleri (Market'ten alınır).
  static const int evFiyati = 10000;
  static const int yazlikFiyati = 12000;
}

/// 🚗 Gürbüz Oto Galeri'nin stoğu.
///
/// Araçlar `_baslangicUrunler`'de DEĞİL: normal müşteriler araç satmaz/almaz,
/// toptancıdan ya da kapalı kutudan çıkmaz, koleksiyona da girmez. Tek
/// kaynakları Galerici Gürbüz.
///
/// [gecisSaniye] "Konum Değiştir"deki yolculuk süresi. Motosiklet uzun,
/// otomobil kısa — aracın niteliği geçişe yansısın.
class Arac {
  final GameItem item;
  final int gecisSaniye;
  const Arac(this.item, this.gecisSaniye);

  static final List<Arac> tumu = [
    Arac(GameItem(id: 'arac1', name: 'Kızıl Şimşek', gorsel: 'assets/arac_1.png',
      category: ItemCategory.arac, basePrice: 9000, kondisyon: 4), 35),
    Arac(GameItem(id: 'arac2', name: 'Amiral 500', gorsel: 'assets/arac_2.png',
      category: ItemCategory.arac, basePrice: 14000, kondisyon: 5), 30),
    Arac(GameItem(id: 'arac3', name: 'Sarı Melek', gorsel: 'assets/arac_3.png',
      category: ItemCategory.arac, basePrice: 6000, kondisyon: 3), 45),
    Arac(GameItem(id: 'arac4', name: 'Vınn Motor', gorsel: 'assets/arac_4.png',
      category: ItemCategory.arac, basePrice: 3000, kondisyon: 4), 120),
    Arac(GameItem(id: 'arac5', name: 'Yol Kartalı', gorsel: 'assets/arac_5.png',
      category: ItemCategory.arac, basePrice: 11000, kondisyon: 5), 75),
  ];

  /// Bir ürün id'sinin geçiş süresi. Araç değilse null.
  static int? gecisSuresi(String id) =>
      tumu.where((a) => a.item.id == id).map((a) => a.gecisSaniye).firstOrNull;
}

class GameItem {
  final String id;
  final String name;
  final String gorsel;
  final ItemCategory category;
  final int basePrice;
  final int kondisyon;
  final int? maliyet; // oyuncu bu ürünü kaça aldı (başlangıç envanteri ise null)
  final bool curuk;      // çürük/hasarlı — piyasa değeri düşer, tamir edilebilir
  final bool kapaliKutu; // kapalı kutu — açılana kadar satılamaz, içinden random ürün çıkar
  /// Bu ürüne özel çürük çarpanı (0..1). null ise varsayılan `curukCarpani`.
  /// Müşterinin getirdiği hasarlı mal toptancı hurdası kadar ucuz olmasın diye
  /// ürün başına verilebiliyor.
  final double? curukOran;
  /// Bu ürün gerçekten OYNANABİLİR bir mini oyun içeriyor. Envanterde köşesine
  /// yıldız konur, tıklanınca oynama teklifi çıkar.
  final bool oynanabilir;

  GameItem({required this.id, required this.name, required this.gorsel, required this.category, required this.basePrice, required this.kondisyon, this.maliyet, this.curuk = false, this.kapaliKutu = false, this.curukOran, this.oynanabilir = false});

  /// Çürük ürünün piyasa değeri düşer. Tüm pazarlık hesapları bunu kullanır.
  static const double curukCarpani = 0.35;
  int get etkinFiyat => curuk ? (basePrice * (curukOran ?? curukCarpani)).round().clamp(1, basePrice) : basePrice;

  String get kondisyonYildiz => '★' * kondisyon + '☆' * (5 - kondisyon);

  GameItem kopya() => GameItem(id: id, name: name, gorsel: gorsel, category: category, basePrice: basePrice, kondisyon: kondisyon, maliyet: maliyet, curuk: curuk, kapaliKutu: kapaliKutu, curukOran: curukOran, oynanabilir: oynanabilir);

  /// Alan bazlı kopya (tamir, çürütme, maliyet atama için)
  GameItem kopyaWith({int? kondisyon, int? maliyet, bool? curuk, bool? kapaliKutu, double? curukOran}) => GameItem(
    id: id, name: name, gorsel: gorsel, category: category, basePrice: basePrice,
    kondisyon: kondisyon ?? this.kondisyon,
    maliyet: maliyet ?? this.maliyet,
    curuk: curuk ?? this.curuk,
    kapaliKutu: kapaliKutu ?? this.kapaliKutu,
    curukOran: curukOran ?? this.curukOran,
    oynanabilir: oynanabilir,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'gorsel': gorsel,
    'category': category.name, 'basePrice': basePrice, 'kondisyon': kondisyon,
    if (maliyet != null) 'maliyet': maliyet,
    if (curuk) 'curuk': true,
    if (kapaliKutu) 'kapaliKutu': true,
    if (curukOran != null) 'curukOran': curukOran,
    if (oynanabilir) 'oynanabilir': true,
  };

  factory GameItem.fromJson(Map<String, dynamic> j) => GameItem(
    id: j['id'] as String, name: j['name'] as String, gorsel: j['gorsel'] as String,
    category: ItemCategory.values.firstWhere((e) => e.name == j['category'], orElse: () => ItemCategory.cd),
    basePrice: j['basePrice'] as int, kondisyon: j['kondisyon'] as int,
    maliyet: j['maliyet'] as int?,
    curuk: (j['curuk'] as bool?) ?? false,
    kapaliKutu: (j['kapaliKutu'] as bool?) ?? false,
    curukOran: (j['curukOran'] as num?)?.toDouble(),
    oynanabilir: (j['oynanabilir'] as bool?) ?? false,
  );
}

// ─── TOPTANCI ────────────────────────────────────────────────────────────────

enum ToptanciTip { urun, curukUrun, tamirSeti, kapaliKutu }

/// Toptancıdaki tek bir satış kalemi. Stok her gün yenilenir.
class ToptanciUrun {
  final ToptanciTip tip;
  final GameItem? item; // tamirSeti için null
  final int fiyat;
  bool satildi;

  ToptanciUrun({required this.tip, this.item, required this.fiyat, this.satildi = false});

  Map<String, dynamic> toJson() => {
    'tip': tip.name,
    if (item != null) 'item': item!.toJson(),
    'fiyat': fiyat,
    'satildi': satildi,
  };

  factory ToptanciUrun.fromJson(Map<String, dynamic> j) => ToptanciUrun(
    tip: ToptanciTip.values.firstWhere((e) => e.name == j['tip'], orElse: () => ToptanciTip.urun),
    item: j['item'] != null ? GameItem.fromJson(j['item'] as Map<String, dynamic>) : null,
    fiyat: j['fiyat'] as int,
    satildi: (j['satildi'] as bool?) ?? false,
  );
}

// ─── GÜN OLAYLARI ────────────────────────────────────────────────────────────

/// Her günün başında rastgele tetiklenen olay. Etkiler o gün boyunca geçerlidir.
class GunOlayi {
  final String id;
  final String emoji;
  final String baslik;
  final String aciklama;
  final int musteriDelta;       // günlük müşteri limitine eklenir/çıkarılır
  final double piyasaCarpani;   // >1 = müşteriler cömert, <1 = cimri
  final int paraDelta;          // anında para etkisi
  final double toptanciIndirim; // 0.0-0.5 → toptancı fiyatlarından düşülür
  final bool fareIstilasi;      // envanterden rastgele bir ürünü çürütür

  const GunOlayi({
    required this.id, required this.emoji, required this.baslik, required this.aciklama,
    this.musteriDelta = 0, this.piyasaCarpani = 1.0, this.paraDelta = 0,
    this.toptanciIndirim = 0.0, this.fareIstilasi = false,
  });

  static const List<GunOlayi> havuz = [
    GunOlayi(id: 'tiktok', emoji: '📱', baslik: 'Dükkânın Viral Oldu!',
      aciklama: 'Biri dükkânını TikTok\'ta paylaşmış, video patladı. Bugün kapı çalmaktan durmayacak!',
      musteriDelta: 3),
    GunOlayi(id: 'elektrik', emoji: '⚡', baslik: 'Elektrik Kesintisi',
      aciklama: 'Mahallede elektrik yok. Karanlık dükkâna kimse girmek istemiyor.',
      musteriDelta: -2),
    GunOlayi(id: 'fuar', emoji: '🎪', baslik: 'Retro Oyun Fuarı',
      aciklama: 'Şehirde retro oyun fuarı var. Koleksiyoncular cebi dolu geziyor!',
      piyasaCarpani: 1.20),
    GunOlayi(id: 'kriz', emoji: '💸', baslik: 'Ekonomik Kriz',
      aciklama: 'Zamlar konuşuluyor. Herkes cüzdanını sıkı tutuyor bugün.',
      piyasaCarpani: 0.85),
    GunOlayi(id: 'kazi', emoji: '🚧', baslik: 'Kaldırım Kazısı',
      aciklama: 'Belediye dükkânın önünü kazdı. Girişi bulan aferin alsın.',
      musteriDelta: -2),
    GunOlayi(id: 'hediye', emoji: '🎁', baslik: 'Sürpriz Zarf',
      aciklama: 'Eski bir müşterin kapının altından teşekkür zarfı bırakmış.',
      paraDelta: 250),
    GunOlayi(id: 'fare', emoji: '🐀', baslik: 'Depoda Fare!',
      aciklama: 'Gece depoya fare girmiş. Bir ürünün hâline bakılacak gibi değil.',
      fareIstilasi: true),
    GunOlayi(id: 'kampanya', emoji: '🚚', baslik: 'Toptancıda Kampanya',
      aciklama: 'Toptancı stok eritiyor: bugün tüm fiyatlar düşük!',
      toptanciIndirim: 0.25),
    GunOlayi(id: 'yagmur', emoji: '☔', baslik: 'Sağanak Yağmur',
      aciklama: 'Dışarısı göl. Az müşteri var ama gelen ıslanmışken pazarlığa üşeniyor.',
      musteriDelta: -1, piyasaCarpani: 1.15),
    GunOlayi(id: 'gazete', emoji: '📰', baslik: 'Gazetede Övgü',
      aciklama: 'Yerel gazete dükkânını "mahallenin hazinesi" diye yazmış!',
      musteriDelta: 2, piyasaCarpani: 1.10),
  ];

  static GunOlayi? bul(String? id) {
    if (id == null) return null;
    for (final o in havuz) { if (o.id == id) return o; }
    return null;
  }
}

// ─── GÜNLÜK HEDEF ────────────────────────────────────────────────────────────

enum HedefTip { satisAdedi, gelir, tamir, kutu, toptanciAlim, tekSatis }

/// Her günün başında üretilen küçük görev. Tamamlanınca anında ödül verir.
/// Amaç: her güne "hayatta kal"ın ötesinde somut bir amaç koymak.
class GunlukHedef {
  final HedefTip tip;
  final int hedef;
  final int odul;
  int ilerleme;
  bool tamamlandi;

  GunlukHedef({required this.tip, required this.hedef, required this.odul,
    this.ilerleme = 0, this.tamamlandi = false});

  String get emoji {
    switch (tip) {
      case HedefTip.satisAdedi:   return '🛍️';
      case HedefTip.gelir:        return '💰';
      case HedefTip.tamir:        return '🔧';
      case HedefTip.kutu:         return '🎁';
      case HedefTip.toptanciAlim: return '🚚';
      case HedefTip.tekSatis:     return '💎';
    }
  }

  String get baslik {
    switch (tip) {
      case HedefTip.satisAdedi:   return '$hedef ürün sat';
      case HedefTip.gelir:        return '$hedef lira satış yap';
      case HedefTip.tamir:        return '$hedef çürük ürün tamir et';
      case HedefTip.kutu:         return '$hedef kapalı kutu aç';
      case HedefTip.toptanciAlim: return 'Toptancıdan $hedef ürün al';
      case HedefTip.tekSatis:     return 'Tek satışta $hedef lira kazan';
    }
  }

  /// tekSatis'te ilerleme "en yüksek tek satış" olarak tutulur
  double get oran => hedef == 0 ? 1 : (ilerleme / hedef).clamp(0.0, 1.0);

  static GunlukHedef uret(int dukkanSeviye) {
    final rng = Random();
    final k = dukkanSeviye; // 1..5 — dükkan büyüdükçe hedef büyür
    switch (HedefTip.values[rng.nextInt(HedefTip.values.length)]) {
      case HedefTip.satisAdedi:
        final h = 2 + rng.nextInt(2) + k;              // 3..7
        return GunlukHedef(tip: HedefTip.satisAdedi, hedef: h, odul: 60 * h);
      case HedefTip.gelir:
        final h = (400 + rng.nextInt(300)) * k;        // 400..2100+
        return GunlukHedef(tip: HedefTip.gelir, hedef: h, odul: (h * 0.28).round());
      case HedefTip.tamir:
        final h = 1 + (k > 2 ? 1 : 0);                 // 1..2
        return GunlukHedef(tip: HedefTip.tamir, hedef: h, odul: 260 * h);
      case HedefTip.kutu:
        return GunlukHedef(tip: HedefTip.kutu, hedef: 1, odul: 200);
      case HedefTip.toptanciAlim:
        final h = 1 + rng.nextInt(2);                  // 1..2
        return GunlukHedef(tip: HedefTip.toptanciAlim, hedef: h, odul: 130 * h);
      case HedefTip.tekSatis:
        final h = (250 + rng.nextInt(250)) * k;        // 250..1500+
        return GunlukHedef(tip: HedefTip.tekSatis, hedef: h, odul: (h * 0.35).round());
    }
  }

  Map<String, dynamic> toJson() => {
    'tip': tip.name, 'hedef': hedef, 'odul': odul,
    'ilerleme': ilerleme, 'tamamlandi': tamamlandi,
  };

  factory GunlukHedef.fromJson(Map<String, dynamic> j) => GunlukHedef(
    tip: HedefTip.values.firstWhere((e) => e.name == j['tip'], orElse: () => HedefTip.satisAdedi),
    hedef: j['hedef'] as int, odul: j['odul'] as int,
    ilerleme: (j['ilerleme'] as int?) ?? 0,
    tamamlandi: (j['tamamlandi'] as bool?) ?? false,
  );
}

// ─── ROZETLER / HEDEFLER ─────────────────────────────────────────────────────

/// Hedef tamamlanınca rozet kazanılır. Ödüller SADECE yeni sistemleri etkiler —
/// mevcut oyun mekaniklerini kilitlemez, sadece ekler.
class Rozet {
  final String id;
  final String emoji;
  final String baslik;
  final String hedefAciklama;
  final String odul;
  final int hedefDeger;

  const Rozet({required this.id, required this.emoji, required this.baslik,
    required this.hedefAciklama, required this.odul, required this.hedefDeger});

  static const List<Rozet> tumu = [
    Rozet(id: 'ilk_satis', emoji: '🏪', baslik: 'İlk Satış',
      hedefAciklama: 'Bir müşteriye ürün sat', odul: '+100 lira hediye', hedefDeger: 1),
    Rozet(id: 'tuccar', emoji: '💼', baslik: 'Tüccar',
      hedefAciklama: '10 ürün sat', odul: 'Toptancıda 6. tezgâh açılır', hedefDeger: 10),
    Rozet(id: 'tamirci', emoji: '🔧', baslik: 'Tamirci',
      hedefAciklama: '5 çürük ürün tamir et', odul: 'Tamir seti %30 indirimli', hedefDeger: 5),
    Rozet(id: 'kutu_avcisi', emoji: '🎁', baslik: 'Kutu Avcısı',
      hedefAciklama: '10 kapalı kutu aç', odul: 'Kutulardan çürük çıkma şansı yarıya iner', hedefDeger: 10),
    Rozet(id: 'koleksiyoncu', emoji: '💎', baslik: 'Koleksiyoncu',
      hedefAciklama: '10 farklı ürün sat', odul: 'Toptancı ürünleri daha iyi kondisyonda', hedefDeger: 10),
    Rozet(id: 'zengin', emoji: '💰', baslik: 'Zengin',
      hedefAciklama: '10.000 liraya ulaş', odul: 'Toptancıda kalıcı %10 indirim', hedefDeger: 10000),
    Rozet(id: 'pazarlikci', emoji: '🤝', baslik: 'Pazarlık Ustası',
      hedefAciklama: '30 pazarlığı anlaşmayla bitir', odul: 'Çürük ürünler %20 daha ucuz', hedefDeger: 30),
    Rozet(id: 'emektar', emoji: '📅', baslik: 'Emektar',
      hedefAciklama: '15. güne ulaş', odul: 'Her gün başında +200 lira destek', hedefDeger: 15),
  ];
}

class Customer {
  final String name;
  final String gorsel;
  final bool musteriSatiyor;
  final GameItem item;
  final int ilkTeklif;
  final MusteriOzellik ozellik;
  /// Karakterin kuşağı ve cinsiyeti — görselden geliyor, replikleri filtreler.
  final YasGrubu yas;
  final String cinsiyet; // 'E' | 'K'

  Customer({required this.name, required this.gorsel, required this.musteriSatiyor, required this.item, required this.ilkTeklif, required this.ozellik, required this.yas, required this.cinsiyet});

  // ── SELAMLAMA HAVUZLARI ──
  // {AD} = müşteri adı, {URUN} = ürün adı.
  // DİKKAT: Tek harfli placeholder KULLANMA — "Arkadaşlar"daki A'yı da değiştirir.
  //
  // Etiketsiz Replik = her yaşa/cinsiyete uyar. Etiketliler yalnız kendi
  // kuşağına gider; uyan replik bulunamazsa `replikSec` nötrlere düşer.

  static const List<Replik> _kolonyaSelam = [
    Replik('Ben kolonya satıyorum, üreticiyim. İlgilenir misin?', yas: kYasBuyuk),
    Replik('Kolonyacı geldi! Limon, tütün, lavanta... hepsi var. Bakar mısın?'),
    Replik('Selam usta! Kolonya satıyorum, dükkâna misk gibi kokar.'),
    Replik('Kolonyam var kolonya! Müşterinin gönlünü alır, deneyeceksin göreceksin.'),
    Replik('Ben kolonyacı. Dükkânda kolonya olmazsa olmaz, bilirsin.', yas: kYasBuyuk),
    Replik('Babamın kolonya tezgâhı var, ben de dükkânları geziyorum. Alır mısın?', yas: kYasGenc),
    Replik('Harçlığımı çıkarmak için kolonya satıyorum. Bir şişe alsana!', yas: [YasGrubu.cocuk]),
    Replik('Ben kolonyacıyım evladım, kırk yıllık. Bir bak istersen.', yas: [YasGrubu.yasli]),
    Replik('Kolonyanın iyisini kadın bilir derler, bu da benim işim. Bakar mısın?', cinsiyet: 'K', yas: kYasBuyuk),
  ];

  static const List<Replik> _saticiSelam = [
    // ── nötr ──
    Replik('Merhaba, ben {AD}. Elimde {URUN} var, satmak istiyorum. İlgilenir misin?'),
    Replik('Selam! {AD} ben. Şu {URUN} elimde kaldı, alır mısın?'),
    Replik('Kolay gelsin! {AD}. {URUN} satıyorum, bir bakar mısın?'),
    Replik('{AD} ben. {URUN} boşuna duruyordu, dedim satayım. İlgini çeker mi?'),
    Replik('Selamlar! {AD}. {URUN} devretmek istiyorum, konuşalım mı?'),
    Replik('Hayırlı işler! {AD} ben. {URUN} var bende, alıcısı sensin galiba.'),
    Replik('Merhaba! {AD}. Şu {URUN} taşımaktan yoruldum, satalım gitsin.'),
    Replik('Ben {AD}. {URUN} getirdim, hem de tertemiz. Bakar mısın?'),
    Replik('Selam usta! {AD}. {URUN} satılık, ilgilenir misin?'),
    Replik('İyi günler! {AD}. {URUN} elimde, paraya ihtiyacım var. Konuşalım mı?'),
    Replik('Merhaba {AD} ben. {URUN} bu dükkâna yakıştırdım, alır mısın?'),
    Replik('Selam! Ben {AD}. {URUN} satıyorum, fiyatı sen söyle.'),
    Replik('Selam, {AD} ben. Elimde {URUN} var, sana özel fiyat yaparım.'),
    Replik('Merhabalar! {AD} ben. Şu {URUN} için doğru yere mi geldim?'),
    Replik('Selam patron! {AD}. {URUN} satmak istiyorum, vaktin var mı?'),
    Replik('Ben {AD}. Bu {URUN} bende duruyor, sende değer bulur diye geldim.'),
    Replik('Selam! {AD} ben. {URUN} getirdim, kıymetini bilene satarım.'),
    Replik('Merhaba {AD}. Dolabın dibinden {URUN} çıktı, alıcısı var mı dedim.'),
    // ── çocuk ──
    Replik('{AD} ben. Anneme sormadan {URUN} satmaya geldim, aramızda kalsın.', yas: [YasGrubu.cocuk]),
    Replik('Merhaba, adım {AD}. {URUN} bana küçük geldi artık, satsam mı acaba?', yas: [YasGrubu.cocuk]),
    Replik('Ben {AD}! Bisiklet için para biriktiriyorum, {URUN} satıyorum.', yas: [YasGrubu.cocuk]),
    Replik('Selam! {AD}. Ağabeyim "{URUN} satılır" dedi, ben de geldim.', yas: [YasGrubu.cocuk]),
    // ── çocuk + genç ──
    Replik('Selam! {AD} ben. Yeni oyuna para lazım, {URUN} gözden çıkardım.', yas: kYasGenc),
    Replik('{AD} ben. Arkadaşlar burayı önerdi, {URUN} satacağım.', yas: kYasGenc),
    // ── genç ──
    Replik('Selam, {AD}. Öğrenciyim, harçlık bitti; {URUN} satıyorum.', yas: [YasGrubu.genc]),
    Replik('Merhaba {AD} ben. Yurda taşınıyorum, {URUN} sığmıyor valize.', yas: [YasGrubu.genc]),
    Replik('{AD} ben. İnternette satacaktım ama kargoyla uğraşamam. {URUN} sende kalsın.', yas: [YasGrubu.genc]),
    // ── yetişkin ──
    Replik('Merhaba, adım {AD}. Evi toparlarken {URUN} çıktı, sana getirdim.', yas: kYasBuyuk),
    Replik('{AD} ben. Çocuklara oda açıyorum, {URUN} fazlalık oldu.', yas: [YasGrubu.yetiskin]),
    Replik('Selam {AD}. Ay sonu geldi, {URUN} satıp faturaya sayacağım.', yas: [YasGrubu.yetiskin]),
    // ── yetişkin + yaşlı ──
    Replik('Ben {AD}. Gençliğimden kalma {URUN} bu, kıymetini bilene gitsin.', yas: kYasBuyuk),
    Replik('Merhaba {AD}. Bunu aldığımda bu dükkân daha yoktu. {URUN} satılık.', yas: kYasBuyuk),
    // ── yaşlı ──
    Replik('Selam evladım, {AD} ben. Torunum büyüdü, {URUN} artık oynanmıyor evde.', yas: [YasGrubu.yasli]),
    Replik('{AD} ben evladım. Emekli maaşı yetmiyor, {URUN} satayım dedim.', yas: [YasGrubu.yasli]),
    Replik('Merhaba yavrum, adım {AD}. Sandığı karıştırırken {URUN} çıktı.', yas: [YasGrubu.yasli]),
    // ── cinsiyet imalı ──
    Replik('Ben {AD}. Kadın satıcıya ucuza kapatırım sanma, {URUN} kıymetlidir.', cinsiyet: 'K'),
    Replik('Selam! {AD} ben. Ablan sana kazık atmaz, {URUN} tertemiz.', cinsiyet: 'K', yas: kYasBuyuk),
    Replik('Merhaba, {AD}. Oğlum bunu bırakıp gitti; {URUN} bana ne yapsın?', cinsiyet: 'K', yas: [YasGrubu.yasli]),
    Replik('{AD} ben. Delikanlı adam gibi konuşalım: {URUN} satılık, fiyatı sen söyle.', cinsiyet: 'E', yas: kYasYetiskin),
    Replik('Selam evladım, {AD} ben. Amcanı kırma, {URUN} için iyi bir rakam ver.', cinsiyet: 'E', yas: [YasGrubu.yasli]),
  ];

  static const List<Replik> _aliciSelam = [
    // ── nötr ──
    Replik('Selam! Ben {AD}. Elinde {URUN} olduğunu duydum, bana satar mısın?'),
    Replik('Merhaba, {AD} ben. {URUN} arıyorum, sende var mı diye uğradım.'),
    Replik('Kolay gelsin! {AD}. {URUN} için ta buraya geldim, satar mısın?'),
    Replik('Selam! {AD}. Arkadaşlar "{URUN} ondadır" dedi, doğru mu?'),
    Replik('Merhaba! {AD}. {URUN} görünce dayanamadım, alabilir miyim?'),
    Replik('Selamlar, {AD}. {URUN} lazım bana. Konuşalım mı?'),
    Replik('Ben {AD}. {URUN} rüyamda gördüm, sabah soluğu burada aldım.'),
    Replik('Hayırlı işler! {AD}. {URUN} talibim, fiyat nedir?'),
    Replik('{AD} ben. Koleksiyonumda {URUN} eksik. Tamamlayalım mı?'),
    Replik('Merhaba! {AD}. {URUN} varmış sende, gözüme kestirdim.'),
    Replik('Selam usta! {AD}. Şu {URUN} bana ayırır mısın?'),
    Replik('İyi günler, {AD}. {URUN} için pazarlığa hazır mısın?'),
    Replik('Ben {AD}. {URUN} almadan bu dükkândan çıkmam.'),
    Replik('Merhabalar, {AD} ben. {URUN} görürsem duramıyorum, kaça?'),
    Replik('Selam! {AD}. {URUN} bulmak için üç dükkân gezdim, son duraksın.'),
    Replik('Merhaba {AD} ben. Vitrinden {URUN} gördüm, içeri dalıverdim.'),
    Replik('Selam! {AD}. Şu {URUN} bende olmalı, kader bizi buluşturdu.'),
    // ── çocuk ──
    Replik('Kolay gelsin, {AD} ben. {URUN} için harçlığımı biriktirdim!', yas: kYasGenc),
    Replik('Merhaba! Ben {AD}. Annem "bak bakalım" dedi, {URUN} kaça?', yas: [YasGrubu.cocuk]),
    Replik('{AD} ben! Karnem iyi geldi, ödül olarak {URUN} isteyeceğim.', yas: [YasGrubu.cocuk]),
    Replik('Selam abi! {AD}. Kumbaramı kırdım, {URUN} alacağım.', yas: [YasGrubu.cocuk]),
    Replik('Ben {AD}. Sınıfta herkeste {URUN} var, bir bende yok!', yas: [YasGrubu.cocuk]),
    // ── çocuk + genç ──
    Replik('Selam! {AD}. Arkadaşlarda gördüm {URUN}, bende de olsun istiyorum.', yas: kYasGenc),
    Replik('{AD} ben. {URUN} için üç haftadır para biriktiriyorum.', yas: kYasGenc),
    // ── genç ──
    Replik('Merhaba, {AD}. Öğrenciyim; bütçem dar ama {URUN} çok istiyorum.', yas: [YasGrubu.genc]),
    Replik('Selam! {AD} ben. Yurtta akşamları {URUN} oynayacağız, alsam mı?', yas: [YasGrubu.genc]),
    Replik('{AD} ben. Bunu bulduğumu paylaşırsam kıskanırlar. {URUN} satılık mı?', yas: [YasGrubu.genc]),
    // ── yetişkin ──
    Replik('Merhaba {AD}. Çocuğun doğum günü var, {URUN} hediye alacağım.', yas: [YasGrubu.yetiskin]),
    Replik('Selam, {AD} ben. Akşamları kafa dağıtmak istiyorum; {URUN} var mı?', yas: [YasGrubu.yetiskin]),
    Replik('{AD} ben. Yeğenime hediye alacağım, {URUN} tam olur.', yas: kYasBuyuk),
    // ── yetişkin + yaşlı ──
    Replik('{AD} ben. Çocukluğumdan beri {URUN} arıyorum. Sende varmış!', yas: kYasBuyuk),
    Replik('Merhaba {AD}. Bizim zamanımızda {URUN} çok kıymetliydi, hâlâ da öyle.', yas: kYasBuyuk),
    // ── yaşlı ──
    Replik('Selam evladım, {AD} ben. Torunuma {URUN} alacağım, yardım et.', yas: [YasGrubu.yasli]),
    Replik('{AD} ben yavrum. Bu {URUN} nedir bilmem ama torun istiyor, alacağım.', yas: [YasGrubu.yasli]),
    Replik('Merhaba evladım. {AD}. Emekliyim, {URUN} için bir kolaylık yaparsın.', yas: [YasGrubu.yasli]),
    // ── cinsiyet imalı ──
    Replik('Selam! {AD} ben. Kızlar {URUN} oynamaz derler ama ben bayılıyorum. Bana satar mısın?', cinsiyet: 'K', yas: kYasYetiskin),
    Replik('Merhaba, {AD}. Kadın müşteriyi hafife alma; {URUN} için geldim.', cinsiyet: 'K'),
    Replik('{AD} ben yavrum. Teyzeni kırma, {URUN} torunuma lazım.', cinsiyet: 'K', yas: [YasGrubu.yasli]),
    Replik('Selam {AD} ben. Erkek adam istediğini alır: {URUN} bende olacak.', cinsiyet: 'E', yas: kYasYetiskin),
    Replik('Merhaba evladım, {AD} ben. Amcana {URUN} konusunda yardımcı ol.', cinsiyet: 'E', yas: [YasGrubu.yasli]),
  ];

  String get selamMesaji {
    if (musteriSatiyor && item.id == 'kolonya') {
      return replikSec(_kolonyaSelam, yas, cinsiyet);
    }
    final havuz = musteriSatiyor ? _saticiSelam : _aliciSelam;
    return replikSec(havuz, yas, cinsiyet)
        .replaceAll('{AD}', name)
        .replaceAll('{URUN}', item.name);
  }
}

// ─── OYUN DURUMU ─────────────────────────────────────────────────────────────

class GameState extends ChangeNotifier {
  int para = 1000;
  int gun = 1;
  int musteriSayisi = 0;
  int gunlukMusteriSayisi = 0;
  int gunlukMusteriLimiti = 12; // ilk gün için üretilir
  OzelMusteri? aktifOzelMusteri;
  bool ozelMusteriGorunuyor = false;
  int _sonrakiOzelMusteriSayisi = 0; // kaçıncı müşteride özel gelecek
  int _ozelMusteriSayaci = 0;        // toplam müşteri sayacı (özel dahil değil)
  // Rotasyon: sadece "olay" tipli özel müşteriler. Toptancı Rıza BURADA DEĞİL —
  // onun kendi günlük programı var (_rizaGunuAyarla).
  List<OzelMusteriTip> _ozelTipSirasi = [OzelMusteriTip.hirsiz, OzelMusteriTip.polis, OzelMusteriTip.vergici, OzelMusteriTip.kurye, OzelMusteriTip.falci];
  int _ozelTipIndex = 0;
  /// Falcının kehaneti: bir sonraki özel müşteri bu tip olacak.
  /// Sıradaki müşteride tüketilir (rotasyon bozulmaz, sadece araya girer).
  OzelMusteriTip? zorunluOzelTip;

  void _ozelMusteriSayaciniAyarla() {
    _sonrakiOzelMusteriSayisi = _ozelMusteriSayaci + 10 + Random().nextInt(11); // 10-20 sonra
  }

  // ── Toptancı Rıza: hırsız/polis/vergici/kurye rotasyonundan AYRI çalışır.
  //    O rotasyon 10-20 müşteride bir → 5 tiple Rıza'ya sıra 5-7 günde bir gelirdi.
  //    Ekonominin merkezindeki bir karakter için çok seyrek. Rıza günde bir uğrar.
  bool _rizaBugunGeldi = false;
  int  _rizaZiyaretSirasi = 2;

  void _rizaGunuAyarla() {
    _rizaBugunGeldi = false;
    final ust = gunlukMusteriLimiti - 3;
    _rizaZiyaretSirasi = 2 + (ust > 1 ? Random().nextInt(ust) : 0);
    _galericiBugunGeldi = false;
  }

  // ── Galerici Gürbüz: Rıza gibi kendi programı var, rotasyona girmez.
  //    4. günden itibaren ÜÇ GÜNDE BİR (4, 7, 10…) günün 2. müşterisi olarak
  //    uğrar. Her gün gelmesi araç almayı sıradanlaştırırdı.
  bool _galericiBugunGeldi = false;
  bool get _galericiZamani =>
      !_galericiBugunGeldi && gun >= 4 && (gun - 4) % 3 == 0;

  /// Özel müşteri ROTASYONUNA hiç girmeyen tipler — her birinin kendi
  /// programı var, rotasyondan da gelirlerse iki kez gelmiş olurlar.
  static const Set<OzelMusteriTip> _rotasyonDisi = {
    OzelMusteriTip.toptanci,
    OzelMusteriTip.guvenlik,
    OzelMusteriTip.galerici,
    OzelMusteriTip.hande,
  };

  // ── 🚗 ARAÇ / 🏠 KONUM ────────────────────────────────────────────────────

  /// Envanterdeki araçlar. "Konum Değiştir" bunlardan birini ister.
  List<GameItem> get sahipAraclar =>
      slotlar.whereType<GameItem>().where((u) => u.category == ItemCategory.arac).toList();
  bool get aracVar => sahipAraclar.isNotEmpty;

  /// Ev / yazlık satın alındı mı (Market'ten) ve içlerine hangi eşyalar
  /// konuldu. Eşya id'leri iki mekân arasında benzersiz (yazlıkta `y_` ön eki),
  /// bu yüzden tek küme yetiyor.
  bool evSahibi = false;
  bool yazlikSahibi = false;
  Set<String> evEsyalari = {};

  bool konumSahibi(Konum k) => k == Konum.yazlik ? yazlikSahibi : evSahibi;

  /// Oyuncu şu an nerede? Yolculuk bittikten sonra `ev` olabilir.
  Konum aktifKonum = Konum.dukkan;

  /// Galerici'nin tezgâhından bir araç seçildi: özel müşteri artık sıradan bir
  /// SATICI müşteriye dönüşür ve normal pazarlık başlar.
  ///
  /// ⚠️ Ekranda karakter zaten duruyor; `_slideController` 1.0'da olduğu için
  /// yeniden içeri girmez, sadece widget'ı değişir (özel → normal müşteri).
  void galericiAracSec(GameItem arac) {
    final ozellik = MusteriOzellik.random();
    final fiyat = arac.etkinFiyat;
    final pv = ozellik.perceivedValue(arac.kondisyon, fiyat);
    final reserv = _piyasaEtkisi(ozellik.reservationPrice(pv, fiyat, true), true);
    final ilkTeklif = ozellik.openingOffer(reserv, fiyat, true).round();

    aktifOzelMusteri = null;
    ozelMusteriGorunuyor = false;
    aktifMusteri = Customer(
      name: 'Galerici Gürbüz', gorsel: 'assets/galerici.png',
      musteriSatiyor: true, item: arac, ilkTeklif: ilkTeklif,
      ozellik: ozellik, yas: YasGrubu.yetiskin, cinsiyet: 'E');
    musteriGorunuyor = true;
    musteriKabulBekliyor = false;

    aktifPazarlik = PazarlikSeans(
      musteriSatiyor: true,
      piyasaFiyati: fiyat,
      musteriTeklif: ilkTeklif,
      oyuncuTeklif: (fiyat * 0.65).round(),
      maxTur: ozellik.maxTur,
      ozellik: ozellik,
      reservationPrice: reserv,
      yas: YasGrubu.yetiskin,
      cinsiyet: 'E',
    );
    mesaj = 'Bu araca $ilkTeklif lira. Hesaplı iş abi, kaçırma!';
    notifyListeners();
  }

  /// Market'ten ev ya da yazlık alınır. Yetersiz parada false döner.
  bool mekanSatinAl(Konum k) {
    final fiyat = k == Konum.yazlik ? EvEsyasi.yazlikFiyati : EvEsyasi.evFiyati;
    if (konumSahibi(k) || para < fiyat) return false;
    para -= fiyat;
    if (k == Konum.yazlik) { yazlikSahibi = true; } else { evSahibi = true; }
    SesServisi.paraGirdi();
    notifyListeners();
    return true;
  }

  /// Evdeki "Eşya Al" tezgâhından bir mobilya alınır.
  bool evEsyasiAl(EvEsyasi e) {
    if (evEsyalari.contains(e.id) || para < e.fiyat) return false;
    para -= e.fiyat;
    evEsyalari.add(e.id);
    SesServisi.paraGirdi();
    notifyListeners();
    return true;
  }

  void konumaGec(Konum k) {
    aktifKonum = k;
    notifyListeners();
  }
  int toplamTeklifSayisi = 0;
  int krediKalanTaksit = 0;
  int krediTaksitMiktar = 0;
  int tamamlananKrediSayisi = 0; // kaç kredi tamamen ödendi (taksit limiti için)
  bool get aktifKrediVar => krediKalanTaksit > 0;
  bool imacSatinAlindi = false;
  int kolonyaKullanim = 0;      // mevcut kolonya kullanım hakkı (0 = yok)
  bool kolonyaIkramEdildi = false; // bu müşteriye ikram edildi mi
  double _kolonyaPendingBonus = 0.0; // pazarlık başlamadan ikram edildiyse bekleyen bonus
  bool kuryeBonusuAktif = false;    // bir sonraki müşteri çok avantajlı olacak
  /// Kuryeden alınan yemek henüz yenmedi. Alt barda "Yemeği Ye" butonu çıkar;
  /// yenince envanterdeki bütün çürük ürünler tamir olur.
  bool yemekVar = false;

  /// Bugün oynanmış oynanabilir ürünlerin id'leri.
  ///
  /// ⚠️ Her oyun GÜNDE 1 KEZ oynanabilir. Sınır olmasaydı oyuncu aynı CD'yi
  /// üst üste oynayıp sınırsız para basardı. `gunuBitir()` içinde temizlenir.
  Set<String> bugunOynananOyunlar = {};

  /// Mini oyunlardan bir günde kazanılabilecek para tavanı (oyun başına).
  static const int oyunPuanTavani = 1000;

  /// Yemeği ye: keyif yerine gelir, tüm hasarlı ekipman tamir olur.
  /// Kaç ürünün onarıldığını döner (0 ise gösterilecek bir şey yok demektir).
  int yemegiYe() {
    yemekVar = false;
    int sayi = 0;
    for (int i = 0; i < slotlar.length; i++) {
      final u = slotlar[i];
      if (u != null && u.curuk) {
        // Çürüklük kalkınca etkinFiyat otomatik olarak tam piyasa fiyatına
        // döner; kondisyonu da elden geçirilmiş gibi yukarı çekiyoruz.
        slotlar[i] = u.kopyaWith(curuk: false, kondisyon: 4 + Random().nextInt(2));
        sayi++;
      }
    }
    if (sayi > 0) tamirEdilenSayisi += sayi;
    notifyListeners();
    return sayi;
  }
  /// Son gelen ürünler (en yenisi başta). Aynı ürünün üst üste çıkmasını
  /// engeller — tek id tutmak yetmiyordu, alıcı/satıcı sırayla gelince aynı
  /// mal iki tur arayla tekrar düşebiliyordu.
  final List<String> _sonUrunIdleri = [];
  static const int _sonUrunHafizasi = 2;
  String? get _sonUrunId => _sonUrunIdleri.isEmpty ? null : _sonUrunIdleri.first;
  void _sonUrunKaydet(String id) {
    _sonUrunIdleri.insert(0, id);
    if (_sonUrunIdleri.length > _sonUrunHafizasi) _sonUrunIdleri.removeLast();
  }
  /// Oynanabilir ürün günde bir kez gelir; bugün geldi mi?
  bool _bugunOynanabilirGeldi = false;
  /// Bugün ve dün gelen oynanabilir ürün — iki gün üst üste aynısı gelmesin.
  String? _bugunGelenOynanabilirId;
  String? _dunGelenOynanabilirId;

  // ── Tamir seti (kolonya gibi: slot yemez, sayaç olarak tutulur) ──
  int tamirSetiAdet = 0;

  // ── Toptancı ──
  List<ToptanciUrun> toptanciStok = [];
  int toptanciStokGunu = 0; // stok hangi gün için üretildi (0 = henüz üretilmedi)

  // ── Günlük olay ──
  String? gunlukOlayId;
  String? yarinkiOlayId;             // gün sonunda açıklanır → "bir gün daha" kancası
  double piyasaCarpani = 1.0;        // >1 cömert gün, <1 cimri gün
  double gunlukToptanciIndirim = 0.0;

  // ── Seri (kombo) ──
  // Üst üste anlaşmayla biten pazarlık. Müşteri kızıp giderse sıfırlanır.
  // Oyuncunun kendi reddi seriyi BOZMAZ (kötü teklifi reddetmek meşru strateji).
  int kombo = 0;
  int enUzunSeri = 0;
  int sonKomboBonusu = 0;            // UI mesajı için

  // ── Günlük hedef ──
  GunlukHedef? gunlukHedef;
  bool hedefYeniTamamlandi = false;  // UI bunu görüp kutlama gösterir

  // ── İstatistikler (rozet ilerlemesi) ──
  int toplamSatis = 0;
  int tamirEdilenSayisi = 0;
  int acilanKutuSayisi = 0;
  int basariliPazarlik = 0;
  Set<String> satilanUrunIdleri = {};

  // ── 📚 KOLEKSİYON ─────────────────────────────────────────────────────────
  /// ⚠️ Koleksiyona girmenin TEK yolu: envanterdeki bir ürünü SATMAK YERİNE
  /// "Koleksiyona Taşı" ile buraya koymak. Satılan ürünler artık koleksiyonda
  /// GÖRÜNMEZ — eskiden her satış otomatik açıyordu ve koleksiyon bir başarı
  /// değil, kendiliğinden dolan bir liste oluyordu.
  ///
  /// Ürün id'leri; aynı üründen ikinci kopya koleksiyonu şişirmesin diye Set.
  Set<String> koleksiyondakiler = {};

  /// Tamamlanıp ödülü alınmış koleksiyon hedeflerinin id'leri.
  Set<String> koleksiyonOdulAlinan = {};

  /// Koleksiyona konan ürünlerin gerçek nesneleri (kategori/oynanabilirlik
  /// hedeflerini sayabilmek için id'den çözülüyor).
  List<GameItem> get koleksiyonNesneleri => koleksiyondakiler
      .map((id) => koleksiyonUrunleri.where((u) => u.id == id).firstOrNull)
      .whereType<GameItem>()
      .toList();

  /// Envanterdeki ürünü kalıcı olarak koleksiyona taşır.
  /// Slot boşalır ama ürün bir daha satılamaz — bilinçli bir takas.
  bool koleksiyonaTasi(GameItem item) {
    if (koleksiyondakiler.length >= kKoleksiyonKutuSayisi) return false;
    if (koleksiyondakiler.contains(item.id)) return false; // zaten var
    if (!urunCikarOrnek(item)) return false;
    koleksiyondakiler.add(item.id);
    notifyListeners();
    return true;
  }

  /// Bu ürün koleksiyona konabilir mi? (zaten varsa ya da yer yoksa hayır)
  ///
  /// ⚠️ Araçlar koleksiyona GİRMEZ: koleksiyon kutuları `koleksiyonUrunleri`
  /// üzerinden çözülüyor, araçlar o listede değil — konsaydı id sette kalır
  /// ama kutuda hiçbir şey görünmezdi.
  bool koleksiyonaKonabilir(GameItem item) =>
      item.category != ItemCategory.arac &&
      !item.kapaliKutu &&
      !koleksiyondakiler.contains(item.id) &&
      koleksiyondakiler.length < kKoleksiyonKutuSayisi;

  /// Tamamlanmış ama ödülü alınmamış hedefleri ödüllendirir; toplam ödülü döner.
  int koleksiyonOdulleriTopla() {
    int toplam = 0;
    for (final h in KoleksiyonHedefi.tumu) {
      if (koleksiyonOdulAlinan.contains(h.id)) continue;
      if (h.ilerleme(this) >= h.hedef) {
        koleksiyonOdulAlinan.add(h.id);
        toplam += h.odul;
      }
    }
    if (toplam > 0) {
      para += toplam;
      SesServisi.paraGirdi();
      notifyListeners();
    }
    return toplam;
  }
  int enYuksekPara = 1000;

  // ── Rozetler ──
  Set<String> kazanilanRozetler = {};
  final List<Rozet> yeniKazanilanRozetler = []; // UI bunu boşaltıp popup gösterir

  bool rozetVar(String id) => kazanilanRozetler.contains(id);

  // Rozet ödülleri — hepsi SADECE yeni sistemleri etkiler
  int    get toptanciSlotSayisi   => rozetVar('tuccar') ? 6 : 5;
  double get tamirSetiIndirim     => rozetVar('tamirci') ? 0.30 : 0.0;
  double get toptanciKaliciIndirim=> rozetVar('zengin') ? 0.10 : 0.0;
  double get curukEkIndirim       => rozetVar('pazarlikci') ? 0.20 : 0.0;
  double get kutuCurukSansi       => rozetVar('kutu_avcisi') ? 0.125 : 0.25;
  bool   get toptanciIyiKondisyon => rozetVar('koleksiyoncu');
  int    get gunlukDestek         => rozetVar('emektar') ? 200 : 0;

  int rozetIlerleme(String id) {
    switch (id) {
      case 'ilk_satis':    return toplamSatis;
      case 'tuccar':       return toplamSatis;
      case 'tamirci':      return tamirEdilenSayisi;
      case 'kutu_avcisi':  return acilanKutuSayisi;
      case 'koleksiyoncu': return satilanUrunIdleri.length;
      case 'zengin':       return enYuksekPara;
      case 'pazarlikci':   return basariliPazarlik;
      case 'emektar':      return gun;
      default:             return 0;
    }
  }

  /// Kazanılan yeni rozetleri tespit eder. notifyListeners içinden çağrılır —
  /// kendisi notifyListeners ÇAĞIRMAZ (sonsuz döngü olmasın).
  void _rozetleriDenetle() {
    for (final r in Rozet.tumu) {
      if (kazanilanRozetler.contains(r.id)) continue;
      if (rozetIlerleme(r.id) >= r.hedefDeger) {
        kazanilanRozetler.add(r.id);
        if (r.id == 'ilk_satis') para += 100; // anlık ödül
        yeniKazanilanRozetler.add(r);
      }
    }
  }
  // ⚠️ `mesaj` doğrudan alan DEĞİL, setter'lı.
  // TypewriterText yalnızca metin DEĞİŞİRSE animasyonu baştan oynatıyor.
  // Replik havuzundan aynı satır iki kez seçilince (ya da fiyat aynı kalınca)
  // ekranda hiçbir şey olmuyor, oyuncu "teklifim tepkisiz kaldı" sanıyordu.
  // `mesajSayaci` her atamada artar ve balona key olarak verilir → aynı metin
  // bile olsa yazım animasyonu yeniden oynar.
  String _mesaj = 'Dükkan açıldı! İlk müşteri bekleniyor...';
  int mesajSayaci = 0;
  String get mesaj => _mesaj;
  set mesaj(String v) {
    // ⚠️ 🐛 AYNI metin tekrar atanırsa sayaç ARTMAZ.
    // `mesajSayaci` balondaki TypewriterText'in key'i; artınca State sıfırlanıp
    // yazı baştan yazılıyor. Bazı akışlarda (müşteri reddedilip çıkarken)
    // mesaj aynı içerikle iki kez atanıyor ve yazı üst üste iki kez
    // yazılıyordu. TypewriterText zaten `didUpdateWidget`te metin değişince
    // kendini yeniden başlatıyor; buradaki tek iş GERÇEK değişimi saymak.
    if (v == _mesaj) return;
    _mesaj = v;
    mesajSayaci++;
  }
  Customer? aktifMusteri;
  PazarlikSeans? aktifPazarlik;
  bool musteriGorunuyor = false;
  bool musteriKabulBekliyor = false;
  /// Anlaşma fiyat olarak kabul edildi ama para yetmediği için GERÇEKLEŞMEDİ.
  /// Widget bunu görüp "ürün masadan aşağı kayıp gitme" efektini atlar —
  /// müşteri elindeki malla birlikte normal şekilde sağdan çıkar.
  bool sonAnlasmaBasarisiz = false;
  DukkanSeviye aktifDukkan = tumDukkanlar[0]; // Seviye 1'den başla

  // ── REHBER HANDE (açılış tanıtımı) ────────────────────────────────────────
  /// Hande oyunun EN BAŞINDA bir kez gelir; "Müşteri Çağır"a basmak gerekmez.
  /// Gösterildikten sonra bir daha gelmez (kayıtta saklanır).
  bool handeGosterildi = false;

  /// Hande'nin kaçıncı repliğinde olduğumuz (0..replikSayisi-1).
  int handeAdim = 0;

  bool get handeAktif => aktifOzelMusteri?.tip == OzelMusteriTip.hande;

  /// Açılış tanıtımını başlatır. Müşteri sayacına DOKUNMAZ: Hande bir ziyaret
  /// değil, oyunun girişi — günlük müşteri hakkını yemesi haksızlık olur.
  void handeyiGonder() {
    if (handeGosterildi) return;
    handeGosterildi = true;
    handeAdim = 0;
    aktifOzelMusteri = OzelMusteri.hande();
    ozelMusteriGorunuyor = true;
    musteriKabulBekliyor = false; // EVET/HAYIR değil, tek "Tamam" butonu var
    mesaj = OzelMusteri.handeReplikleri[0];
    notifyListeners();
  }

  /// "Tamam"a basıldı. Sıradaki replik varsa ona geçer ve `true` döner;
  /// replikler bittiyse `false` döner (çağıran taraf Hande'yi gönderir).
  bool handeIlerle() {
    if (handeAdim >= OzelMusteri.handeReplikleri.length - 1) return false;
    handeAdim++;
    mesaj = OzelMusteri.handeReplikleri[handeAdim];
    notifyListeners();
    return true;
  }

  // ── YAKIŞIKLI GÜVENLİK ────────────────────────────────────────────────────
  /// Güvenlik tutulduysa arka plan güvenlikli sürüme geçer ve **hırsız asla
  /// gelmez**. Ücret her gün kirayla birlikte kesilir; para yetmezse işi bırakır.
  bool guvenlikVar = false;
  static const int guvenlikGunlukUcret = 50;

  /// Teklif 3. günde bir kez gelir. HAYIR denirse 3'ün katlarında tekrar dener.
  /// Kabul edildiyse (ya da hâlâ çalışıyorsa) bir daha teklif gelmez.
  int guvenlikSonTeklifGunu = 0;

  /// Ücreti ödenemediği için güvenlik işi bıraktı — gün sonu popup'ı duyurur,
  /// gösterildikten sonra UI sıfırlar.
  bool guvenlikIsiBirakti = false;

  /// Aktif dükkanın o anki arka planı (güvenlik varsa güvenlikli sürüm).
  /// ⚠️ Güvenlik "işi bırakmamı ister misin?" diye sormak üzere ÖNE geldiğinde
  /// arka plan güvenliksiz sürüme döner. Yoksa ekranda aynı anda iki güvenlik
  /// olurdu: biri tezgâhta konuşan, biri arka planda hâlâ kapıda duran.
  String get aktifArkaplan =>
      (guvenlikVar && !_guvenlikOnde) ? aktifDukkan.arkaplanGuv : aktifDukkan.arkaplan;

  /// Güvenlik şu an müşteri gibi öne gelmiş mi (istifa sorusu).
  bool _guvenlikOnde = false;

  // ── SAHİP OLUNAN DÜKKANLAR ────────────────────────────────────────────────
  /// Satın alınmış satılık dükkanların isimleri. Bunlarda günlük kira yok.
  Set<String> sahipDukkanlar = {};

  /// Sahip olunup KİRAYA VERİLEN dükkanların isimleri — her gün gelir getirir.
  /// Oyuncu kendi oturduğu dükkanı kiraya veremez.
  Set<String> kirayaVerilenDukkanlar = {};

  /// Kiraya verilen bir dükkanın günlük getirisi: bedelinin %1'i.
  /// (Fakir Dükkan 5000 → 50/gün, Rezidans 20000 → 200/gün.)
  static int kiraGeliriHesapla(DukkanSeviye d) =>
      ((d.satinAlmaFiyati ?? 0) * 0.01).round();

  int get gunlukKiraGeliri => kirayaVerilenDukkanlar
      .map((isim) => satilikDukkanlar.firstWhere((d) => d.isim == isim))
      .fold(0, (t, d) => t + kiraGeliriHesapla(d));

  // 25 slot: her dükkan seviyesi 5 slot açar
  // null = boş slot, GameItem = dolu slot
  // Başlangıç: 3 ürün + 2 boş (seviye 1 = 5 slot), geri 20 slot kilitli
  static final List<GameItem> _baslangicUrunler = [
    GameItem(id: 'cd1',      name: 'KARMAGEDDON',       gorsel: 'assets/CD_1.png',                category: ItemCategory.cd,      basePrice: 80,   kondisyon: 4),
    GameItem(id: 'cd2',      name: 'CİMRİCİTY',         gorsel: 'assets/CD_2.png',                category: ItemCategory.cd,      basePrice: 120,  kondisyon: 3),
    GameItem(id: 'cd3',      name: 'SOKAKSOCCER',        gorsel: 'assets/CD_3.png',                category: ItemCategory.cd,      basePrice: 90,   kondisyon: 5),
    GameItem(id: 'cd4',      name: 'ZOOMDAY',            gorsel: 'assets/CD_4.png',                category: ItemCategory.cd,      basePrice: 150,  kondisyon: 2),
    GameItem(id: 'cd5',      name: 'GTR 7',              gorsel: 'assets/CD_5.png',                category: ItemCategory.cd,      basePrice: 200,  kondisyon: 5),
    GameItem(id: 'cd6',      name: 'BOKUS 4D',           gorsel: 'assets/CD_6.png',                category: ItemCategory.cd,      basePrice: 250,  kondisyon: 1),
    GameItem(id: 'cd7',      name: 'TENİS OYUNU',        gorsel: 'assets/CD_7.png',                category: ItemCategory.cd,      basePrice: 110,  kondisyon: 4),
    GameItem(id: 'cd8',      name: 'DALAKKÜREK',         gorsel: 'assets/CD_8.png',                category: ItemCategory.cd,      basePrice: 95,   kondisyon: 3),
    GameItem(id: 'cd9',      name: 'ŞAHMAT',             gorsel: 'assets/CD_9.png',                category: ItemCategory.cd,      basePrice: 130,  kondisyon: 5),
    GameItem(id: 'cd10',     name: 'TOTORACER',          gorsel: 'assets/CD_10.png',               category: ItemCategory.cd,      basePrice: 160,  kondisyon: 4),
    GameItem(id: 'cd11',     name: 'GAMLIBAYKUŞ',        gorsel: 'assets/CD_11.png',               category: ItemCategory.cd,      basePrice: 140,  kondisyon: 2),
    GameItem(id: 'cd12',     name: 'KISPET',             gorsel: 'assets/CD_12.png',               category: ItemCategory.cd,      basePrice: 175,  kondisyon: 3),
    GameItem(id: 'cd13',     name: 'UÇARSOKAR',          gorsel: 'assets/CD_13.png',               category: ItemCategory.cd,      basePrice: 120,  kondisyon: 5),
    GameItem(id: 'cd14',     name: 'DÜTTÜRÜ',            gorsel: 'assets/CD_14.png',               category: ItemCategory.cd,      basePrice: 85,   kondisyon: 4),
    // ⭐ OYNANABİLİR — envanterde tıklanınca gerçekten Kırgeç oynanır.
    // NADİR gelir (bkz. yeniMusteriGonder), toptancı/kutudan hiç çıkmaz.
    // FİYAT KURALI: oynanabilir oyunlar normal oyunların ~2 KATI pahalıdır
    // (normal CD ortalaması ≈ 134 → 270). Yeni oynanabilir ürün eklenirse
    // aynı orana uy.
    GameItem(id: 'cd15',     name: 'KIRGEÇ',             gorsel: 'assets/CD_15.png',               category: ItemCategory.cd,      basePrice: 270,  kondisyon: 5, oynanabilir: true),
    GameItem(id: 'cd16',     name: 'İTELE',              gorsel: 'assets/CD_16.png',               category: ItemCategory.cd,      basePrice: 270,  kondisyon: 5, oynanabilir: true),
    GameItem(id: 'cd17',     name: 'TISSS',              gorsel: 'assets/CD_17.png',               category: ItemCategory.cd,      basePrice: 270,  kondisyon: 5, oynanabilir: true),
    // ── v108: 13 yeni CD (normal, oynanamaz) ──
    // Fiyatlar mevcut CD ortalamasını (~136) koruyacak şekilde dağıtıldı;
    // yoksa "oynanabilir = 2 katı" dengesi kayardı.
    GameItem(id: 'cd18',     name: 'ŞEHRİŞER',           gorsel: 'assets/CD_18.png',               category: ItemCategory.cd,      basePrice: 165,  kondisyon: 5),
    GameItem(id: 'cd19',     name: 'UÇURBENİ',           gorsel: 'assets/CD_19.png',               category: ItemCategory.cd,      basePrice: 130,  kondisyon: 4),
    GameItem(id: 'cd20',     name: 'CIPCIP',             gorsel: 'assets/CD_20.png',               category: ItemCategory.cd,      basePrice: 95,   kondisyon: 3),
    GameItem(id: 'cd21',     name: 'TANTUNİ',            gorsel: 'assets/CD_21.png',               category: ItemCategory.cd,      basePrice: 145,  kondisyon: 5),
    GameItem(id: 'cd22',     name: 'VURKAÇ',             gorsel: 'assets/CD_22.png',               category: ItemCategory.cd,      basePrice: 155,  kondisyon: 4),
    GameItem(id: 'cd23',     name: 'BİLEZ',              gorsel: 'assets/CD_23.png',               category: ItemCategory.cd,      basePrice: 90,   kondisyon: 4),
    GameItem(id: 'cd24',     name: 'TAHTAKALE',          gorsel: 'assets/CD_24.png',               category: ItemCategory.cd,      basePrice: 180,  kondisyon: 5),
    GameItem(id: 'cd25',     name: 'SÜMSÜK',             gorsel: 'assets/CD_25.png',               category: ItemCategory.cd,      basePrice: 125,  kondisyon: 4),
    GameItem(id: 'cd26',     name: 'BİLEKZORU',          gorsel: 'assets/CD_26.png',               category: ItemCategory.cd,      basePrice: 100,  kondisyon: 3),
    GameItem(id: 'cd27',     name: 'MAHŞER',             gorsel: 'assets/CD_27.png',               category: ItemCategory.cd,      basePrice: 190,  kondisyon: 5),
    GameItem(id: 'cd28',     name: 'DİKİZ',              gorsel: 'assets/CD_28.png',               category: ItemCategory.cd,      basePrice: 115,  kondisyon: 4),
    GameItem(id: 'cd29',     name: 'TAMTAM',             gorsel: 'assets/CD_29.png',               category: ItemCategory.cd,      basePrice: 135,  kondisyon: 4),
    GameItem(id: 'cd30',     name: 'KOKARCA',            gorsel: 'assets/CD_30.png',               category: ItemCategory.cd,      basePrice: 140,  kondisyon: 5),
    // ── v112: 11 yeni CD (YENİLEMELER klasöründen) ──
    GameItem(id: 'cd31',     name: 'ÇATAPAT',            gorsel: 'assets/CD_31.png',               category: ItemCategory.cd,      basePrice: 95,   kondisyon: 5),
    GameItem(id: 'cd32',     name: 'KOKOŞ',              gorsel: 'assets/CD_32.png',               category: ItemCategory.cd,      basePrice: 125,  kondisyon: 4),
    GameItem(id: 'cd33',     name: 'METRİS',             gorsel: 'assets/CD_33.png',               category: ItemCategory.cd,      basePrice: 155,  kondisyon: 5),
    GameItem(id: 'cd34',     name: 'BOMBERCAN',          gorsel: 'assets/CD_34.png',               category: ItemCategory.cd,      basePrice: 145,  kondisyon: 4),
    GameItem(id: 'cd35',     name: 'DOBROVSKİ',          gorsel: 'assets/CD_35.png',               category: ItemCategory.cd,      basePrice: 110,  kondisyon: 3),
    GameItem(id: 'cd36',     name: 'İPİMLE KUŞAĞIM',     gorsel: 'assets/CD_36.png',               category: ItemCategory.cd,      basePrice: 100,  kondisyon: 5),
    GameItem(id: 'cd37',     name: 'RECAİ MUMUDİK',      gorsel: 'assets/CD_37.png',               category: ItemCategory.cd,      basePrice: 165,  kondisyon: 4),
    GameItem(id: 'cd38',     name: 'RUHİ KANTER',        gorsel: 'assets/CD_38.png',               category: ItemCategory.cd,      basePrice: 120,  kondisyon: 5),
    GameItem(id: 'cd39',     name: 'SATAN SATANA',       gorsel: 'assets/CD_39.png',               category: ItemCategory.cd,      basePrice: 175,  kondisyon: 3),
    GameItem(id: 'cd40',     name: 'ZIMBALA',            gorsel: 'assets/CD_40.png',               category: ItemCategory.cd,      basePrice: 190,  kondisyon: 4),
    GameItem(id: 'cd41',     name: 'KEVGİR',             gorsel: 'assets/CD_41.png',               category: ItemCategory.cd,      basePrice: 210,  kondisyon: 5),
    GameItem(id: 'cd42',     name: 'PELTE',              gorsel: 'assets/CD_42.png',               category: ItemCategory.cd,      basePrice: 85,   kondisyon: 5),
    GameItem(id: 'cd43',     name: 'SEMSEK',             gorsel: 'assets/CD_43.png',               category: ItemCategory.cd,      basePrice: 130,  kondisyon: 4),
    GameItem(id: 'cd44',     name: 'NÖRÜN',              gorsel: 'assets/CD_44.png',               category: ItemCategory.cd,      basePrice: 150,  kondisyon: 4),
    GameItem(id: 'cd45',     name: 'ÇAYYNİİZ',           gorsel: 'assets/CD_45.png',               category: ItemCategory.cd,      basePrice: 105,  kondisyon: 3),
    GameItem(id: 'cd46',     name: 'CUMBURLOP',          gorsel: 'assets/CD_46.png',               category: ItemCategory.cd,      basePrice: 160,  kondisyon: 5),
    GameItem(id: 'konsol1',  name: 'PlayStatyon',          gorsel: 'assets/konsol_1.png',          category: ItemCategory.konsol,  basePrice: 900,  kondisyon: 4),
    GameItem(id: 'konsol2',  name: 'Ninetendo',            gorsel: 'assets/konsol_2.png',          category: ItemCategory.konsol,  basePrice: 750,  kondisyon: 3),
    GameItem(id: 'konsol3',  name: 'Ateri',                gorsel: 'assets/konsol_3.png',          category: ItemCategory.konsol,  basePrice: 500,  kondisyon: 2),
    GameItem(id: 'konsol4',  name: 'El Konsolu',           gorsel: 'assets/konsol_4.png',          category: ItemCategory.konsol,  basePrice: 420,  kondisyon: 4),
    GameItem(id: 'konsol5',  name: 'El Konsolu',           gorsel: 'assets/konsol_5.png',          category: ItemCategory.konsol,  basePrice: 380,  kondisyon: 2),
    GameItem(id: 'konsol6',  name: 'El Konsolu',           gorsel: 'assets/konsol_6.png',          category: ItemCategory.konsol,  basePrice: 560,  kondisyon: 5),
    GameItem(id: 'konsol7',  name: 'son sistem oyun konsolu', gorsel: 'assets/konsol_7.png',       category: ItemCategory.konsol,  basePrice: 3200, kondisyon: 4),
    GameItem(id: 'aksesuar1',name: 'Oyuncu Direksiyonu',   gorsel: 'assets/oyuncudireksiyonu.png', category: ItemCategory.aksesuar,basePrice: 600,  kondisyon: 3),
    GameItem(id: 'aksesuar2',name: 'Joypad',               gorsel: 'assets/joypad.png',            category: ItemCategory.aksesuar,basePrice: 280,  kondisyon: 3),
    GameItem(id: 'kolonya',  name: 'Kolonya',              gorsel: 'assets/kolonya.png',           category: ItemCategory.aksesuar,basePrice: 120,  kondisyon: 5),
    // ── v109: 9 yeni ekipman (3 el konsolu + 6 aksesuar) ──
    GameItem(id: 'konsol8',  name: 'El Konsolu',           gorsel: 'assets/konsol_8.png',          category: ItemCategory.konsol,  basePrice: 450,  kondisyon: 4),
    GameItem(id: 'konsol9',  name: 'El Konsolu',           gorsel: 'assets/konsol_9.png',          category: ItemCategory.konsol,  basePrice: 620,  kondisyon: 5),
    GameItem(id: 'konsol10', name: 'El Konsolu',           gorsel: 'assets/konsol_10.png',         category: ItemCategory.konsol,  basePrice: 520,  kondisyon: 4),
    GameItem(id: 'aksesuar3',name: '3D Gözlük',            gorsel: 'assets/vrgozluk.png',          category: ItemCategory.aksesuar,basePrice: 850,  kondisyon: 5),
    GameItem(id: 'aksesuar4',name: 'Oyuncu Kulaklığı',     gorsel: 'assets/kulaklik_1.png',        category: ItemCategory.aksesuar,basePrice: 340,  kondisyon: 4),
    GameItem(id: 'aksesuar5',name: 'Kulaklık ve Stant',    gorsel: 'assets/kulaklik_2.png',        category: ItemCategory.aksesuar,basePrice: 390,  kondisyon: 5),
    GameItem(id: 'aksesuar6',name: 'Kablosuz Joypad',      gorsel: 'assets/kumanda_2.png',         category: ItemCategory.aksesuar,basePrice: 300,  kondisyon: 4),
    GameItem(id: 'aksesuar7',name: 'Direksiyon Seti',      gorsel: 'assets/direksiyon_2.png',      category: ItemCategory.aksesuar,basePrice: 750,  kondisyon: 5),
    GameItem(id: 'aksesuar8',name: 'Oyuncu Mausu',         gorsel: 'assets/oyuncumausu.png',       category: ItemCategory.aksesuar,basePrice: 260,  kondisyon: 4),
    // ── v110: kaynak klasörde kalan 10 ekipman (9 konsol + 1 arcade joystick) ──
    // Fiyatlar mevcut konsol aralığına (380-620) oturtuldu; retro LCD'ler ucuz,
    // renkli/neon olanlar pahalı. CD ortalamasına dokunulmadı → oynanabilir
    // ürünlerin "2 kat" dengesi ve onu koruyan test bozulmuyor.
    GameItem(id: 'konsol11', name: 'El Konsolu',           gorsel: 'assets/konsol_11.png',         category: ItemCategory.konsol,  basePrice: 480,  kondisyon: 4),
    GameItem(id: 'konsol12', name: 'El Konsolu',           gorsel: 'assets/konsol_12.png',         category: ItemCategory.konsol,  basePrice: 330,  kondisyon: 2),
    GameItem(id: 'konsol13', name: 'El Konsolu',           gorsel: 'assets/konsol_13.png',         category: ItemCategory.konsol,  basePrice: 290,  kondisyon: 2),
    GameItem(id: 'konsol14', name: 'El Konsolu',           gorsel: 'assets/konsol_14.png',         category: ItemCategory.konsol,  basePrice: 540,  kondisyon: 4),
    GameItem(id: 'konsol15', name: 'Masaüstü Konsol',      gorsel: 'assets/konsol_15.png',         category: ItemCategory.konsol,  basePrice: 360,  kondisyon: 3),
    GameItem(id: 'konsol16', name: 'Masaüstü Konsol',      gorsel: 'assets/konsol_16.png',         category: ItemCategory.konsol,  basePrice: 640,  kondisyon: 5),
    GameItem(id: 'konsol17', name: 'Masaüstü Konsol',      gorsel: 'assets/konsol_17.png',         category: ItemCategory.konsol,  basePrice: 400,  kondisyon: 3),
    GameItem(id: 'konsol18', name: 'El Konsolu',           gorsel: 'assets/konsol_18.png',         category: ItemCategory.konsol,  basePrice: 580,  kondisyon: 4),
    GameItem(id: 'konsol19', name: 'El Konsolu',           gorsel: 'assets/konsol_19.png',         category: ItemCategory.konsol,  basePrice: 700,  kondisyon: 5),
    GameItem(id: 'aksesuar9',name: 'Arcade Joystick',      gorsel: 'assets/joystick.png',          category: ItemCategory.aksesuar,basePrice: 470,  kondisyon: 4),
    // ── v113: 9 yeni ekipman. Adları kullanıcı verdi, marka gibi yazılıyor
    //    (büyük/küçük harfler bilerek böyle: SikstenDo GaMboy, SkeymDeck).
    GameItem(id: 'konsol20', name: 'Masaüstü Konsol',      gorsel: 'assets/konsol_20.png',         category: ItemCategory.konsol,  basePrice: 620,  kondisyon: 5),
    GameItem(id: 'konsol21', name: 'Masaüstü Konsol',      gorsel: 'assets/konsol_21.png',         category: ItemCategory.konsol,  basePrice: 430,  kondisyon: 3),
    GameItem(id: 'konsol22', name: 'Masaüstü Konsol',      gorsel: 'assets/konsol_22.png',         category: ItemCategory.konsol,  basePrice: 510,  kondisyon: 4),
    GameItem(id: 'konsol23', name: 'SikstenDo GaMboy',     gorsel: 'assets/konsol_23.png',         category: ItemCategory.konsol,  basePrice: 340,  kondisyon: 3),
    GameItem(id: 'konsol24', name: 'SkeymDeck',            gorsel: 'assets/konsol_24.png',         category: ItemCategory.konsol,  basePrice: 980,  kondisyon: 5),
    GameItem(id: 'aksesuar10',name: 'Cicitech Mouse',      gorsel: 'assets/cicitechmouse.png',     category: ItemCategory.aksesuar,basePrice: 290,  kondisyon: 4),
    GameItem(id: 'aksesuar11',name: 'Gavrak Oyuncu Tutgacı', gorsel: 'assets/oyuntutgaci.png',    category: ItemCategory.aksesuar,basePrice: 520,  kondisyon: 5),
    GameItem(id: 'aksesuar12',name: 'Şahan Oyuncu Seti',   gorsel: 'assets/sahanoyuncudireksiyon.png', category: ItemCategory.aksesuar,basePrice: 810, kondisyon: 5),
    GameItem(id: 'aksesuar13',name: 'Sonya Kulaklık',      gorsel: 'assets/sonyakulaklik.png',     category: ItemCategory.aksesuar,basePrice: 360,  kondisyon: 4),
  ];

  // 25 slot: index 0-24. Slot bazlı envanter.
  List<GameItem?> slotlar = List.generate(25, (i) {
    if (i == 0) return GameItem(id: 'cd1', name: 'KARMAGEDDON', gorsel: 'assets/CD_1.png', category: ItemCategory.cd, basePrice: 80,  kondisyon: 4);
    if (i == 1) return GameItem(id: 'cd3', name: 'SOKAKSOCCER', gorsel: 'assets/CD_3.png', category: ItemCategory.cd, basePrice: 90,  kondisyon: 5);
    if (i == 2) return GameItem(id: 'cd5', name: 'GTR 7',       gorsel: 'assets/CD_5.png', category: ItemCategory.cd, basePrice: 200, kondisyon: 5);
    return null; // boş veya kilitli
  });

  // Kaç slot açık (dükkan seviyesine göre)
  int get acikSlotSayisi => aktifDukkan.seviye * 5;

  // Stokta satılabilir ürün var mı?
  bool get stokluUrunVar => slotlar.sublist(0, acikSlotSayisi).any((s) => s != null);

  // Stoklu ürünleri listele
  List<GameItem> get stokluUrunler => slotlar.sublist(0, acikSlotSayisi).whereType<GameItem>().toList();

  // Boş slot var mı?
  bool get bosSlotVar => slotlar.sublist(0, acikSlotSayisi).any((s) => s == null);

  // Sessiz ekleme (notify etmez) — toplu işlemlerde çift kayıt olmasın diye
  bool _slotaKoy(GameItem item) {
    for (int i = 0; i < acikSlotSayisi; i++) {
      if (slotlar[i] == null) {
        slotlar[i] = item.kopya();
        return true;
      }
    }
    return false; // doldu
  }

  // Ürün ekle (boş slota koy)
  bool urunEkle(GameItem item) {
    final ok = _slotaKoy(item);
    if (ok) notifyListeners();
    return ok;
  }

  // Slotları öne çek (boşlukları sona it)
  void _slotlariSikistir() {
    final dolu = slotlar.sublist(0, acikSlotSayisi).whereType<GameItem>().toList();
    for (int j = 0; j < acikSlotSayisi; j++) {
      slotlar[j] = j < dolu.length ? dolu[j] : null;
    }
  }

  // Ürün çıkar (ilk eşleşen slottan) ve boşluk bırakmadan dolu slotları öne çek
  bool urunCikar(String itemId) {
    for (int i = 0; i < acikSlotSayisi; i++) {
      if (slotlar[i]?.id == itemId) {
        slotlar[i] = null;
        _slotlariSikistir();
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  /// Belirli bir ÖRNEĞİ çıkarır. Aynı id'den çürük + sağlam iki kopya varsa
  /// yanlışlıkla diğerinin satılmasını engeller.
  bool urunCikarOrnek(GameItem hedef) {
    for (int i = 0; i < acikSlotSayisi; i++) {
      if (identical(slotlar[i], hedef)) {
        slotlar[i] = null; _slotlariSikistir(); notifyListeners(); return true;
      }
    }
    for (int i = 0; i < acikSlotSayisi; i++) {
      final s = slotlar[i];
      if (s != null && s.id == hedef.id && s.curuk == hedef.curuk && s.kondisyon == hedef.kondisyon) {
        slotlar[i] = null; _slotlariSikistir(); notifyListeners(); return true;
      }
    }
    return urunCikar(hedef.id); // son çare
  }

  // ── TOPTANCI ──────────────────────────────────────────────────────────────

  /// Koleksiyon ekranında gösterilecek ürünler (kolonya hariç — o bir sarf malzemesi)
  static List<GameItem> get koleksiyonUrunleri =>
      _baslangicUrunler.where((u) => u.id != 'kolonya').toList();

  /// Kapalı kutu ürünü (envanterde slot işgal eder, açılınca içinden ürün çıkar)
  static GameItem kapaliKutuUret() => GameItem(
    id: 'kapali_kutu', name: 'Kapalı Kutu', gorsel: 'assets/zarf.png',
    category: ItemCategory.aksesuar, basePrice: 300, kondisyon: 3, kapaliKutu: true,
  );

  /// Rıza kapıya geldiğinde stok tazelenir — ziyaretin bonusu budur.
  void toptanciZiyaretiTazele() {
    toptanciStokGunu = 0;
    toptanciStokKontrol();
  }

  /// Günlük stok. Aynı gün içinde tekrar çağrılırsa mevcut stoğu korur.
  void toptanciStokKontrol() {
    if (toptanciStokGunu == gun && toptanciStok.isNotEmpty) return;
    final rng = Random();
    final indirim = (gunlukToptanciIndirim + toptanciKaliciIndirim).clamp(0.0, 0.60);
    final havuz = _baslangicUrunler.where((u) => u.id != 'kolonya' && !u.oynanabilir).toList(); // Kırgeç Rıza'da çıkmaz
    final liste = <ToptanciUrun>[];

    // Her gün 1 tamir seti bulunur (5 kullanımlık)
    liste.add(ToptanciUrun(
      tip: ToptanciTip.tamirSeti,
      fiyat: (450 * (1 - tamirSetiIndirim) * (1 - indirim)).round().clamp(10, 999999),
    ));

    // %70 ihtimalle bir kapalı kutu
    if (rng.nextDouble() < 0.70) {
      liste.add(ToptanciUrun(
        tip: ToptanciTip.kapaliKutu,
        item: kapaliKutuUret(),
        fiyat: (300 * (1 - indirim)).round().clamp(10, 999999),
      ));
    }

    // Kalan tezgâhlar: normal / çürük ürünler
    while (liste.length < toptanciSlotSayisi) {
      final base = havuz[rng.nextInt(havuz.length)];
      if (rng.nextDouble() < 0.40) {
        // Çürük: piyasanın ~%28-40'ı
        final f = base.basePrice * (0.28 + rng.nextDouble() * 0.12) * (1 - indirim) * (1 - curukEkIndirim);
        liste.add(ToptanciUrun(tip: ToptanciTip.curukUrun,
          item: base.kopyaWith(kondisyon: 1, curuk: true), fiyat: f.round().clamp(5, 999999)));
      } else {
        // Sağlam: piyasanın ~%55-75'i
        final kond = toptanciIyiKondisyon ? (4 + rng.nextInt(2)) : (2 + rng.nextInt(4));
        final f = base.basePrice * (0.55 + rng.nextDouble() * 0.20) * (1 - indirim);
        liste.add(ToptanciUrun(tip: ToptanciTip.urun,
          item: base.kopyaWith(kondisyon: kond), fiyat: f.round().clamp(5, 999999)));
      }
    }
    liste.shuffle(rng);
    toptanciStok = liste;
    toptanciStokGunu = gun;
  }

  /// Satın alma. Başarılıysa null, hata varsa mesaj döner.
  String? toptanciSatinAl(int index) {
    if (index < 0 || index >= toptanciStok.length) return 'Ürün bulunamadı.';
    final t = toptanciStok[index];
    if (t.satildi) return 'Bu ürün satıldı.';
    if (para < t.fiyat) return 'Yeterli paran yok!';
    if (t.tip == ToptanciTip.tamirSeti) {
      tamirSetiAdet += 5;
    } else {
      if (!bosSlotVar) return 'Envanter dolu! Önce yer aç.';
      _slotaKoy(t.item!.kopyaWith(maliyet: t.fiyat));
      _hedefIlerlet(HedefTip.toptanciAlim, 1);
    }
    para -= t.fiyat;
    t.satildi = true;
    SesServisi.paraGirdi();
    notifyListeners();
    return null;
  }

  // ── TAMİR ─────────────────────────────────────────────────────────────────

  /// Çürük ürünü tamir eder. 1 tamir seti kullanımı harcar.
  bool tamirEt(int slotIndex) {
    if (tamirSetiAdet <= 0) return false;
    if (slotIndex < 0 || slotIndex >= acikSlotSayisi) return false;
    final item = slotlar[slotIndex];
    if (item == null || !item.curuk) return false;
    slotlar[slotIndex] = item.kopyaWith(curuk: false, kondisyon: 4 + Random().nextInt(2));
    tamirSetiAdet--;
    tamirEdilenSayisi++;
    _hedefIlerlet(HedefTip.tamir, 1);
    SesServisi.tamir();
    notifyListeners();
    return true;
  }

  // ── KAPALI KUTU ───────────────────────────────────────────────────────────

  /// Kutuyu açar, içinden çıkan ürünü aynı slota koyar ve döner.
  GameItem? kutuAc(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= acikSlotSayisi) return null;
    final kutu = slotlar[slotIndex];
    if (kutu == null || !kutu.kapaliKutu) return null;
    final rng = Random();
    final havuz = _baslangicUrunler.where((u) => u.id != 'kolonya' && !u.oynanabilir).toList(); // Kırgeç kutudan çıkmaz
    final base = havuz[rng.nextInt(havuz.length)];
    final curukMu = rng.nextDouble() < kutuCurukSansi;
    final cikan = base.kopyaWith(
      kondisyon: curukMu ? 1 : (2 + rng.nextInt(4)),
      curuk: curukMu,
      maliyet: kutu.maliyet,
    );
    slotlar[slotIndex] = cikan;
    acilanKutuSayisi++;
    _hedefIlerlet(HedefTip.kutu, 1);
    SesServisi.kutuAcildi();
    notifyListeners();
    return cikan;
  }

  /// Fare olayı: envanterdeki rastgele sağlam bir ürünü çürütür.
  GameItem? _rastgeleUrunuCurut() {
    final adaylar = <int>[];
    for (int i = 0; i < acikSlotSayisi; i++) {
      final s = slotlar[i];
      if (s != null && !s.curuk && !s.kapaliKutu) adaylar.add(i);
    }
    if (adaylar.isEmpty) return null;
    final idx = adaylar[Random().nextInt(adaylar.length)];
    final yeni = slotlar[idx]!.kopyaWith(curuk: true, kondisyon: 1);
    slotlar[idx] = yeni;
    return yeni;
  }

  // ── GÜNLÜK HEDEF İLERLEMESİ ───────────────────────────────────────────────

  /// Hedefe ilerleme ekler. [mutlak] true ise en yüksek değer tutulur (tekSatis).
  void _hedefIlerlet(HedefTip tip, int miktar, {bool mutlak = false}) {
    final h = gunlukHedef;
    if (h == null || h.tamamlandi || h.tip != tip) return;
    h.ilerleme = mutlak ? max(h.ilerleme, miktar) : h.ilerleme + miktar;
    if (h.ilerleme >= h.hedef) {
      h.tamamlandi = true;
      para += h.odul;
      hedefYeniTamamlandi = true;
    }
  }

  // ── SERİ (KOMBO) ──────────────────────────────────────────────────────────

  /// Anlaşma tamamlandı → seriyi büyüt, 3'ten itibaren bonus ver.
  void _komboArtir() {
    kombo++;
    if (kombo > enUzunSeri) enUzunSeri = kombo;
    sonKomboBonusu = kombo >= 3 ? kombo * 15 : 0;
    if (sonKomboBonusu > 0) para += sonKomboBonusu;
  }

  /// Müşteri kızıp gitti → seri bozuldu.
  void _komboSifirla() {
    kombo = 0;
    sonKomboBonusu = 0;
  }

  /// Cömert/cimri gün etkisi. Alıcı daha çok öder, satıcı daha az ister.
  double _piyasaEtkisi(double reserv, bool musteriSatiyor) {
    if (piyasaCarpani == 1.0) return reserv;
    return musteriSatiyor ? reserv / piyasaCarpani : reserv * piyasaCarpani;
  }

  static const List<String> _erkekIsimleri = [
    // ── v102: 50 yeni erkek ismi (çeşitlilik) ──
    'Sinan','Devrim','Ferhat','Görkem','Hakan','Işık','Kerem','Mert','Nadir','Oktay',
    'Özgür','Polat','Rüzgar','Sarp','Şahin','Taner','Ulaş','Vedat','Yalçın','Zeki',
    'Atilla','Bülent','Cihat','Çağatay','Demir','Efe','Ferit','Güven','Hikmet','İsmet',
    'Kayhan','Lütfü','Metin','Necmi','Ömür','Poyraz','Rıza','Selçuk','Tayfun','Tuna',
    'Uraz','Ünal','Vural','Yavuz','Zeynel','Alaattin','Bahadır','Cevdet','Dursun','Erdinç',
    'Ahmet','Mehmet','Ali','Mustafa','Ömer','İbrahim','Hüseyin','Hasan','Yusuf','İsmail',
    'Murat','Burak','Emre','Can','Berk','Kaan','Sercan','Arda','Deniz','Furkan',
    'Berkay','Alp','Alperen','Barış','Caner','Doruk','Ege','Eren','Enes','Fatih',
    'Gökhan','Haluk','İlhan','Kadir','Kemal','Koray','Levent','Mahmut','Nail','Okan',
    'Orhan','Ozan','Sabri','Selim','Serhat','Soner','Tahir','Tarık','Tolga','Tuncay',
    'Uğur','Umut','Volkan','Yasin','Yiğit','Zafer','Adem','Adnan','Altan','Aras',
    'Arif','Arman','Aykut','Baran','Bayram','Bilal','Bora','Celal','Cem','Cengiz',
    'Ceyhun','Cihan','Coşkun','Emir','Ercan','Erdem','Ergün','Erhan','Erkan','Ertuğrul',
    'Eyüp','Fırat','Gürkan','Hamit','Harun','İlker','Kağan','Kamil','Kahraman','Kasım',
    'Kaya','Kenan','Korhan','Mesut','Mirza','Nuri','Oğuz','Onur','Rauf','Tamer',
  ];

  static const List<String> _kadinIsimleri = [
    // ── v102: 50 yeni kadın ismi (çeşitlilik) ──
    'Alev','Ceyda','Bengü','Çisem','Ferah','Dilek','Handan','Hayal','Jale','Kader',
    'Lamia','Melis','Nihan','Oya','Öykü','Pelin','Mine','Sena','Şeyma','Papatya',
    'Şirin','Vildan','Yaren','Rengin','Aysel','Berrin','Canan','Çiğdem','Deniz','Esin',
    'Fulya','Gonca','Feride','İnci','Kevser','Leyla','Mercan','Irmak','Nilay','Sıla',
    'Kumsal','Rüya','Nergis','Tansu','Tülay','Ulviye','Vuslat','Yeliz','Zerrin','Afet',
    'Ayşe','Fatma','Zeynep','Emine','Hatice','Elif','Meryem','Büşra','Esra','Merve',
    'Selin','Özge','Duygu','Ebru','Gül','Hande','İpek','Kübra','Lale','Meltem',
    'Neslihan','Nur','Pınar','Reyhan','Seda','Sevgi','Sibel','Tuğçe','Yasemin','Zara',
    'Ahu','Arzu','Aslı','Aylin','Aynur','Banu','Bahar','Berna','Cansu','Ceren',
    'Derya','Didem','Dilara','Ecrin','Ece','Elvan','Emel','Figen','Filiz','Gizem',
    'Gülşen','Güneş','Hülya','İrem','Kamelya','Melike','Mina','Müge','Nazan','Nesrin',
    'Nilüfer','Nisa','Nuray','Özlem','Perihan','Rana','Safiye','Serap','Sevda','Simge',
    'Songül','Şule','Tuba','Yağmur','Zehra','Zeliha','Alize','Almila','Alya','Asena',
    'Ayça','Aydan','Aygün','Bade','Beren','Buse','Damla','Ela','Elçin','Eylül',
    'Gamze','Gönül','Gülay','Hilal','Işıl','Naz','Sevinç','Tuğba','Ülkü','Yıldız',
  ];

  /// 28 karakter. `yas` alanı görsellerden okundu (kontak sayfası ile ölçüldü)
  /// ve repliklerin filtresi bu — "anneme sormadan" repliği artık ak sakallı
  /// amcaya düşmüyor. Kabul edilen değerler: cocuk / genc / yetiskin / yasli.
  final List<Map<String, String>> musteriHavuzu = [
    {'gorsel': 'assets/musteri_1.png',  'cinsiyet': 'E', 'yas': 'genc'},     // kıvırcık saçlı genç, yeşil ceket
    {'gorsel': 'assets/musteri_2.png',  'cinsiyet': 'K', 'yas': 'genc'},     // mor mohawk punk, deri ceket
    {'gorsel': 'assets/musteri_3.png',  'cinsiyet': 'E', 'yas': 'yasli'},    // gri saçlı sakallı bey
    {'gorsel': 'assets/musteri_4.png',  'cinsiyet': 'K', 'yas': 'yasli'},    // beyaz saçlı hanım, teal takım
    {'gorsel': 'assets/musteri_5.png',  'cinsiyet': 'K', 'yas': 'genc'},     // mor dalgalı saçlı genç kadın
    {'gorsel': 'assets/musteri_6.png',  'cinsiyet': 'E', 'yas': 'genc'},     // genç adam, yeşil takım
    {'gorsel': 'assets/musteri_7.png',  'cinsiyet': 'K', 'yas': 'yetiskin'}, // sarışın kadın, kahve kazak
    {'gorsel': 'assets/musteri_8.png',  'cinsiyet': 'K', 'yas': 'genc'},     // sarışın genç, krem elbise
    {'gorsel': 'assets/musteri_9.png',  'cinsiyet': 'K', 'yas': 'genc'},     // topuzlu genç, pembe ceket
    {'gorsel': 'assets/musteri_10.png', 'cinsiyet': 'K', 'yas': 'yetiskin'}, // kızıl saçlı, yeşil kazak
    {'gorsel': 'assets/musteri_11.png', 'cinsiyet': 'E', 'yas': 'genc'},     // şapkalı delikanlı, tişört
    // ── 17 yeni karakter (v103) — görseller kullanıcının kendi kesimi ──
    // NOT: v102'de 18 karakter vardı. Yeni kaynak klasörde bir dosya tekrardı
    // (md5 aynı) ve "kot ceket / hardal etek" karakteri yoktu → 29. slot düştü.
    {'gorsel': 'assets/musteri_12.png', 'cinsiyet': 'E', 'yas': 'yetiskin'}, // bıyıklı orta yaşlı, hawaii gömlek
    {'gorsel': 'assets/musteri_13.png', 'cinsiyet': 'E', 'yas': 'yasli'},    // beyaz saçlı bey, uzun palto
    {'gorsel': 'assets/musteri_14.png', 'cinsiyet': 'E', 'yas': 'yetiskin'}, // kel sakallı, mor bomber ceket
    {'gorsel': 'assets/musteri_15.png', 'cinsiyet': 'K', 'yas': 'yasli'},    // yaşlı teyze, sarı hırka ve gözlük
    {'gorsel': 'assets/musteri_16.png', 'cinsiyet': 'E', 'yas': 'yasli'},    // beyaz bıyıklı amca, yelek
    {'gorsel': 'assets/musteri_17.png', 'cinsiyet': 'E', 'yas': 'genc'},     // genç adam, krem ceket
    {'gorsel': 'assets/musteri_18.png', 'cinsiyet': 'K', 'yas': 'genc'},     // kızıl örgülü, bahçıvan tulumu
    {'gorsel': 'assets/musteri_19.png', 'cinsiyet': 'E', 'yas': 'genc'},     // genç adam, haki ceket
    {'gorsel': 'assets/musteri_20.png', 'cinsiyet': 'K', 'yas': 'yasli'},    // yaşlı hanım, mor palto ve çanta
    {'gorsel': 'assets/musteri_21.png', 'cinsiyet': 'K', 'yas': 'yetiskin'}, // kıvırcık saçlı, turuncu bluz
    {'gorsel': 'assets/musteri_22.png', 'cinsiyet': 'K', 'yas': 'genc'},     // punk, mor mohawk
    {'gorsel': 'assets/musteri_23.png', 'cinsiyet': 'E', 'yas': 'yetiskin'}, // sakallı, yelek ve gömlek
    {'gorsel': 'assets/musteri_24.png', 'cinsiyet': 'K', 'yas': 'genc'},     // renkli saçlı genç
    {'gorsel': 'assets/musteri_25.png', 'cinsiyet': 'E', 'yas': 'genc'},     // takım elbiseli genç
    {'gorsel': 'assets/musteri_26.png', 'cinsiyet': 'E', 'yas': 'cocuk'},    // erkek çocuk, mavi kazak
    {'gorsel': 'assets/musteri_27.png', 'cinsiyet': 'K', 'yas': 'cocuk'},    // kız çocuk, okul üniforması
    {'gorsel': 'assets/musteri_28.png', 'cinsiyet': 'E', 'yas': 'yetiskin'}, // atletik, kolsuz tişört
    // v110 — kaynak klasörde işlenmemiş kalan 6 kesim. Ölçüldü: hepsi 500×500,
    // doluluk 0.95-0.966, alt boşluk 10-15px → mevcut kadroyla birebir uyumlu,
    // yeniden ölçekleme YAPILMADI.
    {'gorsel': 'assets/musteri_29.png', 'cinsiyet': 'E', 'yas': 'genc'},     // genç adam, haki gömlek + kargo pantolon
    {'gorsel': 'assets/musteri_30.png', 'cinsiyet': 'K', 'yas': 'genc'},     // kızıl saçlı, kot ceket
    {'gorsel': 'assets/musteri_31.png', 'cinsiyet': 'K', 'yas': 'yetiskin'}, // topuzlu, krem askılı ve şort
    {'gorsel': 'assets/musteri_32.png', 'cinsiyet': 'K', 'yas': 'genc'},     // "GRRR!" tişört, mor kargo
    {'gorsel': 'assets/musteri_33.png', 'cinsiyet': 'K', 'yas': 'genc'},     // sarışın, pembe şort ve çiçekli çanta
    {'gorsel': 'assets/musteri_34.png', 'cinsiyet': 'K', 'yas': 'yetiskin'}, // sarı bandana, çiçekli gömlek
    // v112 — 8 yeni kesim. Ölçüldü: hepsi 500×500, doluluk 0.914-0.976,
    // alt boşluk 7-17px → mevcut kadroyla uyumlu, olduğu gibi kopyalandı.
    {'gorsel': 'assets/musteri_35.png', 'cinsiyet': 'K', 'yas': 'genc'},     // kızıl örgülü, hardal hırka
    {'gorsel': 'assets/musteri_36.png', 'cinsiyet': 'E', 'yas': 'cocuk'},    // erkek çocuk, basketbol forması
    {'gorsel': 'assets/musteri_37.png', 'cinsiyet': 'E', 'yas': 'genc'},     // rocker, siyah deri ceket
    {'gorsel': 'assets/musteri_38.png', 'cinsiyet': 'E', 'yas': 'genc'},     // at kuyruklu, kahve gömlek
    {'gorsel': 'assets/musteri_39.png', 'cinsiyet': 'E', 'yas': 'yetiskin'}, // gözlüklü, papyonlu takım elbise
    {'gorsel': 'assets/musteri_40.png', 'cinsiyet': 'K', 'yas': 'genc'},     // sarışın örgülü, kargo pantolon
    {'gorsel': 'assets/musteri_41.png', 'cinsiyet': 'E', 'yas': 'yasli'},    // kasketli amca, yelek
    {'gorsel': 'assets/musteri_42.png', 'cinsiyet': 'K', 'yas': 'yasli'},    // başörtülü teyze, yeşil hırka
    // ── SABİT ADLI KARAKTERLER ──
    // 'ad' dolu olduğu için rastgele isim havuzundan isim ÇEKİLMEZ; bu kişiler
    // her gelişlerinde aynı adla tanınır ("Merhaba, ben Kahraman Memo").
    {'gorsel': 'assets/musteri_43.png', 'cinsiyet': 'E', 'yas': 'yetiskin', 'ad': 'Recai Carlos'},   // futbolcu, sarı forma
    {'gorsel': 'assets/musteri_44.png', 'cinsiyet': 'E', 'yas': 'cocuk',    'ad': 'Kahraman Memo'},  // çocuk süper kahraman
    {'gorsel': 'assets/musteri_45.png', 'cinsiyet': 'E', 'yas': 'yetiskin', 'ad': 'Şakir Oneyıl'},   // basketbolcu, mor forma
    {'gorsel': 'assets/musteri_46.png', 'cinsiyet': 'E', 'yas': 'yetiskin'},                          // takım elbiseli bey
  ];
  List<int> _musteriSira = [];

  GameState() {
    gunlukMusteriLimiti = aktifDukkan.gunlukMusteriSayisiUret();
    _ozelTipSirasi.shuffle(Random());
    _ozelMusteriSayaciniAyarla();
    _rizaGunuAyarla();
    gunlukHedef = GunlukHedef.uret(1);
  }

  GameState.fromJson(Map<String, dynamic> j) {
    para = j['para'] as int;
    gun = j['gun'] as int;
    musteriSayisi = j['musteriSayisi'] as int;
    gunlukMusteriSayisi = j['gunlukMusteriSayisi'] as int;
    gunlukMusteriLimiti = j['gunlukMusteriLimiti'] as int;
    // ⚠️ Dükkan artık İSİMLE saklanıyor: satılık dükkanlar kiralıklarla aynı
    // `seviye` değerini paylaşabiliyor, sıra/seviye indeksi tek başına yetmez.
    // Eski kayıtlarda sadece `aktifDukkanSeviye` var — ona düşülür.
    final dukkanIsim = j['aktifDukkanIsim'] as String?;
    if (dukkanIsim != null) {
      aktifDukkan = butunDukkanlar.firstWhere((d) => d.isim == dukkanIsim,
          orElse: () => tumDukkanlar[0]);
    } else {
      final sv = (j['aktifDukkanSeviye'] as int).clamp(1, tumDukkanlar.length);
      aktifDukkan = tumDukkanlar[sv - 1];
    }
    handeGosterildi = j['handeGosterildi'] as bool? ?? true; // eski kayitlar tanitimi gormus sayilir
    guvenlikVar = j['guvenlikVar'] as bool? ?? false;
    guvenlikSonTeklifGunu = j['guvenlikSonTeklifGunu'] as int? ?? 0;
    sahipDukkanlar = ((j['sahipDukkanlar'] as List?) ?? const [])
        .map((e) => e as String).toSet();
    kirayaVerilenDukkanlar = ((j['kirayaVerilenDukkanlar'] as List?) ?? const [])
        .map((e) => e as String).toSet();
    final raw = j['slotlar'] as List;
    slotlar = List.generate(25, (i) => raw[i] != null ? GameItem.fromJson(raw[i] as Map<String, dynamic>) : null);
    _sonrakiOzelMusteriSayisi = j['sonrakiOzelMusteri'] as int;
    _ozelMusteriSayaci = j['ozelSayac'] as int;
    final rawSira = j['ozelTipSirasi'] as List?;
    if (rawSira != null) {
      _ozelTipSirasi = rawSira.map((s) => OzelMusteriTip.values.firstWhere((e) => e.name == s as String, orElse: () => OzelMusteriTip.hirsiz)).toList();
    }
    // Eski kayıt migrasyonu: eksik "olay" tipleri sıraya ekle
    for (final tip in OzelMusteriTip.values) {
      // Rıza, Güvenlik, Gürbüz ve Hande rotasyonda DEĞİL — hepsinin kendi
      // programı var (Rıza gün bazlı, Güvenlik 3'ün katlarında tek teklif,
      // Gürbüz 3 günde bir, Hande yalnız oyunun başında bir kez).
      if (_rotasyonDisi.contains(tip)) continue;
      if (!_ozelTipSirasi.contains(tip)) _ozelTipSirasi.add(tip);
    }
    // Rotasyona sızmışlarsa çıkar (ara sürüm kayıtları için)
    _ozelTipSirasi.removeWhere(_rotasyonDisi.contains);
    _ozelTipIndex = j['ozelTipIndex'] as int;
    // Falcı kehaneti kayıtta bekliyor olabilir (fal bakıldı, müşteri gelmedi)
    final zorunlu = j['zorunluOzelTip'] as String?;
    zorunluOzelTip = zorunlu == null
        ? null
        : OzelMusteriTip.values.where((e) => e.name == zorunlu).firstOrNull;
    toplamTeklifSayisi = j['toplamTeklif'] as int;
    krediKalanTaksit = (j['krediKalanTaksit'] as int?) ?? 0;
    krediTaksitMiktar = (j['krediTaksitMiktar'] as int?) ?? 0;
    tamamlananKrediSayisi = (j['tamamlananKrediSayisi'] as int?) ?? 0;
    imacSatinAlindi = (j['imacSatinAlindi'] as bool?) ?? false;
    kolonyaKullanim = (j['kolonyaKullanim'] as int?) ?? 0;
    // Eski kayıt migrasyonu: kolonya slotta idiyse çıkar, kullanım hakkını koru
    for (int i = 0; i < slotlar.length; i++) {
      if (slotlar[i]?.id == 'kolonya') {
        slotlar[i] = null;
        if (kolonyaKullanim == 0) kolonyaKullanim = 10; // eski kayıt: kullanim yoksa 10 ver
      }
    }
    // Kompaksiyon (slotlardaki boşlukları öne çek)
    final _acik = (j['aktifDukkanSeviye'] as int) * 5;
    final _dolu2 = slotlar.sublist(0, _acik).whereType<GameItem>().toList();
    for (int i = 0; i < _acik; i++) slotlar[i] = i < _dolu2.length ? _dolu2[i] : null;
    // ── Yeni alanlar (eski kayıtlarda yoksa güvenli varsayılan) ──
    tamirSetiAdet          = (j['tamirSetiAdet'] as int?) ?? 0;
    yemekVar               = (j['yemekVar'] as bool?) ?? false;
    bugunOynananOyunlar    = ((j['bugunOynananOyunlar'] as List?) ?? const []).map((e) => e as String).toSet();
    toptanciStokGunu       = (j['toptanciStokGunu'] as int?) ?? 0;
    final rawStok          = j['toptanciStok'] as List?;
    toptanciStok           = rawStok == null ? [] :
        rawStok.map((e) => ToptanciUrun.fromJson(e as Map<String, dynamic>)).toList();
    gunlukOlayId           = j['gunlukOlayId'] as String?;
    piyasaCarpani          = (j['piyasaCarpani'] as num?)?.toDouble() ?? 1.0;
    gunlukToptanciIndirim  = (j['gunlukToptanciIndirim'] as num?)?.toDouble() ?? 0.0;
    toplamSatis            = (j['toplamSatis'] as int?) ?? 0;
    tamirEdilenSayisi      = (j['tamirEdilenSayisi'] as int?) ?? 0;
    acilanKutuSayisi       = (j['acilanKutuSayisi'] as int?) ?? 0;
    basariliPazarlik       = (j['basariliPazarlik'] as int?) ?? 0;
    enYuksekPara           = (j['enYuksekPara'] as int?) ?? para;
    satilanUrunIdleri      = ((j['satilanUrunIdleri'] as List?) ?? []).map((e) => e as String).toSet();
    koleksiyondakiler      = ((j['koleksiyondakiler'] as List?) ?? []).map((e) => e as String).toSet();
    koleksiyonOdulAlinan   = ((j['koleksiyonOdulAlinan'] as List?) ?? []).map((e) => e as String).toSet();
    kazanilanRozetler      = ((j['kazanilanRozetler'] as List?) ?? []).map((e) => e as String).toSet();
    _rizaBugunGeldi        = (j['rizaBugunGeldi'] as bool?) ?? false;
    _galericiBugunGeldi    = (j['galericiBugunGeldi'] as bool?) ?? false;
    evSahibi               = (j['evSahibi'] as bool?) ?? false;
    yazlikSahibi           = (j['yazlikSahibi'] as bool?) ?? false;
    evEsyalari             = ((j['evEsyalari'] as List?) ?? []).map((e) => e as String).toSet();
    // ⚠️ Kayıt her zaman DÜKKANDA açılır: geçiş yolculuğu oturum içi bir
    // durum, oyunu evde kapatıp açan biri dükkanına dönmüş sayılır.
    aktifKonum = Konum.dukkan;
    _rizaZiyaretSirasi     = (j['rizaZiyaretSirasi'] as int?) ?? 2;
    yarinkiOlayId          = j['yarinkiOlayId'] as String?;
    kombo                  = (j['kombo'] as int?) ?? 0;
    enUzunSeri             = (j['enUzunSeri'] as int?) ?? 0;
    final rawHedef         = j['gunlukHedef'] as Map<String, dynamic>?;
    gunlukHedef = rawHedef != null
        ? GunlukHedef.fromJson(rawHedef)
        : GunlukHedef.uret(aktifDukkan.seviye); // eski kayıt → bugüne hedef üret
    mesaj = '$gun. gün devam ediyor...';
  }

  Map<String, dynamic> toJson() => {
    'para': para,
    'gun': gun,
    'musteriSayisi': musteriSayisi,
    'gunlukMusteriSayisi': gunlukMusteriSayisi,
    'gunlukMusteriLimiti': gunlukMusteriLimiti,
    'aktifDukkanSeviye': aktifDukkan.seviye, // eski sürümler için bırakıldı
    'aktifDukkanIsim': aktifDukkan.isim,
    'handeGosterildi': handeGosterildi,
    'guvenlikVar': guvenlikVar,
    'guvenlikSonTeklifGunu': guvenlikSonTeklifGunu,
    'sahipDukkanlar': sahipDukkanlar.toList(),
    'kirayaVerilenDukkanlar': kirayaVerilenDukkanlar.toList(),
    'slotlar': slotlar.map((s) => s?.toJson()).toList(),
    'sonrakiOzelMusteri': _sonrakiOzelMusteriSayisi,
    'ozelSayac': _ozelMusteriSayaci,
    'ozelTipSirasi': _ozelTipSirasi.map((t) => t.name).toList(),
    'ozelTipIndex': _ozelTipIndex,
    'zorunluOzelTip': zorunluOzelTip?.name,
    'toplamTeklif': toplamTeklifSayisi,
    'krediKalanTaksit': krediKalanTaksit,
    'krediTaksitMiktar': krediTaksitMiktar,
    'tamamlananKrediSayisi': tamamlananKrediSayisi,
    'imacSatinAlindi': imacSatinAlindi,
    'kolonyaKullanim': kolonyaKullanim,
    'tamirSetiAdet': tamirSetiAdet,
    'yemekVar': yemekVar,
    'bugunOynananOyunlar': bugunOynananOyunlar.toList(),
    'toptanciStok': toptanciStok.map((t) => t.toJson()).toList(),
    'toptanciStokGunu': toptanciStokGunu,
    'gunlukOlayId': gunlukOlayId,
    'piyasaCarpani': piyasaCarpani,
    'gunlukToptanciIndirim': gunlukToptanciIndirim,
    'toplamSatis': toplamSatis,
    'tamirEdilenSayisi': tamirEdilenSayisi,
    'acilanKutuSayisi': acilanKutuSayisi,
    'basariliPazarlik': basariliPazarlik,
    'enYuksekPara': enYuksekPara,
    'satilanUrunIdleri': satilanUrunIdleri.toList(),
    'koleksiyondakiler': koleksiyondakiler.toList(),
    'koleksiyonOdulAlinan': koleksiyonOdulAlinan.toList(),
    'kazanilanRozetler': kazanilanRozetler.toList(),
    'rizaBugunGeldi': _rizaBugunGeldi,
    'galericiBugunGeldi': _galericiBugunGeldi,
    'evSahibi': evSahibi,
    'yazlikSahibi': yazlikSahibi,
    'evEsyalari': evEsyalari.toList(),
    'aktifKonum': aktifKonum.name,
    'rizaZiyaretSirasi': _rizaZiyaretSirasi,
    'yarinkiOlayId': yarinkiOlayId,
    'kombo': kombo,
    'enUzunSeri': enUzunSeri,
    if (gunlukHedef != null) 'gunlukHedef': gunlukHedef!.toJson(),
  };

  @override
  void notifyListeners() {
    if (para > enYuksekPara) enYuksekPara = para;
    _rozetleriDenetle(); // kendisi notify çağırmaz — döngü yok
    super.notifyListeners();
    KayitServisi.kaydet(this); // fire-and-forget auto-save
  }

  bool get gunBitmeli => gunlukMusteriSayisi >= gunlukMusteriLimiti && aktifMusteri == null && aktifOzelMusteri == null;
  bool get oyunBitti => para <= 0 && !stokluUrunVar;

  void dukkanDegistir(DukkanSeviye yeniDukkan) {
    aktifDukkan = yeniDukkan;
    // Taşınılan dükkan kiraya verilmiş olamaz — oyuncu kendi oturduğu yeri
    // kiracıya bırakamaz.
    kirayaVerilenDukkanlar.remove(yeniDukkan.isim);
    notifyListeners();
  }

  // ── YAKIŞIKLI GÜVENLİK ────────────────────────────────────────────────────

  void guvenligiIseAl() {
    guvenlikVar = true;
    notifyListeners();
  }

  void guvenligiIstenCikar() {
    guvenlikVar = false;
    notifyListeners();
  }

  /// Dükkandaki güvenliğe tıklandı — müşteri gibi öne gelip istifayı sorar.
  /// Müşteri sayacına DOKUNMAZ: bu bir ziyaret değil, oyuncunun kendi eylemi;
  /// günlük müşteri hakkını tüketmesi haksızlık olur.
  void guvenligiOneCagir() {
    if (!guvenlikVar) return;
    _guvenlikOnde = true; // arka plandaki kopyası silinsin, iki güvenlik olmasın
    aktifOzelMusteri = OzelMusteri.guvenlikIstifa();
    ozelMusteriGorunuyor = true;
    musteriKabulBekliyor = true;
    mesaj = aktifOzelMusteri!.ilkMesaj;
    notifyListeners();
  }

  // ── SATILIK DÜKKANLAR ─────────────────────────────────────────────────────

  bool dukkanSahibiMi(DukkanSeviye d) => sahipDukkanlar.contains(d.isim);

  /// Satın alma. Başarılıysa null, değilse hata metni döner.
  /// Satın alınan dükkana OTOMATİK geçilmez — oyuncu isterse geçer, isterse
  /// kiraya verir (ikinci dükkan senaryosu).
  String? dukkanSatinAl(DukkanSeviye d) {
    if (!d.satilik) return 'Bu dükkan satılık değil.';
    if (dukkanSahibiMi(d)) return 'Bu dükkan zaten senin.';
    if (gun < d.minGun) return '${d.minGun}. günden önce satılık dükkan alınamaz.';
    final fiyat = d.satinAlmaFiyati!;
    if (para < fiyat) return 'Yeterli paran yok! ($fiyat lira gerekli)';
    para -= fiyat;
    sahipDukkanlar.add(d.isim);
    SesServisi.paraGirdi();
    notifyListeners();
    return null;
  }

  /// Sahip olunan bir dükkanı kiraya ver / kiradan çek.
  void kirayaVerToggle(DukkanSeviye d) {
    if (!dukkanSahibiMi(d)) return;
    if (d.isim == aktifDukkan.isim) return; // oturduğun yeri kiraya veremezsin
    if (kirayaVerilenDukkanlar.contains(d.isim)) {
      kirayaVerilenDukkanlar.remove(d.isim);
    } else {
      kirayaVerilenDukkanlar.add(d.isim);
    }
    notifyListeners();
  }

  /// Falın etkisini uygular. `satir` null ise fal sadece hikâyeydi ve ekstra
  /// bir sonuç şeridi gösterilmez; `miktar` fal metnindeki `{X}` için kullanılır.
  ///
  /// ⚠️ Burada `notifyListeners()` ÇAĞRILMAZ — çağıran taraf falı gösterdikten
  /// sonra tek seferde bildirir, popup açıkken ekran zıplamasın.
  FalSonuc falUygula(Fal fal) {
    final rng = Random();
    int miktar = fal.max > fal.min ? fal.min + rng.nextInt(fal.max - fal.min + 1) : fal.min;
    switch (fal.etki) {
      case FalEtki.yok:
        return const FalSonuc(null, 0);

      case FalEtki.paraKazanc:
        para += miktar;
        return FalSonuc('💰 Kasana $miktar lira girdi!', miktar);

      case FalEtki.paraKayip:
        // Parayı eksiye düşürme — iflas falcı yüzünden olmasın.
        if (miktar > para) miktar = para;
        if (miktar <= 0) return const FalSonuc('💨 Kaybedecek paran bile yokmuş. Bu sefer ucuz atlattın.', 0);
        para -= miktar;
        return FalSonuc('💸 $miktar lira kaybettin!', miktar);

      case FalEtki.dukkanBuyut:
        if (aktifDukkan.seviye >= tumDukkanlar.length) {
          // Zaten en büyük dükkandayız — kehanet boşa gitmesin, paraya çevir.
          para += 500;
          return const FalSonuc('🏠 Daha büyüğü yok! Faloya özür diledi, 500 lira bıraktı.', 500);
        }
        final yeni = tumDukkanlar[aktifDukkan.seviye]; // seviye 1-tabanlı → sonraki
        aktifDukkan = yeni;
        _slotlariSikistir();
        return FalSonuc('🏠 Bedava taşındın: ${yeni.isim}!', yeni.seviye);

      case FalEtki.kolonyaHediye:
        kolonyaKullanim += 10;
        return const FalSonuc('🧴 10 kullanımlık kolonya hediye!', 10);

      case FalEtki.tamirSeti:
        tamirSetiAdet += 2;
        return const FalSonuc('🔧 2 tamir seti hediye!', 2);

      case FalEtki.kapaliKutu:
        if (_slotaKoy(kapaliKutuUret())) return const FalSonuc('🎁 Envanterine kapalı kutu kondu!', 1);
        return const FalSonuc('🎁 Kutu getirmişti ama envanterin dolu. Faloya kutuyu geri aldı.', 0);

      case FalEtki.urunCuruk:
        final adaylar = <int>[];
        for (int i = 0; i < acikSlotSayisi; i++) {
          final u = slotlar[i];
          if (u != null && !u.curuk && !u.kapaliKutu) adaylar.add(i);
        }
        if (adaylar.isEmpty) return const FalSonuc('🍀 Bozulacak malın yokmuş. Kehanet boşa çıktı.', 0);
        final i = adaylar[rng.nextInt(adaylar.length)];
        slotlar[i] = slotlar[i]!.kopyaWith(curuk: true);
        return FalSonuc('🐀 ${slotlar[i]!.name} çürüdü!', 1);

      case FalEtki.kuryeSansi:
        kuryeBonusuAktif = true;
        return const FalSonuc('🍀 Sıradaki müşteri çok cömert olacak!', 0);

      // Kehanetler: sonuç şeridi YOK — sürpriz bozulmasın, kapıyı kendisi çalsın.
      case FalEtki.vergiciGelecek:
        zorunluOzelTip = OzelMusteriTip.vergici;
        return const FalSonuc(null, 0);
      case FalEtki.hirsizGelecek:
        zorunluOzelTip = OzelMusteriTip.hirsiz;
        return const FalSonuc(null, 0);
      case FalEtki.polisGelecek:
        zorunluOzelTip = OzelMusteriTip.polis;
        return const FalSonuc(null, 0);
      case FalEtki.kuryeGelecek:
        zorunluOzelTip = OzelMusteriTip.kurye;
        return const FalSonuc(null, 0);
      case FalEtki.toptanciGelecek:
        zorunluOzelTip = OzelMusteriTip.toptanci;
        return const FalSonuc(null, 0);
    }
  }

  /// Yakışıklı Güvenlik bugün teklife gelmeli mi?
  ///
  /// 3. günde BİR KEZ gelir. Oyuncu HAYIR derse bir sonraki denemesi 3'ün
  /// katlarında (6, 9, 12...) olur. Zaten çalışıyorsa bir daha gelmez.
  bool get _guvenlikTeklifiZamani =>
      !guvenlikVar && gun >= 3 && gun % 3 == 0 && guvenlikSonTeklifGunu != gun;

  void yeniMusteriGonder() {
    _ozelMusteriSayaci++;
    // Yakışıklı Güvenlik: gün başına en fazla bir teklif, rotasyondan bağımsız.
    if (_guvenlikTeklifiZamani && gunlukMusteriSayisi >= 2) {
      guvenlikSonTeklifGunu = gun;
      aktifOzelMusteri = OzelMusteri.olustur(OzelMusteriTip.guvenlik);
      ozelMusteriGorunuyor = true;
      musteriKabulBekliyor = true;
      musteriSayisi++;
      gunlukMusteriSayisi++;
      mesaj = aktifOzelMusteri!.ilkMesaj;
      notifyListeners();
      return;
    }
    // 🚗 Galerici Gürbüz — 3 günde bir, günün 2. müşterisi.
    if (_galericiZamani && gunlukMusteriSayisi >= 2) {
      _galericiBugunGeldi = true;
      aktifOzelMusteri = OzelMusteri.galerici();
      ozelMusteriGorunuyor = true;
      musteriKabulBekliyor = true;
      musteriSayisi++;
      gunlukMusteriSayisi++;
      mesaj = aktifOzelMusteri!.ilkMesaj;
      notifyListeners();
      return;
    }
    // Toptancı Rıza günde bir uğrar (özel müşteri rotasyonundan bağımsız)
    if (!_rizaBugunGeldi && gunlukMusteriSayisi >= _rizaZiyaretSirasi) {
      _rizaBugunGeldi = true;
      aktifOzelMusteri = OzelMusteri.olustur(OzelMusteriTip.toptanci);
      ozelMusteriGorunuyor = true;
      musteriKabulBekliyor = true;
      musteriSayisi++;
      gunlukMusteriSayisi++;
      mesaj = aktifOzelMusteri!.ilkMesaj;
      notifyListeners();
      return;
    }
    // Falcı kehaneti bekliyorsa sıradaki müşteri O — sayaç beklemeden gelir.
    // 🛡️ Güvenlik varken "hırsız gelecek" kehaneti de tutmaz: kehanet
    // tüketilir ama hırsız içeri alınmaz, sıradan müşteri gelir.
    if (zorunluOzelTip == OzelMusteriTip.hirsiz && guvenlikVar) {
      zorunluOzelTip = null;
    }
    if (zorunluOzelTip != null) {
      final tip = zorunluOzelTip!;
      zorunluOzelTip = null;
      aktifOzelMusteri = OzelMusteri.olustur(tip);
      ozelMusteriGorunuyor = true;
      musteriKabulBekliyor = true;
      musteriSayisi++;
      gunlukMusteriSayisi++;
      mesaj = aktifOzelMusteri!.ilkMesaj;
      notifyListeners();
      return;
    }
    // Özel müşteri vakti mi?
    if (_ozelMusteriSayaci >= _sonrakiOzelMusteriSayisi) {
      var tip = _ozelTipSirasi[_ozelTipIndex % _ozelTipSirasi.length];
      _ozelTipIndex++;
      // 🛡️ Güvenlik çalışıyorsa HIRSIZ dükkana giremez. Sıra hırsıza
      // geldiyse rotasyonda ilerleyip başka bir tip seçilir (tur atmayı
      // önlemek için en fazla liste uzunluğu kadar denenir).
      if (guvenlikVar && tip == OzelMusteriTip.hirsiz) {
        for (int i = 0; i < _ozelTipSirasi.length; i++) {
          final aday = _ozelTipSirasi[_ozelTipIndex % _ozelTipSirasi.length];
          _ozelTipIndex++;
          if (aday != OzelMusteriTip.hirsiz) { tip = aday; break; }
        }
        // Hepsi hırsızsa (olmamalı) normal müşteriye düş
        if (tip == OzelMusteriTip.hirsiz) {
          _ozelMusteriSayaciniAyarla();
          tip = OzelMusteriTip.polis;
        }
      }
      aktifOzelMusteri = OzelMusteri.olustur(tip);
      ozelMusteriGorunuyor = true;
      musteriKabulBekliyor = true;
      musteriSayisi++;
      gunlukMusteriSayisi++;
      mesaj = aktifOzelMusteri!.ilkMesaj;
      _ozelMusteriSayaciniAyarla();
      notifyListeners();
      return;
    }
    final rng = Random();
    if (_musteriSira.isEmpty) {
      _musteriSira = List.generate(musteriHavuzu.length, (i) => i)..shuffle(rng);
    }
    final musteriIndex = _musteriSira.removeLast();
    final secilen = musteriHavuzu[musteriIndex];
    final gorsel = secilen['gorsel']!;
    final cinsiyet = secilen['cinsiyet']!;
    final yas = yasGrubuCoz(secilen['yas']);
    // Bazı karakterlerin SABİT adı var (havuzda 'ad' alanı dolu). Onlara
    // rastgele isim verilmez — hep aynı kişi olarak tanınırlar.
    final isimListesi = cinsiyet == 'E' ? _erkekIsimleri : _kadinIsimleri;
    final isim = secilen['ad'] ?? isimListesi[rng.nextInt(isimListesi.length)];
    final musteriSatiyor = rng.nextBool();
    final ozellik = MusteriOzellik.random();

    GameItem? secilenUrun;
    if (!musteriSatiyor) {
      // Kolonya ve açılmamış kapalı kutu satılamaz — listeden çıkar
      final mevcut = stokluUrunler.where((u) => u.id != 'kolonya' && !u.kapaliKutu).toList();
      if (mevcut.isEmpty) {
        mesaj = '$isim geldi ama satılacak ürün yok!';
        notifyListeners();
        return;
      }
      // Ardışık aynı ürün engeli: bir önceki ürün havuzdan çıkar (birden fazla varsa)
      final adaylar0 = mevcut.where((u) => !_sonUrunIdleri.contains(u.id)).toList();
      final adaylar = adaylar0.isNotEmpty ? adaylar0
          : (mevcut.length > 1 ? mevcut.where((u) => u.id != _sonUrunId).toList() : mevcut);
      secilenUrun = adaylar[rng.nextInt(adaylar.length)];
    } else {
      // Kolonya zaten varsa tekrar kolonya satan müşteri gelmesin
      final tumHavuz = kolonyaKullanim > 0
          ? _baslangicUrunler.where((u) => u.id != 'kolonya').toList()
          : _baslangicUrunler.toList();
      // Ardışık aynı ürün engeli: bir önceki ürün havuzdan çıkar (birden fazla varsa)
      final havuz0 = tumHavuz.where((u) => !_sonUrunIdleri.contains(u.id)).toList();
      final satisHavuzu = havuz0.isNotEmpty ? havuz0
          : (tumHavuz.length > 1 ? tumHavuz.where((u) => u.id != _sonUrunId).toList() : tumHavuz);
      final normaller = satisHavuzu.where((u) => !u.oynanabilir).toList();
      // Oynanabilir ürünler GÜNDE EN FAZLA BİR KEZ gelir; ayrıca dün gelen
      // oyun bugün gelmez. Sadece nadirlik yüzdesine bırakılsaydı bazı günler
      // üst üste, bazı günler hiç gelmiyordu.
      final nadirler = satisHavuzu.where((u) =>
          u.oynanabilir && !_bugunOynanabilirGeldi && u.id != _dunGelenOynanabilirId).toList();
      final nadirSecildi = nadirler.isNotEmpty && normaller.isNotEmpty && rng.nextInt(100) < 10;
      secilenUrun = nadirSecildi
          ? nadirler[rng.nextInt(nadirler.length)]
          : (normaller.isNotEmpty ? normaller[rng.nextInt(normaller.length)] : satisHavuzu[rng.nextInt(satisHavuzu.length)]);
      if (nadirSecildi) {
        _bugunOynanabilirGeldi = true;
        _bugunGelenOynanabilirId = secilenUrun.id;
      }
      // Getirdiği mal 1/3 ihtimalle hasarlı olur. Toptancı hurdasından (%35)
      // daha değerli: piyasanın %50-75'i. Kolonya hasarlı gelmez.
      if (secilenUrun.id != 'kolonya' && rng.nextInt(3) == 0) {
        secilenUrun = secilenUrun.kopyaWith(
          curuk: true,
          kondisyon: 1 + rng.nextInt(2),
          curukOran: 0.50 + rng.nextDouble() * 0.25,
        );
      }
    }
    _sonUrunKaydet(secilenUrun.id); // sonraki turlarda bu ürün hariç tutulur

    // Yeni model: perceivedValue → reservationPrice → openingOffer
    // etkinFiyat: çürük üründe piyasa değeri %35'e düşer
    final fiyat  = secilenUrun.etkinFiyat;
    final pv     = ozellik.perceivedValue(secilenUrun.kondisyon, fiyat);
    final reserv = _piyasaEtkisi(ozellik.reservationPrice(pv, fiyat, musteriSatiyor), musteriSatiyor);
    final openingRaw = ozellik.openingOffer(reserv, fiyat, musteriSatiyor);
    final ilkTeklif  = openingRaw.round();

    aktifMusteri = Customer(name: isim, gorsel: gorsel, musteriSatiyor: musteriSatiyor, item: secilenUrun, ilkTeklif: ilkTeklif, ozellik: ozellik, yas: yas, cinsiyet: cinsiyet);
    musteriGorunuyor = true;
    musteriKabulBekliyor = true;
    musteriSayisi++;
    gunlukMusteriSayisi++;
    mesaj = aktifMusteri!.selamMesaji;
    notifyListeners();
  }

  void musteriKabul() {
    musteriKabulBekliyor = false;
    final m = aktifMusteri!;
    // Yeni model: perceivedValue ve reservationPrice hesapla
    final fiyat = m.item.etkinFiyat; // çürükse düşük piyasa değeri
    final pv = m.ozellik.perceivedValue(m.item.kondisyon, fiyat);
    final reserv = _piyasaEtkisi(m.ozellik.reservationPrice(pv, fiyat, m.musteriSatiyor), m.musteriSatiyor);
    // Açılış teklifi artık reservationPrice üzerinden geliyor (ilkTeklif zaten init'te hesaplandı)
    // Oyuncunun başlangıç teklifi: müşteri satıyorsa %65, alıyorsa %130
    final oyuncuIlkTeklif = m.musteriSatiyor
        ? (fiyat * 0.65).round()
        : (fiyat * 1.30).round();
    aktifPazarlik = PazarlikSeans(
      musteriSatiyor: m.musteriSatiyor,
      piyasaFiyati: fiyat,
      musteriTeklif: m.ilkTeklif,
      oyuncuTeklif: oyuncuIlkTeklif,
      maxTur: m.ozellik.maxTur,
      ozellik: m.ozellik,
      reservationPrice: reserv,
      yas: m.yas,
      cinsiyet: m.cinsiyet,
    );
    // Pazarlık başlamadan önce kolonya ikram edildiyse bonusu şimdi uygula
    if (_kolonyaPendingBonus > 0) {
      aktifPazarlik!.kolonyaUygula(_kolonyaPendingBonus);
      _kolonyaPendingBonus = 0.0;
    }
    // Kurye bonusu: bir önceki kurye kabul edildiyse çok avantajlı koşullar
    if (kuryeBonusuAktif) {
      kuryeBonusuAktif = false;
      aktifPazarlik!.kuryeBonusuUygula();
    }
    notifyListeners();
  }

  void musteriReddetGirisSafhasinda() {
    if (aktifMusteri == null) return;
    const hayirM = ['Bir dahaki sefere!...','Keşke bir konuşsaydık...','Bugün gününde değil gibisin...','Bir görüşsek iyiydi...','Bugün çok katısın!...','Dostum, hayallerimi yıktın!...','Canın nasıl isterse...','Başım gözüm üstüne...','Belki başka zaman?...'];
    mesaj = hayirM[Random().nextInt(hayirM.length)];
    musteriKabulBekliyor = false;
    notifyListeners();
  }

  void musteriAnimasyonBitti() {
    aktifMusteri = null;
    aktifPazarlik = null;
    aktifOzelMusteri = null;
    musteriGorunuyor = false;
    ozelMusteriGorunuyor = false;
    musteriKabulBekliyor = false;
    kolonyaIkramEdildi = false;
    sonAnlasmaBasarisiz = false;
    // Güvenlik öne gelmişti ve gitti: hâlâ çalışıyorsa arka planda kapıdaki
    // yerine geri döner (istifa ettiyse `guvenlikVar` zaten false yapılıyor).
    _guvenlikOnde = false;
    _kolonyaPendingBonus = 0.0;
    notifyListeners();
  }

  void teklifVer(int oyuncuTeklif) {
    if (aktifPazarlik == null || aktifMusteri == null) return;
    toplamTeklifSayisi++;
    final durum = aktifPazarlik!.oyuncuTeklifVer(oyuncuTeklif);
    if (durum == PazarlikDurum.anlasildi) {
      _anlasmayiTamamla();
    } else if (durum == PazarlikDurum.gitti) {
      _komboSifirla(); // müşteri kızıp gitti → seri bozuldu
      SesServisi.basarisiz();
      mesaj = '${aktifMusteri!.name}: ${aktifPazarlik!.mesaj}';
      _musteriGonder();
    } else {
      mesaj = aktifPazarlik!.mesaj;
      notifyListeners();
    }
  }

  void _anlasmayiTamamla() {
    final m = aktifMusteri!;
    final p = aktifPazarlik!;
    final anlasilanFiyat = m.musteriSatiyor ? p.musteriTeklif : p.oyuncuTeklif;
    sonAnlasmaBasarisiz = false;
    if (m.musteriSatiyor) {
      if (para >= anlasilanFiyat) {
        if (m.item.id == 'kolonya') {
          // Kolonya slota girmez — ayrı tutulur, +1 ilave
          kolonyaKullanim = 10;
        } else {
          final itemMaliyet = m.item.kopyaWith(maliyet: anlasilanFiyat);
          if (!urunEkle(itemMaliyet)) {
            mesaj = 'Envanter dolu!';
            sonAnlasmaBasarisiz = true;
            _musteriGonder();
            return;
          }
        }
        para -= anlasilanFiyat;
        SesServisi.paraGirdi();
      } else {
        SesServisi.hata();
        mesaj = 'Yeterli paran yok! 💸';
        sonAnlasmaBasarisiz = true;
        _musteriGonder();
        return;
      }
    } else {
      urunCikarOrnek(m.item); // aynı id'den çürük/sağlam iki kopya varsa doğrusunu çıkar
      para += anlasilanFiyat;
      toplamSatis++;
      satilanUrunIdleri.add(m.item.id);
      SesServisi.paraGirdi();
      // Günlük hedef ilerlemesi (sadece SATIŞ sayılır)
      _hedefIlerlet(HedefTip.satisAdedi, 1);
      _hedefIlerlet(HedefTip.gelir, anlasilanFiyat);
      _hedefIlerlet(HedefTip.tekSatis, anlasilanFiyat, mutlak: true);
    }
    basariliPazarlik++;
    _komboArtir();
    SesServisi.anlasma();
    // Kabul mesajını göster, göndermeyi UI'daki gecikme yönetir
    mesaj = p.mesaj;
    notifyListeners();
  }

  void musteriReddet() {
    if (aktifMusteri == null) return;
    final isim = aktifMusteri!.name;
    final vazgecM = ['Anlaşmak isterdim ama olmadı...','En azından anlaşmayı denedik...','$isim sana kırgın ayrıldı...','Bu gelişte $isim mutlu olamadı.','Peki. Yanından son hız ayrılıyorum!','Seninle anlaşmak imkansız gibi!...','Faydalar faydasız, imkanlar imkansız...','En sert satıcılardan biri çıktın!...',"Daha da Davos'a gelmem!...",'Yine görüşeceğiz!...'];
    mesaj = vazgecM[Random().nextInt(vazgecM.length)];
    musteriKabulBekliyor = false;
    notifyListeners();
  }

  // Kolonya ikramı: pazarlık bonusu uygula, kullanim hakkını düş
  void kolonyaIkramEt() {
    final hasMusteri = aktifMusteri != null || aktifOzelMusteri != null;
    if (kolonyaKullanim <= 0 || kolonyaIkramEdildi || !hasMusteri) return;
    kolonyaIkramEdildi = true;
    kolonyaKullanim--; // 0'a düşünce widget otomatik gizlenir, slotta olmadığı için urunCikar gerekmez
    // Özel müşteriye ikram: pazarlık bonusu yok (onlar zaten gidecek)
    if (aktifMusteri != null) {
      // Normal müşteri: rastgele bonus 0.15..0.35
      final bonus = 0.15 + Random().nextDouble() * 0.20;
      if (aktifPazarlik != null) {
        aktifPazarlik!.kolonyaUygula(bonus);
      } else {
        _kolonyaPendingBonus = bonus;
      }
    }
    notifyListeners();
  }

  void imacSatin() {
    para -= 2000;
    imacSatinAlindi = true;
    SesServisi.paraGirdi();
    notifyListeners();
  }

  /// alinanTutar: oyuncuya eklenen para, geriOdeme: faizli toplam geri ödeme
  void krediAl(int alinanTutar, int geriOdeme, int taksitSayisi) {
    krediTaksitMiktar = (geriOdeme / taksitSayisi).ceil();
    krediKalanTaksit = taksitSayisi;
    para += alinanTutar;
    SesServisi.paraGirdi();
    notifyListeners();
  }

  /// Günü bitir — kira + kredi taksiti düş, sonucu döndür
  (int kiraMiktari, int krediKesinti, bool gameOver) gunuBitir() {
    final kira = aktifDukkan.kira;
    gun++;
    gunlukMusteriSayisi = 0;
    gunlukMusteriLimiti = aktifDukkan.gunlukMusteriSayisiUret();
    bugunOynananOyunlar.clear(); // yeni gün → mini oyunlar tekrar oynanabilir
    // Oynanabilir ürün hakkı yenilenir; bugünkü "dün"e devredilir ki
    // iki gün üst üste aynı oyun gelmesin.
    _dunGelenOynanabilirId = _bugunGelenOynanabilirId;
    _bugunGelenOynanabilirId = null;
    _bugunOynanabilirGeldi = false;
    para -= kira;
    SesServisi.paraGirdi();
    // 🛡️ Güvenlik ücreti — parası yetmiyorsa işi bırakır ve arka plan
    // güvenliksiz sürüme döner. Sessizce çalışmaya devam etmesi haksızlık olur.
    if (guvenlikVar) {
      if (para >= guvenlikGunlukUcret) {
        para -= guvenlikGunlukUcret;
      } else {
        guvenlikVar = false;
        guvenlikIsiBirakti = true; // UI gün sonu popup'ında duyurur
      }
    }
    // 🏠 Kiraya verilen dükkanların günlük getirisi
    para += gunlukKiraGeliri;
    int krediKesinti = 0;
    if (krediKalanTaksit > 0) {
      krediKesinti = krediTaksitMiktar;
      para -= krediKesinti;
      krediKalanTaksit--;
      if (krediKalanTaksit == 0) tamamlananKrediSayisi++; // kredi tamamen ödendi
      SesServisi.paraGirdi();
    }
    // ── Emektar rozeti: günlük destek ──
    if (gunlukDestek > 0) para += gunlukDestek;
    // ── Bugünün olayı: DÜN AKŞAM açıklanmıştı (yarinkiOlayId) ──
    gunlukOlayId = yarinkiOlayId;
    piyasaCarpani = 1.0;
    gunlukToptanciIndirim = 0.0;
    final rng = Random();
    final bugunku = GunOlayi.bul(gunlukOlayId);
    if (bugunku != null) {
      piyasaCarpani         = bugunku.piyasaCarpani;
      gunlukToptanciIndirim = bugunku.toptanciIndirim;
      gunlukMusteriLimiti   = (gunlukMusteriLimiti + bugunku.musteriDelta).clamp(3, 99);
      if (bugunku.paraDelta != 0) para += bugunku.paraDelta;
      if (bugunku.fareIstilasi) _rastgeleUrunuCurut();
    }
    // ── YARININ olayını şimdiden belirle (gün sonu popup'ında duyurulacak) ──
    yarinkiOlayId = (gun >= 2 && rng.nextDouble() < 0.55)
        ? GunOlayi.havuz[rng.nextInt(GunOlayi.havuz.length)].id
        : null;
    // ── Yeni günün hedefi ──
    gunlukHedef = GunlukHedef.uret(aktifDukkan.seviye);
    hedefYeniTamamlandi = false;
    // Yeni gün → toptancı stoğu tazelensin (indirim hesaba katılarak yeniden üretilir)
    toptanciStokGunu = 0;
    _rizaGunuAyarla(); // Rıza bugün hangi müşteri sırasında uğrayacak?
    mesaj = '$gun. gün başlıyor!';
    notifyListeners();
    return (kira, krediKesinti, para < 0);
  }

  /// Game over kesintisi — gun artırmadan sadece kira/kredi keser.
  /// Bilgisayar popup'ı ve yeni gün geçişi tetiklenmez.
  void gameOverGecis() {
    para -= aktifDukkan.kira;
    SesServisi.paraGirdi();
    if (krediKalanTaksit > 0) {
      para -= krediTaksitMiktar;
      krediKalanTaksit--;
      SesServisi.paraGirdi();
    }
    notifyListeners();
  }

  void _musteriGonder() {
    musteriGorunuyor = false;
    ozelMusteriGorunuyor = false;
    aktifOzelMusteri = null;
    musteriKabulBekliyor = false;
    notifyListeners();
  }
}

// ─── ANA OYUN EKRANI ─────────────────────────────────────────────────────────

class GameScreen extends StatefulWidget {
  final bool yeniOyun;
  final GameState? yuklenenState;
  const GameScreen({super.key, required this.yeniOyun, this.yuklenenState});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

/// Browser penceresinde acilabilen sayfalar.
enum _BrowserSayfa { menu, dukkanlar, satilik, hedefler, market, banka }

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late GameState _state;
  late AnimationController _slideController;
  late Animation<double> _slideAnim;
  // Ürünün "anlaşma sonrası masadan aşağı kayıp gitmesi" efekti — AYRI
  // controller. Önceden AnimatedPositioned kullanılıyordu ama onun left/top'u
  // her karede _slideAnim'e göre değişiyordu; AnimatedPositioned her deger
  // degisiminde yeni hedefe 650ms'de gitmeye calisiyor, yani hareketli bir
  // hedefi kovalıyordu → ürün müşteriden yarım saniye geride kalarak giriyordu.
  // Artık giriş konumu (left/top) DOĞRUDAN _slideAnim'den okunuyor (Positioned,
  // animasyonsuz) — müşteriyle birebir aynı anda hareket ediyor. Aşağı kayıp
  // gitme efekti bu ayrı controller ile, konumdan bağımsız olarak uygulanıyor.
  late AnimationController _urunKayipController;

  /// 🛡️ Güvenliğin "kapıdaki yeri ↔ tezgâh" geçişi. Normal müşterilerin sağdan
  /// kayması burada YANLIŞ olurdu: güvenlik dükkanın içinde zaten duruyor,
  /// dışarıdan gelmiyor.
  ///
  /// Tek controller, iki yön:
  ///   `forward` → yukarıdan belirip aşağı iner ve büyür (tezgâha gelir)
  ///   `reverse` → aynı hareketin tersi; kaybolduğu anda arka plan güvenlikli
  ///               sürüme döndüğü için yerine geçmiş gibi görünür.
  ///
  /// 0 = kapıdaki yerinde (görünmez), 1 = tezgâhta (tam görünür).
  late AnimationController _guvenlikBelirmeController;
  /// Geçiş halkasının sürekli dönüşü (saat yönünün TERSİNE — ters yönde
  /// dönen bir halka "işlem sürüyor" hissini daha net veriyor).
  late AnimationController _gecisController;

  // ── 💰 PARA SAYACI ANİMASYONU ─────────────────────────────────────────────
  // Para değişince bakiye kutusu büyür, yeşile (giriş) ya da kırmızıya (çıkış)
  // boyanır, rakamlar eski değerden yenisine doğru SAYARAK ilerler, sonra
  // normale döner. Satış/alım anını gözden kaçırmak zorlaşsın diye.
  late AnimationController _paraController;
  int _paraBaslangic = 0;   // sayımın başladığı değer (ekranda görünen)
  int _paraHedef = 0;       // ulaşılacak değer
  bool _paraArtis = true;   // true = yeşil (giriş), false = kırmızı (çıkış)

  static const Color _paraYesil = Color(0xFF3CC850);
  static const Color _paraKirmizi = Color(0xFFF84C4C);

  /// Sayım toplam sürenin bu oranında biter; kalanı "normale dönüş".
  static const double _paraSayimOrani = 0.72;

  /// Ekranda o an gösterilecek bakiye.
  int get _gosterilenPara {
    if (!_paraController.isAnimating && _paraController.value == 0) return _paraHedef;
    final t = _paraController.value;
    if (t >= _paraSayimOrani) return _paraHedef;
    final p = Curves.easeOutCubic.transform(t / _paraSayimOrani);
    return (_paraBaslangic + (_paraHedef - _paraBaslangic) * p).round();
  }

  // ── 🗓️ GÜN SAYACI ANİMASYONU ──────────────────────────────────────────────
  // Para kutusuyla AYNI dil: kutu büyür, yeşile döner, sayı değişir, normale
  // soluyor. Fark: gün hep +1 arttığı için "sayma" yerine ODOMETRE gibi
  // dönüyor — eski sayı yukarı çıkıp giderken yeni sayı alttan geliyor.
  late AnimationController _gunController;
  int _gunEski = 1;
  int _gunYeni = 1;

  void _gunDegisimKontrol() {
    if (_state.gun == _gunYeni) return;
    _gunEski = _gunYeni;
    _gunYeni = _state.gun;
    _gunController.forward(from: 0);
  }

  /// `_state.para` değişti mi? Değiştiyse sayımı baştan başlat.
  void _paraDegisimKontrol() {
    if (_state.para == _paraHedef) return;
    // Animasyon ortasında yeni bir değişiklik gelirse ekrandaki değerden devam
    // et — sayı asla geri sıçramasın.
    _paraBaslangic = _gosterilenPara;
    _paraArtis = _state.para > _paraBaslangic;
    _paraHedef = _state.para;
    _paraController.forward(from: 0);
  }
  bool _envanterAcik = false;
  /// Toptanci ekraninda envanter sekmesi acik mi (tek yonlu gecis)
  bool _toptanciEnvanterSekmesi = false;

  // ── 🚗 KONUM GEÇİŞİ ───────────────────────────────────────────────────────
  // Yolculuk gerçek zamanda ilerler: sahnede solda küçük araç görseli ve
  // çevresinde SAAT YÖNÜNÜN TERSİNE dönen bir halka. Süre aracın niteliğinden
  // gelir (motosiklet uzun, otomobil kısa) — `Arac.gecisSaniye`.
  bool _gecisAktif = false;
  Konum _gecisHedef = Konum.ev;
  String? _gecisAracGorsel;
  int _gecisToplamSn = 0;
  DateTime? _gecisBaslangic;
  Timer? _gecisTimer;

  /// 0..1 arası ilerleme. Timer her saniye tetiklendiği için yeterince akıcı
  /// değil; halka `_gecisController` ile ayrıca sürekli dönüyor.
  double get _gecisOran {
    if (!_gecisAktif || _gecisBaslangic == null || _gecisToplamSn <= 0) return 0;
    final gecen = DateTime.now().difference(_gecisBaslangic!).inMilliseconds / 1000.0;
    return (gecen / _gecisToplamSn).clamp(0.0, 1.0);
  }

  int get _gecisKalanSn {
    if (!_gecisAktif) return 0;
    return (_gecisToplamSn * (1 - _gecisOran)).ceil();
  }

  /// Hedefler sayfasındaki sekme: 0 = HEDEFLER, 1 = KOLEKSİYON.
  /// ⚠️ Browser gövdesi her karede baştan çalıştığı için widget içinde
  /// tutulamaz — banka sayfasının tutar/taksit seçimiyle aynı sebep.
  int _hedefSekme = 0;
  // ⚠️ Ürün büyütme önizlemeleri artık `showDialog` ile açılıyor, ana
  // `Stack`'e katman olarak DEĞİL. Eskiden bu iki alan bir bayrak tutuyor,
  // görsel de sahne Stack'inin en üstüne çiziliyordu; ama `showDialog` ile
  // açılan bir pencere (Toptancı Rıza) sayfanın TAMAMININ üstünde ayrı bir
  // route olduğu için büyütme onun ALTINDA kalıyor, Rıza kapanınca arkada
  // duruyordu. Dialog route'u her zaman en üstte olur → sorun kökten çözülür.
  /// Anlaşma sonrası ürün masadan aşağı kayıyor mu
  bool _urunAsagiKayiyor = false;
  bool _gunBitiPopupGosterildi = false;
  bool _pazarlikBekleniyor = false;
  bool _bilgisayarGeldiGosterildi = false;
  bool _gameOverGosterildi = false; // game over popup gösterildiyse diğer popup'ları engelle
  String? _kolonyaGeciciMesaj; // 3 saniyeliğine gösterilecek özel mesaj
  Timer? _kolonyaMesajTimer;
  Timer? _kuryeTimer;
  int _kolonyaSonrasiSonIdx = -1; // alıcı + kolonya sonrası tekrarlamasın diye son seçilen mesaj indeksi

  // ── Animasyonlu bildirim (toast) ──
  String? _toastMetin;
  String _toastAltYazi = '';
  String _toastEmoji = '🔥';
  Color _toastRenk = const Color(0xFFFFD700);
  int _toastId = 0; // her yeni toast'ta animasyon baştan başlasın
  Timer? _toastTimer;
  bool _rozetPopupAcik = false;   // rozet popup'ları üst üste binmesin

  // ── Daire geri sayım animasyonu ──
  late Ticker _daireTicker;
  Duration _dairePrevTick = Duration.zero;
  double _daireGosterilen = 0.0; // 0.0..1.0 — ekranda görünen değer
  double _daireHedef     = 0.0; // müşteri sayısına göre gerçek hedef
  double _daireHiz       = 0.3; // birim/saniye — her müşteride rassal değişir
  final _daireRng        = Random();

  @override
  void initState() {
    super.initState();
    _state = widget.yuklenenState ?? GameState();
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnim = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _urunKayipController = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _guvenlikBelirmeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
    _gecisController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
    // 💰 Para sayacı: toplam ~2.2 sn (sayım + normale dönüş)
    _paraController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
    _paraBaslangic = _paraHedef = _state.para;
    _gunController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
    _gunEski = _gunYeni = _state.gun;
    _state.addListener(_gunDegisimKontrol);
    _state.addListener(_paraDegisimKontrol);
    _state.addListener(_daireHedefGuncelle);
    _daireTicker = createTicker(_daireTick)..start();
    // 👩‍🏫 Rehber Hande: oyunun EN BAŞINDA kendiliğinden gelir, "Müşteri Çağır"a
    // basmak gerekmez. Sadece yeni oyunda ve bir kez (`handeGosterildi`).
    // Kısa gecikme: sahne otursun, kapı sesi/animasyon üst üste binmesin.
    if (widget.yeniOyun && !_state.handeGosterildi) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        SesServisi.kapiyiCal();
        _state.handeyiGonder();
        _slideController.forward(from: 0);
      });
    }
  }

  void _daireHedefGuncelle() {
    final limit = _state.gunlukMusteriLimiti;
    final hedef = limit > 0 ? _state.gunlukMusteriSayisi / limit.toDouble() : 0.0;
    if (hedef > _daireHedef) {
      _daireHedef = hedef;
      // Rassal hız: 0.18–0.55 birim/sn — her müşteride farklı tempo
      _daireHiz = 0.18 + _daireRng.nextDouble() * 0.37;
    } else if (hedef < _daireHedef - 0.001) {
      // Yeni gün: sıfırla
      _daireGosterilen = 0.0;
      _daireHedef = 0.0;
      _dairePrevTick = Duration.zero;
    }
  }

  void _daireTick(Duration now) {
    if (_dairePrevTick == Duration.zero) { _dairePrevTick = now; return; }
    final dt = (now - _dairePrevTick).inMilliseconds / 1000.0;
    _dairePrevTick = now;
    final gap = _daireHedef - _daireGosterilen;
    if (gap > 0.0001) {
      // Ana ilerleme: hedefe doğru mevcut hızda git
      final adim = (_daireHiz * dt).clamp(0.0, gap);
      setState(() { _daireGosterilen += adim; });
      // Hedefe yaklaşınca yavaşla (doğal hissettir)
      if (gap < 0.04) _daireHiz = (_daireHiz * 0.92).clamp(0.04, 1.0);
    } else {
      // Hedefte: çok yavaş sürüklenme (sürekli hareket hissi)
      final surukleme = 0.008 * dt;
      setState(() { _daireGosterilen = (_daireGosterilen + surukleme).clamp(0.0, _daireHedef + 0.005); });
    }
  }

  @override
  void dispose() {
    _kolonyaMesajTimer?.cancel();
    _kuryeTimer?.cancel();
    _toastTimer?.cancel();
    _daireTicker.dispose();
    _state.removeListener(_gunDegisimKontrol);
    _state.removeListener(_paraDegisimKontrol);
    _state.removeListener(_daireHedefGuncelle);
    _slideController.dispose();
    _urunKayipController.dispose();
    _guvenlikBelirmeController.dispose();
    _gecisController.dispose();
    _gecisTimer?.cancel();
    _paraController.dispose();
    _gunController.dispose();
    super.dispose();
  }

  void _musteriCagir() {
    _state.yeniMusteriGonder();
    if (_state.musteriGorunuyor || _state.ozelMusteriGorunuyor) {
      SesServisi.kapiyiCal();
      _slideController.forward(from: 0);
    }
  }

  void _musteriHayir() {
    if (_state.aktifOzelMusteri != null) {
      _ozelMusteriHayirPopup(_state.aktifOzelMusteri!);
      return;
    }
    _state.musteriReddetGirisSafhasinda();
    _slideController.reverse().then((_) { if (mounted) _state.musteriAnimasyonBitti(); });
  }

  void _musteriEvet() {
    // Özel müşteri mi?
    if (_state.aktifOzelMusteri != null) {
      _ozelMusteriEvetPopup(_state.aktifOzelMusteri!);
      return;
    }
    final m = _state.aktifMusteri!;
    // Müşteri satıyorsa ve envanter doluysa engelle
    if (m.musteriSatiyor) {
      final bosSlotVar = _state.slotlar
          .sublist(0, _state.acikSlotSayisi)
          .any((s) => s == null);
      if (!bosSlotVar) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1a1008),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.orangeAccent, width: 2),
            ),
            title: const Text('📦 Envanter Dolu!', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.orangeAccent, fontSize: 18)),
            content: const Text('Daha geniş bir dükkana geç.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Panel.yazi, fontSize: 15)),
            actions: [Center(child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _state.musteriReddetGirisSafhasinda();
                _slideController.reverse().then((_) {
                  if (mounted) _state.musteriAnimasyonBitti();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.black),
              child: const Text('Tamam', style: TextStyle(fontWeight: FontWeight.bold)),
            ))],
          ),
        );
        return;
      }
    }
    _state.musteriKabul();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _state.aktifMusteri != null) _pazarlikGoster();
    });
  }

  /// Kazanılan rozetleri sıraya göre gösterir. Sadece ekran müsaitken
  /// (müşteri yok, pazarlık yok, envanter kapalı) tetiklenir ki üst üste
  /// dialog binmesin.
  void _rozetKuyrugunuIsle() {
    if (_rozetPopupAcik) return;
    if (_state.yeniKazanilanRozetler.isEmpty) return;
    if (_state.aktifMusteri != null || _state.aktifPazarlik != null) return;
    if (_state.aktifOzelMusteri != null || _envanterAcik) return;
    if (_gunBitiPopupGosterildi || _gameOverGosterildi) return; // gün sonu/iflas popup'ıyla çakışmasın
    _rozetPopupAcik = true;
    final rozet = _state.yeniKazanilanRozetler.removeAt(0);
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) { _rozetPopupAcik = false; return; }
      SesServisi.rozet();
      _rozetPopup(rozet);
    });
  }

  void _rozetPopup(Rozet r) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1008),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFa371f7), width: 2)),
        title: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(r.emoji, style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 6),
          const Text('ROZET KAZANDIN!', textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFa371f7), fontSize: 15, letterSpacing: 2, fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(r.baslik, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(r.hedefAciklama, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF3fb950).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF3fb950).withValues(alpha: 0.5)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('🎁 ', style: TextStyle(fontSize: 15)),
              Flexible(child: Text(r.odul, textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF3fb950), fontSize: 13, fontWeight: FontWeight.bold))),
            ]),
          ),
        ]),
        actions: [Center(child: ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            _rozetPopupAcik = false;
            _rozetKuyrugunuIsle(); // sırada başka rozet varsa göster
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFa371f7), foregroundColor: Colors.white),
          child: const Text('Süper!', style: TextStyle(fontWeight: FontWeight.bold)),
        ))],
      ),
    );
  }

  /// Bir gün olayının etkilerini renkli çipler halinde gösterir.
  /// Hem gün sonu "yarın" önizlemesinde hem Hedefler ekranında kullanılır.
  static Widget _olayEtkiCipleri(GunOlayi o) {
    final etkiler = <String>[];
    if (o.musteriDelta > 0) etkiler.add('+${o.musteriDelta} müşteri');
    if (o.musteriDelta < 0) etkiler.add('${o.musteriDelta} müşteri');
    if (o.piyasaCarpani > 1.0) etkiler.add('Müşteriler cömert');
    if (o.piyasaCarpani < 1.0) etkiler.add('Müşteriler cimri');
    if (o.paraDelta != 0) etkiler.add('+${o.paraDelta} lira');
    if (o.toptanciIndirim > 0) etkiler.add('Toptancıda %${(o.toptanciIndirim * 100).round()} indirim');
    if (o.fareIstilasi) etkiler.add('Bir ürün çürüyecek');
    if (etkiler.isEmpty) return const SizedBox.shrink();
    final iyi = o.musteriDelta > 0 || o.piyasaCarpani > 1.0 || o.paraDelta > 0 || o.toptanciIndirim > 0;
    final renk = iyi ? const Color(0xFF3fb950) : const Color(0xFFff7043);
    return Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6,
      children: etkiler.map((e) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: renk.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: renk.withValues(alpha: 0.45)),
        ),
        child: Text(e, style: TextStyle(color: renk, fontSize: 10, fontWeight: FontWeight.bold)),
      )).toList());
  }

  /// Seri bonusu ve günlük hedef tamamlanmasını oyunun kendi temasında
  /// animasyonlu bir toast ile duyurur. Popup/SnackBar yok — akış kesilmesin.
  void _anlikBildirimleriIsle() {
    if (_state.sonKomboBonusu > 0) {
      final b = _state.sonKomboBonusu;
      final k = _state.kombo;
      _state.sonKomboBonusu = 0; // tüket
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        SesServisi.seri();
        _toastGoster('$k\'LÜ SERİ!', altYazi: '+$b lira', emoji: '🔥',
          renk: const Color(0xFFFF9500));
      });
    }
    if (_state.hedefYeniTamamlandi) {
      final h = _state.gunlukHedef;
      _state.hedefYeniTamamlandi = false; // tüket
      if (h != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          SesServisi.hedefTamam();
          _toastGoster('GÜNÜN HEDEFİ TAMAM!', altYazi: '+${h.odul} lira', emoji: '🎯',
            renk: const Color(0xFF3fb950));
        });
      }
    }
  }

  /// Toast ekrandayken müşteri çıkış animasyonu BEKLETİLİR — bildirimi
  /// okurken müşterinin kayıp gitmesi dikkati bölüyordu. Toast kapanınca
  /// bekleyen çıkış hemen başlar.
  VoidCallback? _toastSonrasiIs;

  void _toastGoster(String metin, {required String altYazi, required String emoji,
      required Color renk, int ms = 4200}) {
    _toastTimer?.cancel();
    setState(() {
      _toastId++;
      _toastMetin = metin; _toastAltYazi = altYazi; _toastEmoji = emoji; _toastRenk = renk;
    });
    _toastTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      setState(() => _toastMetin = null);
      final is_ = _toastSonrasiIs;
      _toastSonrasiIs = null;
      is_?.call();
    });
  }

  /// Ekranda süreli bir bildirim varsa [is_] onu bekler, yoksa hemen çalışır.
  void _toastBitinceCalistir(VoidCallback is_) {
    if (_toastMetin == null) { is_(); return; }
    final onceki = _toastSonrasiIs;
    _toastSonrasiIs = () { onceki?.call(); is_(); };
  }

  /// Polisin alkol testine cevap verildi. Doğruysa ceza yok, yanlışsa
  /// rastgele bir ceza kesilir. İki durumda da polis gider.
  void _alkolTestiCevapla(int secilen) {
    final om = _state.aktifOzelMusteri;
    if (om == null || !om.alkolTesti) return;
    _state.musteriKabulBekliyor = false;
    if (secilen == om.dogruCevap) {
      _state.mesaj = 'Tamam, iyisin. Ceza kesmekten vazgeçtim!';
    } else {
      final ceza = 40 + Random().nextInt(211);
      _state.para -= ceza;
      SesServisi.paraGirdi();
      _state.mesaj = 'Yanlış! Belli ki içmişsin. $ceza lira ceza kestim!';
    }
    _state.notifyListeners();
    _kuryeTimer?.cancel();
    _kuryeTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) _ozelMusteriGonder();
    });
  }

  /// Dialog İÇİNDEN gösterilen kısa bildirim (toptancı, tamir vb.).
  ///
  /// Neden `_toastGoster` değil: o kart ana `Stack`'te render ediliyor, dialog
  /// açıkken onun ALTINDA kalır ve görünmez. SnackBar `Overlay`'de çıktığı için
  /// dialog'un üstünde görünür.
  ///
  /// ⚠️ Material'in VARSAYILAN renklerine güvenme: koyu temada yazı rengi de
  /// koyu geliyor, koyu zeminle kaynaşıyor ve metin okunmuyordu. Renkler burada
  /// açıkça veriliyor — zemin/çerçeve/yazı `_buildToast` ile aynı dilde.
  void _dialogBildirim(BuildContext ctx, String metin, {bool hata = false}) {
    final renk = hata ? const Color(0xFFff6b6b) : const Color(0xFF4ade80);
    ScaffoldMessenger.of(ctx)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF241a10),
        elevation: 8,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: renk, width: 2),
        ),
        content: Text(
          metin,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black, blurRadius: 3, offset: Offset(0, 1))],
          ),
        ),
      ));
  }

  /// Oyun temasına uygun, animasyonlu bildirim kartı.
  /// Aşağıdan yukarı süzülerek gelir, hafif zıplar, sonra kaybolur.
  Widget _buildToast() {
    final renk = _toastRenk;
    // Rozet kazandın popup'ıyla aynı dilde — ekranın MERKEZİNDE, rahat
    // gözükecek genişlikte. Eskiden alttan %26'da, dar bir kutuydu.
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
          key: ValueKey(_toastId),
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 420),
          curve: Curves.elasticOut,
          builder: (context, t, child) {
            final opak = t.clamp(0.0, 1.0);
            return Opacity(
              opacity: opak,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 26),
                child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
              ),
            );
          },
          child: Container(
              constraints: const BoxConstraints(minWidth: 260),
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [const Color(0xFF241a10), const Color(0xFF120c06)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: renk, width: 2),
                boxShadow: [
                  BoxShadow(color: renk.withValues(alpha: 0.45), blurRadius: 22, spreadRadius: 1),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_toastEmoji, style: const TextStyle(fontSize: 30)),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_toastMetin ?? '',
                        style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w900, color: renk,
                          letterSpacing: 1.1,
                          shadows: const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1))],
                        )),
                      const SizedBox(height: 2),
                      Text(_toastAltYazi,
                        style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1))],
                        )),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _gunBitiKontrol() {
    if (_gameOverGosterildi) return; // game over zaten işlendi, başka popup tetikleme
    _anlikBildirimleriIsle();
    _rozetKuyrugunuIsle();
    if (_state.oyunBitti) {
      _gameOverGosterildi = true;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _gameOverPopup('Para bitti ve envanter boş!\n\n${_state.gun}. günde iflas ettin.', _state.gun);
      });
      return;
    }
    if (_state.gun >= 2 && !_bilgisayarGeldiGosterildi) {
      _bilgisayarGeldiGosterildi = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _bilgisayarGeldiPopup();
      });
    }
    if (_state.gunBitmeli && !_gunBitiPopupGosterildi) {
      _gunBitiPopupGosterildi = true;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _gunSonuPopupGoster();
      });
    }
  }

  void _bilgisayarGeldiPopup() {
    const mesajlar = [
      'Tebrikler! Seni seven biri, sana hayırlı olsun hediyesi olarak bilgisayar gönderdi. Artık internete bağlanabilirsin.',
      'Tebrikler! 2. güne ulaşma hediyesi olarak dükkan sahibin sana bir bilgisayar hediye etti. Artık internete bağlanabilirsin.',
      'Tebrikler! Yan komşun, kullanmadığı bilgisayarını sana hediye etti. Artık internete bağlanabilirsin.',
      'Tebrikler! Komşuların aralarında para toplayarak sana hediye bir bilgisayar almışlar. Artık internete bağlanabilirsin.',
      'Tebrikler! Kimliği belirsiz biri, kapına bir bilgisayar bırakmış. Artık internete bağlanabilirsin.',
      'Tebrikler! Mağaza çekilişinden bir bilgisayar kazandın. Artık internete bağlanabilirsin.',
    ];
    final mesaj = mesajlar[Random().nextInt(mesajlar.length)];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1008),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFFFD700), width: 2)),
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🖥️', textAlign: TextAlign.center, style: TextStyle(fontSize: 48)),
            SizedBox(height: 4),
            Text('Bilgisayar Geldi!', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFFFD700), fontSize: 20)),
          ],
        ),
        content: Text(mesaj, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 15)),
        actions: [Center(child: ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black),
          child: const Text('Harika!', style: TextStyle(fontWeight: FontWeight.bold)),
        ))],
      ),
    );
  }

  void _gunSonuPopupGoster() {
    SesServisi.gunSonu();
    final eskiGun = _state.gun;
    final kira = _state.aktifDukkan.kira;
    final paraOncesi = _state.para;
    final krediKesinti = _state.aktifKrediVar ? _state.krediTaksitMiktar : 0;
    final toplamKesinti = kira + krediKesinti;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1008),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFFFD700), width: 2)),
        title: Text('🌙 $eskiGun. Gün Bitti!', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Kasa: $paraOncesi', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('🏠 Kira: ', style: TextStyle(color: Colors.white54, fontSize: 14)),
              Text('-$kira', style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            if (krediKesinti > 0) ...[
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('🏦 Kredi taksiti: ', style: TextStyle(color: Colors.white54, fontSize: 14)),
                Text('-$krediKesinti', style: const TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 4),
              Text('(${_state.krediKalanTaksit - 1} taksit kaldı)',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
            const SizedBox(height: 8),
            const Divider(color: Color(0xFFFFD700), height: 1),
            const SizedBox(height: 8),
            Text('Kalan: ${paraOncesi - toplamKesinti}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: (paraOncesi - toplamKesinti) < 0 ? Colors.redAccent : const Color(0xFF00FF88),
                fontSize: 18, fontWeight: FontWeight.bold)),
            // ── Günün hedefi sonucu ──
            if (_state.gunlukHedef != null) ...[
              const SizedBox(height: 10),
              Builder(builder: (_) {
                final h = _state.gunlukHedef!;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (h.tamamlandi ? const Color(0xFF3fb950) : Colors.white24).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: (h.tamamlandi ? const Color(0xFF3fb950) : Colors.white30).withValues(alpha: 0.5)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(h.tamamlandi ? '✅' : '${h.emoji} ', style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    Flexible(child: Text(
                      h.tamamlandi ? 'Günün hedefi tamam! +${h.odul}' : 'Hedef kaçtı: ${h.baslik}',
                      style: TextStyle(fontSize: 11,
                        color: h.tamamlandi ? const Color(0xFF3fb950) : Colors.white38))),
                  ]),
                );
              }),
            ],
            // ── Seri ──
            if (_state.kombo >= 2) ...[
              const SizedBox(height: 6),
              Text('🔥 ${_state.kombo}\'lü seri devam ediyor!',
                style: const TextStyle(fontSize: 11, color: Color(0xFFFF8C00), fontWeight: FontWeight.bold)),
            ],
            // ── YARIN NE OLACAK? — "bir gün daha" kancası ──
            if (paraOncesi - toplamKesinti >= 0) ...[
              const SizedBox(height: 12),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 10),
              Builder(builder: (_) {
                final o = GunOlayi.bul(_state.yarinkiOlayId);
                if (o == null) {
                  return const Text('☀️ Yarın sıradan bir gün görünüyor.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.white38));
                }
                final iyi = o.musteriDelta > 0 || o.piyasaCarpani > 1.0 || o.paraDelta > 0 || o.toptanciIndirim > 0;
                final renk = iyi ? const Color(0xFF3fb950) : const Color(0xFFff7043);
                return Column(children: [
                  const Text('YARIN', style: TextStyle(fontSize: 10, color: Colors.white38, letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text('${o.emoji}  ${o.baslik}', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: renk, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(o.aciklama, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Colors.white54, height: 1.25)),
                  const SizedBox(height: 8),
                  _olayEtkiCipleri(o),
                ]);
              }),
            ],
          ],
        ),
        actions: [Center(child: ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            if (paraOncesi - toplamKesinti < 0) {
              // Kira ödenemez → gun artırmadan sadece kes, game over popup göster
              _state.gameOverGecis();
              setState(() {
                _gunBitiPopupGosterildi = true;
                _gameOverGosterildi = true; // bilgisayar popup + bg geçişi engelle
              });
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) _gameOverPopup('Kira ödenemedi!\n\n${_state.gun}. günde iflas ettin.', _state.gun);
              });
            } else {
              // Normal geçiş — yeni güne başlamadan önce interstitial reklam
              ReklamServisi.goster(onClosed: () {
                if (!mounted) return;
                _state.gunuBitir();
                setState(() => _gunBitiPopupGosterildi = false);
                // Olay dün akşam duyuruldu — sabah tekrar popup açmıyoruz.
                // Aktif olay gün boyu header mesajında ve Hedefler ekranında görünür.
              });
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black),
          child: const Text('Yeni Güne Başla', style: TextStyle(fontWeight: FontWeight.bold)),
        ))],
      ),
    );
  }

  void _gameOverPopup(String mesaj, int gun) {
    KayitServisi.enYuksekGunGuncelle(gun);
    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1008),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.red, width: 2)),
        title: const Text('💀 OYUN BİTTİ', textAlign: TextAlign.center, style: TextStyle(color: Colors.red, fontSize: 22)),
        content: Text(mesaj, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 15)),
        actions: [Center(child: ElevatedButton(
          onPressed: () { Navigator.pop(ctx); Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AnaMenuEkrani())); },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text('Ana Menüye Dön', style: TextStyle(fontWeight: FontWeight.bold)),
        ))],
      ),
    );
  }

  /// Market — browser sayfası gövdesi.
  Widget _marketGovdesi(BuildContext ctx) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('🛒 ', style: TextStyle(fontSize: 20)),
          Text('MARKET', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFFf78166), letterSpacing: 2)),
        ]),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.78,
          children: [
            _marketUrunKart(
              ikon: '🖥️',
              isim: 'iMac',
              fiyat: 2000,
              satinAlindi: _state.imacSatinAlindi,
              onTap: () { Navigator.pop(ctx); _imacDetayPopup(); },
            ),
            _marketUrunKart(
              ikon: '🏠',
              isim: 'Ev',
              fiyat: EvEsyasi.evFiyati,
              satinAlindi: _state.evSahibi,
              onTap: () { Navigator.pop(ctx); _mekanSatinAlPopup(Konum.ev); },
            ),
            _marketUrunKart(
              ikon: '🏖️',
              isim: 'Yazlık',
              fiyat: EvEsyasi.yazlikFiyati,
              satinAlindi: _state.yazlikSahibi,
              onTap: () { Navigator.pop(ctx); _mekanSatinAlPopup(Konum.yazlik); },
            ),
          ],
        ),
      ],
    );
  }

  Widget _marketUrunKart({
    required String ikon,
    required String isim,
    required int fiyat,
    required bool satinAlindi,
    required VoidCallback onTap,
    bool kilitli = false,
    String kilitYazi = '',
  }) {
    return Opacity(
      opacity: kilitli ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: kilitli ? null : onTap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161b22),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: satinAlindi
                  ? const Color(0xFF3fb950).withValues(alpha: 0.6)
                  : const Color(0xFFf78166).withValues(alpha: 0.35),
              width: satinAlindi ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(ikon, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 6),
              Text(isim, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              if (kilitli)
                Text('🔒 $kilitYazi', style: const TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold))
              else if (satinAlindi)
                const Text('✅ Alındı', style: TextStyle(fontSize: 10, color: Color(0xFF3fb950), fontWeight: FontWeight.bold))
              else
                Text('$fiyat', style: const TextStyle(fontSize: 11, color: Color(0xFFf78166), fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  TOPTANCI — günlük stok, ucuz ürün / çürük ürün / tamir seti / kapalı kutu
  // ═══════════════════════════════════════════════════════════════════════════
  /// Toptancı ekranındaki sekme düğmesi (Tezgâh / Envanter).
  Widget _toptanciSekme(String etiket, bool secili, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: secili ? const Color(0xFFd29922).withValues(alpha: 0.16) : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: secili ? const Color(0xFFd29922) : const Color(0xFFd29922).withValues(alpha: 0.20),
                width: secili ? 2.5 : 1,
              ),
            ),
          ),
          child: Text(etiket,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.6,
              color: secili ? const Color(0xFFd29922) : Colors.white38)),
        ),
      ),
    );
  }

  Future<void> _toptanciPopup({bool ziyaret = false}) async {
    _toptanciEnvanterSekmesi = false; // her açılışta tezgâhla başla
    if (ziyaret) {
      _state.toptanciZiyaretiTazele(); // kapıya geldiyse taze stok
    } else {
      _state.toptanciStokKontrol();    // stok bugüne aitse korunur, değilse üretilir
    }
    await showDialog(
      context: context,
      // ⚠️ ListenableBuilder ŞART. Bu pencere bir `StatefulBuilder`; kendi
      // `setDlg`'i dışında hiçbir şey onu yenilemiyordu. Kapalı kutu açmak
      // (`kutuAc`) ve ürün çöpe atmak (`urunCikarOrnek`) `_state` üzerinden
      // çalışıp `notifyListeners()` çağırıyor ama bu pencere onu DİNLEMİYORDU:
      // model doğru güncelleniyor, ekran eski listeyi çizmeye devam ediyordu.
      // Kullanıcıya "kutu açılmıyor / ürün silinmiyor" gibi görünüyordu — üstelik
      // ikinci denemede `kutuAc` artık kutu olmayan bir slota bakıp `null`
      // döndüğü için sonuç penceresi de hiç açılmıyordu.
      builder: (ctx) => ListenableBuilder(
        listenable: _state,
        builder: (ctx, _) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final indirimliGun = _state.gunlukToptanciIndirim > 0;
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.82),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1a1008),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFd29922).withValues(alpha: 0.6), width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Başlık: toptancı görseli + konuşma ──
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFd29922).withValues(alpha: 0.10),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        border: Border(bottom: BorderSide(color: const Color(0xFFd29922).withValues(alpha: 0.3))),
                      ),
                      child: Row(children: [
                        Image.asset('assets/toptanci.png', width: 78, height: 78, fit: BoxFit.contain),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('TOPTANCI RIZA',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFd29922), letterSpacing: 1.2)),
                              const SizedBox(height: 3),
                              Text(
                                ziyaret
                                    ? 'Ayağına kadar getirdim, tepsi taze!'
                                    : (indirimliGun
                                        ? 'Bugün stok eritiyorum abi, fiyatlar dibde!'
                                        : 'Gel bakalım, bugün elimde bunlar var.'),
                                style: const TextStyle(fontSize: 11, color: Colors.white60, height: 1.25)),
                              const SizedBox(height: 4),
                              Row(children: [
                                const Text('💰 ', style: TextStyle(fontSize: 11)),
                                Text('${_state.para}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00FF88))),
                                if (_state.tamirSetiAdet > 0) ...[
                                  const Text('   🔧 ', style: TextStyle(fontSize: 11)),
                                  Text('${_state.tamirSetiAdet}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF58a6ff))),
                                ],
                              ]),
                            ],
                          ),
                        ),
                      ]),
                    ),
                    // ── Sekmeler: Tezgâh / Envanter ──
                    // Rıza kapıdayken oyuncunun envanteri de görebilmesi lazım;
                    // yer açmak için bir şey satmak/tamir etmek gerekebiliyor.
                    // ⚠️ Geçiş TEK YÖNLÜ tasarlandı: envanterin kendi
                    // popup'ından toptancıya geçiş YOK — alışveriş yalnızca
                    // Rıza kapıya geldiğinde açılmalı.
                    Row(children: [
                      _toptanciSekme('🛒 Tezgâh', !_toptanciEnvanterSekmesi,
                          () => setDlg(() => _toptanciEnvanterSekmesi = false)),
                      _toptanciSekme('📦 Envanter', _toptanciEnvanterSekmesi,
                          () => setDlg(() => _toptanciEnvanterSekmesi = true)),
                    ]),
                    if (_toptanciEnvanterSekmesi)
                      Flexible(child: _envanterGovdesi(baslikGoster: false))
                    else
                    // ── Stok ──
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                        child: Column(children: [
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.82),
                            itemCount: _state.toptanciStok.length,
                            itemBuilder: (c, i) => _toptanciKart(i, setDlg),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            indirimliGun ? '🔥 Kampanya bugün geçerli — yarın stok yenilenir.'
                                         : 'Stok her gün yenilenir.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, color: indirimliGun ? const Color(0xFFd29922) : Colors.white30)),
                        ]),
                      ),
                    ),
                    // ── Kapat: scroll ALANININ DIŞINDA, hep görünür ──
                    // Eskiden listenin sonundaydı; stok uzun olunca oyuncu
                    // butonu görmek için aşağı kaydırmak zorunda kalıyordu.
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1a1008),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                        border: Border(top: BorderSide(color: const Color(0xFFd29922).withValues(alpha: 0.25))),
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Panel.ikincilZemin, foregroundColor: Panel.yazi,
                          minimumSize: const Size(double.infinity, 42),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: const BorderSide(color: Panel.ikincilKenar),
                        ),
                        child: const Text('Kapat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _toptanciKart(int index, void Function(void Function()) setDlg) {
    final t = _state.toptanciStok[index];
    final alinabilir = !t.satildi && _state.para >= t.fiyat;

    // Tipine göre görünüm
    late final Widget gorselW;
    late final String isim;
    late final String altBilgi;
    late final Color renk;
    // Tezgâhtaki HER kart aynı sarı çerçeve ve sarı butonla çizilir. Eskiden
    // kart rengi ürün tipinden geliyordu (mavi/mor/kırmızı/sarı) ve tezgâh
    // rengarenk görünüyordu. `renk` hâlâ tipe özel — sadece alt bilgi yazısında
    // kullanılıyor (ör. "ÇÜRÜK · Tamir edilebilir" kırmızı kalsın).
    const tezgahRenk = Color(0xFFd29922);
    switch (t.tip) {
      case ToptanciTip.tamirSeti:
        gorselW = const Center(child: Text('🔧', style: TextStyle(fontSize: 42)));
        isim = 'CD Tamir Seti';
        altBilgi = '5 kullanım';
        renk = const Color(0xFF58a6ff);
        break;
      case ToptanciTip.kapaliKutu:
        gorselW = const Center(child: Text('🎁', style: TextStyle(fontSize: 42)));
        isim = 'Kapalı Kutu';
        altBilgi = 'İçinde ne var?';
        renk = const Color(0xFFa371f7);
        break;
      case ToptanciTip.curukUrun:
        gorselW = Stack(children: [
          Positioned.fill(child: Opacity(opacity: 0.55, child: Image.asset(t.item!.gorsel, fit: BoxFit.contain))),
          Positioned(top: 0, left: 0, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: const Color(0xFFcc3311), borderRadius: BorderRadius.circular(3)),
            child: const Text('ÇÜRÜK', style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.white)),
          )),
        ]);
        isim = t.item!.name;
        altBilgi = 'Tamir edilebilir';
        renk = const Color(0xFFcc3311);
        break;
      case ToptanciTip.urun:
        gorselW = Image.asset(t.item!.gorsel, fit: BoxFit.contain);
        isim = t.item!.name;
        altBilgi = t.item!.kondisyonYildiz;
        renk = const Color(0xFFd29922);
        break;
    }

    return Opacity(
      opacity: t.satildi ? 0.35 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF1c1610),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tezgahRenk.withValues(alpha: t.satildi ? 0.2 : 0.5), width: 1.2),
        ),
        child: Column(children: [
          // Gerçek bir ürün görseli varsa (tamir seti / kapalı kutu emoji
          // değilse) dokununca büyür — envanterdekiyle aynı davranış.
          Expanded(
            child: t.item == null
                ? gorselW
                : GestureDetector(
                    onTap: () => _urunGorseliBuyut(t.item!.gorsel, oynanabilir: t.item!.oynanabilir),
                    child: gorselW,
                  ),
          ),
          const SizedBox(height: 3),
          Text(isim, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70)),
          Text(altBilgi, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 8, color: renk)),
          const SizedBox(height: 4),
          SizedBox(
            height: 26,
            width: double.infinity,
            child: t.satildi
              ? Center(child: Text('SATILDI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white24)))
              : ElevatedButton(
                  onPressed: alinabilir ? () {
                    final hata = _state.toptanciSatinAl(index);
                    if (hata != null) {
                      SesServisi.hata();
                      _dialogBildirim(context, hata, hata: true);
                    }
                    setDlg(() {});
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tezgahRenk, foregroundColor: Colors.black,
                    disabledBackgroundColor: const Color(0xFF2a2a2a),
                    disabledForegroundColor: Colors.white24,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: Text('${t.fiyat}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
          ),
        ]),
      ),
    );
  }

  /// Hedefler ekranının tepesi: bugünün hedefi + aktif olay + seri
  Widget _bugunPaneli() {
    final h = _state.gunlukHedef;
    final olay = GunOlayi.bul(_state.gunlukOlayId);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1226),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.45), width: 1.2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${_state.gun}. GÜN', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFFD700), letterSpacing: 1)),
          const Spacer(),
          if (_state.kombo >= 2)
            Text('🔥 ${_state.kombo}\'lü seri', style: const TextStyle(fontSize: 11, color: Color(0xFFFF8C00), fontWeight: FontWeight.bold)),
        ]),
        if (h != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            Text(h.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h.baslik, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                color: h.tamamlandi ? const Color(0xFF3fb950) : Colors.white70)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: h.oran, minHeight: 5, backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation(h.tamamlandi ? const Color(0xFF3fb950) : const Color(0xFFFFD700)),
                ),
              ),
              const SizedBox(height: 3),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${h.ilerleme} / ${h.hedef}', style: const TextStyle(fontSize: 9, color: Colors.white30)),
                Text(h.tamamlandi ? '✅ +${h.odul} alındı' : '🎁 +${h.odul}',
                  style: TextStyle(fontSize: 9, color: h.tamamlandi ? const Color(0xFF3fb950) : Colors.white38)),
              ]),
            ])),
          ]),
        ],
        if (olay != null) ...[
          const SizedBox(height: 9),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 7),
          Text('${olay.emoji}  ${olay.baslik}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
          const SizedBox(height: 5),
          _olayEtkiCipleri(olay),
        ],
      ]),
    );
  }

  /// Koleksiyon: hangi ürünleri en az bir kez sattın?
  /// 📚 Koleksiyon sekmesi: 6×10 ızgara + altında koleksiyon hedefleri.
  ///
  /// ⚠️ Izgara ürün listesinden DEĞİL, sabit 60 kutudan oluşuyor. Koleksiyona
  /// konan ürünler sırayla kutuları dolduruyor; kalanlar boş "?" olarak
  /// duruyor. Eskiden her ürün için bir kutu vardı ve satılan her şey
  /// kendiliğinden açılıyordu.
  Widget _koleksiyonGovdesi(void Function(VoidCallback) setDlg) {
    final nesneler = _state.koleksiyonNesneleri;
    final dolu = nesneler.length;
    final yuzde = (dolu * 100 / kKoleksiyonKutuSayisi).round();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Text('📚 KOLEKSİYON',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
              color: Color(0xFF58a6ff), letterSpacing: 1)),
          const Spacer(),
          Text('$dolu / $kKoleksiyonKutuSayisi  ·  %$yuzde',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF58a6ff))),
        ]),
        const SizedBox(height: 3),
        const Text('Bir ürünü satmak yerine envanterden buraya taşıyabilirsin.',
          style: TextStyle(fontSize: 10, color: Panel.yaziSoluk)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: kKoleksiyonSutun,
            mainAxisSpacing: 6, crossAxisSpacing: 6, childAspectRatio: 1),
          itemCount: kKoleksiyonKutuSayisi,
          itemBuilder: (c, i) {
            final u = i < nesneler.length ? nesneler[i] : null;
            return Container(
              decoration: BoxDecoration(
                color: u != null ? const Color(0xFF0d2137) : Colors.black38,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: u != null
                    ? const Color(0xFF58a6ff).withValues(alpha: 0.7)
                    : Colors.white12),
              ),
              child: u != null
                ? Padding(padding: const EdgeInsets.all(3),
                    child: Image.asset(u.gorsel, fit: BoxFit.contain))
                : const Icon(Icons.question_mark, size: 16, color: Colors.white24),
            );
          },
        ),
        const SizedBox(height: 14),
        const Text('🎯 KOLEKSİYON HEDEFLERİ',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
            color: Color(0xFFd29922), letterSpacing: 1)),
        const SizedBox(height: 8),
        ...KoleksiyonHedefi.tumu.map((h) {
          final ilerleme = h.ilerleme(_state).clamp(0, h.hedef);
          final tamam = ilerleme >= h.hedef;
          final odulAlindi = _state.koleksiyonOdulAlinan.contains(h.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: tamam ? const Color(0xFF14200f) : const Color(0xFF16131c),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: tamam
                    ? const Color(0xFF3fb950).withValues(alpha: 0.7)
                    : Colors.white12),
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(h.baslik, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                    color: tamam ? const Color(0xFF3fb950) : Panel.yazi)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: h.hedef == 0 ? 1 : ilerleme / h.hedef,
                      minHeight: 5,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation(
                        tamam ? const Color(0xFF3fb950) : const Color(0xFF58a6ff)),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text('$ilerleme / ${h.hedef}',
                    style: const TextStyle(fontSize: 9, color: Colors.white30)),
                ])),
                const SizedBox(width: 8),
                Column(children: [
                  Text('🎁 ${h.odul}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                      color: tamam ? const Color(0xFF3fb950) : Colors.white38)),
                  if (odulAlindi)
                    const Text('alındı', style: TextStyle(fontSize: 8, color: Colors.white24)),
                ]),
              ]),
            ),
          );
        }),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HEDEFLER — bugünün hedefi, rozetler, koleksiyon
  // ═══════════════════════════════════════════════════════════════════════════
  /// Hedefler — browser sayfası gövdesi.
  Widget _hedeflerGovdesi(void Function(VoidCallback) setDlg) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Sekmeler: HEDEFLER / KOLEKSİYON ──
        Row(children: [
          Expanded(child: _hedefSekmeButonu('🏆 HEDEFLER', 0, setDlg)),
          const SizedBox(width: 8),
          Expanded(child: _hedefSekmeButonu('📚 KOLEKSİYON', 1, setDlg)),
        ]),
        const SizedBox(height: 12),
        if (_hedefSekme == 1)
          _koleksiyonGovdesi(setDlg)
        else
          // +1 bugün paneli (başta)
          // ⚠️ ListView değil: browser içeriği zaten kaydırılabilir bir
          // SingleChildScrollView; iç içe iki kaydırma alanı istemiyoruz.
          ...List.generate(Rozet.tumu.length + 1, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _hedefSatiri(i),
          )),
      ],
    );
  }

  /// Hedefler sayfasının üstündeki iki sekmeden biri.
  Widget _hedefSekmeButonu(String etiket, int idx, void Function(VoidCallback) setDlg) {
    final aktif = _hedefSekme == idx;
    return GestureDetector(
      onTap: () { SesServisi.dokun(); setDlg(() => _hedefSekme = idx); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: aktif ? const Color(0xFF2a1d3d) : Panel.ikincilZemin,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: aktif ? const Color(0xFFa371f7) : Panel.ikincilKenar,
            width: aktif ? 1.5 : 1),
        ),
        child: FittedBox(fit: BoxFit.scaleDown, child: Text(etiket,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: aktif ? const Color(0xFFa371f7) : Panel.yaziSoluk))),
      ),
    );
  }

  /// Hedefler listesinin tek satırı: 0 → bugün paneli, son → koleksiyon,
  /// aradakiler rozet kartı.
  Widget _hedefSatiri(int i) {
    if (i == 0) return _bugunPaneli();
    final r = Rozet.tumu[i - 1];
    final kazanildi = _state.rozetVar(r.id);
    final ilerleme = _state.rozetIlerleme(r.id).clamp(0, r.hedefDeger);
    final oran = r.hedefDeger == 0 ? 1.0 : ilerleme / r.hedefDeger;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kazanildi ? const Color(0xFF1d1630) : const Color(0xFF16131c),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: kazanildi ? const Color(0xFFa371f7).withValues(alpha: 0.7) : Colors.white12,
          width: kazanildi ? 1.4 : 1),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Opacity(opacity: kazanildi ? 1.0 : 0.30,
          child: Text(r.emoji, style: const TextStyle(fontSize: 28))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(r.baslik,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                color: kazanildi ? const Color(0xFFa371f7) : Colors.white54))),
            if (kazanildi) const Text('✓', style: TextStyle(fontSize: 14, color: Color(0xFF3fb950), fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 2),
          Text(r.hedefAciklama, style: const TextStyle(fontSize: 10, color: Colors.white38)),
          const SizedBox(height: 5),
          // İlerleme çubuğu
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: oran.toDouble().clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation(
                kazanildi ? const Color(0xFF3fb950) : const Color(0xFFa371f7)),
            ),
          ),
          const SizedBox(height: 3),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('$ilerleme / ${r.hedefDeger}',
              style: const TextStyle(fontSize: 9, color: Colors.white30)),
            Flexible(child: Text('🎁 ${r.odul}', textAlign: TextAlign.right, maxLines: 2,
              style: TextStyle(fontSize: 9,
                color: kazanildi ? const Color(0xFF3fb950) : Colors.white38))),
          ]),
        ])),
      ]),
    );
  }

  void _imacDetayPopup() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final yeterliPara = _state.para >= 2000;
          return AlertDialog(
            backgroundColor: const Color(0xFF1a1008),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFf78166), width: 1.5),
            ),
            title: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('🖥️ ', style: TextStyle(fontSize: 24)),
              Text('iMac', style: TextStyle(color: Color(0xFFf78166), fontSize: 20, fontWeight: FontWeight.bold)),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🖥️', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161b22),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Text(
                    'Bu, gelişmiş bir bilgisayardır. Birçok işini kolaylaştırır.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                  ),
                ),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Fiyat:', style: TextStyle(color: Colors.white54, fontSize: 14)),
                  const Text('2000', style: TextStyle(color: Color(0xFFf78166), fontSize: 18, fontWeight: FontWeight.bold)),
                ]),
                if (!yeterliPara) ...[
                  const SizedBox(height: 8),
                  const Text('Yetersiz bakiye!', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                ],
              ],
            ),
            actions: [
              Row(children: [
                Expanded(child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Panel.ikincilZemin,
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Panel.ikincilKenar),
                  ),
                  child: const Text('Çıkış', style: TextStyle(fontWeight: FontWeight.bold)),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                  onPressed: (_state.imacSatinAlindi || !yeterliPara) ? null : () {
                    _state.imacSatin();
                    Navigator.pop(ctx);
                    Future.delayed(const Duration(milliseconds: 200), () {
                      if (!mounted) return;
                      showDialog(
                        context: context,
                        builder: (c) => AlertDialog(
                          backgroundColor: const Color(0xFF1a1008),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFFFD700), width: 2),
                          ),
                          title: const Text('🖥️', textAlign: TextAlign.center, style: TextStyle(fontSize: 40)),
                          content: const Text('Yeni iMac hayırlı olsun!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFFF5E6C8), fontSize: 17, fontWeight: FontWeight.bold)),
                          actions: [Center(child: ElevatedButton(
                            onPressed: () => Navigator.pop(c),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black),
                            child: const Text('Teşekkürler!', style: TextStyle(fontWeight: FontWeight.bold)),
                          ))],
                        ),
                      );
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFf78166),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.grey.withValues(alpha: 0.55),
                    disabledForegroundColor: Colors.white.withValues(alpha: 0.85),
                  ),
                  child: Text(
                    _state.imacSatinAlindi ? 'Alındı ✅' : 'Satın Al',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                )),
              ]),
            ],
          );
        },
      ),
    );
  }

  /// Ayarlar satırı: solda etiket, sağda iki segmentli Açık/Kapalı switch.
  /// "AÇIK/KAPALI" tek kelimeyken hangi durumda olduğu ve dokununca ne
  /// olacağı belirsizdi; iki segment yan yana, aktif olan renkli duruyor.
  static Widget _ayarSatiri({
    required String etiket,
    required bool deger,
    required ValueChanged<bool> onDegis,
  }) {
    Widget segment(String metin, bool bu, Color renk) {
      final secili = deger == bu;
      return GestureDetector(
        onTap: () => onDegis(bu),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: secili ? renk : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(metin,
            style: TextStyle(
              color: secili ? Colors.white : Colors.white38,
              fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(etiket, style: const TextStyle(fontSize: 16, color: Color(0xFFF0DFC4), fontWeight: FontWeight.bold)),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            // Switch yuvası: panelden bir ton koyu kahve (lacivert gri değil).
            color: const Color(0xFF2A2018),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: Colors.black26),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            segment('Açık', true, const Color(0xFF2E9E2E)),
            segment('Kapalı', false, const Color(0xFFA02020)),
          ]),
        ),
      ],
    );
  }

  void _ayarlarPopup() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Panel.zemin,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFd2a679), width: 1.5),
          ),
          title: const Text('⚙️ Ayarlar', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF0DFC4), letterSpacing: 1)),
          // Ses ve Titreşim AYRI ayarlar: sessiz oynayan biri titreşimi
          // isteyebilir. İkisi de aynı iki segmentli switch dilinde.
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _ayarSatiri(
              etiket: '🔊 Ses:',
              deger: SesServisi.sesAcik,
              onDegis: (v) => setDialogState(() { SesServisi.sesAcik = v; AyarServisi.kaydet(); }),
            ),
            const SizedBox(height: 14),
            _ayarSatiri(
              etiket: '📳 Titreşim:',
              deger: SesServisi.titresimAcik,
              // Açılırken hemen bir titreşim ver: ayarın ne yaptığı anlaşılsın.
              onDegis: (v) => setDialogState(() {
                SesServisi.titresimAcik = v;
                AyarServisi.kaydet();
                if (v) SesServisi.dokun();
              }),
            ),
          ]),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          // Ana eylem SOLDA: buradaki asıl çıkış "Kapat" (Ayarlar'ı VE altındaki
          // browser'ı birlikte kapatır); "Geri" sadece Ayarlar'ı kapatıp
          // browser menüsüne döner.
          actions: [dialogButonlari(
            anaEtiket: 'Kapat',
            anaRenk: const Color(0xFFd2a679),
            anaOnTap: () { Navigator.pop(ctx); Navigator.pop(context); },
            ikincilEtiket: 'Geri',
            ikincilOnTap: () => Navigator.pop(ctx),
          )],
        ),
      ),
    );
  }

  /// Browser'da açık olan sayfa. Menü dışındaki sayfalar aynı pencerede
  /// açılır; geri oku menüye döndürür.
  _BrowserSayfa _browserSayfa = _BrowserSayfa.menu;

  /// Adres çubuğunda görünecek metin (browser.png'deki yazının üstüne biner).
  String _browserAdres(_BrowserSayfa s) {
    switch (s) {
      case _BrowserSayfa.menu:      return 'oyuncu_dukkani';
      case _BrowserSayfa.dukkanlar: return 'kiralik_dukkanlar';
      case _BrowserSayfa.satilik:   return 'satilik_dukkanlar';
      case _BrowserSayfa.hedefler:  return 'hedefler';
      case _BrowserSayfa.market:    return 'market';
      case _BrowserSayfa.banka:     return 'banka_kredisi';
    }
  }

  void _browserPopup() {
    _browserSayfa = _BrowserSayfa.menu; // her açılışta ana sayfa
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final menude = _browserSayfa == _BrowserSayfa.menu;
          void git(_BrowserSayfa s) => setDlg(() => _browserSayfa = s);
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            // ⚠️ SABİT yükseklik — eskiden ConstrainedBox(maxHeight:) kullanılıyordu,
            // Column mainAxisSize.min ile içerik kısaysa (ör. Banka) pencere
            // küçülüyordu. Artık SizedBox ile yükseklik SABİT, Column
            // mainAxisSize.max ile o yüksekliği dolduruyor, ortadaki
            // SingleChildScrollView Expanded ile kalan alanı her sayfada
            // aynı şekilde kaplıyor.
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.75,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF0d1117),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF30363d), width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // ── Browser başlığı: görsel + adres yazısı + geri oku ──
                    // browser.png'de adres ("oyuncu_dukkani") ve oklar ÇİZİLİ.
                    // Sayfaya göre değişebilmesi için üstüne bindiriliyor.
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                      child: SizedBox(
                        height: 110,
                        width: double.infinity,
                        child: Stack(children: [
                          Positioned.fill(
                            child: Image.asset('assets/browser.png', fit: BoxFit.cover, alignment: Alignment.topCenter),
                          ),
                          // Adres metni — görseldeki yazıyı beyazla örtüp yenisini yazar
                          Positioned(
                            left: 0, right: 0, top: 52, height: 26,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 96, right: 22),
                              child: Container(
                                color: Colors.white,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _browserAdres(_browserSayfa),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF202124), fontSize: 14,
                                    fontWeight: FontWeight.w500, letterSpacing: 0.1),
                                ),
                              ),
                            ),
                          ),
                          // Geri oku — menüde değilken sarı ve tıklanabilir
                          Positioned(
                            left: 4, top: 46, width: 40, height: 38,
                            child: GestureDetector(
                              onTap: menude ? null : () => git(_BrowserSayfa.menu),
                              child: Container(
                                color: Colors.white,
                                child: Center(
                                  child: Icon(Icons.arrow_back,
                                    size: 20,
                                    color: menude ? const Color(0xFFBDC1C6) : const Color(0xFFE6A800)),
                                ),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    // ── İçerik — Expanded: her sayfada AYNI yüksekliği kaplar ──
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        child: menude
                            ? _browserMenuGovdesi(ctx, git)
                            : _browserSayfaGovdesi(ctx, setDlg),
                      ),
                    ),
                    // ── Alt buton çubuğu — kaydırma alanının DIŞINDA, sabit ──
                    // Menüde sadece Kapat; alt sayfalarda Geri + Kapat.
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Color(0xFF30363d))),
                      ),
                      child: Row(children: [
                        if (!menude) ...[
                          Expanded(child: ElevatedButton(
                            onPressed: () => git(_BrowserSayfa.menu),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Panel.ikincilZemin,
                              foregroundColor: const Color(0xFFE6A800),
                              minimumSize: const Size(0, 42),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              side: const BorderSide(color: Color(0xFFE6A800)),
                            ),
                            child: const Text('Geri', style: TextStyle(fontWeight: FontWeight.bold)),
                          )),
                          const SizedBox(width: 10),
                        ],
                        Expanded(child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Panel.ikincilZemin,
                            foregroundColor: Colors.white70,
                            minimumSize: const Size(0, 42),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            side: const BorderSide(color: Panel.ikincilKenar),
                          ),
                          child: const Text('Kapat', style: TextStyle(fontWeight: FontWeight.bold)),
                        )),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Browser ana sayfası — bölüm listesi.
  Widget _browserMenuGovdesi(BuildContext ctx, void Function(_BrowserSayfa) git) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hedefler EN ÜSTTE: oyuncunun en sık baktığı yer.
        _browserMenuItem(
          ikon: '🏆',
          baslik: 'Hedefler',
          altyazi: '${_state.kazanilanRozetler.length}/${Rozet.tumu.length} rozet · '
                   '${_state.koleksiyondakiler.length}/$kKoleksiyonKutuSayisi koleksiyon',
          renk: const Color(0xFFa371f7),
          onTap: () => git(_BrowserSayfa.hedefler),
        ),
        const SizedBox(height: 10),
        _browserMenuItem(
          ikon: '🏠',
          baslik: 'Kiralık Dükkanlar',
          altyazi: 'DükkanKirala.com — ${_state.aktifDukkan.isim}',
          renk: const Color(0xFF58a6ff),
          onTap: () => git(_BrowserSayfa.dukkanlar),
        ),
        const SizedBox(height: 10),
        _browserMenuItem(
          // Anahtar yerine ev: burada satılan şey dükkan, anahtar soyut kalıyordu.
          ikon: '🏡',
          baslik: 'Satılık Dükkanlar',
          altyazi: _state.gun < 5
              ? '5. günde açılır'
              : (_state.sahipDukkanlar.isEmpty
                  ? 'Kirayı bitir, dükkanın sahibi ol'
                  : '${_state.sahipDukkanlar.length} dükkanın var'),
          renk: const Color(0xFF3fb950),
          kilitli: _state.gun < 5,
          onTap: () => git(_BrowserSayfa.satilik),
        ),
        const SizedBox(height: 10),
        _browserMenuItem(
          ikon: '🏦',
          baslik: 'Banka Kredisi',
          altyazi: _state.gun < 3
              ? '3. günde açılır'
              : (_state.aktifKrediVar
                  ? 'Aktif kredi: ${_state.krediTaksitMiktar} × ${_state.krediKalanTaksit} taksit kaldı'
                  : 'İhtiyaç kredisi başvurusu yap'),
          renk: const Color(0xFF3fb950),
          kilitli: _state.gun < 3,
          onTap: () { _bankaSayfasiHazirla(); git(_BrowserSayfa.banka); },
        ),
        // ⚠️ Toptancı Rıza BİLEREK burada yok. Alışveriş sadece Rıza kapıya
        // geldiğinde yapılabilir; menüden istediği an açmak ziyaretini
        // anlamsızlaştırıyordu.
        const SizedBox(height: 10),
        _browserMenuItem(
          ikon: '🛒',
          baslik: 'Market',
          altyazi: 'Dükkanını geliştir',
          renk: const Color(0xFFf78166),
          onTap: () => git(_BrowserSayfa.market),
        ),
        const SizedBox(height: 10),
        // 🚗 Konum Değiştir — envanterde araç YOKSA tıklanamaz.
        _browserMenuItem(
          ikon: '🚗',
          baslik: 'Konum Değiştir',
          altyazi: _state.aracVar
              ? (_gecisAktif ? 'Geçiş sürüyor...' : 'Aracınla başka bir yere git')
              : 'Envanterde 1 araç olması gerekmekte.',
          renk: const Color(0xFF4f8bd6),
          kilitli: !_state.aracVar || _gecisAktif,
          onTap: () { Navigator.pop(ctx); _konumSecPopup(); },
        ),
        const SizedBox(height: 10),
        _browserMenuItem(
          ikon: '⚙️',
          baslik: 'Ayarlar',
          altyazi: 'Ses: ${SesServisi.sesAcik ? "Açık" : "Kapalı"} · '
                   'Titreşim: ${SesServisi.titresimAcik ? "Açık" : "Kapalı"}',
          renk: const Color(0xFFd2a679),
          onTap: () => _ayarlarPopup(),
        ),
        const SizedBox(height: 10),
        _browserMenuItem(
          ikon: '🔄',
          baslik: 'Yeniden Başlat',
          altyazi: 'Oyunu sıfırla ve başa dön',
          renk: const Color(0xFFE07B00),
          onTap: () { Navigator.pop(ctx); _yenidenBaslatOnay(); },
        ),
      ],
    );
  }

  /// Browser'da açılan alt sayfanın gövdesi.
  Widget _browserSayfaGovdesi(BuildContext ctx, void Function(VoidCallback) setDlg) {
    switch (_browserSayfa) {
      case _BrowserSayfa.dukkanlar:
        return _dukkanlarGovdesi(() => Navigator.pop(ctx));
      case _BrowserSayfa.satilik:
        return _satilikDukkanlarGovdesi(ctx, setDlg);
      case _BrowserSayfa.hedefler:
        return _hedeflerGovdesi(setDlg);
      case _BrowserSayfa.market:
        return _marketGovdesi(ctx);
      case _BrowserSayfa.banka:
        return _bankaGovdesi(ctx, setDlg);
      case _BrowserSayfa.menu:
        return const SizedBox.shrink();
    }
  }

  void _yenidenBaslatOnay() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1008),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE07B00), width: 2),
        ),
        title: const Text('⚠️ Emin misin?', textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFE07B00), fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text(
          'Her şey kaybolacak!\nAna menüye dönülsün mü?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Panel.yazi, fontSize: 15),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          dialogButonlari(
            anaEtiket: 'Evet',
            anaRenk: const Color(0xFFE07B00),
            anaYazi: Colors.white,
            anaOnTap: () {
              Navigator.pop(ctx);
              KayitServisi.sil();
              // ⚠️ Yeni oyunu doğrudan başlatmıyoruz: oyuncu ANA MENÜYE dönsün.
              // Oradan "Başla"ya kendisi bassın — "Devam Et" de artık pasif olur.
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AnaMenuEkrani()),
                (route) => false,
              );
            },
            ikincilEtiket: 'Hayır',
            ikincilOnTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Widget _browserMenuItem({
    required String ikon,
    required String baslik,
    required String altyazi,
    required Color renk,
    required VoidCallback onTap,
    bool kilitli = false,
  }) {
    // Kilitli satır: soluk, tıklanamaz, sağda kilit ikonu. Gizlemek yerine
    // göstermek daha iyi — oyuncu neyin açılacağını görsün.
    final opak = kilitli ? 0.40 : 1.0;
    return Opacity(
      opacity: opak,
      child: GestureDetector(
        onTap: kilitli ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF161b22),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: renk.withValues(alpha: 0.35), width: 1),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: renk.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Text(ikon, style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(baslik, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: renk)),
              const SizedBox(height: 3),
              Text(altyazi, style: const TextStyle(fontSize: 11, color: Colors.white38)),
            ])),
            Icon(kilitli ? Icons.lock : Icons.chevron_right,
                color: renk.withValues(alpha: 0.6), size: 20),
          ]),
        ),
      ),
    );
  }

  // ── BANKA KREDİSİ — browser sayfası ─────────────────────────────────────
  // Sayfa her karede yeniden çizildiği için tutar/taksit seçimi widget'ın
  // içinde tutulamaz; _GameScreenState alanlarında duruyor ve sayfaya
  // girilirken _bankaSayfasiHazirla() ile bir kez kuruluyor.
  int _krediTutar = 500;
  int _krediTaksit = 2;

  static const int _krediMinTutar = 500;
  static const int _krediMinTaksit = 2;

  /// Gün çarpanı: oyun ilerledikçe banka daha yüksek limit veriyor.
  int get _krediCarpan {
    final g = _state.gun;
    return g <= 5 ? 1 : g <= 10 ? 2 : g <= 20 ? 3 : 4;
  }

  int get _krediMaxTutar => 3000 * _krediCarpan;

  /// Taksit limiti önceki kredi geçmişine göre açılır.
  /// İlk kredide 3 çok azdı — taban 6'ya çıkarıldı.
  int get _krediMaxTaksit {
    final t = _state.tamamlananKrediSayisi;
    return t == 0 ? 6 : t == 1 ? 8 : 10;
  }

  /// Faiz: her ek taksit %5 (2 taksit = %5 … 9 taksit = %40)
  int _krediGeriOdeme(int tutar, int taksit) =>
      (tutar * (1.0 + 0.05 * (taksit - 1))).round();

  void _bankaSayfasiHazirla() {
    final rng = Random();
    final baseSteps = 10 + rng.nextInt(21); // 10..30 → 1000..3000
    _krediTutar = (baseSteps * 100 * _krediCarpan).clamp(_krediMinTutar, _krediMaxTutar);
    _krediTaksit = _krediMinTaksit;
  }

  /// Banka — browser sayfası gövdesi.
  Widget _bankaGovdesi(BuildContext ctx, void Function(VoidCallback) setD) {
    // Aktif kredi varken yeni başvuru alınmaz
    if (_state.aktifKrediVar) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🏦 AKTİF KREDİ VAR',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.orangeAccent, fontSize: 16,
                fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 14),
        Text(
          'Hâlâ aktif bir krediniz var.\n\n'
          '${_state.krediTaksitMiktar} × ${_state.krediKalanTaksit} taksit kaldı.\n\n'
          'Krediniz bitince yeni başvuru yapabilirsiniz.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ]);
    }

    final gun = _state.gun;
    final carpan = _krediCarpan;
    final maxTutar = _krediMaxTutar;
    final maxTaksit = _krediMaxTaksit;
    final geriOdeme = _krediGeriOdeme(_krediTutar, _krediTaksit);
    final gunlukKesinti = (geriOdeme / _krediTaksit).ceil();
    final faizPct = 5 * (_krediTaksit - 1);

    Widget okBtn(IconData icon, Color color, VoidCallback? onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: onTap != null ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: onTap != null ? color.withValues(alpha: 0.5) : Colors.white12),
          ),
          child: Icon(icon, color: onTap != null ? color : Colors.white24, size: 22),
        ),
      );
    }

    // Etiket + ▼ değer ▲ satırı
    Widget ayarSatiri({
      required String label,
      required String value,
      required Color color,
      required VoidCallback? onDown,
      required VoidCallback? onUp,
    }) {
      return Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12))),
        okBtn(Icons.arrow_drop_down, color, onDown),
        const SizedBox(width: 4),
        SizedBox(
          width: 80,
          child: Text(value, textAlign: TextAlign.center,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        const SizedBox(width: 4),
        okBtn(Icons.arrow_drop_up, color, onUp),
      ]);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('🏦 ', style: TextStyle(fontSize: 22)),
          Text('Banka Kredisi',
              style: TextStyle(color: Color(0xFF3fb950), fontSize: 19, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 14),
        // Çarpan rozeti
        if (carpan > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Text(
                '${carpan}x kredi limiti aktif · $gun. gün',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ayarSatiri(
          label: 'Kredi tutarı:',
          value: '$_krediTutar ₺',
          color: const Color(0xFF3fb950),
          onDown: _krediTutar > _krediMinTutar ? () => setD(() => _krediTutar -= 100) : null,
          onUp: _krediTutar < maxTutar ? () => setD(() => _krediTutar += 100) : null,
        ),
        const SizedBox(height: 8),
        ayarSatiri(
          label: 'Taksit:',
          value: '$_krediTaksit gün',
          color: Colors.orangeAccent,
          onDown: _krediTaksit > _krediMinTaksit ? () => setD(() => _krediTaksit--) : null,
          onUp: _krediTaksit < maxTaksit ? () => setD(() => _krediTaksit++) : null,
        ),
        const SizedBox(height: 14),
        // Özet kutusu
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF161b22),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF3fb950).withValues(alpha: 0.3)),
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Alacaksınız:', style: TextStyle(color: Colors.white54, fontSize: 12)),
              Text('+$_krediTutar ₺',
                  style: const TextStyle(color: Color(0xFF3fb950), fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Toplam ödeme (%$faizPct faiz):',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
              Text('$geriOdeme ₺', style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ]),
            const Divider(color: Colors.white12, height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Günlük kesinti:', style: TextStyle(color: Colors.white54, fontSize: 12)),
              Text('-$gunlukKesinti ₺/gün',
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: () {
            final tutar = _krediTutar;
            Navigator.pop(ctx); // browser'ı kapat
            _state.krediAl(tutar, geriOdeme, _krediTaksit);
            _krediAlindiPopup(tutar);
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3fb950), foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: const Text('Krediyi Al', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ],
    );
  }

  /// Tebrik popup'ı — 3 saniye sonra kendi kendine kapanır.
  void _krediAlindiPopup(int tutar) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx3) {
        Future.delayed(const Duration(seconds: 3), () {
          if (ctx3.mounted) Navigator.of(ctx3).pop();
        });
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1008),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF3fb950), width: 1.5),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 10),
              Text(
                'Tebrikler, $tutar ₺ kredi alındı!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF3fb950),
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _yeniDukkanPopup(String dukkanIsim) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        Future.delayed(const Duration(seconds: 3), () {
          if (ctx.mounted) Navigator.of(ctx).pop();
        });
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1008),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFFFD700), width: 2),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text(dukkanIsim,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Yeni dükkana geçildi, hayırlı olsun!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }

  /// Kiralık dükkanlar — browser sayfası gövdesi.
  /// `onKirala`: dükkan seçilince çağrılır (browser'ı kapatmak için).
  /// Satılık Dükkanlar — browser sayfası.
  ///
  /// Kiralıklardan farkı: burada dükkan SATIN ALINIR, günlük kira ödenmez.
  /// Sahip olunan bir dükkana tekrar tıklanınca "geçmek mi, kiraya vermek mi?"
  /// diye sorulur — ikinci dükkan hem yaşanacak yer hem gelir kapısı olabilir.
  Widget _satilikDukkanlarGovdesi(BuildContext ctx, void Function(VoidCallback) setDlg) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('🔑 SatilikDukkan.com', textAlign: TextAlign.center,
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF3fb950), letterSpacing: 1)),
      const SizedBox(height: 3),
      Text(
        _state.sahipDukkanlar.isEmpty
            ? 'Satın aldığın dükkanda kira ödemezsin.'
            : 'Kira geliri: ${_state.gunlukKiraGeliri}/gün',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: Colors.white38)),
      const SizedBox(height: 12),
      ...List.generate(satilikDukkanlar.length, (i) {
        final d = satilikDukkanlar[i];
        final sahip = _state.dukkanSahibiMi(d);
        final oturuyor = _state.aktifDukkan.isim == d.isim;
        final kirada = _state.kirayaVerilenDukkanlar.contains(d.isim);
        final kilitli = _state.gun < d.minGun;
        final alinabilir = !sahip && !kilitli && _state.para >= d.satinAlmaFiyati!;
        final renk = sahip ? const Color(0xFF3fb950) : const Color(0xFFFFD700);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Opacity(
            opacity: kilitli ? 0.45 : 1.0,
            child: GestureDetector(
              onTap: kilitli
                  ? null
                  : (sahip
                      ? () => _sahipDukkanSecenekleri(ctx, d, setDlg)
                      : () => _dukkanSatinAlOnay(ctx, d, setDlg)),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: oturuyor ? const Color(0xFF12200f) : const Color(0xFF161b22),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: renk.withValues(alpha: oturuyor ? 0.9 : 0.35),
                    width: oturuyor ? 1.6 : 1),
                ),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(d.arkaplan, width: 54, height: 54, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.isim, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: renk)),
                    const SizedBox(height: 2),
                    if (kilitli)
                      Text('🔒 ${d.minGun}. günde açılır',
                        style: const TextStyle(fontSize: 11, color: Colors.white38))
                    else ...[
                      Row(children: [
                        const Text('Büyüklük: ', style: TextStyle(fontSize: 10, color: Colors.white38)),
                        Text(d.yildizlar, style: const TextStyle(fontSize: 11, color: Color(0xFFFFD700))),
                      ]),
                      const SizedBox(height: 2),
                      Text(
                        sahip
                            ? (oturuyor
                                ? '✓ Burada oturuyorsun'
                                : (kirada
                                    ? '🔑 Kirada — ${GameState.kiraGeliriHesapla(d)}/gün'
                                    : 'Senin · boş duruyor'))
                            : '${d.satinAlmaFiyati} lira · kira YOK',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: sahip
                              ? const Color(0xFF3fb950)
                              : (alinabilir ? const Color(0xFF00FF88) : Colors.redAccent)),
                      ),
                    ],
                  ])),
                  if (oturuyor) const Icon(Icons.check_circle, color: Color(0xFF3fb950), size: 20)
                  else if (!kilitli) Icon(Icons.chevron_right, color: renk.withValues(alpha: 0.6), size: 20),
                ]),
              ),
            ),
          ),
        );
      }),
    ]);
  }

  /// Satın alma onayı.
  void _dukkanSatinAlOnay(BuildContext ctx, DukkanSeviye d, void Function(VoidCallback) setDlg) {
    showDialog(
      context: context,
      builder: (c2) => AlertDialog(
        backgroundColor: const Color(0xFF1a1008),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF3fb950), width: 1.5),
        ),
        title: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(d.arkaplan, width: 130, height: 90, fit: BoxFit.cover),
          ),
          const SizedBox(height: 8),
          Text(d.isim, textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF3fb950), fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          '${d.satinAlmaFiyati} liraya satın alınacak.\n\n'
          'Satın alınan dükkanda günlük kira ÖDEMEZSİN. '
          'İstersen buraya taşınır, istersen kiraya verip gelir elde edersin.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [Row(children: [
          Expanded(child: ElevatedButton(
            onPressed: () {
              final hata = _state.dukkanSatinAl(d);
              Navigator.pop(c2);
              if (hata != null) {
                SesServisi.hata();
                _dialogBildirim(ctx, hata, hata: true);
              } else {
                _dialogBildirim(ctx, '🔑 ${d.isim} senin oldu!');
                setDlg(() {});
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3fb950), foregroundColor: Colors.black,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Satın Al', style: TextStyle(fontWeight: FontWeight.bold)),
          )),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(
            onPressed: () => Navigator.pop(c2),
            style: ElevatedButton.styleFrom(
              backgroundColor: Panel.ikincilZemin, foregroundColor: Panel.yazi,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              side: const BorderSide(color: Panel.ikincilKenar)),
            child: const Text('Vazgeç', style: TextStyle(fontWeight: FontWeight.bold)),
          )),
        ])],
      ),
    );
  }

  /// Sahip olunan dükkana tıklanınca: taşın ya da kiraya ver.
  void _sahipDukkanSecenekleri(BuildContext ctx, DukkanSeviye d, void Function(VoidCallback) setDlg) {
    final oturuyor = _state.aktifDukkan.isim == d.isim;
    final kirada = _state.kirayaVerilenDukkanlar.contains(d.isim);
    showDialog(
      context: context,
      builder: (c2) => AlertDialog(
        backgroundColor: const Color(0xFF1a1008),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF3fb950), width: 1.5),
        ),
        title: Text(d.isim, textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF3fb950), fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text(
          oturuyor
              ? 'Şu an bu dükkandasın. Kiraya vermek için önce başka bir dükkana geçmelisin.'
              : (kirada
                  ? 'Bu dükkan kirada, günde ${GameState.kiraGeliriHesapla(d)} lira getiriyor.\n\n'
                    'Bu dükkana geçmek mi, kirayı sonlandırmak mı istiyorsun?'
                  : 'Bu dükkana geçmek mi kiraya vermek mi istiyorsun?'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          if (oturuyor)
            Center(child: ElevatedButton(
              onPressed: () => Navigator.pop(c2),
              style: ElevatedButton.styleFrom(
                backgroundColor: Panel.ikincilZemin, foregroundColor: Panel.yazi,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Tamam', style: TextStyle(fontWeight: FontWeight.bold)),
            ))
          else
            Row(children: [
              Expanded(child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(c2);
                  Navigator.pop(ctx); // browser'ı kapat, yeni dükkan görünsün
                  _state.dukkanDegistir(d);
                  _yeniDukkanPopup(d.isim);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3fb950), foregroundColor: Colors.black,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('Buraya Geç', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                onPressed: () {
                  _state.kirayaVerToggle(d);
                  Navigator.pop(c2);
                  setDlg(() {});
                  _dialogBildirim(ctx, kirada
                      ? '🔑 Kira sonlandırıldı.'
                      : '🔑 Kiraya verildi — ${GameState.kiraGeliriHesapla(d)}/gün');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFd29922), foregroundColor: Colors.black,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: Text(kirada ? 'Kirayı Bitir' : 'Kiraya Ver',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              )),
            ]),
        ],
      ),
    );
  }

  Widget _dukkanlarGovdesi(VoidCallback onKirala) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('🏠 DükkanKirala.com', textAlign: TextAlign.center,
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFFFFD700), letterSpacing: 1)),
      const SizedBox(height: 3),
      Text('Güncel dükkanın: ${_state.aktifDukkan.isim}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: Colors.white38)),
      const SizedBox(height: 12),
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: tumDukkanlar.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx2, i) {
              final d = tumDukkanlar[i];
              final aktif = d.seviye == _state.aktifDukkan.seviye;
              final kilitli = _state.gun < d.minGun; // gün gereksinimi karşılanmadı
              return Opacity(
                opacity: kilitli ? 0.50 : 1.0,
                child: GestureDetector(
                  onTap: kilitli ? null : () {
                    if (aktif) return; // zaten bu dükkanda
                    _state.dukkanDegistir(d);
                    onKirala();
                    _yeniDukkanPopup(d.isim);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: aktif ? const Color(0xFFFFD700).withValues(alpha: 0.15) : const Color(0xFF2a1a0a),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: aktif ? const Color(0xFFFFD700) : (kilitli ? Colors.white12 : Colors.white24),
                        width: aktif ? 2 : 1,
                      ),
                    ),
                    child: Row(children: [
                      // Dükkan ikonu
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1a1008),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Center(child: Text(
                          kilitli ? '🔒' : ['🏚️','🏠','🏪','🏬','🏢'][i],
                          style: const TextStyle(fontSize: 24),
                        )),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.isim, style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold,
                          color: aktif ? const Color(0xFFFFD700) : Colors.white)),
                        const SizedBox(height: 3),
                        if (kilitli)
                          Text('🔒 ${d.minGun}. günde açılır',
                            style: const TextStyle(fontSize: 11, color: Colors.white38))
                        else ...[
                          Row(children: [
                            const Text('Büyüklük: ', style: TextStyle(fontSize: 11, color: Colors.white38)),
                            Text(d.yildizlar, style: const TextStyle(fontSize: 12, color: Color(0xFFFFD700))),
                          ]),
                          const SizedBox(height: 2),
                          Row(children: [
                            const Text('Kira: ', style: TextStyle(fontSize: 11, color: Colors.white38)),
                            Text('${d.kira}/gün', style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 2),
                          Row(children: [
                            const Text('Müşteri: ', style: TextStyle(fontSize: 11, color: Colors.white38)),
                            Text('${10 + (d.seviye - 1) * 5}-${15 + (d.seviye - 1) * 5}/gün',
                              style: const TextStyle(fontSize: 11, color: Colors.white60)),
                          ]),
                        ],
                      ])),
                      if (aktif) const Icon(Icons.check_circle, color: Color(0xFFFFD700), size: 20),
                    ]),
                  ),
                ),
              );
        },
      ),
    ]);
  }

  /// Kapıda bekleyen silüet.
  ///
  /// Eskiden `biri.png` tam ekran `BoxFit.cover` ile basılıyordu ve kapının
  /// yeri görsele gömülüydü. Dükkan başına farklı arka plan gelince silüet
  /// kapının yanına düştü. Artık sprite (`kapidaki.png`), arka planın ekrandaki
  /// `cover` kutusu hesaplanıp o dükkanın kapı oranlarına yerleştiriliyor —
  /// yani sahnedeki diğer her şey gibi, sabit piksel yok.
  Widget _buildKapidaki() {
    return LayoutBuilder(builder: (context, kutu) {
      final d = _state.aktifDukkan;
      final sw = kutu.maxWidth, sh = kutu.maxHeight;
      // BoxFit.cover + Alignment.center: iki eksenden büyük ölçek kazanır,
      // taşan kısım iki yandan eşit kırpılır.
      final gorselOrani = d.arkaplanOrani;          // en / boy
      final ekranOrani  = sw / sh;
      final double dw, dh;
      if (ekranOrani > gorselOrani) {               // ekran daha geniş → ene sığdır
        dw = sw; dh = sw / gorselOrani;
      } else {                                      // ekran daha dar → boya sığdır
        dh = sh; dw = sh * gorselOrani;
      }
      final sol = (sw - dw) / 2, ust = (sh - dh) / 2;
      // Ekranda hangi arka plan varsa kapı ona göre konumlanır: güvenlikli
      // sürüm ayrı bir çizim olduğu için camı biraz kaymış olabiliyor.
      final guv = _state.guvenlikVar;
      final kapiSol = d.kapiSol + (guv ? d.kapiSolGuvFark : 0);
      final kapiUst = d.kapiUst + (guv ? d.kapiUstGuvFark : 0);
      // Kutu = kapı camı. `fill` ile silüet camı boşluksuz doldurur.
      return Stack(children: [
        Positioned(
          left:   sol + kapiSol * dw,
          top:    ust + kapiUst * dh,
          width:  d.kapiGen * dw,
          height: d.kapiYuk * dh,
          child: Image.asset('assets/kapidaki.png', fit: BoxFit.fill),
        ),
      ]);
    });
  }

  // Güvenliğin arka plan görseli İÇİNDEKİ yeri (0..1). Beş dükkanda da
  // kapının hemen sağında, neredeyse aynı yerde duruyor — tek kutu yetiyor.
  // Kutu güvenliğin figüründen biraz GENİŞ tutuldu: parmakla vurulacak bir
  // hedef, piksel hassasiyetinde olması gerekmiyor.
  static const double kGuvenlikSol = 0.45;
  static const double kGuvenlikUst = 0.11;
  static const double kGuvenlikGen = 0.21;
  static const double kGuvenlikYuk = 0.34;

  /// Görünmez dokunma kutusu: dükkanda duran güvenliğe basılınca müşteri gibi
  /// öne gelip "İşi bırakmamı ister misin?" diye sorar.
  Widget _buildGuvenlikDokunmaAlani() {
    return LayoutBuilder(builder: (context, kutu) {
      final d = _state.aktifDukkan;
      final sw = kutu.maxWidth, sh = kutu.maxHeight;
      // Kapı silüetiyle BİREBİR aynı cover matematiği — ikisi de arka planın
      // ekrandaki kutusuna kilitli olmalı, yoksa çözünürlük değişince kayarlar.
      final gorselOrani = d.arkaplanOrani;
      final ekranOrani = sw / sh;
      final double dw, dh;
      if (ekranOrani > gorselOrani) { dw = sw; dh = sw / gorselOrani; }
      else                          { dh = sh; dw = sh * gorselOrani; }
      final sol = (sw - dw) / 2, ust = (sh - dh) / 2;
      return Stack(children: [
        Positioned(
          left:   sol + kGuvenlikSol * dw,
          top:    ust + kGuvenlikUst * dh,
          width:  kGuvenlikGen * dw,
          height: kGuvenlikYuk * dh,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _guvenligeDokun,
            child: const SizedBox.expand(),
          ),
        ),
      ]);
    });
  }

  /// Güvenlik görevine geri dönüyor: repliği okunacak kadar beklenir, sonra
  /// beliriş animasyonu TERSİNE oynatılır (yukarı süzülüp küçülerek kaybolur).
  /// Bitince `musteriAnimasyonBitti` `_guvenlikOnde`i sıfırlar → arka plan
  /// güvenlikli sürüme döner ve güvenlik kapıdaki yerinde belirir.
  void _guvenlikYerineDon() {
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _guvenlikBelirmeController.reverse().then((_) {
        if (!mounted) return;
        _state.musteriAnimasyonBitti();
      });
    });
  }

  /// Rehber Hande'nin "Tamam" butonu: sıradaki repliğe geçer, replikler
  /// bitince Hande sağdan çıkar ve oyun normal akışına döner (kapıda müşteri
  /// beklemeye başlar).
  void _handeTamam() {
    if (!_state.handeAktif) return;
    if (_state.handeIlerle()) return; // daha anlatacağı var
    _ozelMusteriGonder();
  }

  /// Güvenliği "müşteri" olarak öne çağırır (istifa sorusu modunda).
  void _guvenligeDokun() {
    if (!_state.guvenlikVar) return;
    if (_state.aktifMusteri != null || _state.aktifOzelMusteri != null) return;
    if (_state.gunBitmeli) return;
    _state.guvenligiOneCagir();
    // ⚠️ Sağdan kaydırma YOK: `_slideController` doğrudan "ortalanmış"
    // değerine (1.0) atlatılıyor, yatay konum sabit kalıyor. Beliriş
    // yalnızca `_guvenlikBelirmeController` ile dikeyde + ölçekte oluyor.
    // Yine de değeri set etmek şart: EVET (istifa) seçilirse çıkış bu
    // controller'ın `reverse`ıyla sağa doğru oynatılıyor.
    _slideController.value = 1.0;
    _guvenlikBelirmeController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        _gunBitiKontrol();
        // 🏠 Oyuncu evdeyse dükkan sahnesi hiç çizilmez — header aynı kalır,
        // gövde ve alt bar evin kendi düzenine geçer.
        if (_state.aktifKonum != Konum.dukkan) return _buildEvEkrani();
        return Scaffold(
          body: Stack(
            children: [
              // 1. Dükkan arka planı — seviyeye göre değişir, geçiş yumuşasın
              //    diye AnimatedSwitcher ile çapraz solma yapılır.
              //
              //    ⚠️ layoutBuilder ŞART: AnimatedSwitcher'ın varsayılanı
              //    `StackFit.loose` bir Stack. Loose kısıtta Image kendi doğal
              //    boyutuna küçülür, arka plan ekranı KAPLAMAZ ve kapı silüeti
              //    (tam ekran kutuya göre konumlanıyor) kayar. expand ile
              //    çocuklar tam ekran kalır, cover eskisi gibi çalışır.
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 700),
                  layoutBuilder: (current, previous) => Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: [...previous, if (current != null) current],
                  ),
                  child: Image.asset(
                    // Güvenlik tutulduysa aynı dükkanın güvenlikli sürümü.
                    // key arka plan yoluna bağlı → güvenlik gelince/gidince
                    // AnimatedSwitcher çapraz solmayı kendiliğinden oynatır.
                    _state.aktifArkaplan,
                    key: ValueKey(_state.aktifArkaplan),
                    fit: BoxFit.cover, alignment: Alignment.center,
                  ),
                ),
              ),
              // 2. Kapı gölgesi (müşteri yokken görünür)
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: (_state.musteriGorunuyor || _state.ozelMusteriGorunuyor) ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: _buildKapidaki(),
                ),
              ),
              // ╔═══════════════════════════════════════════════════════════════╗
              // ║  KATMAN SİSTEMİ — Stack Z-order (arkadan öne)               ║
              // ║  1. arka plan        — dükkan seviyesine göre (bgbos*)       ║
              // ║  2. kapidaki.png     — kapı silüeti (müşteri yokken)         ║
              // ║  3. MÜŞTERİ görseli  — masanın ALTINDA ← BU KATMAN          ║
              // ║  4. Masa (AnimatedSwitcher: bg1/bg2/bgbosmasa)               ║
              // ║  5. SafeArea UI      — header + _buildSahne() + altbar       ║
              // ║     └─ _buildSahne() içinde: placeholder (564×564) + ÜRÜN   ║
              // ╠═══════════════════════════════════════════════════════════════╣
              // ║  MÜŞTERİ BOYUTU VE KONUMU (dış Stack — katman 3):            ║
              // ║    width: 564, height: 564  ← DOKUNMA!                       ║
              // ║      Alt kısmı masa layer'ının arkasına gizleniyor            ║
              // ║      Ekrandan taşması intentional                             ║
              // ║    hedef = (screenW - 564) / 2  ← yatayda ortalı             ║
              // ║    dx = hedef + (screenW - hedef) * slideAnim.value           ║
              // ║         ← sağdan kayarak giriş animasyonu                     ║
              // ║    musteriTop = statusBar + 48.0 + screenH * 0.14 + 44        ║
              // ║      statusBar = mq.padding.top                               ║
              // ║      48.0      = header yüksekliği (hh)                       ║
              // ║      0.14      = ekranın %14'ü                                ║
              // ║      44        = ince ayar (SON DEĞER — DOKUNMA!)             ║
              // ╚═══════════════════════════════════════════════════════════════╝
              if (_state.aktifMusteri != null || _state.aktifOzelMusteri != null)
                AnimatedBuilder(
                  animation: _slideAnim,
                  builder: (context, child) {
                    // Masa metriğine kilitli — çözünürlükten bağımsız
                    final m = SahneMetrik.hesapla(MediaQuery.of(context).size);
                    final screenW = MediaQuery.of(context).size.width;
                    final boy = m.u(kMusteriBoyu);
                    final hedef = (screenW - boy) / 2;
                    final dx = hedef + (screenW - hedef) * _slideAnim.value;
                    return Positioned(
                      left: dx, top: m.y(kMusteriUstu),
                      width: boy, height: boy,
                      child: child!,
                    );
                  },
                  // 🛡️ Güvenlik tezgâha SAĞDAN kaymaz — dükkanın içinde zaten
                  // duruyor, dışarıdan gelmiyor. Yukarıdan belirip aşağı iner
                  // ve büyür; gidişi de bunun birebir tersidir (aynı controller
                  // ters yönde). Diğer müşteriler bu dönüşümden etkilenmez.
                  child: AnimatedBuilder(
                    animation: _guvenlikBelirmeController,
                    builder: (context, child) {
                      final om = _state.aktifOzelMusteri;
                      final guvenlikOnde =
                          om != null && om.tip == OzelMusteriTip.guvenlik && om.istifaSorusu;
                      if (!guvenlikOnde) return child!;
                      // easeOut: hızlı belirip yumuşak oturur (iniş hissi)
                      final t = Curves.easeOutCubic
                          .transform(_guvenlikBelirmeController.value.clamp(0.0, 1.0));
                      return Opacity(
                        opacity: t,
                        child: Transform.translate(
                          // yukarıdan gelir: t=0'da 130px yukarıda, t=1'de yerinde
                          offset: Offset(0, -130 * (1 - t)),
                          // büyüyerek gelir
                          child: Transform.scale(scale: 0.78 + 0.22 * t, child: child),
                        ),
                      );
                    },
                    child: Image.asset(
                      _state.aktifOzelMusteri != null
                        ? _state.aktifOzelMusteri!.gorsel
                        : _state.aktifMusteri!.gorsel,
                      fit: BoxFit.contain, isAntiAlias: true, filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              // 4. Masa layer'ı (müşterinin üzerinde, SafeArea'nın altında)
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: _state.imacSatinAlindi
                    ? Align(key: const ValueKey('bg2'), alignment: Alignment.bottomCenter, child: Transform.translate(offset: const Offset(0, 6), child: Transform.scale(scale: 1.4, alignment: Alignment.bottomCenter, child: Image.asset('assets/bg2.png', fit: BoxFit.fitWidth))))
                    : (_state.gun >= 2
                      ? Align(key: const ValueKey('bg1'), alignment: Alignment.bottomCenter, child: Transform.translate(offset: const Offset(0, 6), child: Transform.scale(scale: 1.4, alignment: Alignment.bottomCenter, child: Image.asset('assets/bg1.png', fit: BoxFit.fitWidth))))
                      : Align(key: const ValueKey('bgbosmasa'), alignment: Alignment.bottomCenter, child: Transform.translate(offset: const Offset(0, 6), child: Transform.scale(scale: 1.4, alignment: Alignment.bottomCenter, child: Image.asset('assets/bgbosmasa.png', fit: BoxFit.fitWidth))))),
                ),
              ),
              SafeArea(child: Column(children: [_buildHeader(), Expanded(child: _buildSahne()), _buildAltBar()])),
              // Dükkan kiralama butonu — 3. günde bilgisayar gelince görünür
              if (_state.gun >= 2)
              Positioned(
                left: 16,
                bottom: 300,
                child: GestureDetector(
                  onTap: _browserPopup,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('🖥️', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 4),
                      Text(_state.aktifDukkan.yildizlar, style: const TextStyle(fontSize: 12, color: Color(0xFFFFD700))),
                    ]),
                  ),
                ),
              ),
              if (_envanterAcik) _buildEnvanterOverlay(),
              // 🚗 Yolculuk göstergesi — sahnenin solunda, dokunuşu yutmaz.
              _buildGecisGostergesi(),
              if (_toastMetin != null) _buildToast(),
              // 🛡️ Güvenliğe dokunma alanı — Stack'in EN SONUNDA.
              //
              // ⚠️ Sıra kritik: Stack'te sonra gelen çocuk önce hit-test edilir.
              // Bu katman arka planın hemen üstündeyken dokunuş masa
              // katmanı/SafeArea tarafından yutuluyor, güvenliğe basılamıyordu.
              // Kutu küçük ve sahnenin üst kısmında; alt bardaki butonlarla,
              // header'la ya da browser düğmesiyle çakışmıyor.
              if (_state.guvenlikVar &&
                  _state.aktifMusteri == null &&
                  _state.aktifOzelMusteri == null)
                Positioned.fill(child: _buildGuvenlikDokunmaAlani()),
            ],
          ),
        );
      },
    );
  }

  /// Gün yazısı — odometre gibi döner: eski gün yukarı çıkıp kaybolurken yeni
  /// gün alttan gelir. Para kutusundaki "sayma" burada işe yaramaz, çünkü gün
  /// hep +1 artıyor; arada gösterilecek ara değer yok.
  Widget _gunYazisi(double t, double vurgu) {
    final renk = Color.lerp(const Color(0xFFFFD700), Colors.black, vurgu);
    TextStyle stil() => TextStyle(
        fontSize: 20, fontWeight: FontWeight.w900, color: renk, height: 1.0);
    if (t == 0 || _gunEski == _gunYeni) {
      return Text('$_gunYeni. GÜN', style: stil());
    }
    // Dönüş sayım fazında tamamlanır; kalan süre renk/boyutun normale dönüşü.
    final d = Curves.easeOutCubic.transform((t / _paraSayimOrani).clamp(0.0, 1.0));
    const yuk = 26.0; // yazı kutusunun yüksekliği — taşan kısım kırpılır
    return SizedBox(
      height: yuk,
      child: ClipRect(
        child: Stack(alignment: Alignment.center, children: [
          Opacity(
            opacity: (1 - d).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -yuk * d),
              child: Text('$_gunEski. GÜN', style: stil()),
            ),
          ),
          Opacity(
            opacity: d.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, yuk * (1 - d)),
              child: Text('$_gunYeni. GÜN', style: stil()),
            ),
          ),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  🏠 EV EKRANI
  // ═══════════════════════════════════════════════════════════════════════════
  /// Evin sahnesi. Header (para + gün) dükkandakinin AYNISI — para animasyonu
  /// da olduğu gibi çalışsın diye `_buildHeader()` yeniden kullanılıyor.
  ///
  /// Eşyalar arka planın ekrandaki `BoxFit.cover` kutusuna göre konumlanır;
  /// sabit piksel yok (sahne metriğiyle aynı felsefe).
  Widget _buildEvEkrani() {
    final mekan = Mekan.bul(_state.aktifKonum);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(mekan.arkaplan,
              fit: BoxFit.cover, alignment: Alignment.center),
          ),
          Positioned.fill(child: _buildEvEsyalari(mekan)),
          SafeArea(
            child: Column(children: [
              _buildHeader(),
              const Spacer(),
              _buildEvAltBar(),
            ]),
          ),
        ],
      ),
    );
  }

  /// Satın alınmış eşyaları arka planın cover kutusuna oranlayarak çizer.
  /// Liste sırası çizim sırası — `EvEsyasi.tumu` arkadan öne dizili.
  Widget _buildEvEsyalari(Mekan mekan) {
    return LayoutBuilder(builder: (context, kis) {
      final oran = mekan.oran;
      final ekranOrani = kis.maxWidth / kis.maxHeight;
      // BoxFit.cover: hangi kenar taşıyorsa ona göre ölçeklenir.
      final double bgW, bgH;
      if (ekranOrani > oran) { bgW = kis.maxWidth; bgH = bgW / oran; }
      else { bgH = kis.maxHeight; bgW = bgH * oran; }
      final ofsX = (kis.maxWidth - bgW) / 2;
      final ofsY = (kis.maxHeight - bgH) / 2;
      return Stack(children: [
        for (final e in EvEsyasi.konumun(_state.aktifKonum))
          if (_state.evEsyalari.contains(e.id))
            // Tam tuval katmanlar (yazlık) arka planın kutusuna birebir
            // oturur — konum hesabı yok, sadece aynı kutuya serilir.
            Positioned(
              left: ofsX + e.sol * bgW,
              top: ofsY + e.ust * bgH,
              width: e.gen * bgW,
              height: e.tamKatman ? bgH : null,
              child: Image.asset(e.gorsel,
                fit: e.tamKatman ? BoxFit.fill : BoxFit.contain),
            ),
      ]);
    });
  }

  Widget _buildEvAltBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black.withValues(alpha: 0.0), Colors.black.withValues(alpha: 0.70)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Row(children: [
        Expanded(child: _oyunButon(
          emoji: '🛋️', label: 'Eşya Al',
          onTap: _evEsyaTezgahi,
          gradyan: const [Color(0xFFffd740), Color(0xFF9a6f00)],
          kenar: const Color(0xFFFFD700),
          yaziRenk: Colors.black,
        )),
        const SizedBox(width: 12),
        Expanded(child: _oyunButon(
          emoji: '🚪', label: 'Çıkış',
          onTap: () => _state.konumaGec(Konum.dukkan),
          gradyan: const [Color(0xFFe53935), Color(0xFF7f0000)],
          kenar: const Color(0xFFef9a9a),
        )),
      ]),
    );
  }

  /// Evin eşya tezgâhı — her eşya adı, görseli ve fiyatıyla listelenir.
  /// Alınan eşya "Evde" olarak işaretlenir, tekrar alınamaz.
  void _evEsyaTezgahi() {
    showDialog(
      context: context,
      builder: (ctx) => ListenableBuilder(
        listenable: _state,
        builder: (c, __) => Dialog(
          backgroundColor: Panel.zemin,
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFd29922), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_state.aktifKonum == Konum.yazlik
                    ? '🏖️ YAZLIK EŞYALARI' : '🛋️ EV EŞYALARI',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                  color: Color(0xFFd29922), letterSpacing: 1)),
              const SizedBox(height: 3),
              Text('Kasanda ${_state.para} lira var',
                style: const TextStyle(fontSize: 11, color: Panel.yaziSoluk)),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(children: EvEsyasi.konumun(_state.aktifKonum).map((e) {
                    final alindi = _state.evEsyalari.contains(e.id);
                    final parayeter = _state.para >= e.fiyat;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Opacity(
                        opacity: alindi ? 0.5 : 1.0,
                        child: GestureDetector(
                          onTap: (alindi || !parayeter) ? null : () {
                            SesServisi.dokun();
                            _state.evEsyasiAl(e);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1f1710),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: alindi
                                  ? const Color(0xFF3fb950).withValues(alpha: 0.7)
                                  : const Color(0xFFd29922).withValues(alpha: 0.55)),
                            ),
                            child: Row(children: [
                              SizedBox(width: 56, height: 48,
                                child: Image.asset(e.onizleme, fit: BoxFit.contain)),
                              const SizedBox(width: 10),
                              Expanded(child: Text(e.ad,
                                style: const TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.bold, color: Panel.yazi))),
                              Text(alindi ? '✅ Evde' : '${e.fiyat}',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                                  color: alindi
                                    ? const Color(0xFF3fb950)
                                    : (parayeter ? const Color(0xFFd29922) : Colors.white24))),
                            ]),
                          ),
                        ),
                      ),
                    );
                  }).toList()),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Panel.ikincilZemin,
                    foregroundColor: Colors.white70,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Panel.ikincilKenar)),
                  ),
                  child: const Text('Kapat',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  /// 🚗 Sahnenin SOL tarafında, yolculuk sürerken görünen küçük gösterge:
  /// aracın minik görseli ve çevresinde saat yönünün TERSİNE dönen halka.
  Widget _buildGecisGostergesi() {
    final gorsel = _gecisAracGorsel;
    if (!_gecisAktif || gorsel == null) return const SizedBox.shrink();
    return Positioned(
      left: 10,
      top: MediaQuery.of(context).size.height * 0.30,
      child: IgnorePointer(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 74, height: 74,
            child: Stack(alignment: Alignment.center, children: [
              AnimatedBuilder(
                animation: _gecisController,
                builder: (c, __) => CustomPaint(
                  size: const Size(74, 74),
                  // Negatif açı → saat yönünün tersi.
                  painter: _GecisHalkaPainter(
                    donus: -_gecisController.value * 2 * pi,
                    oran: _gecisOran),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(15),
                child: Image.asset(gorsel, fit: BoxFit.contain),
              ),
            ]),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$_gecisKalanSn sn',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                color: Color(0xFF4FC3F7))),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    final gunDecor = BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.black.withValues(alpha: 0.80), const Color(0xFF1a2a1a).withValues(alpha: 0.85)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF4caf50).withValues(alpha: 0.55), width: 1.3),
      boxShadow: [BoxShadow(color: const Color(0xFF4caf50).withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))],
    );
    final paraDecor = BoxDecoration(
      gradient: LinearGradient(
        colors: [const Color(0xFF3a2800).withValues(alpha: 0.90), const Color(0xFF1a1000).withValues(alpha: 0.90)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.70), width: 1.3),
      boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 2))],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Sol: Gün (yeni güne geçişte canlanır) ──
          Expanded(
            child: AnimatedBuilder(
              animation: _gunController,
              builder: (context, _) {
                final t = _gunController.value;
                final vurgu = t == 0
                    ? 0.0
                    : (t < _paraSayimOrani
                        ? 1.0
                        : 1.0 - ((t - _paraSayimOrani) / (1 - _paraSayimOrani)));
                final olcek = 1.0 + 0.16 * sin(pi * t.clamp(0.0, 1.0));
                final aktifDecor = vurgu == 0
                    ? gunDecor
                    : BoxDecoration(
                        color: Color.lerp(const Color(0xFF16240f), _paraYesil, vurgu),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Color.lerp(const Color(0xFF4caf50), Colors.black, vurgu * 0.75)!,
                          width: 1.3 + vurgu * 0.9),
                        boxShadow: [BoxShadow(
                          color: _paraYesil.withValues(alpha: 0.55 * vurgu),
                          blurRadius: 8 + 14 * vurgu)],
                      );
                return Transform.scale(
                  scale: olcek,
                  child: Container(
                    height: 48,
                    decoration: aktifDecor,
                    child: Center(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('🗓️', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        _gunYazisi(t, vurgu),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
          // ── Orta: Daire geri sayım (CustomPaint) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: CustomPaint(
              size: const Size(40, 40),
              painter: _DairePainter(_daireGosterilen.clamp(0.0, 1.0)),
            ),
          ),
          // ── Sağ: Bakiye (para değişiminde canlanır) ──
          Expanded(
            child: AnimatedBuilder(
              animation: _paraController,
              builder: (context, _) {
                final t = _paraController.value;
                // Vurgu: sayım boyunca tam güçte, sonunda normale solar.
                final vurgu = t == 0
                    ? 0.0
                    : (t < _paraSayimOrani
                        ? 1.0
                        : 1.0 - ((t - _paraSayimOrani) / (1 - _paraSayimOrani)));
                // Büyüyüp geri küçülme (tek tepe)
                final olcek = 1.0 + 0.16 * sin(pi * t.clamp(0.0, 1.0));
                final efektRenk = _paraArtis ? _paraYesil : _paraKirmizi;
                final aktifDecor = vurgu == 0
                    ? paraDecor
                    : BoxDecoration(
                        color: Color.lerp(const Color(0xFF2a1c00), efektRenk, vurgu),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Color.lerp(const Color(0xFFFFD700), Colors.black, vurgu * 0.75)!,
                          width: 1.3 + vurgu * 0.9),
                        boxShadow: [BoxShadow(
                          color: efektRenk.withValues(alpha: 0.55 * vurgu),
                          blurRadius: 8 + 14 * vurgu)],
                      );
                return Transform.scale(
                  scale: olcek,
                  child: Container(
                    height: 48,
                    decoration: aktifDecor,
                    child: Center(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('💰', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text('$_gosterilenPara',
                          style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900,
                            // Renkli zeminde siyah yazı okunur kalıyor
                            color: Color.lerp(const Color(0xFFFFD700), Colors.black, vurgu),
                            letterSpacing: 0.3)),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSahne() {
    return Stack(
      children: [

        // ╔═══════════════════════════════════════════════════════════════╗
        // ║  _buildSahne() MÜŞTERİ PLACEHOLDER (SafeArea içi)            ║
        // ║  Gerçek müşteri görseli dış Stack katman 3'te render edilir.  ║
        // ║  Burası Z-order'ı korumak için boş yer tutar + isim etiketi.  ║
        // ║  Tüm konumlar SahneMetrik ile masa görseline kilitlidir —     ║
        // ║  sabit piksel YOK, her çözünürlükte aynı yere oturur.         ║
        // ╚═══════════════════════════════════════════════════════════════╝
        if (_state.aktifMusteri != null || _state.aktifOzelMusteri != null)
          AnimatedBuilder(
            animation: _slideAnim,
            builder: (context, _) {
              final mq = MediaQuery.of(context);
              final m = SahneMetrik.hesapla(mq.size);
              final ofs = mq.padding.top + 48.0; // _buildSahne yerel koordinat kayması
              final boy = m.u(kMusteriBoyu);
              final hedef = (mq.size.width - boy) / 2;
              final dx = hedef + (mq.size.width - hedef) * _slideAnim.value;
              // İsmin alt kenarı masa çizgisine kilitli → kutunun altından uzaklığı:
              final isimBottom = boy - (m.y(kIsimAlti) - m.y(kMusteriUstu));
              return Positioned(
                left: dx, top: m.y(kMusteriUstu) - ofs,
                width: boy, height: boy,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      bottom: isimBottom,
                      left: 0, right: 0,
                      child: Center(
                        child: _state.aktifOzelMusteri != null
                          ? _ozelMusteriIsimEtiketi(_state.aktifOzelMusteri!)
                          : GestureDetector(
                              onTap: () => _ozellikKartiGoster(_state.aktifMusteri!),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.6)),
                                ),
                                child: Text(_state.aktifMusteri!.name, style: const TextStyle(fontSize: 12, color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        // ╔═══════════════════════════════════════════════════════════════╗
        // ║  ÜRÜN KONUMU — masa görseline kilitli (SahneMetrik)           ║
        // ║  Sadece müşteri satıcıyken veya kurye geldiğinde gösterilir   ║
        // ║                                                               ║
        // ║  Alt kenarı  : kUrunTabani (masa görselinin %56.8'i)          ║
        // ║  Yüksekliği  : kUrunBoyu × masa boyu (masayla ölçeklenir)     ║
        // ║  Yatay       : müşteriyi takip eder (dx + oransal kayma)      ║
        // ║  Sabit piksel YOK — her çözünürlükte masaya oturur.           ║
        // ╚═══════════════════════════════════════════════════════════════╝
        if (_state.aktifMusteri != null && _state.aktifMusteri!.musteriSatiyor ||
            _state.aktifOzelMusteri?.tip == OzelMusteriTip.kurye)
          AnimatedBuilder(
            animation: _slideAnim,
            builder: (context, _) {
              final mq = MediaQuery.of(context);
              final m = SahneMetrik.hesapla(mq.size);
              final ofs = mq.padding.top + 48.0; // _buildSahne yerel koordinat kayması
              final musteriBoy = m.u(kMusteriBoyu);
              final hedef = (mq.size.width - musteriBoy) / 2;
              final dx = hedef + (mq.size.width - hedef) * _slideAnim.value;
              // Kurye ise durum.png, normal müşteri ise kendi ürün görseli
              final gorsel = _state.aktifOzelMusteri?.tip == OzelMusteriTip.kurye
                  ? 'assets/durum.png'
                  : _state.aktifMusteri!.item.gorsel;
              // Geniş/dolu görseller sahnede fazla büyük duruyor → %15 küçültülür.
              // v109 ekipmanları da 0.90 doluluk ile üretildiği için bu gruba girer.
              const kucukGorseller = {
                'assets/konsol_3.png', 'assets/konsol_4.png', 'assets/konsol_5.png',
                'assets/konsol_6.png', 'assets/oyuncudireksiyonu.png', 'assets/joypad.png',
                'assets/konsol_8.png', 'assets/konsol_9.png', 'assets/konsol_10.png',
                'assets/vrgozluk.png', 'assets/kulaklik_1.png', 'assets/kulaklik_2.png',
                'assets/kumanda_2.png', 'assets/direksiyon_2.png', 'assets/oyuncumausu.png',
                // v110 — aynı 0.90 doluluk ile üretildiler, aynı gruba girerler
                'assets/konsol_11.png', 'assets/konsol_12.png', 'assets/konsol_13.png',
                'assets/konsol_14.png', 'assets/konsol_15.png', 'assets/konsol_16.png',
                'assets/konsol_17.png', 'assets/konsol_18.png', 'assets/konsol_19.png',
                'assets/joystick.png',
                // v113 — aynı 0.90 doluluk hattından geçtiler
                'assets/konsol_20.png', 'assets/konsol_21.png', 'assets/konsol_22.png',
                'assets/konsol_23.png', 'assets/konsol_24.png',
                'assets/cicitechmouse.png', 'assets/oyuntutgaci.png',
                'assets/sahanoyuncudireksiyon.png', 'assets/sonyakulaklik.png',
              };
              final kucukUrun = kucukGorseller.contains(gorsel);
              // Tek tek ince ayar gereken ürünler: gruptaki %85 onlara oturmuyor.
              // Değerler grup oranıyla çarpılmış hâlleri (0.85 × istenen).
              const urunOzelOran = {
                'assets/oyuncumausu.png':   0.425,  // %50 küçült
                'assets/direksiyon_2.png':  1.105,  // %30 büyüt
              };
              // Ürüne özel küçültmeler (oranlar korunur)
              final urunOran = urunOzelOran[gorsel]
                  ?? (gorsel == 'assets/durum.png' ? 0.80 : (kucukUrun ? 0.85 : 1.0));
              final productSize = m.u(kUrunBoyu) * urunOran;
              // Yatay ince ayarlar da oransal (sabit px değil)
              final ekKaydir = (gorsel == 'assets/oyuncudireksiyonu.png' ? 0.0081 : 0.0)
                             + (gorsel == 'assets/konsol_2.png'          ? 0.0058 : 0.0)
                             + (gorsel == 'assets/konsol_3.png'          ? 0.0058 : 0.0);
              final productLeft = dx + m.u(kUrunSagKaydir + ekKaydir);
              // Alt kenarı masa çizgisine kilitli → üst kenar = taban - boy
              final normalTop = m.y(kUrunTabani) - productSize - ofs;
              // ⚠️ left/top burada DOĞRUDAN _slideAnim'den okunuyor (Positioned,
              // animasyonsuz) — müşteriyle aynı karede, aynı anda hareket eder.
              // Anlaşma sonrası "masadan aşağı kayıp gitme" efekti, konumdan
              // bağımsız ayrı bir AnimationController (_urunKayipController)
              // ile uygulanıyor; bkz. yukarıdaki alan yorumu.
              return Positioned(
                left: productLeft, top: normalTop,
                child: AnimatedBuilder(
                  animation: _urunKayipController,
                  builder: (context, child) {
                    final t = Curves.easeInBack.transform(_urunKayipController.value);
                    return Opacity(
                      opacity: 1 - _urunKayipController.value,
                      child: Transform.translate(
                        offset: Offset(0, t * (mq.size.height - normalTop)),
                        child: child,
                      ),
                    );
                  },
                  child: GestureDetector(
                    // Masadaki ürüne dokununca büyük önizleme açılır
                    onTap: _urunAsagiKayiyor ? null : () => _urunGorseliBuyut(gorsel,
                        oynanabilir: _state.aktifMusteri?.item.oynanabilir ?? false),
                    child: Image.asset(
                      gorsel,
                      width: productSize, height: productSize, fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),
        // ╔═══════════════════════════════════════════════════════════════╗
        // ║  KONUŞMA BALONU (mesaj kutusu)                                ║
        // ║  Positioned(top:6, left:6, right:6) — kenar boşlukları       ║
        // ║  Container padding: EdgeInsets.all(6)                         ║
        // ║                                                               ║
        // ║  Müşteri SATICI ise (musteriSatiyor==true):                   ║
        // ║    → Sadece TypewriterText (metin ortalı)                     ║
        // ║                                                               ║
        // ║  Müşteri ALICI ise (musteriSatiyor==false):                   ║
        // ║    → Row layout:                                              ║
        // ║       Sol : Image.asset(item.gorsel, 100×100px)               ║
        // ║       Ara : SizedBox(width:8)                                 ║
        // ║       Sağ : Expanded > Transform.translate(Offset(-15,0))     ║
        // ║                      > Center > TypewriterText                ║
        // ║         -15 = metni 15px sola kaydır (SON DEĞER — DOKUNMA!)  ║
        // ╚═══════════════════════════════════════════════════════════════╝
        Positioned(
          top: 6, left: 6, right: 6,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _state.aktifOzelMusteri != null
                ? _ozelMusteriRengi(_state.aktifOzelMusteri!.tip).withValues(alpha: 0.7)
                : const Color(0xFFFFD700).withValues(alpha: 0.4)),
            ),
            // ⚠️ 🐛 TEK TypewriterText — İKİ AYRI DAL YAZMA.
            // Eskiden alıcı müşteri için Row'lu, diğer hallerde düz bir dal
            // vardı ve her dalın KENDİ TypewriterText'i bulunuyordu. Müşteri
            // gidince (`aktifMusteri` null olunca) dal değişiyor, Flutter eski
            // widget'ı atıp yenisini yaratıyor ve State sıfırlandığı için AYNI
            // yazı bir daha baştan yazılıyordu — "yazı üst üste iki kere
            // yazılıyor" hatası buydu.
            //
            // Ürün görseli artık ayrı bir dal değil: yer her zaman duruyor,
            // gösterilmeyeceği zaman genişliği 0'a iniyor. Böylece
            // TypewriterText ağaçta hep AYNI konumda kalıyor, State korunuyor.
            child: Builder(builder: (_) {
              final m = _state.aktifMusteri;
              final urunGoster = m != null && !m.musteriSatiyor &&
                  (_state.musteriKabulBekliyor ||
                   (_state.aktifPazarlik != null && _state.aktifPazarlik!.turSayisi == 0));
              // Sarı mouse (oyuncumausu.png) balonda orantısız büyük duruyordu
              // — %30 küçültüldü. Diğer ürünler etkilenmez.
              final urunGorsel = m?.item.gorsel;
              final balonBoy = urunGorsel == 'assets/oyuncumausu.png' ? 70.0 : 100.0;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: urunGoster ? balonBoy : 0,
                    height: urunGoster ? balonBoy : 0,
                    child: urunGoster
                        ? Image.asset(urunGorsel!, fit: BoxFit.contain)
                        : null,
                  ),
                  SizedBox(width: urunGoster ? 8 : 0),
                  Expanded(
                    child: Transform.translate(
                      // Görsel varken metni hafif sola çek ki balonda ortalı dursun
                      offset: urunGoster ? const Offset(-15, 0) : Offset.zero,
                      child: Center(
                        child: TypewriterText(
                          // key: ayni metin tekrar gelse de animasyon bastan oynasin
                          key: ValueKey(_state.mesajSayaci),
                          text: _kolonyaGeciciMesaj ?? _state.mesaj,
                          style: TextStyle(fontSize: 14,
                            color: _state.aktifOzelMusteri != null
                              ? _ozelMusteriRengi(_state.aktifOzelMusteri!.tip)
                              : const Color(0xFFFFD700)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  /// Özel müşterinin tema rengi. Balon çerçevesi, isim etiketi ve vurgular
  /// bunu kullanır — yeni bir tip eklenince tek yerden renk verilir.
  static Color _ozelMusteriRengi(OzelMusteriTip tip) {
    switch (tip) {
      case OzelMusteriTip.hirsiz:   return Colors.redAccent;
      case OzelMusteriTip.polis:    return Colors.blueAccent;
      case OzelMusteriTip.vergici:  return Colors.orangeAccent;
      case OzelMusteriTip.kurye:    return const Color(0xFFFF8C00); // parlak turuncu
      case OzelMusteriTip.toptanci: return const Color(0xFFd29922); // toptancı altın sarısı
      case OzelMusteriTip.falci:    return const Color(0xFFB967FF); // falcı moru
      case OzelMusteriTip.guvenlik: return const Color(0xFF4FC3F7); // güvenlik mavisi
      case OzelMusteriTip.hande:    return const Color(0xFF7fdfff); // rehber camgöbeği
      case OzelMusteriTip.galerici: return const Color(0xFF90caf9); // galerici mavisi
    }
  }

  /// Özel müşteri isim etiketi. Konumu normal müşteriyle ORTAK kod tarafından
  /// (SahneMetrik + kIsimAlti) verilir — burada sadece görünüm var.
  Widget _ozelMusteriIsimEtiketi(OzelMusteri om) {
    final renk = _ozelMusteriRengi(om.tip);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: renk.withValues(alpha: 0.8)),
      ),
      child: Text(om.ad, style: TextStyle(fontSize: 13, color: renk, fontWeight: FontWeight.bold)),
    );
  }

  void _ozellikKartiGoster(Customer musteri) {
    final o = musteri.ozellik;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1008),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFFFD700), width: 1.5)),
        title: Row(children: [
          Image.asset(musteri.gorsel, width: 40, height: 40, fit: BoxFit.contain),
          const SizedBox(width: 10),
          Text(musteri.name, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _ozellikSatiri('⏳ Sabır', o.sabir),
          const SizedBox(height: 10),
          _ozellikSatiri('🔍 Titizlik', o.titizlik),
          const SizedBox(height: 10),
          _ozellikSatiri('🧠 Zeka', o.zeka),
        ]),
        actions: [Center(child: ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black),
          child: const Text('Kapat', style: TextStyle(fontWeight: FontWeight.bold)),
        ))],
      ),
    );
  }

  Widget _ozellikSatiri(String label, int yildiz) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
        Row(children: List.generate(5, (i) => Text(
          i < yildiz ? '★' : '☆',
          style: TextStyle(fontSize: 18, color: i < yildiz ? const Color(0xFFFFD700) : Colors.white24),
        ))),
      ],
    );
  }

  // ── Oyun stili özel buton ──────────────────────────────────────────────────
  // ── Pixel art buton ────────────────────────────────────────────────────────
  Widget _oyunButon({
    required String label,
    String emoji = '',
    required VoidCallback? onTap,
    required List<Color> gradyan,
    required Color kenar,
    Color yaziRenk = Colors.white,
  }) {
    final aktif = onTap != null;
    return GestureDetector(
      // Dokunsal geri bildirim tek yerden: ana ekrandaki bütün önemli butonlar
      // (Müşteri Çağır, Envanter, EVET/HAYIR, Teklif Ver, Reddet, Kabul Et,
      // Kolonya Tut, Tamam...) bu widget'tan geçiyor. Pasif butonda titreşim
      // YOK — dokunuşun bir karşılığı yoksa titretmek yanıltıcı olur.
      onTap: aktif ? () { SesServisi.dokun(); onTap(); } : null,
      child: CustomPaint(
        painter: _PixelButonPainter(renk: gradyan[0], aktif: aktif),
        child: SizedBox(
          height: 50,
          child: Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (emoji.isNotEmpty) ...[
                Text(emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 7),
              ],
              Text(label, style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: aktif ? yaziRenk : Colors.white38,
                letterSpacing: 0.5,
                shadows: aktif ? [const Shadow(color: Colors.black87, blurRadius: 3, offset: Offset(0, 1))] : null,
              )),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildAltBar() {
    // ⚠️ Ekranda hâlâ biri varken çağırma KAPALI. Eskiden sadece
    // `musteriKabulBekliyor` bakılıyordu; toptancı tepsiyi kapatıp çıkış
    // animasyonu oynarken buton aktif oluyor ve basılınca Rıza yeniden
    // geliyordu. Aynısı normal müşteri çıkarken de olabiliyordu.
    final musteriCagirAktif = !_state.musteriKabulBekliyor &&
        _state.aktifPazarlik == null &&
        _state.aktifMusteri == null &&
        _state.aktifOzelMusteri == null &&
        !_state.gunBitmeli;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black.withValues(alpha: 0.0), Colors.black.withValues(alpha: 0.70)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 👩‍🏫 Rehber Hande anlatırken TEK ve GENİŞ bir "Tamam" butonu olur;
          // alış/satış yapmadığı için EVET/HAYIR ya da pazarlık butonları yok.
          if (_state.handeAktif) ...[
            _oyunButon(
              emoji: '👍', label: 'Tamam',
              onTap: _handeTamam,
              gradyan: const [Color(0xFF43c468), Color(0xFF1a6b32)],
              kenar: const Color(0xFF81c784),
            ),
            const SizedBox(height: 8),
          ]
          // Özel müşteriye kolonya ikram edilmişse EVET/HAYIR gizlenir (3 sn sonra gider)
          else if (_state.musteriKabulBekliyor && _kolonyaGeciciMesaj == null) ...[
            // 🚗 Galerici Gürbüz: EVET/HAYIR yerine "Araç Seç" / "Vazgeç"
            if (_state.aktifOzelMusteri?.tip == OzelMusteriTip.galerici) ...[
              Row(children: [
                Expanded(child: _oyunButon(
                  emoji: '🚗', label: 'Araç Seç',
                  onTap: _galericiTezgahi,
                  gradyan: const [Color(0xFF4f8bd6), Color(0xFF16324f)],
                  kenar: const Color(0xFF90caf9),
                )),
                const SizedBox(width: 12),
                Expanded(child: _oyunButon(
                  emoji: '❌', label: 'Vazgeç',
                  onTap: _musteriHayir,
                  gradyan: const [Color(0xFFe53935), Color(0xFF7f0000)],
                  kenar: const Color(0xFFef9a9a),
                )),
              ]),
            ]
            // Alkol testi yapan polis: EVET/HAYIR yerine iki sayı şıkkı
            else if (_state.aktifOzelMusteri?.alkolTesti == true) ...[
              Builder(builder: (_) {
                final om = _state.aktifOzelMusteri!;
                return Row(children: [
                  Expanded(child: _oyunButon(
                    emoji: '🔢', label: '${om.sikSol}',
                    onTap: () => _alkolTestiCevapla(om.sikSol!),
                    gradyan: const [Color(0xFF4f8bd6), Color(0xFF16324f)],
                    kenar: const Color(0xFF90caf9),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _oyunButon(
                    emoji: '🔢', label: '${om.sikSag}',
                    onTap: () => _alkolTestiCevapla(om.sikSag!),
                    gradyan: const [Color(0xFF4f8bd6), Color(0xFF16324f)],
                    kenar: const Color(0xFF90caf9),
                  )),
                ]);
              }),
            ] else
              Row(children: [
                Expanded(child: _oyunButon(
                  emoji: '✅', label: 'EVET',
                  onTap: _musteriEvet,
                  gradyan: const [Color(0xFF43c468), Color(0xFF1a6b32)],
                  kenar: const Color(0xFF81c784),
                )),
                const SizedBox(width: 12),
                Expanded(child: _oyunButon(
                  emoji: '❌', label: 'HAYIR',
                  onTap: _musteriHayir,
                  gradyan: const [Color(0xFFe53935), Color(0xFF7f0000)],
                  kenar: const Color(0xFFef9a9a),
                )),
              ]),
            const SizedBox(height: 8),
          ],
          // Hande anlatırken sadece "Tamam" görünür — Müşteri Çağır/Envanter
          // ve pazarlık butonları gizlenir.
          if (_state.handeAktif)
            const SizedBox.shrink()
          else if (_pazarlikBekleniyor) ...[
            // Kabul Et — en az 1 tur geçtiyse (alıcı veya satıcı fark etmez)
            if (_state.aktifMusteri != null &&
                _state.aktifPazarlik != null && _state.aktifPazarlik!.turSayisi > 0) ...[
              _oyunButon(
                emoji: '✓', label: 'Kabul Et  (${_state.aktifPazarlik!.musteriTeklif})',
                onTap: _kabulEt,
                gradyan: const [Color(0xFF43c468), Color(0xFF1a6b32)],
                kenar: const Color(0xFF81c784),
              ),
              const SizedBox(height: 8),
            ],
            Row(children: [
              Expanded(child: _oyunButon(
                emoji: '💬', label: 'Teklif Ver',
                onTap: _pazarlikGoster,
                gradyan: const [Color(0xFFffd740), Color(0xFF9a6f00)],
                kenar: const Color(0xFFFFD700),
                yaziRenk: Colors.black,
              )),
              const SizedBox(width: 12),
              Expanded(child: _oyunButon(
                emoji: '🚶', label: 'Reddet',
                onTap: _pazarlikVazgec,
                gradyan: const [Color(0xFFe53935), Color(0xFF7f0000)],
                kenar: const Color(0xFFef9a9a),
              )),
            ]),
          ] else Row(children: [
            Expanded(child: _oyunButon(
              emoji: '🚪', label: 'Müşteri Çağır',
              onTap: musteriCagirAktif ? _musteriCagir : null,
              gradyan: const [Color(0xFF43c468), Color(0xFF1a6b32)],
              kenar: const Color(0xFF81c784),
            )),
            const SizedBox(width: 12),
            Expanded(child: _oyunButon(
              emoji: '📦', label: 'Envanter',
              onTap: () { SesServisi.envanter(); setState(() => _envanterAcik = true); },
              gradyan: const [Color(0xFF8c6aff), Color(0xFF311b92)],
              kenar: const Color(0xFFb39ddb),
            )),
          ]),
          // Kolonya Tut butonu — kolonya envanterde varsa görünür
          if (_state.kolonyaKullanim > 0) ...[
            const SizedBox(height: 8),
            Builder(builder: (_) {
              final hasMusteri = _state.aktifMusteri != null || _state.aktifOzelMusteri != null;
              // ⚠️ BUG FIX: normal müşteri HAYIR dedikten sonra ~600ms'lik
              // çıkış animasyonu boyunca `aktifMusteri` hâlâ dolu kalıyor ama
              // `musteriKabulBekliyor` zaten false oluyor. Bu dar pencerede
              // kolonya verilirse `_kolonyaIkramEt` mesajı günceliyor (alıcı
              // için "tekrar sorar" repliği) ama ne EVET/HAYIR ne de Teklif
              // Ver/Reddet gösteriliyor — müşteri "zombi" kalıyordu. Normal
              // müşteride kolonya artık sadece gerçekten etkileşimdeyken
              // (karşılama ya da pazarlık sırasında) aktif.
              final musteriEtkilesimde = _state.aktifOzelMusteri != null ||
                  _state.musteriKabulBekliyor || _pazarlikBekleniyor;
              final aktif = hasMusteri && !_state.kolonyaIkramEdildi && musteriEtkilesimde;
              return GestureDetector(
                // Bu buton `_oyunButon`'dan geçmiyor (kendi CustomPaint'i var),
                // dokunsal geri bildirimi elle veriliyor.
                onTap: aktif ? () { SesServisi.dokun(); _kolonyaIkramEt(); } : null,
                child: CustomPaint(
                  painter: _PixelButonPainter(renk: const Color(0xFFE6A800), aktif: aktif),
                  child: SizedBox(
                    height: 50,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Opacity(
                              opacity: aktif ? 1.0 : 0.35,
                              child: Image.asset('assets/kolonya.png', width: 22, height: 22, fit: BoxFit.contain),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Kolonya Tut',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: aktif ? Colors.white : Colors.white38,
                                letterSpacing: 0.5,
                                shadows: aktif ? [const Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1))] : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_state.kolonyaKullanim}/10',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: aktif ? Colors.white70 : Colors.white24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
          // ── Yemeği Ye — EN ALTTA, diğer bütün butonların altında ──
          // Kuryeden yemek alındıysa çıkar, yenince kaybolur.
          if (_state.yemekVar) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _yemegiYe,
              child: CustomPaint(
                painter: _PixelButonPainter(renk: const Color(0xFFFF7043), aktif: true),
                child: SizedBox(
                  height: 50,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/durum.png', width: 26, height: 26, fit: BoxFit.contain),
                        const SizedBox(width: 8),
                        const Text(
                          'Yemeği Ye',
                          style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 15, color: Colors.white, letterSpacing: 0.5,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1))],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// "Yemeği Ye" — keyif yerine gelir, envanterdeki tüm hasarlı ekipman
  /// oyuncunun kendi elinden tamir olur.
  void _yemegiYe() {
    final onarilan = _state.yemegiYe();
    SesServisi.tamir();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1008),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFFF7043), width: 2),
        ),
        title: const Column(mainAxisSize: MainAxisSize.min, children: [
          Text('🍽️', textAlign: TextAlign.center, style: TextStyle(fontSize: 44)),
          SizedBox(height: 4),
          Text('AFİYET OLSUN!', textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFFF7043), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        ]),
        content: Text(
          onarilan > 0
              ? 'Yiyince keyfin yerine geldi ve tüm hasarlı ekipmanı kendin tamir ettin!\n\n🔧 $onarilan ürün onarıldı.'
              : 'Yiyince keyfin yerine geldi. Tamir edilecek hasarlı ekipmanın yoktu, olsaydı bu moralle hepsini tamir etmiş sayılacaktın.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
        ),
        actions: [Center(child: ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7043), foregroundColor: Colors.black),
          child: const Text('Harika!', style: TextStyle(fontWeight: FontWeight.bold)),
        ))],
      ),
    );
  }

  /// Bir ürün görselini ekranın ortasında büyütür (salt önizleme).
  /// `showDialog` ile açılır → Toptancı Rıza gibi başka bir pencere açıkken
  /// bile onun ÜSTÜNDE görünür. `TweenAnimationBuilder` ile büyüyerek gelir.
  /// [oynanabilir] verilirse görselin altında "Oynanabilir Oyun!" rozeti
  /// çıkar — masadaki CD'nin sıradan bir ürün olmadığı satın almadan ÖNCE
  /// belli olsun.
  void _urunGorseliBuyut(String gorsel, {bool oynanabilir = false}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Material(
          type: MaterialType.transparency,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.35, end: 1.0),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              builder: (c, t, child) => Transform.scale(scale: t, child: child),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Image.asset(gorsel,
                    width: MediaQuery.of(ctx).size.width * 0.86,
                    fit: BoxFit.contain),
                ),
                if (oynanabilir) ...[
                  const SizedBox(height: 14),
                  const Text('⭐ Oynanabilir Oyun!', textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF00E5D0), fontSize: 17,
                      fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      'Bu oyun satın alındığında Oyuncu Dükkanı\'nda başlatılıp oynanabilir.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 13, height: 1.35, fontWeight: FontWeight.w600)),
                  ),
                ],
                const SizedBox(height: 14),
                const Text('Kapatmak için dokun',
                  style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  /// Envanterdeki sağlam ürüne dokununca açılan büyük önizleme —
  /// masadaki ürünle aynı görsel dil, ek olarak "Çöpe At" seçeneği var.
  /// `showDialog` ile açılır ki Toptancı Rıza penceresi açıkken de üstte kalsın.
  void _envanterUrunBuyut(GameItem item) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Material(
          type: MaterialType.transparency,
          child: Center(
            child: GestureDetector(
              onTap: () {}, // içeriğe dokunma dışarı tıklama sayılmasın
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.35, end: 1.0),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                builder: (c, t, child) => Transform.scale(scale: t, child: child),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Image.asset(item.gorsel,
                      width: MediaQuery.of(ctx).size.width * 0.86,
                      fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 18),
                  // ── Koleksiyona Taşı: Çöpe At / Kapat satırının ÜSTÜNDE ──
                  // Koleksiyona girmenin TEK yolu bu; ürün satılmak yerine
                  // kalıcı olarak vitrine konuyor.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _state.koleksiyonaKonabilir(item)
                          ? () => _koleksiyonaTasiOnay(item, ctx) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2a1d3d),
                          foregroundColor: const Color(0xFFa371f7),
                          disabledBackgroundColor: const Color(0xFF201a26),
                          disabledForegroundColor: Colors.white24,
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: _state.koleksiyonaKonabilir(item)
                                ? const Color(0xFFa371f7) : Colors.white12),
                          ),
                        ),
                        child: Text(
                          _state.koleksiyondakiler.contains(item.id)
                            ? '📚 Zaten Koleksiyonda'
                            : '📚 Koleksiyona Taşı',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(children: [
                      Expanded(child: ElevatedButton(
                        onPressed: () => _envanterUrunCopeAtOnay(item, ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3a1010),
                          foregroundColor: const Color(0xFFff7043),
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Color(0xFFcc3311)),
                          ),
                        ),
                        child: const Text('🗑️ Çöpe At', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Panel.ikincilZemin,
                          foregroundColor: Colors.white70,
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Panel.ikincilKenar),
                          ),
                        ),
                        child: const Text('Kapat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      )),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "Koleksiyona Taşı" onayı — ürün bir daha satılamaz, geri dönüşü yok.
  /// [buyutmeCtx] büyütme dialogunun context'i — onaylanırsa o da kapanır.
  void _koleksiyonaTasiOnay(GameItem item, BuildContext buyutmeCtx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Panel.zemin,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFa371f7), width: 1.5),
        ),
        title: const Text('📚 Koleksiyona konsun mu?', textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFa371f7), fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          '"${item.name}" kalıcı olarak koleksiyona girer.\n'
          'Bir daha satamazsın ama koleksiyon hedeflerine sayılır.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Panel.yazi, fontSize: 13)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          dialogButonlari(
            anaEtiket: 'Koleksiyona Koy',
            anaRenk: const Color(0xFFa371f7),
            anaOnTap: () {
              Navigator.pop(ctx);
              if (_state.koleksiyonaTasi(item)) {
                if (Navigator.canPop(buyutmeCtx)) Navigator.pop(buyutmeCtx);
                final odul = _state.koleksiyonOdulleriTopla();
                _toastGoster('📚 Koleksiyona eklendi!',
                  altYazi: odul > 0
                    ? 'Hedef tamamlandı: +$odul lira'
                    : '${_state.koleksiyondakiler.length}/$kKoleksiyonKutuSayisi kutu dolu',
                  emoji: '📚', renk: const Color(0xFFa371f7));
              }
            },
            ikincilEtiket: 'Vazgeç',
            ikincilOnTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  /// "Çöpe At" onayı — yanlışlıkla bir CD'yi silmek geri alınamaz.
  /// [buyutmeCtx] büyütme dialogunun context'i — onaylanırsa o da kapanır.
  void _envanterUrunCopeAtOnay(GameItem item, BuildContext buyutmeCtx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1008),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFcc3311), width: 1.5),
        ),
        title: const Text('🗑️ Emin misin?', textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFff7043), fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text(
          'Bu oyunu envanterinden çıkarıp çöpe atmak istediğine emin misin?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Panel.yazi, fontSize: 14),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [dialogButonlari(
          anaEtiket: 'Çöpe At',
          anaRenk: const Color(0xFFcc3311),
          anaYazi: Colors.white,
          anaOnTap: () {
            Navigator.pop(ctx);            // onay penceresi
            Navigator.pop(buyutmeCtx);     // büyütme penceresi
            _state.urunCikarOrnek(item);
          },
          ikincilEtiket: 'Vazgeç',
          ikincilOnTap: () => Navigator.pop(ctx),
        )],
      ),
    );
  }

  /// Envanterin İÇERİĞİ — başlık + ipucu + ürün ızgarası.
  ///
  /// Ayrı çıkarıldı çünkü iki yerde kullanılıyor: kendi popup'ında ve
  /// Toptancı Rıza ekranındaki "Envanter" sekmesinde.
  Widget _envanterGovdesi({bool baslikGoster = true}) {
    // Bir kez hesapla — itemBuilder her kartta yeniden üretmesin
    final ekKartlar = _ekEnvanterKartlari;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (baslikGoster) ...[
        const SizedBox(height: 12),
        const Text('📦 ENVANTER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFFFD700), letterSpacing: 1.5)),
      ],
      // Oynanabilir ürünler için küçük ipucu — yıldızın ne demek olduğu başka
      // hiçbir yerde yazmıyor. Başlığın hemen altında ki gözden kaçmasın.
      const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text(
          '⭐ Yıldızlı oyunlar tıklanıp oynanabilir',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: Color(0xFF7fdfff), fontWeight: FontWeight.w600),
        ),
      ),
      const SizedBox(height: 10),
      Flexible(
        child: GridView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.80,
          ),
          // İlave kartlar: kolonya ve tamir seti slot işgal etmez
          itemCount: 25 + ekKartlar.length,
          itemBuilder: (context, i) =>
              i >= 25 ? ekKartlar[i - 25] : _buildSlotKart(i),
        ),
      ),
    ]);
  }

  /// Envanter popup'ı — Toptancı Rıza ekranıyla aynı dilde: ekranın
  /// ORTASINDA, çerçeveli bir kart. Eskiden alttan çekmece gibi açılıyordu.
  Widget _buildEnvanterOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _envanterAcik = false),
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1a1008),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.6), width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: _envanterGovdesi()),
                    // Kapat scroll alanının DIŞINDA, hep görünür
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                        border: Border(top: BorderSide(color: const Color(0xFFFFD700).withValues(alpha: 0.25))),
                      ),
                      child: ElevatedButton(
                        onPressed: () => setState(() => _envanterAcik = false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Panel.ikincilZemin, foregroundColor: Panel.yazi,
                          minimumSize: const Size(double.infinity, 42),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: const BorderSide(color: Panel.ikincilKenar),
                        ),
                        child: const Text('Kapat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Slot işgal etmeyen ilave envanter kartları (kolonya, tamir seti)
  List<Widget> get _ekEnvanterKartlari => [
    if (_state.kolonyaKullanim > 0) _buildKolonyaEnvanterKarti(),
    if (_state.tamirSetiAdet > 0) _buildTamirSetiKarti(),
  ];

  // Tamir seti kartı — slota girmez, çürük ürünleri tamir etmekte kullanılır
  Widget _buildTamirSetiKarti() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0a1220).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF58a6ff).withValues(alpha: 0.7), width: 1.2),
        boxShadow: [BoxShadow(color: const Color(0xFF58a6ff).withValues(alpha: 0.15), blurRadius: 6)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Stack(children: [
              const Center(child: Text('🔧', style: TextStyle(fontSize: 34))),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF58a6ff), width: 0.5),
                  ),
                  child: Text('${_state.tamirSetiAdet}',
                    style: const TextStyle(fontSize: 8, color: Color(0xFF58a6ff), fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 2),
          const Text('Tamir Seti', style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Color(0xFF58a6ff)), textAlign: TextAlign.center),
          const Text('çürük tamiri', style: TextStyle(fontSize: 7, color: Colors.white38), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // Kolonya envanter kartı — slota girmez, grid'in sonuna eklenir (+1 ilave)
  Widget _buildKolonyaEnvanterKarti() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0a1a0a).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF00FF88).withValues(alpha: 0.7), width: 1.2),
        boxShadow: [BoxShadow(color: const Color(0xFF00FF88).withValues(alpha: 0.15), blurRadius: 6)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Stack(children: [
              Positioned.fill(child: Image.asset('assets/kolonya.png', fit: BoxFit.contain)),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF00FF88), width: 0.5),
                  ),
                  child: Text('${_state.kolonyaKullanim}/10',
                    style: const TextStyle(fontSize: 8, color: Color(0xFF00FF88), fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 2),
          const Text('Kolonya', style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Color(0xFF00FF88)), textAlign: TextAlign.center),
          const Text('+1 özel', style: TextStyle(fontSize: 7, color: Colors.white38), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildSlotKart(int slotIndex) {
    final acik = slotIndex < _state.acikSlotSayisi;
    final item = acik ? _state.slotlar[slotIndex] : null;

    if (!acik) {
      // Kilitli slot — hangi dükkan seviyesi gerekiyor?
      final gerekliSeviye = (slotIndex ~/ 5) + 1;
      final yildiz = '★' * gerekliSeviye;
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, color: Colors.white24, size: 18),
            const SizedBox(height: 4),
            Text(yildiz, style: const TextStyle(fontSize: 9, color: Colors.white24)),
            const Text('Dukkan', style: TextStyle(fontSize: 8, color: Colors.white24)),
          ],
        ),
      );
    }

    if (item == null) {
      // Boş açık slot
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a1a).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: const Center(child: Icon(Icons.add, color: Colors.white24, size: 22)),
      );
    }

    // ── Kapalı kutu: tıkla-aç ──
    if (item.kapaliKutu) {
      return GestureDetector(
        onTap: () => _kutuAcPopup(slotIndex),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF1a1030).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFa371f7).withValues(alpha: 0.8), width: 1.4),
            boxShadow: [BoxShadow(color: const Color(0xFFa371f7).withValues(alpha: 0.20), blurRadius: 7)],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(child: Stack(children: [
                Positioned.fill(child: Image.asset(item.gorsel, fit: BoxFit.contain)),
                const Positioned(top: 0, right: 0, child: Text('🎁', style: TextStyle(fontSize: 14))),
              ])),
              const SizedBox(height: 2),
              const Text('Kapalı Kutu', style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Color(0xFFa371f7)), textAlign: TextAlign.center),
              const Text('AÇMAK İÇİN TIKLA', style: TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: Colors.white54), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    // ── Normal / çürük ürün ──
    final curuk = item.curuk;
    // Oynanabilir ürün: köşesinde yıldız, tıklanınca oyun teklifi.
    // Çürükse önce tamir edilmeli — bozuk CD oynanmaz.
    final oynanir = item.oynanabilir && !curuk;
    return GestureDetector(
      onTap: curuk
          ? () => _tamirPopup(slotIndex)
          : (oynanir ? () => _oyunuAcPopup(slotIndex) : () => _envanterUrunBuyut(item)),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: curuk ? const Color(0xFF2a1010).withValues(alpha: 0.9) : const Color(0xFF2a1a0a).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10),
          // Envanter kartları TURKUAZ çerçeveli — tezgâhın sarısından ayrılsın,
          // hangi listeye baktığın bir bakışta belli olsun. ÇÜRÜK kırmızı
          // kalıyor (bilgi taşıyor), oynanabilir de kendi parlak camgöbeğinde.
          border: Border.all(color: curuk
              ? const Color(0xFFcc3311).withValues(alpha: 0.8)
              : (oynanir ? const Color(0xFF00e5ff).withValues(alpha: 0.85)
                         : const Color(0xFF40E0D0).withValues(alpha: 0.65)),
              width: curuk ? 1.3 : (oynanir ? 1.4 : 1.1)),
          boxShadow: oynanir
              ? [BoxShadow(color: const Color(0xFF00e5ff).withValues(alpha: 0.20), blurRadius: 7)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: Stack(children: [
              Positioned.fill(child: Opacity(opacity: curuk ? 0.5 : 1.0, child: Image.asset(item.gorsel, fit: BoxFit.contain))),
              if (curuk)
                Positioned(top: 0, left: 0, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFFcc3311), borderRadius: BorderRadius.circular(3)),
                  child: const Text('ÇÜRÜK', style: TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: Colors.white)),
                )),
              // ⭐ Oynanabilir işareti — kartın sağ üst köşesi
              if (oynanir)
                const Positioned(top: 0, right: 0,
                  child: Text('⭐', style: TextStyle(fontSize: 13, shadows: [Shadow(color: Colors.black, blurRadius: 3)]))),
              if (curuk && _state.tamirSetiAdet > 0)
                const Positioned(bottom: 0, right: 0, child: Text('🔧', style: TextStyle(fontSize: 11))),
            ])),
            const SizedBox(height: 2),
            Text(item.name, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.white70), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${item.etkinFiyat}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: curuk ? const Color(0xFFff7043) : const Color(0xFF00FF88))),
            Text(item.kondisyonYildiz, style: const TextStyle(fontSize: 8, color: Color(0xFFFFD700), letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  /// Oynanabilir ürünün id'sine göre açılacak oyun ekranı.
  /// Yeni oynanabilir ürün eklenince buraya bir satır yazmak yeterli.
  Widget? _oyunEkrani(String urunId) {
    switch (urunId) {
      case 'cd15': return const KirgecOyunu();
      case 'cd16': return const IteleOyunu();
      case 'cd17': return const TisssOyunu();
      default:     return null;
    }
  }

  // ── Oynanabilir ürün: "oynamak ister misin?" ──
  void _oyunuAcPopup(int slotIndex) {
    final item = _state.slotlar[slotIndex];
    if (item == null || !item.oynanabilir) return;

    // GÜNDE 1 KEZ. Sınır olmasa aynı CD üst üste oynanıp para basılırdı.
    if (_state.bugunOynananOyunlar.contains(item.id)) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1a1008),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF6b7280), width: 2),
          ),
          title: const Column(mainAxisSize: MainAxisSize.min, children: [
            Text('🌙', style: TextStyle(fontSize: 40)),
            SizedBox(height: 4),
            Text('BUGÜNLÜK BU KADAR', textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9ca3af), fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ]),
          content: Text(
            'Bugün ${item.name} oyunu oynandı.\nBir sonraki oyun için yarın gel.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          actions: [Center(child: ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6b7280), foregroundColor: Colors.white),
            child: const Text('Tamam', style: TextStyle(fontWeight: FontWeight.bold)),
          ))],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1008),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00e5ff), width: 2),
        ),
        title: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset(item.gorsel, width: 96, height: 96, fit: BoxFit.contain),
          const SizedBox(height: 6),
          Text("${item.name}'i oynamak ister misin?",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF00e5ff), fontSize: 17, fontWeight: FontWeight.bold)),
        ]),
        content: const Text(
          'Topladığın her puan kadar para kazanırsın.\nHer oyun günde bir kez oynanabilir.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        // Evet SOLDA — asıl eylem önce gelsin. Hayır da dolu bir buton;
        // düz metin olduğunda boşta duruyordu.
        actions: [Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _oyunuBaslat(slotIndex); },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00e5ff), foregroundColor: Colors.black,
              minimumSize: const Size(104, 42)),
            child: const Text('Evet', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3a3f4b), foregroundColor: Colors.white70,
              minimumSize: const Size(104, 42)),
            child: const Text('Hayır', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ])],
      ),
    );
  }

  /// Mini oyunu ayrı bir ekranda açar; oyun bitince toplanan puan kadar para
  /// bakiyeye eklenir ve dükkana kalınan yerden dönülür.
  Future<void> _oyunuBaslat(int slotIndex) async {
    final item = _state.slotlar[slotIndex];
    if (item == null) return;
    final ekran = _oyunEkrani(item.id);
    if (ekran == null) return;

    final urunId = item.name;
    // Oyuna girer girmez işaretle: oyuncu ortada çıksa da gün hakkı yanar,
    // yoksa "beğenmediğim skoru sıfırlayıp tekrar gireyim" sömürüsü olurdu.
    _state.bugunOynananOyunlar.add(item.id);
    setState(() => _envanterAcik = false); // envanter kapansın, oyun tam ekran

    final puan = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => ekran),
    );
    if (!mounted) return;
    // Tavan: tek oyundan çıkabilecek en yüksek para
    final kazanilan = (puan ?? 0).clamp(0, GameState.oyunPuanTavani);

    if (kazanilan > 0) {
      _state.para += kazanilan;
      SesServisi.paraGirdi();
    }
    _state.notifyListeners();

    // "Dükkana dön" ile mini oyundan çıkarken geçiş reklamı; kapanınca oyun
    // özeti gösterilir. Emülatörde/reklam yoksa doğrudan özete geçer.
    ReklamServisi.goster(onClosed: () {
      if (mounted) _oyunOzetiGoster(urunId, kazanilan);
    });
  }

  /// Mini oyun bitiş özeti (geçiş reklamından sonra gösterilir).
  void _oyunOzetiGoster(String urunAdi, int kazanilan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1008),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00e5ff), width: 2),
        ),
        title: const Column(mainAxisSize: MainAxisSize.min, children: [
          Text('🕹️', style: TextStyle(fontSize: 40)),
          SizedBox(height: 4),
          Text('OYUN BİTTİ', textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF00e5ff), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ]),
        content: Text(
          kazanilan > 0
              ? '$urunAdi oyunundan $kazanilan puan topladın!\n\n💰 Kasana $kazanilan lira eklendi.'
              : 'Hiç puan toplayamadın. Yarın tekrar dene!',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actions: [Center(child: ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00e5ff), foregroundColor: Colors.black),
          child: const Text('Tamam', style: TextStyle(fontWeight: FontWeight.bold)),
        ))],
      ),
    );
  }

  // ── Kapalı kutu açma ──
  void _kutuAcPopup(int slotIndex) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1008),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFa371f7), width: 2)),
        title: const Column(mainAxisSize: MainAxisSize.min, children: [
          Text('🎁', style: TextStyle(fontSize: 44)),
          SizedBox(height: 4),
          Text('Kapalı Kutu', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFa371f7), fontSize: 19)),
        ]),
        content: const Text('İçinde ne olduğu belli değil. Sağlam bir şey de çıkabilir, çürük bir şey de...\n\nAçmak istiyor musun?',
          textAlign: TextAlign.center, style: TextStyle(color: Panel.yazi, fontSize: 14)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [dialogButonlari(
          anaEtiket: 'Aç!',
          anaRenk: const Color(0xFFa371f7),
          anaYazi: Colors.white,
          anaOnTap: () {
            Navigator.pop(ctx);
            final cikan = _state.kutuAc(slotIndex);
            if (cikan != null) _kutuSonucPopup(cikan);
          },
          ikincilEtiket: 'Dursun',
          ikincilOnTap: () => Navigator.pop(ctx),
        )],
      ),
    );
  }

  void _kutuSonucPopup(GameItem cikan) {
    final iyi = !cikan.curuk;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1008),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: iyi ? const Color(0xFF3fb950) : const Color(0xFFcc3311), width: 2)),
        title: Text(iyi ? '✨ Kutudan çıktı!' : '😞 Eh işte...', textAlign: TextAlign.center,
          style: TextStyle(color: iyi ? const Color(0xFF3fb950) : const Color(0xFFcc3311), fontSize: 18)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(height: 90, child: Opacity(opacity: cikan.curuk ? 0.55 : 1.0, child: Image.asset(cikan.gorsel, fit: BoxFit.contain))),
          const SizedBox(height: 8),
          Text(cikan.name, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          if (cikan.curuk)
            const Text('ÇÜRÜK — tamir edilebilir', style: TextStyle(color: Color(0xFFcc3311), fontSize: 11, fontWeight: FontWeight.bold)),
          Text(cikan.kondisyonYildiz, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 13)),
          const SizedBox(height: 4),
          Text('Piyasa değeri: ${cikan.etkinFiyat}',
            style: const TextStyle(color: Color(0xFF00FF88), fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
        actions: [Center(child: ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(
            backgroundColor: iyi ? const Color(0xFF3fb950) : const Color(0xFF8B5E3C), foregroundColor: Colors.white),
          child: const Text('Tamam', style: TextStyle(fontWeight: FontWeight.bold)),
        ))],
      ),
    );
  }

  /// Çürük ürüne dokununca açılan ekran.
  ///
  /// Sağlam üründeki büyütmeyle AYNI görsel dil: görsel ekranın büyük kısmını
  /// kaplar, bilgiler onun altında, en altta butonlar. Fark, iki eylemin
  /// olması: üst satırda "Çöpe At / Tamir Et", altında tam genişlikte "Kapat".
  void _tamirPopup(int slotIndex) {
    final item = _state.slotlar[slotIndex];
    if (item == null || !item.curuk) return;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (ctx) {
        // Tamir seti sayısı popup açıkken değişebilir (başka bir yerden değil
        // ama yine de) — state'i dinleyip taze göstermek zararsız.
        final setVar = _state.tamirSetiAdet > 0;
        return GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Material(
            type: MaterialType.transparency,
            child: Center(
              child: GestureDetector(
                onTap: () {}, // içeriğe dokunma dışarı tıklama sayılmasın
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.35, end: 1.0),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  builder: (c, t, child) => Transform.scale(scale: t, child: child),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    // ── Büyük ürün görseli (çürük olduğu için soluk) ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Opacity(
                        opacity: 0.6,
                        child: Image.asset(item.gorsel,
                          width: MediaQuery.of(ctx).size.width * 0.72,
                          fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // ── Bilgiler ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFcc3311),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('ÇÜRÜK',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    const SizedBox(height: 8),
                    Text(item.name, textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Column(children: [
                        const Text('Şu an', style: TextStyle(color: Colors.white38, fontSize: 10)),
                        Text('${item.etkinFiyat}',
                          style: const TextStyle(color: Color(0xFFff7043), fontSize: 17, fontWeight: FontWeight.bold)),
                      ]),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Text('→', style: TextStyle(color: Colors.white38, fontSize: 20))),
                      Column(children: [
                        const Text('Tamir sonrası', style: TextStyle(color: Colors.white38, fontSize: 10)),
                        Text('~${item.basePrice}',
                          style: const TextStyle(color: Color(0xFF3fb950), fontSize: 17, fontWeight: FontWeight.bold)),
                      ]),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      setVar
                        ? '1 tamir seti kullanılacak. (Kalan: ${_state.tamirSetiAdet})'
                        : 'Tamir setin yok! Toptancıdan alabilirsin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: setVar ? Colors.white60 : const Color(0xFFff7043), fontSize: 12)),
                    const SizedBox(height: 16),
                    // ── Üst satır: ana eylem (Tamir Et) SOLDA ──
                    // Çöpe At yıkıcı bir alternatif; nötr değil, kendi kırmızı
                    // kimliğini koruyor ama aynı dolu+çerçeveli dilde.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: dialogButonlari(
                        anaEtiket: '🔧 Tamir Et',
                        // Koyu mavi: 🔧 emojisi gri, açık mavide kayboluyordu.
                        anaRenk: const Color(0xFF1E63C8),
                        anaYazi: Colors.white,
                        anaOnTap: setVar ? () {
                          Navigator.pop(ctx);
                          if (_state.tamirEt(slotIndex)) {
                            _dialogBildirim(context, '🔧 Ürün tamir edildi!');
                          }
                        } : null,
                        ikincilEtiket: '🗑️ Çöpe At',
                        ikincilOnTap: () => _envanterUrunCopeAtOnay(item, ctx),
                        ikincilZemin: const Color(0xFF3a1010),
                        ikincilKenar: const Color(0xFFcc3311),
                        ikincilYazi: const Color(0xFFff7043),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // ── Alt satır: iki butonun toplam genişliğinde Kapat ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Panel.ikincilZemin,
                            foregroundColor: Colors.white70,
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Panel.ikincilKenar),
                            ),
                          ),
                          child: const Text('Kapat',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Özel müşteriyi sağdan çıkarır. [bitince] çıkış animasyonu BİTTİKTEN sonra
  /// çalışır — arka planı değiştiren işler (güvenlik istifası) buraya verilmeli,
  /// yoksa karakter daha ekrandayken sahne altından değişir.
  void _ozelMusteriGonder({VoidCallback? bitince}) {
    _toastBitinceCalistir(() {
      if (!mounted) return;
      _slideController.reverse().then((_) {
        if (!mounted) return;
        _state.musteriAnimasyonBitti();
        bitince?.call();
      });
    });
  }

  /// Fal ekranı. Üstte falcı emojisi, ortada 2-3 cümlelik fal metni,
  /// altta (varsa) etkiyi anlatan tek satırlık sonuç şeridi.
  Future<void> _falPopup(Fal fal, FalSonuc fs) {
    final metin = fal.metniDoldur(fs.miktar);
    final sonuc = fs.satir;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a0f1c),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFB967FF), width: 2),
        ),
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🔮', textAlign: TextAlign.center, style: TextStyle(fontSize: 44)),
            SizedBox(height: 4),
            Text('FALIN', textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFB967FF), fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(metin, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4)),
            if (sonuc != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFB967FF).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFB967FF).withValues(alpha: 0.5)),
                ),
                child: Text(sonuc, textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFE9C9FF), fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        actions: [Center(child: ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB967FF), foregroundColor: Colors.black),
          child: const Text('Eyvallah', style: TextStyle(fontWeight: FontWeight.bold)),
        ))],
      ),
    );
  }

  void _ozelMusteriEvetPopup(OzelMusteri om) {
    final rng = Random();
    String mesaj = '';
    int kesinti = 0;

    if (om.tip == OzelMusteriTip.guvenlik) {
      if (om.istifaSorusu) {
        // İstifa onaylandı. Arka plan zaten güvenliksiz sürümde (öne geldiğinde
        // `_guvenlikOnde` ile değişmişti), o yüzden `guvenlikVar`ı HEMEN
        // kapatmak güvenli — bir kare bile "iki güvenlik" görünmüyor.
        _state.guvenligiIstenCikar();
        _state.mesaj = 'Sana hırsızlarla dolu bir hayatta başarılar!';
        _state.notifyListeners();
        _ozelMusteriGonder();
        return;
      }
      // 🛡️ İşe alındı — arka plan güvenlikli sürüme geçer, hırsız gelmez.
      // İlk günün ücreti hemen değil, gün sonunda kirayla birlikte kesilir.
      _state.guvenligiIseAl();
      _state.mesaj = 'Anlaştık! Bugünden itibaren kapıdayım, kimse giremez.';
      _state.notifyListeners();
      _ozelMusteriGonder();
      return;
    }

    if (om.tip == OzelMusteriTip.hirsiz) {
      kesinti = om.ilkMiktar;
      mesaj = 'Polisler duymadan kaçıyorum!';
      _state.para -= kesinti;
      SesServisi.paraGirdi();
      _state.mesaj = mesaj;
      _state.notifyListeners();
      _ozelMusteriGonder();
      return;
    }

    if (om.tip == OzelMusteriTip.polis) {
      kesinti = om.ilkMiktar;
      _state.para -= kesinti;
      SesServisi.paraGirdi();
      _state.mesaj = 'Cezayı ödedim. Polis gitti.';
      _state.notifyListeners();
      _ozelMusteriGonder();
      return;
    }

    if (om.tip == OzelMusteriTip.vergici) {
      final secim = rng.nextInt(5);
      switch (secim) {
        case 0: mesaj = 'Aferin, iyi bir vatandaşsın.'; break;
        case 1:
          final x = 50 + rng.nextInt(251);
          mesaj = 'Bana hiç öyle gelmedi. $x lira cezalısın!';
          kesinti = x;
          break;
        case 2: mesaj = 'Güzel. Bu şekilde devam et.'; break;
        case 3:
          final x = 100 + rng.nextInt(201);
          mesaj = 'Demek vergi kaçırıyorsun! $x lira ceza kesiyorum sana.';
          kesinti = x;
          break;
        case 4: mesaj = 'Harikasın. Ülkemiz böyle kalkınıyor.'; break;
      }
      if (kesinti > 0) { _state.para -= kesinti; SesServisi.paraGirdi(); }
      _state.mesaj = mesaj;
      _state.notifyListeners();
      _ozelMusteriGonder();
      return;
    }

    if (om.tip == OzelMusteriTip.kurye) {
      // Ödeme yap, kurye bonus aktifleştir, veda mesajı göster, 3sn sonra git
      _state.para -= om.ilkMiktar;
      SesServisi.paraGirdi();
      _state.kuryeBonusuAktif = true;
      _state.yemekVar = true; // alt barda "Yemeği Ye" butonu belirir
      _state.musteriKabulBekliyor = false;
      const vedaMesajlar = [
        'Afiyet bal şeker olsun dostum!',
        'Afiyetler olsun, görüşürüz!',
        'Afiyet ve şifa olsun. Kaçtım ben!',
      ];
      _state.mesaj = vedaMesajlar[rng.nextInt(vedaMesajlar.length)];
      _state.notifyListeners();
      _kuryeTimer?.cancel();
      _kuryeTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) _ozelMusteriGonder();
      });
      return;
    }

    if (om.tip == OzelMusteriTip.falci) {
      // Parası yetmiyorsa ücret ALINMAZ — fal isteğe bağlı, oyuncuyu buradan
      // iflasa sürüklemek olmaz. (Hırsız/polis zorla alır, falcı almaz.)
      if (_state.para < om.ilkMiktar) {
        _state.musteriKabulBekliyor = false;
        _state.mesaj = 'Cebinde o kadar yok evladım. Fal başka bahara kalsın.';
        _state.notifyListeners();
        _kuryeTimer?.cancel();
        _kuryeTimer = Timer(const Duration(milliseconds: 1800), () {
          if (mounted) _ozelMusteriGonder();
        });
        return;
      }
      // Ücreti al, falı seç, popup'ta göster. Etki popup kapanınca değil
      // popup AÇILIRKEN uygulanır — sonuç satırı da aynı ekranda görünsün.
      _state.para -= om.ilkMiktar;
      SesServisi.paraGirdi();
      _state.musteriKabulBekliyor = false;
      final fal = Fal.havuz[rng.nextInt(Fal.havuz.length)];
      final sonuc = _state.falUygula(fal);
      _state.mesaj = 'Bakalım yıldızlar ne diyor...';
      _state.notifyListeners();
      _falPopup(fal, sonuc).then((_) {
        if (!mounted) return;
        const vedalar = [
          'Gaipten haber verdim, gerisi sana kalmış. Eyvallah!',
          'Yıldızlar yalan söylemez evladım. Hadi bana müsaade.',
          'Falına baktım, bahtına küsme. Görüşürüz!',
          'Ben gidiyorum ama söylediklerim kalıyor. Kendine iyi bak.',
        ];
        _state.mesaj = vedalar[Random().nextInt(vedalar.length)];
        _state.notifyListeners();
        _kuryeTimer?.cancel();
        _kuryeTimer = Timer(const Duration(milliseconds: 1800), () {
          if (mounted) _ozelMusteriGonder();
        });
      });
      return;
    }

    if (om.tip == OzelMusteriTip.toptanci) {
      // Tepsiyi aç: taze stokla toptancı ekranı. Ekran kapanınca Rıza gider.
      _state.musteriKabulBekliyor = false;
      _state.mesaj = 'Bakalım Rıza bugün ne getirmiş...';
      _state.notifyListeners();
      _toptanciPopup(ziyaret: true).then((_) {
        if (!mounted) return;
        const vedalar = [
          'Bereketli olsun patron, yine uğrarım!',
          'Eyvallah usta, kolay gelsin!',
          'Hadi ben kaçtım, tepsi soğumadan!',
        ];
        _state.mesaj = vedalar[Random().nextInt(vedalar.length)];
        _state.notifyListeners();
        _kuryeTimer?.cancel();
        _kuryeTimer = Timer(const Duration(milliseconds: 1400), () {
          if (mounted) _ozelMusteriGonder();
        });
      });
      return;
    }
  }

  /// 🚗 "Hangi konuma gitmek istersin?" — Ev ve Yazlık kutuları.
  /// Satın alınmamış mekân pasif kalır.
  void _konumSecPopup() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Panel.zemin,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF4f8bd6), width: 1.5),
        ),
        title: const Text('🚗 Hangi konuma gitmek istersin?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF90caf9), fontSize: 16, fontWeight: FontWeight.bold)),
        content: Row(mainAxisSize: MainAxisSize.min, children: [
          Expanded(child: _konumKutusu(
            ikon: '🏠', ad: 'Ev',
            aciklama: _state.evSahibi ? 'Senin evin' : 'Önce Market\'ten al',
            aktif: _state.evSahibi,
            onTap: () { Navigator.pop(ctx); _gecisBaslat(Konum.ev); },
          )),
          const SizedBox(width: 10),
          Expanded(child: _konumKutusu(
            ikon: '🏖️', ad: 'Yazlık',
            aciklama: _state.yazlikSahibi ? 'Senin yazlığın' : 'Önce Market\'ten al',
            aktif: _state.yazlikSahibi,
            onTap: () { Navigator.pop(ctx); _gecisBaslat(Konum.yazlik); },
          )),
        ]),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [Center(child: ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(
            backgroundColor: Panel.ikincilZemin, foregroundColor: Colors.white70,
            minimumSize: const Size(140, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Panel.ikincilKenar)),
          ),
          child: const Text('Vazgeç', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ))],
      ),
    );
  }

  Widget _konumKutusu({
    required String ikon, required String ad, required String aciklama,
    required bool aktif, required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: aktif ? 1.0 : 0.42,
      child: GestureDetector(
        onTap: aktif ? () { SesServisi.dokun(); onTap(); } : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF11202f),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: aktif ? const Color(0xFF4f8bd6) : Colors.white24,
              width: aktif ? 1.5 : 1),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(aktif ? ikon : '🔒', style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 6),
            Text(ad, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Panel.yazi)),
            const SizedBox(height: 2),
            Text(aciklama, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Panel.yaziSoluk)),
          ]),
        ),
      ),
    );
  }

  /// Yolculuğu başlatır. Süre envanterdeki EN HIZLI aracın süresidir —
  /// birden fazla araç varsa oyuncu doğal olarak iyi olanla gider.
  void _gecisBaslat(Konum hedef) {
    final araclar = _state.sahipAraclar;
    if (araclar.isEmpty) return;
    int enIyiSn = 1 << 30;
    String gorsel = araclar.first.gorsel;
    for (final a in araclar) {
      final sn = Arac.gecisSuresi(a.id) ?? 60;
      if (sn < enIyiSn) { enIyiSn = sn; gorsel = a.gorsel; }
    }
    setState(() {
      _gecisAktif = true;
      _gecisHedef = hedef;
      _gecisAracGorsel = gorsel;
      _gecisToplamSn = enIyiSn;
      _gecisBaslangic = DateTime.now();
    });
    _toastGoster('Geçiş başladı...', altYazi: '$enIyiSn saniye sürecek',
      emoji: '🚗', renk: const Color(0xFF4f8bd6));
    _gecisTimer?.cancel();
    _gecisTimer = Timer.periodic(const Duration(milliseconds: 500), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_gecisOran >= 1.0) {
        t.cancel();
        _gecisTamamlandi();
      } else {
        setState(() {}); // kalan süre yazısı tazelensin
      }
    });
  }

  /// Yolculuk bitti. ⚠️ Dükkanda müşteri varken popup AÇILMAZ — pazarlığın
  /// ortasına girmek haksızlık olur; müşteri gidince tekrar denenir.
  void _gecisTamamlandi() {
    if (!mounted) return;
    final mesgul = _state.aktifMusteri != null ||
        _state.aktifOzelMusteri != null ||
        _state.aktifPazarlik != null ||
        _state.musteriKabulBekliyor;
    if (mesgul) {
      // Müşteri gidince yeniden denenmesi için kısa aralıklı bekleme.
      _gecisTimer?.cancel();
      _gecisTimer = Timer.periodic(const Duration(milliseconds: 700), (t) {
        if (!mounted) { t.cancel(); return; }
        final hala = _state.aktifMusteri != null ||
            _state.aktifOzelMusteri != null ||
            _state.aktifPazarlik != null ||
            _state.musteriKabulBekliyor;
        if (!hala) { t.cancel(); _gecisSorusuGoster(); }
      });
      return;
    }
    _gecisSorusuGoster();
  }

  void _gecisSorusuGoster() {
    final hedef = _gecisHedef;
    setState(() { _gecisAktif = false; _gecisAracGorsel = null; });
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Panel.zemin,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF4f8bd6), width: 1.5),
        ),
        title: const Text('🚗 Yolculuk tamam', textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF90caf9), fontSize: 17, fontWeight: FontWeight.bold)),
        content: const Text('Geçiş işlemleri gerçekleşti. Eve geçmek istiyor musun?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Panel.yazi, fontSize: 14, height: 1.3)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          dialogButonlari(
            anaEtiket: 'Evet',
            anaRenk: const Color(0xFF4f8bd6),
            anaYazi: Colors.white,
            anaOnTap: () { Navigator.pop(ctx); _state.konumaGec(hedef); },
            ikincilEtiket: 'Hayır',
            ikincilOnTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  /// 🏠 / 🏖️ Market'teki ev ya da yazlık kartına dokununca çıkan satın alma onayı.
  void _mekanSatinAlPopup(Konum k) {
    final yazlik = k == Konum.yazlik;
    final ad = yazlik ? 'Yazlık' : 'Ev';
    final ikon = yazlik ? '🏖️' : '🏠';
    final fiyat = yazlik ? EvEsyasi.yazlikFiyati : EvEsyasi.evFiyati;
    final sahip = _state.konumSahibi(k);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Panel.zemin,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFf78166), width: 1.5),
        ),
        title: Text('$ikon $ad', textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFf78166), fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset(Mekan.bul(k).arkaplan, height: 150, fit: BoxFit.cover),
          const SizedBox(height: 12),
          Text(
            sahip
              ? 'Bura zaten senin. Araç aldıysan "Konum Değiştir" ile gidebilirsin.'
              : 'Kendine ait bir $ad. $fiyat lira.\n'
                'Aldıktan sonra bir araçla gidip eşya alabilirsin.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Panel.yazi, fontSize: 13, height: 1.3)),
        ]),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          dialogButonlari(
            anaEtiket: 'Satın Al',
            anaRenk: const Color(0xFFf78166),
            anaOnTap: (sahip || _state.para < fiyat)
              ? null
              : () {
                  Navigator.pop(ctx);
                  if (_state.mekanSatinAl(k)) {
                    _dialogBildirim(context, '$ikon $ad aldın, artık konum değiştirebilirsin!');
                  }
                },
            ikincilEtiket: 'Kapat',
            ikincilOnTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  /// 🚗 Gürbüz Oto Galeri'nin tezgâhı. Bir araç seçilirse galerici sıradan bir
  /// satıcı müşteriye dönüşür ve NORMAL pazarlık başlar — ekipmandaki akışın
  /// aynısı, ayrı bir satın alma yolu yok.
  void _galericiTezgahi() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Panel.zemin,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF4f8bd6), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🚗 GÜRBÜZ OTO GALERİ',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                color: Color(0xFF90caf9), letterSpacing: 1)),
            const SizedBox(height: 3),
            const Text('Beğendiğin araca tıkla, pazarlığa oturalım.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Panel.yaziSoluk)),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(children: Arac.tumu.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: GestureDetector(
                    onTap: () {
                      SesServisi.dokun();
                      Navigator.pop(ctx);
                      _state.galericiAracSec(a.item);
                      setState(() => _pazarlikBekleniyor = true);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF11202f),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF4f8bd6).withValues(alpha: 0.55)),
                      ),
                      child: Row(children: [
                        Image.asset(a.item.gorsel, width: 72, height: 54, fit: BoxFit.contain),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.item.name, style: const TextStyle(fontSize: 13,
                              fontWeight: FontWeight.bold, color: Panel.yazi)),
                            const SizedBox(height: 2),
                            Text('Geçiş süresi: ${a.gecisSaniye} sn',
                              style: const TextStyle(fontSize: 10, color: Panel.yaziSoluk)),
                          ])),
                        Text('${a.item.basePrice}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                            color: Color(0xFF90caf9))),
                      ]),
                    ),
                  ),
                )).toList()),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Panel.ikincilZemin,
                  foregroundColor: Colors.white70,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Panel.ikincilKenar),
                  ),
                ),
                child: const Text('Kapat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _ozelMusteriHayirPopup(OzelMusteri om) {
    final rng = Random();
    String mesaj = '';
    int kesinti = 0;

    if (om.tip == OzelMusteriTip.guvenlik) {
      if (om.istifaSorusu) {
        // Çalışmaya devam ediyor: dükkandan ÇIKMIYOR, kapıdaki yerine dönüyor.
        // O yüzden sağa kaydırmak yanlış olurdu — yukarı süzülüp kayboluyor,
        // kaybolduğu anda arka plan güvenlikli sürüme geçiyor.
        _state.mesaj = 'İyi o zaman, kapıdayım patron.';
        _state.notifyListeners();
        _guvenlikYerineDon();
        return;
      }
      // İşe alma teklifine HAYIR → küsmeden gider, 3'ün katlarında tekrar dener.
      _state.mesaj = 'Peki, fikrini değiştirirsen buralardayım.';
      _state.notifyListeners();
      _ozelMusteriGonder();
      return;
    }

    // 🚗 Galerici Gürbüz küsmez, kapıdan çıkar gider — kesinti yok.
    if (om.tip == OzelMusteriTip.galerici) {
      _state.mesaj = 'Olsun abi, canın sağ olsun. Yolun düşerse galeriye bekleriz!';
      _state.notifyListeners();
      _ozelMusteriGonder();
      return;
    }

    if (om.tip == OzelMusteriTip.hirsiz) {
      final y = 10 + rng.nextInt(91);
      kesinti = om.ilkMiktar + y;
      mesaj = 'Demek öyle! Senden zorla $kesinti lira çalıp kaçıyorum!';
      _state.para -= kesinti;
      SesServisi.paraGirdi();
      _state.mesaj = mesaj;
      _state.notifyListeners();
      _ozelMusteriGonder();
      return;
    }

    if (om.tip == OzelMusteriTip.polis) {
      final y = 30 + rng.nextInt(171);
      kesinti = om.ilkMiktar + y;
      mesaj = 'Kolluk güçlerine karşı gelemezsin! Cezanı $kesinti yaptım!';
      _state.para -= kesinti;
      SesServisi.paraGirdi();
      _state.mesaj = mesaj;
      _state.notifyListeners();
      _ozelMusteriGonder();
      return;
    }

    if (om.tip == OzelMusteriTip.vergici) {
      final secim = rng.nextInt(4);
      switch (secim) {
        case 0: mesaj = 'Bravo. Dürüstlüğünden dolayı sana ceza kesmiyorum.'; break;
        case 1: mesaj = 'Tebrikler. Özü sözü bir birisin. Şimdilik affettim seni...'; break;
        case 2:
          final x = 100 + rng.nextInt(201);
          mesaj = 'Bir de ukalaca hayır diyorsun öyle mi? $x lira ceza kesiyorum sana!';
          kesinti = x;
          break;
        case 3:
          final x = 10 + rng.nextInt(41);
          mesaj = 'O zaman senden $x lira rüşvet alıp sessizce kaçıyorum.';
          kesinti = x;
          break;
      }
      if (kesinti > 0) { _state.para -= kesinti; SesServisi.paraGirdi(); }
      _state.mesaj = mesaj;
      _state.notifyListeners();
      _ozelMusteriGonder();
      return;
    }

    if (om.tip == OzelMusteriTip.kurye) {
      // Hayır — veda mesajı göster, 3sn sonra git
      _state.musteriKabulBekliyor = false;
      const redMesajlar = [
        'İyi, ben de kendim yerim!',
        'İstemiyorsan isteme!',
        'Ben de sokak hayvanlarına veririm!',
        'Götürüp iade edeyim öyleyse!',
      ];
      _state.mesaj = redMesajlar[rng.nextInt(redMesajlar.length)];
      _state.notifyListeners();
      _kuryeTimer?.cancel();
      _kuryeTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) _ozelMusteriGonder();
      });
      return;
    }

    if (om.tip == OzelMusteriTip.falci) {
      _state.musteriKabulBekliyor = false;
      const redMesajlar = [
        'İnanmayana fal bakılmaz zaten. Eyvallah!',
        'Nasıl istersen evladım. Ama merak edeceksin, bilirim.',
        'Peki peki, zorla güzellik olmaz. Hoşça kal!',
        'Kaderin senden saklı kalsın öyleyse. Görüşürüz!',
        'Param yoksa kaderim de yok mu diyorsun? Neyse, gidiyorum.',
      ];
      _state.mesaj = redMesajlar[rng.nextInt(redMesajlar.length)];
      _state.notifyListeners();
      _kuryeTimer?.cancel();
      _kuryeTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) _ozelMusteriGonder();
      });
      return;
    }

    if (om.tip == OzelMusteriTip.toptanci) {
      _state.musteriKabulBekliyor = false;
      const redMesajlar = [
        'Peki patron, başka sefere. Kolay gelsin!',
        'Olsun, tepsiyi başkasına götüreyim.',
        'Eyvallah, işin varmış. Yine uğrarım!',
        'Nasıl istersen usta, mal burada bekler.',
      ];
      _state.mesaj = redMesajlar[rng.nextInt(redMesajlar.length)];
      _state.notifyListeners();
      _kuryeTimer?.cancel();
      _kuryeTimer = Timer(const Duration(milliseconds: 1600), () {
        if (mounted) _ozelMusteriGonder();
      });
      return;
    }
  }

  void _pazarlikGoster() {
    final m = _state.aktifMusteri!;
    setState(() => _pazarlikBekleniyor = false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PazarlikDialog(state: _state, musteri: m),
    ).then((_) {
      if (!mounted) return;
      final p = _state.aktifPazarlik;
      if (p != null && p.durum == PazarlikDurum.devamEdiyor) {
        setState(() => _pazarlikBekleniyor = true);
      } else if (p != null && p.durum == PazarlikDurum.anlasildi) {
        // ⚠️ p.durum fiyat üzerinde ANLAŞILDIĞINI gösterir — parasızlık veya
        // dolu envanter yüzünden alım GERÇEKLEŞMEMİŞ olabilir
        // (bkz. `sonAnlasmaBasarisiz`, GameState._anlasmayiTamamla). Öyleyse
        // ürün hâlâ müşteride demektir; masadan aşağı kaymamalı, müşteriyle
        // birlikte normal şekilde sağdan çıkmalı.
        //
        // Oyuncu SATIN ALDIYSA ürün masadan aşağı kayıp kaybolur — malın el
        // değiştirdiği görünsün. Oyuncu satıyorsa zaten masada ürün yok.
        if (_state.aktifMusteri?.musteriSatiyor == true && !_state.sonAnlasmaBasarisiz) {
          setState(() => _urunAsagiKayiyor = true);
          _urunKayipController.forward(from: 0);
        }
        // Kabul mesajı balonda görünsün, 1.5 sn sonra müşteri gitsin.
        // ⚠️ Ekranda seri/hedef bildirimi varsa çıkış onu BEKLER; bildirim
        // kapanır kapanmaz müşteri gitmeye başlar.
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (!mounted) return;
          _toastBitinceCalistir(() {
            if (!mounted) return;
            _slideController.reverse().then((_) {
              if (!mounted) return;
              _state.musteriAnimasyonBitti();
              setState(() => _urunAsagiKayiyor = false); // sonraki müşteri için sıfırla
              _urunKayipController.reset();
            });
          });
        });
      } else {
        setState(() => _pazarlikBekleniyor = false);
        _slideController.reverse().then((_) { if (mounted) _state.musteriAnimasyonBitti(); });
      }
    });
  }

  // Kolonya şişesine tıklandığında: 3 saniyelik teşekkür mesajı + pazarlık bonusu
  void _kolonyaIkramEt() {
    if (_state.kolonyaIkramEdildi || _state.kolonyaKullanim <= 0) return;
    if (_state.aktifMusteri == null && _state.aktifOzelMusteri == null) return;
    _state.kolonyaIkramEt();
    _kolonyaMesajTimer?.cancel();
    if (_state.aktifOzelMusteri != null) {
      final tip = _state.aktifOzelMusteri!.tip;
      // ⚠️ Toptancı Rıza ikramdan sonra GİTMEZ. Gitseydi tepsi hiç açılmadan
      // kaybolur, oyuncu kolonya ikram ettiği için alışverişi kaçırırdı.
      if (tip == OzelMusteriTip.toptanci) {
        setState(() => _kolonyaGeciciMesaj = 'Ellerine sağlık patron, mis gibi! Hadi bak bakalım tepsiye.');
        _kolonyaMesajTimer = Timer(const Duration(seconds: 3), () {
          if (!mounted) return;
          setState(() => _kolonyaGeciciMesaj = null);
        });
        return;
      }
      // Diğer özel müşteriler: 3 sn sonra parasız gider.
      // Tehdit eden tipler (hırsız/polis/vergici) "affediyorum" der; kurye/falcı teşekkür eder.
      final dostane = tip == OzelMusteriTip.kurye || tip == OzelMusteriTip.falci;
      setState(() => _kolonyaGeciciMesaj = dostane
          ? 'Ellerine sağlık patron, mis gibi! Ben kaçtım.'
          : 'Vay, çok naziksin, seni bu seferlik rahat bırakıyorum!');
      _kolonyaMesajTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _kolonyaGeciciMesaj = null);
        _ozelMusteriGonder();
      });
    } else {
      // Normal müşteriye ikram — 3 sn teşekkür, sonra alıcıysa 6 random'dan biri ile devam
      setState(() => _kolonyaGeciciMesaj = 'Kolonya ikramın için teşekkürler! :)');
      _kolonyaMesajTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        // Alıcı (alıcı) için kolonya sonrası random mesaj: önceki ürünü hatırla, tekrar etmesin
        if (_state.aktifMusteri != null && !_state.aktifMusteri!.musteriSatiyor) {
          final urunAd = _state.aktifMusteri!.item.name;
          final mesajlar = <String>[
            'Ne diyorduk? Elinde $urunAd olduğunu duydum, bana satar mısın?',
            'En son $urunAd cd\'sini bana satmanı rica ediyordum. Mümkün mü?',
            'Nerede kalmıştık... Evet. $urunAd cd\'ni bana satar mısın?',
            'Hah ne diyordum; $urunAd cd\'ni alabilir miyim mümkünse?',
            '$urunAd cd\'n hala duruyorsa ben alabilir miyim?',
            'Ferahladığıma göre tekrar sorayım, $urunAd satılık mı halen?',
          ];
          final adaylar = List<int>.generate(mesajlar.length, (i) => i)
              .where((i) => i != _kolonyaSonrasiSonIdx).toList();
          final idx = adaylar[Random().nextInt(adaylar.length)];
          _kolonyaSonrasiSonIdx = idx;
          _state.mesaj = mesajlar[idx];
          _state.notifyListeners();
        }
        setState(() => _kolonyaGeciciMesaj = null);
      });
    }
  }

  // Ana ekrandaki "Kabul Et" butonuna basılınca — popup açmadan müşteri fiyatını kabul et
  void _kabulEt() {
    final p = _state.aktifPazarlik;
    if (p == null) return;
    setState(() => _pazarlikBekleniyor = false);
    _state.teklifVer(p.musteriTeklif); // musteriSatiyor + oyuncuTeklif == musteriTeklif → anlasildi
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      _toastBitinceCalistir(() {
        if (!mounted) return;
        _slideController.reverse().then((_) { if (mounted) _state.musteriAnimasyonBitti(); });
      });
    });
  }

  void _pazarlikVazgec() {
    setState(() => _pazarlikBekleniyor = false);
    _state.musteriReddet();
    _slideController.reverse().then((_) { if (mounted) _state.musteriAnimasyonBitti(); });
  }
}

// ─── PAZARLIK DİALOG ─────────────────────────────────────────────────────────

class _PazarlikDialog extends StatefulWidget {
  final GameState state;
  final Customer musteri;
  const _PazarlikDialog({required this.state, required this.musteri});
  @override
  State<_PazarlikDialog> createState() => _PazarlikDialogState();
}

class _PazarlikDialogState extends State<_PazarlikDialog> {
  late TextEditingController _teklifController;
  String _dialogMesaj = '';
  bool _bitti = false;

  @override
  void initState() {
    super.initState();
    final p = widget.state.aktifPazarlik!;
    _teklifController = TextEditingController(text: p.oyuncuTeklif.toString());
    _dialogMesaj = widget.musteri.musteriSatiyor
        ? '"${widget.musteri.item.name}" için ${p.musteriTeklif} istiyorum.'
        : '"${widget.musteri.item.name}" için ${p.musteriTeklif} vereyim.';
  }

  @override
  void dispose() { _teklifController.dispose(); super.dispose(); }

  static const int _teklifTavani = 999999;

  /// Bu turda girilebilecek EN DÜŞÜK teklif.
  ///
  /// Müşteri son teklifi reddetti; oyuncu ALIYORSA o rakamın altına inmek
  /// anlamsız (zaten kabul etmedi). Sınır tek yönlü: oyuncu bu sınırın
  /// üstünde istediği gibi aşağı yukarı gezinebilir.
  int get _minTeklif {
    final p = widget.state.aktifPazarlik;
    if (p == null || p.turSayisi == 0) return 1; // ilk teklif serbest
    return widget.musteri.musteriSatiyor ? p.oyuncuTeklif + 1 : 1;
  }

  /// Bu turda girilebilecek EN YÜKSEK teklif (satarken reddedilen fiyatın altı).
  int get _maxTeklif {
    final p = widget.state.aktifPazarlik;
    if (p == null || p.turSayisi == 0) return _teklifTavani;
    return widget.musteri.musteriSatiyor ? _teklifTavani : p.oyuncuTeklif - 1;
  }

  /// Girilen teklif oyuna gönderilebilir mi? Geçerli aralığın içinde olmalı.
  bool _teklifGecerliMi(int? teklif) =>
      teklif != null && teklif >= _minTeklif && teklif <= _maxTeklif;

  /// Artır/azalt oku basılabilir mi?
  ///
  /// ⚠️ Yön bazlı DEĞİL, SINIR bazlı. Eskiden "oyuncu alıyorsa ▼ hep pasif"
  /// deniyordu; oyuncu ▲ ile yukarı çıktığında bile aşağı inemiyordu. Artık
  /// mevcut değer sınıra dayanmadıkça iki ok da çalışır.
  bool _okAktif({required bool azalt}) {
    final val = int.tryParse(_teklifController.text.trim()) ?? 0;
    return azalt ? val > _minTeklif : val < _maxTeklif;
  }

  /// Oku bir adım oynat — sınırın ötesine geçmez, sınıra yapışır.
  void _okAdim({required bool azalt}) {
    final val = int.tryParse(_teklifController.text.trim()) ?? _minTeklif;
    final yeni = (azalt ? val - 10 : val + 10).clamp(_minTeklif, _maxTeklif);
    setState(() => _teklifController.text = '$yeni');
  }

  void _teklifGonder() {
    if (_bitti) return; // çift dokunuşta iki kez gönderilmesin
    final teklif = int.tryParse(_teklifController.text.trim());
    if (!_teklifGecerliMi(teklif)) return; // buton zaten pasif, savunma amaçlı
    setState(() => _bitti = true);
    // ⚠️ pop() try/finally İÇİNDE: teklifVer bir hata atarsa popup açık kalıp
    // sadece arkadaki balon değişiyordu. Kapanma her koşulda garanti olmalı.
    try {
      widget.state.teklifVer(teklif!);
    } finally {
      // Her durumda popup kapanır, mesaj ana ekranda balondan okunur
      if (mounted) Navigator.of(context).pop();
    }
  }

  Widget _buildMesajWidget(String mesaj, bool anlasildi, bool gitti) {
    final color = anlasildi ? Colors.greenAccent : gitti ? Colors.redAccent : Colors.white70;
    final regex = RegExp(r'\b([0-9]{2,})\b');
    final spans = <TextSpan>[];
    int last = 0;
    for (final match in regex.allMatches(mesaj)) {
      if (match.start > last) spans.add(TextSpan(text: mesaj.substring(last, match.start), style: TextStyle(color: color, fontStyle: FontStyle.italic, fontSize: 15)));
      spans.add(TextSpan(text: match.group(0), style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 18)));
      last = match.end;
    }
    if (last < mesaj.length) spans.add(TextSpan(text: mesaj.substring(last), style: TextStyle(color: color, fontStyle: FontStyle.italic, fontSize: 15)));
    return RichText(textAlign: TextAlign.center, text: TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.musteri;
    final p = widget.state.aktifPazarlik;
    final musteriTeklif = p?.musteriTeklif ?? m.ilkTeklif;
    final anlasildi = p?.durum == PazarlikDurum.anlasildi;
    final gitti = p?.durum == PazarlikDurum.gitti;

    return AlertDialog(
      backgroundColor: const Color(0xFF1a1008),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFFFD700), width: 1.5)),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.70),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Opacity(
                opacity: m.item.curuk ? 0.55 : 1.0,
                child: Image.asset(m.item.gorsel, width: 160, height: 160, fit: BoxFit.contain))),
              const SizedBox(height: 10),
              Text(m.item.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              if (m.item.curuk) ...[
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFcc3311), borderRadius: BorderRadius.circular(4)),
                  child: const Text('ÇÜRÜK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                ),
              ],
              const SizedBox(height: 4),
              RichText(textAlign: TextAlign.center, text: TextSpan(children: [
                const TextSpan(text: 'Piyasa: ', style: TextStyle(fontSize: 14, color: Colors.white60, fontWeight: FontWeight.w600)),
                TextSpan(text: '${m.item.etkinFiyat}', style: const TextStyle(fontSize: 14, color: Color(0xFF64B5F6), fontWeight: FontWeight.bold)),
              ])),
              if (!m.musteriSatiyor && m.item.maliyet != null) ...[
                const SizedBox(height: 2),
                RichText(textAlign: TextAlign.center, text: TextSpan(children: [
                  const TextSpan(text: 'Maliyet: ', style: TextStyle(fontSize: 14, color: Colors.white60, fontWeight: FontWeight.w600)),
                  TextSpan(text: '${m.item.maliyet}', style: const TextStyle(fontSize: 14, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                ])),
              ],
              const SizedBox(height: 2),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Kondisyon: ', style: TextStyle(fontSize: 13, color: Colors.white38)),
                Text(m.item.kondisyonYildiz, style: const TextStyle(fontSize: 13, color: Color(0xFFFFD700))),
              ]),
              const SizedBox(height: 12),
              if (_dialogMesaj.isNotEmpty)
                Builder(builder: (context) {
                  final tiklayabilir = !anlasildi && !gitti && !_bitti;
                  return GestureDetector(
                    onTap: tiklayabilir ? () {
                      widget.state.teklifVer(musteriTeklif);
                      Navigator.of(context).pop();
                    } : null,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: tiklayabilir
                            ? Colors.green.withValues(alpha: 0.12)
                            : anlasildi ? Colors.green.withValues(alpha: 0.15)
                            : gitti ? Colors.red.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(tiklayabilir ? 24 : 8),
                        border: Border.all(
                          color: tiklayabilir
                              ? const Color(0xFF4caf50)
                              : anlasildi ? Colors.green.withValues(alpha: 0.5)
                              : gitti ? Colors.red.withValues(alpha: 0.5)
                              : Colors.white12,
                          width: tiklayabilir ? 1.8 : 1.0,
                        ),
                        boxShadow: tiklayabilir ? [
                          BoxShadow(color: Colors.green.withValues(alpha: 0.25), blurRadius: 8, spreadRadius: 1),
                        ] : null,
                      ),
                      child: _buildMesajWidget(_dialogMesaj, anlasildi, gitti),
                    ),
                  );
                }),
              if (p != null && !_bitti && widget.state.imacSatinAlindi)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Müşteri Sabrı: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ...List.generate(p.maxTur, (i) => Container(
                        width: 10, height: 10,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: i < p.turSayisi ? Colors.redAccent : Colors.white24),
                      )),
                    ],
                  ),
                ),
              if (!_bitti)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFFFD700), width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    // ▼ Sınıra (reddedilen fiyata) dayanınca pasifleşir.
                    Builder(builder: (_) {
                      final aktif = _okAktif(azalt: true);
                      return GestureDetector(
                        onTap: aktif ? () => _okAdim(azalt: true) : null,
                        child: Container(
                          width: 44, height: 54,
                          decoration: const BoxDecoration(color: Color(0xFF2a1a0a), borderRadius: BorderRadius.horizontal(left: Radius.circular(7))),
                          child: Center(child: Text('▼', style: TextStyle(
                            fontSize: 20, color: aktif ? const Color(0xFFFFD700) : Colors.white24))),
                        ),
                      );
                    }),
                    Expanded(
                      child: TextField(
                        controller: _teklifController,
                        keyboardType: TextInputType.number,
                        // Geçerlilik anında güncellensin diye her tuşta setState
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                          border: InputBorder.none,
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Color(0xFFFFD700), width: 1)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Color(0xFFFFD700), width: 1)),
                        ),
                      ),
                    ),
                    // ▲ Satarken sınır reddedilen fiyatın bir altı; alırken yok.
                    Builder(builder: (_) {
                      final aktif = _okAktif(azalt: false);
                      return GestureDetector(
                        onTap: aktif ? () => _okAdim(azalt: false) : null,
                        child: Container(
                          width: 44, height: 54,
                          decoration: const BoxDecoration(color: Color(0xFF2a1a0a), borderRadius: BorderRadius.horizontal(right: Radius.circular(7))),
                          child: Center(child: Text('▲', style: TextStyle(
                            fontSize: 20, color: aktif ? const Color(0xFFFFD700) : Colors.white24))),
                        ),
                      );
                    }),
                  ]),
                ),
              if (!_bitti) ...[
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Expanded(child: ElevatedButton(
                    onPressed: () { Navigator.of(context).pop(); widget.state.musteriReddet(); },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFAA0000), foregroundColor: Colors.white, padding: EdgeInsets.zero),
                    child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Reddet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                  )),
                  const SizedBox(width: 8),
                  // Geçerli bir teklif girilene kadar pasif ve soluk — eskiden
                  // aktif görünüp basınca hiçbir şey olmuyordu.
                  Expanded(child: Builder(builder: (_) {
                    final gecerli = _teklifGecerliMi(int.tryParse(_teklifController.text.trim()));
                    return ElevatedButton(
                      onPressed: gecerli ? _teklifGonder : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black,
                        disabledBackgroundColor: const Color(0xFF6b5a1e),
                        disabledForegroundColor: Colors.white38,
                        padding: EdgeInsets.zero),
                      child: FittedBox(fit: BoxFit.scaleDown, child: Text(m.musteriSatiyor ? 'Teklif Ver' : 'Fiyat Ver', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                    );
                  })),
                ]),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── PIXEL ART BUTON PAINTER ─────────────────────────────────────────────────

class _PixelButonPainter extends CustomPainter {
  final Color renk;
  final bool aktif;
  static const _p = 4.0; // pixel kare boyutu

  _PixelButonPainter({required this.renk, required this.aktif});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Metalik dış çerçeve ──
    final frameRect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(9));
    canvas.drawRRect(frameRect, Paint()
      ..shader = LinearGradient(
        colors: aktif
            ? [const Color(0xFF3a3a3a), const Color(0xFF0a0a0a)]
            : [const Color(0xFF2a2a2a), const Color(0xFF080808)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h)));

    // Çerçeve iç kenar (üst-sol parlak, alt-sağ karanlık)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(1.5, 1.5, w - 3, h - 3), const Radius.circular(7.5)),
      Paint()
        ..color = Colors.white.withValues(alpha: aktif ? 0.30 : 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // ── İç buton alanı ──
    final inner = Rect.fromLTWH(3.5, 3, w - 7, h - 6);
    final darkRenk = aktif ? Color.lerp(renk, Colors.black, 0.52)! : const Color(0xFF2a2a2a);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, const Radius.circular(5)),
      Paint()..shader = LinearGradient(
        colors: aktif ? [renk, darkRenk] : [const Color(0xFF555555), const Color(0xFF1a1a1a)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ).createShader(inner),
    );

    if (!aktif) return;

    // ── Pixel köşe dekorasyonları ──
    final pixRenk = Color.lerp(renk, Colors.black, 0.62)!;
    final pp = Paint()..color = pixRenk;

    // Pattern: L-şekli (köşeden içe doğru basamaklı)
    const pattern = [
      [5.0, 5.0], [9.0, 5.0], [13.0, 5.0],
      [5.0, 9.0], [9.0, 9.0],
      [5.0, 13.0],
      [13.0, 9.0],
    ];

    void kose(double cx, double cy, bool mx, bool my) {
      for (final pos in pattern) {
        final dx = mx ? -pos[0] - _p : pos[0];
        final dy = my ? -pos[1] - _p : pos[1];
        canvas.drawRect(Rect.fromLTWH(cx + dx, cy + dy, _p, _p), pp);
      }
    }

    kose(0, 0, false, false); // sol üst
    kose(w, 0, true, false);  // sağ üst
    kose(0, h, false, true);  // sol alt
    kose(w, h, true, true);   // sağ alt

    // ── Üst glossy şerit ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(5, 4, w - 10, (h - 6) * 0.32), const Radius.circular(4)),
      Paint()..color = Colors.white.withValues(alpha: 0.16),
    );
  }

  @override
  bool shouldRepaint(_PixelButonPainter old) => old.renk != renk || old.aktif != aktif;
}

// ─── DAİRE GERİ SAYIM ────────────────────────────────────────────────────────

/// 🚗 Geçiş göstergesinin halkası: soluk taban çember + üstünde dönen bir yay.
/// [donus] negatif verilir → saat yönünün TERSİNE döner.
/// [oran] 0..1 tamamlanma; yayın uzunluğu buna göre büyür, oyuncu ne kadar
/// kaldığını bir bakışta görür.
class _GecisHalkaPainter extends CustomPainter {
  final double donus;
  final double oran;
  const _GecisHalkaPainter({required this.donus, required this.oran});

  @override
  void paint(Canvas canvas, Size size) {
    final merkez = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;
    final rect = Rect.fromCircle(center: merkez, radius: r);

    canvas.drawCircle(merkez, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.black.withValues(alpha: 0.45));

    // Tamamlanma yayı — en az bir dilim hep görünsün ki halka "ölü" durmasın.
    final tarama = (0.18 + 0.72 * oran.clamp(0.0, 1.0)) * 2 * pi;
    canvas.drawArc(rect, donus, tarama, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF4FC3F7));
  }

  @override
  bool shouldRepaint(_GecisHalkaPainter old) =>
      old.donus != donus || old.oran != oran;
}

class _DairePainter extends CustomPainter {
  final double progress; // 0.0 (boş) → 1.0 (tam dolu)
  _DairePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Arka plan dairesi
    canvas.drawCircle(c, r, Paint()..color = Colors.white.withValues(alpha: 0.10));

    // Sarı dilim — saat yönünde, 12'den başlar
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -pi / 2,                  // başlangıç: yukarı (12)
        2 * pi * progress,        // saat yönü (+)
        true,                     // merkeze bağlı dilim
        Paint()..color = const Color(0xFFFFD700),
      );
    }

    // İnce siyah çerçeve
    canvas.drawCircle(c, r, Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(_DairePainter old) => old.progress != progress;
}

// ─── TYPEWRITER TEXT ──────────────────────────────────────────────────────────

class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  const TypewriterText({super.key, required this.text, this.style, this.textAlign = TextAlign.center});

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _gorunen = '';
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _baslat(widget.text);
  }

  @override
  void didUpdateWidget(TypewriterText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _timer?.cancel();
      _gorunen = '';
      _index = 0;
      _baslat(widget.text);
    }
  }

  void _baslat(String metin) {
    if (metin.isEmpty) return;
    _timer = Timer.periodic(const Duration(milliseconds: 32), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_index < metin.length) {
        setState(() => _gorunen = metin.substring(0, ++_index));
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text(_gorunen, style: widget.style, textAlign: widget.textAlign);
}
