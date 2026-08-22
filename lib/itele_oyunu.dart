import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'konsol_cerceve.dart';

/// ─── İTELE ──────────────────────────────────────────────────────────────────
///
/// Envanterdeki "İTELE" CD'si oynanınca açılan tek kişilik pong.
/// ALT çubuk oyuncunun, ÜST çubuk bilgisayarın. İlk 10 sayıya ulaşan kazanır.
///
/// PUAN = PARA. Her sayı 10 puan; galibiyet tam 100 lira eder, yenilirsen
/// o ana kadar attığın sayı kadar alırsın. Bilgisayar bilerek iyi oynuyor —
/// para kazanmak kolay olmamalı.
///
/// KONTROL: Kırgeç ile aynı — ekranın sağ yarısına basılı tut, çubuk sağa;
/// sol yarısına bas, sola.
class IteleOyunu extends StatefulWidget {
  const IteleOyunu({super.key});

  @override
  State<IteleOyunu> createState() => _IteleOyunuState();
}

class _IteleOyunuState extends State<IteleOyunu> with SingleTickerProviderStateMixin {
  // ── Mantıksal alan ──
  static const double _alanEn = 100;
  static const double _alanBoy = 140;

  // ── Çubuklar ──
  static const double _cubukEn = 20;
  static const double _cubukBoy = 2.4;
  static const double _oyuncuHiz = 82;   // birim/saniye
  static const double _altY = _alanBoy - 9;
  static const double _ustY = 6.6;
  double _oyuncuX = 50;
  double _botX = 50;

  /// Botun tepki hızı. Oyuncudan biraz yavaş — yenilebilir ama zorlu.
  static const double _botHiz = 60;
  /// Botun nişan hatası: her sekmede yeniden çekilir, hep mükemmel olmasın.
  double _botHata = 0;

  // ── Top ──
  static const double _topR = 1.7;
  double _topX = 50, _topY = 70;
  double _hizX = 0, _hizY = 0;
  double _topHiz = 46;
  static const double _topHizBaslangic = 46;

  // ── Skor ──
  static const int _hedefSayi = 10;
  static const int _sayiPuani = 10; // 10 sayı × 10 = 100 lira
  int _oyuncuSkor = 0;
  int _botSkor = 0;

  bool _basladi = false;
  bool _bitti = false;
  bool _kazandi = false;
  int _yon = 0;

  Ticker? _ticker;
  Duration _oncekiTick = Duration.zero;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _serviyeHazirla(oyuncuyaDogru: true);
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _serviyeHazirla({required bool oyuncuyaDogru}) {
    _basladi = false;
    _topX = 50;
    _topY = _alanBoy / 2;
    _hizX = 0;
    _hizY = 0;
    _topHiz = _topHizBaslangic;
    _botHata = _rng.nextDouble() * 6 - 3;
    // Sayıyı kim yediyse servis ona doğru gider
    _servisYonuAsagi = oyuncuyaDogru;
  }

  bool _servisYonuAsagi = true;

  void _topuFirlat() {
    if (_basladi) return;
    _basladi = true;
    final sapma = (_rng.nextDouble() * 50 - 25) * pi / 180;
    final temelAci = _servisYonuAsagi ? (pi / 2) : (-pi / 2);
    _hizX = sin(sapma) * _topHiz;
    _hizY = cos(sapma) * _topHiz * (temelAci > 0 ? 1 : -1);
  }

  void _sayi({required bool oyuncuAtti}) {
    if (oyuncuAtti) {
      _oyuncuSkor++;
    } else {
      _botSkor++;
    }
    if (_oyuncuSkor >= _hedefSayi || _botSkor >= _hedefSayi) {
      _kazandi = _oyuncuSkor >= _hedefSayi;
      _bitti = true;
      return;
    }
    // Sayıyı yiyen tarafa servis
    _serviyeHazirla(oyuncuyaDogru: !oyuncuAtti);
  }

