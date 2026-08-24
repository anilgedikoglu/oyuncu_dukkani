import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'konsol_cerceve.dart';

/// ─── KIRGEÇ ─────────────────────────────────────────────────────────────────
///
/// Envanterdeki "KIRGEÇ" CD'si oynanınca açılan mini breakout oyunu.
/// Ana oyundan tamamen bağımsız çalışır: `Navigator.push` ile açılır, biterken
/// `Navigator.pop(context, puan)` ile toplanan puanı geri döner. Ana ekran o
/// puanı paraya çevirip bakiyeye ekler.
///
/// KONTROL: ekranın sağ yarısına basılı tutulunca çubuk sağa, sol yarısına
/// basılı tutulunca sola kayar. Tek dokunuş değil — parmak kalkana kadar hareket
/// sürer, yoksa çubuğu topa yetiştirmek imkânsız oluyordu.
///
/// Oyun alanı `_AlanOlcu` ile mantıksal 100x100 birime kilitli; her şey oranla
/// hesaplanıp ekrana ölçekleniyor, böylece çözünürlükten bağımsız.
class KirgecOyunu extends StatefulWidget {
  const KirgecOyunu({super.key});

  @override
  State<KirgecOyunu> createState() => _KirgecOyunuState();
}

/// Tek bir tuğla.
class _Tugla {
  final double x, y, en, boy;
  final Color renk;
  final int puan;
  bool kirik = false;
  _Tugla(this.x, this.y, this.en, this.boy, this.renk, this.puan);
}

class _KirgecOyunuState extends State<KirgecOyunu> with SingleTickerProviderStateMixin {
  // ── Mantıksal oyun alanı (birim) ──
  static const double _alanEn = 100;
  static const double _alanBoy = 140;

  // ── Çubuk ──
  static const double _cubukBoy = 2.2;
  static const double _cubukHiz = 78;   // birim/saniye
  final double _cubukEn = 16;   // dar tutuldu: kolay geçilmesin
  double _cubukX = 50;                  // merkez

  // ── Top ──
  static const double _topR = 1.6;
  double _topX = 50, _topY = 100;
  double _hizX = 0, _hizY = 0;
  static const double _topHizBaslangic = 52;
  double _topHiz = _topHizBaslangic;

  // ── Durum ──
  final List<_Tugla> _tuglalar = [];
  int _puan = 0;
  int _can = 3;
  bool _basladi = false;   // ilk dokunuşa kadar top çubuğa yapışık
  bool _bitti = false;
  bool _kazandi = false;
  int _yon = 0;            // -1 sol, 0 dur, +1 sağ

  Ticker? _ticker;
  Duration _oncekiTick = Duration.zero;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _seviyeKur();
    _topuCubugaYapistir();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _seviyeKur() {
    _tuglalar.clear();
    const satirlar = 6, sutunlar = 8;
    const kenar = 4.0, ustBosluk = 16.0, aralik = 1.0;
    final en = (_alanEn - kenar * 2 - aralik * (sutunlar - 1)) / sutunlar;
    const boy = 4.4;
    // Üst satırlar daha değerli — oyuncunun yukarı nişan almasını ödüllendirir.
    const renkler = [
      Color(0xFFff5252), Color(0xFFff9800), Color(0xFFffd600),
      Color(0xFF64dd17), Color(0xFF00b0ff), Color(0xFFaa00ff),
    ];
    for (int r = 0; r < satirlar; r++) {
      for (int c = 0; c < sutunlar; c++) {
        _tuglalar.add(_Tugla(
          kenar + c * (en + aralik),
          ustBosluk + r * (boy + aralik),
          en, boy,
          renkler[r],
          // PUAN = PARA. Tam temizlik 336 + 50 bonus ≈ 386 lira etsin diye
          // düşük tutuldu; kolay kazanç olmamalı. Üst satır daha değerli.
          (satirlar - r) * 2, // üst satır 12, alt satır 2 puan
        ));
      }
    }
  }

  void _topuCubugaYapistir() {
    _basladi = false;
    _topX = _cubukX;
    _topY = _alanBoy - 8 - _topR;
    _hizX = 0;
    _hizY = 0;
    _topHiz = _topHizBaslangic;
  }

  void _topuFirlat() {
    if (_basladi) return;
    _basladi = true;
    // Hafif rastgele açı ama hep yukarı
    final aci = (-90 + (_rng.nextDouble() * 40 - 20)) * pi / 180;
    _hizX = cos(aci) * _topHiz;
    _hizY = sin(aci) * _topHiz;
  }

