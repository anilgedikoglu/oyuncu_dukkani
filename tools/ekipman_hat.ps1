# ASCII-only. Alfa sinir kutusunu bulur, kare tuvale ORTALI, en-boy koruyarak,
# uzun kenar tuvalin %<fill> kadari olacak sekilde yerlestirir.
Add-Type -AssemblyName System.Drawing
$src = $args[0]; $dst = $args[1]
$size = [int]$args[2]; $fill = [double]$args[3]

$b = [System.Drawing.Bitmap]::FromFile($src)
$w = $b.Width; $h = $b.Height
$minx = $w; $miny = $h; $maxx = -1; $maxy = -1
for ($y = 0; $y -lt $h; $y++) {
  for ($x = 0; $x -lt $w; $x++) {
    if ($b.GetPixel($x,$y).A -gt 12) {
      if ($x -lt $minx) { $minx = $x }
      if ($x -gt $maxx) { $maxx = $x }
      if ($y -lt $miny) { $miny = $y }
      if ($y -gt $maxy) { $maxy = $y }
    }
  }
}
if ($maxx -lt 0) { Write-Output "EMPTY"; exit 1 }
$bw = $maxx - $minx + 1; $bh = $maxy - $miny + 1
$hedef = $size * $fill
$olcek = [Math]::Min($hedef / $bw, $hedef / $bh)
$nw = [int][Math]::Round($bw * $olcek); $nh = [int][Math]::Round($bh * $olcek)
$ox = [int][Math]::Round(($size - $nw) / 2.0); $oy = [int][Math]::Round(($size - $nh) / 2.0)

$out = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($out)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
$srcRect = New-Object System.Drawing.Rectangle($minx, $miny, $bw, $bh)
$dstRect = New-Object System.Drawing.Rectangle($ox, $oy, $nw, $nh)
$g.DrawImage($b, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose()
$out.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Output ("OK {0} bbox {1}x{2} -> {3}x{4}" -f (Split-Path $dst -Leaf), $bw, $bh, $nw, $nh)
$out.Dispose(); $b.Dispose()
