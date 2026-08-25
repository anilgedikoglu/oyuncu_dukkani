import 'package:flutter_test/flutter_test.dart';
import 'package:oyuncu_dukkani/main.dart';

/// Pazarlık motoru regresyon testleri.
///
/// 🐛 ASIL SEBEP (v112'de düzeltildi): müşterinin teklifi kendi rezervasyon
/// sınırına dayandığında `oyuncuTeklifVer` içindeki `clamp` çağrısının alt
/// sınırı üst sınırını geçiyordu (`musteriTeklif - 1 < reservationPrice.ceil()`).
/// Dart bu durumda ArgumentError ATAR; istisna `teklifVer`den yukarı kaçıyor,
/// pazarlık dialogu `finally` sayesinde kapanıyor ama ne `mesaj` ne
/// `musteriTeklif` güncelleniyordu. Oyuncu "Teklif Ver"e basıp duruyor, hiçbir
/// şey değişmiyordu — ta ki teklifi müşterininkini geçene kadar.
///
/// Aşağıdaki testler o dar bandı bilerek hedefler.

void main() {
  MusteriOzellik ozellik({int sabir = 5, int titizlik = 3, int zeka = 3}) =>
      MusteriOzellik(sabir: sabir, titizlik: titizlik, zeka: zeka);

  group('rezervasyon sınırına dayanmış pazarlık patlamaz', () {
    test('SATICI müşteri: musteriTeklif tam rezervasyonun 1 üstünde', () {
      // reservationPrice 100.4 → ceil 101. musteriTeklif 101 iken
      // clamp(101, 100) eskiden ArgumentError atıyordu.
      for (int i = 0; i < 200; i++) {
        final p = PazarlikSeans(
          musteriSatiyor: true,
          piyasaFiyati: 150,
          musteriTeklif: 101,
          oyuncuTeklif: 60,
          maxTur: 9,
          ozellik: ozellik(),
          reservationPrice: 100.4,
        );
        // Oyuncu rezervasyonun ALTINDA kalan bir teklif veriyor →
        // erken kabul dallarına düşmüyor, tam sorunlu koda giriyor.
        expect(() => p.oyuncuTeklifVer(70), returnsNormally);
      }
    });

    test('ALICI müşteri: musteriTeklif tam rezervasyonun 1 altında', () {
      for (int i = 0; i < 200; i++) {
        final p = PazarlikSeans(
          musteriSatiyor: false,
          piyasaFiyati: 150,
          musteriTeklif: 100,
          oyuncuTeklif: 240,
          maxTur: 9,
          ozellik: ozellik(),
          reservationPrice: 100.6, // floor 100 → clamp(101, 100) patlardı
        );
        expect(() => p.oyuncuTeklifVer(230), returnsNormally);
      }
    });

    test('musteriTeklif rezervasyonun tam üstündeyken de patlamaz', () {
      for (final rp in [100.0, 100.5, 99.9]) {
        final p = PazarlikSeans(
          musteriSatiyor: true,
          piyasaFiyati: 150,
          musteriTeklif: 100,
          oyuncuTeklif: 50,
          maxTur: 9,
          ozellik: ozellik(),
          reservationPrice: rp,
        );
        expect(() => p.oyuncuTeklifVer(60), returnsNormally, reason: 'rp=$rp');
      }
    });
  });

  test('uzun pazarlık boyunca hiçbir tur istisna atmaz', () {
    // Oyuncu gıdım gıdım yaklaşıyor: müşteri teklifi rezervasyona dayanana
    // kadar iner ve orada sıkışır — hatanın gerçek oyundaki senaryosu.
    for (int seed = 0; seed < 60; seed++) {
      final p = PazarlikSeans(
        musteriSatiyor: true,
        piyasaFiyati: 200,
        musteriTeklif: 260,
        oyuncuTeklif: 80,
        maxTur: 9,
        ozellik: ozellik(sabir: 5),
        reservationPrice: 150.0,
      );
      var teklif = 80;
      for (int tur = 0; tur < 9; tur++) {
        if (p.durum != PazarlikDurum.devamEdiyor) break;
        teklif += 5;
        expect(() => p.oyuncuTeklifVer(teklif), returnsNormally,
            reason: 'seed=$seed tur=$tur teklif=$teklif');
      }
    }
  });

  test('devam eden her turda mesaj dolu ve müşteri teklifi geçerli kalır', () {
    // "Ne yazı değişiyor ne yeni fiyat geliyor" şikayetinin doğrudan karşılığı:
    // durum devamEdiyor ise oyuncuya gösterilecek bir replik ÜRETİLMİŞ olmalı.
    for (int seed = 0; seed < 120; seed++) {
      final p = PazarlikSeans(
        musteriSatiyor: true,
        piyasaFiyati: 200,
        musteriTeklif: 260,
        oyuncuTeklif: 100,
        maxTur: 9,
        ozellik: ozellik(sabir: 5),
        reservationPrice: 150.0,
      );
      var teklif = 100;
      for (int tur = 0; tur < 9; tur++) {
        if (p.durum != PazarlikDurum.devamEdiyor) break;
        teklif += 4;
        p.oyuncuTeklifVer(teklif);
        if (p.durum == PazarlikDurum.devamEdiyor) {
          expect(p.mesaj.isNotEmpty, isTrue,
              reason: 'seed=$seed tur=$tur — boş replik');
          expect(p.mesaj.contains('{'), isFalse,
              reason: 'doldurulmamış placeholder: ${p.mesaj}');
          // Satıcı müşteri asla kendi tabanının altına inmez
          expect(p.musteriTeklif, greaterThanOrEqualTo(150),
              reason: 'seed=$seed tur=$tur');
        }
      }
    }
  });

  test('alıcı müşteri kendi tavanının üstüne çıkmaz', () {
    for (int seed = 0; seed < 120; seed++) {
      final p = PazarlikSeans(
        musteriSatiyor: false,
        piyasaFiyati: 200,
        musteriTeklif: 120,
        oyuncuTeklif: 320,
        maxTur: 9,
        ozellik: ozellik(sabir: 5),
        reservationPrice: 240.0,
      );
      var teklif = 320;
      for (int tur = 0; tur < 9; tur++) {
        if (p.durum != PazarlikDurum.devamEdiyor) break;
        teklif -= 6;
        p.oyuncuTeklifVer(teklif);
        if (p.durum == PazarlikDurum.devamEdiyor) {
          expect(p.mesaj.isNotEmpty, isTrue, reason: 'seed=$seed tur=$tur');
          expect(p.musteriTeklif, lessThanOrEqualTo(240),
              reason: 'seed=$seed tur=$tur');
        }
      }
    }
  });
}
