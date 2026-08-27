Add-Type -AssemblyName System.Drawing
foreach ($f in (Get-ChildItem $args[0] | Where-Object { $_.Extension -match 'jpg|jpeg|png' } | Sort-Object Name)) {
  $b = [System.Drawing.Bitmap]::FromFile($f.FullName)
  Write-Output ("{0} {1}x{2}" -f $f.Name, $b.Width, $b.Height)
  $b.Dispose()
}
