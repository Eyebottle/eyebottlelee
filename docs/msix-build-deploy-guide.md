# MSIX 빌드 및 배포 가이드 (WAV 변환 수정 버전)

## 📋 현재 상황

**테스트 중인 버전**: `eyebottlelee-v1.3.0-wav-fix`
- 빌드 시간: 2025-11-07 07:41
- 발견된 문제: 세그먼트 분할 시 WAV 변환 누락
- 수정 완료: `splitSegment()`에서 `skipRecordingCheck: true` 추가

## 🔧 수정 내용

**문제:**
- 9:20에 생성된 세그먼트 파일이 WAV로 남아있음
- 세그먼트 분할 직후 녹음 중지 시 변환이 취소됨

**해결:**
- `lib/services/audio_service.dart` line 370 수정
- `_scheduleWavConversion(completedPath, skipRecordingCheck: true)` 추가

## 🏗️ 빌드 및 배포 단계

### 1. WSL → Windows 동기화 (완료)
```bash
bash scripts/sync_wsl_to_windows.sh
```

### 2. Windows에서 MSIX 빌드

**PowerShell에서 실행:**
```powershell
cd C:\ws-workspace\eyebottlelee

# Release 빌드
flutter build windows --release

# MSIX 패키지 생성
dart run msix:create
```

**예상 소요 시간:**
- Release 빌드: 30-40초
- MSIX 생성: 20-30초
- 총: 약 1분

### 3. MSIX 파일 확인

**생성 위치:**
```
C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix
```

**확인 사항:**
- 파일 크기: 약 83 MB
- 파일 날짜: 현재 시간
- 버전: 1.3.0.0

### 4. OneDrive로 복사

**옵션 A: 기존 폴더 업데이트**
```powershell
# 기존 MSIX 파일 백업 (선택적)
Copy-Item "C:\Users\user\OneDrive\이안과\eyebottlelee-v1.3.0-wav-fix\medical_recorder.msix" `
  "C:\Users\user\OneDrive\이안과\eyebottlelee-v1.3.0-wav-fix\medical_recorder.msix.backup"

# 새 MSIX 파일 복사
Copy-Item "C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix" `
  "C:\Users\user\OneDrive\이안과\eyebottlelee-v1.3.0-wav-fix\medical_recorder.msix" -Force
```

**옵션 B: 새 폴더 생성**
```powershell
# 새 폴더 생성
$newFolder = "C:\Users\user\OneDrive\이안과\eyebottlelee-v1.3.0-wav-fix-v2"
New-Item -ItemType Directory -Path $newFolder -Force

# MSIX 파일 복사
Copy-Item "C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix" `
  "$newFolder\medical_recorder.msix"
```

### 5. 버전 정보 파일 생성

**OneDrive 폴더에 버전 정보 파일 생성:**
```powershell
$versionInfo = @"
아이보틀 진료 녹음 MSIX 패키지 (WAV 변환 수정 버전)
====================================================

빌드 날짜: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
MSIX 버전: 1.3.0.0
앱 버전: 1.3.0+11

🔧 수정 사항
------------
- 세그먼트 분할 시 WAV 변환 누락 문제 수정
- 녹음 중지 직전에 분할된 파일도 변환되도록 개선

📦 파일 정보
------------
파일명: medical_recorder.msix
크기: 약 83 MB

✅ 테스트 항목
-------------
- [ ] 10분 이상 녹음 (세그먼트 분할 발생)
- [ ] 녹음 중지 직전에 분할된 파일 확인
- [ ] 모든 WAV 파일이 AAC로 변환되는지 확인
- [ ] 로그에서 FFmpeg 오류 확인

문서: docs/msix-wav-conversion-fix.md
"@

Set-Content -Path "C:\Users\user\OneDrive\이안과\eyebottlelee-v1.3.0-wav-fix\버전정보.txt" `
  -Value $versionInfo -Encoding UTF8
```

## 🧪 재설치 및 테스트

### 1. 이전 버전 제거
```powershell
Remove-AppxPackage -Package eyebottle.medical.recorder_1.3.0.0_x64__fxkeb4dgdm144
```

### 2. 새 버전 설치
```powershell
cd "C:\Users\user\OneDrive\이안과\eyebottlelee-v1.3.0-wav-fix"
Add-AppxPackage -Path medical_recorder.msix
```

### 3. 테스트 시나리오
- [ ] 10분 이상 녹음 진행 (세그먼트 분할 발생)
- [ ] 녹음 중지 직전에 분할된 파일 확인
- [ ] 모든 WAV 파일이 AAC로 변환되는지 확인
- [ ] 로그 확인: `%LOCALAPPDATA%\Packages\eyebottle.medical.recorder_fxkeb4dgdm144\LocalState\logs\`

## 📝 변경 이력

**2025-11-07:**
- 세그먼트 분할 시 WAV 변환 누락 문제 수정
- `splitSegment()`에서 `skipRecordingCheck: true` 추가

