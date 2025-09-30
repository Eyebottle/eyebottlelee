# 아이보틀 진료녹음 & 자동실행 매니저 (Eyebottle Medical Recorder)

진료 중 환자와의 대화를 자동으로 녹음하고, 진료실 프로그램을 자동으로 실행하여 체계적으로 관리하는 Windows 데스크톱 애플리케이션입니다.

## 🚀 주요 기능

### 녹음 기능
- **자동 녹음**: 진료 시간표 기반 완전 자동화 녹음 및 시작/종료 동기화
- **스마트 분할**: 10분 단위 자동 파일 분할, 날짜별 폴더 정리
- **VAD 지원**: 무음 구간 자동 감지 및 스킵, 민감도 조절 가능
- **녹음 품질 프리셋**: 64/48/32kbps AAC-LC 프로필과 조용한 환경용 메이크업 게인(+0~12dB) 제공
- **OneDrive 동기화**: 개인 OneDrive 폴더 자동 백업 + 보관 기간 관리
- **자동 마이크 점검**: 앱 시작 시 3초 샘플로 장치/권한/입력 레벨 검사 (RMS 0.04 기준)

### 자동 실행 매니저 (신규 ✨)
- **앱 시작 시 프로그램 자동 실행**: EMR, PACS 뷰어, 진단 장비, 문서 등을 순차적으로 자동 실행
- **다양한 파일 지원**: 실행 파일(.exe), 문서(Office, PDF 등), URL 등록 가능
- **실행 순서 조정**: 드래그 핸들(⋮⋮)로 쉬운 순서 변경
- **개별 제어**: 프로그램별 활성화/비활성화, 편집, 삭제 기능
- **대기 시간 설정**: 프로그램 간 로딩 시간 확보용 대기 시간(초) 개별 설정
- **파일 유효성 검증**: 경로 오류 시 즉시 알림 (빨간색 경고 아이콘)
- **테스트 실행**: 설정 완료 후 바로 동작 확인 가능

### 사용자 경험
- **3탭 구조**: 녹음 대시보드 / 녹음 설정 / 자동 실행 (ON/OFF 상태 실시간 표시)
- **시스템 트레이**: 닫아도 백그라운드 유지, 우클릭 메뉴로 녹음 토글·마이크 점검·설정·종료 제어
- **도움말 & 튜토리얼**: 앱 내 도움말 다이얼로그와 3개 쇼케이스 튜토리얼 (대시보드/설정/자동실행)

## 📚 문서

- 개발 가이드: [docs/developing.md](docs/developing.md)
- 사용자 가이드: [docs/user-guide.md](docs/user-guide.md)
- 제품 요구사항(PRD): [docs/medical-recording-prd.md](docs/medical-recording-prd.md)
- 자동 실행 매니저 PRD: [docs/auto-lancher-prd.md](docs/auto-lancher-prd.md)
- WSL ↔ Windows 동기화 가이드: [docs/sync-workflow.md](docs/sync-workflow.md)

## 🛠 개발 환경 설정

> 📖 **자세한 설치 가이드**: [INSTALL.md](INSTALL.md) 참고

- 표준 Flutter 버전: `3.35.3 (stable)`
- Windows 자동 설치 스크립트는 기본적으로 위 버전을 설치/유지합니다.
- 개발 코드는 WSL 경로(`/home/.../eyebottlelee`)에, Windows 빌드는 NTFS 경로(`C:\ws-workspace\eyebottlelee`)에서 수행합니다.
- 커밋 시 post-commit 훅이 `scripts/sync_wsl_to_windows.sh`를 호출해 자동 동기화하며, 필요 시 수동으로 실행하세요.

### ⚡ 빠른 설치 (권장)
PowerShell(관리자)에서 실행:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\windows\setup-dev.ps1
```

**Android Studio 직접 다운로드 시**:
```powershell
# SHA-256 검증 포함 설치
.\scripts\windows\setup-dev.ps1 -StudioPath 'C:\Downloads\android-studio-2025.1.3.7-windows.exe' -StudioSha256 e9c127638428cc4298f98529c1b582dbca100c98dbf4792dc95e92d2f19918c5
```

버전 강제 재설치(선택):
```powershell
# 이미 다른 Flutter가 설치되어 있을 때 표준 버전으로 맞춤
.\scripts\windows\setup-dev.ps1 -ForceFlutter -FlutterVersion 3.35.3
```

**설치 검증**:
```powershell
.\scripts\windows\verify-setup.ps1
```

### 1. Windows 환경 준비

#### Flutter SDK 설치
```cmd
# 1. Flutter SDK 다운로드
# https://docs.flutter.dev/get-started/install/windows

