# ASCII-only. Kapi bolgesini kirpip buyutur; kod kutusunu kirmizi cizer.
# kapikirp.ps1 <gorsel> <cikis> <sol> <ust> <gen> <yuk>
Add-Type -AssemblyName System.Drawing
$src=$args[0]; $dst=$args[1]
$s=[double]$args[2]; $u=[double]$args[3]; $gn=[double]$args[4]; $y=[double]$args[5]
$b=[System.Drawing.Bitmap]::FromFile($src); $W=$b.Width; $H=$b.Height
$px=[int]($s*$W); $py=[int]($u*$H); $pw=[int]($gn*$W); $ph=[int]($y*$H)
$mx=[int]($pw*0.55); $my=[int]($ph*0.30)
$cx=[Math]::Max(0,$px-$mx); $cy=[Math]::Max(0,$py-$my)
$cw=[Math]::Min($W-$cx,$pw+2*$mx); $ch=[Math]::Min($H-$cy,$ph+2*$my)
$z=3.0
$o=New-Object System.Drawing.Bitmap([int]($cw*$z),[int]($ch*$z))
$g=[System.Drawing.Graphics]::FromImage($o)
$g.InterpolationMode='HighQualityBicubic'
$g.DrawImage($b,(New-Object System.Drawing.Rectangle(0,0,[int]($cw*$z),[int]($ch*$z))),
  (New-Object System.Drawing.Rectangle($cx,$cy,$cw,$ch)),[System.Drawing.GraphicsUnit]::Pixel)
$pen=New-Object System.Drawing.Pen([System.Drawing.Color]::Red,3)
$g.DrawRectangle($pen,[int](($px-$cx)*$z),[int](($py-$cy)*$z),[int]($pw*$z),[int]($ph*$z))
$o.Save($dst,[System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose();$o.Dispose();$b.Dispose()
