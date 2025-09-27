# Developing Guide (아이보틀 진료 녹음)

문서 목적: 이 저장소를 처음 받는 개발자가 현재까지의 구현 상태를 빠르게 파악하고, 동일한 방향으로 다음 작업을 이어갈 수 있도록 돕습니다.

- 대상: Windows 데스크톱용 Flutter 앱 개발(WSL 파일시스템 + Windows 툴체인)
- 마지막 갱신: 2025-09-25
- 참고: [제품 요구사항 PRD](medical-recording-prd.md)

---

## 1) 개요
- 제품: 아이보틀 진료 녹음(Eyebottle Medical Recorder)
- 목표: 진료 시간표 기반 자동 녹음, 10분 분할 저장, OneDrive 폴더 동기화, 무음(VAD) 스킵으로 용량 절감
- 스택: Flutter 3.24+ / Dart 3+, Windows Desktop, 주요 패키지 `record`, `path_provider`, `shared_preferences`, `cron`, `system_tray`, `window_manager`, `launch_at_startup`, `file_selector`

---

## 2) 현재까지 반영 사항
핵심 구현 요약(시험 구현 기준, MVP 지향):

- 녹음/분할/레벨
  - `record` 패키지로 AAC-LC 64/48/32kbps 모노 프로필 지원(기본 64kbps), 32kHz 이하 샘플레이트를 사용해 용량 최적화
  - 조용한 환경 보정을 위해 +0~+12dB 메이크업 게인을 선택적으로 적용(RecordConfig.autoGain 활성화 + UI 슬라이더)
  - 10분 단위 자동 분할(`Timer.periodic`)
  - UI로 입력 레벨 시각화(200ms 주기)
- 메인 화면의 "오늘 녹음" 카드는 세션 누적 시간을 실시간으로 집계해 표시
- VAD(무음 자동 스킵)
  - 임계값 기본 `0.006`(정규화 레벨)
  - 4초 무음 지속 시 `pause()`, 음성 감지 후 500ms 뒤 `resume()`
  - 고급 설정에서 활성화/임계값 조정 가능
- 스케줄링/설정
  - 주간 진료 시간표 저장/로드(`SharedPreferences`)
  - 앱 시작 시 저장된 스케줄 적용(없으면 기본값) 및 현재 시간이 진료 시간대라면 자동으로 녹음/중지 상태 동기화
  - 요일별로 `종일` 또는 `오전/오후` 분할 근무를 선택할 수 있으며, 기본 오전/오후 시간은 09:00~13:00 / 14:00~18:00으로 제공
  - 저장 폴더 지정: `file_selector`로 폴더 선택(OneDrive 폴더 권장)
- 파일 보관/정리
  - 기본값은 영구 보존이며, 고급 설정에서 1주·1개월·3개월·6개월·1년 옵션을 선택하면 해당 기간 경과 후 앱이 자동 삭제
  - 저장 루트 하위에 `YYYY-MM-DD` 폴더를 자동 생성해 날짜별로 세그먼트를 정리하며, 빈 날짜 폴더는 보관 주기 정리 시 자동 삭제
- 트레이 연동(가드 적용)
  - 트레이 초기화 및 상태 아이콘 업데이트(아이콘 미존재 시 무시)
  - 로깅 서비스 에러 이벤트를 받아 트레이 아이콘을 오류 상태로 전환하고 사용자에게 알림
  - 창 닫기/Alt+F4 시 앱은 종료되지 않고 트레이로 숨겨지며, 녹음 상태는 유지됨
  - 트레이 메뉴의 "종료" 선택 시에만 완전 종료되며, 종료 직전에 녹음 세션을 안전하게 중단
  - 트레이 아이콘 좌/더블 클릭 시 메인 창 복원, 우클릭 시 컨텍스트 메뉴가 열린다
  - 트레이 메뉴에서 녹음 시작·중지 토글, 마이크 점검, 설정 열기, 종료를 직접 실행할 수 있다
  - 트레이 메뉴는 도움말 다이얼로그도 호출 가능하며, 튜토리얼을 재생할 수 있다
