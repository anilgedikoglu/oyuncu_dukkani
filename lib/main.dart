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
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1a1008),
      ),
      home: const AnaMenuEkrani(),
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

  void _yeniOyun(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const GameScreen(yeniOyun: true)),
    );
  }

  void _devamEt(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const GameScreen(yeniOyun: false)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/anamenu.png', fit: BoxFit.cover),
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Spacer(flex: 3),
                  _menuButon('Yeni Oyun', () => _yeniOyun(context)),
                  const SizedBox(height: 12),
                  _menuButon('Devam Et', () => _devamEt(context)),
                  const SizedBox(height: 12),
                  _menuButon('Ayarlar', () => setState(() => _ayarlarAcik = true)),
                  const Spacer(flex: 1),
                ],
              ),
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
        child: Text(label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold,
            color: Color(0xFF3a2000),
            fontFamily: 'monospace',
            letterSpacing: 1,
          )),
      ),
    );
  }

  Widget _buildAyarlarOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _ayarlarAcik = false),
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF5E6C8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF8B5E3C), width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⚙️ AYARLAR', style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold,
                    color: Color(0xFF3a2000), letterSpacing: 1)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('🔊 Ses:', style: TextStyle(
                        fontSize: 16, color: Color(0xFF3a2000), fontWeight: FontWeight.bold)),
                      GestureDetector(
                        onTap: () => setState(() => _sesAcik = !_sesAcik),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _sesAcik ? const Color(0xFF228B22) : const Color(0xFF8B0000),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_sesAcik ? 'AÇIK' : 'KAPALI',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () => setState(() => _ayarlarAcik = false),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5E3C),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Kapat', textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── PAZARLIK MODELİ ─────────────────────────────────────────────────────────

enum PazarlikDurum { devamEdiyor, anlasildi, gitti }

class PazarlikSeans {
  final bool musteriSatiyor;
  final int piyasaFiyati;
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
  })  : turSayisi = 0,
        durum = PazarlikDurum.devamEdiyor,
        mesaj = '';

  PazarlikDurum oyuncuTeklifVer(int yeniOyuncuTeklif) {
    oyuncuTeklif = yeniOyuncuTeklif;
    turSayisi++;

    if (musteriSatiyor) {
      if (oyuncuTeklif >= musteriTeklif) {
        durum = PazarlikDurum.anlasildi;
        mesaj = 'Anlaştık! 🤝';
        return durum;
      }
    } else {
      if (oyuncuTeklif <= musteriTeklif) {
        durum = PazarlikDurum.anlasildi;
        mesaj = 'Anlaştık! 🤝';
        return durum;
      }
    }

    if (turSayisi >= maxTur) {
      durum = PazarlikDurum.gitti;
      mesaj = 'Anlaşamadık, bir dahaki sefere...';
      return durum;
    }

    final fark = (musteriTeklif - oyuncuTeklif).abs();
    final farkOrani = fark / piyasaFiyati;

    if (turSayisi > 1 && farkOrani > 0.5) {
      final gitmeIhtimali = farkOrani > 0.7 ? 0.5 : 0.2;
      if (Random().nextDouble() < gitmeIhtimali) {
        durum = PazarlikDurum.gitti;
        mesaj = 'Bu fiyata olmaz! diyerek çıktı. 😤';
        return durum;
      }
    }

    _musteriKarsiTeklif(farkOrani);
    durum = PazarlikDurum.devamEdiyor;
    return durum;
  }

  void _musteriKarsiTeklif(double farkOrani) {
    final rng = Random();
    if (musteriSatiyor) {
      double indirimOrani;
      if (farkOrani > 0.4) {
        indirimOrani = 0.02 + rng.nextDouble() * 0.04;
      } else if (farkOrani > 0.2) {
        indirimOrani = 0.05 + rng.nextDouble() * 0.07;
      } else {
        indirimOrani = 0.08 + rng.nextDouble() * 0.10;
      }
      final indirim = (piyasaFiyati * indirimOrani).round();
      musteriTeklif = (musteriTeklif - indirim).clamp((piyasaFiyati * 0.80).round(), musteriTeklif - 1);
      mesaj = 'En fazla $musteriTeklif₺ yapabilirim.';
    } else {
      double artisOrani;
      if (farkOrani > 0.4) {
        artisOrani = 0.02 + rng.nextDouble() * 0.04;
      } else if (farkOrani > 0.2) {
        artisOrani = 0.05 + rng.nextDouble() * 0.07;
      } else {
        artisOrani = 0.08 + rng.nextDouble() * 0.10;
      }
      final artis = (piyasaFiyati * artisOrani).round();
      musteriTeklif = (musteriTeklif + artis).clamp(musteriTeklif + 1, (piyasaFiyati * 1.20).round());
      mesaj = 'O zaman $musteriTeklif₺ vereyim.';
    }
  }

  static int maxTurHesapla(int oyuncuIlkTeklif, int musteriIlkTeklif, int piyasa) {
    final fark = (oyuncuIlkTeklif - musteriIlkTeklif).abs() / piyasa;
    if (fark > 0.6) return 3 + Random().nextInt(2);
    if (fark > 0.3) return 4 + Random().nextInt(2);
    return 5 + Random().nextInt(2);
  }
}

