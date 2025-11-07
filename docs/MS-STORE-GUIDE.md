# 🏪 MS Store 출시 가이드 - 마스터 문서

> **📌 이 문서가 MS Store 출시 작업의 메인 가이드입니다.**
>
> 새로운 세션에서 작업을 시작할 때 이 문서를 참조하세요.

---

## 📚 관련 문서

1. **[ms-store-release-plan.md](./ms-store-release-plan.md)** - 상세 작업 계획 및 타임라인
2. **[ms-store-publish.md](./ms-store-publish.md)** - MS Store 정책 준수 체크리스트

---

## 🎯 현재 상태 (2025-11-07 업데이트)

### ✅ 완료
- [x] v1.3.0 릴리즈 빌드 생성
- [x] 진료실 테스트용 배포 (`C:\Users\user\OneDrive\이안과\eyebottlelee-v1.3.0-release\`)
- [x] 시간표 버그 수정 (요일 매핑 오류)
- [x] 스케줄 리셋 로직 개선
- [x] 저장기간 자동 정리 검증
- [x] **WAV 중단 변환 문제 해결** (녹음 중지 시에도 마지막 파일 AAC 변환)
- [x] **Phase 1: 코드 정리 완료** (2025-11-06)
  - 디버그 로그 정리 (🔧, 🐛 제거)
  - dart format, flutter analyze, dart fix 실행
  - 사용되지 않는 코드 제거 (5개 항목)
  - 이슈 58개 → 48개 (경고 0개)
- [x] **Phase 2: 자동화 테스트 완료** (2025-11-06)
  - 공식 로고 적용 (eyebottle.kr)
  - 파일 구조 검증 (5/5)
  - 서비스 파일 확인 (9/9)
  - 의존성 확인 (7/7)
  - Release 빌드 성공 (34.6초)
  - 자동화 스크립트 3개 생성
- [x] **Phase 3: 문서화 완료** (2025-11-06)
  - CHANGELOG.md 작성 (v1.3.0)
  - README.md 업데이트 (버전, 주요 기능)
  - 릴리즈 노트 작성
  - MS-STORE-GUIDE.md 업데이트
  - 스크린샷 가이드 작성
  - MSIX 패키징 체크리스트 작성

### 🔄 진행 중
- [x] **Phase 4: MSIX 패키징 완료** (2025-11-07)
  - [x] pubspec.yaml 설정 확인 (msix_version: 1.3.0.0)
  - [x] 필수 파일 확인 (icon.ico 172KB, ffmpeg.exe 182MB)
  - [x] Release 빌드 성공
  - [x] **MSIX 패키지 생성 성공 (83MB)** ✨
  - [x] **세그먼트 분할 WAV 변환 버그 수정** ⭐
  - [x] 전체 재빌드 및 배포
  - [ ] 개발 PC MSIX 설치 테스트 (수동)
  - [ ] 진료실 .exe 실사용 테스트 (수동)

### ⏳ 대기 중 (수동 개입 필요)

**진료실 컴퓨터 (.exe 실행):**
- [ ] 10분 이상 장시간 녹음 테스트
- [ ] 세그먼트 분할 시 WAV → AAC 변환 확인
- [ ] 시간표 자동 녹음 동작 확인
- [ ] 로고 표시 확인
- 위치: `C:\Users\user\OneDrive\이안과\eyebottlelee-v1.3.0-wav-fix\medical_recorder.exe`
- 제약: MSIX 설치 불가 (보안 정책)

**개발 컴퓨터 (MSIX 설치):**
- [ ] MSIX 로컬 설치 테스트
- [ ] MSIX 환경에서 FFmpeg 실행 확인
- [ ] 모든 기능 동작 확인
- [ ] WACK 테스트 (선택적)
- 위치: `C:\Users\user\OneDrive\이안과\eyebottlelee-v1.3.0-wav-fix\medical_recorder.msix`
- 가이드: `docs/msix-dev-test-guide.md`

**Phase 5 준비:**
- [ ] MS Store 제출

---

## 💰 MS Store 출시 비용

| 항목 | 비용 | 빈도 |
|------|------|------|
| MS 개발자 계정 (개인) | **$19** | 일회성 |
| Code Signing Certificate | **$0** | 불필요 (MS 자동 서명) |
| **총계** | **$19** | **한 번만 지불** |

---

## 📅 작업 로드맵

### Phase 1: 코드 정리 (1-2일) ⏳
**시작 조건:** 진료실 테스트 완료 및 문제 없음

**작업 내용:**
```bash
# 1. 디버그 로그 정리
grep -r "🐛\|🔧" lib/ --include="*.dart"
# → audio_service.dart, schedule_service.dart 등 수정

# 2. 포맷팅 & 린트
dart format lib/
flutter analyze
dart fix --apply

# 3. TODO 처리
grep -r "TODO\|FIXME" lib/ --include="*.dart"
# → 2개 항목 처리 또는 Issue로 이동

# 4. 불필요한 주석 제거
# → 주석 처리된 오래된 코드 제거
# → 문서화 주석(///)은 유지
```

**완료 기준:**
- [ ] `flutter analyze` 경고 0개
- [ ] TODO 항목 0개 또는 Issue로 이동
- [ ] 디버그 로그 최소화 (중요한 것만 유지)
- [ ] 코드 포맷팅 완료

---

### Phase 2: 테스트 & 검증 (1일)
- [ ] 모든 주요 기능 재테스트
- [ ] 에지 케이스 테스트
- [ ] 성능 테스트 (메모리 누수, CPU 사용량)
- [ ] Windows 10 & 11 호환성 확인

---

### Phase 3: 문서화 (1일)
- [ ] **CHANGELOG.md** 작성
  ```markdown
  # v1.3.0 (2025-11-XX)

  ## 🆕 새로운 기능
  - WAV 자동 변환 기능

  ## 🐛 버그 수정
  - 시간표 요일 매핑 오류 수정
  - 스케줄 리셋 로직 개선

  ## ✨ 개선사항
  - 저장기간 자동 정리 안정화
  ```

- [ ] **README.md** 업데이트
- [ ] **릴리즈 노트** 작성

---

### Phase 4: MSIX 패키징 (1일)

**4.1. pubspec.yaml 설정**
```yaml
msix_config:
  display_name: 아이보틀 진료 녹음
  publisher_display_name: Eyebottle
  identity_name: eyebottle.medical.recorder
  msix_version: 1.3.0.0
  logo_path: assets/icons/icon.ico
  capabilities: "microphone, internetClient"
```

**4.2. MSIX 생성**
```bash
# Release 빌드
flutter build windows --release

# MSIX 패키지 생성
dart run msix:create

# 생성 위치
# build/windows/x64/runner/Release/medical_recorder.msix
```

**✅ 4.2 실행 결과 (2025-11-07)**
```
소요 시간:
- Flutter 빌드: 18.4초
- MSIX 빌드: 34.2초
- MSIX 패킹: 12.2초
- 총 소요 시간: ~64.8초

파일 정보:
- 파일명: medical_recorder.msix
- 크기: 83 MB
- 위치: C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\
- 패키지 버전: 1.3.0.0
- 아키텍처: x64
```

**4.3. 로컬 테스트**
```powershell
# 개발자 모드 활성화 후
Add-AppxPackage -Path "medical_recorder.msix"

# 테스트
# 1. 설치 확인
# 2. 모든 기능 동작 확인
# 3. 제거 후 재설치 테스트
```

**4.4. WACK 테스트**
```powershell
# Windows App Certification Kit 실행
# 모든 항목 통과 확인
```

---

### Phase 5: MS Store 제출 (1일)

**5.1. MS 개발자 계정 등록**
- URL: https://partner.microsoft.com/dashboard
- 비용: $19 (개인) / $99 (기업)
- 결제 후 즉시 사용 가능

**5.2. Partner Center에서 앱 생성**
1. "새 앱" 클릭
2. 앱 이름 예약: "아이보틀 진료 녹음"
3. 카테고리: 의료 / 생산성

**5.3. 스토어 리스팅 작성**

**앱 설명 (샘플):**
```
아이보틀 진료 녹음 - 진료실을 위한 스마트 녹음 솔루션

진료 중 환자와의 대화를 자동으로 녹음하고 체계적으로 관리하는
Windows 데스크톱 애플리케이션입니다.

🎙️ 주요 기능
• 진료 시간표 기반 자동 녹음
• 10분 단위 자동 파일 분할
• WAV → AAC/Opus 자동 변환 (용량 90% 절감)
• 마이크 자동 진단
• OneDrive 백업 및 보관 기간 관리
• 진료실 프로그램 자동 실행

💡 특징
• 완전 자동화 - 설정 후 자동 동작
• 안전한 로컬 저장
• 직관적인 3탭 UI
• 시스템 트레이 지원
```

**스크린샷 준비 (4-5장):**
1. 메인 대시보드 (녹음 상태)
2. 진료 시간표 설정 화면
3. 고급 설정 (WAV 변환)
4. 자동 실행 매니저
5. 도움말 화면

**개인정보 처리방침:**
```
아이보틀 진료 녹음 개인정보 처리방침

1. 수집하는 정보
- 마이크 입력 (녹음 파일)
- 앱 설정 정보 (로컬 저장)

2. 정보 사용 목적
- 진료 녹음 기능 제공
- 사용자 설정 저장

3. 정보 저장 및 보안
- 모든 데이터는 로컬에만 저장
- 외부 서버로 전송되지 않음
- 사용자가 직접 관리 및 삭제 가능

4. 제3자 제공
- 없음

5. 문의
eyebottle@example.com
```

**5.4. MSIX 업로드**
- Partner Center에서 "패키지" 섹션
- medical_recorder.msix 업로드
- Microsoft가 자동으로 서명 및 검증

**5.5. 제출**
- 모든 정보 입력 확인
- "심사 제출" 클릭
- 2-3일 대기

---

## ✅ 최종 체크리스트

### 코드 품질
- [ ] `flutter analyze` 경고 0개
- [ ] `dart format` 완료
- [ ] TODO 항목 처리
- [ ] 디버그 로그 정리
- [ ] 주석 정리

### 기능 완성도
- [ ] 모든 주요 기능 동작 확인
- [ ] 에러 처리 완료
- [ ] 진료실 테스트 통과

### 문서화
- [ ] CHANGELOG.md
- [ ] README.md 최신화
- [ ] 릴리즈 노트

### 빌드 & 패키징
- [ ] Release 빌드 성공
- [ ] MSIX 생성 성공
- [ ] 로컬 설치 테스트 통과
- [ ] WACK 테스트 통과

### MS Store 제출
- [ ] 개발자 계정 등록 ($19)
- [ ] 앱 리스팅 작성
- [ ] 스크린샷 준비 (4-5장)
- [ ] 개인정보 처리방침 작성
- [ ] MSIX 업로드
- [ ] 제출 완료

---

## 🔄 새 세션에서 작업 재개 방법

### 1. 현재 상태 확인
```bash
# 이 문서 열기
code docs/MS-STORE-GUIDE.md

# 현재 Phase 확인
# → 체크리스트에서 완료된 항목 확인
```

### 2. 다음 작업 확인
- "현재 상태" 섹션의 "진행 중" 항목 확인
- 해당 Phase의 "작업 내용" 참조

### 3. 작업 시작
```bash
# Phase 1 (코드 정리)이면
grep -r "🐛" lib/ --include="*.dart"
# → 로그 제거 작업 시작

# Phase 2 (테스트)면
# → 테스트 시나리오 실행

# Phase 4 (MSIX)면
flutter build windows --release
dart run msix:create
```

---

## 📞 중요 링크

- **MS Partner Center:** https://partner.microsoft.com/dashboard
- **개발자 계정 등록:** https://developer.microsoft.com/microsoft-store/register
- **MSIX 문서:** https://learn.microsoft.com/windows/msix/
- **Flutter MSIX 플러그인:** https://pub.dev/packages/msix

---

## 🎯 최종 목표

**"아이보틀 진료 녹음"을 MS Store에 성공적으로 출시하여:**
- ✅ $19만 지불 (인증서 비용 $0)
- ✅ 자동 업데이트 지원
- ✅ 사용자 신뢰도 향상
- ✅ 검색 가능성 증가

---

**문서 작성일:** 2025-11-06
**최종 업데이트:** 2025-11-06
**다음 업데이트:** 진료실 테스트 완료 후