  void _tick(Duration simdi) {
    final dtRaw = (simdi - _oncekiTick).inMicroseconds / 1e6;
    _oncekiTick = simdi;
    if (_bitti) return;
    // Kare atlarsa fizik patlamasın diye adım sınırlı
    final dt = dtRaw.clamp(0.0, 1 / 30);
    if (dt <= 0) return;

    // ── Çubuk ──
    if (_yon != 0) {
      _cubukX = (_cubukX + _yon * _cubukHiz * dt).clamp(_cubukEn / 2, _alanEn - _cubukEn / 2);
    }
    if (!_basladi) {
      _topX = _cubukX;
      setState(() {});
      return;
    }

    // ── Top ──
    _topX += _hizX * dt;
    _topY += _hizY * dt;

    // Yan duvarlar
    if (_topX - _topR < 0) { _topX = _topR; _hizX = _hizX.abs(); }
    if (_topX + _topR > _alanEn) { _topX = _alanEn - _topR; _hizX = -_hizX.abs(); }
    // Tavan
    if (_topY - _topR < 0) { _topY = _topR; _hizY = _hizY.abs(); }

    // ── Çubuk çarpışması ──
    final cubukUst = _alanBoy - 8;
    if (_hizY > 0 &&
        _topY + _topR >= cubukUst &&
        _topY - _topR <= cubukUst + _cubukBoy &&
        _topX >= _cubukX - _cubukEn / 2 - _topR &&
        _topX <= _cubukX + _cubukEn / 2 + _topR) {
      _topY = cubukUst - _topR;
      // Çubuğun neresine çarptıysa o yöne sapar — oyuncuya kontrol verir
      final fark = ((_topX - _cubukX) / (_cubukEn / 2)).clamp(-1.0, 1.0);
      final aci = (-90 + fark * 60) * pi / 180;
      _topHiz = min(_topHiz + 1.5, 95); // her vuruşta hafif hızlanır
      _hizX = cos(aci) * _topHiz;
      _hizY = sin(aci) * _topHiz;
    }

    // ── Tuğla çarpışması ──
    for (final t in _tuglalar) {
      if (t.kirik) continue;
      if (_topX + _topR < t.x || _topX - _topR > t.x + t.en) continue;
      if (_topY + _topR < t.y || _topY - _topR > t.y + t.boy) continue;
      t.kirik = true;
      _puan += t.puan;
      // Hangi yüzeye çarptığını kabaca kestir: daha az gömüldüğü eksenden seker
      final solMesafe = (_topX + _topR - t.x).abs();
      final sagMesafe = (t.x + t.en - (_topX - _topR)).abs();
      final ustMesafe = (_topY + _topR - t.y).abs();
      final altMesafe = (t.y + t.boy - (_topY - _topR)).abs();
      final enAz = [solMesafe, sagMesafe, ustMesafe, altMesafe].reduce(min);
      if (enAz == ustMesafe || enAz == altMesafe) {
        _hizY = -_hizY;
      } else {
        _hizX = -_hizX;
      }
      break; // kare başına tek tuğla — çoklu sekme fiziği bozuyor
    }

    // ── Alt çizgi: can gitti ──
    if (_topY - _topR > _alanBoy) {
      _can--;
      if (_can <= 0) {
        _bitti = true;
      } else {
        _topuCubugaYapistir();
      }
    }

    // ── Bütün tuğlalar kırıldı ──
    if (!_bitti && _tuglalar.every((t) => t.kirik)) {
      _kazandi = true;
      _bitti = true;
      _puan += 50; // bitirme bonusu
    }

    setState(() {});
  }

  void _cik() => Navigator.of(context).pop(_puan);

  // ── Dokunma: ekranın hangi yarısı? ──
  void _dokunusBasla(Offset yerel, double genislik) {
    if (_bitti) return;
    _topuFirlat();
    _yon = yerel.dx < genislik / 2 ? -1 : 1;
  }

