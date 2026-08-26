# ASCII-only. bosev uzerine mobilyalari oranlarla cizer (dogrulama gorseli).
# NOT: Bitmap::FromFile dosyayi kilitler ve tembel yukler; bayt akisindan
# yuklemek daha guvenli.
Add-Type -AssemblyName System.Drawing
function Yukle($p) {
  $bytes = [System.IO.File]::ReadAllBytes($p)
  $ms = New-Object System.IO.MemoryStream(,$bytes)
  return [System.Drawing.Bitmap]::FromStream($ms)
}
$items = @(
  @('vazo',0.205,0.235,0.060),
  @('tv',0.365,0.255,0.290),
  @('lambader',0.855,0.295,0.110),
  @('teklibir',0.030,0.425,0.280),
  @('tekliiki',0.725,0.425,0.260),
  @('ortasehpa',0.345,0.468,0.330),
  @('sehpa2',0.005,0.535,0.130),
  @('sehpa1',0.865,0.530,0.130),
  @('ikilikoltuk',0.105,0.545,0.790)
)
$bg = Yukle("C:/src/oyuncu_dukkani/assets/ev_bos.jpg")
$W = $bg.Width; $H = $bg.Height
$out = New-Object System.Drawing.Bitmap($W, $H)
$g = [System.Drawing.Graphics]::FromImage($out)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
$g.DrawImage($bg, 0, 0, $W, $H)
foreach ($it in $items) {
  $f = "C:/src/oyuncu_dukkani/assets/ev_" + $it[0] + ".png"
  $im = Yukle($f)
  $px = [single]([double]$it[1] * $W)
  $py = [single]([double]$it[2] * $H)
  $pw = [single]([double]$it[3] * $W)
  $ph = [single]($pw * $im.Height / $im.Width)
  $dr = New-Object System.Drawing.RectangleF($px, $py, $pw, $ph)
  $sr = New-Object System.Drawing.RectangleF(0, 0, $im.Width, $im.Height)
  $g.DrawImage($im, $dr, $sr, [System.Drawing.GraphicsUnit]::Pixel)
  Write-Output ("{0}: {1},{2} {3}x{4}" -f $it[0], [int]$px, [int]$py, [int]$pw, [int]$ph)
}
$g.Dispose()
$out.Save("C:/Users/AG/AppData/Local/Temp/claude/ev_kompozit3.png", [System.Drawing.Imaging.ImageFormat]::Png)
