# v1.3.16 코드 리뷰 및 재검증 프롬프트

아래 프롬프트를 다른 AI 에이전트에게 전달하여 재검증을 요청하세요.

---

## 프롬프트

```
당신은 Flutter Windows 데스크톱 앱의 코드 리뷰어입니다.
v1.3.16에서 치명적 버그 수정과 아키텍처 변경이 이루어졌습니다.
변경 내용을 검증하고, 누락된 부분이나 잠재적 위험을 찾아주세요.

───────────────────────────────────────
## 1. 배경 (반드시 읽고 이해하세요)
───────────────────────────────────────

### 앱 정보
- 앱 이름: 아이보틀 진료녹음 & 자동실행 매니저
- 프레임워크: Flutter 3.x (Windows Desktop)
- 배포: Microsoft Store (MSIX 패키지)
- 프로젝트 경로: /home/usereyebottle/projects/eyebottlelee

### 크래시 원인 (v1.3.14 → v1.3.15에서 미완전 수정)
`launch_at_startup` v0.5.1 패키지의 MSIX 구현체가
`Process.runSync('powershell', ...)` 로 .lnk 바로가기 파일을 만드는 방식을 사용했습니다.
MSIX 샌드박스에서 이 PowerShell 호출이 **네이티브 레벨에서 크래시**되어
Dart의 try-catch를 우회합니다.
SharedPreferences에 `launchAtStartup=true`가 저장된 상태에서
매 실행마다 크래시가 반복되는 **영구 데스 루프**가 발생했습니다.

### v1.3.16 수정 방향 (근본 교체)
임시방편(패키지 제거 + uptime 해킹)이 아닌,
**WinRT StartupTask API를 C++ Platform Channel로 직접 구현**하여 근본적으로 교체했습니다.

───────────────────────────────────────
## 2. 변경된 파일 목록 (모두 검토하세요)
───────────────────────────────────────

### 신규 C++ 파일 (Windows runner)
1. `windows/runner/startup_task_handler.h` — Platform Channel 헤더
2. `windows/runner/startup_task_handler.cpp` — WinRT StartupTask API 구현 (핵심)

### 수정된 C++ 파일
3. `windows/runner/CMakeLists.txt` — 파일 추가, RuntimeObject.lib 링크
4. `windows/runner/flutter_window.cpp` — RegisterStartupTaskChannel 호출 추가

### 신규 Dart 파일
5. `lib/services/startup_task_service.dart` — Platform Channel Dart 래퍼

### 수정된 Dart 파일
6. `lib/services/auto_launch_service.dart` — 전면 재작성 (WinRT API 기반)
7. `lib/main.dart` — --autostart 인자 감지 복원, uptime 해킹 제거
8. `lib/ui/widgets/advanced_settings_dialog.dart` — 자동 실행 토글 복원
9. `lib/ui/screens/main_screen.dart` — 실제 StartupTask 상태 전달

### 수정된 설정 파일
10. `pubspec.yaml` — v1.3.16, launch_at_startup 의존성 제거, startup_task 설정

───────────────────────────────────────
## 3. 검증 요청 사항
───────────────────────────────────────

### A. C++ Platform Channel 코드 검증 (가장 중요)

파일: `windows/runner/startup_task_handler.cpp`

검증 항목:
1. **WinRT COM 인터페이스 정의가 정확한가?**
   - IStartupTask의 vtable 레이아웃 (RequestEnableAsync, Disable, get_State, get_TaskId)
   - IStartupTaskStatics의 vtable 레이아웃 (GetForCurrentPackageAsync, GetAsync)
   - 인터페이스 IID가 Windows SDK와 일치하는가?

2. **IAsyncOperation<StartupTask> 결과 추출이 올바른가?**
   - vtable index 8에서 GetResults를 호출하는 것이 맞는가?
   - IInspectable(6) + put_Completed(1) + get_Completed(1) + GetResults(1) = index 8 가정
   - Sleep(500)으로 비동기 대기하는 것이 안전한가? 더 나은 방법은?

3. **메모리 관리**
   - COM 객체의 Release() 호출이 모든 경로에서 정확한가?
   - HSTRING의 WindowsDeleteString() 호출이 누락되지 않았는가?
   - asyncOp 객체의 Release()가 모든 분기에서 이루어지는가?

4. **에러 처리**
   - RoGetActivationFactory 실패 시 안전하게 처리되는가?
   - MSIX가 아닌 환경(개발 모드)에서 크래시하지 않는가?
   - GetStartupTask()가 nullptr를 반환할 때 모든 호출자가 안전한가?

5. **스레딩**
   - Platform Channel 핸들러가 UI 스레드에서 실행되는데, Sleep(500)이 문제가 되지 않는가?
   - WinRT async 작업을 동기적으로 대기하는 것이 STA에서 데드락을 유발하지 않는가?

### B. Dart 코드 검증

1. **startup_task_service.dart**
   - Platform Channel 메서드 이름이 C++과 일치하는가?
   - MissingPluginException 처리가 모든 메서드에 있는가?
   - 반환값 타입이 C++ 쪽과 매칭되는가?

2. **auto_launch_service.dart**
   - enable()/disable() 호출 후 settings도 함께 저장하는가?
   - getStatusSnapshot()에서 새로운 필드(startupTaskState, startupTaskEnabled)가 올바른가?

3. **main.dart**
   - `--autostart` 인자 감지가 MSIX StartupTask 실행에서만 발생하는지 확인
   - `hasAutostart && launchAtStartup && startMinimizedOnBoot` 세 조건이 모두 필요한 이유가 타당한가?
   - `args` 파라미터가 `_initializeApp`에 올바르게 전달되는가?

4. **advanced_settings_dialog.dart**
   - `_launchAtStartup` 상태가 WinRT API에서 올바르게 초기화되는가?
   - `_startupDisabledByUser` 상태에서 토글이 비활성화되는가?
   - `_save()`에서 enable()/disable() 호출이 올바른가?
   - AutoLaunchService import가 복원되었는가?

5. **main_screen.dart**
   - `_autoLaunchEnabled` 필드가 존재하고 초기화되는가?
   - `statusSnapshot.startupTaskEnabled`를 `_autoLaunchEnabled`에 올바르게 할당하는가?
   - `_SettingsTab`에 `_autoLaunchEnabled`를 전달하는가?

### C. MSIX Manifest 검증

`pubspec.yaml`의 msix_config 섹션:
- `startup_task.task_id: EyebottleMedicalRecorder` — C++ 코드의 TaskId 문자열과 일치하는가?
- `startup_task.parameters: "--autostart"` — main.dart의 args.contains('--autostart')와 일치하는가?
- `startup_task.enabled: true` — manifest에 StartupTask가 포함되는가?

### D. 삭제된 코드 검증

- `launch_at_startup` 패키지가 pubspec.yaml에서 완전히 제거되었는가?
- `win32_system_uptime.dart` (uptime 해킹)가 어디서도 import되지 않았는가?
- `dart:io` import가 main.dart에서 제거되었는가? (더 이상 필요 없으므로)

### E. 잠재적 위험 분석

1. **C4819 경고 재발 가능성**: C++ 파일에 non-ASCII 문자가 포함되면 빌드 실패
2. **vtable 레이아웃 오류**: 잘못된 인덱스로 함수 호출 시 크래시
3. **Sleep(500) 부족**: 느린 시스템에서 async 작업이 완료되지 않을 수 있음
4. **STA 데드락**: UI 스레드에서 WinRT async를 동기 대기 시 발생 가능
5. **기존 사용자 마이그레이션**: SharedPreferences에 launchAtStartup=true가 남아있는 사용자

───────────────────────────────────────
## 4. 실행 방법
───────────────────────────────────────

### 정적 분석
dart analyze lib/

### 빌드 (Windows 환경 필요)
cmd.exe /c "C: && cd C:\ws-workspace\eyebottlelee && flutter build windows --release"

### MSIX 패키징
cmd.exe /c "C: && cd C:\ws-workspace\eyebottlelee && dart run msix:create"

### 현재 빌드 상태
- dart analyze: 0 errors, 0 warnings (info 3개는 기존 deprecated 경고)
- flutter build windows --release: 성공 (14.5초)
- dart run msix:create: 성공 (medical_recorder.msix 생성)

───────────────────────────────────────
## 5. 출력 형식
───────────────────────────────────────

검증 결과를 다음 형식으로 보고해주세요:

### 치명적 이슈 (출시 차단)
- [있으면 나열]

### 중요 이슈 (출시 전 수정 권장)
- [있으면 나열]

### 경미한 이슈 (다음 버전에서 개선)
- [있으면 나열]

### 검증 통과 항목
- [확인된 항목 나열]

### 최종 판정
- [ ] 출시 가능
- [ ] 수정 후 출시
- [ ] 재설계 필요
```