  void _dokunusBitir() => _yon = 0;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Geri tuşuyla çıkılırsa da puan ana oyuna gitsin
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
                  // Mantıksal alanı ekrana sığdır (en-boy korunur)
                  final olcek = min(kutu.maxWidth / _alanEn, kutu.maxHeight / _alanBoy);
                  final en = _alanEn * olcek, boy = _alanBoy * olcek;
                  return Center(
                    child: SizedBox(
                      width: en, height: boy,
                      child: Listener(
                        onPointerDown: (e) => _dokunusBasla(e.localPosition, en),
                        // Parmak kaydırılırsa yön anında güncellensin
                        onPointerMove: (e) {
                          if (_bitti) return;
                          _yon = e.localPosition.dx < en / 2 ? -1 : 1;
                        },
                        onPointerUp: (_) => _dokunusBitir(),
                        onPointerCancel: (_) => _dokunusBitir(),
                        child: Stack(children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _KirgecPainter(
                                tuglalar: _tuglalar,
                                cubukX: _cubukX, cubukEn: _cubukEn, cubukBoy: _cubukBoy,
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
        const Text('KIRGEÇ',
          style: TextStyle(color: Color(0xFF00e5ff), fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const Spacer(),
        Row(children: List.generate(3, (i) => Padding(
          padding: const EdgeInsets.only(left: 3),
          child: Icon(Icons.circle,
            size: 12, color: i < _can ? const Color(0xFFff5252) : Colors.white12),
        ))),
        const SizedBox(width: 14),
        Text('$_puan',
          style: const TextStyle(color: Color(0xFFFFD700), fontSize: 20, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _buildBaslaYazisi() {
    // ⚠️ Konsol kasası oyun alanını daralttı; sabit fontla metin taşıp iki
    // satıra bölünüyor ve tuğlaların üstüne biniyordu. FittedBox ile sığdırılır,
    // alt yarıya hizalanır ki tuğlaları kapatmasın.
    return const Align(
      alignment: Alignment(0, 0.45),
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
          ]),
        ),
      ),
    );
  }

  Widget _buildBitisPaneli() {
    // ⚠️ Dar konsol kasası ekranında sabit fontla "TOPLAR BİTTİ" ve
    // "DÜKKANA DÖN" tek satıra sığmayıp bölünüyordu. FittedBox+maxLines:1
    // ile taşarsa küçülür, hiçbir zaman satır kaymaz. Kenar boşlukları da
    // biraz daraltıldı (24→16) — daha fazla yatay alan bıraksın.
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        decoration: BoxDecoration(
          color: const Color(0xFF120c1e),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF00e5ff), width: 2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_kazandi ? '🏆' : '💀', style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_kazandi ? 'HEPSİNİ KIRDIN!' : 'TOPLAR BİTTİ',
              maxLines: 1,
              style: const TextStyle(color: Color(0xFF00e5ff), fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          ),
          const SizedBox(height: 12),
          Text('$_puan PUAN',
            style: const TextStyle(color: Color(0xFFFFD700), fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _cik,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00e5ff), foregroundColor: Colors.black,
              minimumSize: const Size(190, 44),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('DÜKKANA DÖN', maxLines: 1, style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Oyun alanını çizer. Tüm koordinatlar mantıksal birimde gelir, burada
/// ekran ölçeğine çevrilir.
class _KirgecPainter extends CustomPainter {
  final List<_Tugla> tuglalar;
  final double cubukX, cubukEn, cubukBoy;
  final double topX, topY, topR;
  final double alanEn, alanBoy;

  _KirgecPainter({
    required this.tuglalar,
    required this.cubukX, required this.cubukEn, required this.cubukBoy,
    required this.topX, required this.topY, required this.topR,
    required this.alanEn, required this.alanBoy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / alanEn;
    final sy = size.height / alanBoy;

    // Zemin + ızgara
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0a0618));
    final izgara = Paint()..color = const Color(0xFF1b1236)..strokeWidth = 1;
    for (double x = 0; x <= alanEn; x += 10) {
      canvas.drawLine(Offset(x * sx, 0), Offset(x * sx, size.height), izgara);
    }
    for (double y = 0; y <= alanBoy; y += 10) {
      canvas.drawLine(Offset(0, y * sy), Offset(size.width, y * sy), izgara);
    }

    // Tuğlalar
    for (final t in tuglalar) {
      if (t.kirik) continue;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(t.x * sx, t.y * sy, t.en * sx, t.boy * sy),
        Radius.circular(2 * sx),
      );
      canvas.drawRRect(r, Paint()..color = t.renk);
      // Üstte açık bir şerit — pixel-art hissi
      canvas.drawRect(
        Rect.fromLTWH(t.x * sx, t.y * sy, t.en * sx, t.boy * sy * 0.28),
        Paint()..color = Colors.white.withValues(alpha: 0.25),
      );
    }

    // Çubuk
    final cubukUst = alanBoy - 8;
    final cubukRect = RRect.fromRectAndRadius(
      Rect.fromLTWH((cubukX - cubukEn / 2) * sx, cubukUst * sy, cubukEn * sx, cubukBoy * sy),
      Radius.circular(3 * sx),
    );
    canvas.drawRRect(cubukRect, Paint()
      ..shader = const LinearGradient(colors: [Color(0xFF40c4ff), Color(0xFF0091ea)])
          .createShader(cubukRect.outerRect));
    canvas.drawRRect(cubukRect, Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 1.5
      ..color = const Color(0xFF80d8ff));

    // Top + parıltı
    final topMerkez = Offset(topX * sx, topY * sy);
    canvas.drawCircle(topMerkez, topR * sx * 2.2,
      Paint()..color = const Color(0xFF00e5ff).withValues(alpha: 0.18));
    canvas.drawCircle(topMerkez, topR * sx, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _KirgecPainter old) => true;
}
