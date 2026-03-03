# MSIX Verification Script for v1.3.11
# Run in PowerShell on Windows

$msix = 'C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix'

Write-Host '=== MSIX Manifest Check ==='
Add-Type -Assembly System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($msix)
$manifest = $zip.Entries | Where-Object { $_.Name -eq 'AppxManifest.xml' }
$sr = New-Object System.IO.StreamReader($manifest.Open())
$content = $sr.ReadToEnd()
$sr.Close()

if ($content -match 'Version="([^"]+)"') { Write-Host "Version: $($Matches[1])" }
if ($content -match 'Identity Name="([^"]+)"') { Write-Host "Identity: $($Matches[1])" }
if ($content -match 'Publisher="([^"]+)"') { Write-Host "Publisher: $($Matches[1])" }
if ($content -match 'StartupTask') {
    Write-Host 'StartupTask: FOUND'
} else {
    Write-Host 'StartupTask: NOT FOUND (WARNING!)'
}

Write-Host ''
Write-Host '=== Capabilities ==='
[regex]::Matches($content, '<(?:uap:)?Capability Name="([^"]+)"') | ForEach-Object { Write-Host "  - $($_.Groups[1].Value)" }
[regex]::Matches($content, '<rescap:Capability Name="([^"]+)"') | ForEach-Object { Write-Host "  - $($_.Groups[1].Value) (restricted)" }

Write-Host ''
Write-Host '=== Dependencies ==='
[regex]::Matches($content, 'PackageDependency Name="([^"]+)"') | ForEach-Object { Write-Host "  - $($_.Groups[1].Value)" }

Write-Host ''
Write-Host '=== File Count ==='
$total = $zip.Entries.Count
$exes = ($zip.Entries | Where-Object { $_.Name -like '*.exe' }).Count
$dlls = ($zip.Entries | Where-Object { $_.Name -like '*.dll' }).Count
Write-Host "Total: $total, EXE: $exes, DLL: $dlls"
$zip.Dispose()

Write-Host ''
Write-Host '=== DONE ==='
