# MS Store 출시 준비 계획

## 📅 타임라인

### Phase 1: 코드 정리 (1-2일)
- [ ] 디버그 로그 정리
- [ ] 불필요한 주석 제거
- [ ] 코드 포맷팅
- [ ] TODO 항목 처리

### Phase 2: 테스트 & 검증 (1일)
- [ ] 진료실 테스트 완료 확인
- [ ] 모든 기능 재검증
- [ ] 성능 테스트

### Phase 3: 문서화 (1일)
- [ ] CHANGELOG.md 작성
- [ ] README.md 업데이트
- [ ] 사용자 가이드 최종 점검

### Phase 4: 빌드 & 패키징 (1일)
- [ ] MSIX 패키지 생성
- [ ] 인증서 서명
- [ ] 패키지 검증

### Phase 5: MS Store 제출 (1일)
- [ ] 스토어 리스팅 작성
- [ ] 스크린샷 준비
- [ ] 제출 및 심사 대기

---

## 🧹 Phase 1: 코드 정리 상세 계획

### 1.1 디버그 로그 정리

#### 제거할 로그
```dart
// 너무 상세한 디버그 로그
🐛 진료 시간 확인: 요일=4(목), 시각=15:24
🐛   -> 요일 스케줄: ...
🐛   -> 진료 시간 여부: ...

💡 🔧 _buildRecordConfig 시작
💡 🔧 _selectSupportedEncoder 반환됨
💡 🔧 RecordConfig 생성 시작
💡 🔧 RecordConfig 생성 완료
```

#### 유지할 로그
```dart
// 중요한 이벤트와 오류만 유지
💡 녹음 시작 성공 (코덱: wav)
⛔ 녹음 시작 실패 (aacLc)
📅 새로운 진료 시간표 적용 완료
⚠️ WAV 변환 실패: ...
```

**작업 파일:**
- `lib/services/audio_service.dart`
- `lib/services/schedule_service.dart`
- `lib/services/audio_converter_service.dart`
- `lib/services/mic_diagnostics_service.dart`

---

### 1.2 불필요한 주석 제거

#### 제거 대상
```dart
// 개발 중 메모
// TODO: 나중에 최적화
// FIXME: 임시 해결책
// NOTE: 테스트용
// 주석 처리된 오래된 코드
```

#### 유지 대상
```dart
/// 문서화 주석 (dartdoc)
/// API 설명
/// 중요한 로직 설명
```

**도구:** `dart doc` 실행하여 문서화 검증

---

### 1.3 코드 포맷팅

```bash
# 전체 코드 포맷팅
dart format lib/ --set-exit-if-changed

# 린트 검사
flutter analyze

# 미사용 import 제거
dart fix --apply
```

---

### 1.4 TODO 항목 처리

**현재 TODO 목록 확인:**
```bash
grep -r "TODO" lib/ --include="*.dart"
grep -r "FIXME" lib/ --include="*.dart"
```

**처리 방법:**
- 완료 가능한 항목: 즉시 처리
- 장기 계획 항목: GitHub Issues로 이동
- 불필요한 항목: 제거

---

## 📦 Phase 4: MSIX 패키징 상세

### 4.1 pubspec.yaml 설정 확인

```yaml
msix_config:
  display_name: 아이보틀 진료 녹음
  publisher_display_name: Eyebottle
  identity_name: eyebottle.medical.recorder
  msix_version: 1.3.0.0
  logo_path: assets/icons/icon.ico
  capabilities: "microphone, internetClient"
  # 추가 필요 항목
  publisher: CN=YourPublisher
  certificate_path: path/to/certificate.pfx
  certificate_password: your_password
```

### 4.2 MSIX 생성 명령

```bash
# 1. Release 빌드
flutter build windows --release

# 2. MSIX 패키지 생성
dart run msix:create

# 3. 생성된 패키지 위치
# build/windows/x64/runner/Release/medical_recorder.msix
```

### 4.3 테스트 설치

```powershell
# 개발자 모드 활성화 후
Add-AppxPackage -Path "medical_recorder.msix"
```

---

## 🏪 Phase 5: MS Store 제출 준비

### 5.1 필요한 자료

#### 앱 정보
- **앱 이름:** 아이보틀 진료 녹음
- **짧은 설명:** 진료 중 대화를 자동으로 녹음하고 관리하는 데스크톱 앱
- **상세 설명:** (200자 이상)
- **카테고리:** 의료/생산성
- **연령 등급:** 전체 이용가

