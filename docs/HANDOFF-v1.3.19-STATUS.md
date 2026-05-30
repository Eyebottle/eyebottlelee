# 핸드오프 — v1.3.19 상태 / 다음 작업 (2026-05-30)

브랜치: `feat/v1.3.18-launch-boot-refactor` (main 대비 7커밋). main 미머지.

---

## 1. 지금 어디까지 됐나

**v1.3.19.0 빌드·검증 완료, MS Store 제출(업로드) 단계.**

- `medical_recorder.msix` = **1.3.19.0** (Build 30), ffmpeg 번들 포함, 2026-05-30 빌드
- `flutter analyze` 에러 0 / 경고 0 (사전 deprecation info 3건만 — 빌드 무관)
- `flutter build windows --release` + `dart run msix:create` 성공
- `scripts/preflight/verify-msix.ps1` 전 항목 OK (버전/StartupTask/capability/ffmpeg)
- 업로드 경로: `C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix`
  (OneDrive 복사본: `C:\Users\user\OneDrive\이안과\eyebottlelee-msix-latest\`)
- 제출 프롬프트: `docs/MS-STORE-SUBMISSION-v1.3.19-BROWSER-CLAUDE-PROMPT.md` (+ COMET 버전)

**버전 주의:** Store는 같은 버전(1.3.18.0) 재업로드를 막고 **revision(4번째 자리)=0을 강제**한다.
그래서 1.3.18.1이 아니라 build 자리를 올려 **1.3.19.0**으로 재빌드했다. 다음에도 동일 규칙
(1.3.20.0 식, revision 항상 0).

## 2. v1.3.19에 들어간 것

**부팅 백그라운드(트레이) 시작 — 근본 수정 (이 릴리스의 핵심)**
- 근본 원인 확정: MSIX StartupTask의 `uap10:Parameters="--autostart")`가 진료실 Win10 Home에서
  실제 argv로 전달되지 않음(진단 이력 `args=[]`, hasAutostart=false). full-trust 앱 + 1903 미만 등.
- 수정: `main.cpp`는 native `Show()` 호출을 완전히 제거(Dart가 가시성 단독 제어, race 제거).
  `main.dart`: `shouldStartMinimized = startMinimizedOnBoot && (hasAutostart || 부팅후경과<5분)`.
  `lib/utils/win32_uptime.dart`(GetTickCount64)로 부팅 직후 판별. 진단 패널에 uptime·likelyBoot 추가.

**자동실행 매니저**
- `.lnk`/문서/exe 실행을 `cmd /c start` → **ShellExecuteEx**(`lib/utils/win32_shell_execute.dart`)로 교체.
  바로가기를 셸이 해석해 실제 대상 실행, 창 상태(nShow) 반영, 콘솔 깜빡임 제거.
- **드래그 앤 드롭 등록**(`desktop_drop`), 다중 드롭 일괄 등록.
- 인수 따옴표 토크나이저(공백 경로), 프로그램 고유 ID(해시 충돌 제거), lastExecuted 1회 병합 저장.

**리팩토링/정리** (사용자 영향 없음)
- `main_screen.dart` 2,793→1,107줄, part 파일 3개 분리(dashboard/tabs/diagnostics).
- 볼륨 파형 `ValueNotifier`(녹음 중 전체 리빌드 제거), 죽은 코드 ~1,050줄 삭제.
- 경고색 투명 버그(`0xFFA000`→`0xFFFFA000`), ffmpeg 변환 5분 타임아웃, cron close await.
- B7(_InfoCallout 중복제거), A23(MicDiagnosticStatus.isProblem 추출).

## 3. ⏳ 다음 세션에서 할 일 (우선순위 순)

### (A) 먼저: 진료실 PC 실기기 검증 — 게이트
1.3.19 게시 후 Store 업데이트로 받아 **재부팅 1회**:
- [ ] **백그라운드 시작 ON → 재부팅 → 창이 안 뜨고 트레이만** (이번 핵심 수정 — 반드시 통과해야 함)
- [ ] 안 되면 진단 패널 "최근 부팅 결정 이력"의 **`uptime` 값** 확인.
      - uptime이 5분 넘게 찍혔으면(로그인 지연/StartupTask 지연) → `main.dart`의 `bootWindow`(현재 5분) 상향, 또는 "백그라운드 ON이면 항상 트레이" 방식으로 전환 검토.
- [ ] 자동실행: **바탕화면 바로가기(.lnk)를 드래그로 등록 → 테스트 실행 → 대상 프로그램 뜨는지**
- [ ] 부팅 시 등록 프로그램들이 10초 간격으로 실행되는지

### (B) 그 다음: 보류했던 리팩토링 — **1.3.20**에서 (기기 테스트 필수)
이번에 **일부러 안 한** 항목들. 부팅/트레이/창 생명주기를 건드려 `analyze`로는 거동 검증이 안 되고,
**실제 재부팅 테스트로만** 확인 가능하기 때문. 1.3.19가 기기에서 정상 확인된 뒤, 각 변경마다 빌드→재부팅 테스트를 붙여 진행할 것.
- **B5** (위험 낮음, 기계적): `gStartedInBackground` 전역 → `MainScreen` 생성자 주입. `const` 드롭 필요(analyze가 잡음).
- **B4** (주의): `main_screen.dart` `_bringToFront`의 500ms 폴링 루프(`_isHidingToTray`) → awaitable Future. 트레이 복원 타이밍 거동 변화 → 재부팅/트레이 클릭 테스트 필수.
- **B2** (가장 조심): `_MainScreenState`에서 `SessionDurationTracker`(가장 독립적, 여기부터) → `WindowLifecycleController`(WindowListener+트레이 hide/show/exit) → `TutorialController` 순차 추출. WindowLifecycleController가 핵심 위험 구간.
- (선택) A26: 죽은 `_StartupStatusBadge` + startup status-mismatch 경로 제거(`main_screen_tabs.dart`). 현재 무해(삼항 참조라 미사용 경고 없음). 제거 시 `_showStartupDiagnostics`/`StartupDiagnosticsDialog` 도달성 확인 필요.
- (선택) deprecation 3건: `DropdownButtonFormField(value:)`→`initialValue`, Radio `groupValue`/`onChanged`→`RadioGroup`. info-level, 거동 바뀔 수 있어 신중히.

### (C) 마무리
- [ ] 브랜치 `feat/v1.3.18-launch-boot-refactor` → **main 머지/푸시** (사용자 확인 후).

## 4. 빌드/검증 방법 (이 세션에서 확인된 핵심)

**WSL에서 cmd.exe interop으로 Windows flutter를 직접 구동 가능** (이전 "WSL 불가" 기록은 Linux 래퍼 기준).
```bash
# 1) WSL→Windows 동기화 (rsync -a --delete)
bash scripts/sync_wsl_to_windows.sh
# 2) pub get → analyze → build → msix (analyze는 info로 exit 1이 정상 — && 체인에 넣지 말 것)
cmd.exe /c "cd /d C:\ws-workspace\eyebottlelee && C:\flutter\bin\flutter.bat pub get && C:\flutter\bin\flutter.bat analyze"
cmd.exe /c "cd /d C:\ws-workspace\eyebottlelee && C:\flutter\bin\flutter.bat build windows --release && C:\flutter\bin\dart.bat run msix:create"
# 3) preflight
cmd.exe /c "cd /d C:\ws-workspace\eyebottlelee && powershell -NoProfile -ExecutionPolicy Bypass -File scripts\preflight\verify-msix.ps1"
```

**⚠️ 함정 (이번에 겪음):**
- `sync_wsl_to_windows.sh`는 `rsync -a --delete`라 **gitignore된 Windows 전용 파일(`assets/bin/ffmpeg.exe`)을 삭제**한다.
  → ffmpeg.exe를 WSL 리포 `assets/bin/`에 둬서 보존(현재 그렇게 해둠, `*.exe` gitignore라 커밋 안 됨).
  없으면 `build/flutter_assets/assets/bin/ffmpeg.exe`에서 복원.
- 동기화가 Windows `pubspec.lock`을 WSL 것으로 덮으므로 sync 후 `flutter pub get` 재실행 필요(현재 WSL lock엔 desktop_drop 반영됨).
- cmd.exe interop은 반드시 `cd /d C:\경로`로 Windows 경로에서 실행(WSL UNC 경로면 실패). `>nul` 리다이렉트 넣지 말 것(실패 사례 있음).

## 5. 커밋 (브랜치 7개)
```
6277ac8 chore: 버전 1.3.19.0 상향 (Store revision=0 정책)
08f1298 refactor: 진단 isProblem(A23) + 콜아웃 위젯화(B7)
68b7db3 fix: 빌드 차단 요소 해소 + pubspec.lock (analyze/build 통과)
ac31320 docs: 브라우저 조작 Claude 제출 프롬프트
f4f0008 refactor: 볼륨 ValueNotifier (B1/A24)
9736ec3 refactor: main_screen.dart part 분할 (2793→1107)
ab08b53 feat: v1.3.18 자동실행 강화 + 부팅 근본 수정 + 코드 정리
```
