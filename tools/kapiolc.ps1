# ASCII-only. Kapi cami dikdortgenini olcer VE gorselin ustune cizip kaydeder.
# Kullanim: kapiolc.ps1 <gorsel> <cikis> <kodSol> <kodUst> <kodGen> <kodYuk>
# Kod kutusunun cevresinde +-%9 tarar; parlak (dis dunya gorunen) bolgeyi bulur.
Add-Type -AssemblyName System.Drawing
$src=$args[0]; $dst=$args[1]
$kS=[double]$args[2]; $kU=[double]$args[3]; $kG=[double]$args[4]; $kY=[double]$args[5]
$b=[System.Drawing.Bitmap]::FromFile($src); $W=$b.Width; $H=$b.Height

function Parlak($bm,$x,$y){ $c=$bm.GetPixel($x,$y); return (($c.R+$c.G+$c.B) -gt 560) }

# --- Dikey: kod kutusunun yatay ortasindan gecen seride satirlari tara
$xa=[int](($kS+$kG*0.30)*$W); $xb=[int](($kS+$kG*0.70)*$W)
$yA=[int](($kU-0.09)*$H); if($yA -lt 0){$yA=0}
$yB=[int](($kU+$kY+0.09)*$H); if($yB -ge $H){$yB=$H-1}
$satir=@{}
for($y=$yA;$y -lt $yB;$y++){
  $p=0;$n=0; for($x=$xa;$x -lt $xb;$x+=2){ $n++; if(Parlak $b $x $y){$p++} }
  $satir[$y] = $p/$n
}
# En uzun kesintisiz "parlak" blogu (esik 0.35)
$enU=-1;$enA=-1;$enBoy=0; $bas=-1
for($y=$yA;$y -lt $yB;$y++){
  if($satir[$y] -ge 0.35){ if($bas -lt 0){$bas=$y} }
  else { if($bas -ge 0){ $boy=$y-$bas; if($boy -gt $enBoy){$enBoy=$boy;$enU=$bas;$enA=$y-1}; $bas=-1 } }
}
if($bas -ge 0){ $boy=$yB-$bas; if($boy -gt $enBoy){$enBoy=$boy;$enU=$bas;$enA=$yB-1} }

# --- Yatay: bulunan dikey aralikta sutunlari tara
$ya=$enU+[int]($enBoy*0.15); $yb=$enA-[int]($enBoy*0.15)
$xA=[int](($kS-0.09)*$W); if($xA -lt 0){$xA=0}
$xB=[int](($kS+$kG+0.09)*$W); if($xB -ge $W){$xB=$W-1}
$sut=@{}
for($x=$xA;$x -lt $xB;$x++){
  $p=0;$n=0; for($y=$ya;$y -lt $yb;$y+=2){ $n++; if(Parlak $b $x $y){$p++} }
  $sut[$x]=$p/$n
}
$enS=-1;$enSa=-1;$enGen=0;$bas=-1
for($x=$xA;$x -lt $xB;$x++){
  if($sut[$x] -ge 0.35){ if($bas -lt 0){$bas=$x} }
  else { if($bas -ge 0){ $g2=$x-$bas; if($g2 -gt $enGen){$enGen=$g2;$enS=$bas;$enSa=$x-1}; $bas=-1 } }
}
if($bas -ge 0){ $g2=$xB-$bas; if($g2 -gt $enGen){$enGen=$g2;$enS=$bas;$enSa=$xB-1} }

$oS=[Math]::Round($enS/[double]$W,4); $oU=[Math]::Round($enU/[double]$H,4)
$oG=[Math]::Round($enGen/[double]$W,4); $oY=[Math]::Round($enBoy/[double]$H,4)
Write-Host ("{0}|{1}|{2}|{3}|{4}" -f (Split-Path $src -Leaf),$oS,$oU,$oG,$oY)

$o=New-Object System.Drawing.Bitmap($W,$H); $g=[System.Drawing.Graphics]::FromImage($o)
$g.DrawImage($b,0,0,$W,$H)
$pk=New-Object System.Drawing.Pen([System.Drawing.Color]::Red,3)
$pl=New-Object System.Drawing.Pen([System.Drawing.Color]::Lime,3)
$g.DrawRectangle($pk,[int]($kS*$W),[int]($kU*$H),[int]($kG*$W),[int]($kY*$H))
$g.DrawRectangle($pl,$enS,$enU,$enGen,$enBoy)
$o.Save($dst,[System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose();$o.Dispose();$b.Dispose()