// ─── VERİ MODELLERİ ──────────────────────────────────────────────────────────

enum ItemCategory { cd, konsol, aksesuar }

class GameItem {
  final String id;
  final String name;
  final String emoji;
  final ItemCategory category;
  final int basePrice;
  int stock;

  GameItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.basePrice,
    this.stock = 0,
  });
}

class Customer {
  final String name;
  final String gorsel;
  final bool musteriSatiyor;
  final GameItem item;
  final int ilkTeklif;

  Customer({
    required this.name,
    required this.gorsel,
    required this.musteriSatiyor,
    required this.item,
    required this.ilkTeklif,
  });

  String get selamMesaji {
    if (musteriSatiyor) {
      return 'Merhaba, ben $name. Elimde ${item.name} var, satmak istiyorum. İlgilenir misin?';
    } else {
      return 'Selam! Ben $name. Elinde ${item.name} olduğunu duydum, bana satar mısın?';
    }
  }
}

// ─── OYUN DURUMU ─────────────────────────────────────────────────────────────

class GameState extends ChangeNotifier {
  int para = 500;
  int gun = 1;
  int musteriSayisi = 0;
  int gunlukMusteriSayisi = 0;
  int toplamTeklifSayisi = 0;
  String mesaj = 'Dükkan açıldı! İlk müşteri bekleniyor...';
  Customer? aktifMusteri;
  PazarlikSeans? aktifPazarlik;
  bool musteriGorunuyor = false;
  bool musteriKabulBekliyor = false;

  final List<GameItem> envanter = [
    GameItem(id: 'cd1', name: 'Klasik PC Oyunu', emoji: '💿', category: ItemCategory.cd, basePrice: 80, stock: 3),
    GameItem(id: 'cd2', name: 'Nadir Koleksiyon CD', emoji: '🎮', category: ItemCategory.cd, basePrice: 250, stock: 1),
    GameItem(id: 'kon1', name: 'Retro Konsol', emoji: '🕹️', category: ItemCategory.konsol, basePrice: 400, stock: 2),
    GameItem(id: 'kon2', name: 'El Konsolu', emoji: '👾', category: ItemCategory.konsol, basePrice: 300, stock: 0),
    GameItem(id: 'aks1', name: 'Joystick', emoji: '🎯', category: ItemCategory.aksesuar, basePrice: 120, stock: 4),
    GameItem(id: 'aks2', name: 'Retro Kılıf', emoji: '🧳', category: ItemCategory.aksesuar, basePrice: 60, stock: 2),
  ];

  final List<Map<String, String>> musteriHavuzu = [
    {'gorsel': 'assets/musteri_1.png', 'isim': 'Uras'},
    {'gorsel': 'assets/musteri_2.png', 'isim': 'Hande'},
    {'gorsel': 'assets/musteri_3.png', 'isim': 'Yavuz'},
    {'gorsel': 'assets/musteri_4.png', 'isim': 'Ayşe'},
  ];
  List<int> _musteriSira = [];

