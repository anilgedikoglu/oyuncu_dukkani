Add-Type -AssemblyName System.Drawing
$b = [System.Drawing.Bitmap]::FromFile($args[0])
$w=$b.Width; $h=$b.Height
$cx=[int]($w/2)
$bas=-1; $son=-1
for ($y=0; $y -lt $h; $y++) {
  $p=$b.GetPixel($cx,$y)
  $siyah = ($p.A -gt 200 -and $p.R -lt 14 -and $p.G -lt 14 -and $p.B -lt 14)
  if ($siyah -and $bas -lt 0 -and $y -gt ($h*0.08)) { $bas=$y }
  if ($siyah) { $son=$y }
  if (-not $siyah -and $bas -ge 0 -and $y -gt $bas -and ($y-$son) -gt 3 -and $y -gt ($h*0.5)) { break }
}
$cy=[int](($bas+$son)/2)
$sol=-1; $sag=-1
for ($x=0; $x -lt $w; $x++) {
  $p=$b.GetPixel($x,$cy)
  $siyah = ($p.A -gt 200 -and $p.R -lt 14 -and $p.G -lt 14 -and $p.B -lt 14)
  if ($siyah -and $sol -lt 0 -and $x -gt ($w*0.05)) { $sol=$x }
  if ($siyah) { $sag=$x }
}
Write-Output ("tuval {0}x{1} | ekran y {2}..{3} x {4}..{5}" -f $w,$h,$bas,$son,$sol,$sag)
Write-Output ("SOL {0:N4} UST {1:N4} GEN {2:N4} YUK {3:N4}" -f ($sol/$w),($bas/$h),(($sag-$sol)/$w),(($son-$bas)/$h))
$b.Dispose()
