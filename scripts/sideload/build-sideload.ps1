<#
.SYNOPSIS
    사이드로딩용 .msix를 빌드하고 자체 서명한 뒤 버전/날짜 라벨을 붙입니다.

.DESCRIPTION
    진료실 PC에서 MS Store를 거치지 않고 직접 설치(sideload)할 수 있는, 자체
    서명된 .msix를 만듭니다.

    중요: msix 패키지는 pubspec.yaml의 `msix_config.store: true`가 있으면 store
    모드로 동작하여 **서명 단계를 통째로 건너뜁니다**(미서명 패키지 → 사이드로딩
    설치 불가). `--store` 는 boolean 플래그라 `--store false` 로는 끌 수 없고,
    yaml의 `store: true` 가 항상 우선합니다. 따라서 이 스크립트는 빌드 동안에만
    pubspec.yaml의 `store: true` → `store: false` 로 임시 치환했다가 finally에서
    원본을 그대로 복원합니다. Store 제출용 빌드(`store: true`)에는 영향이 없습니다.

    빌드 후 산출물을 medical_recorder-sideload-<버전>-<날짜시간>.msix 로 복사하고
    서명 여부를 검증합니다.

.PARAMETER PfxPath
    서명용 .pfx 경로. 기본값: scripts/sideload/eyebottle-sideload.pfx

.EXAMPLE
    .\build-sideload.ps1
    # 비밀번호 프롬프트 후 빌드 → dist 폴더에 라벨링된 서명 msix 생성
#>
[CmdletBinding()]
param(
    [string]$PfxPath = (Join-Path $PSScriptRoot "eyebottle-sideload.pfx")
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$pubspecPath = Join-Path $repoRoot "pubspec.yaml"

# finally에서 안전하게 접근/해제하기 위해 try 밖에서 선언
$bstr = [IntPtr]::Zero
$plainPassword = $null
$origPubspec = $null

Push-Location $repoRoot
try {
    if (-not (Test-Path $PfxPath)) {
        throw "서명용 .pfx가 없습니다: $PfxPath  (먼저 create-cert.ps1 실행)"
    }

    $securePassword = Read-Host -Prompt "PFX 비밀번호" -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)

    # 매니페스트 버전 추출 (pubspec.yaml의 msix_version)
    $origPubspec = Get-Content $pubspecPath -Raw
    $version = "unknown"
    if ($origPubspec -match "msix_version:\s*([0-9.]+)") {
        $version = $Matches[1]
    }

    # store: true → false 로 임시 치환 (서명이 실행되도록). 들여쓰기 보존.
    $sideloadPubspec = [regex]::Replace(
        $origPubspec, '(?m)^(\s*)store:\s*true\s*$', '${1}store: false')
    if ($sideloadPubspec -eq $origPubspec) {
        Write-Host "경고: pubspec.yaml에서 'store: true' 를 찾지 못했습니다. " -ForegroundColor Yellow
        Write-Host "      이미 false거나 형식이 다를 수 있습니다. 빌드 후 서명 검증으로 확인합니다."
    }
    Set-Content -Path $pubspecPath -Value $sideloadPubspec -NoNewline

    Write-Host "=== 사이드로딩 빌드 (v$version, store=false 임시 적용) ===" -ForegroundColor Cyan
    Write-Host "1) flutter build windows --release"
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build 실패" }

    Write-Host "2) msix:create (자체 서명)"
    flutter pub run msix:create `
        --certificate-path $PfxPath `
        --certificate-password $plainPassword
    if ($LASTEXITCODE -ne 0) { throw "msix:create 실패" }

    # 산출물명은 pubspec name(medical_recorder) 기준. 혹시 다를 경우 최신 msix로 폴백.
    $releaseDir = Join-Path $repoRoot "build\windows\x64\runner\Release"
    $built = Join-Path $releaseDir "medical_recorder.msix"
    if (-not (Test-Path $built)) {
        $latest = Get-ChildItem $releaseDir -Filter *.msix -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $latest) { throw "빌드 산출물(.msix)을 찾을 수 없음: $releaseDir" }
        $built = $latest.FullName
    }

    # 서명 검증 — store 모드로 잘못 빌드되면 미서명이므로 사이드로딩이 불가하다.
    $sig = Get-AuthenticodeSignature $built
    if ($sig.Status -ne 'Valid' -and $sig.SignerCertificate -eq $null) {
        throw "산출물이 서명되지 않았습니다(Status=$($sig.Status)). " +
              "pubspec의 store 설정이 false로 적용됐는지 확인하세요. 사이드로딩 불가."
    }
    Write-Host "서명 확인: Status=$($sig.Status), Signer=$($sig.SignerCertificate.Subject)" -ForegroundColor Green

    $stamp = Get-Date -Format "yyyyMMdd-HHmm"
    $dist = Join-Path $repoRoot "dist"
    New-Item -ItemType Directory -Force -Path $dist | Out-Null
    $labeled = Join-Path $dist "medical_recorder-sideload-$version-$stamp.msix"
    Copy-Item $built $labeled -Force

    Write-Host ""
    Write-Host "사이드로딩 빌드 완료:" -ForegroundColor Green
    Write-Host "  $labeled"
    Write-Host "진료실 PC로 전달 후 install.ps1 로 설치하세요."
}
finally {
    # pubspec.yaml 원본 복원 (store: true 등 모든 원상복귀)
    if ($origPubspec -ne $null) {
        Set-Content -Path $pubspecPath -Value $origPubspec -NoNewline
    }
    # 평문 비밀번호가 담긴 비관리 BSTR 메모리를 제로화/해제
    if ($bstr -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        $bstr = [IntPtr]::Zero
    }
    $plainPassword = $null
    Pop-Location
}
