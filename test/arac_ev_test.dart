import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oyuncu_dukkani/main.dart';

/// 🚗 Galerici Gürbüz / araçlar ve 🏠 ev sistemi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SesServisi.sesAcik = false;
  });

  group('Araçlar', () {
    test('5 araç var, hepsinin id\'si ve görseli benzersiz', () {
      expect(Arac.tumu.length, 5);
      expect(Arac.tumu.map((a) => a.item.id).toSet().length, 5);
      expect(Arac.tumu.map((a) => a.item.gorsel).toSet().length, 5);
    });

    test('araçlar arac kategorisinde ve normal ürün havuzunda DEĞİL', () {
      for (final a in Arac.tumu) {
        expect(a.item.category, ItemCategory.arac);
      }
      final havuzIdleri = GameState.koleksiyonUrunleri.map((u) => u.id).toSet();
      for (final a in Arac.tumu) {
        expect(havuzIdleri.contains(a.item.id), isFalse,
            reason: '${a.item.id} normal ürün havuzuna sızmış');
      }
    });

    test('motosiklet otomobilden uzun sürüyor', () {
      final motor = Arac.tumu.firstWhere((a) => a.item.id == 'arac4'); // Vınn Motor
      final araba = Arac.tumu.firstWhere((a) => a.item.id == 'arac2'); // Amiral 500
      expect(motor.gecisSaniye, greaterThan(araba.gecisSaniye));
    });

    test('gecisSuresi araç olmayan id için null döner', () {
      expect(Arac.gecisSuresi('arac1'), isNotNull);
      expect(Arac.gecisSuresi('cd1'), isNull);
    });
  });

  group('Galerici Gürbüz', () {
    test('rotasyona girmez — özel müşteri sırasında yok', () {
      final s = GameState();
      final json = s.toJson();
      final sira = (json['ozelTipSirasi'] as List).cast<String>();
      expect(sira.contains(OzelMusteriTip.galerici.name), isFalse);
      expect(sira.contains(OzelMusteriTip.hande.name), isFalse);
      expect(sira.contains(OzelMusteriTip.toptanci.name), isFalse);
      expect(sira.contains(OzelMusteriTip.guvenlik.name), isFalse);
    });

    test('eski kayıttan rotasyona sızmışsa temizlenir', () {
      final s = GameState();
      final json = s.toJson();
      json['ozelTipSirasi'] = [
        OzelMusteriTip.hirsiz.name,
        OzelMusteriTip.galerici.name,
        OzelMusteriTip.hande.name,
      ];
      final s2 = GameState.fromJson(json);
      final sira = (s2.toJson()['ozelTipSirasi'] as List).cast<String>();
      expect(sira.contains(OzelMusteriTip.galerici.name), isFalse);
      expect(sira.contains(OzelMusteriTip.hande.name), isFalse);
    });

    test('araç seçilince özel müşteri normal SATICI müşteriye dönüşür', () {
      final s = GameState();
      s.aktifOzelMusteri = OzelMusteri.galerici();
      s.ozelMusteriGorunuyor = true;
      final arac = Arac.tumu.first.item;
      s.galericiAracSec(arac);

      expect(s.aktifOzelMusteri, isNull);
      expect(s.aktifMusteri, isNotNull);
      expect(s.aktifMusteri!.musteriSatiyor, isTrue);
      expect(s.aktifMusteri!.item.id, arac.id);
      expect(s.aktifPazarlik, isNotNull);
      expect(s.aktifPazarlik!.musteriSatiyor, isTrue);
    });
  });

  group('Ev', () {
    test('para yetmiyorsa ev alınamaz', () {
      final s = GameState()..para = 100;
      expect(s.mekanSatinAl(Konum.ev), isFalse);
      expect(s.evSahibi, isFalse);
      expect(s.para, 100);
    });

    test('ev alınınca para düşer, ikinci kez alınamaz', () {
      final s = GameState()..para = EvEsyasi.evFiyati + 500;
      expect(s.mekanSatinAl(Konum.ev), isTrue);
      expect(s.evSahibi, isTrue);
      expect(s.para, 500);
      expect(s.mekanSatinAl(Konum.ev), isFalse);
    });

    test('eşya alınınca para düşer, aynı eşya ikinci kez alınamaz', () {
      final e = EvEsyasi.tumu.first;
      final s = GameState()..para = e.fiyat + 50;
      expect(s.evEsyasiAl(e), isTrue);
      expect(s.evEsyalari.contains(e.id), isTrue);
      expect(s.para, 50);
      expect(s.evEsyasiAl(e), isFalse);
    });

    test('eşya konumları 0..1 aralığında, id ve görseller benzersiz', () {
      expect(EvEsyasi.tumu.map((e) => e.gorsel).toSet().length, EvEsyasi.tumu.length);
      expect(EvEsyasi.tumu.map((e) => e.id).toSet().length, EvEsyasi.tumu.length);
      for (final e in EvEsyasi.tumu) {
        expect(e.sol, inInclusiveRange(0.0, 1.0), reason: e.id);
        expect(e.ust, inInclusiveRange(0.0, 1.0), reason: e.id);
        expect(e.gen, inInclusiveRange(0.0, 1.0), reason: e.id);
        expect(e.sol + e.gen, lessThanOrEqualTo(1.0), reason: '${e.id} sağdan taşıyor');
        expect(e.fiyat, greaterThan(0), reason: e.id);
      }
    });

    test('ev ve eşyaları kayıt turunda korunur, konum hep dükkana döner', () {
      final s = GameState()..para = 99999;
      s.mekanSatinAl(Konum.ev);
      s.evEsyasiAl(EvEsyasi.tumu.first);
      s.konumaGec(Konum.ev);

      final s2 = GameState.fromJson(s.toJson());
      expect(s2.evSahibi, isTrue);
      expect(s2.evEsyalari.contains(EvEsyasi.tumu.first.id), isTrue);
      // Evde kapatılan oyun dükkanda açılır — yolculuk oturum içi bir durum.
      expect(s2.aktifKonum, Konum.dukkan);
    });
  });

  group('Yazlık', () {
    test('12 yazlık eşyası var, hepsi tam katman ve kırpılmış ikonu var', () {
      final y = EvEsyasi.konumun(Konum.yazlik);
      expect(y.length, 12);
      for (final e in y) {
        expect(e.tamKatman, isTrue, reason: e.id);
        expect(e.ikon, isNotNull, reason: '${e.id} tezgâhta görünmez');
        expect(e.onizleme, isNot(e.gorsel), reason: e.id);
      }
    });

    test('ev eşyaları tam katman DEĞİL, önizlemesi kendi görseli', () {
      final ev = EvEsyasi.konumun(Konum.ev);
      expect(ev.length, 9);
      for (final e in ev) {
        expect(e.tamKatman, isFalse, reason: e.id);
        expect(e.onizleme, e.gorsel, reason: e.id);
      }
    });

    test('yazlık ayrı satın alınır, ev sahipliğinden bağımsız', () {
      final s = GameState()..para = 99999;
      expect(s.konumSahibi(Konum.yazlik), isFalse);
      expect(s.mekanSatinAl(Konum.yazlik), isTrue);
      expect(s.yazlikSahibi, isTrue);
      expect(s.evSahibi, isFalse);
      expect(s.mekanSatinAl(Konum.yazlik), isFalse); // ikinci kez alınamaz
    });

    test('yazlık sahipliği kayıt turunda korunur', () {
      final s = GameState()..para = 99999;
      s.mekanSatinAl(Konum.yazlik);
      s.evEsyasiAl(EvEsyasi.konumun(Konum.yazlik).first);
      final s2 = GameState.fromJson(s.toJson());
      expect(s2.yazlikSahibi, isTrue);
      expect(s2.evEsyalari.contains(EvEsyasi.konumun(Konum.yazlik).first.id), isTrue);
    });

    test('her mekânın kendi arka planı ve oranı var', () {
      expect(Mekan.bul(Konum.ev).arkaplan, isNot(Mekan.bul(Konum.yazlik).arkaplan));
      expect(Mekan.bul(Konum.dukkan).arkaplan, Mekan.ev.arkaplan); // varsayılan ev
      expect(Mekan.ev.oran, greaterThan(0));
      expect(Mekan.yazlik.oran, greaterThan(0));
    });
  });

  group('Araç + koleksiyon', () {
    test('araç koleksiyona konamaz', () {
      final s = GameState();
      expect(s.koleksiyonaKonabilir(Arac.tumu.first.item), isFalse);
    });

    test('sıradan ürün koleksiyona konabilir', () {
      final s = GameState();
      final urun = GameState.koleksiyonUrunleri.first;
      expect(s.koleksiyonaKonabilir(urun), isTrue);
    });
  });

  group('Araç envanteri', () {
    test('araç yokken aracVar false, eklenince true', () {
      final s = GameState();
      expect(s.aracVar, isFalse);
      s.slotlar[0] = Arac.tumu.first.item;
      expect(s.aracVar, isTrue);
      expect(s.sahipAraclar.length, 1);
    });
  });
}
