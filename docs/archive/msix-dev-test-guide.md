# 개발 PC에서 MSIX 테스트 가이드

MS Store 제출 전 개발 PC에서 MSIX 패키지를 테스트하는 가이드입니다.

---

## 🎯 테스트 목적

**진료실 컴퓨터:**
- .exe 파일로 실사용 테스트
- MSIX 설치 불가 (보안 정책)

**개발 컴퓨터:**
- MSIX 설치 테스트
- MS Store 버전과 동일한 환경에서 검증
- Phase 4 수동 테스트 완료

---

## 📋 사전 준비

### 1. 개발자 모드 활성화

**Windows 11:**
```
설정 → 개인정보 보호 및 보안 → 개발자용 → "개발자 모드" 토글 켜기
```

**Windows 10:**
```
설정 → 업데이트 및 보안 → 개발자용 → "개발자 모드" 선택
```

### 2. 이전 버전 제거 (있다면)

```powershell
# PowerShell 관리자 권한으로 실행

# 설치된 버전 확인
Get-AppxPackage | Where-Object {$_.Name -like "*eyebottle*"}

# 출력 예시:
# Name              : eyebottle.medical.recorder
# Publisher         : CN=Eyebottle
# Architecture      : X64
# PackageFullName   : eyebottle.medical.recorder_1.3.0.0_x64__fxkeb4dgdm144

# 제거
Remove-AppxPackage -Package "eyebottle.medical.recorder_1.3.0.0_x64__fxkeb4dgdm144"
```

---

## ✅ MSIX 설치 테스트

### Step 1: MSIX 파일 위치 확인

```
C:\Users\user\OneDrive\이안과\eyebottlelee-v1.3.0-wav-fix\medical_recorder.msix
```

또는:
```
C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix
```

### Step 2: 설치 실행

**방법 1: PowerShell**
```powershell
cd "C:\Users\user\OneDrive\이안과\eyebottlelee-v1.3.0-wav-fix"
Add-AppxPackage -Path medical_recorder.msix
```

**방법 2: 더블클릭**
```
medical_recorder.msix 파일 더블클릭
→ "설치" 버튼 클릭
→ 설치 완료 대기
```

### Step 3: 설치 확인

- [ ] 설치 오류 없음
- [ ] 시작 메뉴 검색: "아이보틀 진료 녹음"
- [ ] 타일 아이콘: eyebottle 로고 표시됨
- [ ] 타일 클릭: 앱 실행됨

---

## 🧪 기능 테스트

### 1. 앱 실행 및 초기화

- [ ] **앱 실행**
  - 시작 메뉴 → "아이보틀 진료 녹음" 클릭
  - 3초 이내 앱 창 표시
  - 로딩 오류 없음

- [ ] **마이크 권한**
  - 첫 실행 시 마이크 권한 요청
  - "허용" 클릭
  - Windows 설정 → 마이크에서 앱 표시 확인

- [ ] **저장 폴더 설정**
  - 폴더 선택 다이얼로그 정상 작동
  - OneDrive/문서 폴더 선택 가능
  - 설정 저장 확인

---

### 2. 녹음 기능 테스트

#### A. 짧은 녹음 (1-2분)

```
목적: 녹음 중지 시 WAV → AAC 변환 확인
```

- [ ] 녹음 시작 버튼 클릭
- [ ] 볼륨 미터 움직임 확인
- [ ] 1-2분 대기
- [ ] 녹음 중지 버튼 클릭
- [ ] **5초 대기** (중요!)
- [ ] 저장 폴더 확인:
  ```
  예상 결과:
  20251107_143000.aac (5 MB)

  WAV 파일 없어야 함!
  ```

**❌ 실패 시:**
- WAV 파일이 남아있음 → FFmpeg 실행 문제
- 로그 확인 필요

---

#### B. 장시간 녹음 (10분+)

```
목적: 세그먼트 분할 시 WAV → AAC 변환 확인
```

- [ ] 녹음 시작
- [ ] 10분 이상 녹음 진행
- [ ] 10분마다 세그먼트 분할 발생
- [ ] 녹음 중지
- [ ] **5초 대기**
- [ ] 저장 폴더 확인:
  ```
  예상 결과:
  20251107_143000.aac (30 MB)
  20251107_144000.aac (30 MB)
  20251107_145000.aac (15 MB)

  모든 파일이 AAC!
  WAV 파일 없어야 함!
  ```

**✅ 성공 기준:**
- 모든 파일이 .aac 확장자
- .wav 파일이 하나도 없음
- 파일 크기가 합리적 (WAV의 ~17%)

