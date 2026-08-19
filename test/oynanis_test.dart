import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oyuncu_dukkani/main.dart';

/// v105 oynanış değişikliklerinin regresyon testleri.

GameItem _urun({bool curuk = false, double? oran}) => GameItem(
      id: 'cd1', name: 'KARMAGEDDON', gorsel: 'assets/CD_1.png',
      category: ItemCategory.cd, basePrice: 200, kondisyon: 4,
      curuk: curuk, curukOran: oran,
    );

void main() {
  // GameState.notifyListeners -> KayitServisi.kaydet -> SharedPreferences.
  // Binding ve sahte depo olmadan test ortamında patlıyor.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('polis alkol testi', () {
    test('şıklar geçerli: biri doğru, biri yanlış, ikisi de pozitif', () {
      var testliSayisi = 0;
      for (var i = 0; i < 400; i++) {
        final om = OzelMusteri.olustur(OzelMusteriTip.polis);
        if (!om.alkolTesti) continue;
        testliSayisi++;
        expect(om.sikSol, isNotNull);
        expect(om.sikSag, isNotNull);
        expect(om.sikSol, isNot(om.sikSag), reason: 'iki şık aynı olamaz');
        expect(om.sikSol! > 0 && om.sikSag! > 0, isTrue, reason: 'şıklar pozitif olmalı');
        // Doğru cevap şıklardan biri olmalı
        expect(om.dogruCevap == om.sikSol || om.dogruCevap == om.sikSag, isTrue);
        expect(om.ilkMesaj.contains('kaç eder?'), isTrue, reason: om.ilkMesaj);
      }
      expect(testliSayisi, greaterThan(0), reason: 'hiç alkol testi üretilmedi');
    });

    test('doğru cevap bazen solda bazen sağda', () {
      var solda = 0, sagda = 0;
      for (var i = 0; i < 600; i++) {
        final om = OzelMusteri.olustur(OzelMusteriTip.polis);
        if (!om.alkolTesti) continue;
        if (om.dogruCevap == om.sikSol) {
          solda++;
        } else {
          sagda++;
        }
      }
      expect(solda, greaterThan(0));
      expect(sagda, greaterThan(0));
    });

    test('normal polis (ceza) hâlâ üretiliyor', () {
      final cezali = List.generate(400, (_) => OzelMusteri.olustur(OzelMusteriTip.polis))
          .where((o) => !o.alkolTesti).toList();
      expect(cezali, isNotEmpty);
      for (final o in cezali.take(20)) {
        expect(o.ilkMiktar, inInclusiveRange(30, 250));
      }
    });
  });

  group('hasarlı ürün fiyatı', () {
    test('ürüne özel çürük oranı etkinFiyatı belirler', () {
      expect(_urun().etkinFiyat, 200);
      // Varsayılan çürük (toptancı/kutu): %35
      expect(_urun(curuk: true).etkinFiyat, (200 * 0.35).round());
      // Müşterinin getirdiği hasarlı mal: %50-75 → daha değerli
      expect(_urun(curuk: true, oran: 0.5).etkinFiyat, 100);
      expect(_urun(curuk: true, oran: 0.75).etkinFiyat, 150);
    });

    test('müşteri hasarlısı toptancı hurdasından pahalı', () {
      final hurda = _urun(curuk: true).etkinFiyat;
      final musteriMali = _urun(curuk: true, oran: 0.5).etkinFiyat;
      expect(musteriMali, greaterThan(hurda));
    });

    test('curukOran kayıt/yükleme turunu atlatıyor', () {
      final u = _urun(curuk: true, oran: 0.63);
      final geri = GameItem.fromJson(u.toJson());
      expect(geri.curuk, isTrue);
      expect(geri.curukOran, closeTo(0.63, 0.0001));
      expect(geri.etkinFiyat, u.etkinFiyat);
    });
  });

  group('yemeği ye', () {
    test('envanterdeki tüm hasarlı ürünler onarılır ve fiyatları artar', () {
      final s = GameState();
      s.slotlar[0] = _urun(curuk: true, oran: 0.5);
      s.slotlar[1] = _urun(curuk: true, oran: 0.6);
      s.slotlar[2] = _urun(); // sağlam
      final oncekiFiyat = s.slotlar[0]!.etkinFiyat;
      s.yemekVar = true;

      final onarilan = s.yemegiYe();

      expect(onarilan, 2);
      expect(s.yemekVar, isFalse);
      for (var i = 0; i < 3; i++) {
        expect(s.slotlar[i]!.curuk, isFalse);
      }
      // Onarılınca piyasa değeri tam fiyata döner
      expect(s.slotlar[0]!.etkinFiyat, 200);
      expect(s.slotlar[0]!.etkinFiyat, greaterThan(oncekiFiyat));
    });

    test('hasarlı ürün yoksa 0 döner ve çökmez', () {
      final s = GameState();
      s.yemekVar = true;
      expect(s.yemegiYe(), 0);
      expect(s.yemekVar, isFalse);
    });
  });

  test('yemekVar kayıtta saklanıyor', () {
    final s = GameState();
    s.yemekVar = true;
    expect(GameState.fromJson(s.toJson()).yemekVar, isTrue);
    s.yemekVar = false;
    expect(GameState.fromJson(s.toJson()).yemekVar, isFalse);
  });
}
