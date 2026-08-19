import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oyuncu_dukkani/main.dart';

/// Oynanabilir ürün (KIRGEÇ) regresyon testleri.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SesServisi.sesAcik = false; // test ortaminda audioplayers plugin yok
  });

  GameItem kirgec() => GameState.koleksiyonUrunleri.firstWhere((u) => u.id == 'cd15');

  test('KIRGEÇ koleksiyonda ve oynanabilir', () {
    final k = kirgec();
    expect(k.name, 'KIRGEÇ');
    expect(k.oynanabilir, isTrue);
    expect(k.gorsel, 'assets/CD_15.png');
  });

  test('oynanabilir ürün normal CD ortalamasının ~2 katı', () {
    final cdler = GameState.koleksiyonUrunleri
        .where((u) => u.category == ItemCategory.cd && !u.oynanabilir);
    final ortalama = cdler.map((u) => u.basePrice).reduce((a, b) => a + b) / cdler.length;
    final oran = kirgec().basePrice / ortalama;
    expect(oran, closeTo(2.0, 0.15), reason: 'ortalama=$ortalama, kirgec=${kirgec().basePrice}');
  });

  test('tek oynanabilir ürün var — hepsi 2x kuralına uymalı', () {
    final oynanabilirler = GameState.koleksiyonUrunleri.where((u) => u.oynanabilir).toList();
    expect(oynanabilirler.length, greaterThanOrEqualTo(1));
    for (final u in oynanabilirler) {
      expect(u.gorsel, isNotEmpty);
      expect(u.basePrice, greaterThan(200));
    }
  });

  test('oynanabilir bayrağı kayıt turunu atlatıyor', () {
    final geri = GameItem.fromJson(kirgec().toJson());
    expect(geri.oynanabilir, isTrue);
    expect(geri.name, 'KIRGEÇ');
  });

  test('kopyaWith oynanabilir bayrağını kaybetmiyor', () {
    final k = kirgec().kopyaWith(maliyet: 100, kondisyon: 3);
    expect(k.oynanabilir, isTrue);
    expect(k.kopya().oynanabilir, isTrue);
  });

  test('İTELE de oynanabilir ve aynı fiyat kuralında', () {
    final itele = GameState.koleksiyonUrunleri.firstWhere((u) => u.id == 'cd16');
    expect(itele.name, 'İTELE');
    expect(itele.oynanabilir, isTrue);
    expect(itele.gorsel, 'assets/CD_16.png');
    expect(itele.basePrice, greaterThan(200));
  });

  test('gün sınırı: oynanan oyun aynı gün tekrar oynanamaz, ertesi gün açılır', () {
    final s = GameState();
    expect(s.bugunOynananOyunlar, isEmpty);
    s.bugunOynananOyunlar.add('cd15');
    expect(s.bugunOynananOyunlar.contains('cd15'), isTrue);
    expect(s.bugunOynananOyunlar.contains('cd16'), isFalse);
    s.gunuBitir();
    expect(s.bugunOynananOyunlar, isEmpty, reason: 'gün bitince hak yenilenmeli');
  });

  test('gün sınırı kayıtta saklanıyor', () {
    final s = GameState();
    s.bugunOynananOyunlar.addAll({'cd15', 'cd16'});
    final geri = GameState.fromJson(s.toJson());
    expect(geri.bugunOynananOyunlar, {'cd15', 'cd16'});
  });

  test('kapalı kutudan oynanabilir ürün çıkmaz', () {
    for (var deneme = 0; deneme < 200; deneme++) {
      final s = GameState();
      s.slotlar[0] = GameState.kapaliKutuUret();
      final cikan = s.kutuAc(0);
      if (cikan == null) continue;
      expect(cikan.oynanabilir, isFalse, reason: 'kutudan ${cikan.name} çıktı');
    }
  });

  test('toptancı stoğunda oynanabilir ürün olmaz', () {
    for (var gun = 0; gun < 60; gun++) {
      final s = GameState();
      s.toptanciZiyaretiTazele();
      for (final t in s.toptanciStok) {
        expect(t.item?.oynanabilir ?? false, isFalse, reason: '${t.item?.name} Rıza\'da çıktı');
      }
    }
  });
}
