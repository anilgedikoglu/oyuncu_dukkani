import 'dart:math';
import 'package:flutter/material.dart';

/// ─── KONSOL KASASI ──────────────────────────────────────────────────────────
///
/// Mini oyunları (Kırgeç / İtele / TISSS) bir oyun konsolunun ekranı içinde
/// çalışıyormuş gibi gösterir. Kasa görseli ekranı `cover` ile TAMAMEN kaplar
/// ve oyun, kasanın SİYAH EKRAN alanına yerleştirilir.
///
/// ⚠️ Neden `cover`, `contain` değil: kasa görselleri 9:20'ye (0.45) çok yakın
/// üretildi ama telefon oranları cihazdan cihaza değişiyor. `contain` en ufak
/// sapmada alt/üstte siyah bant bırakıyordu. `cover` ile bant hiç oluşmuyor,
/// karşılığında kenarlardan birkaç piksel kırpılıyor (bu kasalarda en fazla
/// ~%2,5) — kasa kenarları dekoratif olduğu için fark edilmiyor.
///
/// Elde iki kasa var; hangisinin geleceği her oyun açılışında rastgele seçilir.
class KonsolCercevesi extends StatefulWidget {
  final Widget cocuk;
  const KonsolCercevesi({super.key, required this.cocuk});

  @override
  State<KonsolCercevesi> createState() => _KonsolCercevesiState();
}

/// Bir kasa: görseli + ekranının görsel İÇİNDEKİ yeri (0..1 oranları).
///
/// Oranlar görsel üzerine dikdörtgen çizdirilerek doğrulandı; ekranın koyu
/// alanının biraz içinden geçiyorlar ki oyun kenarlara dayanmasın.
class _Kasa {
  final String gorsel;
  final double oran;                 // en / boy
  final double sol, ust, gen, yuk;   // ekran dikdörtgeni
  const _Kasa(this.gorsel, this.oran, this.sol, this.ust, this.gen, this.yuk);
}

class _KonsolCercevesiState extends State<KonsolCercevesi> {
  // Ekran dikdörtgenleri görsel üzerine çizdirilerek doğrulandı.
  static const List<_Kasa> _kasalar = [
    // Retro el konsolu — 1080×2401
    _Kasa('assets/konsol_cerceve_1.jpg', 1080 / 2401, 0.055, 0.290, 0.890, 0.395),
    // Arcade kabin — 1080×2340
    _Kasa('assets/konsol_cerceve_2.jpg', 1080 / 2340, 0.085, 0.195, 0.830, 0.545),
  ];

  late final _Kasa _secili;

  @override
  void initState() {
    super.initState();
    // ⚠️ Kasa oyun BAŞLARKEN bir kez seçilir. build() içinde seçilseydi
    // her karede değişir, ekran titrerdi.
    _secili = _kasalar[Random().nextInt(_kasalar.length)];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, k) {
      // cover: ekranda boşluk kalmasın; taşan kenar kırpılır
      final ekranOrani = k.maxWidth / k.maxHeight;
      final double gw, gh;
      if (ekranOrani > _secili.oran) {
        gw = k.maxWidth;        // ekran daha geniş → eni doldur, dikeyde taşsın
        gh = gw / _secili.oran;
      } else {
        gh = k.maxHeight;       // ekran daha uzun → boyu doldur, yatayda taşsın
        gw = gh * _secili.oran;
      }
      final ox = (k.maxWidth - gw) / 2;
      final oy = (k.maxHeight - gh) / 2;

      return Stack(children: [
        Positioned(
          left: ox, top: oy, width: gw, height: gh,
          child: Image.asset(_secili.gorsel, fit: BoxFit.fill),
        ),
        Positioned(
          left:   ox + _secili.sol * gw,
          top:    oy + _secili.ust * gh,
          width:  _secili.gen * gw,
          height: _secili.yuk * gh,
          // ClipRect: oyun hiçbir koşulda ekranın dışına taşmasın
          child: ClipRect(child: widget.cocuk),
        ),
      ]);
    });
  }
}
