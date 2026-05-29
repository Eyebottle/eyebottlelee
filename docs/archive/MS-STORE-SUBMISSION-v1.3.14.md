# MS Store 제출 - v1.3.14

> **제출 준비일:** 2026-03-02
> **버전:** 1.3.14.0 (Build 25)
> **이전 Store 버전:** 1.3.13.0

---

## 🐛 v1.3.13 → v1.3.14 핵심 버그 수정

### 문제
사용자가 **앱 아이콘을 직접 클릭**해서 실행하면 "번쩍" 보이고 바로 사라지는 현상.
트레이에도 없고 작업표시줄에도 없어서 앱이 완전히 사라진 것처럼 보임.

### 원인
`main.dart`의 `shouldStartMinimized` 판단 로직 오류:
```dart
// ❌ v1.3.13 (버그): 수동 실행에서도 설정값 ON이면 숨김
final shouldStartMinimized = launchAtStartup && startMinimizedOnBoot;
```

사용자가 설정에서 `launchAtStartup=true` + `startMinimizedOnBoot=true`를 켜놓으면,
**수동 실행**(아이콘 클릭)에서도 창이 숨겨졌음.

### 수정
```dart
// ✅ v1.3.14 (수정): --autostart 인자가 있을 때만 숨김
final shouldStartMinimized = hasAutostartArg && startMinimizedOnBoot;
```

추가로 `main.cpp`에서 `--autostart` 시 `window.Show()` 자체를 건너뛰어
"번쩍" 현상 원천 차단.

---

## 📋 빌드 전 체크리스트

| # | 항목 | 확인 |
|---|------|------|
| 1 | `pubspec.yaml` 버전 확인: `version: 1.3.14+25` | [ ] |
| 2 | `pubspec.yaml` MSIX 버전 확인: `msix_version: 1.3.14.0` | [ ] |
| 3 | `pubspec.yaml` → `store: true` 확인 | [ ] |
| 4 | `pubspec.yaml` → `capabilities: "microphone, internetClient"` 확인 | [ ] |
| 5 | `pubspec.yaml` → `windows_capabilities: "runFullTrust"` 확인 | [ ] |
| 6 | `pubspec.yaml` → `dependencies: "Microsoft.VCLibs.140.00.UWPDesktop"` 확인 | [ ] |
| 7 | `pubspec.yaml` → `startup_task` 섹션 + `parameters: "--autostart"` 확인 | [ ] |
| 8 | Git 커밋 완료 | [ ] |

---

## 🔄 전체 파이프라인 (WSL → Windows → Partner Center)

### Step 1: WSL에서 코드 확인 및 동기화

```bash
# 1-1. WSL에서 현재 코드 상태 확인
cd /home/usereyebottle/projects/eyebottlelee
git status
git log --oneline -5

# 1-2. Windows로 동기화
bash scripts/sync_wsl_to_windows.sh
```

> **동기화 대상:** `/home/usereyebottle/projects/eyebottlelee/` → `C:\ws-workspace\eyebottlelee\`
> **제외 항목:** `.git/`, `build/`, `.dart_tool/`, `.claude/`, `windows/flutter/ephemeral/`

### Step 2: Windows에서 MSIX 빌드

**방법 A: PowerShell 자동화 스크립트** (권장)
```powershell
cd C:\ws-workspace\eyebottlelee
pwsh -File scripts\windows\build-msix.ps1
```

**방법 B: 수동 빌드**
```powershell
cd C:\ws-workspace\eyebottlelee

# 의존성 업데이트
flutter clean
flutter pub get

# Release 빌드
flutter build windows --release

# MSIX 패키지 생성
dart run msix:create

# 결과 확인
dir build\windows\x64\runner\Release\medical_recorder.msix
```

### Step 3: MSIX 로컬 테스트

```powershell
# 기존 앱 제거 (이미 설치 시)
Get-AppxPackage -Name "DCD952CB.367669DCDC1D3" | Remove-AppxPackage

# 설치 (Windows 개발자 모드 필요)
Add-AppxPackage -Path "C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix"
```

**테스트 시나리오:**
1. ✅ 앱 아이콘 클릭 → 창이 정상적으로 표시됨 (번쩍+사라짐 없음)
2. ✅ X 버튼 클릭 → 트레이로 숨김 (트레이 아이콘 확인)
3. ✅ 트레이 아이콘 더블클릭 → 창 복원
4. ✅ 트레이 우클릭 → 컨텍스트 메뉴 표시

### Step 4: Partner Center 업로드

1. https://partner.microsoft.com/dashboard 접속
2. "아이보틀 진료녹음 & 자동실행 매니저" 선택
3. "새 제출 시작" (또는 기존 draft 제출이 있으면 삭제 후 새로 생성)
4. 아래 섹션의 릴리스 노트/인증 노트 입력
5. 패키지 업로드
6. 제출

---

## 📝 릴리스 노트 (스토어 목록 > "이 릴리스의 새로운 기능")

```
v1.3.14 업데이트

[긴급 버그 수정]
• 앱 실행 시 창이 사라지는 문제 수정
  - 앱 아이콘 클릭 시 정상적으로 창이 표시됩니다
  - 백그라운드 시작은 Windows 부팅 자동실행에서만 동작합니다
```

### 축약 버전

```
v1.3.14 - 앱 실행 시 창이 사라지는 버그 수정
```

---

## 📝 인증 노트 (제출 옵션 > "인증 노트")

```
v1.3.14 - Critical Bug Fix: Window disappearing on manual launch

ISSUE FIXED:
When users manually launched the app (clicking the icon), the window
would flash briefly and then disappear completely. This was caused by
the background start logic incorrectly activating during manual launches.

ROOT CAUSE:
The previous version checked settings values (launchAtStartup &&
startMinimizedOnBoot) to decide whether to hide the window, without
checking if the launch was actually triggered by Windows boot.

FIX:
The window is now only hidden when the --autostart parameter is present,
which is exclusively passed by the MSIX startup task during Windows boot.
Manual launches always show the window normally.

TESTING:
Test Case 1: Manual Launch
1. Click the app icon / Start Menu entry
2. Expected: Window appears and stays visible

Test Case 2: Close to Tray
1. Launch app normally
2. Click X button
3. Expected: Window hides to system tray
4. Double-click tray icon
5. Expected: Window reappears

All v1.3.13 features unchanged.
Requires: Windows 10 1809+, VCLibs.140.00.UWPDesktop
```

---

## 🔍 변경 파일

| 파일 | 변경 내용 |
|------|-----------|
| `windows/runner/main.cpp` | `--autostart`일 때 `window.Show()` 건너뛰기 |
| `lib/main.dart` | `shouldStartMinimized` 로직 수정: `hasAutostartArg && startMinimizedOnBoot` |

---

**작성일:** 2026-03-02
**현재 pubspec 버전:** v1.3.14 (Build 25, MSIX 1.3.14.0) ← pubspec 업데이트 필요
**이전 Store 버전:** v1.3.13.0
