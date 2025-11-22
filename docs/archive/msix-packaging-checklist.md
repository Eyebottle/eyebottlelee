# MSIX 패키징 체크리스트

MS Store 제출을 위한 MSIX 패키지 생성 가이드입니다.

---

## ✅ 사전 준비

### 1. 필수 파일 확인
- [ ] `pubspec.yaml` - msix_config 설정 완료
- [ ] `assets/icons/icon.ico` - 로고 파일 존재 (171.82 KB)
- [ ] `assets/bin/ffmpeg.exe` - FFmpeg 바이너리 존재
- [ ] Release 빌드 성공

### 2. pubspec.yaml 설정 확인

현재 설정:
```yaml
msix_config:
  display_name: 아이보틀 진료 녹음
  publisher_display_name: Eyebottle
  identity_name: eyebottle.medical.recorder
  msix_version: 1.3.0.0
  logo_path: assets/icons/icon.ico
  capabilities: "microphone, internetClient"
```

확인 사항:
- [ ] `msix_version: 1.3.0.0` 정확함
- [ ] `logo_path` 파일 존재 확인
- [ ] `capabilities` 필요한 권한만 포함

---

## 🏗️ MSIX 생성 단계

### Step 1: Release 빌드

```powershell
cd C:\ws-workspace\eyebottlelee
flutter build windows --release
```

**예상 소요 시간**: 30-40초

**확인**:
- [ ] 빌드 성공 메시지
- [ ] `build\windows\x64\runner\Release\medical_recorder.exe` 생성됨

---

### Step 2: MSIX 패키지 생성

```powershell
dart run msix:create
```

**예상 소요 시간**: 20-30초

**생성 위치**:
```
build/windows/x64/runner/Release/medical_recorder.msix
```

**확인**:
- [ ] MSIX 파일 생성됨
- [ ] 파일 크기 확인 (약 30-50 MB)
- [ ] 오류 메시지 없음

---

### Step 3: 로컬 테스트 설치

#### 개발자 모드 활성화

1. Windows 설정 → 개인정보 보호 및 보안 → 개발자용
2. "개발자 모드" 토글 켜기

#### MSIX 설치

```powershell
cd build\windows\x64\runner\Release
Add-AppxPackage -Path medical_recorder.msix
```

또는:
- MSIX 파일 더블클릭
- "설치" 버튼 클릭

**확인**:
- [ ] 설치 성공
- [ ] 시작 메뉴에 "아이보틀 진료 녹음" 표시
- [ ] 아이콘이 정상 표시됨

---

### Step 4: 기능 테스트

설치 후 다음 기능 확인:

#### 필수 테스트
- [ ] 앱 실행 (시작 메뉴에서)
- [ ] 녹음 시작/중지
- [ ] 파일 저장 확인
- [ ] 설정 변경 및 저장
- [ ] 앱 종료 및 재시작
- [ ] 시스템 트레이 동작

#### 권한 테스트
- [ ] 마이크 권한 요청 (첫 실행 시)
- [ ] 파일 저장 경로 접근
- [ ] OneDrive 폴더 접근 (설정 시)

#### MSIX 특화 테스트
- [ ] 앱 데이터 폴더 접근 가능
  - `%LOCALAPPDATA%\Packages\eyebottle.medical.recorder_*\LocalState`
- [ ] FFmpeg 실행 가능
- [ ] 설정 저장/로드 정상

---

### Step 5: 제거 테스트

```powershell
Remove-AppxPackage -Package eyebottle.medical.recorder_1.3.0.0_x64__*
```

또는:
- 설정 → 앱 → 설치된 앱
- "아이보틀 진료 녹음" 찾기
- "제거" 클릭

**확인**:
- [ ] 제거 성공
- [ ] 시작 메뉴에서 사라짐
- [ ] 앱 데이터 폴더 삭제됨 (선택적)

---

### Step 6: 재설치 테스트

```powershell
Add-AppxPackage -Path medical_recorder.msix
```

**확인**:
- [ ] 재설치 성공
- [ ] 이전 설정 유지/초기화 확인
- [ ] 모든 기능 정상 작동

---

## 🧪 WACK (Windows App Certification Kit) 테스트

### WACK 실행

#### 방법 1: GUI
1. 시작 → "Windows App Cert Kit" 검색
2. 앱 실행
3. "Windows 데스크톱 앱 유효성 검사" 선택
4. MSIX 파일 선택
5. "다음" → 테스트 시작

