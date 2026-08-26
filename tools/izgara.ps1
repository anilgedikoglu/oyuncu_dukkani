# ASCII-only. Gorseli buyuk panele basar, %5'lik etiketli izgara cizer.
Add-Type -AssemblyName System.Drawing
$src = $args[0]; $out = $args[1]; $panelW = [int]$args[2]
$im = [System.Drawing.Bitmap]::FromFile($src)
$sc = $panelW / $im.Width
$w = $panelW; $h = [int]($im.Height * $sc)
$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($im, 0, 0, $w, $h)
$penI = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(90,255,0,0)), 1
$penK = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(220,0,255,255)), 2
$font = New-Object System.Drawing.Font("Arial", 11, [System.Drawing.FontStyle]::Bold)
$br = [System.Drawing.Brushes]::Yellow
for ($p = 0; $p -le 100; $p += 5) {
  $x = [int]($w * $p / 100.0); $y = [int]($h * $p / 100.0)
  $pen = if ($p % 10 -eq 0) { $penK } else { $penI }
  $g.DrawLine($pen, $x, 0, $x, $h)
  $g.DrawLine($pen, 0, $y, $w, $y)
  if ($p % 10 -eq 0) {
    $g.DrawString($p, $font, $br, $x+2, 2)
    $g.DrawString($p, $font, $br, 2, $y+2)
  }
}
$g.Dispose(); $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose(); $im.Dispose()
Write-Output ("OK {0}x{1}" -f $w, $h)
