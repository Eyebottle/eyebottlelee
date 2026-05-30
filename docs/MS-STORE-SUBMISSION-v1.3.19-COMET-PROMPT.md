# MS Store v1.3.19 코멧 프롬프트

아래 프롬프트를 코멧 브라우저에 그대로 복사-붙여넣기하세요.
(빌드가 끝나 `medical_recorder.msix`가 v1.3.19.0로 생성된 뒤에 진행)

---

## 프롬프트

```
Microsoft Store Partner Center에서 앱 업데이트를 제출해줘.

1. https://partner.microsoft.com/dashboard 에 접속해.
2. 로그인이 안 되어 있으면 로그인해.
3. 앱 목록에서 "아이보틀 진료녹음 & 자동실행 매니저"를 클릭해.
4. "새 제출 시작" 또는 "Start submission" 버튼을 클릭해. 기존 draft 제출이 있으면 삭제하고 새로 만들어.
5. "패키지" 또는 "Packages" 탭으로 이동해.
6. 기존 패키지(v1.3.17 이하)가 있으면 X 버튼으로 삭제해.
7. "찾아보기" 또는 "Browse"를 클릭하고 이 파일을 업로드해: C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix
8. 업로드 후 자동 검증이 통과(녹색 체크마크)되는지 확인해. 버전이 1.3.19.0으로 표시되어야 해.
9. "스토어 목록" 탭으로 이동해.
10. "이 릴리스의 새로운 기능" 또는 "What's new in this release" 입력란에 아래 내용을 입력해:

v1.3.19 업데이트

[버그 수정]
• 일부 PC에서 "백그라운드로 시작"을 켜도 부팅 시 창이 뜨던 문제 해결
• 바로가기(.lnk) 등록 시 실행이 안 되던 문제 해결
• 경고 표시가 보이지 않던 문제 수정

[새로운 기능]
• 자동실행 목록에 파일을 끌어다 놓아(드래그 앤 드롭) 바로 등록
• 프로그램별 창 상태(일반/최소화/최대화)가 실제로 적용됨

[안정성]
• 부팅 자동시작 판별 로직 보강(인자 미전달 환경 대응)
• 오디오 변환 멈춤 방지(타임아웃) 및 내부 코드 정리

11. "제출 옵션" 또는 "Submission options" 탭으로 이동해.
12. "인증 노트" 또는 "Notes for certification" 입력란에 아래 내용을 입력해:

v1.3.19 - Fix: boot-to-tray on systems where StartupTask args are not delivered

ROOT CAUSE (boot-to-tray still failing for some users):
v1.3.16/1.3.17 detected a startup launch by checking for a "--autostart"
command-line argument declared via the MSIX StartupTask
uap10:Parameters attribute. On some Windows 10 setups this parameter is
NOT delivered as an actual command-line argument to the full-trust
process (the boot-decision history showed args=[] even though the
StartupTask state was "enabled"). With no argument, the app could not tell
a boot launch from a manual launch, so the main window appeared on boot
even when the user enabled "Start minimized to tray".

FIX (Structural):
1. windows/runner/main.cpp: the native layer no longer calls window.Show()
   at all. The window is created hidden (ForceRedraw renders the first
   frame) and visibility is decided entirely by Dart. This removes the
   native-Show vs Dart-hide race for every launch path.
2. lib/main.dart: boot detection no longer depends solely on the argument.
   shouldStartMinimized = startMinimizedOnBoot AND
     (hasAutostart OR systemUptime < 5 minutes).
   The system-uptime signal (GetTickCount64) reliably identifies a launch
   that happens shortly after boot/login, while a manual launch later in
   the session still shows the window normally.
3. Diagnostics panel now records system uptime and the derived
   "likely boot launch" flag in the boot-decision history for support.

ALSO IN THIS RELEASE:
- Auto-launch manager now launches programs/shortcuts via the Windows
  shell (ShellExecuteEx) instead of "cmd /c start". This fixes .lnk
  shortcuts, removes a console-window flash, and applies the per-program
  window state (normal/minimized/maximized).
- Drag-and-drop registration of programs.
- Quote-aware command-line argument parsing (paths with spaces).
- ffmpeg WAV conversion now has a 5-minute timeout so a stuck conversion
  cannot permanently stall the queue.
- Dead-code cleanup (~1,050 lines removed) and a transparent "warning"
  color bug fixed.

TEST CASES:
1. Enable "Start minimized to tray", reboot -> only the tray icon appears,
   no main window. Click the tray icon -> window opens at 660x980.
2. "Start minimized" OFF, reboot -> main window appears normally.
3. Launch manually during the day (long after boot) -> window appears.
4. Auto-launch manager: register a .lnk shortcut, click Test -> it runs.
5. Drag an .exe/.lnk onto the auto-launch card -> it is added to the list.
6. Recording, scheduling, and WAV->m4a conversion all work as before.

Requires: Windows 10 1809+, VCLibs.140.00.UWPDesktop

13. "저장" 후 "제출"을 클릭해.
14. 제출 완료 후 제출 ID를 알려줘.
```

---

**참고:** "long file" 에러가 발생하면 10번의 릴리스 노트를 아래로 교체:

```
v1.3.19: 부팅 백그라운드 시작 안정화 + 바로가기/드래그 등록 + 정리
```
