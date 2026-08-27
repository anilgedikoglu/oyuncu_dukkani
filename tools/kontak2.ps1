Add-Type -AssemblyName System.Drawing
$out = $args[0]
$files = $args[1..($args.Count-1)]
$cell = 300; $cols = 3
$rows = [Math]::Ceiling($files.Count / $cols)
$bmp = New-Object System.Drawing.Bitmap(($cols*$cell), ($rows*($cell+26)))
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(255,45,45,55))
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$font = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Bold)
$br = [System.Drawing.Brushes]::Yellow
$i = 0
foreach ($f in $files) {
  $cx = ($i % $cols) * $cell; $cy = [Math]::Floor($i / $cols) * ($cell+26)
  $im = [System.Drawing.Bitmap]::FromFile($f)
  $s = [Math]::Min(($cell-14)/$im.Width, ($cell-14)/$im.Height)
  $nw = [int]($im.Width*$s); $nh = [int]($im.Height*$s)
  $g.DrawImage($im, ($cx + ($cell-$nw)/2), ($cy + ($cell-$nh)/2), $nw, $nh)
  $g.DrawString((Split-Path $f -Leaf), $font, $br, $cx+6, $cy+$cell+2)
  $im.Dispose(); $i++
}
$g.Dispose(); $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
Write-Output "OK"
