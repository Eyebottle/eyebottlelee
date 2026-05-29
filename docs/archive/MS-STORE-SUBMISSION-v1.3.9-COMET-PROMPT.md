# MS Store 제출 - v1.3.9 (코멧 자동화용)

> **제출 준비일:** 2026-01-28
> **버전:** 1.3.9.0 (Build 20)

---

## 코멧 자동화 제출 프롬프트

### 프롬프트 (전체)

```
Microsoft Store Partner Center에서 앱 업데이트를 제출해야 합니다.

## 기본 정보
- Partner Center URL: https://partner.microsoft.com/dashboard
- 앱 이름: 아이보틀 진료녹음 & 자동실행 매니저
- 현재 Store 버전: 1.3.4.0
- 새 버전: 1.3.9.0

## 제출 절차

### 1단계: Partner Center 접속
1. https://partner.microsoft.com/dashboard 접속
2. 로그인 (이미 로그인되어 있으면 스킵)
3. 앱 목록에서 "아이보틀 진료녹음 & 자동실행 매니저" 클릭

### 2단계: 새 제출 시작
1. 앱 개요 페이지에서 "새 제출 시작" 또는 "Start submission" 버튼 클릭
2. 기존 제출이 있으면 삭제하거나 새로 시작

### 3단계: 패키지 업로드
1. "패키지" 또는 "Packages" 탭으로 이동
2. 기존 v1.3.4 패키지가 있으면 삭제 (X 버튼)
3. "찾아보기" 또는 "Browse" 클릭
4. 다음 파일 업로드:
   C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix
5. 업로드 완료 후 "자동 검증 통과" 확인 (녹색 체크마크)

### 4단계: 스토어 목록 - 릴리스 노트 입력
"스토어 목록" > "이 릴리스의 새로운 기능" 섹션에 다음 입력:

---릴리스 노트 시작---
v1.3.9 업데이트

[버그 수정]
• Windows 부팅 시 자동 시작 기능 완전 수정
  - 설정 OFF 상태에서 부팅 시 앱이 실행되는 문제 해결
  - 백그라운드(트레이) 시작 시 창이 잠깐 보이는 문제 해결

• 자동 실행 상태 표시 개선
  - 현재 상태를 명확하게 표시하는 배지 추가
  - 진단 다이얼로그에서 상세 정보 확인 가능

[개선 사항]
• 앱 시작 안정성 향상
• 불필요한 외부 프로세스 호출 제거 (PowerShell/WMIC)
• 코드 품질 개선 (컴파일 에러 0개)

[기술적 변경]
• --autostart 인자 기반 부팅 감지로 변경
• WindowTaskbarService 통합으로 창/작업표시줄 관리 일원화
---릴리스 노트 끝---

### 5단계: 제출 옵션 - 인증 노트 입력
"제출 옵션" > "인증 노트" 섹션에 다음 입력:

---인증 노트 시작---
v1.3.9 - Startup Task Bug Fixes

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
3. Status should show: "켜짐 · 백그라운드"
4. Restart PC
5. Expected: App starts in tray only (no window flash)

Test Case 3: Startup ON + Background OFF
1. Enable "Launch at Windows startup"
2. Disable "Start minimized to tray on boot"
3. Status should show: "켜짐"
4. Restart PC
5. Expected: App window appears normally

DIAGNOSTIC DIALOG:
- Settings > Windows Startup > "진단 정보" link
- Shows current startup state, --autostart detection, settings values

LOG FILE:
%LOCALAPPDATA%\Packages\DCD952CB.367669DCDC1D3_...\LocalCache\Local\아이보틀\logs\

NO BREAKING CHANGES:
- All v1.3.4 features work as before
- User settings preserved on upgrade
- Backward compatible

DEPENDENCIES (unchanged):
- Microsoft.VCLibs.140.00.UWPDesktop
- Windows 10 version 1809+
---인증 노트 끝---

### 6단계: 최종 확인 및 제출
1. 모든 필수 항목 입력 확인 (체크마크)
2. "제출" 또는 "Submit" 버튼 클릭
3. 확인 다이얼로그에서 "확인" 클릭

### 7단계: 제출 완료 확인
1. "제출 진행 중" 또는 "Submission in progress" 상태 확인
2. 제출 ID 기록
3. 완료!

## 주의사항
- MSIX 파일이 Windows에서 빌드되어 있어야 함
- 자동 검증 통과 후에만 제출 가능
- "long file" 오류 발생 시: 릴리스 노트나 인증 노트가 너무 길 수 있음 → 축약 필요
```

---

## 오류 대응

### "Long file" 오류 발생 시

릴리스 노트를 다음 축약 버전으로 교체:

```
v1.3.9 업데이트

[버그 수정]
• Windows 부팅 시 자동 시작 기능 수정
• 백그라운드 시작 시 창이 잠깐 보이는 문제 해결
• 자동 실행 상태 표시 개선

[개선 사항]
• 앱 시작 안정성 향상
• 코드 품질 개선
```

인증 노트 축약 버전:

```
v1.3.9 - Startup Bug Fixes

CHANGES:
- Fixed: App launching when startup setting is OFF
- Fixed: Window flash on background start
- Removed PowerShell/WMIC dependency

TEST:
1. Settings > Windows Startup > Toggle OFF
2. Restart PC
3. Verify: App does NOT start

4. Toggle startup ON + background ON
5. Restart PC
6. Verify: App in tray only (no window)

All v1.3.4 features unchanged.
Requires: Windows 10 1809+, VCLibs.140.00.UWPDesktop
```

---

## 제출 전 체크리스트

| 항목 | 상태 |
|------|------|
| Windows에서 MSIX 빌드 완료 | [ ] |
| medical_recorder.msix 파일 존재 | [ ] |
| 버전 1.3.9.0 확인 | [ ] |
| Partner Center 로그인 가능 | [ ] |

---

## 빌드 명령어 (Windows PowerShell)

```powershell
cd C:\ws-workspace\eyebottlelee
flutter clean
flutter pub get
flutter build windows --release
dart run msix:create
dir build\windows\x64\runner\Release\medical_recorder.msix
```

---

**작성일:** 2026-01-28
**용도:** 코멧 자동화 브라우저 MS Store 제출용
