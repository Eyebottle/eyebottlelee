# MSIX 패키지 빌드 스크립트
# 사용법: pwsh -File scripts/windows/build-msix.ps1

param(
    [string]$OutputDir = "C:\Users\user\OneDrive\이안과\eyebottlelee-msix-latest"
)

Write-Host "=== 아이보틀 진료녹음 MSIX 패키지 빌드 ===" -ForegroundColor Cyan
Write-Host ""

# 1. 빌드 디렉터리 확인
$BuildDir = "C:\ws-workspace\eyebottlelee"
if (-not (Test-Path $BuildDir)) {
    Write-Host "❌ 빌드 디렉터리를 찾을 수 없습니다: $BuildDir" -ForegroundColor Red
    Write-Host "WSL에서 Windows로 코드를 동기화했는지 확인하세요." -ForegroundColor Yellow
    Write-Host "동기화 명령: bash scripts/sync_wsl_to_windows.sh" -ForegroundColor Yellow
    exit 1
}

Write-Host "📂 빌드 디렉터리: $BuildDir" -ForegroundColor Green
Set-Location $BuildDir

# 2. Flutter 버전 확인
Write-Host ""
Write-Host "🔍 Flutter 버전 확인 중..." -ForegroundColor Cyan
flutter --version | Select-Object -First 1

# 3. pubspec.yaml 버전 확인
Write-Host ""
Write-Host "📋 버전 정보 확인 중..." -ForegroundColor Cyan
$pubspecContent = Get-Content "pubspec.yaml" -Raw
if ($pubspecContent -match "version:\s*([\d.]+)\+(\d+)") {
    $appVersion = $matches[1]
    $buildNumber = $matches[2]
    Write-Host "  앱 버전: $appVersion+$buildNumber" -ForegroundColor Gray
}
if ($pubspecContent -match "msix_version:\s*([\d.]+)") {
    $msixVersion = $matches[1]
    Write-Host "  MSIX 버전: $msixVersion" -ForegroundColor Gray
}

# 4. 의존성 업데이트
Write-Host ""
Write-Host "📦 의존성 업데이트 중..." -ForegroundColor Cyan
flutter pub get

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 의존성 업데이트 실패" -ForegroundColor Red
    exit 1
}

# 5. Release 빌드
Write-Host ""
Write-Host "🔨 Release 빌드 시작..." -ForegroundColor Cyan
Write-Host "  예상 소요 시간: 30-40초" -ForegroundColor Gray
Write-Host ""

flutter build windows --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 빌드 실패" -ForegroundColor Red
    exit 1
}

# 6. 빌드 결과 확인
$ReleasePath = Join-Path $BuildDir "build\windows\x64\runner\Release"
if (-not (Test-Path $ReleasePath)) {
    Write-Host "❌ Release 폴더를 찾을 수 없습니다" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ Release 빌드 완료: $ReleasePath" -ForegroundColor Green

# 7. MSIX 패키지 생성
Write-Host ""
Write-Host "📦 MSIX 패키지 생성 중..." -ForegroundColor Cyan
Write-Host "  예상 소요 시간: 20-30초" -ForegroundColor Gray
Write-Host ""

dart run msix:create

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ MSIX 생성 실패" -ForegroundColor Red
    exit 1
}

# 8. MSIX 파일 확인
$MsixPath = Join-Path $ReleasePath "medical_recorder.msix"
if (-not (Test-Path $MsixPath)) {
    Write-Host "❌ MSIX 파일을 찾을 수 없습니다: $MsixPath" -ForegroundColor Red
    exit 1
}

$MsixSize = (Get-Item $MsixPath).Length / 1MB
$MsixDate = (Get-Item $MsixPath).LastWriteTime

Write-Host ""
Write-Host "✅ MSIX 패키지 생성 완료!" -ForegroundColor Green
Write-Host "  파일: medical_recorder.msix" -ForegroundColor Gray
Write-Host "  크기: $([math]::Round($MsixSize, 2)) MB" -ForegroundColor Gray
Write-Host "  위치: $MsixPath" -ForegroundColor Gray
Write-Host "  생성 시간: $($MsixDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray

# 9. OneDrive로 복사 (선택적)
if ($OutputDir) {
    Write-Host ""
    Write-Host "📁 OneDrive로 복사 중..." -ForegroundColor Cyan
    
    if (Test-Path $OutputDir) {
        Write-Host "  기존 폴더 삭제 중..." -ForegroundColor Gray
        Remove-Item -Path $OutputDir -Recurse -Force
    }
    
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    
    Write-Host "  MSIX 파일 복사 중..." -ForegroundColor Gray
    Copy-Item -Path $MsixPath -Destination $OutputDir -Force
    
    # 버전 정보 파일 생성
    $VersionInfo = @"
아이보틀 진료 녹음 MSIX 패키지
================================

빌드 날짜: $($MsixDate.ToString('yyyy-MM-dd HH:mm:ss'))
MSIX 버전: $msixVersion
앱 버전: $appVersion+$buildNumber

📦 파일 정보
------------
파일명: medical_recorder.msix
크기: $([math]::Round($MsixSize, 2)) MB
위치: $OutputDir

✅ 빌드 완료
이제 MSIX 테스트 체크리스트를 따라 테스트를 진행하세요!

문서: docs/msix-test-checklist.md
"@
    
    Set-Content -Path (Join-Path $OutputDir "빌드정보.txt") -Value $VersionInfo -Encoding UTF8
    
    Write-Host ""
    Write-Host "✅ OneDrive 복사 완료: $OutputDir" -ForegroundColor Green
}

# 10. 완료 메시지
Write-Host ""
Write-Host "=" * 60 -ForegroundColor Green
Write-Host "✅ MSIX 빌드 완료!" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green
Write-Host ""
Write-Host "📂 MSIX 파일 위치:" -ForegroundColor Cyan
Write-Host "  $MsixPath" -ForegroundColor White
if ($OutputDir) {
    Write-Host ""
    Write-Host "📁 OneDrive 복사본:" -ForegroundColor Cyan
    Write-Host "  $OutputDir" -ForegroundColor White
}
Write-Host ""
Write-Host "다음 단계:" -ForegroundColor Yellow
Write-Host "  1. MSIX 테스트 체크리스트 확인: docs/msix-test-checklist.md" -ForegroundColor White
Write-Host "  2. Windows 개발자 모드 활성화 확인" -ForegroundColor White
Write-Host "  3. PowerShell에서 설치: Add-AppxPackage -Path `"$MsixPath`"" -ForegroundColor White
Write-Host ""

# MSIX 파일 탐색기로 열기
explorer.exe /select,"$MsixPath"

