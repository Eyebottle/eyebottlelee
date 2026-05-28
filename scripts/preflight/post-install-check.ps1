<#
.SYNOPSIS
    사이드로딩 설치 직후 헬스체크 — 설치/매니페스트/StartupTask 상태를 확인합니다.

.EXAMPLE
    .\post-install-check.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$packagePrefix = "DCD952CB.367669DCDC1D3"

Write-Host "=== 설치 직후 헬스체크 ===" -ForegroundColor Cyan

$pkg = Get-AppxPackage -Name "$packagePrefix*" -ErrorAction SilentlyContinue
if (-not $pkg) {
    Write-Host "[FAIL] 패키지가 설치되어 있지 않습니다." -ForegroundColor Red
    exit 1
}
Write-Host "[ OK ] 설치됨: $($pkg.PackageFullName) (v$($pkg.Version))" -ForegroundColor Green

$manifestPath = Join-Path $pkg.InstallLocation "AppxManifest.xml"
if (Test-Path $manifestPath) {
    $xml = (Get-Content $manifestPath -Raw)
    if ($xml -match 'startupTask' -and $xml -match '--autostart') {
        Write-Host "[ OK ] StartupTask(--autostart) 매니페스트 확인" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] 매니페스트에 StartupTask(--autostart) 없음" -ForegroundColor Red
    }
} else {
    Write-Host "[WARN] AppxManifest.xml 을 찾을 수 없음" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Windows 시작프로그램 상태:" -ForegroundColor Cyan
Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue |
    Where-Object { $_.Command -like "*Eyebottle*" -or $_.Name -like "*Eyebottle*" } |
    Format-Table Name, Command, Location -AutoSize

Write-Host "헬스체크 완료. 이제 재부팅하여 STARTUP-TEST-MATRIX 시나리오를 진행하세요."