- 자동 마이크 점검
  - 앱이 켜질 때 3초간 샘플을 녹음해 권한/장치/입력 레벨을 확인하고, 결과를 대시보드 카드에 표시
  - RMS 대신 평균 dBFS·SNR을 계산해 조용한 환경에서도 정상/주의 판정을 세분화
  - `SharedPreferences`에 마지막 검사 결과와 안내 문구를 저장해 재시작 후에도 상태를 바로 보여줌
  - 대시보드에서 "다시 점검" 버튼으로 수동 진단 가능하며, 녹음 중에는 점검을 제한해 충돌을 방지
- UI/설정 다이얼로그
  - 메인 화면은 `대시보드 / 설정` 탭 구조로 개편되어 상단 헤더, 실시간 볼륨 막대, 오늘/예정 녹음 요약을 한 화면에서 확인
  - “진료 시간표 설정” 다이얼로그 저장 → 스케줄 즉시 재적용
  - “고급 설정” 다이얼로그(녹음 품질·메이크업 게인, VAD 토글/임계값, Windows 자동 시작, 녹음 파일 보관 기간)
  - 대시보드 하단 카드에서 현재 저장 경로 및 자동 정리 정책 안내

### 2025-09-25 주요 업데이트
### 2025-09-27 진료실 배포 테스트 진행 중
- 현장 테스트에서 발견된 문제:
  - 녹음 품질·민감도 설정을 변경해도 UI와 실제 동작이 기본값으로 되돌아가는 현상. 저장 시 상태 업데이트 논리 점검 필요.
    - TODO: `AdvancedSettingsDialog._save`에서 `SettingsService.setRecordingProfile` / `setMakeupGainDb` 호출 및 대시보드 카드 상태 동기화 확인.
  - 마이크 점검 카드가 실제 정상 음성에도 "입력이 약함"으로 표시되어 진단 임계값/게인 설명이 과도하게 엄격함. dBFS/SNR 계산 및 안내 문구 조정 필요.
- `docs/clinic-deployment-guide.md` 를 기준으로 MSIX·폴더 복사 두 가지 배포 경로를 정리했고, 실제 진료실 PC에서 Phase 1 테스트를 시작했습니다.
- 현재 Phase 1 항목 중 앱 기동/SmartScreen 우회는 완료했으며, 마이크 연결 환경이 준비되는 즉시 진단·수동 녹음 항목을 검증할 예정입니다.
- 테스트 도중 발견되는 수정점은 `docs/clinic-deployment-guide.md`에 즉시 반영하고 있으므로, 후속 개발자는 최신 절차를 참고해 추가 이슈를 기록해 주세요.
- 8시간 Soak 테스트는 Claude 에이전트가 `scripts/windows/run-soak-test.ps1`로 완료했고, 로그는 `C\ws-workspace\eyebottlelee\soak-logs` 아래 공유되었습니다. 현재는 MSIX 릴리즈 빌드를 기준으로 실사용 테스트(Phase 1~2) 검증을 진행 중입니다.

- 대시보드 마이크 진단 카드를 헤더·요약·힌트·버튼 구조로 컴팩트하게 재구성하고, 상태 아이콘/색상/기본 가이드를 통일된 헬퍼로 관리(`refactor: compact mic diagnostic card`).
- 설정 탭의 "고급 설정" 항목 옆에 VAD, 자동 실행 상태를 즉시 확인할 수 있는 ON/OFF 배지를 추가(`feat: show toggle states in settings`).
- 앱 초기/최소 창 크기를 660×980 / 640×900으로 확장해 기본 레이아웃을 여유 있게 확인할 수 있도록 조정(`chore: increase default window size`).
- 녹음 일시정지/재개 버튼을 제거해 녹음 흐름을 `시작 ↔ 중지` 두 단계로 단순화(`chore: remove pause recording feature`).
- 저장 기간 항목에 현재 선택한 보관 기간(영구/1주일/1개월 등)을 배지로 노출하고, 다이얼로그 저장 후 즉시 갱신하도록 개선(`feat: show retention duration badge`).

