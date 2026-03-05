# MS Store v1.3.16 코멧 프롬프트

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
6. 기존 패키지(v1.3.15 이하)가 있으면 X 버튼으로 삭제해.
7. "찾아보기" 또는 "Browse"를 클릭하고 이 파일을 업로드해: C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix
8. 업로드 후 자동 검증이 통과(녹색 체크마크)되는지 확인해. 버전이 1.3.16.0으로 표시되어야 해.
9. "스토어 목록" 탭으로 이동해.
10. "이 릴리스의 새로운 기능" 또는 "What's new in this release" 입력란에 아래 내용을 입력해:

v1.3.16 업데이트

[긴급 버그 수정]
• 자동 실행 설정 시 앱이 시작되지 않는 치명적 크래시 수정
• launch_at_startup 패키지를 WinRT StartupTask API로 완전 교체
• 앱 내에서 자동 실행 ON/OFF 토글 복원

[개선]
• WinRT StartupTask API를 Platform Channel로 직접 호출
• Windows가 사용자 설정에서 비활성화한 경우 UI에 안내 표시
• 시작프로그램 상태를 OS와 정확히 동기화

11. "제출 옵션" 또는 "Submission options" 탭으로 이동해.
12. "인증 노트" 또는 "Notes for certification" 입력란에 아래 내용을 입력해:

v1.3.16 - CRITICAL FIX: Replace launch_at_startup with WinRT StartupTask API

ROOT CAUSE:
The launch_at_startup v0.5.1 package used Process.runSync('powershell', ...)
to create .lnk shortcuts instead of the proper WinRT StartupTask API.
In the MSIX sandbox, PowerShell calls crash natively (not a Dart exception),
bypassing all try-catch handlers and creating a permanent death loop.

FIX (Fundamental replacement, not a workaround):
- Completely removed launch_at_startup package
- Implemented WinRT StartupTask API via C++ Platform Channel
  (windows/runner/startup_task_handler.cpp)
- App now directly calls RequestEnableAsync(), Disable(), get_State()
  through the proper Windows.ApplicationModel.StartupTask API
- Restored in-app autostart toggle with real-time OS state sync
- Detects "DisabledByUser" state (when user disabled via Windows Settings)
  and shows appropriate guidance
- Boot-time detection uses MSIX manifest uap10:Parameters="--autostart"

TEST CASES:
1. Fresh install > App launches normally > No crash
2. Settings > Toggle "Launch at Startup" ON > Reboot > App auto-starts
3. Settings > Toggle "Launch at Startup" OFF > Reboot > App does not start
4. Settings > Background start ON + Startup ON > Reboot > Starts to tray
5. Manual launch after reboot > App shows window normally
6. Disable via Windows Settings > App shows "DisabledByUser" guidance

13. "저장" 후 "제출"을 클릭해.
14. 제출 완료 후 제출 ID를 알려줘.
```

---

## 변경 사항 요약

### 근본 원인
`launch_at_startup` v0.5.1의 MSIX 구현체가 PowerShell로 .lnk 바로가기를 생성 → MSIX 샌드박스에서 네이티브 크래시

### 근본 수정 (임시방편 아님)
- `launch_at_startup` 패키지 **완전 제거**
- **WinRT StartupTask API를 C++ Platform Channel로 직접 구현**
  - `RequestEnableAsync()` → 자동 실행 활성화
  - `Disable()` → 자동 실행 비활성화
  - `get_State()` → 현재 상태 조회 (Enabled/Disabled/DisabledByUser/DisabledByPolicy)
- 앱 내 자동 실행 토글 **완전 복원**
- `DisabledByUser` 상태 감지 및 UI 안내

### 영향 파일
| 파일 | 변경 유형 |
|------|-----------|
| `windows/runner/startup_task_handler.h` | 신규 (Platform Channel 헤더) |
| `windows/runner/startup_task_handler.cpp` | 신규 (WinRT StartupTask API 구현) |
| `windows/runner/CMakeLists.txt` | 수정 (파일 추가, RuntimeObject 링크) |
| `windows/runner/flutter_window.cpp` | 수정 (채널 등록) |
| `lib/services/startup_task_service.dart` | 신규 (Dart Platform Channel 래퍼) |
| `lib/services/auto_launch_service.dart` | 전면 재작성 (WinRT API 기반) |
| `lib/main.dart` | 수정 (--autostart 인자 감지 복원) |
| `lib/ui/widgets/advanced_settings_dialog.dart` | 수정 (토글 복원) |
| `lib/ui/screens/main_screen.dart` | 수정 (실제 StartupTask 상태 표시) |
| `pubspec.yaml` | 수정 (v1.3.16, launch_at_startup 제거) |
