# 아이보틀 진료 녹음 - 설치 가이드

## 🚀 빠른 시작 (권장)

### Windows 자동 설치
PowerShell(관리자)에서 실행:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\windows\setup-dev.ps1
```

표준 Flutter 버전: `3.35.3 (stable)`
```powershell
# 이미 다른 버전이 설치된 환경에서 표준 버전으로 강제 재설치
.\scripts\windows\setup-dev.ps1 -ForceFlutter -FlutterVersion 3.35.3
```

### Android Studio 파일을 직접 다운로드한 경우
```powershell
.\scripts\windows\setup-dev.ps1 -StudioPath 'C:\Downloads\android-studio-2025.1.3.7-windows.exe' -StudioSha256 e9c127638428cc4298f98529c1b582dbca100c98dbf4792dc95e92d2f19918c5
```

## 📋 필요한 설치 항목

### 1. Android Studio (필수)
**다운로드 옵션:**
- **권장**: `android-studio-2025.1.3.7-windows.exe` (1.4GB)
- **ZIP 버전**: `android-studio-2025.1.3.7-windows.zip` (1.4GB)

**SHA-256 확인**:
- `.exe`: `e9c127638428cc4298f98529c1b582dbca100c98dbf4792dc95e92d2f19918c5`
- `.zip`: `824ddc4f926f13d0cbe65f741ba0c40fd6c8d4d471adbbd4a35b3db5ee7c0a39`

### 2. Flutter SDK (필수)
- Windows 64-bit용 Flutter SDK
- 권장 경로: `C:\flutter`
- Windows Desktop 지원 활성화 필요

### 3. Visual Studio 2022 (필수)
- Community 버전 (무료) 또는 Build Tools
- **필수 워크로드**: "Desktop development with C++"
- Windows SDK 포함

### 4. Git (권장)
- 버전 관리 및 소스 코드 다운로드용

## 🛠 수동 설치 과정

### 1. Android Studio 설치
1. 위 다운로드 링크에서 `.exe` 파일 다운로드
2. SHA-256 해시 검증 (보안)
3. 설치 실행 및 Flutter/Dart 플러그인 설치

### 2. Flutter SDK 설치
```cmd
# 1. Flutter SDK 다운로드
# https://docs.flutter.dev/get-started/install/windows

# 2. C:\flutter에 압축 해제
# 3. 시스템 PATH에 C:\flutter\bin 추가

# 4. Windows Desktop 활성화
flutter config --enable-windows-desktop

# 5. 환경 확인
flutter doctor
```

### 3. Visual Studio 2022 설치
```cmd
# Chocolatey 사용 (권장)
choco install visualstudio2022community --params "--add Microsoft.VisualStudio.Workload.NativeDesktop"

# 또는 직접 다운로드
# https://visualstudio.microsoft.com/vs/community/
```

## 🔍 설치 검증

### 자동 검증 스크립트
```powershell
.\scripts\windows\verify-setup.ps1
```

### 수동 검증
```cmd
# 각 도구 설치 확인
flutter --version
dart --version
git --version

# Flutter 환경 전체 확인
flutter doctor -v

# Windows Desktop 지원 확인
flutter config
```

## 📂 프로젝트 설정

### WSL 프로젝트 열기
1. Android Studio 실행
2. **Open** 클릭
3. 경로 입력: `\\wsl$\Ubuntu\home\usereyebottle\projects\eyebottlelee`
4. **OK** 클릭

### 패키지 설치
```cmd
# 프로젝트 폴더에서 실행
flutter pub get
```

### 실행 테스트
```cmd
# Windows Desktop으로 실행
flutter run -d windows
```

## ⚠ 문제 해결

### "flutter: command not found"
- 시스템 재시작 후 PATH 환경변수 적용
- PowerShell 새 창에서 다시 시도

### Visual Studio Build Tools 오류
```cmd
# Visual Studio Installer에서 확인
# C++ 워크로드가 설치되었는지 확인
```

### WSL 경로 접근 불가
```cmd
# WSL Ubuntu 실행 확인
wsl -l -v

# Ubuntu가 Running 상태인지 확인
```

### Android Studio 플러그인 오류
1. Android Studio > File > Settings
2. Plugins > Flutter/Dart 검색 및 설치
3. IDE 재시작

## 🚀 개발 시작

### 1. 디바이스 선택
- Android Studio 상단 디바이스 선택: **Windows (desktop)**

### 2. 앱 실행
- **Run** 버튼 클릭 또는 F5
- 첫 실행 시 의존성 다운로드 시간 소요

### 3. Hot Reload 테스트
- 코드 수정 후 **Ctrl+S** 또는 **Hot Reload** 버튼
- UI 변경사항 즉시 반영 확인

## 📦 빌드 및 배포

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
# 앱 스토어 배포용 패키지 생성
dart run msix:create
```

**참고**: MSIX 생성 시 `assets/icons/icon.ico` 파일이 필요합니다.

## 📞 지원

### 문제 발생 시
1. `flutter doctor -v` 실행하여 환경 확인
2. 검증 스크립트로 설치 상태 점검
3. GitHub Issues에 문제 보고

### 유용한 명령어
```cmd
# 캐시 정리
flutter clean
flutter pub get

# 패키지 업데이트
flutter pub upgrade

# 환경 정보 확인
flutter doctor -v
flutter config
```

---
**아이보틀 개발팀** | 문의: support@eyebottle.kr
