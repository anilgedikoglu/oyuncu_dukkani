# ASCII-only. Merkezden disari tarayarak IC siyah ekrani bulur.
Add-Type -AssemblyName System.Drawing
$b=[System.Drawing.Bitmap]::FromFile($args[0])
$w=$b.Width; $h=$b.Height
$cx=[int]($w/2); $cy=[int]($h*0.42)
function Siyah($p) { return ($p.A -gt 200 -and $p.R -lt 18 -and $p.G -lt 18 -and $p.B -lt 18) }
$ust=$cy; while ($ust -gt 0 -and (Siyah $b.GetPixel($cx,$ust-1))) { $ust-- }
$alt=$cy; while ($alt -lt $h-1 -and (Siyah $b.GetPixel($cx,$alt+1))) { $alt++ }
$cy2=[int](($ust+$alt)/2)
$sol=$cx; while ($sol -gt 0 -and (Siyah $b.GetPixel($sol-1,$cy2))) { $sol-- }
$sag=$cx; while ($sag -lt $w-1 -and (Siyah $b.GetPixel($sag+1,$cy2))) { $sag++ }
Write-Output ("ekran x {0}..{1} y {2}..{3}" -f $sol,$sag,$ust,$alt)
Write-Output ("SOL {0:N4} UST {1:N4} GEN {2:N4} YUK {3:N4}" -f ($sol/$w),($ust/$h),(($sag-$sol)/$w),(($alt-$ust)/$h))
$b.Dispose()