  bool get gunBitmeli => gunlukMusteriSayisi >= 15 || toplamTeklifSayisi > 100;
  bool get oyunBitti {
    final stokBos = envanter.every((e) => e.stock == 0);
    return para <= 0 && stokBos;
  }

  void yeniMusteriGonder() {
    final rng = Random();
    if (_musteriSira.isEmpty) {
      _musteriSira = List.generate(musteriHavuzu.length, (i) => i)..shuffle(rng);
    }
    final musteriIndex = _musteriSira.removeLast();
    final secilen = musteriHavuzu[musteriIndex];
    final isim = secilen['isim']!;
    final gorsel = secilen['gorsel']!;
    final musteriSatiyor = rng.nextBool();

    GameItem? secilenUrun;
    if (!musteriSatiyor) {
      final stokluUrunler = envanter.where((e) => e.stock > 0).toList();
      if (stokluUrunler.isEmpty) {
        mesaj = '$isim geldi ama stokta ürün yok!';
        notifyListeners();
        return;
      }
      secilenUrun = stokluUrunler[rng.nextInt(stokluUrunler.length)];
    } else {
      secilenUrun = envanter[rng.nextInt(envanter.length)];
    }

    final double carpan = musteriSatiyor
        ? 1.2 + rng.nextDouble() * 0.3
        : 0.6 + rng.nextDouble() * 0.2;
    final ilkTeklif = (secilenUrun.basePrice * carpan).round();

    aktifMusteri = Customer(
      name: isim,
      gorsel: gorsel,
      musteriSatiyor: musteriSatiyor,
      item: secilenUrun,
      ilkTeklif: ilkTeklif,
    );
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
    final oyuncuIlkTeklif = m.musteriSatiyor
        ? (m.item.basePrice * 0.65).round()
        : (m.item.basePrice * 1.3).round();
    final maxTur = PazarlikSeans.maxTurHesapla(oyuncuIlkTeklif, m.ilkTeklif, m.item.basePrice);
    aktifPazarlik = PazarlikSeans(
      musteriSatiyor: m.musteriSatiyor,
      piyasaFiyati: m.item.basePrice,
      musteriTeklif: m.ilkTeklif,
      oyuncuTeklif: oyuncuIlkTeklif,
      maxTur: maxTur,
    );
    notifyListeners();
  }

