# HANDOFF — v1.3.17 제출 완료 + 진료실 PC 검증 대기

작성일: 2026-05-29
세션 ID(직전): e28d9fbb-89de-4b85-b3ab-209b58a179c2
대상: 다음 Claude Code 세션 (특히 진료실 PC가 여전히 백그라운드 시작이 안 될 때)

---

## ⏱ 30초 요약 (TL;DR)

- **v1.3.17 빌드·2-pass 검증·MS Store 제출 완료.** Submission 17 = "Update in certification"(인증 진행 중), 통과 시 자동 게시. v1.3.16은 게시 전까지 라이브 유지.
- **무엇을 고쳤나:** 부팅 자동시작 시 "백그라운드(창 안 뜨고 트레이만) 시작"이 깨지던 문제. (1) main.cpp가 `--autostart`일 때 native `Show()` 생략(Show→hide race 제거), (2) main.dart 부팅 조건을 `hasAutostart && startMinimizedOnBoot` 이중 AND로 단순화(MSIX에서 깨지던 `launchAtStartup` 중복 체크 제거), (3) 로그 디렉터리 4단계 fallback, (4) 앱 내 진단 패널 신설.
- **사용자 핵심 관측(매우 중요):** 신규 설치 PC = 백그라운드 정상 / **기존(업그레이드된) 진료실 PC = 백그라운드 실패, 업데이트해도 지속.** → 코드가 아니라 **보존된 MSIX 프로필의 stale 설정값** 문제를 강하게 시사.
- **진료실 PC가 v1.3.17로 고쳐질 확률: 약 60~65%** (5-에이전트 독립 추정 [45,62,66,68,70], 평균 62/중앙 66). **악화 위험 0**(만장일치). 진단 패널 한 줄로 확정 판정 가능.
- **다음 세션 첫 행동:** 사용자에게 진료실 PC **진단 패널 > "최근 부팅 결정 이력" 첫 줄**의 `hasAutostart` / `startMinimizedOnBoot` / `shouldStartMinimized` 값을 받아 아래 § "판정 & 플레이북"대로 분기.

---

## 1. 현재 상태

- Git: `main`, HEAD `7ca00d8`. origin 대비 **ahead**(푸시 여부는 직전 세션 마지막 참조).
- 버전: `pubspec.yaml` `1.3.17+28`, `msix_version 1.3.17.0`, `startup_task.enabled: true`(사용자 결정 — 신규 설치도 자동시작 기본 ON).
- 빌드 산출물: `C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix` (2026-05-29 빌드, 매니페스트 `StartupTask Enabled="true"` + `--autostart` 확인).
- MS Store: Submission 17 인증 중.

### 커밋 (이번 세션)
| 커밋 | 내용 |
|------|------|
| `953ae40` | feat: 부팅 race 제거 + 진단/검증 파이프라인 (핵심) |
| `4aa8a28` | fix: 빌드 차단 요소 해소 (app_icon.ico RC2176 / .gitattributes 바이너리 보호 / verify-msix git 가드) |
| `59d2757` | chore: StartupTask 기본 ON 유지 (사용자 결정) |
| `7ca00d8` | docs: 브라우저 조작 Claude용 제출 프롬프트 |

---

## 2. 근본 원인 분석 (경합 시나리오 X / Y / Z)

진료실 PC가 v1.3.16에서 실패한 이유의 경합 가설:

- **시나리오 X (가장 유력, ~60%): 보존된 `launch_at_startup` SharedPreferences = stale-false.**
  v1.3.16 부팅 판정은 삼중 AND `hasAutostart && launchAtStartup && startMinimizedOnBoot`. 진료실 PC는 옛 버전 시절 자동시작을 켰지만 이 키가 true로 안 박힌 채 보존됨(MSIX 앱 데이터는 업데이트 간 보존). → AND가 깨져 창이 뜸. **v1.3.17이 이 항을 제거 → 고쳐짐.**
