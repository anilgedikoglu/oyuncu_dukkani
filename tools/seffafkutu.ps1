Add-Type -AssemblyName System.Drawing
$b=[System.Drawing.Bitmap]::FromFile($args[0])
$w=$b.Width; $h=$b.Height
$cx=[int]($w/2); $cy=[int]($h*0.42)
function Bos($p) { return ($p.A -lt 30) }
$ust=$cy; while ($ust -gt 0 -and (Bos $b.GetPixel($cx,$ust-1))) { $ust-- }
$alt=$cy; while ($alt -lt $h-1 -and (Bos $b.GetPixel($cx,$alt+1))) { $alt++ }
$cy2=[int](($ust+$alt)/2)
$sol=$cx; while ($sol -gt 0 -and (Bos $b.GetPixel($sol-1,$cy2))) { $sol-- }
$sag=$cx; while ($sag -lt $w-1 -and (Bos $b.GetPixel($sag+1,$cy2))) { $sag++ }
Write-Output ("ekran x {0}..{1} y {2}..{3}" -f $sol,$sag,$ust,$alt)
Write-Output ("SOL {0:N4} UST {1:N4} GEN {2:N4} YUK {3:N4}" -f ($sol/$w),($ust/$h),(($sag-$sol)/$w),(($alt-$ust)/$h))
$b.Dispose()
