import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'konsol_cerceve.dart';

/// ─── TISSS ──────────────────────────────────────────────────────────────────
///
/// Envanterdeki "TISSS" CD'si oynanınca açılan yılan oyunu.
///
/// KONTROL: ekranın sağ yarısına her dokunuşta yılan 90° SAĞA, sol yarısına
/// her dokunuşta 90° SOLA döner. Yön mutlak değil, yılanın kendi yönüne göre
/// göreceli — klasik tek parmak yılan kontrolü.
///
/// PUAN = PARA. Yem başına 5 puan; yılan uzadıkça hızlanır, uzun oyun zor.
/// Tavan ana oyunda `GameState.oyunPuanTavani` ile sınırlı.
class TisssOyunu extends StatefulWidget {
  const TisssOyunu({super.key});

  @override
  State<TisssOyunu> createState() => _TisssOyunuState();
}

class _TisssOyunuState extends State<TisssOyunu> with SingleTickerProviderStateMixin {
  // ── Izgara ──
  // 15x21 hücre; en/boy oranı 0.714 → sahne kutusuyla aynı, hücreler kare.
  static const int _sutun = 15;
  static const int _satir = 21;

  // ── Yön: 0 yukarı, 1 sağ, 2 aşağı, 3 sol ──
  static const List<Point<int>> _yonler = [
    Point(0, -1), Point(1, 0), Point(0, 1), Point(-1, 0),
  ];
  int _yon = 0;

  /// Bu adımda uygulanacak dönüşler. Kuyruk, çünkü bir adım içinde iki kez
  /// dokunulursa ikisi de sırayla işlensin — dokunuş yutulmasın.
  final List<int> _bekleyenDonusler = [];

  // ── Yılan ──
  late List<Point<int>> _yilan;
  late Point<int> _yem;

  // ── Zamanlama ──
  static const double _adimBaslangic = 0.22; // saniye/hücre
  double _adimSuresi = _adimBaslangic;
  double _birikim = 0;

  // ── Durum ──
  static const int _yemPuani = 5;
  int _puan = 0;
  bool _basladi = false;
  bool _bitti = false;

  Ticker? _ticker;
  Duration _oncekiTick = Duration.zero;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _yilan = [
      const Point(_sutun ~/ 2, _satir ~/ 2),
      const Point(_sutun ~/ 2, _satir ~/ 2 + 1),
      const Point(_sutun ~/ 2, _satir ~/ 2 + 2),
    ];
    _yemKoy();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _yemKoy() {
    // Yılanın üstüne denk gelmeyen rastgele bir hücre
    final bos = <Point<int>>[];
    for (int x = 0; x < _sutun; x++) {
      for (int y = 0; y < _satir; y++) {
        final p = Point(x, y);
        if (!_yilan.contains(p)) bos.add(p);
      }
    }
    if (bos.isEmpty) { _bitti = true; return; }
    _yem = bos[_rng.nextInt(bos.length)];
  }

  void _tick(Duration simdi) {
    final dtRaw = (simdi - _oncekiTick).inMicroseconds / 1e6;
    _oncekiTick = simdi;
    if (_bitti || !_basladi) return;
    final dt = dtRaw.clamp(0.0, 1 / 30);
    _birikim += dt;
    if (_birikim < _adimSuresi) return;
    _birikim = 0;

    // Bekleyen dönüşten birini uygula
    if (_bekleyenDonusler.isNotEmpty) {
      _yon = _bekleyenDonusler.removeAt(0);
    }

    final d = _yonler[_yon];
    final bas = _yilan.first;
    final yeni = Point(bas.x + d.x, bas.y + d.y);

    // Duvar
    if (yeni.x < 0 || yeni.x >= _sutun || yeni.y < 0 || yeni.y >= _satir) {
      setState(() => _bitti = true);
      return;
    }
    // Kendine çarpma — kuyruğun son hücresi bu adımda boşalacağı için hariç
    final govde = _yilan.sublist(0, _yilan.length - 1);
    if (govde.contains(yeni)) {
      setState(() => _bitti = true);
      return;
    }

    _yilan.insert(0, yeni);
    if (yeni == _yem) {
      _puan += _yemPuani;
      // Her yemde hafif hızlan — uzun oyun giderek zorlaşsın
      _adimSuresi = max(0.085, _adimSuresi - 0.004);
      _yemKoy();
    } else {
      _yilan.removeLast();
    }
    setState(() {});
  }

  /// Dokunuş: sağ yarı → sağa 90°, sol yarı → sola 90°.
  void _dokun(Offset yerel, double genislik) {
    if (_bitti) return;
    if (!_basladi) { setState(() => _basladi = true); return; }
    final sonYon = _bekleyenDonusler.isNotEmpty ? _bekleyenDonusler.last : _yon;
    final saga = yerel.dx >= genislik / 2;
    final yeniYon = saga ? (sonYon + 1) % 4 : (sonYon + 3) % 4;
    // Kuyruk iki dönüşle sınırlı; daha fazlası kontrolü kaygan yapıyor
    if (_bekleyenDonusler.length < 2) _bekleyenDonusler.add(yeniYon);
  }

