# HANDOFF — v1.3.17 백그라운드 시작 근본 안정화 + MS Store 만반 준비

작성일: 2026-05-29
이전 세션 ID: 1e5eb5bb-9e71-4da9-a299-de49172e6600
대상: 이 작업을 이어받는 다음 Claude Code 세션

---

## ⏱ 30초 요약 (TL;DR)

- **현재 상태**: MS Store 게시본은 v1.3.16. 진료실 PC에 설치 확인됨(`DCD952CB.367669DCDC1D3_tmhr7zc3de56j`). 그러나 **부팅 시 백그라운드(트레이) 시작이 작동 안 함** — 사용자 설정 "자동 실행 ON + 백그라운드 시작 ON" 상태에서도 부팅 후 메인 창이 보임.
- **두 모델(Opus tracer + Codex rescue) 분석 합의**: `windows/runner/main.cpp:43`의 무조건 `window.Show()` + `lib/main.dart:87`의 삼중 AND 조건이 구조적 약점. 두 가지를 같이 손봐야 race·중복체크 모두 제거됨.
- **로그 상태**: 진료실 PC `LocalState\Documents\EyebottleRecorder\logs\`에 부팅 모드 로그 없음 → 자동시작 모드에서 LoggingService 초기화 전에 종료/실패할 가능성 있음. 로깅 견고화도 함께 필요.
- **사용자 결정**: "오래 걸려도 좋으니 장기 안정성 우선". 5개 축(A/B/C/D/E) 전부 진행 합의. 그 뒤 핸드오프로 전환.
- **다음 세션 첫 행동**: 본 문서 § "다음 세션 첫 행동"의 순서대로 진행. 코드 변경은 § "5개 축 상세 작업"에 파일/줄/패치 형태로 명시.

---

## 1. 컨텍스트 / 배경

### 프로젝트
- Flutter Windows Desktop 앱 "아이보틀 진료녹음" (의료용 녹음)
- 배포: MS Store (MSIX). identity_name `DCD952CB.367669DCDC1D3`, publisher CN `0CEBC30B-3CD4-4E21-A48A-421AE62E38D3`
- Repo: `/home/usereyebottle/projects/eyebottlelee` (WSL 작업, 빌드는 Windows 측에서)

### 사용자 환경
- 개발 PC: **이 PC** (이전 세션이 작업한 환경). 앱은 설치 안 됨
- 진료실 PC: **실제 사용 환경**. v1.3.16 설치돼 있음. 사용자 퇴근 시간으로 원격 접근 어려움
- 사용자: `lee@eyebottle.kr` (의사, Eyebottle 운영)

### 현재 버전 상태
- `pubspec.yaml`: `version: 1.3.16+27`, `msix_version: 1.3.16.0`
- Git HEAD: `72ea3a0` (chore: pubspec.lock에서 launch_at_startup 잔존 제거) → `594bfba` (feat: v1.3.16 WinRT StartupTask API)
- 로컬 MSIX 빌드: `C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix` — **빌드 시각 2026-03-05 10:04 KST**, v1.3.16 정식 커밋(2026-03-05 21:57 KST)보다 11시간 53분 빠름. 이 빌드본은 정식 v1.3.16 코드가 아닐 가능성이 있음. **재빌드 필요.**
- `git status`: `docs/MS-STORE-SUBMISSION-v1.3.16-COMET-PROMPT.md` staged-modified (정리 미커밋)

---

## 2. 문제 정의

### 사용자가 보고한 정확한 증상 (AskUserQuestion 답변)
> "부팅시 백그라운드 시작 설정이 켜져 있어도, 항상 백그라운드 시작이 아니라 창이 켜져서 나와, 원하는 것은 트레이에만 있기를 기대"

### 현재 설정 (사용자 답변)
- "Windows 시작 시 자동 실행": **ON**
- "부팅 시 백그라운드로 시작": **ON**
- 그럼에도 부팅 후 메인 창이 표시됨

### 그동안의 시도 이력 (v1.3.4 → v1.3.16)
| 버전 | 일자 | 시도 |
|------|------|------|
| 1.3.4 | 2025-11-21 | 부팅 시 백그라운드 시작 옵션 첫 추가, `WindowOptions(skipTaskbar: shouldStartMinimized)` 등 |
| 1.3.9 | 2026-01-28 | `--autostart` 인자 기반 부팅 감지, PowerShell/WMIC 의존성 제거 |
| 1.3.10 | 2026-02-24 | MS Store 제출용 버전 업 |
| 1.3.15 | 2026-03-04 | `launch_at_startup` 패키지 안정화 + exit(0) 가드 제거 |
| 1.3.16 | 2026-03-05 | `launch_at_startup` 완전 제거 → WinRT StartupTask API로 근본 교체 |

여러 패턴 시도됨: `WindowOptions(skipTaskbar: shouldStartMinimized)` ↔ `setSkipTaskbar(true)→(false)` 토글 ↔ 현재의 `setSkipTaskbar(true)+hide()` 조합. 모두 race 또는 조건 평가 실패로 좌초.

---

## 3. 두 모델 정밀 분석 결과 요약

이전 세션에서 `oh-my-claudecode:tracer`(Opus 4.7)와 `codex:codex-rescue`(Codex)를 병렬로 띄워 독립 분석을 받음. 결론은 거의 일치.

### 합의된 두 가지 구조적 약점
1. **`windows/runner/main.cpp:43`의 무조건 `window.Show()`**
   - C++ 단에서 동기 `ShowWindow(SW_SHOWNORMAL)` 호출 — Dart 엔진 초기화 전에 창이 가시화
   - Dart의 `windowManager.waitUntilReadyToShow` 콜백은 첫 프레임 직전에 실행 → 그 사이 윈도우가 보임
   - 주석엔 "Dart가 가시성 제어"라 적혀 있지만 실제로는 race가 있음

2. **`lib/main.dart:87-88`의 삼중 AND 조건**
   ```dart
   shouldStartMinimized = hasAutostart && launchAtStartup && startMinimizedOnBoot
   ```
   - `--autostart` 인자가 OS에서 들어왔다는 것 자체가 이미 StartupTask 활성화 증거 → `launchAtStartup` SharedPreferences 추가 체크는 **중복**
   - MSIX 샌드박스에서 SharedPreferences 값 저장/조회 실패 시 false 반환 → 항상 창 표시 결과
   - `pubspec.yaml:81`의 `enabled: true`(매니페스트)와 SharedPreferences 기본값 `false`가 구조적 불일치

### 추가로 짚힌 약점
- **`lib/services/logging_service.dart:191-198`** — `_resolveLogDirectory`가 `getApplicationDocumentsDirectory()`만 사용. MSIX 컨테이너 → 실제 Documents 리디렉션이 환경에 따라 다름. fallback 없음 → 진료실 PC에서 로그 자체가 안 찾힘
- **`windows/runner/startup_task_handler.cpp:130`** — `Sleep(500)` 후 vtable[8] 직접 접근으로 WinRT async op 결과 가져옴. fragile, ABI 의존
- **`lib/ui/widgets/advanced_settings_dialog.dart:607` 주석** — *"launchAtStartup 설정은 더 이상 사용하지 않으나 호환성을 위해 유지"* → 그러면서 main.dart는 그 값을 AND 조건에 사용 중. 의도 불일치

### Opus와 Codex의 미묘한 차이
- Opus tracer: "H5(매니페스트↔SharedPreferences 불일치)가 최강"
- Codex rescue: "H3(SharedPreferences 저장 실패)가 가장 흔한 실제 원인"
- → 같은 경로(`shouldStartMinimized=false`)를 다른 각도로 본 것. 통합 결론은 동일

---

## 4. 합의된 5개 축 작업 계획

사용자 결정: **"오래 걸려도 좋으니 장기 안정성 좋은 방향. MS Store에 매번 올리는 게 스트레스"**. 전체 5개 축 진행 합의.

### A. 부팅 자동시작 로직 구조적 단순화 (필수)
**목표**: race / 중복 체크 / 의도 불일치를 동시에 제거

#### A1. `windows/runner/main.cpp` — `--autostart` 인자 있으면 `window.Show()` 호출 안 함
- 현재 (`main.cpp:40-43`):
  ```cpp
  // Always call Show() here. Window visibility is controlled by Dart's
  // windowManager.waitUntilReadyToShow() which hides the window initially
  // and shows/hides it in its callback based on --autostart and settings.
  window.Show();
  ```
- 변경 후:
  ```cpp
  // If launched by StartupTask with --autostart, leave the window hidden at
  // the native layer. Dart will call windowManager.show() only if it decides
  // the user wants the window visible. This eliminates the Show()→hide() race.
  bool launched_by_startup_task = false;
  for (const auto& arg : command_line_arguments) {
    if (arg == "--autostart") {
      launched_by_startup_task = true;
      break;
    }
  }
  if (!launched_by_startup_task) {
    window.Show();
  }
  ```
- 영향: 수동 실행 경로는 변화 없음. 자동시작 경로에서만 native Show 생략

#### A2. `lib/main.dart:82-134` — 조건 단순화 + show 흐름 보정
- `shouldStartMinimized` 평가를 **`hasAutostart && startMinimizedOnBoot`** 이중 AND로 축소
- `waitUntilReadyToShow` 콜백 안에서:
  - `shouldStartMinimized=true`: A1로 인해 native가 이미 hidden이므로 `setSkipTaskbar(true)`만 호출, `show()` 안 함
  - `hasAutostart=true && shouldStartMinimized=false` (자동시작인데 백그라운드 OFF): native가 hidden이므로 `show() + focus()` 명시적 호출 필요
  - `hasAutostart=false` (수동 실행): native가 이미 Show했으므로 `show() + focus()` 명시. (현재와 동일)
- 변경 패치 (주석 정리 포함):
  ```dart
  final hasAutostart = args.contains('--autostart');
  final settings = SettingsService();
  final startMinimizedOnBoot = await settings.getStartMinimizedOnBoot();
  final shouldStartMinimized = hasAutostart && startMinimizedOnBoot;
  gStartedInBackground = shouldStartMinimized;

  logging.info(
    'Background start decision: '
    'hasAutostart=$hasAutostart, '
    'startMinimizedOnBoot=$startMinimizedOnBoot → '
    'shouldStartMinimized=$shouldStartMinimized',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (shouldStartMinimized) {
      await windowManager.setSkipTaskbar(true);
      // 'hide()' 호출 불요 — native가 이미 hidden
      logging.info('Started minimized to tray (background mode)');
    } else {
      await windowManager.show();
      await windowManager.focus();
      logging.info('Started normally (visible window)');
    }
  });
  ```
- `getLaunchAtStartup()` 호출 자체를 제거. UI 토글(`advanced_settings_dialog.dart`)에서는 그대로 두지만 `main.dart` 분기에서는 안 씀.

#### A3. `lib/ui/screens/main_screen.dart:114-130` — 재숨김 백업 코드 단순화
- A1+A2가 본질적으로 막아주므로 "isVisible 체크 후 재hide" 백업은 불필요해지나, 안전망으로는 유지 가치 있음.
- 변경: 조건은 그대로 두되 로깅 수준을 `warning` → `info`로 (이제 정상 케이스이므로). 또는 코드 제거 후 회귀 시 재추가.
- 권장: 유지하되 주석 갱신:
  ```dart
  // v1.3.17: native main.cpp가 --autostart일 때 Show()를 안 부르므로
  // 평상시엔 여기서 isVisible=false. 만일을 위한 백업.
  ```

### B. 진단 가시성 — 로깅 견고화 + 앱 내 진단 패널
**목표**: 다음에 다시 문제가 생겨도 사용자가 1분 안에 원인을 캡처할 수 있도록

#### B1. `lib/services/logging_service.dart:191-199` — `_resolveLogDirectory` 견고화
- 1순위 시도: `getApplicationDocumentsDirectory() + EyebottleRecorder/logs`
- 1순위 실패/예외 시 fallback: `getApplicationSupportDirectory() + logs`
- 2순위까지 실패 시 fallback: `Platform.environment['LOCALAPPDATA'] + EyebottleRecorder\\logs`
- `info()` 한 번 더 호출 — fallback이 발동했음을 기록 (어디로 갔는지)
- 추가: 부팅 직후 첫 로그 라인을 `print()` (개발 빌드에선 stdout, MSIX에선 OutputDebugString을 통해 DebugView로 잡힘) — 파일 쓰기 실패해도 콘솔 트레이스 확보

#### B2. 앱 내 "진단" 패널 신설
- 위치: `lib/ui/widgets/advanced_settings_dialog.dart`의 마지막 섹션으로 "진단" 추가 (또는 별도 다이얼로그)
- 표시 항목:
  - 현재 `--autostart` 감지 여부 (gStartedInBackground 또는 별도 상태)
  - SharedPreferences `launch_at_startup` 값
  - SharedPreferences `start_minimized_on_boot` 값
  - StartupTask 상태 (`enabled/disabled/disabledByUser/disabledByPolicy/unavailable`)
  - 마지막 부팅 결정 트레이스 (B3에서 저장한 값)
  - 패키지 식별자 (`tryGetPackageFamilyName`)
  - 트레이 아이콘 초기화 성공/실패
  - 로그 디렉터리 경로 (B1에서 어디로 떨어졌는지)
- 버튼:
  - "로그 폴더 열기" → `Process.run('explorer', [logDir])`
  - "로그 zip 내보내기" → 사용자 데스크탑에 `eyebottle-diag-<날짜>.zip` 생성 (logs/ 전체 + diagnostic.json 포함)
  - "진단 정보 클립보드 복사" → 위 항목들을 텍스트로

#### B3. 부팅 결정 트레이스 영구 저장
- `SettingsService`에 새 키 `boot_decision_history` 추가
- 매 부팅 시 `main.dart`에서 다음 JSON 한 줄을 append (최대 10개 유지):
  ```json
  {
    "timestamp": "2026-05-29T08:15:23+09:00",
    "args": ["--autostart"],
    "hasAutostart": true,
    "startMinimizedOnBoot": true,
    "shouldStartMinimized": true
  }
  ```
- B2 진단 패널에서 표시

### C. 사이드로딩 기반 검증 파이프라인 — Store 안 거치는 검증
**목표**: 매번 MS Store 제출 안 거치고 진료실 PC에서 직접 .msix를 sideload해서 실전 테스트

#### C1. 자체 서명 인증서 발급
- PowerShell 스크립트 `scripts/sideload/create-cert.ps1`:
  - `New-SelfSignedCertificate`로 코드 사인 인증서 생성
  - publisher는 **현재 매니페스트와 동일한 CN** 사용 — `CN=0CEBC30B-3CD4-4E21-A48A-421AE62E38D3`
  - `.pfx`로 export (비밀번호 설정), `.cer`로 별도 export
- 결과: `scripts/sideload/eyebottle-sideload.pfx`, `eyebottle-sideload.cer`
- `.gitignore`에 `.pfx` 추가 필수

#### C2. 사이드로딩용 빌드 프로파일
- 두 옵션:
  - 옵션 ① — `pubspec.yaml`을 그대로 두고, 별도 빌드 명령 라인에서 `--certificate-path` 등을 지정. `flutter pub run msix:create --certificate-path=scripts/sideload/eyebottle-sideload.pfx --certificate-password=... --store=false`
  - 옵션 ② — `dev_pubspec_overrides.yaml`(또는 별도 yaml) 만들어서 `msix_config.store: false` + 서명 정보 박아둠
- 권장: 옵션 ①. 빌드 산출물 이름은 자동(`medical_recorder.msix`)이라 헷갈리므로 빌드 후 rename:
  - Store용: `medical_recorder.msix` (그대로)
  - Sideload용: `medical_recorder-sideload-<버전>-<날짜시간>.msix`

#### C3. 원클릭 설치/제거/진단 스크립트
- `scripts/sideload/install.ps1`:
  - 이전 버전 자동 제거 (`Get-AppxPackage DCD952CB.* | Remove-AppxPackage`)
  - 인증서가 `Cert:\LocalMachine\TrustedPeople\`에 등록돼 있는지 확인, 없으면 등록 (관리자 권한 요청)
  - 새 .msix 설치 (`Add-AppxPackage`)
  - 결과 표시 + 매니페스트 버전 확인
- `scripts/sideload/uninstall.ps1`:
  - `Get-AppxPackage DCD952CB.* | Remove-AppxPackage`
- `scripts/sideload/diagnose.ps1`:
  - 로그 디렉터리, 매니페스트, 패키지 정보, StartupTask 상태 모두 zip으로 묶음
  - 출력: `%USERPROFILE%\Desktop\eyebottle-diag-<날짜>.zip`

#### C4. 버전 라벨 분리
- 사이드로딩용 빌드는 빌드 후 매니페스트 버전을 그대로 두되 파일명에 `dev-YYYYMMDD-HHMM` 박기
- README 또는 docs에 "Store 빌드 vs Sideload 빌드 식별 방법" 명시

### D. 자동화된 사전 점검 (Pre-flight)
**목표**: 빌드 실수로 잘못된 MSIX를 올리지 않도록 자동 검증

#### D1. 빌드 후 자동 검증 스크립트
- `scripts/preflight/verify-msix.ps1`:
  - 인자: msix 경로 (기본 `build\windows\x64\runner\Release\medical_recorder.msix`)
  - 검사 항목:
    - 파일 존재 + 크기 합리성 (50MB 이상)
    - 안에서 `AppxManifest.xml` 추출 후:
      - `<Identity Version="..."/>` 값이 pubspec.yaml의 `version`과 일치
      - `<StartupTask Parameters="--autostart" Enabled="..."/>` 존재
      - `<DesktopExtension Category="windows.startupTask">` 존재
      - `<Capabilities>`에 `microphone`, `internetClient`, `runFullTrust` 모두 존재
    - 안에 `ffmpeg.exe` 자산 포함 여부
    - 빌드 시각 vs git HEAD 시각 비교 (빌드가 HEAD 이전이면 경고)
  - 모든 항목 ✅이면 종료 코드 0, 하나라도 ❌이면 1 + 사유 출력

#### D2. (선택) 사이드로딩 직후 헬스체크
- `scripts/preflight/post-install-check.ps1`:
  - `Get-AppxPackage DCD952CB.*`로 설치 확인
  - 매니페스트 추출 후 `<StartupTask>` 존재 확인
  - 윈도우 설정의 시작프로그램 상태 조회

### E. 회귀 방지 — 테스트 매트릭스 + CHANGELOG 강화
#### E1. `docs/STARTUP-TEST-MATRIX.md` 신설
- 매 빌드 시 거쳐야 할 검증 시나리오:
  | # | 시나리오 | 기대 결과 |
  |---|----------|-----------|
  | 1 | 신규 설치 후 수동 실행 | 메인 창 표시, 크래시 없음 |
  | 2 | 자동시작 ON + 백그라운드 OFF → 재부팅 | 메인 창 표시 |
  | 3 | 자동시작 ON + 백그라운드 ON → 재부팅 | 트레이만, 메인 창 안 보임 |
  | 4 | 자동시작 OFF → 재부팅 | 앱 실행 안 됨 |
  | 5 | Windows 설정에서 시작프로그램 OFF → 앱에서 토글 | "DisabledByUser" 안내 표시 |
  | 6 | 자동시작 ON → 토글 OFF → 다음 부팅 | 앱 실행 안 됨 |
  | 7 | 자동시작 ON + 백그라운드 ON → 트레이 아이콘 클릭 | 메인 창 정상 표시 |
  | 8 | 백그라운드 시작 후 녹음 → 정상 동작 | 녹음 정상 |
  | 9 | 부팅 → 진단 패널의 모든 항목 정상 | (B2 항목 모두 ✅) |
  | 10 | 부팅 → 로그 파일 생성 확인 | logs/ 안에 오늘 날짜 파일 |
- 각 시나리오의 "사용자 액션 → 기대 동작 → 확인 방법"을 한 줄씩

#### E2. CHANGELOG에 v1.3.17 부팅 동작 변경 명시
- `CHANGELOG.md`에 v1.3.17 섹션 추가 (§ "MS Store 업로드 문구 초안" 참조)

---

## 5. 실행 순서 (다음 세션이 따라갈 흐름)

1. **A1** (main.cpp 패치) — Edit
2. **A2** (lib/main.dart 패치) — Edit
3. **A3** (lib/ui/screens/main_screen.dart 주석 갱신) — Edit
4. **B1** (logging_service.dart 견고화) — Edit
5. **B3** (SettingsService에 boot_decision_history 키) — Edit
6. **B2** (advanced_settings_dialog.dart 진단 섹션) — Edit. 큰 작업
7. **C1** (create-cert.ps1) — Write
8. **C2** + **C3** (install/uninstall/diagnose.ps1) — Write
9. **D1** (verify-msix.ps1) — Write
10. **E1** (docs/STARTUP-TEST-MATRIX.md) — Write
11. **pubspec.yaml** 버전 업: `1.3.16+27` → `1.3.17+28`, `msix_version: 1.3.17.0`
12. **CHANGELOG.md** v1.3.17 섹션 추가
13. **docs/MS-STORE-SUBMISSION-v1.3.17-COMET-PROMPT.md** 작성 (§ "MS Store 업로드 문구" 그대로)
14. 사용자에게 빌드/검증/제출 가이드 한 줄로 정리 (§ "빌드/검증/제출 절차" 그대로)
15. git status / log 확인 후 사용자에게 "안드로이드 스튜디오에서 빌드만 누르시면 됩니다" 안내

---

## 6. 빌드 / 검증 / 제출 절차

다음 세션이 코드 변경 끝낸 뒤 사용자에게 안내할 정확한 순서.

### 6.1 로컬 빌드 (사용자 측 — Windows / 안드로이드 스튜디오)
```bash
flutter clean
flutter pub get
flutter build windows --release
flutter pub run msix:create
```
산출물: `build\windows\x64\runner\Release\medical_recorder.msix`

### 6.2 사전 점검 (D1 — Windows PowerShell)
```powershell
.\scripts\preflight\verify-msix.ps1
```
모든 항목 ✅ 확인.

### 6.3 사이드로딩 검증 (C — 진료실 PC)
1. 인증서가 진료실 PC에 등록돼 있지 않다면 1회만:
   ```powershell
   .\scripts\sideload\install-cert.ps1   # (C1 결과물 .cer 등록)
   ```
2. 빌드된 사이드로딩용 MSIX 진료실 PC로 전달
3. 설치:
   ```powershell
   .\scripts\sideload\install.ps1 -MsixPath .\medical_recorder-sideload-1.3.17-...msix
   ```
4. § E1 STARTUP-TEST-MATRIX의 시나리오 1~10 실행
5. 모든 시나리오 ✅이면 § 6.4 진행

### 6.4 MS Store 제출
1. `docs/MS-STORE-SUBMISSION-v1.3.17-COMET-PROMPT.md` 사용
2. Comet 브라우저에 프롬프트 그대로 붙여넣기
3. 자동 진행 → 제출 ID 받기
4. 게시 후 진료실 PC에서 Store 업데이트로 검증 (사이드로딩본 제거 후 Store본 설치)

---

## 7. MS Store 업로드 문구 초안

### 7.1 새 코멧 프롬프트 — `docs/MS-STORE-SUBMISSION-v1.3.17-COMET-PROMPT.md`

````markdown
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
• 로깅 fallback 경로 추가로 어떤 상태에서도 진단 가능
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
   wants the window visible.
2. main.dart: shouldStartMinimized = hasAutostart && startMinimizedOnBoot
   (reduced to two-AND; launchAtStartup removed from the boot decision).
3. logging_service.dart: tri-layer fallback for log directory resolution
   (getApplicationDocumentsDirectory → getApplicationSupportDirectory →
   %LOCALAPPDATA%), and earliest-possible init so boot-time failures
   always leave a log line.
4. advanced_settings_dialog: new "진단" section exposes --autostart
   detection, StartupTask state, boot decision history, and one-click
   log folder open / zip export.

TEST CASES:
1. Fresh install → manual launch → window visible, no crash
2. Startup ON + Background OFF → reboot → window visible
3. Startup ON + Background ON → reboot → tray only, no window flash
4. Startup OFF → reboot → app not launched
5. Disable via Windows Settings → app shows "DisabledByUser" guidance
6. Tray icon click in background mode → window restores
7. Boot in background → diagnostics panel all green
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
````

### 7.2 CHANGELOG.md 추가 섹션

```markdown
## [1.3.17] - <빌드 날짜>