# 2. 압축 해제 (예: C:\flutter)
# 3. 시스템 PATH에 C:\flutter\bin 추가

# 4. Windows Desktop 활성화
flutter config --enable-windows-desktop

# 5. 개발 환경 확인
flutter doctor
```

#### Visual Studio 2022 설치
- Visual Studio 2022 Community 다운로드
- "Desktop development with C++" 워크로드 설치
- Windows SDK 포함 설치

#### Android Studio 설치
- Android Studio 다운로드 및 설치
- Flutter/Dart 플러그인 설치
- Flutter SDK 경로 설정

### 2. 프로젝트 설정

#### WSL에서 프로젝트 클론/개발
```bash
# WSL에서 실행
cd /home/<user>/projects
git clone <repository-url> eyebottlelee
cd eyebottlelee

# 의존성 설치는 Windows에서 수행
```

#### Windows에서 의존성 설치
```cmd
# Windows 명령프롬프트에서 실행
# WSL 경로 접근: \\wsl$\\<distro>\\home\\<user>\\projects\\eyebottlelee
cd "\\wsl$\\Ubuntu\\home\\<user>\\projects\\eyebottlelee"

flutter pub get
```

### 3. 개발 및 실행

#### Android Studio에서 개발
1. Android Studio(Windows)에서 프로젝트 열기
   - 경로: `\\wsl$\<배포판>\home\<user>\projects\eyebottlelee`
2. 디바이스 선택: `Windows (desktop)`
3. 실행: F5 또는 Run 버튼

#### 명령어로 실행
```cmd
# Windows에서 실행
flutter run -d windows
```

## 📱 빌드 및 패키징

### Debug 빌드
```cmd
flutter build windows --debug
```

### Release 빌드
```cmd
flutter build windows --release
```

### MSIX 패키징
```cmd
# MSIX 패키지 생성 (Microsoft Store 배포용)
dart run msix:create
```
> 장시간 안정성 점검용으로 PowerShell에서 `pwsh -File scripts\windows\run-soak-test.ps1`를 실행하면 8시간 Soak 테스트 로그(`C:\ws-workspace\eyebottlelee\soak-logs` 저장)를 수집할 수 있습니다.


> 참고: `msix_config.logo_path`는 `assets/icons/icon.ico`를 바라봅니다. 공식 로고 기반 ICO는 `scripts/windows/generate-placeholder-icons.ps1`로 생성할 수 있으며, 배포 전에는 실제 아이콘을 생성하거나 교체하세요.

## 🔧 설정

### 1. 진료 시간표 설정
- 앱 실행 후 "진료 시간표 설정" 클릭
- 요일별 진료 시간 및 점심시간 설정 (기본: 오전 09:00~13:00 / 오후 14:00~18:00)

### 2. 저장 폴더 설정
- OneDrive 동기화 폴더 선택 권장
- 기본 경로: `%USERPROFILE%\OneDrive\진료녹음`

### 3. 자동 실행 매니저 설정 (신규 ✨)
- 메인 화면 → **자동 실행 탭** 선택
- **자동 실행 스위치**: 상단 스위치를 켜면 앱 시작 시 등록된 프로그램들이 자동 실행됩니다
- **프로그램 추가**:
  1. "프로그램 추가" 버튼 클릭
  2. "찾아보기"로 실행 파일(.exe), 문서, URL 선택
  3. 프로그램명과 대기 시간(초) 입력
  4. "추가" 버튼으로 등록
- **프로그램 관리**:
  - 드래그 핸들(⋮⋮)을 잡고 드래그하여 실행 순서 변경
  - 각 프로그램 우측 스위치로 개별 활성화/비활성화
  - 연필 아이콘으로 편집, 휴지통 아이콘으로 삭제
  - 파일 경로 오류 시 빨간색 경고 아이콘 표시
- **테스트 실행**: "테스트 실행" 버튼으로 설정 즉시 검증 가능

### 4. 시스템 트레이 사용
- 창을 닫아도 앱은 트레이로 숨겨져 녹음을 지속합니다
- 아이콘 좌/더블클릭: 메인 창 복원, 우클릭: 컨텍스트 메뉴 표시
- 메뉴 항목:
  - **녹음 시작/중지**: 현재 상태에 따라 토글
  - **마이크 점검**: 3초 샘플로 장치/입력 레벨 재검사
  - **도움말**: 도움말 다이얼로그 열기 (튜토리얼 포함)
  - **설정 열기**: 메인 창의 설정 탭으로 이동
  - **종료**: 녹음을 안전하게 중지하고 앱 종료

## 📂 프로젝트 구조

```
lib/
├── main.dart                    # 앱 진입점, 윈도우 초기화
├── services/                    # 비즈니스 로직
│   ├── audio_service.dart       # 녹음/분할/VAD/보관정리
│   ├── schedule_service.dart    # 주간 스케줄 → cron 작업 등록
│   ├── tray_service.dart        # 시스템 트레이 연동 (가드)
│   ├── mic_diagnostics_service.dart # 마이크 입력 레벨 진단 (RMS 기준)
│   ├── settings_service.dart    # SharedPreferences 저장/로드
│   ├── logging_service.dart     # logger 기반 파일 로깅/에러 알림
│   ├── auto_launch_service.dart # Windows 시작프로그램 등록/해제
│   └── auto_launch_manager_service.dart # 앱 시작 시 프로그램 자동 실행 엔진 (신규)
├── models/                      # 데이터 모델
│   ├── schedule_model.dart      # WeeklySchedule/DaySchedule
│   ├── launch_program.dart      # 실행 프로그램 설정 모델 (신규)
│   └── launch_manager_settings.dart # 자동 실행 매니저 설정 (신규)
├── ui/                          # 사용자 인터페이스
│   ├── screens/
│   │   └── main_screen.dart    # 3탭 구조 (녹음 대시보드/녹음 설정/자동 실행), 튜토리얼
│   └── widgets/
│       ├── recording_status_widget.dart     # 녹음 상태 카드
│       ├── animated_volume_meter.dart       # 실시간 볼륨 미터
│       ├── schedule_config_widget.dart      # 진료 시간표 편집
│       ├── advanced_settings_dialog.dart    # 품질/VAD/보관 기간 설정
│       ├── launch_manager_widget.dart       # 자동 실행 매니저 메인 UI (신규)
│       ├── add_program_dialog.dart          # 프로그램 추가/편집 다이얼로그 (신규)
│       └── help/
│           ├── help_center_dialog.dart      # 도움말 & 빠른 시작
│           └── help_section.dart            # 도움말 섹션 위젯
└── utils/                       # 유틸리티

