<#
.SYNOPSIS
    사이드로딩 인증서(.cer)를 진료실 PC의 신뢰 저장소에 등록합니다. (관리자 권한 필요, 1회)

.DESCRIPTION
    자체 서명한 .msix를 설치하려면 그 서명 인증서가 LocalMachine\TrustedPeople에
    등록돼 있어야 합니다. 이 스크립트는 .cer 를 거기에 등록합니다.

.PARAMETER CerPath
    등록할 .cer 경로. 기본값은 이 스크립트 폴더의 eyebottle-sideload.cer.
#>
[CmdletBinding()]
param(
    [string]$CerPath = (Join-Path $PSScriptRoot "eyebottle-sideload.cer")
)

$ErrorActionPreference = "Stop"

# 관리자 권한 확인
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    throw "이 스크립트는 관리자 권한 PowerShell에서 실행해야 합니다."
}

if (-not (Test-Path $CerPath)) {
    throw ".cer 파일을 찾을 수 없습니다: $CerPath"
}

Write-Host "신뢰 저장소에 인증서 등록 중: $CerPath" -ForegroundColor Cyan
Import-Certificate -FilePath $CerPath -CertStoreLocation "Cert:\LocalMachine\TrustedPeople" | Out-Null
Write-Host "등록 완료. 이제 이 인증서로 서명된 .msix를 설치할 수 있습니다." -ForegroundColor Green
