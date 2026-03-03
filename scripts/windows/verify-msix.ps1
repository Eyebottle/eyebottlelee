Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead('C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix')

Write-Host "FILES:"
foreach ($e in $zip.Entries) {
  if ($e.Name -match 'AppxManifest|ffmpeg|medical_recorder\.exe') {
    $s = [math]::Round($e.Length / 1MB, 1)
    Write-Host "  $($e.FullName) ($s MB)"
  }
}

$manifest = $zip.GetEntry('AppxManifest.xml')
$reader = New-Object System.IO.StreamReader($manifest.Open())
$content = $reader.ReadToEnd()
$reader.Close()
$zip.Dispose()

Set-Content -Path 'C:\ws-workspace\_manifest.txt' -Value $content -Encoding UTF8
Write-Host "MANIFEST saved to C:\ws-workspace\_manifest.txt"
