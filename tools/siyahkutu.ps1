# ASCII-only. Gorseldeki tamamen siyah (opak) dikdortgeni bulur.
Add-Type -AssemblyName System.Drawing
$b = [System.Drawing.Bitmap]::FromFile($args[0])
$w = $b.Width; $h = $b.Height
$minx=$w; $miny=$h; $maxx=-1; $maxy=-1
for ($y=0; $y -lt $h; $y+=2) { for ($x=0; $x -lt $w; $x+=2) {
  $p = $b.GetPixel($x,$y)
  if ($p.A -gt 200 -and $p.R -lt 12 -and $p.G -lt 12 -and $p.B -lt 12) {
    if ($x -lt $minx) {$minx=$x}; if ($x -gt $maxx) {$maxx=$x}
    if ($y -lt $miny) {$miny=$y}; if ($y -gt $maxy) {$maxy=$y}
  } } }
Write-Output ("tuval {0}x{1} | siyah {2},{3} -> {4},{5}" -f $w,$h,$minx,$miny,$maxx,$maxy)
Write-Output ("oran sol {0:N4} ust {1:N4} gen {2:N4} yuk {3:N4}" -f ($minx/$w),($miny/$h),(($maxx-$minx)/$w),(($maxy-$miny)/$h))
$b.Dispose()
