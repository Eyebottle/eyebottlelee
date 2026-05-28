<#
.SYNOPSIS
    빌드된 .msix가 제출 가능한 상태인지 자동 검증합니다 (제출 전 사전 점검).

.DESCRIPTION
    잘못된 빌드(구버전 코드, 누락된 capability, ffmpeg 누락 등)를 MS Store에
    올리는 실수를 막기 위한 게이트입니다. 모든 항목 통과 시 종료 코드 0,
    하나라도 실패 시 1 + 사유를 출력합니다.

    검사 항목:
      1. 파일 존재 + 크기 합리성 (>= 50MB)
      2. AppxManifest.xml의 Identity Version == pubspec.yaml의 msix_version
      3. StartupTask(Parameters="--autostart") 존재
      4. windows.startupTask DesktopExtension 존재
      5. Capabilities: microphone / internetClient / runFullTrust 모두 존재
      6. ffmpeg.exe 자산 포함
      7. 빌드 시각이 git HEAD 커밋 시각 이후인지 (이전이면 경고)

.PARAMETER MsixPath
    검사할 .msix 경로. 기본값: build\windows\x64\runner\Release\medical_recorder.msix
#>
[CmdletBinding()]
param(
    [string]$MsixPath = "build\windows\x64\runner\Release\medical_recorder.msix"
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$failures = @()
$warnings = @()

function Fail($msg) { $script:failures += $msg; Write-Host "  [FAIL] $msg" -ForegroundColor Red }
function Pass($msg) { Write-Host "  [ OK ] $msg" -ForegroundColor Green }
function Warn($msg) { $script:warnings += $msg; Write-Host "  [WARN] $msg" -ForegroundColor Yellow }

Write-Host "=== MSIX 사전 점검 ===" -ForegroundColor Cyan

$fullMsix = if ([System.IO.Path]::IsPathRooted($MsixPath)) { $MsixPath } else { Join-Path $repoRoot $MsixPath }
Write-Host "대상: $fullMsix"
Write-Host ""

# 1) 파일 존재 + 크기
if (-not (Test-Path $fullMsix)) {
    Fail "파일이 존재하지 않음: $fullMsix"
    Write-Host "사전 점검 중단." -ForegroundColor Red
    exit 1
}
$sizeMB = [math]::Round((Get-Item $fullMsix).Length / 1MB, 1)
if ($sizeMB -ge 50) { Pass "파일 크기 ${sizeMB}MB (>=50MB)" }
else { Fail "파일 크기 ${sizeMB}MB — 너무 작음 (ffmpeg 누락 의심)" }

# pubspec의 msix_version 읽기
$pubspec = Get-Content (Join-Path $repoRoot "pubspec.yaml") -Raw
$expectedVersion = $null
if ($pubspec -match "msix_version:\s*([0-9.]+)") { $expectedVersion = $Matches[1] }

# 매니페스트 추출 (msix = zip)
Add-Type -AssemblyName System.IO.Compression.FileSystem
$tmp = Join-Path $env:TEMP ("msix-verify-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
try {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($fullMsix)
    try {
        $manifestEntry = $zip.Entries | Where-Object { $_.FullName -eq "AppxManifest.xml" }
        if (-not $manifestEntry) {
            Fail "AppxManifest.xml 을 패키지에서 찾을 수 없음"
        } else {
            $manifestPath = Join-Path $tmp "AppxManifest.xml"
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($manifestEntry, $manifestPath, $true)
            [xml]$manifest = Get-Content $manifestPath

            # 2) 버전 일치
            $identityVersion = $manifest.Package.Identity.Version
            if ($expectedVersion) {
                # msix_version은 1.3.17.0, Identity도 1.3.17.0 형식
                if ($identityVersion -eq $expectedVersion) {
                    Pass "버전 일치: $identityVersion"
                } else {
                    Fail "버전 불일치: 매니페스트=$identityVersion, pubspec=$expectedVersion"
                }
            } else {
                Warn "pubspec.yaml에서 msix_version을 읽지 못해 버전 대조 생략"
            }

            $xml = $manifest.OuterXml

            # 3) StartupTask --autostart
            if ($xml -match 'startupTask' -and $xml -match '--autostart') {
                Pass "StartupTask(--autostart) 존재"
            } else {
                Fail "StartupTask(--autostart) 설정을 찾을 수 없음"
            }

            # 4) windows.startupTask DesktopExtension
            if ($xml -match 'Category="windows.startupTask"') {
                Pass "windows.startupTask DesktopExtension 존재"
            } else {
                Fail "windows.startupTask DesktopExtension 누락"
            }

            # 5) Capabilities
            foreach ($cap in @("microphone", "internetClient", "runFullTrust")) {
                if ($xml -match $cap) { Pass "Capability '$cap' 존재" }
                else { Fail "Capability '$cap' 누락" }
            }
        }

        # 6) ffmpeg.exe 포함
        $ffmpeg = $zip.Entries | Where-Object { $_.FullName -like "*ffmpeg.exe" }
        if ($ffmpeg) { Pass "ffmpeg.exe 포함 ($([math]::Round($ffmpeg.Length/1MB,1))MB)" }
        else { Fail "ffmpeg.exe 자산 누락 (WAV 변환 깨짐)" }
    }
    finally {
        $zip.Dispose()
    }

    # 7) 빌드 시각 vs git HEAD (git 작업트리가 아닐 수 있음 — 예: 비-git 빌드 복사본)
    $buildTime = (Get-Item $fullMsix).LastWriteTime
    $gitAvailable = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
    $isGitRepo = Test-Path (Join-Path $repoRoot ".git")
    if ($gitAvailable -and $isGitRepo) {
        Push-Location $repoRoot
        try {
            $headEpoch = (git log -1 --format=%ct 2>$null | Out-String).Trim()
            if ($headEpoch) {
                $headTime = [DateTimeOffset]::FromUnixTimeSeconds([long]$headEpoch).LocalDateTime
                if ($buildTime -ge $headTime) {
                    Pass "빌드 시각($buildTime)이 HEAD 커밋($headTime) 이후"
                } else {
                    Warn "빌드 시각($buildTime)이 HEAD 커밋($headTime)보다 이전 — 재빌드 권장"
                }
            }
        } finally {
            Pop-Location
        }
    } else {
        Warn "git 작업트리가 아니어서 빌드 시각 vs HEAD 비교를 생략 (빌드 시각: $buildTime)"
    }
}
finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
if ($failures.Count -eq 0) {
    if ($warnings.Count -gt 0) {
        Write-Host "통과 (경고 $($warnings.Count)건 — 검토 권장)" -ForegroundColor Yellow
    } else {
        Write-Host "모든 항목 통과. 제출 가능." -ForegroundColor Green
    }
    exit 0
} else {
    Write-Host "$($failures.Count)개 항목 실패 — 제출 금지." -ForegroundColor Red
    exit 1
}