  void musteriReddetGirisSafhasinda() {
    if (aktifMusteri == null) return;
    mesaj = 'Bir dahaki sefere!...';
    musteriKabulBekliyor = false;
    notifyListeners();
    // Müşteri gidecek — ekranda yazı kalsın biraz
    Future.delayed(const Duration(milliseconds: 1200), () {
      _musteriGonder();
    });
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
        m.item.stock++;
        para -= anlasilanFiyat;
        mesaj = '${m.name}\'den "${m.item.name}" $anlasilanFiyat₺\'ye alındı! 📦';
      } else {
        mesaj = 'Yeterli paran yok! 💸';
        _musteriGonder();
        return;
      }
    } else {
      m.item.stock--;
      para += anlasilanFiyat;
      mesaj = '${m.name} "${m.item.name}" ürününü $anlasilanFiyat₺\'ye aldı! 💰';
    }
    _musteriGonder();
  }

  void musteriReddet() {
    if (aktifMusteri == null) return;
    mesaj = '${aktifMusteri!.name} anlaşamadık diyerek ayrıldı.';
    _musteriGonder();
  }

  void yeniGunBaslat() {
    gun++;
    gunlukMusteriSayisi = 0;
    mesaj = '$gun. gün başlıyor!';
    notifyListeners();
  }

  void _musteriGonder() {
    aktifMusteri = null;
    aktifPazarlik = null;
    musteriGorunuyor = false;
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
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _musteriCagir() {
    _state.yeniMusteriGonder();
    if (_state.musteriGorunuyor) {
      _slideController.forward(from: 0);
    }
  }

  void _musteriHayir() {
    _state.musteriReddetGirisSafhasinda();
    // Geri git animasyonu
    _slideController.reverse();
  }

  void _musteriEvet() {
    _state.musteriKabul();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _state.aktifMusteri != null) {
        _pazarlikGoster();
      }
    });
  }

  void _gunBitiKontrol() {
    if (_state.gunBitmeli && !_gunBitiPopupGosterildi) {
      _gunBitiPopupGosterildi = true;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1a1008),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFFFD700), width: 2),
            ),
            title: const Text('🌙 Gün Bitti!', textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFFFD700), fontSize: 20)),
            content: Text('${_state.gun + 1}. gün başlıyor!\n\nKasa: ${_state.para}₺',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
            actions: [
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _state.yeniGunBaslat();
                    setState(() => _gunBitiPopupGosterildi = false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Yeni Güne Başla', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      });
    }

    if (_state.oyunBitti) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1a1008),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.red, width: 2),
            ),
            title: const Text('💀 OYUN BİTTİ', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red, fontSize: 22)),
            content: Text('Para bitti ve envanter boş!\n\n${_state.gun}. günde iflas ettin.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15)),
            actions: [
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const AnaMenuEkrani()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Ana Menüye Dön', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      });
    }
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
              Positioned.fill(
                child: Image.asset('assets/dukkan_bg.jpeg', fit: BoxFit.cover),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(child: _buildSahne()),
                    _buildAltBar(),
                  ],
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
              const Text('OYUNCU DÜKKANI', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold,
                color: Color(0xFFFFD700), letterSpacing: 1.2)),
              Text('${_state.gun}. Gün • ${_state.gunlukMusteriSayisi}/15 Müşteri',
                style: const TextStyle(fontSize: 10, color: Colors.white70)),
            ]),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFD700), width: 1),
            ),
            child: Text('💰 ${_state.para}₺',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                color: Color(0xFFFFD700))),
          ),
        ],
      ),
    );
  }

  Widget _buildSahne() {
    return Stack(
      children: [
        // Müşteri animasyonu — sağdan sola
        if (_state.aktifMusteri != null)
          AnimatedBuilder(
            animation: _slideAnim,
            builder: (context, child) {
              final screenW = MediaQuery.of(context).size.width;
              final screenH = MediaQuery.of(context).size.height;
              // Başlangıç: ekran sağ dışı (screenW), bitiş: ortada (screenW*0.25)
              final hedef = screenW * 0.25;
              final dx = hedef + (screenW - hedef) * _slideAnim.value;
              return Positioned(
                left: dx,
                top: screenH * 0.13,
                child: child!,
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 180,
                  height: 180,
                  color: Colors.transparent,
                  child: Image.asset(
                    _state.aktifMusteri!.gorsel,
                    width: 180,
                    height: 180,
                    fit: BoxFit.contain,
                    isAntiAlias: true,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.6)),
                  ),
                  child: Text(_state.aktifMusteri!.name,
                    style: const TextStyle(fontSize: 12,
                      color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
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
              border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
            ),
            child: Text(_state.mesaj,
              style: const TextStyle(fontSize: 12, color: Color(0xFFFFD700)),
              textAlign: TextAlign.center),
          ),
        ),
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
          // EVET / HAYIR butonları
          if (_state.musteriKabulBekliyor) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _musteriEvet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00AA55),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('✅ EVET', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _musteriHayir,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFAA0000),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('❌ HAYIR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          // Ana butonlar
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_state.aktifMusteri != null || _state.gunBitmeli) ? null : _musteriCagir,
                  icon: const Text('🚪', style: TextStyle(fontSize: 16)),
                  label: const Text('Müşteri Çağır',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00AA55),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.withValues(alpha: 0.35),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _envanterAcik = true),
                  icon: const Text('📦', style: TextStyle(fontSize: 16)),
                  label: const Text('Envanter',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5533AA),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
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
              height: MediaQuery.of(context).size.height * 0.55,
              decoration: BoxDecoration(
                color: const Color(0xFF1a1008).withValues(alpha: 0.97),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: const Border(
                  top: BorderSide(color: Color(0xFFFFD700), width: 1.5),
                  left: BorderSide(color: Color(0xFFFFD700), width: 1.5),
                  right: BorderSide(color: Color(0xFFFFD700), width: 1.5),
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text('📦 ENVANTER', style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD700), letterSpacing: 1.5)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, mainAxisSpacing: 10,
                        crossAxisSpacing: 10, childAspectRatio: 0.85,
                      ),
                      itemCount: _state.envanter.length,
                      itemBuilder: (context, i) => _buildEnvanterKart(_state.envanter[i]),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnvanterKart(GameItem item) {
    final stokVar = item.stock > 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: stokVar
            ? const Color(0xFF2a1a0a).withValues(alpha: 0.9)
            : const Color(0xFF111111).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: stokVar ? const Color(0xFFFFD700).withValues(alpha: 0.5) : Colors.white12,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(item.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 4),
          Text(item.name,
            style: TextStyle(fontSize: 10, color: stokVar ? Colors.white70 : Colors.white30),
            textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('${item.basePrice}₺',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
              color: stokVar ? const Color(0xFF00FF88) : Colors.white24)),
          Text('Stok: ${item.stock}',
            style: TextStyle(fontSize: 10,
              color: stokVar ? Colors.white54 : Colors.white24)),
        ],
      ),
    );
  }

  void _pazarlikGoster() {
    final m = _state.aktifMusteri!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PazarlikDialog(state: _state, musteri: m),
    ).then((_) {
      if (_state.aktifMusteri != null) {
        _state.musteriReddet();
      }
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
  void dispose() {
    _teklifController.dispose();
    super.dispose();
  }

  void _teklifGonder() {
    final teklif = int.tryParse(_teklifController.text);
    if (teklif == null || teklif <= 0) return;

    final p = widget.state.aktifPazarlik!;
    widget.state.teklifVer(teklif);

    setState(() {
      if (p.durum == PazarlikDurum.anlasildi) {
        _dialogMesaj = '🤝 Anlaştık!';
        _bitti = true;
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) Navigator.of(context).pop();
        });
      } else if (p.durum == PazarlikDurum.gitti) {
        _dialogMesaj = p.mesaj;
        _bitti = true;
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) Navigator.of(context).pop();
        });
      } else {
        _dialogMesaj = p.mesaj;
      }
    });
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFFFD700), width: 1.5),
      ),
      title: Row(
        children: [
          Image.asset(m.gorsel, width: 52, height: 52, fit: BoxFit.contain),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.name, style: const TextStyle(
                fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
              Text(m.musteriSatiyor ? '💼 Satmak istiyor' : '🛒 Almak istiyor',
                style: const TextStyle(fontSize: 11, color: Colors.white54)),
            ],
          )),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Text(m.item.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.item.name, style: const TextStyle(
                    fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('Piyasa: ${m.item.basePrice}₺',
                    style: const TextStyle(fontSize: 10, color: Colors.white38)),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(m.musteriSatiyor ? 'İstediği fiyat:' : 'Verdiği teklif:',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
              Text('$musteriTeklif₺', style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFFFD700))),
            ],
          ),
          const SizedBox(height: 8),
          if (_dialogMesaj.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: anlasildi
                    ? Colors.green.withValues(alpha: 0.15)
                    : gitti ? Colors.red.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: anlasildi
                      ? Colors.green.withValues(alpha: 0.5)
                      : gitti ? Colors.red.withValues(alpha: 0.5) : Colors.white12,
                ),
              ),
              child: Text(_dialogMesaj,
                style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic,
                  color: anlasildi ? Colors.greenAccent : gitti ? Colors.redAccent : Colors.white70),
                textAlign: TextAlign.center),
            ),
          if (p != null && !_bitti)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Tur: ', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ...List.generate(p.maxTur, (i) => Container(
                    width: 10, height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < p.turSayisi ? const Color(0xFFFFD700) : Colors.white24,
                    ),
                  )),
                ],
              ),
            ),
          if (!_bitti)
            TextField(
              controller: _teklifController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: m.musteriSatiyor ? 'Teklifin (₺)' : 'Fiyatın (₺)',
                labelStyle: const TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFFFD700), width: 2),
                ),
              ),
            ),
        ],
      ),
      actions: _bitti ? [] : [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.state.musteriReddet();
          },
          child: const Text('Vazgeç', style: TextStyle(color: Colors.redAccent)),
        ),
        ElevatedButton(
          onPressed: _teklifGonder,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD700),
            foregroundColor: Colors.black,
          ),
          child: Text(m.musteriSatiyor ? 'Teklif Ver' : 'Fiyat Ver',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}