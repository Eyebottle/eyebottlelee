<#
.SYNOPSIS
    아이보틀 진료녹음 사이드로딩용 자체 서명 코드 사인 인증서를 생성합니다.

.DESCRIPTION
    MS Store 제출을 거치지 않고 진료실 PC에서 직접 .msix를 설치(sideload)하여
    실전 테스트하기 위한 인증서를 발급합니다.

    중요: 인증서의 Subject(CN)는 반드시 MSIX 매니페스트의 publisher와
    "정확히" 일치해야 합니다. 일치하지 않으면 Add-AppxPackage가 거부합니다.
    현재 매니페스트(pubspec.yaml msix_config.publisher):
        CN=0CEBC30B-3CD4-4E21-A48A-421AE62E38D3

.PARAMETER Publisher
    인증서 Subject. 기본값은 현재 매니페스트와 동일.

.PARAMETER OutDir
    .pfx / .cer 출력 폴더. 기본값은 이 스크립트와 같은 폴더.

.EXAMPLE
    .\create-cert.ps1
    # 실행 후 비밀번호를 프롬프트로 입력하면 eyebottle-sideload.pfx/.cer 생성
#>
[CmdletBinding()]
param(
    [string]$Publisher = "CN=0CEBC30B-3CD4-4E21-A48A-421AE62E38D3",
    [string]$OutDir = $PSScriptRoot
)

$ErrorActionPreference = "Stop"

Write-Host "=== 아이보틀 사이드로딩 인증서 생성 ===" -ForegroundColor Cyan
Write-Host "Publisher (CN): $Publisher"
Write-Host "출력 폴더      : $OutDir"
Write-Host ""

# 비밀번호 입력 (스크립트에 하드코딩하지 않음 — 보안)
$securePassword = Read-Host -Prompt "PFX 보호 비밀번호를 입력하세요" -AsSecureString
if (-not $securePassword -or $securePassword.Length -eq 0) {
    throw "비밀번호가 비어 있습니다. 다시 실행하세요."
}

$cert = New-SelfSignedCertificate `
    -Type CodeSigningCert `
    -Subject $Publisher `
    -KeyUsage DigitalSignature `
    -FriendlyName "Eyebottle Sideload (DO NOT SHIP)" `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}") `
    -NotAfter (Get-Date).AddYears(2)

Write-Host "인증서 생성됨: Thumbprint=$($cert.Thumbprint)" -ForegroundColor Green

$pfxPath = Join-Path $OutDir "eyebottle-sideload.pfx"
$cerPath = Join-Path $OutDir "eyebottle-sideload.cer"

Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $securePassword | Out-Null
Export-Certificate   -Cert $cert -FilePath $cerPath | Out-Null

Write-Host ""
Write-Host "생성 완료:" -ForegroundColor Green
Write-Host "  PFX (서명용, 비공개): $pfxPath"
Write-Host "  CER (신뢰 등록용)   : $cerPath"
Write-Host ""
Write-Host "다음 단계:" -ForegroundColor Yellow
Write-Host "  1) 진료실 PC에 .cer 를 전달하고 install-cert.ps1 로 신뢰 등록 (1회)"
Write-Host "  2) 빌드 시 .pfx 로 서명 (build-sideload.ps1 또는 msix:create --certificate-path)"
Write-Host ""
Write-Host "주의: .pfx 는 절대 git/배포에 포함하지 마세요 (.gitignore 등록됨)." -ForegroundColor Red
