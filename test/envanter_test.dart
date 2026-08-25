import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oyuncu_dukkani/main.dart';

/// Envanter işlemleri: kapalı kutu açma ve ürün çöpe atma.
///
/// Kullanıcı bildirimi: "çöpe at deyince atmıyor ve kapalı kutuyu aç deyince
/// açmıyor ama sanırım envanter doluyken açmıyor". Bu testler envanterin
/// TAMAMEN DOLU olduğu durumu bilerek kurar.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SesServisi.sesAcik = false; // test ortaminda audioplayers plugin yok
  });

  /// Envanteri tamamen doldurur, [kutuIndex] slotuna kapalı kutu koyar.
  GameState doluEnvanter({required int kutuIndex, int seviye = 2}) {
    final s = GameState();
    s.aktifDukkan = tumDukkanlar.firstWhere((d) => d.seviye == seviye);
    final ornek = GameState.koleksiyonUrunleri
        .firstWhere((u) => u.category == ItemCategory.cd && !u.oynanabilir);
    for (int i = 0; i < s.acikSlotSayisi; i++) {
      s.slotlar[i] = ornek.kopya();
    }
    s.slotlar[kutuIndex] = GameState.kapaliKutuUret();
    return s;
  }

  group('kapalı kutu açma', () {
    test('envanter TAMAMEN DOLUYKEN de açılır', () {
      final s = doluEnvanter(kutuIndex: 1);
      expect(s.bosSlotVar, isFalse, reason: 'test kurulumu: envanter dolu olmalı');

      final cikan = s.kutuAc(1);
      expect(cikan, isNotNull, reason: 'dolu envanterde kutu açılamadı');
      expect(s.slotlar[1]!.kapaliKutu, isFalse, reason: 'kutu hâlâ kapalı');
      expect(s.slotlar[1]!.id, isNot('kapali_kutu'));
    });

    test('her açık slot indeksinde çalışır', () {
      for (int i = 0; i < 10; i++) {
        final s = doluEnvanter(kutuIndex: i);
        expect(s.kutuAc(i), isNotNull, reason: 'slot $i açılamadı');
      }
    });

    test('kutudan oynanabilir ürün çıkmaz', () {
      for (int n = 0; n < 200; n++) {
        final s = doluEnvanter(kutuIndex: 0);
        final cikan = s.kutuAc(0);
        expect(cikan!.oynanabilir, isFalse);
      }
    });

    test('açılan kutu sayacı ve günlük hedef ilerler', () {
      final s = doluEnvanter(kutuIndex: 2);
      final once = s.acilanKutuSayisi;
      s.kutuAc(2);
      expect(s.acilanKutuSayisi, once + 1);
    });

    test('kapalı kutu olmayan slotta null döner (savunma)', () {
      final s = doluEnvanter(kutuIndex: 1);
      expect(s.kutuAc(0), isNull, reason: 'slot 0 normal ürün, açılmamalı');
      expect(s.kutuAc(999), isNull, reason: 'geçersiz indeks');
    });
  });

  group('çöpe atma (urunCikarOrnek)', () {
    test('envanter TAMAMEN DOLUYKEN ürün çıkarılır', () {
      final s = doluEnvanter(kutuIndex: 9);
      final hedef = s.slotlar[3]!;
      final oncekiDolu = s.stokluUrunler.length;

      expect(s.urunCikarOrnek(hedef), isTrue, reason: 'dolu envanterde çıkarılamadı');
      expect(s.stokluUrunler.length, oncekiDolu - 1);
      expect(s.bosSlotVar, isTrue, reason: 'çıkarınca boş slot oluşmalı');
    });

    test('aynı id\'den çürük ve sağlam varsa DOĞRU örnek çıkar', () {
      final s = GameState();
      s.aktifDukkan = tumDukkanlar.firstWhere((d) => d.seviye == 2);
      final base = GameState.koleksiyonUrunleri
          .firstWhere((u) => u.category == ItemCategory.cd && !u.oynanabilir);
      for (int i = 0; i < s.acikSlotSayisi; i++) {
        s.slotlar[i] = null;
      }
      final saglam = base.kopyaWith(curuk: false, kondisyon: 5);
      final curuk  = base.kopyaWith(curuk: true,  kondisyon: 1);
      s.slotlar[0] = saglam;
      s.slotlar[1] = curuk;

      expect(s.urunCikarOrnek(curuk), isTrue);
      // Kalan tek ürün SAĞLAM olmalı
      final kalan = s.stokluUrunler;
      expect(kalan.length, 1);
      expect(kalan.first.curuk, isFalse, reason: 'yanlış örnek silindi');
    });

    test('çıkarma sonrası slotlar öne çekilir, arada boşluk kalmaz', () {
      final s = doluEnvanter(kutuIndex: 9);
      s.urunCikarOrnek(s.slotlar[0]!);
      // İlk (n-1) slot dolu, sonuncusu boş olmalı
      for (int i = 0; i < s.acikSlotSayisi - 1; i++) {
        expect(s.slotlar[i], isNotNull, reason: 'slot $i boş kalmış');
      }
      expect(s.slotlar[s.acikSlotSayisi - 1], isNull);
    });
  });
}