#### 방법 2: 명령줄
```powershell
appcert.exe test -apptype windowsapppackage -appxpackagepath "build\windows\x64\runner\Release\medical_recorder.msix" -reportoutputpath "wack-report.xml"
```

**예상 소요 시간**: 10-15분

### 통과해야 할 테스트

- [ ] **App manifest compliance** - manifest 규격 준수
- [ ] **App manifest resources** - 리소스 파일 존재
- [ ] **Windows security** - 보안 요구사항
- [ ] **Package sanity** - 패키지 무결성
- [ ] **Platform security** - 플랫폼 보안
- [ ] **Supported API** - 지원되는 API 사용
- [ ] **Performance** - 성능 기준

### 실패 시 대처

1. **로그 확인**:
   ```
   wack-report.xml 또는 HTML 리포트
   ```

2. **일반적인 문제**:
   - **Unsupported API**: Win32 API 사용 제한
   - **Missing resources**: 리소스 파일 누락
   - **Performance**: 시작 시간 초과

3. **해결 방법**:
   - pubspec.yaml 수정
   - 의존성 패키지 업데이트
   - 코드 수정 후 재빌드

---

## 📦 최종 패키지 정보

### 파일 정보
- **파일명**: `medical_recorder.msix`
- **크기**: 약 30-50 MB
- **위치**: `build/windows/x64/runner/Release/`

### 패키지 정보
- **패키지 이름**: eyebottle.medical.recorder
- **버전**: 1.3.0.0
- **아키텍처**: x64
- **게시자**: Eyebottle

---

## 🚨 문제 해결

### MSIX 생성 실패

**증상**: `dart run msix:create` 실패

**해결**:
```powershell
# 캐시 정리
flutter clean
flutter pub get

# 재빌드
flutter build windows --release
dart run msix:create
```

### 설치 실패

**증상**: `Add-AppxPackage` 오류

**해결**:
1. 개발자 모드 확인
2. 이전 버전 완전 제거
3. PowerShell 관리자 권한으로 실행

### FFmpeg 실행 안 됨

**증상**: WAV 변환 실패

**해결**:
1. `assets/bin/ffmpeg.exe` 파일 확인
2. pubspec.yaml에 assets 등록 확인:
   ```yaml
   assets:
     - assets/bin/ffmpeg.exe
   ```
3. 재빌드

### 권한 오류

**증상**: 마이크 또는 파일 접근 거부

**해결**:
1. capabilities 확인:
   ```yaml
   capabilities: "microphone, internetClient"
   ```
2. Windows 설정 → 개인정보 → 마이크 확인
3. 앱 재시작

---

## ✅ 최종 체크리스트

### 빌드 전
- [ ] 코드 변경사항 커밋
- [ ] 버전 번호 확인 (pubspec.yaml)
- [ ] 테스트 파일/디버그 코드 제거
- [ ] 로고 파일 존재 확인

### MSIX 생성
- [ ] Release 빌드 성공
- [ ] MSIX 파일 생성 성공
- [ ] 파일 크기 정상 (30-50 MB)

### 로컬 테스트
- [ ] 설치 성공
- [ ] 모든 주요 기능 동작
- [ ] 제거 성공
- [ ] 재설치 성공

### WACK 테스트
- [ ] 모든 테스트 통과
- [ ] 리포트 저장

### MS Store 업로드 준비
- [ ] MSIX 파일 준비
- [ ] WACK 리포트 준비 (선택)
- [ ] 스크린샷 준비 (4-5개)
- [ ] 앱 설명 준비
- [ ] 개인정보 처리방침 준비

---

## 🎯 다음 단계

MSIX 패키징 완료 후:

1. **스크린샷 촬영**
   - [screenshot-guide.md](screenshot-guide.md) 참고
   - 5개 필수 스크린샷

2. **MS Partner Center 준비**
   - 개발자 계정 등록 ($19)
   - 앱 생성
   - 스토어 리스팅 작성

3. **제출**
   - MSIX 업로드
   - 스크린샷 업로드
   - 심사 제출

---

**예상 소요 시간**: 1-2시간 (WACK 포함)
**다음 가이드**: [MS-STORE-GUIDE.md](MS-STORE-GUIDE.md) Phase 5