**❌ 실패 시:**
- WAV 파일 존재 → 세그먼트 분할 버그 재발
- 코드 재확인 필요

---

### 3. MSIX 특화 테스트

#### A. FFmpeg 실행 확인

```
MSIX 샌드박스에서 FFmpeg가 정상 작동하는지 확인
```

- [ ] 짧은 녹음 → AAC 변환 성공
- [ ] 로그에 FFmpeg 오류 없음
- [ ] 변환 속도 정상 (1분 녹음 → 1-2초 변환)

**로그 확인 방법:**
```
1. 앱 내 메뉴 → "진단 정보" (또는 도움말)
2. "로그 폴더 열기" 클릭
3. 최신 로그 파일 열기
4. "FFmpeg", "변환" 키워드 검색
```

**예상 로그:**
```
[INFO] 💡 마지막 WAV 파일 변환 예약
[INFO] WAV 변환 시작: 20251107_143000.wav
[INFO] FFmpeg 실행: C:\...\ffmpeg.exe -i ... -c:a aac ...
[INFO] ✅ AAC 변환 완료: 20251107_143000.aac (5.2 MB)
[INFO] 🗑️ 원본 WAV 삭제: 20251107_143000.wav
```

---

#### B. 앱 데이터 폴더 확인

```
MSIX 앱은 제한된 폴더에만 데이터 저장 가능
```

- [ ] **로그 파일 위치**
  ```
  %LOCALAPPDATA%\Packages\eyebottle.medical.recorder_*\LocalState\logs\
  ```

- [ ] **설정 파일 위치**
  ```
  %LOCALAPPDATA%\Packages\eyebottle.medical.recorder_*\LocalState\
  ```

- [ ] **저장된 녹음 파일**
  ```
  사용자가 선택한 폴더 (OneDrive, 문서 등)
  ```

**확인 방법:**
```powershell
# 앱 데이터 폴더 열기
explorer "%LOCALAPPDATA%\Packages\eyebottle.medical.recorder_fxkeb4dgdm144\LocalState"
```

---

### 4. 시각적 확인

#### A. 아이콘 표시

- [ ] **시작 메뉴 타일**
  - eyebottle 로고 표시
  - 흐릿하거나 깨지지 않음

- [ ] **작업 표시줄**
  - 앱 실행 중 아이콘 표시
  - eyebottle 로고 확인

- [ ] **Alt+Tab**
  - 앱 전환 시 아이콘 표시
  - "아이보틀 진료 녹음" 이름 표시

#### B. UI 동작

- [ ] 창 크기 조절 가능
- [ ] 최대화/최소화 정상 작동
- [ ] 탭 전환 (대시보드, 설정, 자동 실행)
- [ ] 버튼 반응 정상

---

### 5. 설정 기능 테스트

#### A. 진료 시간표

- [ ] "녹음 설정" 탭 클릭
- [ ] 요일별 시간 설정
- [ ] 저장 후 앱 재시작
- [ ] 설정 유지 확인

#### B. 고급 설정

- [ ] "고급 설정" 버튼 클릭
- [ ] WAV 자동 변환 토글 ON
- [ ] 보관 기간 설정
- [ ] 저장 버튼 클릭

#### C. 자동 실행 매니저

- [ ] "자동 실행" 탭 클릭
- [ ] 프로그램 추가 (예: 메모장)
- [ ] ON/OFF 토글 동작 확인
- [ ] 순서 변경 (드래그)

---

## ✅ 안정성 테스트

### A. 재시작 테스트

- [ ] 앱 종료 (X 버튼)
- [ ] 시작 메뉴에서 재실행
- [ ] 이전 설정 유지됨
- [ ] 모든 기능 정상 작동

### B. 장시간 실행

- [ ] 앱을 2-3시간 실행 상태로 유지
- [ ] CPU/메모리 사용량 모니터 (작업 관리자)
- [ ] 메모리 누수 없음 (~150 MB 유지)

### C. 다중 실행 방지

- [ ] 앱 실행 중
- [ ] 시작 메뉴에서 다시 클릭
- [ ] 기존 창이 활성화됨 (새 창 안 열림)

---

## 🔄 제거 및 재설치 테스트

### Step 1: 제거

**방법 1: Windows 설정**
```
설정 → 앱 → 설치된 앱
→ "아이보틀 진료 녹음" 검색
→ "..." → "제거"
```

**방법 2: PowerShell**
```powershell
Remove-AppxPackage -Package eyebottle.medical.recorder_1.3.0.0_x64__fxkeb4dgdm144
```

