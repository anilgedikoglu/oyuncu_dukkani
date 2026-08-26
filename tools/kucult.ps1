# ASCII-only. PNG'yi alfa koruyarak verilen genislige olcekler.
Add-Type -AssemblyName System.Drawing
$src=$args[0]; $dst=$args[1]; $gen=[int]$args[2]
$im=[System.Drawing.Bitmap]::FromFile($src)
$yuk=[int][Math]::Round($im.Height * $gen / $im.Width)
$out=New-Object System.Drawing.Bitmap($gen,$yuk,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g=[System.Drawing.Graphics]::FromImage($out)
$g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.DrawImage($im,0,0,$gen,$yuk); $g.Dispose()
$out.Save($dst,[System.Drawing.Imaging.ImageFormat]::Png)
Write-Output ("{0} {1}x{2}" -f (Split-Path $dst -Leaf),$gen,$yuk)
$out.Dispose(); $im.Dispose()
