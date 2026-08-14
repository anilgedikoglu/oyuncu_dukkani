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
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  const DukkanSeviye({required this.seviye, required this.isim, required this.kira, required this.minGun});

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

const List<DukkanSeviye> tumDukkanlar = [
  DukkanSeviye(seviye: 1, isim: 'Bodrum Kat Dükkan',    kira: 300,  minGun: 1),
  DukkanSeviye(seviye: 2, isim: 'Mahalle Köşe Dükkanı', kira: 600,  minGun: 3),
  DukkanSeviye(seviye: 3, isim: 'Cadde Dükkanı',        kira: 900,  minGun: 5),
  DukkanSeviye(seviye: 4, isim: 'Çarşı Dükkanı',        kira: 1200, minGun: 8),
  DukkanSeviye(seviye: 5, isim: 'AVM Dükkanı',          kira: 1500, minGun: 10),
];

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
  bool _sesAcik = true;
  bool _ayarlarAcik = false;
  bool _yukleniyor = false;
  bool _kayitVar = false;
  int? _enYuksekGun;

  @override
  void initState() {
    super.initState();
    KayitServisi.enYuksekGunYukle().then((v) { if (mounted) setState(() => _enYuksekGun = v); });
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
                const Spacer(flex: 3),
                Center(child: _menuButon('Yeni Oyun', _yeniOyun)),
                const SizedBox(height: 12),
                Center(child: _menuButon('Devam Et', (_kayitVar && !_yukleniyor) ? () => _devamEt() : null)),
                const SizedBox(height: 12),
                Center(child: _menuButon('Ayarlar', () => setState(() => _ayarlarAcik = true))),
                if (_enYuksekGun != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    'En yüksek: $_enYuksekGun. gün',
                    style: const TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                  ),
                ],
                const Spacer(flex: 1),
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
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('🔊 Ses:', style: TextStyle(fontSize: 16, color: Color(0xFF3a2000), fontWeight: FontWeight.bold)),
                GestureDetector(
                  onTap: () => setState(() { _sesAcik = !_sesAcik; SesServisi.sesAcik = _sesAcik; }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: _sesAcik ? const Color(0xFF228B22) : const Color(0xFF8B0000), borderRadius: BorderRadius.circular(8)),
                    child: Text(_sesAcik ? 'AÇIK' : 'KAPALI', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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


// ─── ÖZEL MÜŞTERİ (HIRSIZ / POLİS / VERGİCİ) ────────────────────────────────

enum OzelMusteriTip { hirsiz, polis, vergici, kurye, toptanci }

class OzelMusteri {
  final OzelMusteriTip tip;
  final String gorsel;
  final String ad;
  final int ilkMiktar;
  final String ilkMesaj;
  final String? kuryeAd;    // kurye için kurye ismi
  final String? kuryeYemek; // kurye için yemek ismi

  OzelMusteri({required this.tip, required this.gorsel, required this.ad, required this.ilkMiktar, required this.ilkMesaj, this.kuryeAd, this.kuryeYemek});

  static OzelMusteri olustur(OzelMusteriTip tip) {
    final rng = Random();
    switch (tip) {
      case OzelMusteriTip.hirsiz:
        final x = 50 + rng.nextInt(151);
        return OzelMusteri(tip: tip, gorsel: 'assets/hirsiz.png', ad: 'Hırsız', ilkMiktar: x, ilkMesaj: 'Eller yukarı! Bana acilen $x lira vereceksin!');
      case OzelMusteriTip.polis:
        final x = 30 + rng.nextInt(221);
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
    }
  }
}

// ─── PAZARLIK MODELİ ─────────────────────────────────────────────────────────

enum PazarlikDurum { devamEdiyor, anlasildi, gitti }

class PazarlikSeans {
  final bool musteriSatiyor;
  final int piyasaFiyati;
  final MusteriOzellik ozellik;
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

  PazarlikSeans({
    required this.musteriSatiyor,
    required this.piyasaFiyati,
    required this.musteriTeklif,
    required this.oyuncuTeklif,
    required this.maxTur,
    required this.ozellik,
    required double reservationPrice,
  })  : _reservationPrice = reservationPrice,
        turSayisi = 0,
        durum = PazarlikDurum.devamEdiyor,
        mesaj = '';

  static double _clamp(double v, double lo, double hi) => v < lo ? lo : v > hi ? hi : v;
  static double _rnd(double a, double b) => a + Random().nextDouble() * (b - a);

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

    // ── 2. Rezervasyon sınırı aşıldıysa → kabul ──
    if (musteriSatiyor  && oyuncuTeklif >= _reservationPrice) return _kabul(oyuncuTeklif.toDouble());
    if (!musteriSatiyor && oyuncuTeklif <= _reservationPrice) return _kabul(oyuncuTeklif.toDouble());

    // ── 3. Goodwill: oyuncunun bu turki konsesyonu ──
    double goodwill = 0;
    if (_oyuncuGecmisi.length >= 2) {
      final prev = _oyuncuGecmisi[_oyuncuGecmisi.length - 2];
      final myMove = musteriSatiyor
          ? (oyuncuTeklif - prev).toDouble()
          : (prev - oyuncuTeklif).toDouble();
      goodwill = _clamp(myMove / (mp * 0.08), 0, 1);
    }

    // ── 4. Frustration ──
    final frustrationGrowth = (1 - pat) * 0.18 + (1 - intel) * 0.04;
    _frustration = _clamp(_frustration + frustrationGrowth, 0, 1);

    // ── 5. Müşteri karşı teklif miktarını hesapla ──
    // Erken turda büyük konsesyon, geç turda küçük — ama her zaman en az 1
    // Sürpriz çeşitlilik: %10 büyük sıçrama, %20 orta sıçrama, %70 normal/küçük
    final gapToReserv = musteriSatiyor
        ? (musteriTeklif - _reservationPrice).abs()
        : (_reservationPrice - musteriTeklif).abs();
    final baseRatio = _clamp(0.18 - progress * 0.15, 0.02, 0.18);
    final rng = Random();
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
    final move = (gapToReserv * concessionRatio + goodwill * mp * 0.03)
        .clamp(1, double.infinity)
        .round();

    int yeniMusteriTeklif;
    if (musteriSatiyor) {
      yeniMusteriTeklif = (musteriTeklif - move)
          .clamp(_reservationPrice.ceil(), musteriTeklif - 1).toInt();
    } else {
      yeniMusteriTeklif = (musteriTeklif + move)
          .clamp(musteriTeklif + 1, _reservationPrice.floor()).toInt();
    }

    // ── 6. Rezervasyon tavanına dayandıysa: kabul/git kararı ──
    final atFloor = musteriSatiyor
        ? yeniMusteriTeklif <= _reservationPrice.ceil()
        : yeniMusteriTeklif >= _reservationPrice.floor();

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
    if (turSayisi > 1 && Random().nextDouble() < walkChance) return _git();

    // ── 9. Karşı teklifi uygula ve devam et ──
    musteriTeklif = yeniMusteriTeklif;
    _karsiTeklifMesaj();
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

  void _karsiTeklifMesaj() {
    final rng = Random();
    final x = musteriTeklif;
    const sablonlar = [
      "Maalesef bu fiyata olmaz. X'e ne dersin?",
      'Verdiğin fiyat benim için uygun değil. X yapalım mı?',
      'Anlaşabilmemiz için farklı bir fiyatta buluşmamız gerek. X diyelim mi?',
      "Kabul etmiyorum. X'e ne dersin?",
      'Bunu kabul edemem. X diyebilirim?',
    ];
    mesaj = sablonlar[rng.nextInt(sablonlar.length)].replaceAll('X', '$x');
  }

  PazarlikDurum _kabul(double fiyat) {
    musteriTeklif = fiyat.round();
    durum = PazarlikDurum.anlasildi;
    final x = musteriTeklif;
    final sablonlar = [
      'Teklifini kabul ediyorum, teşekkürler!',
      'Bu fiyat benim için uygun, çok sağol!',
      '$x liralık teklifini kabul ettim!',
      '$x benim için okeydir, kabul!',
      'Anlaştık o zaman!',
      'Güzel fiyat, aldım kabul ettim!...',
      'Neden olmasın, kabul ediyorum.',
      'Peki, dediğin gibi olsun. Kabul!',
    ];
    mesaj = sablonlar[Random().nextInt(sablonlar.length)];
    return durum;
  }

  PazarlikDurum _git() {
    durum = PazarlikDurum.gitti;
    final rng = Random();
    if (_frustration > 0.6) {
      const m = ['Sen şaşırmışsın, konuşmasak daha iyi!','Senin piyasadan hiç mi haberin yok!','Yok artık Lebron James!','Oldu paşam, Malkara Keşan!','Sen tok satıcısın, anlaşıldı!...','Beni aptal yerine koyamazsın!'];
      mesaj = m[rng.nextInt(m.length)];
    } else if (turSayisi >= maxTur) {
      const m = ['Yok ya seninle anlaşamıyoruz...','Olmadı, olduramadık...','Pazarlık benim için bitmiştir!...','Biz bu işi unutalım bence.','Ne sen Leyla\'sın ne de ben Mecnun.','Tekliflerimiz ikimize de makul gelmedi.','Başka işlerim var, gitmeliyim...','Güzel pazarlıktı ama olmadı.'];
      mesaj = m[rng.nextInt(m.length)];
    } else {
      const m = ['Dur ya, vazgeçtim!...','Şu teklifle anında vazgeçtim!','Dolandırılacağım sanırım, kaçıyorum!...','Seninle ortayı bulamıyoruz.'];
      mesaj = m[rng.nextInt(m.length)];
    }
    return durum;
  }
}

// ─── SES SERVİSİ ─────────────────────────────────────────────────────────────

class SesServisi {
  static bool sesAcik = true;

  static void kapiyiCal() {
    if (!sesAcik) return;
    _cal('sounds/kapi.mp3');
  }

  static void paraGirdi() {
    if (!sesAcik) return;
    _cal('sounds/paragirdi.mp3');
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

class KayitServisi {
  static const _key = 'oyun_kayit';
  static const _enYuksekGunKey = 'en_yuksek_gun';

  static Future<void> kaydet(GameState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
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
}

// ─── VERİ MODELLERİ ──────────────────────────────────────────────────────────

enum ItemCategory { cd, konsol, aksesuar }

class GameItem {
  final String id;
  final String name;
  final String gorsel;
  final ItemCategory category;
  final int basePrice;
  final int kondisyon;
  final int? maliyet; // oyuncu bu ürünü kaça aldı (başlangıç envanteri ise null)
  final bool curuk;      // çürük/hasarlı — piyasa değeri %35'e düşer, tamir edilebilir
  final bool kapaliKutu; // kapalı kutu — açılana kadar satılamaz, içinden random ürün çıkar

  GameItem({required this.id, required this.name, required this.gorsel, required this.category, required this.basePrice, required this.kondisyon, this.maliyet, this.curuk = false, this.kapaliKutu = false});

  /// Çürük ürünün piyasa değeri %35'e düşer. Tüm pazarlık hesapları bunu kullanır.
  static const double curukCarpani = 0.35;
  int get etkinFiyat => curuk ? (basePrice * curukCarpani).round().clamp(1, basePrice) : basePrice;

  String get kondisyonYildiz => '★' * kondisyon + '☆' * (5 - kondisyon);

  GameItem kopya() => GameItem(id: id, name: name, gorsel: gorsel, category: category, basePrice: basePrice, kondisyon: kondisyon, maliyet: maliyet, curuk: curuk, kapaliKutu: kapaliKutu);

  /// Alan bazlı kopya (tamir, çürütme, maliyet atama için)
  GameItem kopyaWith({int? kondisyon, int? maliyet, bool? curuk, bool? kapaliKutu}) => GameItem(
    id: id, name: name, gorsel: gorsel, category: category, basePrice: basePrice,
    kondisyon: kondisyon ?? this.kondisyon,
    maliyet: maliyet ?? this.maliyet,
    curuk: curuk ?? this.curuk,
    kapaliKutu: kapaliKutu ?? this.kapaliKutu,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'gorsel': gorsel,
    'category': category.name, 'basePrice': basePrice, 'kondisyon': kondisyon,
    if (maliyet != null) 'maliyet': maliyet,
    if (curuk) 'curuk': true,
    if (kapaliKutu) 'kapaliKutu': true,
  };

  factory GameItem.fromJson(Map<String, dynamic> j) => GameItem(
    id: j['id'] as String, name: j['name'] as String, gorsel: j['gorsel'] as String,
    category: ItemCategory.values.firstWhere((e) => e.name == j['category'], orElse: () => ItemCategory.cd),
    basePrice: j['basePrice'] as int, kondisyon: j['kondisyon'] as int,
    maliyet: j['maliyet'] as int?,
    curuk: (j['curuk'] as bool?) ?? false,
    kapaliKutu: (j['kapaliKutu'] as bool?) ?? false,
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

  Customer({required this.name, required this.gorsel, required this.musteriSatiyor, required this.item, required this.ilkTeklif, required this.ozellik});

  String get selamMesaji => musteriSatiyor
      ? (item.id == 'kolonya'
          ? 'Ben kolonya satıyorum, üreticiyim. İlgilenir misin?'
          : 'Merhaba, ben $name. Elimde ${item.name} var, satmak istiyorum. İlgilenir misin?')
      : 'Selam! Ben $name. Elinde ${item.name} olduğunu duydum, bana satar mısın?';
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
  List<OzelMusteriTip> _ozelTipSirasi = [OzelMusteriTip.hirsiz, OzelMusteriTip.polis, OzelMusteriTip.vergici, OzelMusteriTip.kurye];
  int _ozelTipIndex = 0;

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
  String? _sonUrunId;               // ardışık aynı ürün engeli

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
  String mesaj = 'Dükkan açıldı! İlk müşteri bekleniyor...';
  Customer? aktifMusteri;
  PazarlikSeans? aktifPazarlik;
  bool musteriGorunuyor = false;
  bool musteriKabulBekliyor = false;
  DukkanSeviye aktifDukkan = tumDukkanlar[0]; // Seviye 1'den başla

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
    final havuz = _baslangicUrunler.where((u) => u.id != 'kolonya').toList();
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
    final havuz = _baslangicUrunler.where((u) => u.id != 'kolonya').toList();
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

  final List<Map<String, String>> musteriHavuzu = [
    {'gorsel': 'assets/musteri_1.png', 'cinsiyet': 'E'},
    {'gorsel': 'assets/musteri_2.png', 'cinsiyet': 'K'},
    {'gorsel': 'assets/musteri_3.png', 'cinsiyet': 'E'},
    {'gorsel': 'assets/musteri_4.png', 'cinsiyet': 'K'},
    {'gorsel': 'assets/musteri_5.png', 'cinsiyet': 'K'},
    {'gorsel': 'assets/musteri_6.png', 'cinsiyet': 'E'},
    {'gorsel': 'assets/musteri_7.png', 'cinsiyet': 'K'},
    {'gorsel': 'assets/musteri_8.png', 'cinsiyet': 'K'},
    {'gorsel': 'assets/musteri_9.png', 'cinsiyet': 'K'},
    {'gorsel': 'assets/musteri_10.png', 'cinsiyet': 'K'},
    {'gorsel': 'assets/musteri_11.png', 'cinsiyet': 'E'},
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
    aktifDukkan = tumDukkanlar[(j['aktifDukkanSeviye'] as int) - 1];
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
      if (tip == OzelMusteriTip.toptanci) continue; // Rıza ayrı programda
      if (!_ozelTipSirasi.contains(tip)) _ozelTipSirasi.add(tip);
    }
    // Rıza rotasyona sızmışsa çıkar (ara sürüm kayıtları için)
    _ozelTipSirasi.removeWhere((t) => t == OzelMusteriTip.toptanci);
    _ozelTipIndex = j['ozelTipIndex'] as int;
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
    kazanilanRozetler      = ((j['kazanilanRozetler'] as List?) ?? []).map((e) => e as String).toSet();
    _rizaBugunGeldi        = (j['rizaBugunGeldi'] as bool?) ?? false;
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
    'aktifDukkanSeviye': aktifDukkan.seviye,
    'slotlar': slotlar.map((s) => s?.toJson()).toList(),
    'sonrakiOzelMusteri': _sonrakiOzelMusteriSayisi,
    'ozelSayac': _ozelMusteriSayaci,
    'ozelTipSirasi': _ozelTipSirasi.map((t) => t.name).toList(),
    'ozelTipIndex': _ozelTipIndex,
    'toplamTeklif': toplamTeklifSayisi,
    'krediKalanTaksit': krediKalanTaksit,
    'krediTaksitMiktar': krediTaksitMiktar,
    'tamamlananKrediSayisi': tamamlananKrediSayisi,
    'imacSatinAlindi': imacSatinAlindi,
    'kolonyaKullanim': kolonyaKullanim,
    'tamirSetiAdet': tamirSetiAdet,
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
    'kazanilanRozetler': kazanilanRozetler.toList(),
    'rizaBugunGeldi': _rizaBugunGeldi,
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
    notifyListeners();
  }

  void yeniMusteriGonder() {
    _ozelMusteriSayaci++;
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
    // Özel müşteri vakti mi?
    if (_ozelMusteriSayaci >= _sonrakiOzelMusteriSayisi) {
      final tip = _ozelTipSirasi[_ozelTipIndex % _ozelTipSirasi.length];
      _ozelTipIndex++;
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
    final isimListesi = secilen['cinsiyet'] == 'E' ? _erkekIsimleri : _kadinIsimleri;
    final isim = isimListesi[rng.nextInt(isimListesi.length)];
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
      final adaylar = mevcut.length > 1 ? mevcut.where((u) => u.id != _sonUrunId).toList() : mevcut;
      secilenUrun = adaylar[rng.nextInt(adaylar.length)];
    } else {
      // Kolonya zaten varsa tekrar kolonya satan müşteri gelmesin
      final tumHavuz = kolonyaKullanim > 0
          ? _baslangicUrunler.where((u) => u.id != 'kolonya').toList()
          : _baslangicUrunler.toList();
      // Ardışık aynı ürün engeli: bir önceki ürün havuzdan çıkar (birden fazla varsa)
      final satisHavuzu = tumHavuz.length > 1 ? tumHavuz.where((u) => u.id != _sonUrunId).toList() : tumHavuz;
      secilenUrun = satisHavuzu[rng.nextInt(satisHavuzu.length)];
    }
    _sonUrunId = secilenUrun.id; // bir sonraki seçimde bu ürün hariç tutulur

    // Yeni model: perceivedValue → reservationPrice → openingOffer
    // etkinFiyat: çürük üründe piyasa değeri %35'e düşer
    final fiyat  = secilenUrun.etkinFiyat;
    final pv     = ozellik.perceivedValue(secilenUrun.kondisyon, fiyat);
    final reserv = _piyasaEtkisi(ozellik.reservationPrice(pv, fiyat, musteriSatiyor), musteriSatiyor);
    final openingRaw = ozellik.openingOffer(reserv, fiyat, musteriSatiyor);
    final ilkTeklif  = openingRaw.round();

    aktifMusteri = Customer(name: isim, gorsel: gorsel, musteriSatiyor: musteriSatiyor, item: secilenUrun, ilkTeklif: ilkTeklif, ozellik: ozellik);
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
    if (m.musteriSatiyor) {
      if (para >= anlasilanFiyat) {
        if (m.item.id == 'kolonya') {
          // Kolonya slota girmez — ayrı tutulur, +1 ilave
          kolonyaKullanim = 10;
        } else {
          final itemMaliyet = m.item.kopyaWith(maliyet: anlasilanFiyat);
          if (!urunEkle(itemMaliyet)) { mesaj = 'Envanter dolu!'; _musteriGonder(); return; }
        }
        para -= anlasilanFiyat;
        SesServisi.paraGirdi();
      } else {
        mesaj = 'Yeterli paran yok! 💸';
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
    para -= kira;
    SesServisi.paraGirdi();
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

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late GameState _state;
  late AnimationController _slideController;
  late Animation<double> _slideAnim;
  bool _envanterAcik = false;
  bool _gunBitiPopupGosterildi = false;
  bool _pazarlikBekleniyor = false;
  bool _bilgisayarGeldiGosterildi = false;
  bool _gameOverGosterildi = false; // game over popup gösterildiyse diğer popup'ları engelle
  String? _kolonyaGeciciMesaj; // 3 saniyeliğine gösterilecek özel mesaj
  Timer? _kolonyaMesajTimer;
  Timer? _kuryeTimer;
  int _kolonyaSonrasiSonIdx = -1; // alıcı + kolonya sonrası tekrarlamasın diye son seçilen mesaj indeksi
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
    _state.addListener(_daireHedefGuncelle);
    _daireTicker = createTicker(_daireTick)..start();
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
    _daireTicker.dispose();
    _state.removeListener(_daireHedefGuncelle);
    _slideController.dispose();
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
              style: TextStyle(color: Colors.white70, fontSize: 15)),
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
      _rozetPopup(rozet);
    });
  }

  void _rozetPopup(Rozet r) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF120e18),
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

  /// Seri bonusu ve günlük hedef tamamlanmasını kısa bir SnackBar ile duyurur.
  /// Popup kullanmıyoruz — oyun akışını kesmesin, sadece dopamin dokunuşu.
  void _anlikBildirimleriIsle() {
    if (_state.sonKomboBonusu > 0) {
      final b = _state.sonKomboBonusu;
      final k = _state.kombo;
      _state.sonKomboBonusu = 0; // tüket
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('🔥 $k\'lü seri!  +$b lira'),
          duration: const Duration(milliseconds: 1600),
          backgroundColor: const Color(0xFFB35A00),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(40, 0, 40, 130),
        ));
      });
    }
    if (_state.hedefYeniTamamlandi) {
      final h = _state.gunlukHedef;
      _state.hedefYeniTamamlandi = false; // tüket
      if (h != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('🎯 Günün hedefi tamam!  +${h.odul} lira'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF1a6b32),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(28, 0, 28, 130),
          ));
        });
      }
    }
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

  void _marketPopup() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0d1117),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFf78166).withValues(alpha: 0.5), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFf78166).withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  border: Border(bottom: BorderSide(color: const Color(0xFFf78166).withValues(alpha: 0.3))),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('🛒 ', style: TextStyle(fontSize: 20)),
                  Text('MARKET', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFFf78166), letterSpacing: 2)),
                ]),
              ),
              // Ürün grid
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                        ],
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF21262d),
                          foregroundColor: Colors.white70,
                          minimumSize: const Size(double.infinity, 42),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: const BorderSide(color: Color(0xFF30363d)),
                        ),
                        child: const Text('Kapat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _marketUrunKart({
    required String ikon,
    required String isim,
    required int fiyat,
    required bool satinAlindi,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
            if (satinAlindi)
              const Text('✅ Alındı', style: TextStyle(fontSize: 10, color: Color(0xFF3fb950), fontWeight: FontWeight.bold))
            else
              Text('$fiyat', style: const TextStyle(fontSize: 11, color: Color(0xFFf78166), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  TOPTANCI — günlük stok, ucuz ürün / çürük ürün / tamir seti / kapalı kutu
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _toptanciPopup({bool ziyaret = false}) async {
    if (ziyaret) {
      _state.toptanciZiyaretiTazele(); // kapıya geldiyse taze stok
    } else {
      _state.toptanciStokKontrol();    // stok bugüne aitse korunur, değilse üretilir
    }
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final indirimliGun = _state.gunlukToptanciIndirim > 0;
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.82),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF14100a),
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
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF21262d), foregroundColor: Colors.white70,
                              minimumSize: const Size(double.infinity, 42),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              side: const BorderSide(color: Color(0xFF30363d)),
                            ),
                            child: const Text('Kapat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                        ]),
                      ),
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

  Widget _toptanciKart(int index, void Function(void Function()) setDlg) {
    final t = _state.toptanciStok[index];
    final alinabilir = !t.satildi && _state.para >= t.fiyat;

    // Tipine göre görünüm
    late final Widget gorselW;
    late final String isim;
    late final String altBilgi;
    late final Color renk;
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
          border: Border.all(color: renk.withValues(alpha: t.satildi ? 0.2 : 0.5), width: 1.2),
        ),
        child: Column(children: [
          Expanded(child: gorselW),
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
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(hata), duration: const Duration(seconds: 2),
                        backgroundColor: const Color(0xFF8B0000)));
                    }
                    setDlg(() {});
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: renk, foregroundColor: Colors.black,
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
  Widget _koleksiyonPaneli() {
    final tum = GameState.koleksiyonUrunleri;
    final satilan = _state.satilanUrunIdleri;
    final yuzde = tum.isEmpty ? 0 : (satilan.where((id) => tum.any((u) => u.id == id)).length * 100 / tum.length).round();
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF16131c),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF58a6ff).withValues(alpha: 0.4), width: 1.2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('📚 KOLEKSİYON', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF58a6ff), letterSpacing: 1)),
          const Spacer(),
          Text('%$yuzde', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF58a6ff))),
        ]),
        const SizedBox(height: 3),
        const Text('Sattığın her ürün burada açılır', style: TextStyle(fontSize: 9, color: Colors.white30)),
        const SizedBox(height: 8),
        Wrap(spacing: 5, runSpacing: 5, children: tum.map((u) {
          final acik = satilan.contains(u.id);
          return Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: acik ? const Color(0xFF0d2137) : Colors.black38,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: acik ? const Color(0xFF58a6ff).withValues(alpha: 0.7) : Colors.white12),
            ),
            child: acik
              ? Padding(padding: const EdgeInsets.all(2), child: Image.asset(u.gorsel, fit: BoxFit.contain))
              : const Icon(Icons.question_mark, size: 13, color: Colors.white24),
          );
        }).toList()),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HEDEFLER — bugünün hedefi, rozetler, koleksiyon
  // ═══════════════════════════════════════════════════════════════════════════
  void _hedeflerPopup() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.82),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF120e18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFa371f7).withValues(alpha: 0.6), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFa371f7).withValues(alpha: 0.12),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    border: Border(bottom: BorderSide(color: const Color(0xFFa371f7).withValues(alpha: 0.3))),
                  ),
                  child: Column(children: [
                    const Text('🏆 HEDEFLER',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFa371f7), letterSpacing: 2)),
                    const SizedBox(height: 2),
                    Text('${_state.kazanilanRozetler.length} / ${Rozet.tumu.length} rozet',
                      style: const TextStyle(fontSize: 11, color: Colors.white38)),
                  ]),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                    itemCount: Rozet.tumu.length + 2, // +bugün paneli +koleksiyon
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (c, i) {
                      if (i == 0) return _bugunPaneli();
                      if (i == Rozet.tumu.length + 1) return _koleksiyonPaneli();
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
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF21262d), foregroundColor: Colors.white70,
                      minimumSize: const Size(double.infinity, 42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: const BorderSide(color: Color(0xFF30363d)),
                    ),
                    child: const Text('Kapat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
                    backgroundColor: const Color(0xFF21262d),
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Color(0xFF30363d)),
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

  void _ayarlarPopup() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1a1008),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFd2a679), width: 1.5),
          ),
          title: const Text('⚙️ Ayarlar', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFd2a679), letterSpacing: 1)),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('🔊 Ses:', style: TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: () {
                  setDialogState(() {
                    SesServisi.sesAcik = !SesServisi.sesAcik;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: SesServisi.sesAcik ? const Color(0xFF228B22) : const Color(0xFF8B0000),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    SesServisi.sesAcik ? 'AÇIK' : 'KAPALI',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
          actions: [Center(child: ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFd2a679),
              foregroundColor: Colors.black,
              minimumSize: const Size(120, 40),
            ),
            child: const Text('Kapat', style: TextStyle(fontWeight: FontWeight.bold)),
          ))],
        ),
      ),
    );
  }

  void _browserPopup() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0d1117),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF30363d), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Browser.png — sabit yükseklikli başlık
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  child: SizedBox(
                    height: 110,
                    width: double.infinity,
                    child: Image.asset('assets/browser.png', fit: BoxFit.cover, alignment: Alignment.topCenter),
                  ),
                ),
                // İçerik — kaydırılabilir
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Kiralık Dükkanlar ──
                        _browserMenuItem(
                          ikon: '🏠',
                          baslik: 'Kiralık Dükkanlar',
                          altyazi: 'DükkanKirala.com — ${_state.aktifDukkan.isim}',
                          renk: const Color(0xFF58a6ff),
                          onTap: () { Navigator.pop(ctx); _dukkanKiralaPopup(); },
                        ),
                        const SizedBox(height: 10),
                        // ── Banka Kredisi ──
                        _browserMenuItem(
                          ikon: '🏦',
                          baslik: 'Banka Kredisi',
                          altyazi: _state.aktifKrediVar
                              ? 'Aktif kredi: ${_state.krediTaksitMiktar} × ${_state.krediKalanTaksit} taksit kaldı'
                              : 'İhtiyaç kredisi başvurusu yap',
                          renk: const Color(0xFF3fb950),
                          onTap: () { Navigator.pop(ctx); _bankaKrediPopup(); },
                        ),
                        const SizedBox(height: 10),
                        // ── Toptancı ──
                        _browserMenuItem(
                          ikon: '🚚',
                          baslik: 'Toptancı Rıza',
                          altyazi: _state.gunlukToptanciIndirim > 0
                              ? 'KAMPANYA! Bugün fiyatlar düşük 🔥'
                              : 'Ucuza mal al, kârına sat',
                          renk: const Color(0xFFd29922),
                          onTap: () { Navigator.pop(ctx); _toptanciPopup(); },
                        ),
                        const SizedBox(height: 10),
                        // ── Hedefler ──
                        _browserMenuItem(
                          ikon: '🏆',
                          baslik: 'Hedefler',
                          altyazi: '${_state.kazanilanRozetler.length}/${Rozet.tumu.length} rozet kazanıldı',
                          renk: const Color(0xFFa371f7),
                          onTap: () { Navigator.pop(ctx); _hedeflerPopup(); },
                        ),
                        const SizedBox(height: 10),
                        // ── Market ──
                        _browserMenuItem(
                          ikon: '🛒',
                          baslik: 'Market',
                          altyazi: 'Dükkanını geliştir',
                          renk: const Color(0xFFf78166),
                          onTap: () { Navigator.pop(ctx); _marketPopup(); },
                        ),
                        const SizedBox(height: 10),
                        // ── Ayarlar ──
                        _browserMenuItem(
                          ikon: '⚙️',
                          baslik: 'Ayarlar',
                          altyazi: SesServisi.sesAcik ? 'Ses: Açık' : 'Ses: Kapalı',
                          renk: const Color(0xFFd2a679),
                          onTap: () => _ayarlarPopup(),
                        ),
                        const SizedBox(height: 10),
                        // ── Yeniden Başlat ──
                        _browserMenuItem(
                          ikon: '🔄',
                          baslik: 'Yeniden Başlat',
                          altyazi: 'Oyunu sıfırla ve başa dön',
                          renk: const Color(0xFFE07B00),
                          onTap: () {
                            Navigator.pop(ctx);
                            _yenidenBaslatOnay();
                          },
                        ),
                        const SizedBox(height: 14),
                        // Kapat
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF21262d),
                            foregroundColor: Colors.white70,
                            minimumSize: const Size(double.infinity, 42),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            side: const BorderSide(color: Color(0xFF30363d)),
                          ),
                          child: const Text('Kapat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
          'Her şey kaybolacak!\nOyun baştan başlatılsın mı?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 15),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF21262d),
              foregroundColor: Colors.white70,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              side: const BorderSide(color: Color(0xFF30363d)),
            ),
            child: const Text('Hayır', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              KayitServisi.sil();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const GameScreen(yeniOyun: true)),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE07B00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Evet', style: TextStyle(fontWeight: FontWeight.bold)),
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
  }) {
    return GestureDetector(
      onTap: onTap,
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
          Icon(Icons.chevron_right, color: renk.withValues(alpha: 0.6), size: 20),
        ]),
      ),
    );
  }

  void _bankaKrediPopup() {
    if (_state.aktifKrediVar) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1a1008),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.orangeAccent, width: 1.5)),
          title: const Text('🏦 Aktif Kredi Var', textAlign: TextAlign.center, style: TextStyle(color: Colors.orangeAccent, fontSize: 18)),
          content: Text(
            'Hâlâ aktif bir krediniz var.\n\n${_state.krediTaksitMiktar} × ${_state.krediKalanTaksit} taksit kaldı.\n\nKrediniz bitince yeni başvuru yapabilirsiniz.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [Center(child: ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
            child: const Text('Tamam', style: TextStyle(fontWeight: FontWeight.bold)),
          ))],
        ),
      );
      return;
    }

    // Gün çarpanı: kaç. gün olduğuna göre banka daha fazla kredi verir
    final gun = _state.gun;
    final multiplier = gun <= 5 ? 1 : gun <= 10 ? 2 : gun <= 20 ? 3 : 4;

    // Taksit limitleri: önceki kredi geçmişine göre
    final tamamlanan = _state.tamamlananKrediSayisi;
    const minTaksit = 2;
    final maxTaksit = tamamlanan == 0 ? 3 : tamamlanan == 1 ? 6 : 9;

    // Başlangıç kredi tutarı: 1000–3000 × çarpan, 100'e yuvarlanmış
    final rng = Random();
    final baseSteps = 10 + rng.nextInt(21); // 10..30 → 1000..3000
    final baseAmount = (baseSteps * 100 * multiplier).clamp(500, 3000 * multiplier);
    final minAmount = 500;
    final maxAmount = 3000 * multiplier;

    // Faiz formülü: her taksit %5 ek (2 taksit=%5, 3=%10, ..., 9=%40)
    int hesaplaGeriOdeme(int tutar, int taksit) =>
        (tutar * (1.0 + 0.05 * (taksit - 1))).round();

    int alinanTutar = baseAmount;
    int taksitSayisi = minTaksit;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setD) {
          final geriOdeme = hesaplaGeriOdeme(alinanTutar, taksitSayisi);
          final gunlukKesinti = (geriOdeme / taksitSayisi).ceil();
          final faizPct = 5 * (taksitSayisi - 1);

          // Ok butonu yardımcısı
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

          return AlertDialog(
            backgroundColor: const Color(0xFF1a1008),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF3fb950), width: 1.5)),
            title: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('🏦 ', style: TextStyle(fontSize: 22)),
              Text('Banka Kredisi',
                  style: TextStyle(color: Color(0xFF3fb950), fontSize: 19, fontWeight: FontWeight.bold)),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Çarpan rozeti
                if (multiplier > 1)
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
                        '${multiplier}x kredi limiti aktif · $gun. gün',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                // Kredi tutarı satırı
                ayarSatiri(
                  label: 'Kredi tutarı:',
                  value: '$alinanTutar ₺',
                  color: const Color(0xFF3fb950),
                  onDown: alinanTutar > minAmount ? () => setD(() => alinanTutar -= 100) : null,
                  onUp: alinanTutar < maxAmount ? () => setD(() => alinanTutar += 100) : null,
                ),
                const SizedBox(height: 8),
                // Taksit sayısı satırı
                ayarSatiri(
                  label: 'Taksit:',
                  value: '$taksitSayisi gün',
                  color: Colors.orangeAccent,
                  onDown: taksitSayisi > minTaksit ? () => setD(() => taksitSayisi--) : null,
                  onUp: taksitSayisi < maxTaksit ? () => setD(() => taksitSayisi++) : null,
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
                      Text('+$alinanTutar ₺',
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
              ],
            ),
            actions: [
              Row(children: [
                Expanded(child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3a2000), foregroundColor: Colors.white),
                  child: const Text('Hayır', style: TextStyle(fontWeight: FontWeight.bold)),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _state.krediAl(alinanTutar, geriOdeme, taksitSayisi);
                    // Tebrik popup — 3 saniye sonra otomatik kapanır
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
                                'Tebrikler, $alinanTutar ₺ kredi alındı!',
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
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3fb950), foregroundColor: Colors.black),
                  child: const Text('Krediyi Al', style: TextStyle(fontWeight: FontWeight.bold)),
                )),
              ]),
            ],
          );
        },
      ),
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

  void _dukkanKiralaPopup() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1008),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFFFD700), width: 1.5)),
        title: Column(children: [
          const Text('🏠 DükkanKirala.com', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFFD700), letterSpacing: 1)),
          const SizedBox(height: 4),
          Text('Güncel dükkanın: ${_state.aktifDukkan.isim}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.white38)),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
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
                    Navigator.pop(ctx);
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
        ),
        actions: [Center(child: ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3a2000), foregroundColor: Colors.white),
          child: const Text('Kapat', style: TextStyle(fontWeight: FontWeight.bold)),
        ))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        _gunBitiKontrol();
        return Scaffold(
          body: Stack(
            children: [
              // 1. Sabit arka plan
              Positioned.fill(
                child: Image.asset('assets/bgbos.png', fit: BoxFit.cover, alignment: Alignment.center),
              ),
              // 2. Kapı gölgesi (müşteri yokken görünür)
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: (_state.musteriGorunuyor || _state.ozelMusteriGorunuyor) ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Image.asset('assets/biri.png', fit: BoxFit.cover, alignment: Alignment.center),
                ),
              ),
              // ╔═══════════════════════════════════════════════════════════════╗
              // ║  KATMAN SİSTEMİ — Stack Z-order (arkadan öne)               ║
              // ║  1. bgbos.png        — sabit dükkan arkaplanı                ║
              // ║  2. biri.png         — kapı gölgesi (müşteri yokken)         ║
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
                  child: Image.asset(
                    _state.aktifOzelMusteri != null
                      ? _state.aktifOzelMusteri!.gorsel
                      : _state.aktifMusteri!.gorsel,
                    fit: BoxFit.contain, isAntiAlias: true, filterQuality: FilterQuality.high,
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
            ],
          ),
        );
      },
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
          // ── Sol: Gün ──
          Expanded(
            child: Container(
              height: 48,
              decoration: gunDecor,
              child: Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🗓️', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                  Text('${_state.gun}. GÜN',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFFFD700), height: 1.0)),
                ]),
              ),
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
          // ── Sağ: Bakiye ──
          Expanded(
            child: Container(
              height: 48,
              decoration: paraDecor,
              child: Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('💰', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text('${_state.para}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFFFD700), letterSpacing: 0.3)),
                ]),
              ),
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
              final kucukUrun = gorsel == 'assets/konsol_3.png' || gorsel == 'assets/oyuncudireksiyonu.png'
                  || gorsel == 'assets/konsol_4.png' || gorsel == 'assets/konsol_5.png' || gorsel == 'assets/konsol_6.png'
                  || gorsel == 'assets/joypad.png';
              // Ürüne özel küçültmeler (oranlar korunur)
              final urunOran = gorsel == 'assets/durum.png' ? 0.80 : (kucukUrun ? 0.85 : 1.0);
              final productSize = m.u(kUrunBoyu) * urunOran;
              // Yatay ince ayarlar da oransal (sabit px değil)
              final ekKaydir = (gorsel == 'assets/oyuncudireksiyonu.png' ? 0.0081 : 0.0)
                             + (gorsel == 'assets/konsol_2.png'          ? 0.0058 : 0.0)
                             + (gorsel == 'assets/konsol_3.png'          ? 0.0058 : 0.0);
              final productLeft = dx + m.u(kUrunSagKaydir + ekKaydir);
              // Alt kenarı masa çizgisine kilitli → üst kenar = taban - boy
              final productTop = m.y(kUrunTabani) - productSize - ofs;
              return Positioned(
                left: productLeft, top: productTop,
                child: Image.asset(
                  gorsel,
                  width: productSize, height: productSize, fit: BoxFit.contain,
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
                ? ((_state.aktifOzelMusteri!.tip == OzelMusteriTip.hirsiz) ? Colors.redAccent : (_state.aktifOzelMusteri!.tip == OzelMusteriTip.polis) ? Colors.blueAccent : (_state.aktifOzelMusteri!.tip == OzelMusteriTip.kurye) ? const Color(0xFFFF8C00) : Colors.orangeAccent).withValues(alpha: 0.7)
                : const Color(0xFFFFD700).withValues(alpha: 0.4)),
            ),
            child: _state.aktifMusteri != null && !_state.aktifMusteri!.musteriSatiyor &&
                   (_state.musteriKabulBekliyor || (_state.aktifPazarlik != null && _state.aktifPazarlik!.turSayisi == 0))
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      _state.aktifMusteri!.item.gorsel,
                      width: 100, height: 100, fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Transform.translate(
                        offset: const Offset(-15, 0),
                        child: Center(
                          child: TypewriterText(
                            text: _kolonyaGeciciMesaj ?? _state.mesaj,
                            style: TextStyle(fontSize: 14, color: const Color(0xFFFFD700)),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : TypewriterText(
                  text: _kolonyaGeciciMesaj ?? _state.mesaj,
                  style: TextStyle(fontSize: 14,
                    color: _state.aktifOzelMusteri != null
                      ? ((_state.aktifOzelMusteri!.tip == OzelMusteriTip.hirsiz) ? Colors.redAccent : (_state.aktifOzelMusteri!.tip == OzelMusteriTip.polis) ? Colors.blueAccent : (_state.aktifOzelMusteri!.tip == OzelMusteriTip.kurye) ? const Color(0xFFFF8C00) : Colors.orangeAccent)
                      : const Color(0xFFFFD700)),
                  textAlign: TextAlign.center,
                ),
          ),
        ),
      ],
    );
  }

  /// Özel müşteri isim etiketi. Konumu normal müşteriyle ORTAK kod tarafından
  /// (SahneMetrik + kIsimAlti) verilir — burada sadece görünüm var.
  Widget _ozelMusteriIsimEtiketi(OzelMusteri om) {
    Color renk;
    switch (om.tip) {
      case OzelMusteriTip.hirsiz:   renk = Colors.redAccent; break;
      case OzelMusteriTip.polis:    renk = Colors.blueAccent; break;
      case OzelMusteriTip.vergici:  renk = Colors.orangeAccent; break;
      case OzelMusteriTip.kurye:    renk = const Color(0xFFFF8C00); break; // parlak turuncu
      case OzelMusteriTip.toptanci: renk = const Color(0xFFd29922); break; // toptancı altın sarısı
    }
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
      onTap: onTap,
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
    final musteriCagirAktif = !_state.musteriKabulBekliyor && _state.aktifPazarlik == null && !_state.gunBitmeli;
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
          // Özel müşteriye kolonya ikram edilmişse EVET/HAYIR gizlenir (3 sn sonra gider)
          if (_state.musteriKabulBekliyor && _kolonyaGeciciMesaj == null) ...[
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
          if (_pazarlikBekleniyor) ...[
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
              onTap: () => setState(() => _envanterAcik = true),
              gradyan: const [Color(0xFF8c6aff), Color(0xFF311b92)],
              kenar: const Color(0xFFb39ddb),
            )),
          ]),
          // Kolonya Tut butonu — kolonya envanterde varsa görünür
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
        ],
      ),
    );
  }

  Widget _buildEnvanterOverlay() {
    // Bir kez hesapla — itemBuilder her kartta yeniden üretmesin
    final ekKartlar = _ekEnvanterKartlari;
    return GestureDetector(
      onTap: () => setState(() => _envanterAcik = false),
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: BoxDecoration(
                color: const Color(0xFF1a1008).withValues(alpha: 0.97),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: const Border(top: BorderSide(color: Color(0xFFFFD700), width: 1.5), left: BorderSide(color: Color(0xFFFFD700), width: 1.5), right: BorderSide(color: Color(0xFFFFD700), width: 1.5)),
              ),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFFFD700).withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2))),
                ),
                const Text('📦 ENVANTER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFFFD700), letterSpacing: 1.5)),
                const SizedBox(height: 10),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
              ]),
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
    return GestureDetector(
      onTap: curuk ? () => _tamirPopup(slotIndex) : null,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: curuk ? const Color(0xFF2a1010).withValues(alpha: 0.9) : const Color(0xFF2a1a0a).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: curuk
              ? const Color(0xFFcc3311).withValues(alpha: 0.8)
              : const Color(0xFFFFD700).withValues(alpha: 0.5), width: curuk ? 1.3 : 1),
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

  // ── Kapalı kutu açma ──
  void _kutuAcPopup(int slotIndex) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF120e18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFa371f7), width: 2)),
        title: const Column(mainAxisSize: MainAxisSize.min, children: [
          Text('🎁', style: TextStyle(fontSize: 44)),
          SizedBox(height: 4),
          Text('Kapalı Kutu', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFa371f7), fontSize: 19)),
        ]),
        content: const Text('İçinde ne olduğu belli değil. Sağlam bir şey de çıkabilir, çürük bir şey de...\n\nAçmak istiyor musun?',
          textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14)),
        actions: [Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dursun', style: TextStyle(color: Colors.white38)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final cikan = _state.kutuAc(slotIndex);
              if (cikan != null) _kutuSonucPopup(cikan);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFa371f7), foregroundColor: Colors.white),
            child: const Text('AÇ!', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ])],
      ),
    );
  }

  void _kutuSonucPopup(GameItem cikan) {
    final iyi = !cikan.curuk;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF120e18),
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

  // ── Çürük ürün tamiri ──
  void _tamirPopup(int slotIndex) {
    final item = _state.slotlar[slotIndex];
    if (item == null || !item.curuk) return;
    final setVar = _state.tamirSetiAdet > 0;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16100c),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF58a6ff), width: 2)),
        title: const Column(mainAxisSize: MainAxisSize.min, children: [
          Text('🔧', style: TextStyle(fontSize: 40)),
          SizedBox(height: 4),
          Text('Tamir', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF58a6ff), fontSize: 19)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(item.name, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Column(children: [
              const Text('Şu an', style: TextStyle(color: Colors.white38, fontSize: 10)),
              Text('${item.etkinFiyat}', style: const TextStyle(color: Color(0xFFff7043), fontSize: 17, fontWeight: FontWeight.bold)),
            ]),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 14),
              child: Text('→', style: TextStyle(color: Colors.white38, fontSize: 20))),
            Column(children: [
              const Text('Tamir sonrası', style: TextStyle(color: Colors.white38, fontSize: 10)),
              Text('~${item.basePrice}', style: const TextStyle(color: Color(0xFF3fb950), fontSize: 17, fontWeight: FontWeight.bold)),
            ]),
          ]),
          const SizedBox(height: 10),
          Text(
            setVar
              ? '1 tamir seti kullanılacak. (Kalan: ${_state.tamirSetiAdet})'
              : 'Tamir setin yok! Toptancıdan alabilirsin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: setVar ? Colors.white60 : const Color(0xFFff7043), fontSize: 12)),
        ]),
        actions: [Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç', style: TextStyle(color: Colors.white38)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: setVar ? () {
              Navigator.pop(ctx);
              if (_state.tamirEt(slotIndex)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('🔧 Ürün tamir edildi!'), duration: Duration(seconds: 2),
                  backgroundColor: Color(0xFF1a6b32)));
              }
            } : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF58a6ff), foregroundColor: Colors.black,
              disabledBackgroundColor: const Color(0xFF2a2a2a), disabledForegroundColor: Colors.white24),
            child: const Text('Tamir Et', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ])],
      ),
    );
  }

  void _ozelMusteriGonder() {
    _slideController.reverse().then((_) {
      if (mounted) _state.musteriAnimasyonBitti();
    });
  }

  void _ozelMusteriEvetPopup(OzelMusteri om) {
    final rng = Random();
    String mesaj = '';
    int kesinti = 0;

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

  void _ozelMusteriHayirPopup(OzelMusteri om) {
    final rng = Random();
    String mesaj = '';
    int kesinti = 0;

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
        // Kabul mesajı balonda görünsün, 1.5 sn sonra müşteri gitsin
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (!mounted) return;
          _slideController.reverse().then((_) { if (mounted) _state.musteriAnimasyonBitti(); });
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
      // Özel müşteriye ikram: 3 sn sonra müşteriyi parasız gönder
      // Tehdit eden tipler (hırsız/polis/vergici) "affediyorum" der; kurye/toptancı sadece teşekkür eder.
      final tip = _state.aktifOzelMusteri!.tip;
      final dostane = tip == OzelMusteriTip.kurye || tip == OzelMusteriTip.toptanci;
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
      _slideController.reverse().then((_) { if (mounted) _state.musteriAnimasyonBitti(); });
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

  void _teklifGonder() {
    final teklif = int.tryParse(_teklifController.text);
    if (teklif == null || teklif <= 0) return;
    widget.state.teklifVer(teklif);
    // Her durumda popup kapanır, mesaj ana ekranda balondan okunur
    Navigator.of(context).pop();
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
                    GestureDetector(
                      onTap: () {
                        final val = int.tryParse(_teklifController.text) ?? 0;
                        setState(() => _teklifController.text = (val - 10).clamp(1, 999999).toString());
                      },
                      child: Container(
                        width: 44, height: 54,
                        decoration: const BoxDecoration(color: Color(0xFF2a1a0a), borderRadius: BorderRadius.horizontal(left: Radius.circular(7))),
                        child: const Center(child: Text('▼', style: TextStyle(fontSize: 20, color: Color(0xFFFFD700)))),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _teklifController,
                        keyboardType: TextInputType.number,
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
                    GestureDetector(
                      onTap: () {
                        final val = int.tryParse(_teklifController.text) ?? 0;
                        setState(() => _teklifController.text = (val + 10).toString());
                      },
                      child: Container(
                        width: 44, height: 54,
                        decoration: const BoxDecoration(color: Color(0xFF2a1a0a), borderRadius: BorderRadius.horizontal(right: Radius.circular(7))),
                        child: const Center(child: Text('▲', style: TextStyle(fontSize: 20, color: Color(0xFFFFD700)))),
                      ),
                    ),
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
                  Expanded(child: ElevatedButton(
                    onPressed: _teklifGonder,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black, padding: EdgeInsets.zero),
                    child: FittedBox(fit: BoxFit.scaleDown, child: Text(m.musteriSatiyor ? 'Teklif Ver' : 'Fiyat Ver', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                  )),
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