- **시나리오 Y (~20%): 부팅 시 `--autostart`를 실제로 못 받음.** 레거시 시작폴더 `.lnk`/StartupApproved 레지스트리가 인자 없이 띄우거나 StartupTask 상태 이상 → `hasAutostart=false` → v1.3.17도 못 고침. (단 레거시 .lnk 타깃은 버전별 WindowsApps 경로라 업데이트 후 죽은 링크일 공산이 커 무해할 가능성이 높음.)
- **시나리오 Z (~18%): `start_minimized_on_boot`마저 MSIX에서 stale-false로 읽힘.** X와 같은 SharedPreferences 신뢰성 문제가 이 키에도 적용되면 → `shouldStartMinimized=false` → v1.3.17도 못 고침.

검증: 부팅 로직 자체는 결함 0(window_manager 0.5.1 소스로 `waitUntilReadyToShow` 콜백이 native Show 없이도 발동함 확인). v1.3.17은 회귀 위험 없음(최악=무변화).

---

## 3. 판정 & 플레이북 (다음 세션 핵심)

게시 후 진료실 PC: **업데이트 → 재부팅 → 설정 > 진단 패널 > "최근 부팅 결정 이력" 첫 줄** 확인.

| 진단 패널 값 | 시나리오 | 조치 |
|---|---|---|
| `hasAutostart=true, startMinimizedOnBoot=true, shouldStartMinimized=true` + 트레이로 시작됨 | X (고쳐짐) | **끝.** 추가 작업 불필요 ✅ |
| `hasAutostart=true, startMinimizedOnBoot=false` | Z | start_minimized 저장값이 stale → 아래 Z 플레이북 |
| `hasAutostart=false` | Y | --autostart 미전달 → 아래 Y 플레이북 |

### 먼저 시도 (코드 0, 빌드 0) — Z·Y 상당 부분 자가 치유
1. 진료실 PC에서 설정 토글을 **OFF→ON 재설정**: "자동 실행" OFF→ON + "백그라운드 시작" OFF→ON.
   - 내부적으로 `setStartMinimizedOnBoot(true)` 재기록(Z 치유) + `AutoLaunchService.enable()`로 StartupTask 재등록 & `launch_at_startup=true` 재기록.
2. 레거시 시작폴더 .lnk 수동 삭제(사용자 권한 = MSIX 가상화 영향 없음):
   ```powershell
   Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Eyebottle Medical Recorder.lnk" -Force -ErrorAction SilentlyContinue
   ```
3. 재부팅 후 다시 진단 패널 확인.

### 시나리오 Z 코드 수정 (필요 시 v1.3.18)
부팅 결정에 쓰는 설정(`start_minimized_on_boot`)을 SharedPreferences 단독 의존에서 벗어나 **견고한 경로에 평문 파일로 미러링**(이미 구현된 로깅 4단계 fallback과 동일 발상). 부팅 시 SharedPref가 default를 반환하면 미러 파일을 읽어 보정.
- 대상: `lib/services/settings_service.dart` (setStartMinimizedOnBoot에서 미러 파일 동시 기록), `lib/main.dart` (부팅 시 미러 fallback 읽기).

### 시나리오 Y 코드 수정 (필요 시 v1.3.18)
레거시 시작폴더 `.lnk` + `HKCU\...\Explorer\StartupApproved\Run`의 "Eyebottle Medical Recorder" 값 청소.
- ⚠️ MSIX는 앱의 레지스트리/파일 쓰기를 **가상화**하므로 Dart/앱 코드로는 실제 경로를 못 지울 수 있음 → **native C++(runFullTrust)로 실제 경로 직접 조작** 권장(`windows/runner/`), 또는 사용자 1회 수동 청소(위 one-liner + 레지스트리).
- 레거시 등록 경로 근거: `launch_at_startup 0.5.1` (Windows pub cache: `app_auto_launcher_impl_windows.dart` — `_shortcutFile` = `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\<appName>.lnk`, appName='Eyebottle Medical Recorder'; + StartupApproved\Run 바이너리 값).

