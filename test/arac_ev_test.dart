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
    test('11 araç var, hepsinin id\'si ve görseli benzersiz', () {
      expect(Arac.tumu.length, 11);
      expect(Arac.tumu.map((a) => a.item.id).toSet().length, 11);
      expect(Arac.tumu.map((a) => a.item.gorsel).toSet().length, 11);
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
      final s = GameState()..para = Mekan.ev.fiyat + 500;
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
      for (final m in Mekan.satinAlinabilir) {
        expect(m.oran, greaterThan(0), reason: m.ad);
        expect(m.fiyat, greaterThan(0), reason: m.ad);
      }
      expect(Mekan.satinAlinabilir.map((m) => m.arkaplan).toSet().length,
          Mekan.satinAlinabilir.length);
    });
  });

  group('Dağ Evi', () {
    test('7 dağ evi eşyası var, hepsi tam katman ve ikonlu', () {
      final d = EvEsyasi.konumun(Konum.dagevi);
      expect(d.length, 7);
      for (final e in d) {
        expect(e.tamKatman, isTrue, reason: e.id);
        expect(e.ikon, isNotNull, reason: e.id);
        expect(e.id, startsWith('d_'), reason: e.id);
      }
    });

    test('dağ evi ayrı satın alınır ve kayıtta korunur', () {
      final s = GameState()..para = 99999;
      expect(s.konumSahibi(Konum.dagevi), isFalse);
      expect(s.mekanSatinAl(Konum.dagevi), isTrue);
      expect(s.mekanSatinAl(Konum.dagevi), isFalse);
      expect(s.evSahibi, isFalse);
      s.evEsyasiAl(EvEsyasi.konumun(Konum.dagevi).first);
      final s2 = GameState.fromJson(s.toJson());
      expect(s2.konumSahibi(Konum.dagevi), isTrue);
      expect(s2.evEsyalari.contains('d_somine'), isTrue);
    });

    test('v118 ara kayıt migrasyonu: evSahibi/yazlikSahibi boolları okunur', () {
      final s = GameState();
      final json = s.toJson();
      json.remove('sahipMekanlar');
      json['evSahibi'] = true;
      json['yazlikSahibi'] = true;
      final s2 = GameState.fromJson(json);
      expect(s2.evSahibi, isTrue);
      expect(s2.yazlikSahibi, isTrue);
      expect(s2.konumSahibi(Konum.dagevi), isFalse);
    });
  });

  group('Toptancı stok', () {
    test('tezgâhta aynı üründen iki kopya yok', () {
      for (int i = 0; i < 25; i++) {
        final s = GameState();
        s.toptanciStokKontrol();
        final idler = s.toptanciStok
            .where((t) => t.item != null && !t.item!.kapaliKutu)
            .map((t) => t.item!.id)
            .toList();
        expect(idler.toSet().length, idler.length,
            reason: 'tekrar var: $idler');
      }
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

  group('Araç sahipliği', () {
    test('araç yokken aracVar false, sahiplik listesine girince true', () {
      final s = GameState();
      expect(s.aracVar, isFalse);
      s.sahipAracIdleri.add(Arac.tumu.first.item.id);
      expect(s.aracVar, isTrue);
      expect(s.sahipAraclar.length, 1);
    });

    test('v118/119 kaydındaki slottaki araç sahiplik listesine taşınır', () {
      final s = GameState();
      s.slotlar[0] = Arac.tumu.first.item;
      final s2 = GameState.fromJson(s.toJson());
      expect(s2.aracSahibi(Arac.tumu.first.item.id), isTrue);
      // Slotta araç kalmamalı — envanter yalnızca CD/ekipman içindir.
      expect(s2.slotlar.whereType<GameItem>()
          .any((u) => u.category == ItemCategory.arac), isFalse);
    });

    test('araç satışı: alıcı kurulur, anlaşınca sahiplikten düşer', () {
      final s = GameState()..para = 1000;
      final a = Arac.tumu.first;
      s.sahipAracIdleri.add(a.item.id);
      s.aracSatisiBaslat(a);
      expect(s.aktifMusteri, isNotNull);
      expect(s.aktifMusteri!.musteriSatiyor, isFalse);
      expect(s.satistakiAracId, a.item.id);
      // Müşteri gitti (anlaşmasız) → araç sahipte kalır, bayrak temizlenir.
      s.musteriAnimasyonBitti();
      expect(s.satistakiAracId, isNull);
      expect(s.aracSahibi(a.item.id), isTrue);
    });

    test('mekân değeri eşyayla artar', () {
      final s = GameState()..para = 99999;
      s.mekanSatinAl(Konum.ev);
      final taban = s.mekanDegeri(Konum.ev);
      final esya = EvEsyasi.konumun(Konum.ev).first;
      s.evEsyasiAl(esya);
      expect(s.mekanDegeri(Konum.ev), taban + esya.fiyat);
    });
  });

  group('Yeni özel müşteriler', () {
    test('Deli Bekir 30 replik, Yakup 100 soru, hepsi benzersiz', () {
      expect(DeliBekirRepligi.tumu.length, 30);
      expect(DeliBekirRepligi.tumu.map((r) => r.gelis).toSet().length, 30);
      expect(DeliBekirRepligi.tumu.map((r) => r.evet).toSet().length, 30);
      expect(DeliBekirRepligi.tumu.map((r) => r.hayir).toSet().length, 30);
      expect(YakupSoru.tumu.length, greaterThanOrEqualTo(100));
      expect(YakupSoru.tumu.map((s0) => s0.soru).toSet().length, YakupSoru.tumu.length);
      for (final s0 in YakupSoru.tumu) {
        expect(s0.dogru, isNot(s0.yanlis), reason: s0.soru);
      }
    });

    test('rotasyon: Deli Bekir girer, diğer yeni tipler girmez', () {
      final s = GameState();
      final sira = (s.toJson()['ozelTipSirasi'] as List).cast<String>();
      expect(sira.contains(OzelMusteriTip.delibekir.name), isTrue);
      for (final t in [OzelMusteriTip.sezercik, OzelMusteriTip.seyma,
                       OzelMusteriTip.palyaco, OzelMusteriTip.buyucu]) {
        expect(sira.contains(t.name), isFalse, reason: t.name);
      }
    });

    test('Sezercik cevabı Şeyma\'nın gününü kurar (en az 1 tam gün ara)', () {
      final s = GameState()..para = 1000;
      s.aktifOzelMusteri = OzelMusteri.sezercik(200);
      s.sezercikCevapla(true);
      expect(s.sezercikDurumu, 1);
      expect(s.para, 800);
      expect(s.seymaGunu, isNotNull);
      expect(s.seymaGunu! - s.gun, greaterThanOrEqualTo(2));
    });

    test('Yakup yanlış cevapta para keser, doğruda kesmez', () {
      final s = GameState()..para = 5000;
      s.aktifOzelMusteri = OzelMusteri.buyucu();
      final om = s.aktifOzelMusteri!;
      // Doğru şık hangi taraftaysa onu seç.
      expect(s.yakupCevapla(om.dogruA!), isTrue);
      expect(s.para, 5000);
      s.aktifOzelMusteri = OzelMusteri.buyucu();
      final om2 = s.aktifOzelMusteri!;
      expect(s.yakupCevapla(!om2.dogruA!), isFalse);
      expect(s.para, lessThan(5000));
    });

    test('Şeyma ödülü: bakiyenin 2 katı para ya da sahip olunmayan araç', () {
      final s = GameState()..para = 1000;
      for (int i = 0; i < 20; i++) {
        final (tip, aracId, tutar) = s.seymaOdulSec();
        if (tip == 'para') {
          expect(tutar, s.para * 2);
        } else {
          expect(s.aracSahibi(aracId), isFalse);
        }
      }
    });

    test('sezercik selamları placeholder içermez', () {
      final om = OzelMusteri.sezercik(250);
      expect(om.ilkMesaj.contains('{X}'), isFalse);
      expect(om.ilkMesaj.contains('250'), isTrue);
    });
  });
}
