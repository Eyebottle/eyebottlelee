# MS Store 제출용 스크린샷 자동 캡처 스크립트
# 사용법: PowerShell에서 실행 (관리자 권한 불필요)

param(
    [string]$OutputDir = "screenshots"
)

# .NET 어셈블리 로드
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 출력 디렉토리 절대 경로 설정
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$outputPath = Join-Path $projectRoot $OutputDir

# 디렉토리 생성
if (-not (Test-Path $outputPath)) {
    New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
}

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "MS Store 스크린샷 자동 캡처 도구" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "저장 위치: $outputPath" -ForegroundColor Yellow
Write-Host ""

# 활성 창 캡처 함수
function Capture-ActiveWindow {
    param(
        [string]$filename,
        [string]$outputPath
    )

    # 활성 창 핸들 가져오기
    Add-Type @"
        using System;
        using System.Runtime.InteropServices;
        public class Win32 {
            [DllImport("user32.dll")]
            public static extern IntPtr GetForegroundWindow();

            [DllImport("user32.dll")]
            public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

            [StructLayout(LayoutKind.Sequential)]
            public struct RECT {
                public int Left;
                public int Top;
                public int Right;
                public int Bottom;
            }
        }
"@

    $hwnd = [Win32]::GetForegroundWindow()
    $rect = New-Object Win32+RECT
    [Win32]::GetWindowRect($hwnd, [ref]$rect) | Out-Null

    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    $x = $rect.Left
    $y = $rect.Top

    # 비트맵 생성 및 캡처
    $bitmap = New-Object System.Drawing.Bitmap $width, $height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($x, $y, 0, 0, $bitmap.Size)

    # 파일 저장
    $fullPath = Join-Path $outputPath $filename
    $bitmap.Save($fullPath, [System.Drawing.Imaging.ImageFormat]::Png)

    # 정리
    $graphics.Dispose()
    $bitmap.Dispose()

    Write-Host "✓ 캡처 완료: $filename" -ForegroundColor Green

    # 파일 크기 확인
    $fileSize = (Get-Item $fullPath).Length / 1MB
    Write-Host "  파일 크기: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Gray
}

# 메인 캡처 프로세스
Write-Host "준비 단계:" -ForegroundColor Yellow
Write-Host "1. medical_recorder.exe 앱을 실행하세요" -ForegroundColor White
Write-Host "2. 창을 최대화하거나 적절한 크기로 조정하세요" -ForegroundColor White
Write-Host "3. 진료 시간표를 미리 설정하세요" -ForegroundColor White
Write-Host "4. 자동 실행 프로그램 2-3개를 등록하세요" -ForegroundColor White
Write-Host ""
Write-Host "준비되면 아무 키나 누르세요..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "스크린샷 캡처 시작" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Screenshot 1: Dashboard
Write-Host "[1/5] 대시보드 화면" -ForegroundColor Yellow
Write-Host "  - '대시보드' 탭을 선택하세요" -ForegroundColor White
Write-Host "  - 녹음을 시작하여 볼륨 미터가 보이게 하세요" -ForegroundColor White
Write-Host "  - 앱 창을 활성화한 후 아무 키나 누르세요..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Start-Sleep -Milliseconds 500
Capture-ActiveWindow -filename "screenshot-1-dashboard.png" -outputPath $outputPath
Write-Host ""

# Screenshot 2: Schedule
Write-Host "[2/5] 진료 시간표 화면" -ForegroundColor Yellow
Write-Host "  - '녹음 설정' 탭을 선택하세요" -ForegroundColor White
Write-Host "  - 주간 캘린더가 보이는지 확인하세요" -ForegroundColor White
Write-Host "  - 앱 창을 활성화한 후 아무 키나 누르세요..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Start-Sleep -Milliseconds 500
Capture-ActiveWindow -filename "screenshot-2-schedule.png" -outputPath $outputPath
Write-Host ""

# Screenshot 3: Advanced Settings
Write-Host "[3/5] 고급 설정 다이얼로그" -ForegroundColor Yellow
Write-Host "  - '고급 설정' 버튼을 클릭하세요" -ForegroundColor White
Write-Host "  - 다이얼로그가 열린 상태에서" -ForegroundColor White
Write-Host "  - 앱 창을 활성화한 후 아무 키나 누르세요..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Start-Sleep -Milliseconds 500
Capture-ActiveWindow -filename "screenshot-3-advanced-settings.png" -outputPath $outputPath
Write-Host ""
Write-Host "  - 다이얼로그를 닫으세요 (계속하려면 아무 키)" -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Screenshot 4: Auto Launch
Write-Host "[4/5] 자동 실행 화면" -ForegroundColor Yellow
Write-Host "  - '자동 실행' 탭을 선택하세요" -ForegroundColor White
Write-Host "  - 프로그램 목록이 보이는지 확인하세요" -ForegroundColor White
Write-Host "  - 앱 창을 활성화한 후 아무 키나 누르세요..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Start-Sleep -Milliseconds 500
Capture-ActiveWindow -filename "screenshot-4-auto-launch.png" -outputPath $outputPath
Write-Host ""

# Screenshot 5: Help
Write-Host "[5/5] 도움말 센터" -ForegroundColor Yellow
Write-Host "  - '?' (도움말) 버튼을 클릭하세요" -ForegroundColor White
Write-Host "  - 도움말 다이얼로그가 열린 상태에서" -ForegroundColor White
Write-Host "  - 앱 창을 활성화한 후 아무 키나 누르세요..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Start-Sleep -Milliseconds 500
Capture-ActiveWindow -filename "screenshot-5-help.png" -outputPath $outputPath
Write-Host ""

# 완료 메시지
Write-Host "==================================" -ForegroundColor Green
Write-Host "스크린샷 캡처 완료!" -ForegroundColor Green
Write-Host "==================================" -ForegroundColor Green
Write-Host ""
Write-Host "저장된 파일:" -ForegroundColor Yellow
Get-ChildItem $outputPath -Filter "screenshot-*.png" | ForEach-Object {
    $size = [math]::Round($_.Length / 1MB, 2)
    Write-Host "  ✓ $($_.Name) ($size MB)" -ForegroundColor Green
}
Write-Host ""
Write-Host "총 파일 수: $((Get-ChildItem $outputPath -Filter 'screenshot-*.png').Count)" -ForegroundColor Cyan
Write-Host "저장 위치: $outputPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "다음 단계: MS Store Partner Center에 업로드" -ForegroundColor Yellow
