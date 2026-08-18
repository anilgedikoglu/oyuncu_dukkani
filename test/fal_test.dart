import 'package:flutter_test/flutter_test.dart';
import 'package:oyuncu_dukkani/main.dart';

/// Falcı Faloya — fal havuzu ve etkilerinin regresyon testi.
///
/// Buradaki asıl amaç: bir falın etkisi oyunu bozmasın. Özellikle para kaybı
/// oyuncuyu eksiye düşürmemeli ve dükkan büyütme son seviyede patlamamalı.

void main() {
  test('havuzda 50 fal var ve hepsi benzersiz', () {
    expect(Fal.havuz.length, 50);
    expect(Fal.havuz.map((f) => f.metin).toSet().length, 50);
  });

  test('fal metinlerinde doldurulmamış placeholder kalmıyor', () {
    for (final f in Fal.havuz) {
      expect(f.metniDoldur(123).contains('{'), isFalse, reason: f.metin);
    }
  });

  test('metinler 2-3 cümlelik ve makul uzunlukta', () {
    for (final f in Fal.havuz) {
      final cumle = f.metin.split(RegExp(r'[.!?]')).where((s) => s.trim().isNotEmpty).length;
      expect(cumle, greaterThanOrEqualTo(2), reason: 'çok kısa: ${f.metin}');
      expect(cumle, lessThanOrEqualTo(4), reason: 'çok uzun: ${f.metin}');
    }
  });

  test('para etkili fallarda aralık tanımlı ve tutarlı', () {
    for (final f in Fal.havuz) {
      if (f.etki == FalEtki.paraKazanc || f.etki == FalEtki.paraKayip) {
        expect(f.min, greaterThan(0), reason: f.metin);
        expect(f.max, greaterThanOrEqualTo(f.min), reason: f.metin);
      }
    }
  });

  test('her etki türü havuzda en az bir kez geçiyor', () {
    final kullanilan = Fal.havuz.map((f) => f.etki).toSet();
    for (final e in FalEtki.values) {
      expect(kullanilan.contains(e), isTrue, reason: '$e hiç kullanılmamış');
    }
  });

  test('para kaybı oyuncuyu eksiye düşürmez', () {
    final kayiplar = Fal.havuz.where((f) => f.etki == FalEtki.paraKayip);
    for (final f in kayiplar) {
      for (final baslangic in [0, 1, 50, 100000]) {
        final s = GameState();
        s.para = baslangic;
        s.falUygula(f);
        expect(s.para, greaterThanOrEqualTo(0), reason: '${f.metin} / baslangic=$baslangic');
        expect(s.para, lessThanOrEqualTo(baslangic));
      }
    }
  });

  test('para kazancı kasayı artırır', () {
    final f = Fal.havuz.firstWhere((x) => x.etki == FalEtki.paraKazanc);
    final s = GameState();
    final once = s.para;
    final sonuc = s.falUygula(f);
    expect(s.para, once + sonuc.miktar);
    expect(sonuc.miktar, inInclusiveRange(f.min, f.max));
  });

  test('dükkan büyütme bir üst seviyeye taşır, son seviyede paraya döner', () {
    final f = Fal.havuz.firstWhere((x) => x.etki == FalEtki.dukkanBuyut);
    final s = GameState();
    expect(s.aktifDukkan.seviye, 1);
    s.falUygula(f);
    expect(s.aktifDukkan.seviye, 2);

    // Son seviyede: seviye artmaz, patlamaz, para verir
    final s2 = GameState();
    s2.aktifDukkan = tumDukkanlar.last; // dukkanDegistir notify -> SharedPreferences ister
    final once = s2.para;
    s2.falUygula(f);
    expect(s2.aktifDukkan.seviye, tumDukkanlar.length);
    expect(s2.para, greaterThan(once));
  });

  test('kehanet falları sıradaki özel müşteriyi ayarlar', () {
    const beklenen = {
      FalEtki.vergiciGelecek:  OzelMusteriTip.vergici,
      FalEtki.hirsizGelecek:   OzelMusteriTip.hirsiz,
      FalEtki.polisGelecek:    OzelMusteriTip.polis,
      FalEtki.kuryeGelecek:    OzelMusteriTip.kurye,
      FalEtki.toptanciGelecek: OzelMusteriTip.toptanci,
    };
    beklenen.forEach((etki, tip) {
      final f = Fal.havuz.firstWhere((x) => x.etki == etki);
      final s = GameState();
      final sonuc = s.falUygula(f);
      expect(s.zorunluOzelTip, tip);
      // Kehanet sürprizi bozulmasın diye sonuç şeridi göstermez
      expect(sonuc.satir, isNull);
    });
  });

  test('hediye falları sayaçları artırır', () {
    final kolonya = Fal.havuz.firstWhere((x) => x.etki == FalEtki.kolonyaHediye);
    final s1 = GameState();
    final k0 = s1.kolonyaKullanim;
    s1.falUygula(kolonya);
    expect(s1.kolonyaKullanim, k0 + 10);

    final tamir = Fal.havuz.firstWhere((x) => x.etki == FalEtki.tamirSeti);
    final s2 = GameState();
    final t0 = s2.tamirSetiAdet;
    s2.falUygula(tamir);
    expect(s2.tamirSetiAdet, t0 + 2);
  });

  test('falcı özel müşteri rotasyonunda ve ücret makul', () {
    for (var i = 0; i < 200; i++) {
      final om = OzelMusteri.olustur(OzelMusteriTip.falci);
      expect(om.ad, 'Falcı Faloya');
      expect(om.gorsel, 'assets/falci.png');
      expect(om.ilkMiktar, inInclusiveRange(40, 140));
      // Selamlama ücreti söylemeli — oyuncu ne ödeyeceğini bilmeli
      expect(om.ilkMesaj.contains('${om.ilkMiktar}'), isTrue, reason: om.ilkMesaj);
    }
  });

  test('her dükkan seviyesinin arka planı tanımlı', () {
    for (final d in tumDukkanlar) {
      expect(d.arkaplan, isNotEmpty);
      expect(d.arkaplan.startsWith('assets/'), isTrue);
    }
  });
}
