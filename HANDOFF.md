# HANDOFF

## Sıradaki adım
1.4.1 iki mağazada incelemede (24 Kas 2026). Onay gelince yayında mı kontrol et; sonra AdMob'da Android istek sayısının (ücretsiz geçiş sonrası) artışına bak.

## Ne yapıldı (24 Kas 2026) — sürüm 1.4.1+31
- Google Play: uygulama ÜCRETLİ (₺15,99) → ÜCRETSİZ (geri dönülemez). Reklamlar iOS ile aynı kod.
- Reklam: yükleme hatasında tekrar dene; geçişe merkezi 90 sn aralık; gösterilemezse bekleme sıfırlanır.
- iOS ATT izni artık ilk kare çizildikten sonra soruluyor (runApp'ten önce sorulunca pencere çıkmıyordu → kişiselleştirilmemiş reklam). `lib/main.dart` `_reklamBaslat()`. Cihazda denenmedi.
- Gizlilik/destek sayfaları stüdyo sitesine taşındı (kişisel ad/e-posta yok, AdMob + ATT anlatılıyor):
  `https://futurastictech.github.io/oyuncu-dukkani/privacy-policy.html`, `.../support.html`.
  Play gizlilik URL'si + iOS gizlilik/destek/pazarlama URL'leri güncellendi.
- Android: AAB yerelde derlendi, Play üretime (31 / 1.4.1, %100) yüklendi; reklam beyanı + hedef kitle + gizlilik ile birlikte incelemede.
- iOS: Codemagic DURDU (hesapta ödenmemiş fatura). Yeni yol GitHub Actions `.github/workflows/ios-testflight.yml`
  (`gh workflow run "iOS TestFlight" -R anilgedikoglu/oyuncu_dukkani --ref main`). İmza: ortak dağıtım sertifikası +
  profil `oyuncudukkani_appstore` (`C:\src\oyuncu_dukkani_keys\`, repoda yok); depo secrets kuruldu.
  App Store 1.4.1 asc CLI ile açıldı (metadata 1.1.0'dan), incelemeye gönderildi.

## Yarım kalan
- Eski `anilgedikoglu.github.io/oyuncu_dukkani/*` sayfaları hâlâ yayında (kişisel ad içeriyor); mağazalar artık onlara bağlı değil.

## Denenip olmayan
- Chrome uzantısı 10 MB üstü dosya yükleyemiyor → AAB 9,5 MB parçalara bölünüp sayfada birleştirildi (SHA-256 eşleşti), DataTransfer ile Play'e verildi.
- Codemagic tag tetiklemesi (v1.4.1-ios1) fatura yüzünden hiç başlamadı.
