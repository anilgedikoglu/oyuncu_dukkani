import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OyuncuDukkaniApp());
}

class OyuncuDukkaniApp extends StatelessWidget {
  const OyuncuDukkaniApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oyuncu Dükkanı',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF1a1008)),
      home: const AnaMenuEkrani(),
    );
  }
}

// ─── DÜKKAN SEVİYE SİSTEMİ ───────────────────────────────────────────────────

class DukkanSeviye {
  final int seviye;
  final String isim;
  final int kira;

  const DukkanSeviye({required this.seviye, required this.isim, required this.kira});

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
  DukkanSeviye(seviye: 1, isim: 'Bodrum Kat Dükkan',    kira: 300),
  DukkanSeviye(seviye: 2, isim: 'Mahalle Köşe Dükkanı', kira: 600),
  DukkanSeviye(seviye: 3, isim: 'Cadde Dükkanı',        kira: 900),
  DukkanSeviye(seviye: 4, isim: 'Çarşı Dükkanı',        kira: 1200),
  DukkanSeviye(seviye: 5, isim: 'AVM Dükkanı',          kira: 1500),
];

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
  int? _enYuksekGun;

  @override
  void initState() {
    super.initState();
    KayitServisi.enYuksekGunYukle().then((v) { if (mounted) setState(() => _enYuksekGun = v); });
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
    final state = GameState.fromJson(json!);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => GameScreen(yeniOyun: false, yuklenenState: state)));
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
                Center(child: _menuButon('Devam Et', _yukleniyor ? null : () => _devamEt())),
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
  double reservationPrice(double pv, int marketPrice, bool musteriSatiyor) {
    if (!musteriSatiyor) { // NPC alıyor: maksimum ödeyeceği
      return (pv * (0.75 + pat * 0.20 + met * 0.05))
          .clamp(marketPrice * 0.50, marketPrice * 1.20);
    } else { // NPC satıyor: minimum alacağı
      return (pv * (1.25 - pat * 0.20 - met * 0.05))
          .clamp(marketPrice * 0.65, marketPrice * 1.50);
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

enum OzelMusteriTip { hirsiz, polis, vergici }

class OzelMusteri {
  final OzelMusteriTip tip;
  final String gorsel;
  final String ad;
  final int ilkMiktar;
  final String ilkMesaj;

  OzelMusteri({required this.tip, required this.gorsel, required this.ad, required this.ilkMiktar, required this.ilkMesaj});

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
    }
  }
}

// ─── PAZARLIK MODELİ ─────────────────────────────────────────────────────────

enum PazarlikDurum { devamEdiyor, anlasildi, gitti }

class PazarlikSeans {
  final bool musteriSatiyor;
  final int piyasaFiyati;
  final MusteriOzellik ozellik;
  final double _reservationPrice;

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

    final mp  = piyasaFiyati.toDouble();
    final pat   = ozellik.pat;
    final intel = ozellik.intel;
    final met   = ozellik.met;

    // ── 1. Rezervasyon sınırı aşıldıysa direkt kabul ──
    if (!musteriSatiyor && oyuncuTeklif <= _reservationPrice) {
      return _kabul(oyuncuTeklif.toDouble());
    }
    if (musteriSatiyor && oyuncuTeklif >= _reservationPrice) {
      return _kabul(oyuncuTeklif.toDouble());
    }

    // ── 2. Teklif zaten eşit veya geçtiyse kabul ──
    if (!musteriSatiyor && oyuncuTeklif <= musteriTeklif) return _kabul(oyuncuTeklif.toDouble());
    if (musteriSatiyor  && oyuncuTeklif >= musteriTeklif) return _kabul(oyuncuTeklif.toDouble());

    // ── 3. Goodwill hesapla ──
    double goodwill = 0;
    if (_oyuncuGecmisi.length >= 2) {
      final prev = _oyuncuGecmisi[_oyuncuGecmisi.length - 2];
      final concession = musteriSatiyor
          ? (oyuncuTeklif - prev).toDouble()   // arttırma = iyi
          : (prev - oyuncuTeklif).toDouble();  // düşürme = iyi
      goodwill = _clamp(concession / (mp * 0.10), 0, 1);
    }

