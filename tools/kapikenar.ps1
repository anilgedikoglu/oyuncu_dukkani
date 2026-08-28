# ASCII-only. Kapi caminin SOL/SAG kenarini olcer.
# Kullanim: kapikenar.ps1 <gorsel> <kodSol> <kodUst> <kodGen> <kodYuk>
#
# Kapi kolundaki yatay cubuk otomatik olcumu bozuyordu; bu yuzden tarama
# camin UST %35'inde yapiliyor (orada gokyuzu var, kol yok).
Add-Type -AssemblyName System.Drawing
$b=[System.Drawing.Bitmap]::FromFile($args[0]); $W=$b.Width; $H=$b.Height
$kS=[double]$args[1]; $kU=[double]$args[2]; $kG=[double]$args[3]; $kY=[double]$args[4]
$y0=[int](($kU+$kY*0.05)*$H); $y1=[int](($kU+$kY*0.35)*$H)
$xA=[int](($kS-0.05)*$W); if($xA -lt 0){$xA=0}
$xB=[int](($kS+$kG+0.05)*$W); if($xB -ge $W){$xB=$W-1}
$dizi=@()
for($x=$xA;$x -le $xB;$x++){
  $t=0;$n=0
  for($y=$y0;$y -lt $y1;$y++){ $c=$b.GetPixel($x,$y); $t+=($c.R+$c.G+$c.B); $n++ }
  $dizi += ,@($x, ($t/$n))
}
# En parlak degerin %62'si esik: cam parlak, cerceve koyu.
$enP=0.0; foreach($d in $dizi){ if($d[1] -gt $enP){$enP=$d[1]} }
$esik=$enP*0.62
$sol=-1;$sag=-1
foreach($d in $dizi){ if($d[1] -ge $esik){ if($sol -lt 0){$sol=$d[0]}; $sag=$d[0] } }
Write-Host ("{0}|sol={1}|gen={2}" -f (Split-Path $args[0] -Leaf),
  [Math]::Round($sol/[double]$W,4), [Math]::Round(($sag-$sol+1)/[double]$W,4))
$b.Dispose()
