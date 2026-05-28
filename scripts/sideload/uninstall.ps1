<#
.SYNOPSIS
    설치된 아이보틀 진료녹음 패키지를 제거합니다.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$packagePrefix = "DCD952CB.367669DCDC1D3"

$pkg = Get-AppxPackage -Name "$packagePrefix*" -ErrorAction SilentlyContinue
if ($pkg) {
    Write-Host "제거 중: $($pkg.PackageFullName)" -ForegroundColor Yellow
    $pkg | Remove-AppxPackage
    Write-Host "제거 완료." -ForegroundColor Green
} else {
    Write-Host "설치된 패키지가 없습니다."
}
