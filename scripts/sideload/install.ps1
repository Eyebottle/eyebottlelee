<#
.SYNOPSIS
    사이드로딩용 .msix를 설치합니다 (이전 버전 자동 제거 포함).

.DESCRIPTION
    1) 기존 DCD952CB.* 패키지 제거
    2) 인증서 신뢰 등록 여부 확인 (없으면 안내)
    3) 새 .msix 설치 (Add-AppxPackage)
    4) 설치된 버전 확인 출력

.PARAMETER MsixPath
    설치할 .msix 경로 (필수).

.EXAMPLE
    .\install.ps1 -MsixPath .\medical_recorder-sideload-1.3.17-20260529-0930.msix
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$MsixPath
)

$ErrorActionPreference = "Stop"
$packagePrefix = "DCD952CB.367669DCDC1D3"

if (-not (Test-Path $MsixPath)) {
    throw ".msix 파일을 찾을 수 없습니다: $MsixPath"
}

Write-Host "=== 아이보틀 사이드로딩 설치 ===" -ForegroundColor Cyan

# 1) 기존 버전 제거
$existing = Get-AppxPackage -Name "$packagePrefix*" -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "기존 패키지 제거: $($existing.PackageFullName)" -ForegroundColor Yellow
    $existing | Remove-AppxPackage
} else {
    Write-Host "기존 설치 없음."
}

# 2) 인증서 신뢰 확인
$cerThumbprint = Get-ChildItem "Cert:\LocalMachine\TrustedPeople" -ErrorAction SilentlyContinue |
    Where-Object { $_.Subject -like "*0CEBC30B-3CD4-4E21-A48A-421AE62E38D3*" }
if (-not $cerThumbprint) {
    Write-Host "경고: 사이드로딩 인증서가 TrustedPeople에 없습니다." -ForegroundColor Red
    Write-Host "      먼저 관리자 PowerShell에서 install-cert.ps1 을 실행하세요." -ForegroundColor Red
    Write-Host "      (서명 인증서가 신뢰되지 않으면 아래 설치가 실패합니다)"
}

# 3) 설치
Write-Host "설치 중: $MsixPath" -ForegroundColor Cyan
Add-AppxPackage -Path $MsixPath

# 4) 확인
$installed = Get-AppxPackage -Name "$packagePrefix*"
if ($installed) {
    Write-Host ""
    Write-Host "설치 완료:" -ForegroundColor Green
    Write-Host "  PackageFullName: $($installed.PackageFullName)"
    Write-Host "  Version        : $($installed.Version)"
    Write-Host "  InstallLocation: $($installed.InstallLocation)"
} else {
    throw "설치 후 패키지를 찾을 수 없습니다. 설치 실패."
}
