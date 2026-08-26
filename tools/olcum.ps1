Add-Type -AssemblyName System.Drawing
foreach ($f in $args) {
  $bmp = [System.Drawing.Bitmap]::FromFile($f)
  $w = $bmp.Width; $h = $bmp.Height
  $minx = $w; $miny = $h; $maxx = -1; $maxy = -1
  for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
      if ($bmp.GetPixel($x,$y).A -gt 12) {
        if ($x -lt $minx) { $minx = $x }
        if ($x -gt $maxx) { $maxx = $x }
        if ($y -lt $miny) { $miny = $y }
        if ($y -gt $maxy) { $maxy = $y }
      }
    }
  }
  $bw = $maxx - $minx + 1; $bh = $maxy - $miny + 1
  Write-Output ("{0}|{1}x{2}|bbox {3},{4} {5}x{6}|dolulukY {7:N3}|altBosluk {8}" -f (Split-Path $f -Leaf), $w, $h, $minx, $miny, $bw, $bh, ($bh/$h), ($h-1-$maxy))
  $bmp.Dispose()
}
