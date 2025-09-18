# Developing Guide (아이보틀 진료 녹음)

문서 목적: 이 저장소를 처음 받는 개발자가 현재까지의 구현 상태를 빠르게 파악하고, 동일한 방향으로 다음 작업을 이어갈 수 있도록 돕습니다.

- 대상: Windows 데스크톱용 Flutter 앱 개발(WSL 파일시스템 + Windows 툴체인)
- 마지막 갱신: 2025-09-16
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
  - `record` 패키지로 AAC-LC 64kbps, mono, 16kHz 녹음
  - 10분 단위 자동 분할(`Timer.periodic`)
  - UI로 입력 레벨 시각화(200ms 주기)
  - 메인 화면의 "오늘 녹음" 카드는 UI 플레이스홀더(집계 로직 미구현)
- VAD(무음 자동 스킵)
  - 임계값 기본 `0.01`(정규화 레벨)
  - 3초 무음 지속 시 `pause()`, 음성 감지 후 500ms 뒤 `resume()`
  - 고급 설정에서 활성화/임계값 조정 가능
- 스케줄링/설정
  - 주간 진료 시간표 저장/로드(`SharedPreferences`)
  - 앱 시작 시 저장된 스케줄 적용(없으면 기본값)
  - 저장 폴더 지정: `file_selector`로 폴더 선택(OneDrive 폴더 권장)
- 파일 보관/정리
  - 기본 보관 7일: `.m4a` 수정시각 기준으로 자동 삭제
- 트레이 연동(가드 적용)
  - 트레이 초기화 및 상태 아이콘 업데이트(아이콘 미존재 시 무시)
- UI/설정 다이얼로그
  - “진료 시간표 설정” 다이얼로그 저장 → 스케줄 즉시 재적용
  - “고급 설정” 다이얼로그(VAD 토글/임계값, Windows 자동 시작 토글)

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
- 현재 `assets/icons/`에 아이콘 미포함 → 트레이 초기화가 조용히 실패할 수 있음(앱 동작엔 영향 없음)
- 임시 아이콘 생성(Windows PowerShell):
  - `scripts/windows/generate-placeholder-icons.ps1`
  - 생성 대상: `icon.ico`, `tray_recording.ico`, `tray_waiting.ico`, `tray_error.ico`

`pubspec.yaml`에 `assets/icons/`가 이미 포함되어 있으므로 파일만 존재하면 사용됩니다.

---

## 6) 단계별 향후 개발 계획 (업데이트: 2025-09-16)

### Phase 0. 안정화 (2025-09-16 ~ 09-27)
- [x] **녹음 세션 집계** — "오늘 녹음" 카드에 실제 누적 시간을 표시. 녹음 시작/중지 시 세션 로그를 유지하고 자정 기준으로 리셋. (SharedPreferences에 일자별 초 단위 누적, 실시간 타이머 표시) 관련: `AudioService`, `MainScreen`.
- [x] **로그 인프라** — `LoggingService`로 `logger` 파일 로테이션 구성, 세그먼트/오류 이벤트 기록 및 실패 시 SnackBar 알림. 관련: `lib/services/audio_service.dart`, `lib/services/logging_service.dart`.
- [ ] **8시간 Soak 테스트 스크립트** — Windows PowerShell 또는 Dart 스크립트로 장시간 녹음 안정성 검증, 로그 분석 체크리스트 포함. 완료 조건: 8시간 연속 녹음 중 세그먼트 누락 0건.

### Phase 1. 사용자 경험 향상 (2025-09-30 ~ 10-11)
- [ ] **Windows Toast 알림** — 진료 시작 5분 전/종료 시각에 알림 노출. `system_tray` 또는 Windows API 연계 검토. UI 문구/끄기 옵션 포함.
- [ ] **오류 가시화** — 마이크 미검출, 녹음 실패, 디스크 부족 시 다이얼로그/Toast 안내. AudioService 예외 메시지 표준화.
- [ ] **트레이 아이콘 리소스** — `assets/icons/`에 실제 아이콘(.ico) 포함 및 생성 스크립트 결과 버전관리. 아이콘 미존재 시 fallback 처리.

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
- [ ] 30~60분 시범 녹음 → 세그먼트/보관정리 동작 확인

---

## 8) 알려진 제약/주의
- Windows 권한/장치: `record.hasPermission()` 동작이 플랫폼별 상이할 수 있어 UI 레벨미터로 사전 확인
- 트레이 리소스: 아이콘 없으면 초기화 실패(앱 기능엔 영향 없음) → 아이콘 생성 권장
- 자동 시작: 개발 경로/권한으로 실패 가능, 배포 후 고정 경로에서 재검증 필요
- VAD: 단순 RMS 기반(잡음 환경 오검지 가능) → 임계값 튜닝 필요

---

## 9) 빠른 실행/검증 명령
```
flutter pub get
flutter run -d windows
# (선택) 트레이 아이콘 생성
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