### 🔧 버그 수정 — 부팅 자동시작 백그라운드 모드 안정화

v1.3.4부터 여러 차례 시도했지만 환경에 따라 간헐적으로 실패하던 "부팅 시 백그라운드(트레이)로만 시작" 기능을 **구조적으로 재설계**했습니다.

**해결된 문제:**
- ✅ 자동시작 ON + 백그라운드 시작 ON 상태에서도 메인 창이 보이던 문제
- ✅ 자동시작 모드에서 로그가 남지 않던 문제
- ✅ Dart `hide()`와 C++ `Show()`의 race condition

**기술적 변경:**
- `windows/runner/main.cpp`: `--autostart` 인자가 있으면 native 단의 `Show()` 호출 자체를 생략
- `lib/main.dart`: 백그라운드 시작 조건을 `hasAutostart && startMinimizedOnBoot` 이중 AND로 단순화 (이전 삼중 AND의 중복 체크 제거)
- `lib/services/logging_service.dart`: 로그 디렉터리 결정에 3단계 fallback 추가
- 앱 내 **"진단" 패널** 신설 — 자동시작/StartupTask/부팅 결정 이력을 한눈에 확인 가능

### 📦 패키지 정보
- **버전**: 1.3.17.0 (Build 28)
- **필수 OS**: Windows 10 버전 1809 이상
```

### 7.3 짧은 릴리스 노트 (Store "What's new" 한국어 한 화면 분)

```
v1.3.17 업데이트