    // ── 4. Concession trend analizi (zeka bağımlı) ──
    double inconsistency = _rnd(0, 0.3) * (1 - intel);
    bool fakeConcession  = false;
    if (_oyuncuGecmisi.length >= 3 && intel > 0.4) {
      final c1 = (_oyuncuGecmisi.last - _oyuncuGecmisi[_oyuncuGecmisi.length - 2]).abs().toDouble();
      final c2 = (_oyuncuGecmisi[_oyuncuGecmisi.length - 2] - _oyuncuGecmisi[_oyuncuGecmisi.length - 3]).abs().toDouble();
      fakeConcession = c2 > c1 * 3;
      inconsistency  = _clamp((c1 - c2).abs() / (mp * 0.05), 0, 1);
    }

    // ── 5. Frustration güncelle ──
    final frustrationGrowth = (1 - pat) * 0.20 + (1 - intel) * 0.05;
    _frustration = _clamp(
      _frustration + frustrationGrowth + inconsistency * (1 - pat) * 0.15,
      0, 1,
    );

    // ── 6. Walk away şansı ──
    final currentGap  = (musteriTeklif - oyuncuTeklif).abs().toDouble();
    final gapRatio    = currentGap / mp;
    final roundProgress = turSayisi / maxTur;
    double walkChance =
        _frustration * 0.25 +
        gapRatio * (1 - pat) * 0.30 +
        (fakeConcession && intel > 0.5 ? 0.15 : 0) +
        (turSayisi == 1 ? -0.20 : 0);
    walkChance = _clamp(walkChance, 0, 0.55);
    if (turSayisi > 1 && Random().nextDouble() < walkChance) {
      return _git();
    }

    // ── 7. Kabul eğrisi ──
    final proxThreshold = _clamp(0.04 + (1 - pat) * 0.12 + (1 - met) * 0.04, 0.02, 0.22);
    final gapFraction = currentGap / mp;
    if (gapFraction < proxThreshold) {
      final acceptChance = _clamp(
        (1 - gapFraction / proxThreshold) *
        (0.30 + goodwill * 0.25 + roundProgress * 0.20 + pat * 0.10),
        0, 0.88,
      );
      if (Random().nextDouble() < acceptChance) {
        final w = _rnd(0.55, 0.85);
        return _kabul(musteriTeklif * w + oyuncuTeklif * (1 - w));
      }
    }

    // ── 8. Tur bitti ──
    if (turSayisi >= maxTur) {
      if (gapFraction < 0.08 && Random().nextDouble() < 0.60) {
        final w = _rnd(0.55, 0.85);
        return _kabul(musteriTeklif * w + oyuncuTeklif * (1 - w));
      }
      return _git();
    }

    // ── 9. Karşı teklif üret ──
    final gapFactor  = _clamp(currentGap / (mp * 0.30), 0.3, 1.0);
    final baseMove   = 0.04 + pat * 0.03 + goodwill * 0.06;
    final intelBonus = intel * (fakeConcession ? -0.03 : 0.02);
    final progBonus  = roundProgress * 0.04;
    final moveRatio  = _clamp((baseMove + intelBonus + progBonus) * gapFactor, 0.01, 0.18);
    final moveAmount = moveRatio * mp;

    if (musteriSatiyor) {
      // NPC satıyor: her turda mutlaka düşsün
      // Sınırlar: _reservationPrice ≤ yeni < musteriTeklif
      final hedef = (musteriTeklif - moveAmount).round();
      final alt   = _reservationPrice.round();
      final ust   = musteriTeklif - 1;
      if (alt <= ust) {
        musteriTeklif = hedef.clamp(alt, ust);
      }
      // Not: oyuncunun teklifi çok düşükse burada anlaşma yoktur,
      // walk away veya kabul eğrisi halletmeli
      _karsiTeklifMesaj();
    } else {
      // NPC alıyor: her turda mutlaka yükselsin
      // Sınırlar: musteriTeklif < yeni ≤ _reservationPrice
      final hedef = (musteriTeklif + moveAmount).round();
      final alt   = musteriTeklif + 1;
      final ust   = _reservationPrice.round();
      if (alt <= ust) {
        musteriTeklif = hedef.clamp(alt, ust);
      }
      _karsiTeklifMesaj();
    }

