# 개발자 모드 확인 가이드

## 🔍 개발자 모드 확인 방법

WSL에서 자동 확인이 어려워서, Windows에서 직접 확인해야 합니다.

### 방법 1: PowerShell로 확인 (빠름)

**Windows PowerShell을 관리자 권한으로 실행**한 후:

```powershell
# 개발자 모드 확인
$reg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue

if ($reg -and $reg.AllowDevelopmentWithoutDevLicense -eq 1) {
    Write-Host "✅ 개발자 모드: 활성화됨" -ForegroundColor Green
} else {
    Write-Host "❌ 개발자 모드: 비활성화됨" -ForegroundColor Red
    Write-Host ""
    Write-Host "활성화 방법:" -ForegroundColor Yellow
    Write-Host "  Windows 11: 설정 → 개인정보 보호 및 보안 → 개발자용 → 개발자 모드 토글 켜기"
    Write-Host "  Windows 10: 설정 → 업데이트 및 보안 → 개발자용 → 개발자 모드 선택"
}
```

### 방법 2: Windows 설정에서 확인 (GUI)

**Windows 11:**
1. `Win + I` 키로 설정 열기
2. 왼쪽 메뉴에서 **"개인정보 보호 및 보안"** 클릭
3. 아래로 스크롤하여 **"개발자용"** 클릭
4. **"개발자 모드"** 토글이 **켜짐**인지 확인

**Windows 10:**
1. `Win + I` 키로 설정 열기
2. **"업데이트 및 보안"** 클릭
3. 왼쪽 메뉴에서 **"개발자용"** 클릭
4. **"개발자 모드"** 라디오 버튼이 선택되어 있는지 확인

### 방법 3: 스크립트 실행

프로젝트 폴더에서:

```powershell
# PowerShell에서 실행
cd C:\ws-workspace\eyebottlelee
pwsh -File scripts\windows\check-dev-mode.ps1
```

---

## ✅ 확인 결과에 따른 다음 단계

### 개발자 모드가 활성화된 경우
→ **1단계: 설치 테스트**로 진행 가능합니다!

### 개발자 모드가 비활성화된 경우
1. 위의 방법으로 개발자 모드 활성화
2. 활성화 후 다시 확인
3. 확인 완료되면 설치 테스트 진행

---

## 💡 참고

- 개발자 모드를 활성화하면 시스템 재시작이 필요할 수 있습니다.
- 개발자 모드가 없으면 MSIX 파일 설치 시 오류가 발생합니다.
- 개발자 모드는 시스템 보안에 영향을 주지 않지만, 신뢰할 수 있는 앱만 설치하세요.

