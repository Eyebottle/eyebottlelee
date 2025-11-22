# MSIX 테스트 - WAV 변환 문제 발견 및 수정

## 🐛 발견된 문제

**증상:**
- 9:00-9:30 진료 녹음 중 마지막 파일 중 하나가 WAV로 남아있음
- 파일명: `2025-11-07_09-20-00-557_진료녹음.wav`

**원인 분석:**
1. **세그먼트 분할 시 변환 로직 문제**
   - `splitSegment()` 메서드에서 세그먼트 분할 시 `_scheduleWavConversion()` 호출
   - `skipRecordingCheck` 파라미터를 전달하지 않아 기본값 `false` 사용
   - 분할 직후 녹음이 중지되면 5초 후 변환 시도 시 `_isRecording`이 `false`여서 변환 취소됨

2. **코드 위치:**
   - `lib/services/audio_service.dart` line 368
   - 기존: `_scheduleWavConversion(completedPath)` (skipRecordingCheck: false)
   - 문제: 녹음 중지 직전에 분할된 파일이 변환되지 않음

## ✅ 수정 내용

**변경 사항:**
- `splitSegment()` 메서드에서 `skipRecordingCheck: true` 추가
- 세그먼트 분할 시 생성된 파일도 녹음 중지 여부와 관계없이 변환되도록 수정

**수정 코드:**
```dart
// WAV 자동 변환 로직 (조건부 실행)
// 세그먼트 분할 시에는 녹음이 계속 진행 중이지만,
// 녹음 중지 직전에 분할된 파일도 변환되어야 하므로 skipRecordingCheck: true 사용
if (completedEncoder == AudioEncoder.wav && completedPath != null) {
  unawaited(_scheduleWavConversion(completedPath, skipRecordingCheck: true));
}
```

## 🔍 추가 확인 사항

### MSIX 환경에서 FFmpeg 실행 확인 필요

1. **FFmpeg 경로 확인**
   - MSIX 샌드박스에서 `getApplicationSupportDirectory()`가 올바른 경로 반환하는지 확인
   - 경로: `%LOCALAPPDATA%\Packages\eyebottle.medical.recorder_*\LocalState\`

2. **FFmpeg 실행 권한**
   - MSIX 샌드박스에서 실행 파일 실행 권한 확인
   - 로그에서 FFmpeg 오류 확인 필요

3. **로그 확인 방법**
   - 로그 경로: `%LOCALAPPDATA%\Packages\eyebottle.medical.recorder_fxkeb4dgdm144\LocalState\logs\`
   - 또는 앱 내 "진단 정보" 다이얼로그에서 로그 폴더 열기

## 📋 테스트 계획

### 1. 수정 후 재빌드
```powershell
# WSL에서 Windows로 동기화
bash scripts/sync_wsl_to_windows.sh

# Windows에서 빌드
cd C:\ws-workspace\eyebottlelee
flutter build windows --release
dart run msix:create
```

### 2. 재설치 및 테스트
```powershell
# 이전 버전 제거
Remove-AppxPackage -Package eyebottle.medical.recorder_1.3.0.0_x64__fxkeb4dgdm144

# 새 버전 설치
Add-AppxPackage -Path "C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix"
```

### 3. 테스트 시나리오
- [ ] 10분 이상 녹음 (세그먼트 분할 발생)
- [ ] 녹음 중지 직전에 분할된 파일 확인
- [ ] 모든 WAV 파일이 AAC로 변환되는지 확인
- [ ] 로그에서 FFmpeg 오류 확인

## ⚠️ 주의사항

1. **MSIX 환경 특성**
   - MSIX 샌드박스 환경에서 파일 시스템 접근이 제한될 수 있음
   - FFmpeg 실행 권한 문제 가능성

2. **로그 확인 중요**
   - 변환 실패 시 로그에서 정확한 원인 확인 필요
   - FFmpeg 경로, 실행 권한, 파일 접근 권한 등 확인

3. **추가 수정 가능성**
   - MSIX 환경에서 FFmpeg 실행이 안 되는 경우 추가 수정 필요
   - `getApplicationSupportDirectory()` 대신 다른 경로 사용 고려

## 📝 다음 단계

1. ✅ 코드 수정 완료
2. ⏳ 재빌드 및 MSIX 재생성
3. ⏳ 재설치 및 테스트
4. ⏳ 로그 확인 및 추가 문제 해결

