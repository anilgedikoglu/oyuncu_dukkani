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
    test('28 araç var, hepsinin id\'si ve görseli benzersiz', () {
      expect(Arac.tumu.length, 28);
      expect(Arac.tumu.map((a) => a.item.id).toSet().length, 28);
      expect(Arac.tumu.map((a) => a.item.gorsel).toSet().length, 28);
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

    test('gün kilitleri fiyatla orantılı ve en ucuzu 1. günde açık', () {
      // ⚠️ En ucuz araç 1. günde AÇIK olmalı: mekâna gitmek araç istiyor,
      // hiçbir araç açık değilse konum sistemi kilitlenirdi.
      final enUcuz = Arac.tumu.reduce(
          (a, b) => a.item.basePrice <= b.item.basePrice ? a : b);
      expect(enUcuz.minGun, 1);
      // Pahalı araç ucuzdan önce açılmamalı.
      for (final a in Arac.tumu) {
        for (final b in Arac.tumu) {
          if (a.item.basePrice < b.item.basePrice) {
            expect(a.minGun, lessThanOrEqualTo(b.minGun),
                reason: '${a.item.name} (${a.item.basePrice}) '
                    '${b.item.name}\'den (${b.item.basePrice}) sonra açılıyor');
          }
        }
      }
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

  group('Araç sıralaması', () {
    test('vitrin sırası: mikro → … → özel, her grupta fiyat artan', () {
      final s = Arac.sirali;
      expect(s.length, Arac.tumu.length);
      for (int i = 1; i < s.length; i++) {
        final once = s[i - 1], sonra = s[i];
        expect(once.tip.index <= sonra.tip.index, isTrue,
            reason: '${once.item.id} → ${sonra.item.id} tip sırası bozuk');
        if (once.tip == sonra.tip) {
          expect(once.item.basePrice <= sonra.item.basePrice, isTrue,
              reason: '${once.item.id} → ${sonra.item.id} fiyat sırası bozuk');
        }
      }
      expect(s.first.tip, AracTip.mikro);
      expect(s.last.tip, AracTip.ozel);
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

    test('mekân değeri liste fiyatı kadar', () {
      final s = GameState()..para = 999999;
      s.mekanSatinAl(Konum.mutevaziev);
      expect(s.mekanDegeri(Konum.mutevaziev), Mekan.mutevaziev.fiyat);
    });
  });

  group('Mekânlar (v121)', () {
    test('6 mekân var; id, ad, görsel benzersiz ve fiyat/gün artan', () {
      final ms = Mekan.satinAlinabilir;
      expect(ms.length, 6);
      expect(ms.map((m) => m.konum).toSet().length, 6);
      expect(ms.map((m) => m.ad).toSet().length, 6);
      expect(ms.map((m) => m.arkaplan).toSet().length, 6);
      for (int i = 1; i < ms.length; i++) {
        expect(ms[i].fiyat, greaterThan(ms[i - 1].fiyat),
            reason: '${ms[i].ad} fiyatı sıralı değil');
        expect(ms[i].minGun, greaterThanOrEqualTo(ms[i - 1].minGun),
            reason: '${ms[i].ad} gün kilidi sıralı değil');
        expect(ms[i].konukCarpani, greaterThanOrEqualTo(ms[i - 1].konukCarpani),
            reason: '${ms[i].ad} konuk çarpanı sıralı değil');
      }
    });

    test('eski "ev" kaydı mütevazı eve taşınır', () {
      final s = GameState()..para = 999999;
      final json = s.toJson();
      json['sahipMekanlar'] = ['ev'];
      final s2 = GameState.fromJson(json);
      expect(s2.konumSahibi(Konum.mutevaziev), isTrue);
      expect(s2.sahipMekanlar.contains('ev'), isFalse);
    });

    test('mekân alınca sahiplik ve kayıt turu çalışır', () {
      final s = GameState()..para = 999999;
      expect(s.mekanSatinAl(Konum.tekne), isTrue);
      expect(s.mekanSatinAl(Konum.tekne), isFalse); // iki kez alınmaz
      expect(s.mekanSayisi, 1);
      final s2 = GameState.fromJson(s.toJson());
      expect(s2.konumSahibi(Konum.tekne), isTrue);
      expect(s2.aktifKonum, Konum.dukkan); // kayıt hep dükkanda açılır
    });
  });

  group('📱 Telefon', () {
    test('para yetmiyorsa alınamaz, alınınca kayıtta kalır', () {
      final s = GameState()..para = 100;
      expect(s.telefonSatinAl(), isFalse);
      s.para = GameState.telefonFiyati + 50;
      expect(s.telefonSatinAl(), isTrue);
      expect(s.para, 50);
      expect(s.telefonSatinAl(), isFalse);
      expect(GameState.fromJson(s.toJson()).telefonVar, isTrue);
    });

    test('bilgisayar popup bayrağı kayıtta saklanır (tekrar çıkmasın)', () {
      final s = GameState();
      expect(s.bilgisayarPopupGosterildi, isFalse);
      s.bilgisayarPopupGosterildi = true;
      expect(GameState.fromJson(s.toJson()).bilgisayarPopupGosterildi, isTrue);
    });
  });

  group('📞 Çağrı dengesi', () {
    test('günlük çağrı hakkı sınırlı ve gün sonunda yenilenir', () {
      final s = GameState()..para = 999999;
      s.mekanSatinAl(Konum.mutevaziev);
      s.konumaGec(Konum.mutevaziev);
      expect(s.kalanCagriHakki, GameState.gunlukCagriHakki);
      for (int i = 0; i < GameState.gunlukCagriHakki; i++) {
        expect(s.cagriYapilabilir, isTrue, reason: 'çağrı ');
        s.misafirCagir(RehberKisi.hande);
        // Ziyareti bitir ki bir sonrakine geçebilelim.
        var t = 0;
        while (!s.misafirCevapla(true) && t < 10) { t++; }
      }
      expect(s.cagriYapilabilir, isFalse);
      // Hak bitince çağrı hiç kurulmuyor.
      s.misafirCagir(RehberKisi.seyma);
      expect(s.aktifZiyaret, isNull);
    });

    test('çağrı sayacı kayıtta saklanır', () {
      final s = GameState()..para = 999999;
      s.mekanSatinAl(Konum.mutevaziev);
      s.konumaGec(Konum.mutevaziev);
      s.misafirCagir(RehberKisi.hande);
      expect(GameState.fromJson(s.toJson()).bugunYapilanCagri, 1);
    });
  });

  group('📞 Telefon rehberi', () {
    test('12 kişi var, her birinin adı/görseli/ipucu dolu', () {
      expect(RehberKisi.values.length, 12);
      for (final k in RehberKisi.values) {
        expect(RehberSenaryo.ad(k), isNotEmpty);
        expect(RehberSenaryo.gorsel(k), startsWith('assets/'));
        expect(RehberSenaryo.ipucu(k), isNotEmpty);
      }
    });

    test('her kişinin her mekânda en az 4 senaryosu var', () {
      for (final k in RehberKisi.values) {
        for (final m in Mekan.satinAlinabilir) {
          final s = RehberSenaryo.senaryolar(k, m.konum);
          expect(s.length, greaterThanOrEqualTo(4),
              reason: '${RehberSenaryo.ad(k)} / ${m.ad}: ${s.length} senaryo');
          for (final z in s) {
            expect(z.adimlar, isNotEmpty);
            // Her senaryo bir etkiyle ya da hayır dalıyla kapanmalı —
            // yoksa oyuncu diyalogun sonunda boşlukta kalır.
            final sonAdim = z.adimlar.last;
            expect(sonAdim.etki != null || sonAdim.secimli, isTrue,
                reason: '${RehberSenaryo.ad(k)} / ${m.ad}: senaryo kapanmıyor');
          }
        }
      }
    });

    test('senaryo metinlerinde mekân adı geçiyor (mekâna özel)', () {
      for (final k in RehberKisi.values) {
        final tekne = RehberSenaryo.senaryolar(k, Konum.tekne);
        final tumMetin = tekne.expand((z) => z.adimlar).map((a) => a.metin).join(' ');
        expect(tumMetin.contains('Tekne'), isTrue,
            reason: '${RehberSenaryo.ad(k)} teknede mekân adını anmıyor');
      }
    });

    test('ziyaret akışı: adımlar ilerler, etki uygulanır, biter', () {
      final s = GameState()..para = 5000;
      s.mekanSatinAl(Konum.tekne);
      s.konumaGec(Konum.tekne);
      s.misafirCagir(RehberKisi.hande);
      expect(s.aktifOzelMusteri, isNotNull);
      expect(s.misafirAdimi, isNotNull);
      // Hep "evet" diyerek sonuna kadar götür.
      var tur = 0;
      while (!s.misafirCevapla(true) && tur < 10) { tur++; }
      expect(s.aktifZiyaret, isNull, reason: 'ziyaret kapanmadı');
      expect(s.mesaj, isNotEmpty);
    });

    test('hayır dalı ziyareti anında bitirir', () {
      final s = GameState()..para = 5000;
      s.mekanSatinAl(Konum.yazlik);
      s.konumaGec(Konum.yazlik);
      s.misafirCagir(RehberKisi.sezercik);
      // Seçimli adıma gelene kadar evet de, sonra hayır.
      var tur = 0;
      while (s.misafirAdimi != null && !s.misafirAdimi!.secimli && tur < 10) {
        s.misafirCevapla(true); tur++;
      }
      if (s.misafirAdimi != null) {
        expect(s.misafirCevapla(false), isTrue);
        expect(s.aktifZiyaret, isNull);
      }
    });

    test('lüks mekân konuğu daha cömert (konukCarpani ölçekliyor)', () {
      int kazanc(Konum k) {
        final s = GameState()..para = 999999;
        s.mekanSatinAl(k);
        s.konumaGec(k);
        final onceki = s.para;
        // Para kazancı olan sabit bir senaryo: Şeyma'nın ilk senaryosu.
        final z = RehberSenaryo.senaryolar(RehberKisi.seyma, k).first;
        s.aktifZiyaret = z;
        s.ziyaretAdim = 0;
        var tur = 0;
        while (!s.misafirCevapla(true) && tur < 10) { tur++; }
        return s.para - onceki;
      }
      expect(kazanc(Konum.tekne), greaterThan(kazanc(Konum.mutevaziev)));
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