windows/                        # Windows 플랫폼 코드
assets/                         # 리소스 파일 (icons, logos)
```

## 🎯 주요 의존성

```yaml
dependencies:
  record: ^6.1.1              # 오디오 녹음
  path_provider: ^2.1.4       # 파일 경로
  shared_preferences: ^2.3.2  # 설정 저장
  cron: ^0.5.1                # 스케줄링
  system_tray: ^2.0.3         # 시스템 트레이
  window_manager: ^0.5.1      # 윈도우 관리
  launch_at_startup: ^0.5.1   # 자동 시작 등록
  file_selector: ^1.0.3       # 저장 폴더 선택
  logger: ^2.4.0              # 파일 로깅
```

## 🐛 문제 해결

### Flutter Doctor 오류
```cmd
flutter doctor
# 출력된 문제점들을 순서대로 해결
```

### 권한 문제
- 마이크 권한: Windows 설정 > 개인정보 > 마이크
- 파일 접근: OneDrive 폴더 권한 확인

### 빌드 오류
```cmd
# 캐시 정리
flutter clean
flutter pub get

# 다시 빌드
flutter build windows
```

## 📋 개발 계획

### Week 1: 기본 기능
- [x] 기본 녹음 기능
- [x] 파일 분할 메커니즘
- [x] 마이크 모니터링
- [x] 기본 UI

### Week 2: 자동화
- [x] 진료 시간표 스케줄링
- [x] 시스템 트레이 통합
- [x] 자동 시작 기능

### Week 3: 최적화
- [x] VAD 구현
- [x] OneDrive 연동
- [x] 설정 관리

### Week 4: 완성
- [ ] 품질 보장 테스트
- [ ] 패키징 및 배포 준비

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.

## 👥 기여

버그 리포트나 기능 제안은 Issues 탭에서 해주세요.

---
**아이보틀 개발팀** | [eyebottle.kr](https://eyebottle.kr)
