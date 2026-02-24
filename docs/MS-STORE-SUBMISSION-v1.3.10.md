# MS Store 제출 - v1.3.10

> **제출 준비일:** 2026-02-24
> **버전:** 1.3.10.0 (Build 21)
> **이전 Store 버전:** 1.3.4.0 (v1.3.9는 제출 미완료)

---

## 📋 빌드 전 체크리스트

| # | 항목 | 확인 |
|---|------|------|
| 1 | `pubspec.yaml` 버전 확인: `version: 1.3.10+21` | [ ] |
| 2 | `pubspec.yaml` MSIX 버전 확인: `msix_version: 1.3.10.0` | [ ] |
| 3 | `pubspec.yaml` → `store: true` 확인 | [ ] |
| 4 | `pubspec.yaml` → `capabilities: "microphone, internetClient"` 확인 | [ ] |
| 5 | `pubspec.yaml` → `windows_capabilities: "runFullTrust"` 확인 | [ ] |
| 6 | `pubspec.yaml` → `dependencies: "Microsoft.VCLibs.140.00.UWPDesktop"` 확인 | [ ] |
| 7 | `pubspec.yaml` → `startup_task` 섹션 존재 확인 | [ ] |
| 8 | `assets/bin/ffmpeg.exe` 주석 제외 상태 유지 확인 | [ ] |
| 9 | Git 커밋 완료 | [ ] |

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

**빌드 결과:**
```
C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix
예상 크기: ~83 MB
```

### Step 3: MSIX 로컬 테스트 (선택)

```powershell
# 기존 앱 제거 (이미 설치 시)
Get-AppxPackage -Name "DCD952CB.367669DCDC1D3" | Remove-AppxPackage

# 설치 (Windows 개발자 모드 필요)
Add-AppxPackage -Path "C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix"
```

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
v1.3.10 업데이트

[버그 수정]
• Windows 부팅 시 자동 시작 기능 완전 수정
  - 설정 OFF 상태에서 부팅 시 앱이 실행되는 문제 해결
  - 백그라운드(트레이) 시작 시 창이 잠깐 보이는 문제 해결
• 자동 실행 상태 표시 개선 (OS 동기화 상태 배지 추가)

[개선 사항]
• 앱 시작 안정성 향상
• 불필요한 외부 프로세스 호출 제거 (PowerShell/WMIC)
• 코드 품질 개선 (컴파일 에러 0개)
```

### 축약 버전 (릴리스 노트가 너무 긴 경우)

```
v1.3.10 업데이트

• Windows 부팅 시 자동 시작 기능 수정
• 백그라운드 시작 시 창이 보이는 문제 해결
• 자동 실행 상태 표시 개선
• 앱 시작 안정성 향상
```

---

## 📝 인증 노트 (제출 옵션 > "인증 노트")

```
v1.3.10 - Startup Task Bug Fixes

MAIN CHANGES FROM v1.3.4:
This update fixes critical bugs in the Windows startup feature.

BUG FIXES:
1. Fixed: App launching even when startup setting is OFF
2. Fixed: Window briefly appearing when "start minimized to tray" is enabled
3. Fixed: PowerShell/WMIC dependency removed for better MSIX sandbox compatibility

TESTING INSTRUCTIONS:

Test Case 1: Startup OFF
1. Install app
2. Open Settings > Windows Startup
3. Ensure "Launch at Windows startup" is OFF
4. Restart PC
5. Expected: App should NOT start automatically

Test Case 2: Startup ON + Background ON
1. Enable "Launch at Windows startup"
2. Enable "Start minimized to tray on boot"
3. Restart PC
4. Expected: App starts in tray only (no window flash)

Test Case 3: Startup ON + Background OFF
1. Enable "Launch at Windows startup"
2. Disable "Start minimized to tray on boot"
3. Restart PC
4. Expected: App window appears normally

NO BREAKING CHANGES:
- All v1.3.4 features work as before
- User settings preserved on upgrade
- Backward compatible

DEPENDENCIES (unchanged):
- Microsoft.VCLibs.140.00.UWPDesktop
- Windows 10 version 1809+
```

### 축약 버전 (인증 노트가 너무 긴 경우)

```
v1.3.10 - Startup Bug Fixes

CHANGES:
- Fixed: App launching when startup setting is OFF
- Fixed: Window flash on background start
- Removed PowerShell/WMIC dependency

TEST:
1. Settings > Windows Startup > Toggle OFF > Restart > Verify app NOT started
2. Toggle startup ON + background ON > Restart > Verify app in tray only
3. Toggle startup ON + background OFF > Restart > Verify window appears

All v1.3.4 features unchanged.
Requires: Windows 10 1809+, VCLibs.140.00.UWPDesktop
```

---

## ⚠️ 알려진 주의사항

### 1. `assets/bin/ffmpeg.exe` 제외 상태

현재 `pubspec.yaml`에서 ffmpeg.exe 에셋이 주석 처리되어 있음:
```yaml
# - assets/bin/ffmpeg.exe  # 임시 제외: Partner Center 테스트
```
이는 Partner Center 업로드 시 파일 크기/검증 문제를 방지하기 위한 것으로, WAV 변환 기능은 시스템에 설치된 ffmpeg에 의존합니다.

### 2. `store: true` 필수

`pubspec.yaml`의 `msix_config` > `store: true`가 반드시 `true`여야 합니다.
- `false`일 경우 자체 서명 인증서가 포함되어 Partner Center에서 거부됨
- `true`일 경우 서명을 생략하고 Partner Center가 서명을 처리함

### 3. Origin Push 필요

현재 로컬에 v1.3.9 이후 커밋이 origin에 push되지 않은 상태입니다:
```bash
git push origin main
```

---

## 🔍 pubspec.yaml 핵심 설정 (현재 상태)

```yaml
version: 1.3.10+21

msix_config:
  display_name: 아이보틀 진료 녹음
  publisher_display_name: 아이보틀
  identity_name: DCD952CB.367669DCDC1D3
  publisher: CN=0CEBC30B-3CD4-4E21-A48A-421AE62E38D3
  msix_version: 1.3.10.0
  logo_path: assets/icons/icon.ico
  capabilities: "microphone, internetClient"
  windows_capabilities: "runFullTrust"
  store: true
  dependencies: "Microsoft.VCLibs.140.00.UWPDesktop"
  startup_task:
    task_id: EyebottleMedicalRecorder
    enabled: false
    parameters: "--autostart"
```

---

## 🐛 이전 업로드 에러 대응

### "Long file" 오류
→ 릴리스 노트나 인증 노트를 축약 버전으로 교체

### Publisher/Identity 불일치
→ pubspec.yaml의 identity_name, publisher가 Partner Center 설정과 일치하는지 확인

### 패키지 검증 실패
→ `store: true` 확인, 자체 서명 인증서 포함 여부 확인

---

**작성일:** 2026-02-24
**현재 pubspec 버전:** v1.3.10 (Build 21, MSIX 1.3.10.0)
**이전 Store 버전:** v1.3.4.0