  void _tick(Duration simdi) {
    final dtRaw = (simdi - _oncekiTick).inMicroseconds / 1e6;
    _oncekiTick = simdi;
    if (_bitti) return;
    final dt = dtRaw.clamp(0.0, 1 / 30);
    if (dt <= 0) return;

    // ── Oyuncu çubuğu ──
    if (_yon != 0) {
      _oyuncuX = (_oyuncuX + _yon * _oyuncuHiz * dt).clamp(_cubukEn / 2, _alanEn - _cubukEn / 2);
    }

    // ── Bot çubuğu: topu takip eder ama hız sınırlı + nişan hatalı ──
    // Top uzaklaşıyorsa merkeze dönüyor; bu onu insan gibi gösteriyor ve
    // oyuncuya nefes aldırıyor.
    final botHedef = (_hizY < 0 && _basladi) ? _topX + _botHata : 50.0;
    final botFark = botHedef - _botX;
    final botAdim = _botHiz * dt;
    if (botFark.abs() <= botAdim) {
      _botX = botHedef;
    } else {
      _botX += botFark.sign * botAdim;
    }
    _botX = _botX.clamp(_cubukEn / 2, _alanEn - _cubukEn / 2);

    if (!_basladi) {
      setState(() {});
      return;
    }

    // ── Top ──
    _topX += _hizX * dt;
    _topY += _hizY * dt;

    // Yan duvarlar
    if (_topX - _topR < 0) { _topX = _topR; _hizX = _hizX.abs(); }
    if (_topX + _topR > _alanEn) { _topX = _alanEn - _topR; _hizX = -_hizX.abs(); }

    // ── Oyuncu çubuğu (alt) ──
    if (_hizY > 0 &&
        _topY + _topR >= _altY &&
        _topY - _topR <= _altY + _cubukBoy &&
        _topX >= _oyuncuX - _cubukEn / 2 - _topR &&
        _topX <= _oyuncuX + _cubukEn / 2 + _topR) {
      _topY = _altY - _topR;
      _sektir(_oyuncuX, yukari: true);
    }

    // ── Bot çubuğu (üst) ──
    if (_hizY < 0 &&
        _topY - _topR <= _ustY + _cubukBoy &&
        _topY + _topR >= _ustY &&
        _topX >= _botX - _cubukEn / 2 - _topR &&
        _topX <= _botX + _cubukEn / 2 + _topR) {
      _topY = _ustY + _cubukBoy + _topR;
      _sektir(_botX, yukari: false);
    }

    // ── Sayı ──
    if (_topY - _topR > _alanBoy) {
      _sayi(oyuncuAtti: false); // oyuncu kaçırdı → bot sayı aldı
    } else if (_topY + _topR < 0) {
      _sayi(oyuncuAtti: true);  // bot kaçırdı → oyuncu sayı aldı
    }

    setState(() {});
  }

  /// Çubuğun neresine çarptıysa o yöne saptır; her vuruşta hafif hızlan.
  void _sektir(double cubukMerkez, {required bool yukari}) {
    final fark = ((_topX - cubukMerkez) / (_cubukEn / 2)).clamp(-1.0, 1.0);
    _topHiz = min(_topHiz + 1.2, 88);
    final aci = fark * 55 * pi / 180; // dikeyden sapma
    _hizX = sin(aci) * _topHiz;
    _hizY = cos(aci) * _topHiz * (yukari ? -1 : 1);
    _botHata = _rng.nextDouble() * 6 - 3; // her sekmede yeni hata
  }

  int get _puan => _oyuncuSkor * _sayiPuani;

  void _cik() => Navigator.of(context).pop(_puan);

  void _dokunusBasla(Offset yerel, double genislik) {
    if (_bitti) return;
    _topuFirlat();
    _yon = yerel.dx < genislik / 2 ? -1 : 1;
  }

  void _dokunusBitir() => _yon = 0;

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
                  final olcek = min(kutu.maxWidth / _alanEn, kutu.maxHeight / _alanBoy);
                  final en = _alanEn * olcek, boy = _alanBoy * olcek;
                  return Center(
                    child: SizedBox(
                      width: en, height: boy,
                      child: Listener(
                        onPointerDown: (e) => _dokunusBasla(e.localPosition, en),
                        onPointerMove: (e) {
                          if (_bitti) return;
                          _yon = e.localPosition.dx < en / 2 ? -1 : 1;
                        },
                        onPointerUp: (_) => _dokunusBitir(),
                        onPointerCancel: (_) => _dokunusBitir(),
                        child: Stack(children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _ItelePainter(
                                oyuncuX: _oyuncuX, botX: _botX,
                                cubukEn: _cubukEn, cubukBoy: _cubukBoy,
                                altY: _altY, ustY: _ustY,
                                topX: _topX, topY: _topY, topR: _topR,
                                alanEn: _alanEn, alanBoy: _alanBoy,
                              ),
                            ),
                          ),
                          if (!_basladi && !_bitti) _buildBaslaYazisi(),
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
        const Text('İTELE',
          style: TextStyle(color: Color(0xFF29b6f6), fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const Spacer(),
        _skorKutu('BİLGİSAYAR', _botSkor, const Color(0xFFff5252)),
        const SizedBox(width: 10),
        _skorKutu('SEN', _oyuncuSkor, const Color(0xFF29b6f6)),
      ]),
    );
  }