### 2025-09-26 주요 업데이트
- 도움말 다이얼로그 추가: 대시보드/설정 튜토리얼 분리, 트레이 메뉴와 헤더에서 호출 가능(`feat: add in-app help dialog and tutorial`).
- 설정 탭 튜토리얼: 시간표·저장 위치·녹음 품질·보관 기간·VAD·자동 실행 항목을 쇼케이스로 안내(`feat: add settings tab tutorial walkthrough`).
- 녹음 상태 카드의 헤더와 볼륨 미터를 컴팩트하게 조정해 화면 밀도를 개선(`ui: compact recording card and meter layout`).
- 마이크 진단 임계값을 낮춰 조용한 진료실에서도 "정상" 판정이 쉽게 나오도록 조정(OK=0.04, Caution=0.018) (`tweak: lower mic diagnostic sensitivity thresholds`).
- 기본 진료 시간표 오전/오후 구간을 09:00~13:00 / 14:00~18:00으로 수정(`chore: update default clinic schedule hours`).

### 2025-09-24 주요 업데이트
- 메인 화면을 `대시보드 / 설정` 탭 구조로 재구성하고, 녹음 상태 카드·애니메이션 볼륨 미터·저장 경로 안내 카드를 새 디자인으로 통일(`feat: refresh dashboard layout and window sizing`).
- 스케줄 설정 다이얼로그를 카드형 UI로 전면 수정하고 SegmentedButton·Switch 기반 컨트롤을 도입해 일관된 사용자 경험 제공(`feat: redesign schedule configuration dialog`).
- 고급 설정을 녹음 품질·메이크업 게인 / VAD / 보관 기간 / 자동 실행 네 가지 다이얼로그로 분리하고, 권장 프리셋과 설명을 추가해 사용성을 개선(`feat: split advanced settings into dedicated dialogs`, `feat: add VAD presets and guidance`).
- 창 초기 크기·최소 크기 로직을 개선해 DPI 환경에서도 650×840 레이아웃이 안정적으로 적용되도록 조정(`feat: refresh dashboard layout and window sizing`).
- 날짜별 저장 디렉터리 및 자동 보관 정책을 강화하고, 문서에 최신 정책을 반영.

최근 확인 사항 (2025-09-23)
- Windows 워킹카피(`C:\ws-workspace\eyebottlelee`)에서 `flutter pub get`, `flutter analyze` 수행해 무경고 상태임.
- `AudioService.getTodayRecordingDirectory()`가 날짜별 하위 폴더(`YYYY-MM-DD`)를 생성하며, 기본 저장 위치 카드도 새 경로를 즉시 반영함.
- 고급 설정에서 보관 기간을 `삭제 없음`(기본값) 포함 5개 구간 중 선택할 수 있으며, 선택 시 `AudioService.configureRetention`을 통해 즉시 적용됨.

변경 파일(주요)
- 추가: `lib/services/settings_service.dart`, `lib/ui/widgets/advanced_settings_dialog.dart`, `docs/developing.md`
- 수정: `lib/services/audio_service.dart`, `lib/ui/screens/main_screen.dart`, `lib/ui/widgets/schedule_config_widget.dart`, `pubspec.yaml`(의존성 `file_selector` 추가)

---

## 3) 실행 방법(Windows)
사전 준비(Windows 측)
- Flutter SDK 설치, 채널 stable, `flutter doctor` 통과
- Visual Studio 2022: “Desktop development with C++” 워크로드
- `flutter config --enable-windows-desktop`

코드 위치/열기
- 코드: WSL 경로(예: `/home/<user>/projects/eyebottlelee`)
- Android Studio(Windows)에서 `\\wsl$\<배포판>\home\<user>\projects\eyebottlelee`를 열어 개발/미리보기

명령어
```
flutter pub get
# (선택) 플레이스홀더 아이콘 생성: Windows PowerShell에서 실행
# scripts/windows/generate-placeholder-icons.ps1
flutter run -d windows
```

패키징(MSIX)
```
flutter build windows --release
dart run msix:create
```

---

## 4) 코드 구조(관계도)
```
lib/
├─ main.dart                                 # 앱 엔트리/윈도우 초기화
├─ services/
│  ├─ audio_service.dart                     # 녹음/분할/VAD/보관정리
│  ├─ schedule_service.dart                  # 주간 스케줄 → cron 작업 등록
│  ├─ settings_service.dart                  # SharedPreferences 저장/로드
│  ├─ tray_service.dart                      # 시스템 트레이 연동(가드)
│  └─ logging_service.dart                   # logger 기반 파일 로깅/에러 알림
├─ models/
│  └─ schedule_model.dart                    # WeeklySchedule/DaySchedule
└─ ui/
   ├─ screens/main_screen.dart               # 메인 화면: 상태/버튼/설정 진입
   └─ widgets/
      ├─ recording_status_widget.dart
      ├─ volume_meter_widget.dart
      ├─ schedule_config_widget.dart         # 시간표 편집/저장
      └─ advanced_settings_dialog.dart       # VAD/자동 시작 설정
```

