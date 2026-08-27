# ASCII-only. CD tuvali: 392x512, icerik yuksekligin %83'u, yatay ortali, dikey ortali.
Add-Type -AssemblyName System.Drawing
$src=$args[0]; $dst=$args[1]
$W=392; $H=512; $fill=0.83
$b=[System.Drawing.Bitmap]::FromFile($src)
$bw=$b.Width; $bh=$b.Height
$minx=$bw; $miny=$bh; $maxx=-1; $maxy=-1
for ($y=0; $y -lt $bh; $y++) { for ($x=0; $x -lt $bw; $x++) {
  if ($b.GetPixel($x,$y).A -gt 12) {
    if ($x -lt $minx) {$minx=$x}; if ($x -gt $maxx) {$maxx=$x}
    if ($y -lt $miny) {$miny=$y}; if ($y -gt $maxy) {$maxy=$y}
  } } }
$cw=$maxx-$minx+1; $ch=$maxy-$miny+1
$hedef = $H * $fill
$olcek = $hedef / $ch
if (($cw * $olcek) -gt ($W * 0.95)) { $olcek = ($W * 0.95) / $cw }
$nw=[int][Math]::Round($cw*$olcek); $nh=[int][Math]::Round($ch*$olcek)
$ox=[int][Math]::Round(($W-$nw)/2.0); $oy=[int][Math]::Round(($H-$nh)/2.0)
$out=New-Object System.Drawing.Bitmap($W,$H,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g=[System.Drawing.Graphics]::FromImage($out)
$g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$sr=New-Object System.Drawing.Rectangle($minx,$miny,$cw,$ch)
$dr=New-Object System.Drawing.Rectangle($ox,$oy,$nw,$nh)
$g.DrawImage($b,$dr,$sr,[System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose(); $out.Save($dst,[System.Drawing.Imaging.ImageFormat]::Png)
Write-Output ("OK {0} {1}x{2}" -f (Split-Path $dst -Leaf),$nw,$nh)
$out.Dispose(); $b.Dispose()
