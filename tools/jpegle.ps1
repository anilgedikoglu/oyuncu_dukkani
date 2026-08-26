Add-Type -AssemblyName System.Drawing
$src=$args[0]; $dst=$args[1]; $w=[int]$args[2]; $q=[int]$args[3]
$im=[System.Drawing.Bitmap]::FromFile($src)
$h=[int]($im.Height * $w / $im.Width)
$bmp=New-Object System.Drawing.Bitmap($w,$h)
$g=[System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.Clear([System.Drawing.Color]::Black)
$g.DrawImage($im,0,0,$w,$h); $g.Dispose()
$enc=[System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object {$_.MimeType -eq 'image/jpeg'}
$ps=New-Object System.Drawing.Imaging.EncoderParameters(1)
$ps.Param[0]=New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, $q)
$bmp.Save($dst,$enc,$ps); $bmp.Dispose(); $im.Dispose()
Write-Output ("OK {0}x{1}" -f $w,$h)