[버그 수정]
• 부팅 시 "백그라운드로 시작"이 항상 작동하도록 근본 수정
• 자동시작 모드에서 로그가 안 남던 문제 해결

[안정성]
• 부팅 자동시작 흐름 구조 단순화 (race 제거)
• 앱 내 진단 패널 신설 — 자동시작 상태를 한눈에 확인
```

---

## 8. 다음 세션 첫 행동

1. 본 핸드오프 문서 전체 정독
2. 현재 git 상태 확인:
   ```bash
   git status
   git log --oneline -5
   cat pubspec.yaml | head -10
   ```
3. § "실행 순서" 1번(A1)부터 차례로 진행
4. 각 작업 끝낼 때마다 TaskUpdate로 진행 추적
5. 모든 코드 변경 끝나면 § 7의 문구 그대로 `docs/MS-STORE-SUBMISSION-v1.3.17-COMET-PROMPT.md` + CHANGELOG 작성
6. 사용자에게 § "빌드/검증/제출 절차"를 안내하면서 끝

### 주의 사항
- WSL에서 `flutter build windows`는 안 돌아감 → 빌드는 사용자가 Windows 측에서 해야 함을 명확히
- C축 (사이드로딩)은 인증서가 필요. 사용자가 인증서 보유 여부를 모를 수 있음 → C1 스크립트로 *생성 가능* 하다는 점을 안내
- 사용자가 거절한 AskUserQuestion 항목 중 "작업 범위"는 합의됨(전체 5축), "인증서 상태"와 "워크플로 선호"는 미합의 → C1 스크립트는 만들되 *실제로 인증서를 발급할지는 사용자에게 한 번 확인* 권장
- `docs/MS-STORE-SUBMISSION-v1.3.16-COMET-PROMPT.md`의 staged-modified 상태는 별도 정리 커밋 또는 v1.3.17 작업과 함께 커밋 가능

### 미합의 / 미해결 사항
- **C2 빌드 프로파일 옵션 ①/② 선택**: 기본 ①(빌드 명령 라인) 권장
- **C3 사이드로딩 인증서 비밀번호 보관 방법**: 환경 변수 vs 사용자 입력 — 권장은 사용자 입력 (스크립트 실행 시 prompt)
- **B3 부팅 결정 트레이스 보관 개수**: 10개로 진행 (변경 시 SettingsService 키만 수정)

---

## 9. 참고 자료 / 인용

### 이전 세션의 주요 발견
- 진료실 PC 패키지 확인: `DCD952CB.367669DCDC1D3_tmhr7zc3de56j` 존재 ✅
- 진료실 PC 로그 경로(`LocalState\Documents\EyebottleRecorder\logs\`)에 파일 없음 → B1 필요성의 직접 증거
- 로컬 MSIX 빌드 시각이 v1.3.16 정식 커밋보다 12시간 빠름 → 재빌드 필수

### 핵심 파일 한눈에
| 파일 | 라인 | 역할 |
|------|------|------|
| `windows/runner/main.cpp` | 40-43 | C++ 진입, `window.Show()` (A1 대상) |
| `lib/main.dart` | 82-134 | Dart 부팅 분기 (A2 대상) |
| `lib/ui/screens/main_screen.dart` | 114-130 | 위젯 빌드 후 백업 hide (A3 대상) |
| `lib/services/logging_service.dart` | 191-198 | 로그 디렉터리 결정 (B1 대상) |
| `lib/services/settings_service.dart` | 70, 86 | SharedPreferences 기본값 false |
| `lib/services/auto_launch_service.dart` | 27-49 | StartupTask 동기화 |
| `lib/services/startup_task_service.dart` | — | Dart Platform Channel 래퍼 |
| `windows/runner/startup_task_handler.cpp` | 130 | WinRT API 호출, Sleep(500) (선택 개선) |
| `pubspec.yaml` | 4, 75-82 | 버전, MSIX 설정, StartupTask |
| `lib/ui/widgets/advanced_settings_dialog.dart` | 509-598, 607 | 시작 설정 UI (B2 추가 대상) |

### 외부 의존성
- `window_manager`: 창 제어
- `path_provider`: 디렉터리 해석 (`getApplicationDocumentsDirectory` 등)
- `msix` (^3.16.7): MSIX 패키징
- `shared_preferences`: 설정 저장 (^2.3.2)

### 이전 세션 두 모델 분석 결과 원문 위치
- 본 문서 § 3에 핵심만 요약. 전체 원문은 이전 세션 transcript:
  `/home/usereyebottle/.claude/projects/-home-usereyebottle-projects-eyebottlelee/1e5eb5bb-9e71-4da9-a299-de49172e6600.jsonl`
- (필요 시 grep `"Hypothesis Table"` 또는 `"백그라운드 시작 실패 시나리오"`)

---

**작성 끝.** 다음 세션은 § "다음 세션 첫 행동"부터 시작하시면 됩니다.