  void _cik() => Navigator.of(context).pop(_puan);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _cik(); },
      child: Scaffold(
        backgroundColor: Colors.black,
        // SafeArea YOK: kasa tum ekrani kaplasin, ust/altta bant kalmasin
        body: KonsolCercevesi(
            cocuk: Column(
              children: [
              _buildUstBar(),
              Expanded(
                child: LayoutBuilder(builder: (context, kutu) {
                  final hucre = min(kutu.maxWidth / _sutun, kutu.maxHeight / _satir);
                  final en = hucre * _sutun, boy = hucre * _satir;
                  // ⚠️ Dokunma alanı oyun ızgarasını değil EKRANIN TAMAMINI
                  // kaplar — gerekçesi kirgec_oyunu.dart'ta yazılı.
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (e) => _dokun(e.localPosition, kutu.maxWidth),
                    child: Center(
                      child: SizedBox(
                        width: en, height: boy,
                        child: Stack(children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _TisssPainter(
                                yilan: _yilan, yem: _yem,
                                sutun: _sutun, satir: _satir, bitti: _bitti,
                              ),
                            ),
                          ),
                          // "Başlamak için dokun" oyun alanının üst 1/3'ünde
                          // çıkıyor — tam ortada yılanın başlangıç konumuyla
                          // çakışıyordu.
                          if (!_basladi && !_bitti)
                            Positioned(
                              left: 0, right: 0, top: 0, height: boy / 3,
                              child: Center(child: _buildBaslaYazisi()),
                            ),
                          if (_bitti) _buildBitisPaneli(),
                        ]),
                      ),
                    ),
                  );
                }),
              ),
            ],
            ),
          ),
        ),
      );
  }

  Widget _buildUstBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(children: [
        const Text('TISSS',
          style: TextStyle(color: Color(0xFF7ed957), fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const Spacer(),
        Text('UZUNLUK ${_yilan.length}',
          style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(width: 14),
        Text('$_puan',
          style: const TextStyle(color: Color(0xFFFFD700), fontSize: 20, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _buildBaslaYazisi() {
    // Konsol kasası oyun alanını daralttı → FittedBox ile sığdır (bkz. Kırgeç)
    // Center burada YOK — dışarıdaki Positioned+Center zaten üst 1/3'e
    // konumluyor; ikinci bir Center gereksiz.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          color: Colors.black54,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: const Column(mainAxisSize: MainAxisSize.min, children: [
            Text('BAŞLAMAK İÇİN DOKUN',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            SizedBox(height: 8),
            Text('Sağ yarı → 90° sağa   ·   Sol yarı → 90° sola',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
            SizedBox(height: 4),
            Text('Yem başına 5 puan · duvara ve kendine çarpma',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
        ),
      ),
    );
  }

  Widget _buildBitisPaneli() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        decoration: BoxDecoration(
          color: const Color(0xFF0a1a0c),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF7ed957), width: 2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🐍', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 6),
          const Text('OYUN BİTTİ',
            style: TextStyle(color: Color(0xFF7ed957), fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text('Uzunluk: ${_yilan.length}',
            style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('$_puan PUAN',
            style: const TextStyle(color: Color(0xFFFFD700), fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _cik,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7ed957), foregroundColor: Colors.black,
              minimumSize: const Size(180, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('DÜKKANA DÖN', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ]),
      ),
    );
  }
}

class _TisssPainter extends CustomPainter {
  final List<Point<int>> yilan;
  final Point<int> yem;
  final int sutun, satir;
  final bool bitti;

  _TisssPainter({required this.yilan, required this.yem,
    required this.sutun, required this.satir, required this.bitti});

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.width / sutun; // hücre boyu (kare)

    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF08130a));

    // Izgara
    final izgara = Paint()..color = const Color(0xFF132716)..strokeWidth = 1;
    for (int x = 0; x <= sutun; x++) {
      canvas.drawLine(Offset(x * h, 0), Offset(x * h, size.height), izgara);
    }
    for (int y = 0; y <= satir; y++) {
      canvas.drawLine(Offset(0, y * h), Offset(size.width, y * h), izgara);
    }

    // Yem — parıltılı elma
    final yemMerkez = Offset((yem.x + 0.5) * h, (yem.y + 0.5) * h);
    canvas.drawCircle(yemMerkez, h * 0.55, Paint()..color = const Color(0xFFff5252).withValues(alpha: 0.20));
    canvas.drawCircle(yemMerkez, h * 0.32, Paint()..color = const Color(0xFFff5252));

    // Yılan — baş daha parlak, gövde kuyruğa doğru koyulaşır
    for (int i = 0; i < yilan.length; i++) {
      final p = yilan[i];
      final t = yilan.length == 1 ? 0.0 : i / (yilan.length - 1);
      final renk = Color.lerp(const Color(0xFF9cff6b), const Color(0xFF2e7d32), t)!;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(p.x * h + h * 0.08, p.y * h + h * 0.08, h * 0.84, h * 0.84),
        Radius.circular(h * 0.28),
      );
      canvas.drawRRect(r, Paint()..color = bitti ? renk.withValues(alpha: 0.45) : renk);
      if (i == 0) {
        // Gözler
        final g = Paint()..color = Colors.black87;
        canvas.drawCircle(Offset((p.x + 0.35) * h, (p.y + 0.38) * h), h * 0.09, g);
        canvas.drawCircle(Offset((p.x + 0.65) * h, (p.y + 0.38) * h), h * 0.09, g);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TisssPainter old) => true;
}
