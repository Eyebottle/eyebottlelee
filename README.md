# 아이보틀 진료 녹음 (Eyebottle Medical Recorder)

진료 중 환자와의 대화를 자동으로 녹음하고 체계적으로 관리하는 Windows 데스크톱 애플리케이션입니다.

## 🚀 주요 기능

- **자동 녹음**: 진료 시간표 기반 완전 자동화 녹음
- **스마트 분할**: 10분 단위 자동 파일 분할
- **VAD 지원**: 무음 구간 자동 감지 및 스킵
- **OneDrive 동기화**: 개인 OneDrive 폴더 자동 백업
- **시스템 트레이**: 백그라운드 실행 및 상태 모니터링

## 🛠 개발 환경 설정

> 📖 **자세한 설치 가이드**: [INSTALL.md](INSTALL.md) 참고

- 표준 Flutter 버전: `3.35.3 (stable)`
- Windows 자동 설치 스크립트는 기본적으로 위 버전을 설치/유지합니다.

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

> 참고: `msix` 생성 시 `msix_config.logo_path`(기본: `assets/icons/icon.ico`)가 실제 아이콘 파일이어야 합니다. 
> 현재 레포에는 `assets/icons/.gitkeep`만 포함되어 있으므로 배포 전 실제 `.ico` 파일을 추가하세요.

## 🔧 설정

### 1. 진료 시간표 설정
- 앱 실행 후 "진료 시간표 설정" 클릭
- 요일별 진료 시간 및 점심시간 설정

### 2. 저장 폴더 설정
- OneDrive 동기화 폴더 선택 권장
- 기본 경로: `%USERPROFILE%\OneDrive\진료녹음`

### 3. 시스템 트레이 설정
- Windows 시작 시 자동 실행 설정
- 트레이 아이콘으로 상태 확인

## 📂 프로젝트 구조

```
lib/
├── main.dart                    # 앱 진입점
├── services/                    # 비즈니스 로직
│   ├── audio_service.dart       # 오디오 녹음 서비스
│   ├── schedule_service.dart    # 스케줄링 서비스
│   └── tray_service.dart        # 시스템 트레이 서비스
├── models/                      # 데이터 모델
│   └── schedule_model.dart      # 스케줄 모델
├── ui/                         # 사용자 인터페이스
│   ├── screens/                # 화면
│   │   └── main_screen.dart    # 메인 화면
│   └── widgets/                # 위젯
│       ├── recording_status_widget.dart
│       ├── volume_meter_widget.dart
│       └── schedule_config_widget.dart
└── utils/                      # 유틸리티

windows/                        # Windows 플랫폼 코드
assets/                         # 리소스 파일
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
  launch_at_startup: ^0.5.1   # 자동 시작
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
- [ ] 진료 시간표 스케줄링
- [ ] 시스템 트레이 통합
- [ ] 자동 시작 기능

### Week 3: 최적화
- [ ] VAD 구현
- [ ] OneDrive 연동
- [ ] 설정 관리

### Week 4: 완성
- [ ] 품질 보장 테스트
- [ ] 패키징 및 배포 준비

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.

## 👥 기여

버그 리포트나 기능 제안은 Issues 탭에서 해주세요.

---
**아이보틀 개발팀** | [eyebottle.kr](https://eyebottle.kr)