    durum = PazarlikDurum.devamEdiyor;
    return durum;
  }

  void _karsiTeklifMesaj() {
    if (musteriSatiyor) {
      mesaj = 'En fazla $musteriTeklif₺ yapabilirim.';
    } else {
      mesaj = 'O zaman $musteriTeklif₺ vereyim.';
    }
  }

  PazarlikDurum _kabul(double fiyat) {
    musteriTeklif = fiyat.round();
    durum = PazarlikDurum.anlasildi;
    mesaj = 'Anlaştık! 🤝';
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

  GameItem({required this.id, required this.name, required this.gorsel, required this.category, required this.basePrice, required this.kondisyon, this.maliyet});

  String get kondisyonYildiz => '★' * kondisyon + '☆' * (5 - kondisyon);

  GameItem kopya() => GameItem(id: id, name: name, gorsel: gorsel, category: category, basePrice: basePrice, kondisyon: kondisyon, maliyet: maliyet);

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'gorsel': gorsel,
    'category': category.name, 'basePrice': basePrice, 'kondisyon': kondisyon,
    if (maliyet != null) 'maliyet': maliyet,
  };

  factory GameItem.fromJson(Map<String, dynamic> j) => GameItem(
    id: j['id'] as String, name: j['name'] as String, gorsel: j['gorsel'] as String,
    category: ItemCategory.values.firstWhere((e) => e.name == j['category']),
    basePrice: j['basePrice'] as int, kondisyon: j['kondisyon'] as int,
    maliyet: j['maliyet'] as int?,
  );
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
      ? 'Merhaba, ben $name. Elimde ${item.name} var, satmak istiyorum. İlgilenir misin?'
      : 'Selam! Ben $name. Elinde ${item.name} olduğunu duydum, bana satar mısın?';
}

// ─── OYUN DURUMU ─────────────────────────────────────────────────────────────

class GameState extends ChangeNotifier {
  int para = 500;
  int gun = 1;
  int musteriSayisi = 0;
  int gunlukMusteriSayisi = 0;
  int gunlukMusteriLimiti = 12; // ilk gün için üretilir
  OzelMusteri? aktifOzelMusteri;
  bool ozelMusteriGorunuyor = false;
  int _sonrakiOzelMusteriSayisi = 0; // kaçıncı müşteride özel gelecek
  int _ozelMusteriSayaci = 0;        // toplam müşteri sayacı (özel dahil değil)
  List<OzelMusteriTip> _ozelTipSirasi = [OzelMusteriTip.hirsiz, OzelMusteriTip.polis, OzelMusteriTip.vergici]; // sıra
  int _ozelTipIndex = 0;

  void _ozelMusteriSayaciniAyarla() {
    _sonrakiOzelMusteriSayisi = _ozelMusteriSayaci + 10 + Random().nextInt(11); // 10-20 sonra
  }
  int toplamTeklifSayisi = 0;
  int krediKalanTaksit = 0;
  int krediTaksitMiktar = 0;
  bool get aktifKrediVar => krediKalanTaksit > 0;
  bool imacSatinAlindi = false;
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
    GameItem(id: 'konsol1',  name: 'PlayStatyon',        gorsel: 'assets/konsol_1.png',            category: ItemCategory.konsol,  basePrice: 900,  kondisyon: 4),
    GameItem(id: 'konsol2',  name: 'Ninetendo',          gorsel: 'assets/konsol_2.png',            category: ItemCategory.konsol,  basePrice: 750,  kondisyon: 3),
    GameItem(id: 'konsol3',  name: 'Ateri',              gorsel: 'assets/konsol_3.png',            category: ItemCategory.konsol,  basePrice: 500,  kondisyon: 2),
    GameItem(id: 'aksesuar1',name: 'Oyuncu Direksiyonu', gorsel: 'assets/oyuncudireksiyonu.png',   category: ItemCategory.aksesuar,basePrice: 600,  kondisyon: 3),
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

  // Ürün ekle (boş slota koy)
  bool urunEkle(GameItem item) {
    for (int i = 0; i < acikSlotSayisi; i++) {
      if (slotlar[i] == null) {
        slotlar[i] = item.kopya();
        notifyListeners();
        return true;
      }
    }
    return false; // doldu
  }

  // Ürün çıkar (ilk eşleşen slottan)
  bool urunCikar(String itemId) {
    for (int i = 0; i < acikSlotSayisi; i++) {
      if (slotlar[i]?.id == itemId) {
        slotlar[i] = null;
        notifyListeners();
        return true;
      }
    }
    return false;
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
  ];
  List<int> _musteriSira = [];

  GameState() {
    gunlukMusteriLimiti = aktifDukkan.gunlukMusteriSayisiUret();
    _ozelTipSirasi.shuffle(Random());
    _ozelMusteriSayaciniAyarla();
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
    _ozelTipSirasi = (j['ozelTipSirasi'] as List).map((s) => OzelMusteriTip.values.firstWhere((e) => e.name == s as String)).toList();
    _ozelTipIndex = j['ozelTipIndex'] as int;
    toplamTeklifSayisi = j['toplamTeklif'] as int;
    krediKalanTaksit = (j['krediKalanTaksit'] as int?) ?? 0;
    krediTaksitMiktar = (j['krediTaksitMiktar'] as int?) ?? 0;
    imacSatinAlindi = (j['imacSatinAlindi'] as bool?) ?? false;
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
    'imacSatinAlindi': imacSatinAlindi,
  };

