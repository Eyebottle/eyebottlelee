# 마이크 에러 진단용 테스트 릴리즈 빌드 스크립트
# 사용법: pwsh -File scripts/windows/build-test-release.ps1

param(
    [string]$OutputDir = "C:\Users\user\OneDrive\이안과\eyebottlelee-test-release"
)

Write-Host "=== 아이보틀 진료녹음 테스트 릴리즈 빌드 ===" -ForegroundColor Cyan
Write-Host ""

# 1. 빌드 디렉터리 확인
$BuildDir = "C:\ws-workspace\eyebottlelee"
if (-not (Test-Path $BuildDir)) {
    Write-Host "❌ 빌드 디렉터리를 찾을 수 없습니다: $BuildDir" -ForegroundColor Red
    Write-Host "WSL에서 Windows로 코드를 동기화했는지 확인하세요." -ForegroundColor Yellow
    exit 1
}

Write-Host "📂 빌드 디렉터리: $BuildDir" -ForegroundColor Green
Set-Location $BuildDir

# 2. Flutter 버전 확인
Write-Host ""
Write-Host "🔍 Flutter 버전 확인 중..." -ForegroundColor Cyan
flutter --version

# 3. Flutter 캐시 정리 (중요!)
Write-Host ""
Write-Host "🧹 Flutter 빌드 캐시 정리 중..." -ForegroundColor Cyan
flutter clean

# 4. 의존성 업데이트
Write-Host ""
Write-Host "📦 의존성 업데이트 중..." -ForegroundColor Cyan
flutter pub get

# 5. Release 빌드 (디버그 심볼 포함)
Write-Host ""
Write-Host "🔨 Release 빌드 시작 (클린 빌드)..." -ForegroundColor Cyan
Write-Host "  - 최적화: 활성화" -ForegroundColor Gray
Write-Host "  - 디버그 정보: 포함" -ForegroundColor Gray
Write-Host "  - 캐시: 정리됨" -ForegroundColor Gray
Write-Host "" -ForegroundColor Gray

flutter build windows --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 빌드 실패" -ForegroundColor Red
    exit 1
}

