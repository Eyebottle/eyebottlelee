# 아이보틀 진료녹음 테스트 릴리즈 가이드

## 📋 현재 상황

**현재 버전**: v1.3.0 (WAV 자동 변환 기능)
**문서 업데이트**: 2025-11-05
**상태**: 개발 PC 테스트 완료, 진료실 테스트 대기 중

### 빌드 정보
- **위치**: `C:\Users\user\OneDrive\이안과\eyebottlelee-test-release\`
- **크기**: 211 MB (ffmpeg 포함)
- **빌드 시간**: 90.3초
- **환경**: Flutter 3.35.3, Dart 3.9.2

### 개발 PC 테스트 결과 ✅
- 10분 녹음 테스트 성공
- WAV → AAC 변환 성공
- **용량 절감: 90.7%** (48.7 MB → 4.5 MB)
- 변환 시간: 3.2초

---

## 🎯 v1.3.0 핵심 기능: WAV 자동 변환

### 해결한 문제
- 일부 PC에서 AAC/Opus 직접 녹음 실패 → **WAV로 녹음 후 자동 변환**
- 10분 WAV 파일 48.7 MB → **자동 변환 후 4.5 MB** (90% 절감)
- 하루 8시간 기준 **680 MB 절감**

### 동작 방식
1. AAC/Opus 녹음 시도
2. 실패 시 WAV로 폴백 녹음 (안정적)
3. 세그먼트 완료 후 5초 대기
4. 백그라운드에서 AAC/Opus로 자동 변환
5. 변환 성공 시 원본 WAV 자동 삭제

### 주요 구성 요소
- **AudioConverterService**: ffmpeg 기반 변환 엔진
- **ffmpeg.exe**: 앱에 포함 (182MB, 별도 설치 불필요)
- **설정 UI**: 자동 변환 on/off, 형식 선택(AAC/Opus), 지연 시간 조절

---

## 🧪 진료실 테스트 가이드 (2025-11-06 예정)

### 1단계: 앱 실행
1. `C:\Users\user\OneDrive\이안과\eyebottlelee-test-release\` 폴더 열기
2. `medical_recorder.exe` 더블클릭
3. Windows SmartScreen 경고 시: "추가 정보" → "실행"

### 2단계: 설정 확인
1. 설정 탭 > "WAV 파일 자동 변환" 클릭
2. 자동 변환 활성화 확인 (기본: 켜짐 ✅)
3. 변환 형식: AAC (기본값)
4. 변환 지연: 5초 (기본값)

### 3단계: 녹음 테스트
1. 대시보드 > "녹음 시작"
2. **10분 이상** 녹음 (세그먼트 자동 분할)
3. 로그 확인:
   ```
   ✅ [시도 N] 녹음 시작 성공 (wav)
   WAV 변환 예약: ...
   WAV 변환 시작: ...
   ✅ 변환 완료: ... (4.5 MB, 3.2초)
   원본 WAV 파일 삭제: ...
   ```

### 4단계: 결과 확인
1. 저장 폴더 열기 (대시보드 > "폴더 열기")
2. 파일 확장자 확인:
   - `.m4a` (AAC 변환 완료) ← 기대값
   - `.opus` (Opus 변환 완료)
   - `.wav` (변환 실패 - 문제!)
3. 파일 크기 확인:
   - ✅ **10분 ≈ 4~5 MB** (변환 성공)
   - ❌ **10분 ≈ 45~50 MB** (변환 실패)
4. 파일 재생 테스트 (VLC 또는 Windows Media Player)

### 5단계: 로그 수집
- 성공 시: 용량 절감 비율 기록
- 실패 시:
  - 마이크 진단 카드 > "진단 정보" > "진단 정보 복사"
  - 로그 폴더 열기 > 최신 로그 파일 복사
  - 로그 위치: `%USERPROFILE%\Documents\EyebottleRecorder\logs\`

---

## 🚀 다음 단계

### ✅ 완료
- [x] WAV 자동 변환 기능 개발
- [x] 개발 PC 테스트
- [x] 테스트 빌드 생성
- [x] 도움말 문서 업데이트

### 🔄 진행 중
- [ ] **진료실 테스트** (2025-11-06 예정)
  - WAV 자동 변환 검증
  - 실제 진료 환경 안정성 확인
  - 용량 절감 효과 측정

### 📝 대기 중 (진료실 테스트 성공 시)

#### 3단계: 코드 정리 및 리팩토링
- [ ] 불필요한 주석 제거
- [ ] 디버그 로그 정리 (필수 로그만 유지)
- [ ] 코드 포맷팅 통일 (`dart format`)
- [ ] TODOs 처리
- [ ] 사용하지 않는 코드 제거

#### 4단계: 버전 정보 및 문서
- [ ] pubspec.yaml 버전 확정 (1.3.0)
- [ ] CHANGELOG.md 작성
- [ ] README.md 업데이트
- [ ] 릴리즈 노트 작성

#### 5단계: 정식 빌드
- [ ] Release 빌드 생성 (최적화)
- [ ] MSIX 패키지 생성 (Microsoft Store용)
- [ ] 배포 패키지 준비

#### 6단계: 정식 배포
- [ ] Microsoft Store 업로드
- [ ] 진료실 PC 정식 버전 배포
- [ ] 배포 후 1주일 모니터링

---

## 🔧 빌드 방법 (필요시)

### WSL에서 Windows로 동기화
```bash
cd /home/usereyebottle/projects/eyebottlelee
rsync -av --delete --exclude='.dart_tool/' --exclude='build/' /home/usereyebottle/projects/eyebottlelee/ /mnt/c/ws-workspace/eyebottlelee/
```

### Windows에서 빌드
```powershell
cd C:\ws-workspace\eyebottlelee
flutter clean
flutter pub get
flutter build windows --release
```

### 수동 패키징
```bash
# Release 파일 복사
cp -r /mnt/c/ws-workspace/eyebottlelee/build/windows/x64/runner/Release/* "/mnt/c/Users/user/OneDrive/이안과/eyebottlelee-test-release/"

# ZIP 압축 (Windows PowerShell)
Compress-Archive -Path "eyebottlelee-test-release" -DestinationPath "eyebottlelee-test-release.zip" -Force
```

---

## 🐛 문제 해결

### 변환이 작동하지 않는 경우
1. 로그에서 `WAV 변환 예약` 메시지 확인
2. ffmpeg 경로 확인: 로그에서 `ffmpeg 경로:` 검색
3. 디스크 여유 공간 확인 (최소 500 MB)

### 파일이 여전히 WAV인 경우
1. 변환 실패 로그 확인
2. 설정 > "WAV 파일 자동 변환" > 활성화 확인
3. ffmpeg.exe 파일 존재 확인: `data/flutter_assets/assets/bin/ffmpeg.exe`

### 앱 크래시 시
1. 진단 정보 수집 (마이크 진단 카드 > "진단 정보")
2. 로그 파일 수집
3. Windows Event Viewer 확인 (응용 프로그램 로그)

---

## 📚 참고: 과거 문제 해결 요약

**v1.0.0 ~ v1.2.9**:
- AAC/Opus 코덱 불안정 문제로 여러 시도 (코덱 폴백, DLL 체크, Visual C++ Runtime 업데이트 등)
- 근본적인 해결 실패 - Windows Media Foundation 자체의 불안정성

**v1.3.0 (현재)**:
- **WAV 폴백 + 자동 변환**으로 근본 해결
- 안정성 확보 + 용량 문제 동시 해결
- ffmpeg 통합으로 모든 환경에서 작동

---

**문서 작성**: 2025-11-05
**다음 업데이트 예정**: 진료실 테스트 완료 후