주요 동작 파라미터
- 녹음: AAC-LC 64kbps, mono, 16kHz, 10분 분할
- VAD: 임계값 0.01, 무음 3초 시 pause, 재개 지연 500ms
- 보관: 7일 초과 파일 삭제

---

## 5) 아이콘/트레이 리소스
- 공식 로고: `assets/logos/eyebottle-logo.png` (512×512) → 모든 ICO 생성의 소스
- 아이콘 생성 스크립트(PowerShell): `scripts/windows/generate-placeholder-icons.ps1`
  - ImageMagick(`magick`)이 설치되어 있으면 로고 기반 멀티 해상도 ICO를 생성합니다.
  - 미설치 시 텍스트 플레이스홀더를 생성하고 경고를 출력합니다.
- 결과물: `assets/icons/icon.ico`, `tray_recording.ico`, `tray_waiting.ico`, `tray_error.ico`
  - 트레이 아이콘은 로고 + 상태 배지(빨강/초록/노랑 16px)를 포함합니다.

`pubspec.yaml`에 `assets/icons/`가 이미 포함되어 있으므로 스크립트를 실행해 파일을 생성하면 바로 앱과 패키징에 반영됩니다.

---

## 6) 단계별 향후 개발 계획 (업데이트: 2025-09-16)

### Phase 0. 안정화 (2025-09-16 ~ 09-27)
- [x] **녹음 세션 집계** — "오늘 녹음" 카드에 실제 누적 시간을 표시. 녹음 시작/중지 시 세션 로그를 유지하고 자정 기준으로 리셋. (SharedPreferences에 일자별 초 단위 누적, 실시간 타이머 표시) 관련: `AudioService`, `MainScreen`.
- [x] **로그 인프라** — `LoggingService`로 `logger` 파일 로테이션 구성, 세그먼트/오류 이벤트 기록 및 실패 시 SnackBar 알림. 관련: `lib/services/audio_service.dart`, `lib/services/logging_service.dart`.
- [ ] **8시간 Soak 테스트 스크립트** — Windows PowerShell 또는 Dart 스크립트로 장시간 녹음 안정성 검증, 로그 분석 체크리스트 포함. 완료 조건: 8시간 연속 녹음 중 세그먼트 누락 0건.

### Phase 1. 사용자 경험 향상 (2025-09-30 ~ 10-11)
- [ ] **Windows Toast 알림** — 진료 시작 5분 전/종료 시각에 알림 노출. `system_tray` 또는 Windows API 연계 검토. UI 문구/끄기 옵션 포함.
- [ ] **오류 가시화** — 마이크 미검출, 녹음 실패, 디스크 부족 시 다이얼로그/Toast 안내. AudioService 예외 메시지 표준화.
- [x] **트레이 아이콘 리소스** — `assets/icons/`에 실제 아이콘(.ico) 포함 및 생성 스크립트 결과 버전관리. 아이콘 미존재 시 fallback 처리.
- [x] **인앱 도움말 & 튜토리얼** — 도움말 다이얼로그와 대시보드/설정 쇼케이스 추가로 초보자 온보딩 강화.

### Phase 2. 스케줄/워크플로 확장 (2025-10-14 ~ 10-25)
- [ ] **휴진일·예외 스케줄** — 달력 UI에서 단일 날짜 비활성화/시간 덮어쓰기 저장. SharedPreferences 스키마 확장 및 ScheduleService 적용 로직 보완.
- [ ] **다중 시간 구간 지원** — 오전/오후 등 복수 구간 입력 허용. UI/모델(WeekdaySlot) 재설계, Cron 등록 로직 업데이트.
- [ ] **글로벌 마킹 단축키** — Ctrl+M 입력 시 현재 세그먼트에 타임스탬프 메타 저장(Windows API 제약 확인). 마킹 결과를 별도 JSON/CSV로 기록.

