# 개발자 모드 확인 스크립트
# 사용법: pwsh -File scripts/windows/check-dev-mode.ps1

Write-Host "=== 개발자 모드 확인 ===" -ForegroundColor Cyan
Write-Host ""

try {
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
    $regName = "AllowDevelopmentWithoutDevLicense"
    
    if (Test-Path $regPath) {
        $value = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
        
        if ($value -and $value.$regName -eq 1) {
            Write-Host "✅ 개발자 모드: 활성화됨" -ForegroundColor Green
            Write-Host ""
            Write-Host "MSIX 설치를 진행할 수 있습니다!" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "❌ 개발자 모드: 비활성화됨" -ForegroundColor Red
            Write-Host ""
            Write-Host "개발자 모드를 활성화해야 MSIX 설치가 가능합니다." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "활성화 방법:" -ForegroundColor Yellow
            Write-Host "  Windows 11:" -ForegroundColor White
            Write-Host "    설정 → 개인정보 보호 및 보안 → 개발자용 → 개발자 모드 토글 켜기" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  Windows 10:" -ForegroundColor White
            Write-Host "    설정 → 업데이트 및 보안 → 개발자용 → 개발자 모드 선택" -ForegroundColor Gray
            Write-Host ""
            Write-Host "활성화 후 이 스크립트를 다시 실행하여 확인하세요." -ForegroundColor Yellow
            exit 1
        }
    } else {
        Write-Host "❌ 개발자 모드: 비활성화됨 (레지스트리 키 없음)" -ForegroundColor Red
        Write-Host ""
        Write-Host "개발자 모드를 활성화해야 MSIX 설치가 가능합니다." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "활성화 방법:" -ForegroundColor Yellow
        Write-Host "  Windows 11:" -ForegroundColor White
        Write-Host "    설정 → 개인정보 보호 및 보안 → 개발자용 → 개발자 모드 토글 켜기" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Windows 10:" -ForegroundColor White
        Write-Host "    설정 → 업데이트 및 보안 → 개발자용 → 개발자 모드 선택" -ForegroundColor Gray
        exit 1
    }
} catch {
    Write-Host "❌ 확인 중 오류 발생: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "수동 확인 방법:" -ForegroundColor Yellow
    Write-Host "  Windows 설정에서 개발자 모드를 확인하세요." -ForegroundColor White
    exit 1
}

