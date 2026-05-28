<#
.SYNOPSIS
    진료실 PC에서 부팅 자동시작 문제 진단 정보를 모아 zip으로 내보냅니다.

.DESCRIPTION
    수집 항목:
      - 설치된 패키지 정보 (Get-AppxPackage)
      - AppxManifest.xml (StartupTask 설정 포함)
      - StartupTask 상태 (Windows 시작프로그램)
      - 앱 로그 폴더 전체 (3단계 fallback 경로 모두 탐색)
      - 시스템 정보 요약
    결과: %USERPROFILE%\Desktop\eyebottle-diag-<날짜시간>.zip

.EXAMPLE
    .\diagnose.ps1
#>
[CmdletBinding()]
param(
    [string]$OutDir = [Environment]::GetFolderPath("Desktop")
)

$ErrorActionPreference = "Continue"
$packagePrefix = "DCD952CB.367669DCDC1D3"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$work = Join-Path $env:TEMP "eyebottle-diag-$stamp"
New-Item -ItemType Directory -Force -Path $work | Out-Null

Write-Host "=== 아이보틀 진단 정보 수집 ===" -ForegroundColor Cyan

# 1) 패키지 정보
$pkg = Get-AppxPackage -Name "$packagePrefix*" -ErrorAction SilentlyContinue
if ($pkg) {
    $pkg | Format-List * | Out-File (Join-Path $work "package-info.txt")
    $manifestPath = Join-Path $pkg.InstallLocation "AppxManifest.xml"
    if (Test-Path $manifestPath) {
        Copy-Item $manifestPath (Join-Path $work "AppxManifest.xml")
    }
    Write-Host "패키지 정보 수집됨: $($pkg.Version)"
} else {
    "설치된 패키지 없음" | Out-File (Join-Path $work "package-info.txt")
    Write-Host "설치된 패키지 없음" -ForegroundColor Yellow
}

# 2) 로그 폴더 (앱 logging_service.dart의 4단계 fallback 경로 전부와 1:1 대응)
#    주의: MSIX 컨테이너에서는 %APPDATA%/%LOCALAPPDATA%가 Packages\<family>\LocalCache\
#    아래로 리디렉션된다. 또한 path_provider의 ApplicationSupport는
#    %APPDATA%\<CompanyName>\<ProductName> 로 풀리는데, 현재 Runner.rc 기준
#    CompanyName=com.example, ProductName=medical_recorder 이므로 support fallback의
#    실제 경로는 ...\LocalCache\Roaming\com.example\medical_recorder\logs 다.
$logCandidates = @(
    # 1순위 documents (비패키지 + 패키지 Documents 리디렉션)
    (Join-Path $env:USERPROFILE "Documents\EyebottleRecorder\logs"),
    (Join-Path $env:LOCALAPPDATA "Packages\$($packagePrefix)_*\LocalState\Documents\EyebottleRecorder\logs"),
    # 2순위 support: getApplicationSupportDirectory()\logs = APPDATA\com.example\medical_recorder\logs
    (Join-Path $env:APPDATA "com.example\medical_recorder\logs"),
    (Join-Path $env:LOCALAPPDATA "Packages\$($packagePrefix)_*\LocalCache\Roaming\com.example\medical_recorder\logs"),
    # 3순위 localappdata: %LOCALAPPDATA%\EyebottleRecorder\logs (+ 패키지 LocalCache\Local 리디렉션)
    (Join-Path $env:LOCALAPPDATA "EyebottleRecorder\logs"),
    (Join-Path $env:LOCALAPPDATA "Packages\$($packagePrefix)_*\LocalCache\Local\EyebottleRecorder\logs"),
    # 4순위 temp
    (Join-Path $env:TEMP "EyebottleRecorder\logs"),
    (Join-Path $env:LOCALAPPDATA "Packages\$($packagePrefix)_*\LocalCache\Local\Temp\EyebottleRecorder\logs")
)
$logDest = Join-Path $work "logs"
New-Item -ItemType Directory -Force -Path $logDest | Out-Null
$foundLogs = $false
foreach ($pattern in $logCandidates) {
    $dirs = Get-ChildItem -Path (Split-Path $pattern -Parent) -Filter (Split-Path $pattern -Leaf) -Directory -ErrorAction SilentlyContinue
    foreach ($d in $dirs) {
        $files = Get-ChildItem $d.FullName -Filter "*.log" -ErrorAction SilentlyContinue
        if ($files) {
            $sub = Join-Path $logDest ($d.FullName -replace '[:\\]', '_')
            New-Item -ItemType Directory -Force -Path $sub | Out-Null
            $files | Copy-Item -Destination $sub
            $foundLogs = $true
        }
    }
    # 패턴에 와일드카드가 없는 단순 경로도 직접 확인
    if ((Test-Path $pattern) -and (Get-ChildItem $pattern -Filter "*.log" -ErrorAction SilentlyContinue)) {
        $sub = Join-Path $logDest ($pattern -replace '[:\\]', '_')
        New-Item -ItemType Directory -Force -Path $sub | Out-Null
        Get-ChildItem $pattern -Filter "*.log" | Copy-Item -Destination $sub
        $foundLogs = $true
    }
}
if ($foundLogs) {
    Write-Host "로그 파일 수집됨" -ForegroundColor Green
} else {
    "어떤 fallback 경로에서도 로그 파일을 찾지 못함" | Out-File (Join-Path $logDest "NO-LOGS-FOUND.txt")
    Write-Host "로그 파일 없음 (모든 경로 탐색 실패)" -ForegroundColor Yellow
}

# 3) 시작프로그램 상태
Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue |
    Format-Table -AutoSize | Out-File (Join-Path $work "startup-commands.txt")

# 4) 시스템 요약
@(
    "OS: $((Get-CimInstance Win32_OperatingSystem).Caption) $((Get-CimInstance Win32_OperatingSystem).Version)",
    "수집 시각: $(Get-Date -Format o)",
    "사용자: $env:USERNAME"
) | Out-File (Join-Path $work "system-summary.txt")

# 5) zip
$zipPath = Join-Path $OutDir "eyebottle-diag-$stamp.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$work\*" -DestinationPath $zipPath
Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "진단 zip 생성 완료:" -ForegroundColor Green
Write-Host "  $zipPath"
Write-Host "이 파일을 개발자에게 전달하세요."
