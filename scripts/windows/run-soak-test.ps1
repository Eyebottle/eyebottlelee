[CmdletBinding()]
param(
    [double]$DurationHours = 8,
    [string]$OutputRoot = 'C:\ws-workspace\eyebottlelee\soak-logs',
    [switch]$SkipBuild,
    [switch]$LeaveRunning
)

$ErrorActionPreference = 'Stop'

function Resolve-FlutterBat {
    if ($env:FLUTTER_WIN_HOME) {
        $candidate = Join-Path $env:FLUTTER_WIN_HOME 'bin\flutter.bat'
        if (Test-Path $candidate) { return $candidate }
    }
    $default = 'C:\flutter\bin\flutter.bat'
    if (Test-Path $default) { return $default }
    throw 'Unable to find flutter.bat. Set FLUTTER_WIN_HOME or install Flutter under C:\flutter.'
}

$repoRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
Set-Location $repoRoot

$flutterBat = Resolve-FlutterBat
$releaseExe = Join-Path $repoRoot 'build\windows\x64\runner\Release\medical_recorder.exe'

if (-not $SkipBuild) {
    & $flutterBat build windows --release
}

if (-not (Test-Path $releaseExe)) {
    throw "Release executable not found: $releaseExe"
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$sessionRoot = Join-Path $OutputRoot $timestamp
$logsTarget = Join-Path $sessionRoot 'logs'
$metricsFile = Join-Path $sessionRoot 'metrics.csv'
$notesFile = Join-Path $sessionRoot 'session-notes.txt'

New-Item -ItemType Directory -Path $sessionRoot -Force | Out-Null
New-Item -ItemType Directory -Path $logsTarget -Force | Out-Null

"timestamp,elapsedSeconds,workingSetMB,totalProcessorSeconds" | Out-File -FilePath $metricsFile -Encoding utf8

$process = Start-Process -FilePath $releaseExe -PassThru
$startTime = Get-Date
$deadline = $startTime.AddHours($DurationHours)

while (-not $process.HasExited -and (Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 60
    try {
        $current = Get-Process -Id $process.Id -ErrorAction Stop
        $elapsed = (Get-Date) - $startTime
        $row = '{0},{1},{2},{3}' -f (
            (Get-Date).ToString('s'),
            [Math]::Round($elapsed.TotalSeconds, 1),
            [Math]::Round($current.WorkingSet64 / 1MB, 2),
            [Math]::Round($current.TotalProcessorTime.TotalSeconds, 2)
        )
        Add-Content -Path $metricsFile -Value $row -Encoding utf8
    } catch {
        if ($process.HasExited) { break }
    }
}

if (-not $process.HasExited -and -not $LeaveRunning) {
    Stop-Process -Id $process.Id -Force
    $process.WaitForExit()
}

$documents = [Environment]::GetFolderPath('MyDocuments')
$logSource = Join-Path $documents 'EyebottleRecorder\logs'
if (Test-Path $logSource) {
    Copy-Item -Path (Join-Path $logSource '*') -Destination $logsTarget -Recurse -Force
}

$endTime = Get-Date
$lines = @()
$lines += "start: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))"
$lines += "end: $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))"
$lines += "elapsedHours: $([Math]::Round(($endTime - $startTime).TotalHours, 2))"
$lines += "buildInvoked: $([bool](-not $SkipBuild))"
$lines += "appPath: $releaseExe"
$lines += "logSource: $logSource"
$lines += "leaveRunning: $([bool]$LeaveRunning)"
$lines | Out-File -FilePath $notesFile -Encoding utf8

Write-Host "Soak test session complete." -ForegroundColor Green
Write-Host "Artifacts saved to: $sessionRoot"
