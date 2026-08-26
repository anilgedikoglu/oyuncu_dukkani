# ASCII-only. Etiketli kontak sayfasi uretir.
Add-Type -AssemblyName System.Drawing
$dir = $args[0]; $out = $args[1]
$cell = 300; $cols = 4
$files = Get-ChildItem $dir -Filter *.png | Where-Object { $_.Name -ne 'bosev.png' -and $_.Name -ne 'doluev.png' } | Sort-Object Name
$rows = [Math]::Ceiling($files.Count / $cols)
$bmp = New-Object System.Drawing.Bitmap(($cols*$cell), ($rows*($cell+26)))
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(255,40,40,48))
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$font = New-Object System.Drawing.Font("Arial", 13)
$br = [System.Drawing.Brushes]::White
$i = 0
foreach ($f in $files) {
  $cx = ($i % $cols) * $cell; $cy = [Math]::Floor($i / $cols) * ($cell+26)
  $im = [System.Drawing.Bitmap]::FromFile($f.FullName)
  $s = [Math]::Min(($cell-16)/$im.Width, ($cell-16)/$im.Height)
  $nw = [int]($im.Width*$s); $nh = [int]($im.Height*$s)
  $g.DrawImage($im, ($cx + ($cell-$nw)/2), ($cy + ($cell-$nh)/2), $nw, $nh)
  $g.DrawString(("{0}  {1}x{2}" -f $f.BaseName, $im.Width, $im.Height), $font, $br, $cx+6, $cy+$cell+3)
  $im.Dispose()
  $i++
}
$g.Dispose(); $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
Write-Output "OK $i"
