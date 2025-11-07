# MSIX 테스트 사전 준비 체크리스트

## ✅ 현재 상태 확인

### 1. 이전 버전 설치 확인
- **결과**: 설치된 이전 버전 없음 ✅
- PowerShell 명령어로 확인했을 때 eyebottle 관련 패키지가 없습니다.

### 2. MSIX 파일 확인
- **OneDrive**: `/mnt/c/Users/user/OneDrive/이안과/eyebottlelee-v1.3.0-wav-fix/medical_recorder.msix` ✅
  - 크기: 83MB
  - 생성일: 2025-11-07 07:41
  - 버전: v1.3.0.0 (WAV 변환 개선 + 로고 적용)

- **빌드 폴더**: `/mnt/c/ws-workspace/eyebottlelee/build/windows/x64/runner/Release/medical_recorder.msix` ✅
  - 동일한 파일 (같은 크기, 같은 시간)

⚠️ **참고**: 현재 MSIX 파일이 최신 커밋(08:44 - 실행 파일 아이콘 업데이트)보다 이전 버전입니다.
테스트 후 필요하면 최신 버전으로 재빌드할 수 있습니다.

---

## 📋 사전 준비 단계

### ✅ 1단계: 개발자 모드 활성화 확인

**Windows 11:**
1. Windows 설정 열기 (Win + I)
2. 왼쪽 메뉴에서 "개인정보 보호 및 보안" 클릭
3. 아래로 스크롤하여 "개발자용" 클릭
4. "개발자 모드" 토글을 **켜기**로 설정

**Windows 10:**
1. Windows 설정 열기 (Win + I)
2. "업데이트 및 보안" 클릭
3. 왼쪽 메뉴에서 "개발자용" 클릭
4. "개발자 모드" 라디오 버튼 선택

**확인 방법:**
- 개발자 모드가 켜져 있으면 "개발자 모드" 옆에 켜짐 표시가 보입니다.
- 또는 PowerShell에서 확인:
```powershell
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
```

### ✅ 2단계: 이전 버전 제거 (필요시)

**이미 확인 완료**: 현재 설치된 이전 버전이 없습니다.

만약 나중에 제거가 필요하면:
```powershell
# PowerShell 관리자 권한으로 실행
Get-AppxPackage | Where-Object {$_.Name -like "*eyebottle*"}

# 출력된 패키지가 있으면 제거
Remove-AppxPackage -Package "패키지전체이름"
```

### ✅ 3단계: MSIX 파일 위치 확인

테스트에 사용할 MSIX 파일:
- **경로**: `C:\Users\user\OneDrive\이안과\eyebottlelee-v1.3.0-wav-fix\medical_recorder.msix`
- 또는: `C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.msix`

두 파일은 동일합니다.

---

## 🎯 다음 단계

사전 준비가 완료되면 다음을 진행하세요:

1. **1단계: 설치 테스트** (체크리스트 49-83줄)
   - MSIX 파일 더블클릭 또는 PowerShell로 설치
   - 시작 메뉴 등록 확인
   - 아이콘 표시 확인

2. **2단계: 기본 기능 테스트** (체크리스트 87-114줄)
   - 앱 실행
   - 마이크 권한 요청
   - 저장 폴더 선택

---

## 💡 팁

- 개발자 모드가 켜져 있지 않으면 MSIX 설치 시 오류가 발생합니다.
- 이전 버전이 설치되어 있으면 충돌이 발생할 수 있으므로 반드시 제거하세요.
- MSIX 파일은 Windows 탐색기에서 더블클릭하여 설치할 수 있습니다.

