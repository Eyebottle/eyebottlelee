@echo off
REM MS Store 스크린샷 자동 캡처 실행 파일
REM 이 파일을 더블클릭하면 스크린샷 캡처가 시작됩니다

echo ========================================
echo MS Store 스크린샷 캡처 도구
echo ========================================
echo.

REM PowerShell 스크립트 실행
powershell.exe -ExecutionPolicy Bypass -File "%~dp0capture-screenshots.ps1"

echo.
echo ========================================
echo 완료! 아무 키나 누르면 종료합니다.
echo ========================================
pause