# 5. 빌드 결과 확인
$ReleasePath = Join-Path $BuildDir "build\windows\x64\runner\Release"
if (-not (Test-Path $ReleasePath)) {
    Write-Host "❌ Release 폴더를 찾을 수 없습니다" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ 빌드 완료: $ReleasePath" -ForegroundColor Green

# 6. 출력 디렉터리 생성
Write-Host ""
Write-Host "📦 테스트 패키지 생성 중..." -ForegroundColor Cyan
if (Test-Path $OutputDir) {
    Write-Host "  기존 출력 디렉터리 삭제 중..." -ForegroundColor Gray
    Remove-Item -Path $OutputDir -Recurse -Force
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
Write-Host "  출력 디렉터리: $OutputDir" -ForegroundColor Gray

# 7. Release 파일 복사
Write-Host "  Release 파일 복사 중..." -ForegroundColor Gray
Copy-Item -Path "$ReleasePath\*" -Destination $OutputDir -Recurse -Force

# 8. README 파일 생성
$ReadmeContent = @"
# 아이보틀 진료녹음 - 마이크 에러 진단용 테스트 빌드

빌드 날짜: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## 🎯 목적

이 빌드는 마이크 에러를 진단하기 위해 상세한 로그를 수집합니다.

## 📋 테스트 방법

1. **앱 실행**
   - `medical_recorder.exe` 파일을 더블클릭하여 실행합니다.
   - Windows SmartScreen 경고가 나타나면 "추가 정보" > "실행"을 클릭합니다.

2. **마이크 점검**
   - 앱이 시작되면 자동으로 마이크 점검이 실행됩니다.
   - 대시보드에서 "다시 점검" 버튼으로 재검사할 수 있습니다.

3. **진단 정보 확인**
   - 대시보드 우측 마이크 진단 카드에서 **"진단 정보"** 버튼 클릭
   - "진단 정보 복사" 버튼을 눌러 클립보드에 복사
   - 복사한 내용을 텍스트 파일로 저장하거나 지원팀에 전달

4. **로그 파일 위치**
   - 로그 파일은 다음 위치에 저장됩니다:
     \`%USERPROFILE%\Documents\EyebottleRecorder\logs\`
   - 진단 정보 다이얼로그에서 "로그 폴더 열기" 버튼으로 바로 접근 가능

5. **로그 파일 수집**
   - 로그 폴더에서 최신 로그 파일(`eyebottle_YYYYMMDD.log`)을 찾습니다.
   - 파일을 USB나 이메일로 전달해주세요.

## 🐛 에러가 발생했을 때

### 앱이 자동으로 종료되는 경우 (중요!)

**증상**: 앱 실행 후 3초 내에 자동 종료

**가능한 원인**: AAC 코덱이 설치되어 있지 않음

**해결 방법**:

1. **로그 파일 확인**
   - Windows 탐색기 주소창에 입력: \`%USERPROFILE%\Documents\EyebottleRecorder\logs\`
   - 최신 로그 파일 열기 (eyebottle_YYYYMMDD.log)
   - "AAC 코덱" 또는 "encoder" 키워드 검색

2. **Windows 버전 확인**
   - Windows 설정 > 시스템 > 정보
   - 에디션에 "N" 또는 "KN"이 포함되어 있는지 확인

3. **Windows Media Feature Pack 설치**
   - N/KN 에디션인 경우:
     https://support.microsoft.com/ko-kr/topic/media-feature-pack-list-for-windows-n-editions-c1c6fffa-d052-8338-7a79-a4bb980a700a
   - 해당 버전의 Feature Pack 다운로드 및 설치
   - 시스템 재시작 후 앱 재실행

### 일반 에러

1. **앱 실행 직후 마이크 에러**
   - 빨간색 "📋 에러 로그 확인" 버튼 클릭
   - "진단 정보 복사" 버튼으로 정보 복사
   - 로그 폴더에서 최신 로그 파일 수집

2. **녹음 시작 실패**
   - 에러 메시지 스크린샷 저장
   - 로그 파일 확인

3. **권한 에러**
   - Windows 설정 > 개인정보 보호 > 마이크에서 권한 확인

## 📊 수집할 정보

- [ ] 진단 정보 (클립보드 복사) 또는 로그 파일
- [ ] 에러 스크린샷
- [ ] Windows 버전 (에디션 포함)
- [ ] 마이크 모델명

## ❓ 문의

문제가 발생하거나 도움이 필요하시면 위 정보를 첨부하여 연락 주세요.

---
빌드 버전: TEST-DIAGNOSTIC
"@

Set-Content -Path (Join-Path $OutputDir "README_테스트방법.txt") -Value $ReadmeContent -Encoding UTF8

# 9. 빌드 정보 파일 생성
$BuildInfo = @"
빌드 정보
=========

빌드 시간: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
빌드 타입: Release (진단용)
Flutter 버전: $(flutter --version | Select-Object -First 1)
빌드 머신: $env:COMPUTERNAME

로그 레벨: VERBOSE
디버그 심볼: 포함
목적: 마이크 에러 진단

주요 변경 사항:
- MicDiagnosticsService: 상세 권한/장치 로그 추가
- AudioService: 녹음 시작/중지 상세 로그 추가
- 진단 정보 다이얼로그: 시스템 정보 + 로그 경로 표시
- 로그 폴더 바로 열기 기능 추가
"@

Set-Content -Path (Join-Path $OutputDir "BUILD_INFO.txt") -Value $BuildInfo -Encoding UTF8

# 10. ZIP 패키지 생성
$ZipPath = "$OutputDir.zip"
Write-Host ""
Write-Host "📦 ZIP 패키지 생성 중..." -ForegroundColor Cyan

if (Test-Path $ZipPath) {
    Remove-Item -Path $ZipPath -Force
}

Compress-Archive -Path $OutputDir -DestinationPath $ZipPath -Force

# 11. 완료 메시지
Write-Host ""
Write-Host "=" * 60 -ForegroundColor Green
Write-Host "✅ 테스트 릴리즈 빌드 완료!" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green
Write-Host ""
Write-Host "📂 출력 폴더: $OutputDir" -ForegroundColor Cyan
Write-Host "📦 ZIP 파일: $ZipPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "다음 단계:" -ForegroundColor Yellow
Write-Host "  1. ZIP 파일을 진료실 PC로 전달" -ForegroundColor White
Write-Host "  2. 압축 해제 후 README_테스트방법.txt 읽기" -ForegroundColor White
Write-Host "  3. medical_recorder.exe 실행" -ForegroundColor White
Write-Host "  4. 진단 정보 + 로그 파일 수집" -ForegroundColor White
Write-Host ""

# ZIP 파일 탐색기로 열기
explorer.exe /select,"$ZipPath"
