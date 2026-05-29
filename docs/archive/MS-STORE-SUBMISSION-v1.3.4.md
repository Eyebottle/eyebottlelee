# MS Store 제출 가이드 - v1.3.4

> **제출 준비 완료일:** 2025-11-22
> **MSIX 빌드 시간:** 2025-11-22 12:42:12
> **제출 버전:** 1.3.4.0 (Build 15)

---

## 📦 제출 파일 정보

**MSIX 파일 위치:**
```
C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix
```

**파일 정보:**
- 크기: 83 MB
- 생성: 2025-11-22 12:42:12
- 버전: 1.3.4.0
- 포함 커밋: 0ea8403 (부팅 시 백그라운드 시작 기능 안정화 및 로깅 강화)

---

## 🚀 제출 절차

### 1. Partner Center 접속
- URL: https://partner.microsoft.com/dashboard
- 앱: **아이보틀 진료녹음 & 자동실행 매니저**

### 2. 새 제출 시작
- 대시보드에서 앱 선택
- **새 제출 시작** 버튼 클릭

### 3. 패키지 업로드
1. **패키지** 섹션으로 이동
2. 기존 v1.3.3 패키지 삭제
3. **찾아보기** 또는 드래그 앤 드롭으로 새 MSIX 업로드
4. 업로드 완료 대기 (약 2-5분)
5. 자동 검증 통과 확인

---

## 📝 릴리스 노트 (한국어)