### Phase 3. 동기화·배포 체계 (2025-10-28 ~ 11-15)
- [ ] **OneDrive 동기 상태 감지** — 선택한 폴더에 대해 파일 시스템 이벤트 감시, 동기 지연 시 경고 출력. 옵션: `windows` 플러그인 또는 PowerShell 연동.
- [ ] **자동 시작 안정화** — MSIX 패키징 시 고정 경로 기반으로 `launch_at_startup` 재검증. 개발 환경 경고 문구 문서화.
- [ ] **CI/CD 및 배포** — GitHub Actions로 Windows 빌드/테스트/아티팩트 업로드, MSIX 생성 자동화. 후속으로 코드 서명 및 winget 채널 검토.

---

## 7) 개발 중 체크리스트
- [ ] `flutter doctor` 통과(Windows 컴파일러 포함)
- [ ] `flutter run -d windows` 로컬 실행 OK
- [ ] 폴더 선택으로 OneDrive 경로 지정(예: `C:\\Users\\<user>\\OneDrive\\진료녹음`)
- [ ] 트레이 아이콘 생성 및 표시 확인
- [ ] 창 닫기 → 트레이로 숨김 → 트레이에서 복원/종료 플로우 확인
- [ ] 트레이 메뉴에서 녹음 시작/중지, 마이크 점검, 설정 열기 동작 확인
- [ ] 30~60분 시범 녹음 → 세그먼트/보관정리 동작 확인
- [ ] 사용자 안내 문서(`docs/user-guide.md`) 업데이트 및 README 링크 반영 확인

---

## 8) 알려진 제약/주의
- Windows 권한/장치: `record.hasPermission()` 동작이 플랫폼별 상이할 수 있어 UI 레벨미터로 사전 확인
- 트레이 리소스: 아이콘 없으면 초기화 실패(앱 기능엔 영향 없음) → 아이콘 생성 권장
- 자동 시작: 개발 경로/권한으로 실패할 수 있으므로 로그 확인 필요하며, 앱 기동 시 설정 값과 동기화를 시도함. 배포 후 고정 경로에서 재검증 필요
- VAD: 단순 RMS 기반(잡음 환경 오검지 가능) → 임계값 튜닝 필요

---

## 9) 빠른 실행/검증 명령
```
flutter pub get
flutter run -d windows
# (선택) 공식 로고 기반 아이콘 생성 (ImageMagick 필요)
# pwsh -File scripts/windows/generate-placeholder-icons.ps1
# (선택) MSIX
# flutter build windows --release && dart run msix:create
```

---


## 10) 이어서 작업하기(가이드)
- 작은 단위로 변경 → 실행/확인 → 문서/체크리스트 갱신
- 새 기능 추가 시: UI(설정/토글) → 서비스(로직) → 저장(SharedPreferences) 순으로 연결
- 파괴적 변경(파일 삭제 정책/경로 변경 등)은 반드시 문서에 근거 및 롤백 전략 기재

참고: 루트의 `AGENTS.md`는 에이전트/자동화 도구 작업 지침을 정의합니다. 변경 시 함께 갱신하세요.

## 11) 실사용 테스트 앱 준비 체크리스트
- [ ] Windows에서 `pwsh -File scripts\windows\run-soak-test.ps1` 로 8시간 Soak 테스트를 수행하고, 필요하면 `-DurationHours` 옵션으로 시간을 조절합니다. 로그와 metrics는 `C:\ws-workspace\eyebottlelee\soak-logs\<timestamp>` 아래에 저장됩니다.
- [ ] Soak 테스트 결과를 요약한 `session-notes.txt`와 `metrics.csv`를 확인해 메모리 사용량·CPU 누적 시간을 검토하고, 진료실 PC에서도 동일 스크립트를 재실행해 하드웨어 차이를 비교합니다.
- [ ] `flutter build windows --release` 완료 후 `build\windows\x64\runner\Release` 폴더를 ZIP으로 묶어 테스트앱 패키지를 만든 뒤, 진료실 PC에 전달합니다.
- [ ] 패키지에는 실행 파일 외에 최신 사용자 가이드(`docs/user-guide.md`)의 테스트 절차 요약본과 복구 안내, Soak 테스트 로그 묶음을 포함해 현장에서도 바로 검수할 수 있도록 합니다.
- [ ] 테스트 중 발견한 이슈는 Phase 1~3 일정(알림, 오류 가시화, 동기화 안정화)과 연결해 티켓을 작성하고, 해결 여부를 회고 로그에 남깁니다.


