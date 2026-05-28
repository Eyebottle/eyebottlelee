# MS Store v1.3.17 코멧 프롬프트

아래 프롬프트를 코멧 브라우저에 그대로 복사-붙여넣기하세요.

---

## 프롬프트

```
Microsoft Store Partner Center에서 앱 업데이트를 제출해줘.

1. https://partner.microsoft.com/dashboard 에 접속해.
2. 로그인이 안 되어 있으면 로그인해.
3. 앱 목록에서 "아이보틀 진료녹음 & 자동실행 매니저"를 클릭해.
4. "새 제출 시작" 또는 "Start submission" 버튼을 클릭해. 기존 draft 제출이 있으면 삭제하고 새로 만들어.
5. "패키지" 또는 "Packages" 탭으로 이동해.
6. 기존 패키지(v1.3.16 이하)가 있으면 X 버튼으로 삭제해.
7. "찾아보기" 또는 "Browse"를 클릭하고 이 파일을 업로드해: C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix
8. 업로드 후 자동 검증이 통과(녹색 체크마크)되는지 확인해. 버전이 1.3.17.0으로 표시되어야 해.
9. "스토어 목록" 탭으로 이동해.
10. "이 릴리스의 새로운 기능" 또는 "What's new in this release" 입력란에 아래 내용을 입력해:

v1.3.17 업데이트

[버그 수정]
• 부팅 시 자동시작했을 때 메인 창이 떠버리는 문제 해결
• "백그라운드로 시작" 옵션이 항상 트레이로만 실행되도록 정상화
• 자동시작 모드에서 로그가 남지 않던 문제 수정

[안정성 강화]
• 부팅 자동시작 흐름의 구조적 race 제거
• 로깅 경로 다단계 탐색 추가로 어떤 상태에서도 진단 가능
• 앱 내 "진단" 패널 신설 — 자동시작/StartupTask 상태를 한눈에 확인

11. "제출 옵션" 또는 "Submission options" 탭으로 이동해.
12. "인증 노트" 또는 "Notes for certification" 입력란에 아래 내용을 입력해:

v1.3.17 - Fix: boot-to-tray reliability + diagnostics panel

ROOT CAUSE (background-to-tray failure):
In v1.3.16, windows/runner/main.cpp always called window.Show() at the
native layer before Dart finished initializing. The Dart-side
windowManager.hide() in the waitUntilReadyToShow callback raced against
this and lost on slower hardware, leaving the main window visible even
when the user enabled "Start minimized to tray".

Additionally, the Dart-side shouldStartMinimized condition was a triple
AND of (hasAutostart && launchAtStartup && startMinimizedOnBoot). The
launchAtStartup SharedPreferences flag was redundant — the presence of
the "--autostart" CLI argument already proves Windows StartupTask
activated the app. If SharedPreferences read failed or returned the
default false, the user-visible boot-to-tray option silently broke.

FIX (Structural, not workaround):
1. main.cpp: skip window.Show() when --autostart is present, leaving the
   native window hidden. Dart explicitly calls show() only when the user
   wants the window visible. This eliminates the Show()->hide() race.
2. main.dart: shouldStartMinimized = hasAutostart && startMinimizedOnBoot
   (reduced to two-AND; launchAtStartup removed from the boot decision).
3. logging_service.dart: prioritized log directory resolution
   (getApplicationDocumentsDirectory -> getApplicationSupportDirectory ->
   %LOCALAPPDATA% -> system temp) with a write-probe so boot-time failures
   always leave a log line in a writable location.
4. advanced_settings_dialog: new diagnostics section exposes --autostart
   detection, StartupTask state, boot decision history, and one-click
   log folder open / diagnostics copy.

TEST CASES:
1. Fresh install -> manual launch -> window visible, no crash
2. Startup ON + Background OFF -> reboot -> window visible
3. Startup ON + Background ON -> reboot -> tray only, no window flash
4. Startup OFF -> reboot -> app not launched
5. Disable via Windows Settings -> app shows "DisabledByUser" guidance
6. Tray icon click in background mode -> window restores
7. Boot in background -> diagnostics panel all consistent
8. Boot decision history persists across reboots (last 10 entries)

Requires: Windows 10 1809+, VCLibs.140.00.UWPDesktop

13. "저장" 후 "제출"을 클릭해.
14. 제출 완료 후 제출 ID를 알려줘.
```

---

**참고:** "long file" 에러가 발생하면 10번의 릴리스 노트를 아래로 교체:

```
v1.3.17: 부팅 시 백그라운드 시작 안정화 + 진단 패널
```
