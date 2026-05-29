# MS Store v1.3.17 — 브라우저 조작 Claude용 최종 프롬프트

> 크롬을 직접 조작하는 Claude(browser automation)에게 아래 **"프롬프트"** 블록을
> 그대로 복사해 전달하세요. 로그인은 사용자가 직접 하며, Claude는 로그인 화면에서
> 멈추고 기다립니다. 최종 "제출" 직전에도 사용자 확인을 받습니다.

---

## 프롬프트 (이 아래 전체를 복사)

```
너는 지금 Chrome 브라우저를 직접 조작해서 Microsoft Store(Partner Center)에 앱
업데이트를 제출하는 작업을 맡았다. 아래 절차를 한 단계씩, 각 단계의 결과를
화면에서 확인하며 진행해라. 추측으로 넘어가지 말고, 버튼/입력란을 실제로 찾은
뒤 클릭/입력해라. 한국어로 진행 상황을 보고해라.

[중요 규칙]
1. 로그인: Microsoft 로그인 화면이 나오거나 로그인이 안 되어 있으면, 절대
   직접 로그인 정보를 입력하지 마라. 즉시 멈추고 사용자에게 이렇게 말해라:
   "로그인 화면입니다. 직접 로그인해 주시고, 완료되면 '로그인 완료'라고
   알려주세요." 사용자가 완료를 알릴 때까지 기다린 뒤 다음 단계로 진행해라.
2. 2단계 인증(OTP/Authenticator)도 마찬가지로 사용자에게 맡기고 기다려라.
3. 최종 "제출(Submit)" 버튼은 사용자 확인 없이 누르지 마라(아래 12번 참조).
4. 각 단계에서 예상한 버튼/요소를 못 찾으면, 화면을 캡처해 무엇이 보이는지
   사용자에게 설명하고 어떻게 할지 물어라.

[제출 정보]
- 앱: "아이보틀 진료녹음" (앱 목록에서 "아이보틀"로 검색/식별)
- 새 버전: 1.3.17.0
- 업로드할 파일(이 PC 경로):
  C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix
- 직전 버전: 1.3.16 (패키지 탭에서 발견되면 삭제하고 새로 올림)

[절차]
1. https://partner.microsoft.com/dashboard 로 이동해라.
2. 로그인이 안 되어 있으면 위 [중요 규칙] 1번대로 멈추고 사용자를 기다려라.
   로그인이 되어 있으면 다음으로 진행.
3. 앱 목록(또는 "내 앱")에서 "아이보틀"로 시작하는 앱(아이보틀 진료녹음 /
   아이보틀 진료녹음 & 자동실행 매니저)을 찾아 클릭해라. 정확한 이름이
   애매하면 후보를 사용자에게 확인받아라.
4. "새 제출 시작"(Start submission / Update) 버튼을 클릭해라. 이미 진행 중인
   draft 제출이 있으면, 사용자에게 "기존 미완료 제출이 있습니다. 삭제하고 새로
   만들까요, 이어서 할까요?"라고 물어본 뒤 답에 따라 진행해라.
5. "패키지(Packages)" 탭으로 이동해라.
6. 기존 패키지(1.3.16 이하)가 보이면 X/삭제 버튼으로 제거해라.
7. "찾아보기(Browse)"를 눌러 파일 선택 창을 열고, 위 [제출 정보]의 .msix
   경로를 입력/선택해 업로드해라:
   C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix
8. 업로드 후 자동 검증이 끝날 때까지 기다려라(진행 표시가 사라지고 녹색
   체크/성공 표시가 뜰 때까지). 패키지 버전이 1.3.17.0 으로 표시되는지
   확인해라. 경고/오류가 뜨면 그 내용을 사용자에게 그대로 보고하고 멈춰라.
9. "스토어 목록(Store listings)" → 한국어(ko-kr) 목록으로 이동해라.
   "이 릴리스의 새로운 기능 / What's new in this release" 입력란에 아래를
   그대로 입력해라:

v1.3.17 업데이트

[버그 수정]
• 부팅 시 자동시작했을 때 메인 창이 떠버리는 문제 해결
• "백그라운드로 시작" 옵션이 항상 트레이로만 실행되도록 정상화
• 자동시작 모드에서 로그가 남지 않던 문제 수정

[안정성 강화]
• 부팅 자동시작 흐름의 구조적 race 제거
• 로깅 경로 다단계 탐색 추가로 어떤 상태에서도 진단 가능
• 앱 내 "진단" 패널 신설 — 자동시작/StartupTask 상태를 한눈에 확인

   (만약 글자 수 초과/"too long" 오류가 나면 위 내용을 아래 한 줄로 교체해라:
    v1.3.17: 부팅 시 백그라운드 시작 안정화 + 진단 패널)

10. "제출 옵션(Submission options)" 탭으로 이동해라. "인증 노트(Notes for
    certification)" 입력란에 아래 영문을 그대로 입력해라:

v1.3.17 - Fix: boot-to-tray reliability + diagnostics panel

ROOT CAUSE (background-to-tray failure):
In v1.3.16, windows/runner/main.cpp always called window.Show() at the
native layer before Dart finished initializing. The Dart-side
windowManager.hide() in the waitUntilReadyToShow callback raced against
this and lost on slower hardware, leaving the main window visible even
when the user enabled "Start minimized to tray".

Additionally, the Dart-side shouldStartMinimized condition required a
redundant launchAtStartup SharedPreferences flag in addition to the
"--autostart" CLI argument. The presence of "--autostart" already proves
Windows StartupTask activated the app; if the SharedPreferences read
failed or returned its default, the boot-to-tray option silently broke.

FIX (structural, not a workaround):
1. main.cpp: skip window.Show() when --autostart is present, leaving the
   native window hidden. Dart calls show() only when the user wants it.
2. main.dart: shouldStartMinimized = hasAutostart && startMinimizedOnBoot
   (removed the redundant launchAtStartup term from the boot decision).
3. logging_service.dart: prioritized log directory resolution with a
   write-probe so boot-time failures always leave a log line.
4. Added an in-app diagnostics panel exposing --autostart detection,
   StartupTask state, boot decision history, and log folder access.

TEST CASES:
1. Fresh install -> manual launch -> window visible, no crash
2. Startup ON + Background OFF -> reboot -> window visible
3. Startup ON + Background ON -> reboot -> tray only, no window flash
4. Tray icon click in background mode -> window restores
5. Recording works after a background (tray) boot

Requires: Windows 10 1809+, VCLibs.140.00.UWPDesktop

11. 입력한 내용들을 "저장(Save)"해라. (가격/배포 등 다른 탭은 기존 설정을
    그대로 두고 변경하지 마라.)
12. 최종 제출 직전 확인: "제출(Submit)" 버튼을 누르기 전에, 다음을 요약해
    사용자에게 보고하고 "제출할까요?"라고 물어라. 사용자가 명시적으로
    "제출"이라고 답할 때까지 누르지 마라:
    - 업로드된 패키지 버전(1.3.17.0)
    - "새로운 기능" 입력 완료 여부
    - "인증 노트" 입력 완료 여부
    - 검증 경고/오류 유무
13. 사용자가 확인하면 "제출(Submit)"을 눌러라.
14. 제출이 완료되면 제출 ID(Submission ID)와 상태(예: "인증 진행 중")를
    사용자에게 보고해라.

[문제 발생 시]
- 어떤 단계든 예상과 다른 화면이 나오면 멈추고, 현재 화면을 캡처/설명한 뒤
  사용자에게 어떻게 할지 물어라. 임의로 새 항목을 만들거나 기존 설정을
  바꾸지 마라.
```

---

## 사용 메모 (사용자용 — 브라우저 Claude에게 전달하지 않아도 됨)

- 업로드 파일은 **반드시 v1.3.17 빌드본**이어야 합니다. 빌드 시각이 오늘인지
  탐색기에서 확인: `medical_recorder.msix`가 최신(2026-05-29 빌드).
- 브라우저 Claude는 같은 Windows PC에서 실행되어야 파일 선택 창에서 위 경로에
  접근할 수 있습니다.
- 제출 후 게시까지 보통 수 시간~1일 소요. 게시되면 진료실 PC에서 Store 업데이트로
  받은 뒤 `docs/STARTUP-TEST-MATRIX.md` 시나리오 3(자동시작+백그라운드 ON →
  재부팅 → 트레이만)을 1회 확인하세요.
