# 🤖 MS Store 제출용 프롬프트 (코멧 전달용)

---

## 📋 프롬프트 A: 제출 시작

```
Microsoft Store에 Windows 앱 업데이트를 제출하려고 합니다.
다음 정보를 바탕으로 제출 절차를 안내해주세요.

앱 이름: 아이보틀 진료녹음 & 자동실행 매니저
현재 버전: v1.3.3
새 버전: v1.3.4
Partner Center URL: https://partner.microsoft.com/dashboard

제출 파일:
- 경로: C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix
- 크기: 83 MB
- 빌드 시간: 2025-11-22 12:42:12

주요 변경사항:
1. Windows 부팅 시 백그라운드로 시작 옵션 추가
2. 앱 시작 로깅 강화
3. 자동 실행 기능 안정성 향상
4. 창 크기 설정 개선

질문:
1. Partner Center에서 새 제출을 시작하는 정확한 단계는?
2. 기존 v1.3.3 패키지를 어떻게 처리해야 하나요?
3. 패키지 업로드 시 주의사항은?
```

---

## 📝 프롬프트 B: 릴리스 노트 작성

```
MS Store 제출용 릴리스 노트를 검토해주세요.

아래 텍스트가 다음 기준을 충족하는지 확인해주세요:
- 사용자 친화적인가?
- 주요 기능이 명확하게 전달되는가?
- 너무 기술적이지 않은가?
- 오타나 문법 오류가 없는가?

[릴리스 노트 텍스트]
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

개선 제안이 있다면 알려주세요.
```

---

## 🔍 프롬프트 C: 인증 노트 검토

```
Microsoft Store 검토자를 위한 테스트 가이드를 작성했습니다.
다음 관점에서 검토해주세요:

1. 검토자가 기능을 테스트하기 충분히 명확한가?
2. 예상 동작이 구체적으로 설명되어 있는가?
3. 누락된 정보가 있는가?
4. 영어 문법이나 표현이 자연스러운가?

[인증 노트 텍스트]
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

검토 후 개선점을 알려주세요.
```

---

## ✅ 프롬프트 D: 제출 전 최종 체크

```
MS Store에 v1.3.4를 제출하기 직전입니다.
다음 체크리스트를 기반으로 누락된 항목이 없는지 확인해주세요:

패키지:
✅ MSIX 파일 업로드 완료 (medical_recorder.msix, 83 MB)
✅ 버전 1.3.4.0 확인
✅ 자동 검증 통과
✅ 기존 v1.3.3 패키지 삭제

속성:
✅ 앱 이름: 아이보틀 진료녹음 & 자동실행 매니저
✅ 범주: 생산성 (Productivity)
✅ 개인정보 처리방침 URL 입력됨

연령 등급:
✅ 연령 등급 설정 완료

스토어 목록:
✅ 릴리스 노트 입력 완료
✅ 스크린샷 업로드 (기존 유지)
✅ 앱 설명 확인

제출 옵션:
✅ 인증 노트 입력 완료
✅ 게시 옵션 확인

질문:
1. 제출 전 추가로 확인해야 할 항목이 있나요?
2. Microsoft 검토에서 거부될 가능성이 있는 부분은?
3. 일반적으로 승인까지 얼마나 걸리나요?
```

---

## 🚨 프롬프트 E: 문제 해결

```
MS Store 제출 중 문제가 발생했습니다.
상황을 설명하고 해결 방법을 알려주세요.

[여기에 실제 오류 메시지나 상황을 입력]

예시:
- 자동 검증 실패: [오류 코드]
- 인증 거부: [검토자 피드백]
- 업로드 실패: [에러 메시지]

배경 정보:
- 앱: 아이보틀 진료녹음 & 자동실행 매니저
- 버전: v1.3.4 (1.3.4.0)
- 플랫폼: Windows 10/11 데스크톱
- 이전 버전 (v1.3.3)은 정상 승인됨
```

---

## 📊 프롬프트 F: 제출 후 모니터링

```
MS Store에 v1.3.4를 제출했습니다.
제출 후 해야 할 일과 모니터링 방법을 알려주세요.

제출 정보:
- 제출 시간: [시간 입력]
- 제출 ID: [Partner Center에서 확인]
- 앱 버전: 1.3.4.0

질문:
1. 제출 상태는 어디서 확인하나요?
2. 검토 중 연락이 올 수 있는 경우는?
3. 승인 후 즉시 해야 할 작업은?
4. 사용자 피드백 모니터링 방법은?
```

---

## 🎯 프롬프트 G: 승인 후 작업

```
MS Store에서 v1.3.4가 승인되었습니다!
다음 단계를 안내해주세요.

승인 정보:
- 승인 시간: [시간 입력]
- Store 링크: https://www.microsoft.com/store/apps/9NDZB0QSL928

해야 할 작업:
1. Store에서 직접 설치하여 테스트
2. 백그라운드 시작 기능 검증
3. 로그 파일 확인
4. Git 커밋 push
5. GitHub Release 작성 (선택)

질문:
1. Store 출시 후 얼마나 기다려야 설치 가능한가요?
2. 사용자에게 업데이트가 자동으로 배포되나요?
3. 롤백이 필요한 경우 어떻게 하나요?
```

---

## 📝 사용 방법

### 단계별 프롬프트 사용:

1. **제출 시작 시** → 프롬프트 A 사용
2. **릴리스 노트 작성 시** → 프롬프트 B 사용
3. **인증 노트 작성 시** → 프롬프트 C 사용
4. **제출 직전** → 프롬프트 D 사용
5. **문제 발생 시** → 프롬프트 E 사용 (상황에 맞게 수정)
6. **제출 완료 후** → 프롬프트 F 사용
7. **승인 후** → 프롬프트 G 사용

### 복사-붙여넣기 방법:

1. 해당 프롬프트의 코드 블록(```) 내용 전체 복사
2. 코멧(AI 어시스턴트)에게 붙여넣기
3. 필요 시 [대괄호] 부분을 실제 값으로 수정
4. 전송

---

## 💡 팁

- **여러 프롬프트 조합 가능**: "프롬프트 B와 C를 모두 검토해주세요"
- **상황에 맞게 수정**: 대괄호 [] 부분은 실제 정보로 교체
- **피드백 반영**: 코멧의 제안을 받아 텍스트 수정 후 Partner Center에 입력
- **스크린샷 첨부**: 오류 발생 시 Partner Center 화면 캡처하여 함께 전달

---

**작성일:** 2025-11-22
**용도:** MS Store v1.3.4 제출 시 AI 어시스턴트 협업용
**문서 버전:** 1.0
