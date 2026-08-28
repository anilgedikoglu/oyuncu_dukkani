# ASCII-only. Kapi kutusunun SOL ve SAG kenarini 8x buyutup yan yana koyar.
# Kirmizi dikey cizgi = kutunun kenari. Cam kenari cizginin neresinde?
# Kullanim: kenarkontrol.ps1 <gorsel> <cikis> <sol> <ust> <gen> <yuk>
Add-Type -AssemblyName System.Drawing
$b=[System.Drawing.Bitmap]::FromFile($args[0]); $W=$b.Width; $H=$b.Height
$s=[double]$args[2]; $u=[double]$args[3]; $g=[double]$args[4]; $y=[double]$args[5]
$px=[int]($s*$W); $pw=[int]($g*$W); $py=[int]($u*$H); $ph=[int]($y*$H)
$z=8
$serit=26                       # kenarin iki yaninda kac piksel gosterilsin
$dy0=$py+[int]($ph*0.08); $dy1=$py+[int]($ph*0.32)   # gokyuzu bandi, kol yok
$dh=$dy1-$dy0
$hucreW=$serit*2*$z; $hucreH=$dh*$z
$o=New-Object System.Drawing.Bitmap(($hucreW*2+30),$hucreH)
$gr=[System.Drawing.Graphics]::FromImage($o)
$gr.InterpolationMode='NearestNeighbor'
$gr.Clear([System.Drawing.Color]::FromArgb(255,40,40,50))
foreach ($k in 0,1) {
  $kx = if($k -eq 0){$px}else{$px+$pw}
  $sx = $kx-$serit
  $hedef = New-Object System.Drawing.Rectangle(($k*($hucreW+30)),0,$hucreW,$hucreH)
  $kaynak = New-Object System.Drawing.Rectangle($sx,$dy0,($serit*2),$dh)
  $gr.DrawImage($b,$hedef,$kaynak,[System.Drawing.GraphicsUnit]::Pixel)
  $pen=New-Object System.Drawing.Pen([System.Drawing.Color]::Red,3)
  $cx = ($k*($hucreW+30)) + $serit*$z
  $gr.DrawLine($pen,$cx,0,$cx,$hucreH)
  $f=New-Object System.Drawing.Font('Arial',22,[System.Drawing.FontStyle]::Bold)
  $et = if($k -eq 0){'SOL'}else{'SAG'}
  $gr.DrawString($et,$f,[System.Drawing.Brushes]::Yellow,($k*($hucreW+30))+6,6)
}
$o.Save($args[1],[System.Drawing.Imaging.ImageFormat]::Png)
$gr.Dispose();$o.Dispose();$b.Dispose()
