# v1.3.14 테스트 스크립트
# 앱을 실행하고 5초 후 프로세스 상태를 확인합니다.

Write-Host "=== v1.3.14 Launch Test ===" -ForegroundColor Cyan
Write-Host ""

# 이미 실행 중이면 종료
$existing = Get-Process -Name "medical_recorder" -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "기존 프로세스 종료 중..." -ForegroundColor Yellow
    $existing | Stop-Process -Force
    Start-Sleep -Seconds 2
}

# 앱 실행 (--autostart 없이 = 사용자 수동 실행 시뮬레이션)
Write-Host "[TEST 1] 수동 실행 테스트 (--autostart 없음)" -ForegroundColor Green
$proc = Start-Process "C:\ws-workspace\eyebottlelee\build\windows\x64\runner\Release\medical_recorder.exe" -PassThru
Write-Host "  PID: $($proc.Id)"

Start-Sleep -Seconds 5

# 프로세스 확인
$check = Get-Process -Name "medical_recorder" -ErrorAction SilentlyContinue
if ($check) {
    Write-Host "  [OK] 프로세스 살아있음 (PID: $($check.Id))" -ForegroundColor Green
    
    if ($check.MainWindowHandle -ne 0) {
        Write-Host "  [OK] 메인 윈도우 핸들 있음 (창이 표시됨)" -ForegroundColor Green
        Write-Host "  MainWindowTitle: '$($check.MainWindowTitle)'" 
    } else {
        Write-Host "  [WARN] 메인 윈도우 핸들 없음 (창이 숨겨져 있을 수 있음)" -ForegroundColor Yellow
    }
    
    Write-Host "  Responding: $($check.Responding)"
} else {
    Write-Host "  [FAIL] 프로세스가 종료되었습니다!" -ForegroundColor Red
}

Write-Host ""
Write-Host "--- 5초 후 프로세스 종료 ---"
Start-Sleep -Seconds 5

# 정리
$cleanup = Get-Process -Name "medical_recorder" -ErrorAction SilentlyContinue
if ($cleanup) {
    $cleanup | Stop-Process -Force
    Write-Host "프로세스 종료 완료"
}

Write-Host ""
Write-Host "=== 테스트 완료 ===" -ForegroundColor Cyan
