# MS Store v1.3.18 — 브라우저 조작 Claude용 최종 프롬프트

> 크롬을 직접 조작하는 Claude(browser automation)에게 아래 **"프롬프트"** 블록을
> 그대로 복사해 전달하세요. 로그인은 사용자가 직접 하며, Claude는 로그인 화면에서
> 멈추고 기다립니다. 최종 "제출" 직전에도 사용자 확인을 받습니다.
>
> ⚠️ **먼저 빌드부터**: 이 프롬프트는 v1.3.18 `.msix`가 빌드되어 있어야 동작합니다.
> 같은 Windows PC에서 아래를 먼저 실행하세요(데스크톱 드롭 신규 의존성 때문에
> `flutter pub get`·`flutter analyze`가 반드시 선행):
>
> ```powershell
> bash scripts/sync_wsl_to_windows.sh
> cd C:\ws-workspace\eyebottlelee
> flutter pub get
> flutter analyze          # 0 error 확인 후 진행
> pwsh -File scripts/windows/build-msix.ps1
> ```

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
- 새 버전: 1.3.18.0
- 업로드할 파일(이 PC 경로):
  C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix
- 직전 버전: 1.3.17 (패키지 탭에서 발견되면 삭제하고 새로 올림)

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
6. 기존 패키지(1.3.17 이하)가 보이면 X/삭제 버튼으로 제거해라.
7. "찾아보기(Browse)"를 눌러 파일 선택 창을 열고, 위 [제출 정보]의 .msix
   경로를 입력/선택해 업로드해라:
   C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix
8. 업로드 후 자동 검증이 끝날 때까지 기다려라(진행 표시가 사라지고 녹색
   체크/성공 표시가 뜰 때까지). 패키지 버전이 1.3.18.0 으로 표시되는지
   확인해라. 경고/오류가 뜨면 그 내용을 사용자에게 그대로 보고하고 멈춰라.
9. "스토어 목록(Store listings)" → 한국어(ko-kr) 목록으로 이동해라.
   "이 릴리스의 새로운 기능 / What's new in this release" 입력란에 아래를
   그대로 입력해라:

v1.3.18 업데이트

[버그 수정]
• 일부 PC에서 "백그라운드로 시작"을 켜도 부팅 시 창이 뜨던 문제 해결
• 자동실행에 바로가기(.lnk)를 등록해도 실행되지 않던 문제 해결
• 일부 경고 표시가 보이지 않던 문제 수정

[새로운 기능]
• 자동실행 목록에 파일·바로가기를 끌어다 놓아(드래그 앤 드롭) 바로 등록
• 프로그램별 창 상태(일반/최소화/최대화)가 실제로 적용됨

[안정성]
• 부팅 자동시작 판별 로직 보강(시작 인자 미전달 환경 대응)
• 오디오 변환 멈춤 방지(타임아웃) 및 내부 코드 정리

   (만약 글자 수 초과/"too long" 오류가 나면 위 내용을 아래 한 줄로 교체해라:
    v1.3.18: 부팅 백그라운드 시작 안정화 + 바로가기/드래그 등록 + 정리)

10. "제출 옵션(Submission options)" 탭으로 이동해라. "인증 노트(Notes for
    certification)" 입력란에 아래 영문을 그대로 입력해라:

v1.3.18 - Fix: boot-to-tray on PCs where StartupTask args are not delivered

ROOT CAUSE (boot-to-tray still failing for some users):
v1.3.16/1.3.17 detected a startup launch by checking for a "--autostart"
command-line argument declared via the MSIX StartupTask uap10:Parameters
attribute. On some Windows 10 setups this parameter is NOT delivered as an
actual command-line argument to the full-trust process (the in-app boot
history showed args=[] even though the StartupTask state was "enabled").
With no argument the app could not distinguish a boot launch from a manual
launch, so the main window appeared on boot even with "Start minimized to
tray" enabled.

FIX (structural):
1. windows/runner/main.cpp: the native layer no longer calls window.Show().
   The window is created hidden and visibility is decided entirely by Dart.
   This removes the native-Show vs Dart-hide race on every launch path.
2. lib/main.dart: boot detection no longer depends solely on the argument:
   shouldStartMinimized = startMinimizedOnBoot AND
     (hasAutostart OR systemUptime < 5 minutes).
   The system-uptime signal (GetTickCount64) reliably identifies a launch
   shortly after boot/login; a manual launch later still shows the window.
3. Diagnostics panel now records system uptime and the derived
   "likely boot launch" flag in the boot-decision history for support.

ALSO IN THIS RELEASE:
- Auto-launch manager launches programs/shortcuts via the Windows shell
  (ShellExecuteEx) instead of "cmd /c start": fixes .lnk shortcuts, removes
  a console-window flash, and applies the per-program window state.
- Drag-and-drop registration of programs; quote-aware argument parsing.
- ffmpeg WAV conversion now has a 5-minute timeout so a stuck conversion
  cannot permanently stall the queue. Dead-code cleanup (~1,050 lines).

TEST CASES:
1. Fresh install -> manual launch -> window visible, no crash
2. "Start minimized" ON -> reboot -> tray only, no window (KEY FIX)
3. "Start minimized" OFF -> reboot -> window visible
4. Launch manually long after boot -> window visible
5. Auto-launch manager: register a .lnk shortcut, Test -> it runs
6. Drag an .exe/.lnk onto the auto-launch card -> it is added
7. Recording / scheduling / WAV->m4a conversion work as before

Requires: Windows 10 1809+, VCLibs.140.00.UWPDesktop

11. 입력한 내용들을 "저장(Save)"해라. (가격/배포 등 다른 탭은 기존 설정을
    그대로 두고 변경하지 마라.)
12. 최종 제출 직전 확인: "제출(Submit)" 버튼을 누르기 전에, 다음을 요약해
    사용자에게 보고하고 "제출할까요?"라고 물어라. 사용자가 명시적으로
    "제출"이라고 답할 때까지 누르지 마라:
    - 업로드된 패키지 버전(1.3.18.0)
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

- 업로드 파일은 **반드시 v1.3.18 빌드본**이어야 합니다. 탐색기에서
  `medical_recorder.msix` 속성 → 자세히 → 제품 버전이 **1.3.18.0**, 빌드 시각이
  오늘인지 확인하세요.
- **신규 의존성(desktop_drop)** 때문에 빌드 전 `flutter pub get`이 반드시
  선행되어야 하며, `flutter analyze`로 에러 0을 확인한 뒤 빌드하세요.
  (이번 변경은 WSL에서 컴파일 검증을 하지 못했으므로 analyze가 최종 게이트입니다.)
- 브라우저 Claude는 같은 Windows PC에서 실행되어야 파일 선택 창에서 위 경로에
  접근할 수 있습니다.
- 제출 후 게시까지 보통 수 시간~1일 소요. 게시되면 진료실 PC에서 Store 업데이트로
  받은 뒤 **재부팅 테스트**를 1회 확인하세요:
  "백그라운드 시작 ON → 재부팅 → 창이 뜨지 않고 트레이만". 만약 창이 뜨면
  앱 내 진단 패널의 부팅 이력에서 `uptime` 값을 확인해 알려주세요(5분 초과 시
  임계값 조정이 필요).