  Widget _skorKutu(String ad, int skor, Color renk) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(ad, style: TextStyle(color: renk.withValues(alpha: 0.75), fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
      Text('$skor / $_hedefSayi',
        style: TextStyle(color: renk, fontSize: 16, fontWeight: FontWeight.w900)),
    ]);
  }

  Widget _buildBaslaYazisi() {
    // Konsol kasası oyun alanını daralttı → FittedBox ile sığdır (bkz. Kırgeç)
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('BAŞLAMAK İÇİN DOKUN',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            SizedBox(height: 8),
            Text('Sağ yarı → sağa   ·   Sol yarı → sola',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
            SizedBox(height: 4),
            Text('Önce 10 sayıya ulaşan kazanır',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
        ),
      ),
    );
  }

  Widget _buildBitisPaneli() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        decoration: BoxDecoration(
          color: const Color(0xFF0a1020),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF29b6f6), width: 2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_kazandi ? '🏆' : '💀', style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 6),
          Text(_kazandi ? 'KAZANDIN!' : 'KAYBETTİN',
            style: TextStyle(
              color: _kazandi ? const Color(0xFF29b6f6) : const Color(0xFFff5252),
              fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text('$_oyuncuSkor - $_botSkor',
            style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('$_puan PUAN',
            style: const TextStyle(color: Color(0xFFFFD700), fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _cik,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF29b6f6), foregroundColor: Colors.black,
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

class _ItelePainter extends CustomPainter {
  final double oyuncuX, botX, cubukEn, cubukBoy, altY, ustY;
  final double topX, topY, topR, alanEn, alanBoy;

  _ItelePainter({
    required this.oyuncuX, required this.botX,
    required this.cubukEn, required this.cubukBoy,
    required this.altY, required this.ustY,
    required this.topX, required this.topY, required this.topR,
    required this.alanEn, required this.alanBoy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / alanEn;
    final sy = size.height / alanBoy;

    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF060a16));

    // Orta çizgi — kesik kesik
    final orta = Paint()..color = const Color(0xFF1c2c52)..strokeWidth = 2;
    for (double x = 2; x < alanEn; x += 6) {
      canvas.drawLine(
        Offset(x * sx, alanBoy / 2 * sy),
        Offset((x + 3) * sx, alanBoy / 2 * sy), orta);
    }
    // Kenar ışıkları
    final kenar = Paint()..color = const Color(0xFF16233f)..strokeWidth = 2;
    canvas.drawLine(const Offset(0, 0), Offset(0, size.height), kenar);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, size.height), kenar);

    _cubuk(canvas, botX, ustY, sx, sy, const Color(0xFFff5252), const Color(0xFFb71c1c));
    _cubuk(canvas, oyuncuX, altY, sx, sy, const Color(0xFF40c4ff), const Color(0xFF0277bd));

    final merkez = Offset(topX * sx, topY * sy);
    canvas.drawCircle(merkez, topR * sx * 2.2,
      Paint()..color = Colors.white.withValues(alpha: 0.16));
    canvas.drawCircle(merkez, topR * sx, Paint()..color = Colors.white);
  }

  void _cubuk(Canvas canvas, double merkezX, double y, double sx, double sy, Color a, Color b) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH((merkezX - cubukEn / 2) * sx, y * sy, cubukEn * sx, cubukBoy * sy),
      Radius.circular(3 * sx),
    );
    canvas.drawRRect(rect, Paint()
      ..shader = LinearGradient(colors: [a, b]).createShader(rect.outerRect));
    canvas.drawRRect(rect, Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 1.4
      ..color = a.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(covariant _ItelePainter old) => true;
}
