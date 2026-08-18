# Batch: remove white bg, normalize to 500x500, then build a numbered contact sheet.
. "$PSScriptRoot\arkaplan_sil.ps1"

$kaynakDir = "C:\Users\AG\Desktop\indirilen\YeniKarakterler"
$cikisDir  = "$PSScriptRoot\..\build\yeni_karakterler"
New-Item -ItemType Directory -Force -Path $cikisDir | Out-Null

$dosyalar = Get-ChildItem $kaynakDir -Filter *.png | Sort-Object Name
$i = 0
$uretilen = @()
foreach ($f in $dosyalar) {
    $i++
    $ad = "yeni_{0:D2}.png" -f $i
    $hedef = Join-Path $cikisDir $ad
    $r = [BgKiller]::Process($f.FullName, $hedef, 500, 640, 232, 0.95, 5)
    $kb = [math]::Round((Get-Item $hedef).Length/1KB)
    Write-Host ("{0}  {1,-16} {2,-12} {3,4} KB" -f $i, $ad, $r, $kb)
    $uretilen += $hedef
}

# Contact sheet: 5 columns x 4 rows, 200px cells, index label on each
$hucre = 200; $kol = 5; $satir = [math]::Ceiling($uretilen.Count / $kol)
$sheet = New-Object System.Drawing.Bitmap(($hucre*$kol), ($hucre*$satir))
$g = [System.Drawing.Graphics]::FromImage($sheet)
$g.Clear([System.Drawing.Color]::FromArgb(255,40,40,48))
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$font = New-Object System.Drawing.Font("Arial", 22, [System.Drawing.FontStyle]::Bold)
$sari = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Yellow)
$siyah = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black)
for ($k = 0; $k -lt $uretilen.Count; $k++) {
    $cx = ($k % $kol) * $hucre; $cy = [math]::Floor($k / $kol) * $hucre
    $im = [System.Drawing.Image]::FromFile($uretilen[$k])
    $g.DrawImage($im, $cx, $cy, $hucre, $hucre)
    $im.Dispose()
    $g.FillRectangle($siyah, $cx, $cy, 44, 32)
    $g.DrawString(($k+1).ToString(), $font, $sari, $cx+4, $cy+2)
}
$g.Dispose()
$sheetYol = "$PSScriptRoot\..\build\kontak_sayfasi.png"
$sheet.Save($sheetYol, [System.Drawing.Imaging.ImageFormat]::Png)
$sheet.Dispose()
Write-Host ""
Write-Host "Kontak sayfasi: $sheetYol"
Write-Host ("Toplam boyut: {0} MB" -f [math]::Round((($uretilen | ForEach-Object { (Get-Item $_).Length }) | Measure-Object -Sum).Sum/1MB, 2))