---

## 4. 빌드/제출 절차 + 함정 (재현용)

WSL에서는 `flutter analyze/build` 불가(Windows SDK). 빌드는 Windows 측. 검증된 절차:
1. **소스 동기화** (WSL→Windows, 별도 비-git 복사본):
   ```
   rsync -rc --no-times --exclude='.git/' --exclude='build/' --exclude='.dart_tool/' \
     --exclude='.idea/' --exclude='.omc/' --exclude='.claude/' --exclude='windows/flutter/ephemeral/' \
     /home/usereyebottle/projects/eyebottlelee/ /mnt/c/ws-workspace/eyebottlelee/
   ```
2. **빌드** (flutterw는 백그라운드 셸에서 UNC 경로로 실패 → cmd.exe 직접 pushd 사용):
   ```
   /mnt/c/Windows/System32/cmd.exe /c "pushd C:\ws-workspace\eyebottlelee && flutter clean && flutter build windows --release && flutter pub run msix:create"
   ```
3. **제출 전 점검**: `scripts\preflight\verify-msix.ps1` (버전/StartupTask/capability/ffmpeg).

### 알려진 함정
- **app_icon.ico RC2176 'old DIB'**: 256x256 무압축 DIB → rc.exe 거부. Pillow로 전 프레임 PNG 재생성 완료(commit 4aa8a28). 재발 시 동일 처리.
- **.gitattributes 바이너리 손상**: `windows/** text eol=crlf`가 .ico를 텍스트로 변환해 커밋 blob 손상시킴 → `*.ico binary` 등 규칙 추가 완료. 바이너리 커밋 후 `git show HEAD:파일|md5sum` vs 작업본 일치 검증.
- **LNK1104 (medical_recorder.exe 열 수 없음)**: 실행 중 인스턴스 잠금 → `cmd.exe /c "taskkill /F /IM medical_recorder.exe /T"` 후 재빌드.
- Windows Flutter = 3.35.3. Pillow는 `pip install pillow`로 설치됨(네트워크 가능).

---

## 5. 참고 자료
- 제출 프롬프트: `docs/MS-STORE-SUBMISSION-v1.3.17-BROWSER-CLAUDE-PROMPT.md`(브라우저 Claude용), `docs/MS-STORE-SUBMISSION-v1.3.17-COMET-PROMPT.md`(코멧).
- 테스트 매트릭스: `docs/STARTUP-TEST-MATRIX.md` (시나리오 3 = 핵심).
- 원래(입력) 핸드오프: `docs/HANDOFF-v1.3.17-BACKGROUND-FIX.md` (이번 작업의 출발점, 이제 대부분 완료됨).
- 사이드로딩 도구: `scripts/sideload/` (실기 테스트를 Store 없이 하려면).

### 핵심 파일
| 파일 | 역할 |
|------|------|
| `windows/runner/main.cpp` | --autostart 시 native Show() 생략 |
| `lib/main.dart` | 부팅 판정(이중 AND) + boot_decision 기록 |
| `lib/services/settings_service.dart` | boot_decision_history, start_minimized_on_boot |
| `lib/services/logging_service.dart` | 로그 4단계 fallback |
| `lib/ui/widgets/startup_diagnostics_section.dart` | 진단 패널 (판정 도구) |
| `lib/services/auto_launch_service.dart` | StartupTask enable/disable + SharedPref 동기화 |

---

**마무리.** v1.3.17은 제출까지 완료됐고, 진료실 PC 결과는 게시 후 진단 패널 한 줄로 판정. 안 고쳐졌으면 § 3 플레이북(특히 코드 0 토글 재설정부터)으로 진행. 새 세션은 사용자에게 그 한 줄을 먼저 요청할 것.
