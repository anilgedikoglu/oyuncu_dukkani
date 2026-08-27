# ASCII-only. Kenardan flood-fill ile SIYAH zemini seffaflastirir.
Add-Type -AssemblyName System.Drawing
$src=$args[0]; $dst=$args[1]
$b=[System.Drawing.Bitmap]::FromFile($src)
$c=New-Object System.Drawing.Bitmap($b); $b.Dispose()
$w=$c.Width; $h=$c.Height
$gorulen=New-Object 'bool[,]' $w,$h
$kuyruk=New-Object System.Collections.Generic.Queue[int[]]
for ($x=0; $x -lt $w; $x++) { $kuyruk.Enqueue(@($x,0)); $kuyruk.Enqueue(@($x,$h-1)) }
for ($y=0; $y -lt $h; $y++) { $kuyruk.Enqueue(@(0,$y)); $kuyruk.Enqueue(@($w-1,$y)) }
$bos=[System.Drawing.Color]::FromArgb(0,0,0,0)
$sayac=0
while ($kuyruk.Count -gt 0) {
  $n=$kuyruk.Dequeue(); $x=$n[0]; $y=$n[1]
  if ($x -lt 0 -or $y -lt 0 -or $x -ge $w -or $y -ge $h) { continue }
  if ($gorulen[$x,$y]) { continue }
  $gorulen[$x,$y]=$true
  $p=$c.GetPixel($x,$y)
  if ($p.R -gt 22 -or $p.G -gt 22 -or $p.B -gt 22) { continue }
  $c.SetPixel($x,$y,$bos); $sayac++
  $kuyruk.Enqueue(@(($x+1),$y)); $kuyruk.Enqueue(@(($x-1),$y))
  $kuyruk.Enqueue(@($x,($y+1))); $kuyruk.Enqueue(@($x,($y-1)))
}
$c.Save($dst,[System.Drawing.Imaging.ImageFormat]::Png)
Write-Output ("temizlendi: $sayac piksel")
$c.Dispose()