### Step 2: 제거 확인

- [ ] 시작 메뉴에서 사라짐
- [ ] 설치된 앱 목록에서 사라짐
- [ ] 작업 관리자에 프로세스 없음

### Step 3: 재설치

```powershell
cd "C:\Users\user\OneDrive\이안과\eyebottlelee-v1.3.0-wav-fix"
Add-AppxPackage -Path medical_recorder.msix
```

### Step 4: 재설치 확인

- [ ] 설치 성공
- [ ] 앱 실행 성공
- [ ] 초기 설정 화면 또는 이전 설정 로드
- [ ] 모든 기능 정상 작동

---

## 🧪 선택적: WACK 테스트

Windows App Certification Kit으로 MS Store 심사 기준 확인

### WACK 실행

**방법 1: GUI**
```
시작 → "Windows App Cert Kit" 검색
→ 앱 실행
→ "Windows 데스크톱 앱 유효성 검사"
→ medical_recorder.msix 선택
→ 테스트 시작 (10-15분)
```

**방법 2: 명령줄**
```powershell
appcert.exe test -apptype windowsapppackage `
  -appxpackagepath "C:\Users\user\OneDrive\이안과\eyebottlelee-v1.3.0-wav-fix\medical_recorder.msix" `
  -reportoutputpath "C:\wack-report.xml"
```

### 통과 기준

- [ ] App manifest compliance
- [ ] App manifest resources
- [ ] Windows security
- [ ] Package sanity
- [ ] Platform security
- [ ] Supported API
- [ ] Performance

**❌ 실패 시:**
- 리포트 확인 (XML 또는 HTML)
- 문제 원인 파악 및 수정
- 재빌드 후 재테스트

---

## ✅ 최종 체크리스트

### 필수 테스트 ⭐
- [ ] MSIX 설치 성공
- [ ] 앱 실행 성공
- [ ] 짧은 녹음 → AAC 변환 성공
- [ ] **장시간 녹음 → 모든 파일 AAC 변환** (핵심!)
- [ ] 설정 저장/로드 정상
- [ ] 제거 성공
- [ ] 재설치 성공

### 권장 테스트
- [ ] FFmpeg 실행 확인 (로그)
- [ ] 마이크 권한 정상
- [ ] 앱 데이터 폴더 확인
- [ ] 장시간 실행 안정성
- [ ] WACK 테스트 통과

### 시각적 확인
- [ ] eyebottle 로고 표시 (모든 아이콘)
- [ ] 시작 메뉴 타일 정상
- [ ] 작업 표시줄 아이콘 정상
- [ ] Alt+Tab 아이콘 정상

---

## 🎯 테스트 완료 후

**✅ 모든 테스트 통과 시:**
- Phase 4 완료!
- Phase 5 (MS Store 제출) 진행 가능

**❌ 문제 발견 시:**
1. 문제 상세 기록 (스크린샷, 로그)
2. 코드 수정
3. 재빌드 및 MSIX 재생성
4. 테스트 재진행

---

## 📞 문제 해결

### WAV 파일이 남는 경우

**원인:**
- FFmpeg 실행 실패
- 경로 권한 문제
- 변환 지연 중 앱 종료

**해결:**
1. 로그 확인 (%LOCALAPPDATA%\Packages\...\LocalState\logs\)
2. FFmpeg 경로 확인
3. 변환 대기 시간 충분히 확보 (5초+)

### 설치 실패

**원인:**
- 개발자 모드 비활성화
- 이전 버전 충돌
- 손상된 MSIX 파일

**해결:**
1. 개발자 모드 확인
2. 이전 버전 완전 제거
3. MSIX 재다운로드/재생성
4. PowerShell 관리자 권한

### FFmpeg 실행 안 됨

**원인:**
- MSIX에 FFmpeg 미포함
- 실행 권한 문제

**해결:**
1. pubspec.yaml 확인:
   ```yaml
   assets:
     - assets/bin/ffmpeg.exe
   ```
2. MSIX 재생성
3. 로그에서 FFmpeg 경로 확인

---

## 📝 테스트 기록

**테스트 날짜:** _____________

**테스트 항목:**
- [ ] 설치/제거
- [ ] 짧은 녹음
- [ ] 장시간 녹음 (세그먼트 분할)
- [ ] FFmpeg 변환
- [ ] 설정 저장
- [ ] WACK 테스트

**결과:**
- ⬜ 통과
- ⬜ 실패 (문제: _____________)

**비고:**
_________________________________
_________________________________

---

**다음 단계:** Phase 5 - MS Store 제출 준비
