import 'package:flutter_test/flutter_test.dart';
import 'package:oyuncu_dukkani/main.dart';

/// Yaş/cinsiyet duyarlı replik sistemi — regresyon testi.
///
/// Buradaki asıl amaç şu hatayı bir daha yapmamak: "Anneme sormadan CD satmaya
/// geldim" repliği 75 yaşındaki amcaya düşüyordu. Filtre bozulursa test patlar.

GameItem _urun() => GameItem(
      id: 'cd1', name: 'KARMAGEDDON', gorsel: 'assets/CD_1.png',
      category: ItemCategory.cd, basePrice: 120, kondisyon: 4,
    );

Customer _musteri({required YasGrubu yas, required String cinsiyet, required bool satiyor}) =>
    Customer(
      name: 'Test', gorsel: 'assets/musteri_1.png', musteriSatiyor: satiyor,
      item: _urun(), ilkTeklif: 100, ozellik: MusteriOzellik.random(),
      yas: yas, cinsiyet: cinsiyet,
    );

/// Bir yaş+cinsiyet için bol örnek toplayıp benzersizlerini döner.
Set<String> _ornekle(YasGrubu yas, String cinsiyet, bool satiyor, {int adet = 3000}) {
  final s = <String>{};
  for (var i = 0; i < adet; i++) {
    s.add(_musteri(yas: yas, cinsiyet: cinsiyet, satiyor: satiyor).selamMesaji);
  }
  return s;
}

void main() {
  test('replikSec asla boş dönmez, filtre boşsa nötre düşer', () {
    // Hiçbir repliğin uymadığı bir havuz — güvenlik zinciri devreye girmeli
    const havuz = [
      Replik('nötr satır'),
      Replik('sadece çocuk', yas: [YasGrubu.cocuk]),
    ];
    expect(replikSec(havuz, YasGrubu.yasli, 'E'), 'nötr satır');
    // Nötr bile yoksa tüm havuzdan seç — yine de boş dönmemeli
    const dar = [Replik('sadece çocuk', yas: [YasGrubu.cocuk])];
    expect(replikSec(dar, YasGrubu.yasli, 'E'), isNotEmpty);
  });

  test('çocuk/genç replikleri yetişkin ve yaşlıya düşmez', () {
    const cocukcaLafiar = ['Anneme sormadan', 'harçlığımı biriktirdim', 'Kumbaramı', 'Bayram harçlığım'];
    for (final yas in [YasGrubu.yetiskin, YasGrubu.yasli]) {
      for (final c in ['E', 'K']) {
        for (final satiyor in [true, false]) {
          for (final m in _ornekle(yas, c, satiyor)) {
            for (final laf in cocukcaLafiar) {
              expect(m.contains(laf), isFalse, reason: '$yas/$c → $m');
            }
          }
        }
      }
    }
  });

  test('yaşlı replikleri çocuk ve gence düşmez', () {
    const yaslicaLafiar = ['Torunum', 'torunuma', 'Torunuma', 'Emekli', 'Emekliyim', 'Çocukluğumdan beri'];
    for (final yas in [YasGrubu.cocuk, YasGrubu.genc]) {
      for (final c in ['E', 'K']) {
        for (final satiyor in [true, false]) {
          for (final m in _ornekle(yas, c, satiyor)) {
            for (final laf in yaslicaLafiar) {
              expect(m.contains(laf), isFalse, reason: '$yas/$c → $m');
            }
          }
        }
      }
    }
  });

  test('cinsiyet etiketli replikler karşı cinse düşmez', () {
    for (final satiyor in [true, false]) {
      for (final m in _ornekle(YasGrubu.yetiskin, 'E', satiyor)) {
        expect(m.contains('Ablan'), isFalse, reason: 'erkeğe kadın repliği: $m');
        expect(m.contains('Kızlar'), isFalse, reason: 'erkeğe kadın repliği: $m');
      }
      for (final m in _ornekle(YasGrubu.yetiskin, 'K', satiyor)) {
        expect(m.contains('Erkek adam'), isFalse, reason: 'kadına erkek repliği: $m');
        expect(m.contains('Delikanlı adam'), isFalse, reason: 'kadına erkek repliği: $m');
      }
    }
  });

  test('her yaş/cinsiyet için yeterli çeşitlilik var', () {
    for (final yas in YasGrubu.values) {
      for (final c in ['E', 'K']) {
        for (final satiyor in [true, false]) {
          expect(_ornekle(yas, c, satiyor).length, greaterThanOrEqualTo(20),
              reason: '$yas/$c/satiyor=$satiyor havuzu çok dar');
        }
      }
    }
  });

  test('placeholder tuzağı: {AD} ve {URUN} tamamen doldurulur', () {
    for (final yas in YasGrubu.values) {
      for (final c in ['E', 'K']) {
        for (final satiyor in [true, false]) {
          for (final m in _ornekle(yas, c, satiyor)) {
            expect(m.contains('{'), isFalse, reason: 'doldurulmamış placeholder: $m');
          }
        }
      }
    }
  });
}
