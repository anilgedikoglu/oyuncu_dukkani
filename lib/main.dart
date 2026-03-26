import 'dart:math';
import 'package:flutter/material.dart';

void main() {
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
                Center(child: _menuButon('Yeni Oyun', () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const GameScreen(yeniOyun: true))))),
                const SizedBox(height: 12),
                Center(child: _menuButon('Devam Et', () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const GameScreen(yeniOyun: false))))),
                const SizedBox(height: 12),
                Center(child: _menuButon('Ayarlar', () => setState(() => _ayarlarAcik = true))),
                const Spacer(flex: 1),
              ],
            ),
          ),
          if (_ayarlarAcik) _buildAyarlarOverlay(),
        ],
      ),
    );
  }

  Widget _menuButon(String label, VoidCallback onTap) {
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
                  onTap: () => setState(() => _sesAcik = !_sesAcik),
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
    return MusteriOzellik(sabir: 1 + rng.nextInt(5), titizlik: 1 + rng.nextInt(5), zeka: 1 + rng.nextInt(5));
  }

  int get maxTur {
    final rng = Random();
    switch (sabir) {
      case 1: return 2;
      case 2: return 3 + rng.nextInt(2);
      case 3: return 4 + rng.nextInt(2);
      case 4: return 6 + rng.nextInt(2);
      case 5: return 8 + rng.nextInt(2);
      default: return 4;
    }
  }

  double acilisTeklifCarpani(int kondisyon, bool musteriSatiyor) {
    if (musteriSatiyor) return 1.2 + Random().nextDouble() * 0.3;
    final kondisyonCarpan = (kondisyon - 1) / 4.0;
    final titizlikCarpan = (titizlik - 1) / 4.0;
    final etki = titizlikCarpan * (1 - kondisyonCarpan);
    final minCarpan = 0.40 + (1 - etki) * 0.45;
    return minCarpan + Random().nextDouble() * 0.15;
  }

  double ilkTurGitmeProbabilite() {
    if (zeka == 1) return 0.25;
    if (zeka == 2) return 0.10;
    return 0.0;
  }

  double erkenGitmeProbabilite(double farkOrani) {
    if (zeka == 1) return 0.15 + farkOrani * 0.6;
    if (zeka == 2) return 0.05 + farkOrani * 0.4;
    if (zeka >= 4) return farkOrani > 0.7 ? 0.5 : (farkOrani > 0.5 ? 0.2 : 0.0);
    return farkOrani > 0.7 ? 0.4 : (farkOrani > 0.5 ? 0.15 : 0.0);
  }
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
        const mesajlar = [
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
  int musteriTeklif;
  int oyuncuTeklif;
  int turSayisi;
  int maxTur;
  PazarlikDurum durum;
  String mesaj;

  PazarlikSeans({
    required this.musteriSatiyor,
    required this.piyasaFiyati,
    required this.musteriTeklif,
    required this.oyuncuTeklif,
    required this.maxTur,
    required this.ozellik,
  })  : turSayisi = 0,
        durum = PazarlikDurum.devamEdiyor,
        mesaj = '';

  PazarlikDurum oyuncuTeklifVer(int yeniOyuncuTeklif) {
    oyuncuTeklif = yeniOyuncuTeklif;
    turSayisi++;

    if (musteriSatiyor) {
      if (oyuncuTeklif >= musteriTeklif) { durum = PazarlikDurum.anlasildi; mesaj = 'Anlaştık! 🤝'; return durum; }
    } else {
      if (oyuncuTeklif <= musteriTeklif) { durum = PazarlikDurum.anlasildi; mesaj = 'Anlaştık! 🤝'; return durum; }
    }

    // ── YAKINLIK KABUL EĞRİSİ ───────────────────────────────────────────
    // Fark küçüldükçe kabul ihtimali artar — keskin eşik yok, sürekli eğri
    {
      final farkYuzde = (musteriTeklif - oyuncuTeklif).abs() / piyasaFiyati;
      // Sabır 1 → geniş alan ama düşük maks ihtimal (öngörülemez, kolay ikna)
      // Sabır 5 → dar alan ama yüksek maks ihtimal (ısrarcı, ama yaklaşınca kabul eder)
      // esik: farkın bu yüzdenin altında olduğunda ihtimal hesaplanmaya başlar
      final esikler    = [0.20, 0.16, 0.12, 0.08, 0.05]; // sabır 1→5
      final makslar    = [0.35, 0.40, 0.45, 0.55, 0.70]; // sabır 1→5
      final esik = esikler[(ozellik.sabir - 1).clamp(0, 4)];
      final maks = makslar[(ozellik.sabir - 1).clamp(0, 4)];

      if (farkYuzde < esik) {
        // Doğrusal eğri: fark 0'a yaklaştıkça ihtimal maks'a yaklaşır
        // Tur ilerlemesi ekstra %20 ekler
        final turBonus = (turSayisi / maxTur) * 0.20;
        final kabulIhtimali = ((esik - farkYuzde) / esik) * maks + turBonus;
        if (Random().nextDouble() < kabulIhtimali.clamp(0.0, 0.90)) {
          final _agirlik = 0.55 + Random().nextDouble() * 0.30; // 0.55..0.85 arası müşteri tarafına yakın
          musteriTeklif = (musteriTeklif * _agirlik + oyuncuTeklif * (1 - _agirlik)).round();
          durum = PazarlikDurum.anlasildi; mesaj = 'Anlaştık! 🤝'; return durum;
        }
      }
    }
    // ─────────────────────────────────────────────────────────────────────

    // Ani kabul şansı
    {
      final fark = (musteriTeklif - oyuncuTeklif).abs();
      final farkOrani = fark / piyasaFiyati;
      final turIlerlemesi = turSayisi / maxTur;
      final sabirTolerans = (ozellik.sabir - 1) / 4.0;
      final maksKabulEdilecekFark = 0.10 + sabirTolerans * 0.40;
      double aniKabulSans = farkOrani <= maksKabulEdilecekFark
          ? turIlerlemesi * (0.05 + sabirTolerans * 0.25)
          : turIlerlemesi * sabirTolerans * 0.04;
      aniKabulSans += 0.015;
      if (ozellik.sabir == 1) aniKabulSans *= 0.3;
      if (Random().nextDouble() < aniKabulSans) {
        final _agirlik = 0.55 + Random().nextDouble() * 0.30; // 0.55..0.85 arası müşteri tarafına yakın
          musteriTeklif = (musteriTeklif * _agirlik + oyuncuTeklif * (1 - _agirlik)).round();
        durum = PazarlikDurum.anlasildi;
        mesaj = 'Anlaştık! 🤝';
        return durum;
      }
    }

    if (turSayisi >= maxTur) {
      durum = PazarlikDurum.gitti;
      const turM = ['Yok ya seninle anlaşamıyoruz...','Olmadı, olduramadık...','Pazarlık benim için bitmiştir!...','Biz bu işi unutalım bence.','Ne sen Leyla\'sın ne de ben Mecnun.','Biz seninle ortayı bulamıyoruz.','Ben bu bahsi sürdürmeyeceğim!...','Bence biz boşverelim!...','Benden buraya kadar!...','Kimse yoğurdum ekşi demiyor!','Tekliflerimiz ikimize de makul gelmedi.','Başka işlerim var, gitmeliyim...','Güzel pazarlıktı ama olmadı.','Bir yere varamayacağız, kaçtım ben.'];
      mesaj = turM[Random().nextInt(turM.length)];
      return durum;
    }

    final fark = (musteriTeklif - oyuncuTeklif).abs();
    final farkOrani = fark / piyasaFiyati;

    if (turSayisi == 1 && Random().nextDouble() < ozellik.ilkTurGitmeProbabilite()) {
      durum = PazarlikDurum.gitti;
      const ilkM = ['Dandini dastana dinalar bostana...','Ben niye buradayım şu an ya?...','Burası berber değil miydi?...','Karnım acıktı, kaçtım ben.','Biri beni çağırıyor, ben gittim!...','Aaa evde ocağı açık unuttum!','Ben neredeyim, sen kimsin? Bye!','Estiler geldim, estiler kaçıyorum...','Aaa yanıma para almamışım!...','Burası kasap değil mi ya?...'];
      mesaj = ilkM[Random().nextInt(ilkM.length)];
      return durum;
    }

    if (turSayisi > 1) {
      final gitmeP = ozellik.erkenGitmeProbabilite(farkOrani);
      if (Random().nextDouble() < gitmeP) {
        durum = PazarlikDurum.gitti;
        if (ozellik.zeka <= 2) {
          const m2 = ['Dur ya, vazgeçtim!...','Dolandırılacağım sanırım, kaçıyorum!...','Şu teklifle anında vazgeçtim!','Beni aptal yerine koyamazsın!'];
          mesaj = m2[Random().nextInt(m2.length)];
        } else {
          const m3 = ['Sen şaşırmışsın, konuşmasak daha iyi!','Senin piyasadan hiç mi haberin yok!','Şu teklifle anında vazgeçtim!','Yok artık Lebron James!','Oldu paşam, Malkara Keşan!','Söylediğini kulağın duymuyor bence!','Sen tok satıcısın, anlaşıldı!...','Dolandırılacağım sanırım, kaçıyorum!...','Sen başkalarını kandır dostum!','Beni aptal yerine koyamazsın!'];
          mesaj = m3[Random().nextInt(m3.length)];
        }
        return durum;
      }
    }

    _musteriKarsiTeklif(farkOrani);
    durum = PazarlikDurum.devamEdiyor;
    return durum;
  }

  void _musteriKarsiTeklif(double farkOrani) {
    final rng = Random();
    if (ozellik.zeka == 1 && rng.nextDouble() < 0.3) {
      if (musteriSatiyor) {
        musteriTeklif = (piyasaFiyati * (0.5 + rng.nextDouble() * 1.0)).round();
        mesaj = ['Buna karşılık 5 çeyrek altın isterim. ${musteriTeklif}₺de olur.','Yolda buldum, satmaya getirdim. ${musteriTeklif}₺ olur sana.'][rng.nextInt(2)];
      } else {
        musteriTeklif = (piyasaFiyati * (0.3 + rng.nextDouble() * 1.5)).round();
        mesaj = ['Bana bunu hayrına bedava versen? Neyse, ${musteriTeklif}₺ olur mu?','Çok param yok ha. ${musteriTeklif}₺ yeter mi?','Bütçem kısıtlı, ürünün de kıytırık. ${musteriTeklif}₺ yapalım gitsin.','Ben sayıları pek bilmem. ${musteriTeklif}₺ gibi bişe okey mi?'][rng.nextInt(4)];
      }
      return;
    }

    if (musteriSatiyor) {
      double indirimOrani = farkOrani > 0.4 ? 0.02 + rng.nextDouble() * 0.04 : farkOrani > 0.2 ? 0.05 + rng.nextDouble() * 0.07 : 0.08 + rng.nextDouble() * 0.10;
      final yeniTeklif = musteriTeklif - (piyasaFiyati * indirimOrani).round();
      // Oyuncunun teklifinin üstüne çıkamaz (o zaman zaten anlaşılırdı)
      musteriTeklif = yeniTeklif.clamp((piyasaFiyati * 0.80).round(), oyuncuTeklif - 1);
      mesaj = 'En fazla $musteriTeklif₺ yapabilirim.';
    } else {
      double artisOrani = farkOrani > 0.4 ? 0.02 + rng.nextDouble() * 0.04 : farkOrani > 0.2 ? 0.05 + rng.nextDouble() * 0.07 : 0.08 + rng.nextDouble() * 0.10;
      final yeniTeklif = musteriTeklif + (piyasaFiyati * artisOrani).round();
      // Oyuncunun teklifinin altına inemez (o zaman zaten anlaşılırdı)
      musteriTeklif = yeniTeklif.clamp(oyuncuTeklif + 1, (piyasaFiyati * 1.20).round());
      mesaj = 'O zaman $musteriTeklif₺ vereyim.';
    }
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

  GameItem({required this.id, required this.name, required this.gorsel, required this.category, required this.basePrice, required this.kondisyon});

  String get kondisyonYildiz => '★' * kondisyon + '☆' * (5 - kondisyon);

  GameItem kopya() => GameItem(id: id, name: name, gorsel: gorsel, category: category, basePrice: basePrice, kondisyon: kondisyon);
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
    GameItem(id: 'cd1', name: 'KARMAGEDDON', gorsel: 'assets/CD_1.png', category: ItemCategory.cd, basePrice: 80,  kondisyon: 4),
    GameItem(id: 'cd2', name: 'CİMRİCİTY',   gorsel: 'assets/CD_2.png', category: ItemCategory.cd, basePrice: 120, kondisyon: 3),
    GameItem(id: 'cd3', name: 'SOKAKSOCCER', gorsel: 'assets/CD_3.png', category: ItemCategory.cd, basePrice: 90,  kondisyon: 5),
    GameItem(id: 'cd4', name: 'ZOOMDAY',     gorsel: 'assets/CD_4.png', category: ItemCategory.cd, basePrice: 150, kondisyon: 2),
    GameItem(id: 'cd5', name: 'GTR 7',       gorsel: 'assets/CD_5.png', category: ItemCategory.cd, basePrice: 200, kondisyon: 5),
    GameItem(id: 'cd6', name: 'BOKUS 4D',    gorsel: 'assets/CD_6.png', category: ItemCategory.cd, basePrice: 250, kondisyon: 1),
  ];

  // 25 slot: index 0-24. Slot bazlı envanter.
  final List<GameItem?> slotlar = List.generate(25, (i) {
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

  final List<Map<String, String>> musteriHavuzu = [
    {'gorsel': 'assets/musteri_1.png', 'isim': 'Uras'},
    {'gorsel': 'assets/musteri_2.png', 'isim': 'Hande'},
    {'gorsel': 'assets/musteri_3.png', 'isim': 'Yavuz'},
    {'gorsel': 'assets/musteri_4.png', 'isim': 'Ayşe'},
    {'gorsel': 'assets/musteri_5.png', 'isim': 'Derin'},
    {'gorsel': 'assets/musteri_6.png', 'isim': 'Osman'},
    {'gorsel': 'assets/musteri_7.png', 'isim': 'Lale'},
    {'gorsel': 'assets/musteri_8.png', 'isim': 'Defne'},
  ];
  List<int> _musteriSira = [];

  GameState() {
    gunlukMusteriLimiti = aktifDukkan.gunlukMusteriSayisiUret();
    _ozelTipSirasi.shuffle(Random());
    _ozelMusteriSayaciniAyarla();
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
    final isim = secilen['isim']!;
    final gorsel = secilen['gorsel']!;
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

    final carpan = ozellik.acilisTeklifCarpani(secilenUrun.kondisyon, musteriSatiyor);
    final ilkTeklif = (secilenUrun.basePrice * carpan).round();

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
    final oyuncuIlkTeklif = m.musteriSatiyor ? (m.item.basePrice * 0.65).round() : (m.item.basePrice * 1.3).round();
    aktifPazarlik = PazarlikSeans(
      musteriSatiyor: m.musteriSatiyor,
      piyasaFiyati: m.item.basePrice,
      musteriTeklif: m.ilkTeklif,
      oyuncuTeklif: oyuncuIlkTeklif,
      maxTur: m.ozellik.maxTur,
      ozellik: m.ozellik,
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
        if (!urunEkle(m.item)) { mesaj = 'Envanter dolu!'; _musteriGonder(); return; }
        para -= anlasilanFiyat;
        mesaj = '${m.name}\'den "${m.item.name}" $anlasilanFiyat₺\'ye alındı! 📦';
      } else {
        mesaj = 'Yeterli paran yok! 💸';
        _musteriGonder();
        return;
      }
    } else {
        urunCikar(m.item.id);
      para += anlasilanFiyat;
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

  /// Günü bitir — kira düş, sonucu döndür
  /// Dönen int: yeni para miktarı (kira sonrası)
  /// Dönen bool: kira sonrası para < 0 ise true (game over)
  (int kiraMiktari, bool gameOver) gunuBitir() {
    final kira = aktifDukkan.kira;
    gun++;
    gunlukMusteriSayisi = 0;
    gunlukMusteriLimiti = aktifDukkan.gunlukMusteriSayisiUret();
    para -= kira;
    mesaj = '$gun. gün başlıyor!';
    notifyListeners();
    return (kira, para < 0);
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
  const GameScreen({super.key, required this.yeniOyun});
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
    _state = GameState();
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnim = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() { _slideController.dispose(); super.dispose(); }

  void _musteriCagir() {
    _state.yeniMusteriGonder();
    if (_state.musteriGorunuyor || _state.ozelMusteriGorunuyor) _slideController.forward(from: 0);
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
        _gameOverPopup('Para bitti ve envanter boş!\n\n${_state.gun}. günde iflas ettin.');
      });
    }
  }

  void _gunSonuPopupGoster() {
    final eskiGun = _state.gun;
    final kira = _state.aktifDukkan.kira;
    final paraOncesi = _state.para;

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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🏠 Kira: ', style: TextStyle(color: Colors.white54, fontSize: 14)),
                Text('-$kira₺', style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(color: Color(0xFFFFD700), height: 1),
            const SizedBox(height: 8),
            Text('Kalan: ${paraOncesi - kira}₺',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: (paraOncesi - kira) < 0 ? Colors.redAccent : const Color(0xFF00FF88),
                fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [Center(child: ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            final (_, gameOver) = _state.gunuBitir();
            setState(() => _gunBitiPopupGosterildi = false);
            if (gameOver) {
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) _gameOverPopup('Kira ödenemedi!\n\n${_state.gun - 1}. günde iflas ettin.');
              });
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black),
          child: const Text('Yeni Güne Başla', style: TextStyle(fontWeight: FontWeight.bold)),
        ))],
      ),
    );
  }

  void _gameOverPopup(String mesaj) {
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
              Positioned.fill(child: Image.asset('assets/dukkan_bg.jpeg', fit: BoxFit.cover)),
              SafeArea(child: Column(children: [_buildHeader(), Expanded(child: _buildSahne()), _buildAltBar()])),
              // Dükkan kiralama butonu — ana Stack'te sabit
              Positioned(
                left: 16,
                bottom: 300,
                child: GestureDetector(
                  onTap: _dukkanKiralaPopup,
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
              final hedef = (screenW - 180) / 2;
              final dx = hedef + (screenW - hedef) * _slideAnim.value;
              return Positioned(left: dx, top: screenH * 0.13, child: child!);
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
                      width: 180, height: 180, color: Colors.transparent,
                      child: Image.asset(_state.aktifMusteri!.gorsel, width: 180, height: 180, fit: BoxFit.contain, isAntiAlias: true, filterQuality: FilterQuality.high),
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
                    right: -65, bottom: -50,
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
            child: Text(_state.mesaj, style: TextStyle(fontSize: 12,
              color: _state.aktifOzelMusteri != null
                ? ((_state.aktifOzelMusteri!.tip == OzelMusteriTip.hirsiz) ? Colors.redAccent : (_state.aktifOzelMusteri!.tip == OzelMusteriTip.polis) ? Colors.blueAccent : Colors.orangeAccent)
                : const Color(0xFFFFD700)),
              textAlign: TextAlign.center),
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
          width: 180, height: 180, color: Colors.transparent,
          child: Image.asset(om.gorsel, width: 180, height: 180, fit: BoxFit.contain, isAntiAlias: true, filterQuality: FilterQuality.high),
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
      _state.mesaj = mesaj;
      _state.notifyListeners();
      _ozelMusteriGonder();
      return;
    }

    if (om.tip == OzelMusteriTip.polis) {
      kesinti = om.ilkMiktar;
      _state.para -= kesinti;
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
      if (kesinti > 0) _state.para -= kesinti;
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
      if (kesinti > 0) _state.para -= kesinti;
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
              if (p != null && !_bitti)
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