#### 스크린샷 (최소 1개, 권장 4-5개)
- 1366x768 또는 1920x1080
- PNG 또는 JPEG
- 주요 화면 캡처:
  1. 메인 대시보드 (녹음 상태)
  2. 시간표 설정 화면
  3. 고급 설정 화면
  4. 자동 실행 매니저

#### 개인정보 처리방침
- URL 또는 텍스트로 제공
- 마이크 사용, 파일 저장 명시

#### 지원 정보
- 지원 이메일/웹사이트
- 문의처

---

## 🔒 인증서 및 비용

### MS Store 등록 (권장 ✅)
**총 비용: $19 (일회성)**

- **개발자 계정:** $19 (개인) 또는 $99 (기업)
- **인증서:** **불필요!**
  - Microsoft가 MSIX 업로드 시 자동으로 서명해줍니다
  - 별도의 Code Signing Certificate 구매 불필요
- **갱신:** 필요 없음 (계정 유지만 하면 됨)

**장점:**
- 가장 저렴한 방법
- 자동 업데이트 지원
- 신뢰할 수 있는 배포 경로
- 사용자 발견 가능성 증가

---

### MS Store 외부 배포 (비권장 ❌)
**총 비용: $200-500/년 (매년 지불)**

- **개발자 계정:** 불필요
- **Code Signing Certificate:** $200-500/년
  - DigiCert, GlobalSign 등에서 구매
  - 매년 갱신 필요
- **단점:**
  - 매년 비용 발생
  - 수동 배포 및 업데이트
  - 사용자 신뢰도 낮음

---

### 테스트용 자체 서명 (개발/테스트만)
```powershell
# 로컬 테스트 전용 - 배포 불가
New-SelfSignedCertificate -Type Custom -Subject "CN=Eyebottle" `
  -KeyUsage DigitalSignature -FriendlyName "Eyebottle Certificate" `
  -CertStoreLocation "Cert:\CurrentUser\My" `
  -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}")
```

**⚠️ 주의:** 자체 서명은 실제 사용자에게 배포 불가 (신뢰 경고 발생)

---

## ✅ 체크리스트

### 코드 품질
- [ ] 모든 경고(warnings) 해결
- [ ] Lint 오류 0개
- [ ] 포맷팅 완료
- [ ] 미사용 코드 제거

### 기능 완성도
- [ ] 모든 주요 기능 테스트 완료
- [ ] 에러 처리 완료
- [ ] 사용자 피드백 반영

### 문서화
- [ ] README.md 최신화
- [ ] CHANGELOG.md 작성
- [ ] 코드 주석 정리

### 빌드
- [ ] Release 빌드 성공
- [ ] MSIX 패키지 생성 성공
- [ ] 패키지 설치 테스트 성공

### 스토어 제출
- [ ] 모든 자료 준비 완료
- [ ] 스크린샷 준비
- [ ] 개인정보 처리방침 작성
- [ ] 제출 완료

---

## 📊 예상 일정

| Phase | 작업 | 예상 소요 | 상태 |
|-------|------|-----------|------|
| 1 | 코드 정리 | 1-2일 | ⏳ 대기 |
| 2 | 테스트 & 검증 | 1일 | ⏳ 대기 |
| 3 | 문서화 | 1일 | ⏳ 대기 |
| 4 | 빌드 & 패키징 | 1일 | ⏳ 대기 |
| 5 | MS Store 제출 | 1일 | ⏳ 대기 |

**총 예상 기간:** 5-7일

---

## 🎯 다음 단계

1. **진료실 테스트 완료 대기** (오늘)
2. **코드 정리 시작** (내일)
   - 디버그 로그 제거
   - 포맷팅 & 린트
3. **문서화 작업** (모레)
4. **MSIX 패키징 & 테스트**
5. **MS 개발자 계정 등록** ($19)
6. **MS Store 제출**

---

## 💰 총 비용 요약

| 항목 | 비용 | 빈도 | 비고 |
|------|------|------|------|
| MS 개발자 계정 (개인) | $19 | 일회성 | 필수 |
| Code Signing Certificate | $0 | - | **불필요** (MS가 자동 서명) |
| **총계** | **$19** | **일회성** | 🎉 |

---

**문서 작성일:** 2025-11-06
**최종 업데이트:** 2025-11-06 (인증서 비용 정보 수정)
