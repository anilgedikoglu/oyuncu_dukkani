# ASCII-only. Alfa sinir kutusuna gore tam kirpar (yeniden olceklemez).
Add-Type -AssemblyName System.Drawing
$src = $args[0]; $dst = $args[1]
$b = [System.Drawing.Bitmap]::FromFile($src)
$w = $b.Width; $h = $b.Height
$minx=$w; $miny=$h; $maxx=-1; $maxy=-1
for ($y=0; $y -lt $h; $y++) { for ($x=0; $x -lt $w; $x++) {
  if ($b.GetPixel($x,$y).A -gt 10) {
    if ($x -lt $minx) {$minx=$x}; if ($x -gt $maxx) {$maxx=$x}
    if ($y -lt $miny) {$miny=$y}; if ($y -gt $maxy) {$maxy=$y}
  } } }
$bw = $maxx-$minx+1; $bh = $maxy-$miny+1
$out = New-Object System.Drawing.Bitmap($bw, $bh, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($out)
$sr = New-Object System.Drawing.Rectangle($minx,$miny,$bw,$bh)
$dr = New-Object System.Drawing.Rectangle(0,0,$bw,$bh)
$g.DrawImage($b, $dr, $sr, [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose(); $out.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Output ("{0} -> {1}x{2}" -f (Split-Path $dst -Leaf), $bw, $bh)
$out.Dispose(); $b.Dispose()