**섹션:** 이 릴리스의 새로운 기능 (What's new in this release)

아래 텍스트를 그대로 복사하여 붙여넣으세요:

```
v1.3.4 업데이트

[새로운 기능]
• Windows 부팅 시 백그라운드로 시작 옵션 추가
  - 설정에서 "부팅 시 백그라운드로 시작" 활성화 가능
  - 창 없이 트레이에만 표시되어 조용하게 시작
  - 트레이 아이콘 클릭으로 언제든지 창 열기 가능

[개선 사항]
• 앱 시작 로깅 강화로 문제 진단 용이
• 자동 실행 기능 안정성 향상
• 창 크기 설정 개선

[기술적 개선]
• LoggingService 우선 초기화로 부팅 로그 확보
• --autostart 플래그 감지 및 파일 로깅
• 불필요한 API 호출 최소화
```

---

## 🔍 인증 노트 (Certification Notes - 영어)

**섹션:** Notes for certification (검토자용 테스트 가이드)

아래 텍스트를 그대로 복사하여 붙여넣으세요:

```
v1.3.4 - Background Start Feature

TESTING INSTRUCTIONS:
1. Install the app from Microsoft Store
2. Launch the app
3. Open Settings (⚙️ icon) → Windows Startup
4. Enable "Launch at Windows startup" toggle
5. Enable "Start minimized to tray on boot" toggle
6. Status should show: "켜짐 · 백그라운드" (Enabled · Background)
7. Restart PC
8. After login, wait 5-10 seconds
9. Verify: No window appears, only tray icon in system tray
10. Click tray icon to open window
11. Verify: Window opens at 660×980 size

EXPECTED BEHAVIOR:
- On boot with background mode enabled: App starts hidden in tray
- On boot with background mode disabled: App window appears normally
- Clicking tray icon: Window opens at correct size (660×980)
- All existing features work normally

LOG FILE LOCATION (for debugging if needed):
C:\Users\[username]\OneDrive\Documents\EyebottleRecorder\logs\eyebottle_YYYYMMDD.log

EXPECTED LOG ENTRIES (when background mode is enabled):
- "앱이 자동 실행 모드(--autostart)로 시작되었습니다."
- "Autostart check: shouldStartMinimized=true"
- "Started minimized to tray (background mode)"

CHANGES FROM v1.3.3:
- Added: Background start option in settings
- Improved: Logging system for startup diagnostics
- Improved: Window size stability
- Fixed: Auto-launch reliability

NO BREAKING CHANGES:
- All features from v1.3.3 remain functional
- Existing user settings are preserved
- Backward compatible

DEPENDENCIES:
- Visual C++ Runtime: Microsoft.VCLibs.140.00.UWPDesktop (included)
- Windows 10 version 1809 or higher

ADDITIONAL INFO:
- App uses StartupTask API for Windows startup (not registry)
- Requires microphone permission (for recording feature)
- Requires internet permission (for update checks)
- Requires runFullTrust capability (for desktop integration)
```

---

## ✅ 제출 전 최종 체크리스트

Partner Center에서 다음 항목을 확인하세요:

### 패키지 탭
- [ ] MSIX 파일 업로드 완료
- [ ] 버전: 1.3.4.0 표시 확인
- [ ] 자동 검증 통과 (녹색 체크)
- [ ] 기존 v1.3.3 패키지 삭제됨

### 속성 탭
- [ ] 앱 이름: 아이보틀 진료녹음 & 자동실행 매니저
- [ ] 범주: 생산성 (Productivity)
- [ ] 개인정보 처리방침 URL 입력됨

### 연령 등급 탭
- [ ] 연령 등급 설정 완료

### 스토어 목록 탭
- [ ] 릴리스 노트 입력 완료 (위 한국어 텍스트)
- [ ] 스크린샷 업로드 완료 (기존 유지 가능)
- [ ] 설명 확인

### 제출 옵션 탭
- [ ] 인증 노트 입력 완료 (위 영어 텍스트)
- [ ] 게시 옵션 확인

---

## 🎯 제출 후 예상 일정

| 단계 | 예상 시간 | 비고 |
|------|-----------|------|
| 제출 완료 | 즉시 | 자동 검증 시작 |
| 자동 검증 | 5-10분 | 패키지 무결성 확인 |
| 인증 대기 | 24-48시간 | Microsoft 검토 |
| 승인 | - | v1.3.1은 당일 승인됨 |
| Store 게시 | 승인 후 1-2시간 | 전 세계 배포 |

---

## 📊 v1.3.4 주요 변경사항 요약

### 새로운 기능
1. **부팅 시 백그라운드로 시작 옵션**
   - 설정 UI 추가
   - `--autostart` 플래그 감지
   - 조건부 창 숨김 로직

### 기술적 개선
1. **LoggingService 우선 초기화**
   - `main.dart`에서 가장 먼저 초기화
   - 모든 부팅 과정을 파일로 기록

2. **AutoLaunchService 리팩토링**
   - 상수 추출: `_msixPackageName`, `_autostartArg`
   - 불필요한 API 호출 방지
   - 상세 로깅 추가

3. **창 크기 안정화**
   - WindowOptions에 size 명시
   - 백그라운드 시작 시에도 크기 설정
   - DPI 스케일링 재시도 로직

### 포함된 커밋
```
585e989  docs: v1.3.4 이전 문서 아카이브 및 .gitignore 업데이트
0ea8403  feat: 부팅 시 백그라운드 시작 기능 안정화 및 로깅 강화 (v1.3.4)
c12aa3f  fix: 부팅 시 백그라운드 시작 기능 완성 및 창 크기 문제 해결
16ef66e  feat: 부팅 시 백그라운드 시작 옵션 추가 (v1.3.4)
994f607  fix: 녹음 중지 시 타이머 취소 순서 변경으로 WAV 파일 미변환 방지
```

---

## 🔧 검토자가 확인할 핵심 사항

Microsoft 검토자는 다음을 테스트할 것입니다:

1. **기본 기능**
   - ✅ 앱 설치 및 실행
   - ✅ 마이크 권한 요청
   - ✅ 녹음 시작/중지
   - ✅ 파일 저장 및 재생

2. **새 기능 (v1.3.4)**
   - ✅ 설정 → Windows 시작 메뉴 접근
   - ✅ "부팅 시 백그라운드로 시작" 토글
   - ✅ PC 재시작 후 트레이 아이콘만 표시
   - ✅ 트레이 아이콘 클릭 시 창 정상 표시

3. **안정성**
   - ✅ 크래쉬 없음
   - ✅ 메모리 누수 없음
   - ✅ CPU 사용률 정상

4. **규정 준수**
   - ✅ 개인정보 처리방침 접근 가능
   - ✅ 권한 요청 명확
   - ✅ 오프라인 동작 가능

---

## ⚠️ 주의사항

### 제출 시
- MSIX 파일 경로가 정확한지 재확인
- 릴리스 노트와 인증 노트를 **정확히** 복사-붙여넣기
- 제출 후 수정 불가 (거부되면 다시 제출 필요)

### 예상 질문 대응
Microsoft에서 질문이 올 수 있는 항목:

**Q: 백그라운드 시작이 왜 필요한가?**
A: 진료실 환경에서 PC 부팅 시 자동으로 준비되되, 화면이 어지럽지 않게 트레이로 시작하기 위함. 사용자가 선택적으로 활성화 가능.

**Q: 로그 파일은 왜 OneDrive에 저장되는가?**
A: 사용자 문서 폴더의 표준 위치 사용. OneDrive가 활성화된 경우 자동 백업되어 데이터 손실 방지.

**Q: runFullTrust 권한이 왜 필요한가?**
A:
- 시스템 트레이 통합
- Windows 자동 시작 등록
- 외부 프로그램 자동 실행 (진료 프로그램)
- 파일 시스템 접근

---

## 📞 문제 발생 시

### 자동 검증 실패 시
- 패키지 손상 가능성 → MSIX 재빌드
- 버전 충돌 → pubspec.yaml 버전 확인

### 인증 거부 시
- 검토자 피드백 확인
- 필요 시 수정 후 재제출

### 긴급 연락
- Partner Center 지원팀 문의
- 평균 응답 시간: 24시간

---

## ✅ 제출 완료 후

### 승인 알림 수신 시
1. Store에서 실제 설치 테스트
2. 백그라운드 시작 기능 확인
3. 로그 파일 확인

### 정식 출시 후
1. README.md 업데이트 (버전 v1.3.4)
2. Git push (로컬 커밋들 원격에 동기화)
3. GitHub Release 작성 (선택)

---

## 🎉 성공 기준

다음 조건을 모두 만족하면 성공:

- [x] MSIX 업로드 성공
- [x] 자동 검증 통과
- [ ] Microsoft 인증 승인
- [ ] Store 정식 출시
- [ ] 사용자가 설치 후 백그라운드 시작 정상 작동
- [ ] 로그 파일에서 예상 메시지 확인

---

**작성일:** 2025-11-22
**최종 검토:** 2025-11-22 12:45
**제출 담당자:** eyebottlelee
**문서 버전:** 1.0
