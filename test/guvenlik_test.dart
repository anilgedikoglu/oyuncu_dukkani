import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oyuncu_dukkani/main.dart';

/// Yakışıklı Güvenlik + satılık dükkan sistemleri.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SesServisi.sesAcik = false;
  });

  group('güvenlik', () {
    test('arka plan güvenlik durumuna göre değişir', () {
      final s = GameState();
      expect(s.guvenlikVar, isFalse);
      expect(s.aktifArkaplan, s.aktifDukkan.arkaplan);
      s.guvenligiIseAl();
      expect(s.aktifArkaplan, s.aktifDukkan.arkaplanGuv);
      expect(s.aktifArkaplan, isNot(s.aktifDukkan.arkaplan));
    });

    test('her dükkanın güvenlikli ve güvenliksiz arka planı tanımlı', () {
      for (final d in butunDukkanlar) {
        expect(d.arkaplan.isNotEmpty, isTrue, reason: d.isim);
        expect(d.arkaplanGuv.isNotEmpty, isTrue, reason: d.isim);
        expect(d.arkaplan, isNot(d.arkaplanGuv), reason: d.isim);
      }
    });

    test('güvenlik varken HIRSIZ hiç gelmez', () {
      // Rotasyonu tur tur döndürüp yüzlerce müşteri çağır: bir kez bile
      // hırsız çıkmamalı.
      final s = GameState();
      s.guvenligiIseAl();
      for (int i = 0; i < 400; i++) {
        s.yeniMusteriGonder();
        expect(s.aktifOzelMusteri?.tip, isNot(OzelMusteriTip.hirsiz),
            reason: 'tur $i');
        s.musteriAnimasyonBitti();
      }
    });

    test('güvenlik YOKKEN hırsız gelebiliyor (test anlamlı olsun diye)', () {
      final s = GameState();
      var hirsizGeldi = false;
      for (int i = 0; i < 1200 && !hirsizGeldi; i++) {
        // ⚠️ Günlük müşteri limiti dolunca yeniMusteriGonder boş döner —
        // gün ilerletilmezse döngü havada dönüyor (içerik büyüdükçe
        // özel müşteri sırası da seyrekleşti, test boş kalıyordu).
        // ⚠️ Kasa beslenmezse birkaç gün sonra kira ödenemeyip İFLAS oluyor
        // ve müşteri akışı duruyordu — sabit-ad testiyle aynı tuzak.
        s.para = 100000;
        if (s.gunBitmeli) s.gunuBitir();
        s.yeniMusteriGonder();
        if (s.aktifOzelMusteri?.tip == OzelMusteriTip.hirsiz) hirsizGeldi = true;
        s.musteriAnimasyonBitti();
      }
      expect(hirsizGeldi, isTrue, reason: 'hırsız hiç gelmediyse üstteki test boş kalır');
    });

    test('güvenlik rotasyona sızmaz', () {
      final s = GameState();
      final json = s.toJson();
      final s2 = GameState.fromJson(json);
      // Kayıt turundan sonra da rotasyonda güvenlik/toptancı olmamalı
      for (int i = 0; i < 200; i++) {
        s2.yeniMusteriGonder();
        final t = s2.aktifOzelMusteri?.tip;
        if (t == OzelMusteriTip.guvenlik) {
          // Sadece 3'ün katlarındaki teklif olabilir
          expect(s2.gun % 3, 0);
        }
        s2.musteriAnimasyonBitti();
      }
    });

    test('ücret ödenemezse güvenlik işi bırakır', () {
      final s = GameState();
      s.guvenligiIseAl();
      s.para = 0; // kira bile ödenemez
      s.gunuBitir();
      expect(s.guvenlikVar, isFalse);
      expect(s.guvenlikIsiBirakti, isTrue);
    });

    test('ücret her gün kesilir', () {
      final s = GameState();
      s.guvenligiIseAl();
      s.para = 100000;
      final once = s.para;
      s.gunuBitir();
      // kira + güvenlik ücreti düşmüş olmalı
      expect(once - s.para, greaterThanOrEqualTo(GameState.guvenlikGunlukUcret));
      expect(s.guvenlikVar, isTrue);
    });

    test('kayıt turunu atlatır', () {
      final s = GameState();
      s.guvenligiIseAl();
      s.guvenlikSonTeklifGunu = 6;
      final s2 = GameState.fromJson(s.toJson());
      expect(s2.guvenlikVar, isTrue);
      expect(s2.guvenlikSonTeklifGunu, 6);
    });

    test('güvenlik öne gelince arka plan güvenliksiz sürüme döner', () {
      // Yoksa ekranda aynı anda iki güvenlik olur: tezgâhta konuşan +
      // arka planda hâlâ kapıda duran.
      final s = GameState();
      s.guvenligiIseAl();
      expect(s.aktifArkaplan, s.aktifDukkan.arkaplanGuv);

      s.guvenligiOneCagir();
      expect(s.aktifArkaplan, s.aktifDukkan.arkaplan,
          reason: 'öne gelmişken arka planda da durmamalı');
      expect(s.guvenlikVar, isTrue, reason: 'hâlâ çalışıyor, sadece öne geldi');

      // HAYIR denip gittiğinde kapıdaki yerine geri döner
      s.musteriAnimasyonBitti();
      expect(s.aktifArkaplan, s.aktifDukkan.arkaplanGuv);
    });

    test('istifa edince arka plan güvenliksiz kalır', () {
      final s = GameState();
      s.guvenligiIseAl();
      s.guvenligiOneCagir();
      s.guvenligiIstenCikar();          // EVET
      s.musteriAnimasyonBitti();
      expect(s.guvenlikVar, isFalse);
      expect(s.aktifArkaplan, s.aktifDukkan.arkaplan);
    });

    test('istifa sorusu ayrı bir moddur', () {
      final teklif = OzelMusteri.olustur(OzelMusteriTip.guvenlik);
      expect(teklif.istifaSorusu, isFalse);
      expect(teklif.ilkMesaj.contains('${GameState.guvenlikGunlukUcret} liraya'), isTrue);

      final istifa = OzelMusteri.guvenlikIstifa();
      expect(istifa.istifaSorusu, isTrue);
      expect(istifa.ilkMesaj, 'İşi bırakmamı ister misin?');
    });
  });

  group('satılık dükkanlar', () {
    test('beş dükkan, artan fiyat, hepsi 5. gün', () {
      expect(satilikDukkanlar.length, 5);
      final fiyatlar = satilikDukkanlar.map((d) => d.satinAlmaFiyati!).toList();
      expect(fiyatlar, [5000, 7000, 10000, 13000, 20000]);
      for (final d in satilikDukkanlar) {
        expect(d.minGun, 5, reason: d.isim);
        expect(d.kira, 0, reason: '${d.isim} satın alınınca kira olmamalı');
        expect(d.satilik, isTrue);
      }
      expect(satilikDukkanlar.map((d) => d.isim).toList(),
          ['Fakir Dükkan', 'Derme Çatma Dükkan', 'Lüks Dükkan', 'Klas Dükkan', 'Rezidans Dükkanı']);
    });

    test('kiralık dükkanlar satılık değil', () {
      for (final d in tumDukkanlar) {
        expect(d.satilik, isFalse, reason: d.isim);
        expect(d.kira, greaterThan(0), reason: d.isim);
      }
    });

    test('gün şartı ve para şartı uygulanır', () {
      final d = satilikDukkanlar.first;
      final erken = GameState()..para = 99999..gun = 4;
      expect(erken.dukkanSatinAl(d), isNotNull, reason: '5. günden önce alınabildi');

      final fakir = GameState()..para = 100..gun = 9;
      expect(fakir.dukkanSatinAl(d), isNotNull, reason: 'parasız alınabildi');

      final zengin = GameState()..para = 99999..gun = 9;
      expect(zengin.dukkanSatinAl(d), isNull);
      expect(zengin.dukkanSahibiMi(d), isTrue);
      expect(zengin.para, 99999 - d.satinAlmaFiyati!);
    });

    test('satın alınca otomatik taşınılmaz', () {
      final s = GameState()..para = 99999..gun = 9;
      final oncekiDukkan = s.aktifDukkan.isim;
      s.dukkanSatinAl(satilikDukkanlar.first);
      expect(s.aktifDukkan.isim, oncekiDukkan);
    });

    test('kiraya verme geliri gün sonunda eklenir', () {
      final s = GameState()..para = 99999..gun = 9;
      final d = satilikDukkanlar.last; // 20000 → 200/gün
      s.dukkanSatinAl(d);
      s.kirayaVerToggle(d);
      expect(s.gunlukKiraGeliri, GameState.kiraGeliriHesapla(d));
      expect(s.gunlukKiraGeliri, 200);

      final once = s.para;
      s.gunuBitir();
      // kira gideri + kira geliri birlikte işlendi; gelir eklenmiş olmalı
      expect(s.para, greaterThan(once - s.aktifDukkan.kira - 1));
    });

    test('oturulan dükkan kiraya verilemez', () {
      final s = GameState()..para = 99999..gun = 9;
      final d = satilikDukkanlar.first;
      s.dukkanSatinAl(d);
      s.dukkanDegistir(d);
      s.kirayaVerToggle(d);
      expect(s.kirayaVerilenDukkanlar.contains(d.isim), isFalse);
    });

    test('kiradaki dükkana taşınınca kira biter', () {
      final s = GameState()..para = 99999..gun = 9;
      final d = satilikDukkanlar.first;
      s.dukkanSatinAl(d);
      s.kirayaVerToggle(d);
      expect(s.kirayaVerilenDukkanlar.contains(d.isim), isTrue);
      s.dukkanDegistir(d);
      expect(s.kirayaVerilenDukkanlar.contains(d.isim), isFalse);
    });

    test('sahiplik ve kiralar kayıt turunu atlatır', () {
      final s = GameState()..para = 99999..gun = 9;
      s.dukkanSatinAl(satilikDukkanlar[0]);
      s.dukkanSatinAl(satilikDukkanlar[1]);
      s.kirayaVerToggle(satilikDukkanlar[1]);
      s.dukkanDegistir(satilikDukkanlar[0]);

      final s2 = GameState.fromJson(s.toJson());
      expect(s2.aktifDukkan.isim, 'Fakir Dükkan');
      expect(s2.sahipDukkanlar.length, 2);
      expect(s2.kirayaVerilenDukkanlar, {'Derme Çatma Dükkan'});
    });
  });

  group('rehber Hande', () {
    test('dört replik, hepsi dolu ve placeholder içermiyor', () {
      expect(OzelMusteri.handeReplikleri.length, 4);
      for (final r in OzelMusteri.handeReplikleri) {
        expect(r.trim().isNotEmpty, isTrue);
        expect(r.contains('{'), isFalse, reason: 'doldurulmamış placeholder: $r');
      }
      expect(OzelMusteri.handeReplikleri.first.contains('ben Hande'), isTrue);
    });

    test('replikler sırayla ilerler, sonuncudan sonra biter', () {
      final s = GameState();
      s.handeyiGonder();
      expect(s.handeAktif, isTrue);
      expect(s.handeAdim, 0);
      expect(s.mesaj, OzelMusteri.handeReplikleri[0]);

      for (int i = 1; i < OzelMusteri.handeReplikleri.length; i++) {
        expect(s.handeIlerle(), isTrue, reason: 'adım $i');
        expect(s.handeAdim, i);
        expect(s.mesaj, OzelMusteri.handeReplikleri[i]);
      }
      // Son replikten sonra "devam edecek bir şey yok"
      expect(s.handeIlerle(), isFalse);
    });

    test('alış/satış yapmaz: EVET/HAYIR beklenmiyor', () {
      final s = GameState();
      s.handeyiGonder();
      expect(s.musteriKabulBekliyor, isFalse);
      expect(s.aktifMusteri, isNull);
      expect(s.aktifPazarlik, isNull);
    });

    test('müşteri sayacını tüketmez', () {
      final s = GameState();
      final onceGunluk = s.gunlukMusteriSayisi;
      final onceToplam = s.musteriSayisi;
      s.handeyiGonder();
      expect(s.gunlukMusteriSayisi, onceGunluk);
      expect(s.musteriSayisi, onceToplam);
    });

    test('sadece bir kez gelir', () {
      final s = GameState();
      s.handeyiGonder();
      s.musteriAnimasyonBitti();
      expect(s.handeGosterildi, isTrue);
      s.handeyiGonder();
      expect(s.aktifOzelMusteri, isNull, reason: 'ikinci kez gelmemeli');
    });

    test('rotasyona sızmaz', () {
      final s = GameState();
      for (int i = 0; i < 300; i++) {
        s.yeniMusteriGonder();
        expect(s.aktifOzelMusteri?.tip, isNot(OzelMusteriTip.hande), reason: 'tur $i');
        s.musteriAnimasyonBitti();
      }
    });

    test('gösterildi bilgisi kayıtta saklanır; eski kayıtlar tanıtımı görmüş sayılır', () {
      final s = GameState();
      s.handeyiGonder();
      final s2 = GameState.fromJson(s.toJson());
      expect(s2.handeGosterildi, isTrue);

      // Alan hiç yoksa (eski kayıt) tanıtım tekrar açılmamalı
      final eski = Map<String, dynamic>.from(s.toJson())..remove('handeGosterildi');
      expect(GameState.fromJson(eski).handeGosterildi, isTrue);
    });
  });

  group('sabit adlı karakterler', () {
    test('ad alanı olanlar rastgele isim almaz', () {
      final sabitler = GameState.musteriHavuzu.where((m) => m['ad'] != null).toList();
      expect(sabitler.length, greaterThanOrEqualTo(3));
      final adlar = sabitler.map((m) => m['ad']!).toSet();
      expect(adlar.containsAll({'Recai Carlos', 'Kahraman Memo', 'Şakir Oneyıl'}), isTrue);
    });

    test('sabit adlı karakter geldiğinde hep aynı adı taşır', () {
      final s = GameState();
      final hedef = GameState.musteriHavuzu.firstWhere((m) => m['ad'] == 'Kahraman Memo');
      final gorsel = hedef['gorsel'];
      var goruldu = 0;
      // ⚠️ Kadro büyüdükçe (v122: 65 karakter) belirli birinin gelme olasılığı
      // düşüyor; 800 denemede bazen hiç çıkmıyor, 4000'de ise tüm suite ile
      // birlikte koşarken zaman aşımına uğruyordu. 1500 + açık timeout dengeli.
      for (int i = 0; i < 1500 && goruldu < 1; i++) {
        // ⚠️ Kasa beslenmezse birkaç gün sonra kira ödenemeyip İFLAS oluyor ve
        // müşteri akışı duruyordu — testin asıl kararsızlık sebebi buydu.
        s.para = 100000;
        if (s.gunBitmeli) s.gunuBitir(); // limit dolunca gün ilerlet
        s.yeniMusteriGonder();
        final m = s.aktifMusteri;
        if (m != null && m.gorsel == gorsel) {
          expect(m.name, 'Kahraman Memo');
          goruldu++;
        }
        s.musteriAnimasyonBitti();
      }
      expect(goruldu, greaterThan(0), reason: 'karakter hiç gelmedi, test boş kaldı');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