  @override
  void notifyListeners() {
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
      final mevcut = stokluUrunler;
      if (mevcut.isEmpty) {
        mesaj = '$isim geldi ama stokta ürün yok!';
        notifyListeners();
        return;
      }
      secilenUrun = mevcut[rng.nextInt(mevcut.length)];
    } else {
      secilenUrun = _baslangicUrunler[rng.nextInt(_baslangicUrunler.length)];
    }

    // Yeni model: perceivedValue → reservationPrice → openingOffer
    final pv     = ozellik.perceivedValue(secilenUrun.kondisyon, secilenUrun.basePrice);
    final reserv = ozellik.reservationPrice(pv, secilenUrun.basePrice, musteriSatiyor);
    final openingRaw = ozellik.openingOffer(reserv, secilenUrun.basePrice, musteriSatiyor);
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
    final pv = m.ozellik.perceivedValue(m.item.kondisyon, m.item.basePrice);
    final reserv = m.ozellik.reservationPrice(pv, m.item.basePrice, m.musteriSatiyor);
    // Açılış teklifi artık reservationPrice üzerinden geliyor (ilkTeklif zaten init'te hesaplandı)
    // Oyuncunun başlangıç teklifi: müşteri satıyorsa %65, alıyorsa %130
    final oyuncuIlkTeklif = m.musteriSatiyor
        ? (m.item.basePrice * 0.65).round()
        : (m.item.basePrice * 1.30).round();
    aktifPazarlik = PazarlikSeans(
      musteriSatiyor: m.musteriSatiyor,
      piyasaFiyati: m.item.basePrice,
      musteriTeklif: m.ilkTeklif,
      oyuncuTeklif: oyuncuIlkTeklif,
      maxTur: m.ozellik.maxTur,
      ozellik: m.ozellik,
      reservationPrice: reserv,
    );
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
    notifyListeners();
  }

  void teklifVer(int oyuncuTeklif) {
    if (aktifPazarlik == null || aktifMusteri == null) return;
    toplamTeklifSayisi++;
    final durum = aktifPazarlik!.oyuncuTeklifVer(oyuncuTeklif);
    if (durum == PazarlikDurum.anlasildi) {
      _anlasmayiTamamla();
    } else if (durum == PazarlikDurum.gitti) {
      mesaj = '${aktifMusteri!.name}: ${aktifPazarlik!.mesaj}';
      _musteriGonder();
    } else {
      notifyListeners();
    }
  }

  void _anlasmayiTamamla() {
    final m = aktifMusteri!;
    final p = aktifPazarlik!;
    final anlasilanFiyat = m.musteriSatiyor ? p.musteriTeklif : p.oyuncuTeklif;
    if (m.musteriSatiyor) {
      if (para >= anlasilanFiyat) {
        final itemMaliyet = GameItem(id: m.item.id, name: m.item.name, gorsel: m.item.gorsel, category: m.item.category, basePrice: m.item.basePrice, kondisyon: m.item.kondisyon, maliyet: anlasilanFiyat);
        if (!urunEkle(itemMaliyet)) { mesaj = 'Envanter dolu!'; _musteriGonder(); return; }
        para -= anlasilanFiyat;
        SesServisi.paraGirdi();
        mesaj = '${m.name}\'den "${m.item.name}" $anlasilanFiyat₺\'ye alındı! 📦';
      } else {
        mesaj = 'Yeterli paran yok! 💸';
        _musteriGonder();
        return;
      }
    } else {
        urunCikar(m.item.id);
      para += anlasilanFiyat;
      SesServisi.paraGirdi();
      mesaj = '${m.name} "${m.item.name}" ürününü $anlasilanFiyat₺\'ye aldı! 💰';
    }
    _musteriGonder();
  }

  void musteriReddet() {
    if (aktifMusteri == null) return;
    final isim = aktifMusteri!.name;
    final vazgecM = ['Anlaşmak isterdim ama olmadı...','En azından anlaşmayı denedik...','$isim sana kırgın ayrıldı...','Bu gelişte $isim mutlu olamadı.','Peki. Yanından son hız ayrılıyorum!','Seninle anlaşmak imkansız gibi!...','Faydalar faydasız, imkanlar imkansız...','En sert satıcılardan biri çıktın!...',"Daha da Davos'a gelmem!...",'Yine görüşeceğiz!...'];
    mesaj = vazgecM[Random().nextInt(vazgecM.length)];
    musteriKabulBekliyor = false;
    notifyListeners();
  }

  void imacSatin() {
    para -= 2000;
    imacSatinAlindi = true;
    SesServisi.paraGirdi();
    notifyListeners();
  }

  void krediAl(int toplam, int taksitSayisi) {
    krediTaksitMiktar = toplam ~/ taksitSayisi;
    krediKalanTaksit = taksitSayisi;
    para += toplam;
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
      SesServisi.paraGirdi();
    }
    mesaj = '$gun. gün başlıyor!';
    notifyListeners();
    return (kira, krediKesinti, para < 0);
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

  @override
  void initState() {
    super.initState();
    _state = widget.yuklenenState ?? GameState();
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnim = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() { _slideController.dispose(); super.dispose(); }

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

  void _gunBitiKontrol() {
    if (_state.gunBitmeli && !_gunBitiPopupGosterildi) {
      _gunBitiPopupGosterildi = true;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _gunSonuPopupGoster();
      });
    }
    if (_state.oyunBitti) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _gameOverPopup('Para bitti ve envanter boş!\n\n${_state.gun}. günde iflas ettin.', _state.gun);
      });
    }
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
            Text('Kasa: $paraOncesi₺', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('🏠 Kira: ', style: TextStyle(color: Colors.white54, fontSize: 14)),
              Text('-$kira₺', style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            if (krediKesinti > 0) ...[
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('🏦 Kredi taksiti: ', style: TextStyle(color: Colors.white54, fontSize: 14)),
                Text('-$krediKesinti₺', style: const TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 4),
              Text('(${_state.krediKalanTaksit - 1} taksit kaldı)',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
            const SizedBox(height: 8),
            const Divider(color: Color(0xFFFFD700), height: 1),
            const SizedBox(height: 8),
            Text('Kalan: ${paraOncesi - toplamKesinti}₺',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: (paraOncesi - toplamKesinti) < 0 ? Colors.redAccent : const Color(0xFF00FF88),
                fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [Center(child: ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            final (_, _, gameOver) = _state.gunuBitir();
            setState(() => _gunBitiPopupGosterildi = false);
            if (gameOver) {
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) _gameOverPopup('Kira ödenemedi!\n\n${_state.gun - 1}. günde iflas ettin.', _state.gun - 1);
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
              Text('$fiyat₺', style: const TextStyle(fontSize: 11, color: Color(0xFFf78166), fontWeight: FontWeight.bold)),
          ],
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
                  const Text('2000₺', style: TextStyle(color: Color(0xFFf78166), fontSize: 18, fontWeight: FontWeight.bold)),
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
                    disabledBackgroundColor: Colors.grey.withValues(alpha: 0.25),
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
                              ? 'Aktif kredi: ${_state.krediTaksitMiktar}₺ × ${_state.krediKalanTaksit} taksit kaldı'
                              : 'İhtiyaç kredisi başvurusu yap',
                          renk: const Color(0xFF3fb950),
                          onTap: () { Navigator.pop(ctx); _bankaKrediPopup(); },
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
            'Hâlâ aktif bir krediniz var.\n\n${_state.krediTaksitMiktar}₺ × ${_state.krediKalanTaksit} taksit kaldı.\n\nKrediniz bitince yeni başvuru yapabilirsiniz.',
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

    final rng = Random();
    final y = 3 + rng.nextInt(6); // 3–8
    final minMult = (1000 / y).ceil();
    final maxMult = (3000 / y).floor();
    final mult = minMult + rng.nextInt(maxMult - minMult + 1);
    final x = mult * y;
    final taksitMiktar = x ~/ y;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1008),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF3fb950), width: 1.5)),
        title: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('🏦 ', style: TextStyle(fontSize: 22)),
          Text('Banka Kredisi', style: TextStyle(color: Color(0xFF3fb950), fontSize: 19, fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF161b22),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF3fb950).withValues(alpha: 0.3)),
              ),
              child: Column(children: [
                Text('$x₺', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF3fb950))),
                const SizedBox(height: 4),
                const Text('Kredi Tutarı', style: TextStyle(fontSize: 12, color: Colors.white38)),
              ]),
            ),
            const SizedBox(height: 14),
            Text(
              'Banka şu anda sana $x₺ kredi vermeyi uygun buluyor.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Taksit sayısı:', style: TextStyle(color: Colors.white54, fontSize: 13)),
                Text('$y gün', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 14)),
              ]),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Günlük kesinti:', style: TextStyle(color: Colors.white54, fontSize: 13)),
                Text('-$taksitMiktar₺/gün', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
              ]),
            ),
            const SizedBox(height: 12),
            const Text('Onaylıyor musun?', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
        actions: [
          Row(children: [
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3a2000), foregroundColor: Colors.white),
              child: const Text('Hayır', style: TextStyle(fontWeight: FontWeight.bold)),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _state.krediAl(x, y);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3fb950), foregroundColor: Colors.black),
              child: const Text('Evet', style: TextStyle(fontWeight: FontWeight.bold)),
            )),
          ]),
        ],
      ),
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
              return GestureDetector(
                onTap: () {
                  _state.dukkanDegistir(d);
                  Navigator.pop(ctx);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: aktif ? const Color(0xFFFFD700).withValues(alpha: 0.15) : const Color(0xFF2a1a0a),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: aktif ? const Color(0xFFFFD700) : Colors.white24,
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
                        ['🏚️','🏠','🏪','🏬','🏢'][i],
                        style: const TextStyle(fontSize: 24),
                      )),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d.isim, style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold,
                        color: aktif ? const Color(0xFFFFD700) : Colors.white)),
                      const SizedBox(height: 3),
                      Row(children: [
                        const Text('Büyüklük: ', style: TextStyle(fontSize: 11, color: Colors.white38)),
                        Text(d.yildizlar, style: const TextStyle(fontSize: 12, color: Color(0xFFFFD700))),
                      ]),
                      const SizedBox(height: 2),
                      Row(children: [
                        const Text('Kira: ', style: TextStyle(fontSize: 11, color: Colors.white38)),
                        Text('${d.kira}₺/gün', style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 2),
                      Row(children: [
                        const Text('Müşteri: ', style: TextStyle(fontSize: 11, color: Colors.white38)),
                        Text('${10 + (d.seviye - 1) * 5}-${15 + (d.seviye - 1) * 5}/gün',
                          style: const TextStyle(fontSize: 11, color: Colors.white60)),
                      ]),
                    ])),
                    if (aktif) const Icon(Icons.check_circle, color: Color(0xFFFFD700), size: 20),
                  ]),
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
              Positioned.fill(child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: _state.imacSatinAlindi ? 1.0 : 0.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                builder: (_, t, __) {
                  final musteri = _state.musteriGorunuyor || _state.ozelMusteriGorunuyor;
                  final align = Alignment.lerp(Alignment.center, const Alignment(0.3, 0), t)!;
                  return Stack(children: [
                    // No-customer layer'lar — müşteri gelince AnimatedOpacity ile çıkar
                    AnimatedOpacity(
                      opacity: musteri ? 0.0 : (1.0 - t).clamp(0.0, 1.0),
                      duration: const Duration(milliseconds: 150),
                      child: Image.asset('assets/dukkan_bg_birivar.png',
                        fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                        alignment: align)),
                    AnimatedOpacity(
                      opacity: musteri ? 0.0 : t.clamp(0.0, 1.0),
                      duration: const Duration(milliseconds: 150),
                      child: Image.asset('assets/dukkan_bg_yenibilg_birivar.png',
                        fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                        alignment: align)),
                    // Customer layer'lar — müşteri gelince AnimatedOpacity ile girer
                    AnimatedOpacity(
                      opacity: musteri ? (1.0 - t).clamp(0.0, 1.0) : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: Image.asset('assets/dukkan_bg.png',
                        fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                        alignment: align)),
                    AnimatedOpacity(
                      opacity: musteri ? t.clamp(0.0, 1.0) : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: Image.asset('assets/dukkan_bg_yenibilg.png',
                        fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                        alignment: align)),
                  ]);
                },
              )),
              SafeArea(child: Column(children: [_buildHeader(), Expanded(child: _buildSahne()), _buildAltBar()])),
              // Dükkan kiralama butonu — ana Stack'te sabit
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
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            const Text('🕹️', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('OYUNCU DÜKKANI', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFFFD700), letterSpacing: 1.2)),
              Text('${_state.gun}. Gün • ${_state.gunlukMusteriSayisi}/${_state.gunlukMusteriLimiti} Müşteri', style: const TextStyle(fontSize: 10, color: Colors.white70)),
            ]),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFD700), width: 1),
            ),
            child: Text('💰 ${_state.para}₺', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFFD700))),
          ),
        ],
      ),
    );
  }

  Widget _buildSahne() {
    return Stack(
      children: [

        // Müşteri
        if (_state.aktifMusteri != null || _state.aktifOzelMusteri != null)
          AnimatedBuilder(
            animation: _slideAnim,
            builder: (context, child) {
              final screenW = MediaQuery.of(context).size.width;
              final screenH = MediaQuery.of(context).size.height;
              final hedef = (screenW - 171) / 2;
              final dx = hedef + (screenW - hedef) * _slideAnim.value;
              return Positioned(left: dx, top: screenH * 0.13 + 9, child: child!);
            },
            child: _state.aktifOzelMusteri != null
              ? _buildOzelMusteriWidget(_state.aktifOzelMusteri!)
              : Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 171, height: 171, color: Colors.transparent,
                      child: Image.asset(_state.aktifMusteri!.gorsel, width: 171, height: 171, fit: BoxFit.contain, isAntiAlias: true, filterQuality: FilterQuality.high),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
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
                  ],
                ),

                if (_state.aktifMusteri!.musteriSatiyor)
                  Positioned(
                    right: -94,
                    bottom: _state.aktifMusteri!.item.category == ItemCategory.cd ? -50 : -93,
                    child: Image.asset(_state.aktifMusteri!.item.gorsel, width: 144, height: 144, fit: BoxFit.contain),
                  ),
              ],
            ),
          ),
        // Mesaj kutusu
        Positioned(
          top: 12, left: 12, right: 12,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _state.aktifOzelMusteri != null
                ? ((_state.aktifOzelMusteri!.tip == OzelMusteriTip.hirsiz) ? Colors.redAccent : (_state.aktifOzelMusteri!.tip == OzelMusteriTip.polis) ? Colors.blueAccent : Colors.orangeAccent).withValues(alpha: 0.7)
                : const Color(0xFFFFD700).withValues(alpha: 0.4)),
            ),
            child: TypewriterText(
              text: _state.mesaj,
              style: TextStyle(fontSize: 12,
                color: _state.aktifOzelMusteri != null
                  ? ((_state.aktifOzelMusteri!.tip == OzelMusteriTip.hirsiz) ? Colors.redAccent : (_state.aktifOzelMusteri!.tip == OzelMusteriTip.polis) ? Colors.blueAccent : Colors.orangeAccent)
                  : const Color(0xFFFFD700)),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOzelMusteriWidget(OzelMusteri om) {
    Color renk;
    switch (om.tip) {
      case OzelMusteriTip.hirsiz: renk = Colors.redAccent; break;
      case OzelMusteriTip.polis: renk = Colors.blueAccent; break;
      case OzelMusteriTip.vergici: renk = Colors.orangeAccent; break;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 171, height: 171, color: Colors.transparent,
          child: Image.asset(om.gorsel, width: 171, height: 171, fit: BoxFit.contain, isAntiAlias: true, filterQuality: FilterQuality.high),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: renk.withValues(alpha: 0.8)),
          ),
          child: Text(om.ad, style: TextStyle(fontSize: 12, color: renk, fontWeight: FontWeight.bold)),
        ),
      ],
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

  Widget _buildAltBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      color: Colors.black.withValues(alpha: 0.55),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_state.musteriKabulBekliyor) ...[
            Row(children: [
              Expanded(child: ElevatedButton(
                onPressed: _musteriEvet,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00AA55), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('✅ EVET', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: _musteriHayir,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFAA0000), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('❌ HAYIR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              )),
            ]),
            const SizedBox(height: 8),
          ],
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: (_state.musteriKabulBekliyor || _state.aktifPazarlik != null || _state.gunBitmeli) ? null : _musteriCagir,
              icon: const Text('🚪', style: TextStyle(fontSize: 20)),
              label: const Text('Müşteri Çağır', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00AA55), foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.withValues(alpha: 0.35),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton.icon(
              onPressed: () => setState(() => _envanterAcik = true),
              icon: const Text('📦', style: TextStyle(fontSize: 20)),
              label: const Text('Envanter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5533AA), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )),
          ]),
        ],
      ),
    );
  }

  Widget _buildEnvanterOverlay() {
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
                    itemCount: 25,
                    itemBuilder: (context, i) => _buildSlotKart(i),
                  ),
                ),
              ]),
            ),
          ),
        ),
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

    // Dolu slot
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF2a1a0a).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: Image.asset(item.gorsel, fit: BoxFit.contain)),
          const SizedBox(height: 2),
          Text(item.name, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.white70), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('${item.basePrice}₺', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF00FF88))),
          Text(item.kondisyonYildiz, style: const TextStyle(fontSize: 8, color: Color(0xFFFFD700), letterSpacing: 0.5)),
        ],
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
  }

  void _pazarlikGoster() {
    final m = _state.aktifMusteri!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PazarlikDialog(state: _state, musteri: m),
    ).then((_) {
      _slideController.reverse().then((_) { if (mounted) _state.musteriAnimasyonBitti(); });
    });
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
        ? '"${widget.musteri.item.name}" için ${p.musteriTeklif}₺ istiyorum.'
        : '"${widget.musteri.item.name}" için ${p.musteriTeklif}₺ vereyim.';
  }

  @override
  void dispose() { _teklifController.dispose(); super.dispose(); }

  void _teklifGonder() {
    final teklif = int.tryParse(_teklifController.text);
    if (teklif == null || teklif <= 0) return;
    final p = widget.state.aktifPazarlik!;
    widget.state.teklifVer(teklif);
    setState(() {
      if (p.durum == PazarlikDurum.anlasildi) {
        _dialogMesaj = '🤝 Anlaştık!';
        _bitti = true;
        Future.delayed(const Duration(milliseconds: 800), () { if (mounted) Navigator.of(context).pop(); });
      } else if (p.durum == PazarlikDurum.gitti) {
        _dialogMesaj = p.mesaj;
        _bitti = true;
        Future.delayed(const Duration(milliseconds: 1400), () { if (mounted) Navigator.of(context).pop(); });
      } else {
        _dialogMesaj = p.mesaj;
      }
    });
  }

  Widget _buildMesajWidget(String mesaj, bool anlasildi, bool gitti) {
    final color = anlasildi ? Colors.greenAccent : gitti ? Colors.redAccent : Colors.white70;
    final regex = RegExp(r'([0-9]+₺)');
    final spans = <TextSpan>[];
    int last = 0;
    for (final match in regex.allMatches(mesaj)) {
      if (match.start > last) spans.add(TextSpan(text: mesaj.substring(last, match.start), style: TextStyle(color: color, fontStyle: FontStyle.italic, fontSize: 13)));
      spans.add(TextSpan(text: match.group(0), style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 16)));
      last = match.end;
    }
    if (last < mesaj.length) spans.add(TextSpan(text: mesaj.substring(last), style: TextStyle(color: color, fontStyle: FontStyle.italic, fontSize: 13)));
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
      title: Row(children: [
        Image.asset(m.gorsel, width: 52, height: 52, fit: BoxFit.contain),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m.name, style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
          Text(m.musteriSatiyor ? '💼 Satmak istiyor' : '🛒 Almak istiyor', style: const TextStyle(fontSize: 14, color: Colors.white54)),
        ])),
      ]),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Image.asset(m.item.gorsel, width: 80, height: 80, fit: BoxFit.contain),
                  const SizedBox(width: 4),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.item.name, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Piyasa: ${m.item.basePrice}₺', style: const TextStyle(fontSize: 14, color: Colors.white60, fontWeight: FontWeight.w600)),
                    if (!m.musteriSatiyor && m.item.maliyet != null) ...[
                      const SizedBox(height: 2),
                      Text('Maliyet: ${m.item.maliyet}₺', style: const TextStyle(fontSize: 12, color: Colors.orangeAccent)),
                    ],
                    const SizedBox(height: 2),
                    Row(children: [
                      const Text('Kondisyon: ', style: TextStyle(fontSize: 11, color: Colors.white38)),
                      Text(m.item.kondisyonYildiz, style: const TextStyle(fontSize: 11, color: Color(0xFFFFD700))),
                    ]),
                  ])),
                ]),
              ),
              const SizedBox(height: 12),
              if (_dialogMesaj.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: anlasildi ? Colors.green.withValues(alpha: 0.15) : gitti ? Colors.red.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: anlasildi ? Colors.green.withValues(alpha: 0.5) : gitti ? Colors.red.withValues(alpha: 0.5) : Colors.white12),
                  ),
                  child: _buildMesajWidget(_dialogMesaj, anlasildi, gitti),
                ),
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
            ],
          ),
        ),
      ),
      actions: _bitti ? [] : [
        ElevatedButton(
          onPressed: () { Navigator.of(context).pop(); widget.state.musteriReddet(); },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFAA0000), foregroundColor: Colors.white),
          child: const Text('Vazgeç', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          onPressed: _teklifGonder,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black),
          child: Text(m.musteriSatiyor ? 'Teklif Ver' : 'Fiyat Ver', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
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