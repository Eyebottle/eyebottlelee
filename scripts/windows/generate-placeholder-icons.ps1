# 아이보틀 진료 녹음 - 플레이스홀더 아이콘 생성 스크립트
# PowerShell에서 실행: .\scripts\windows\generate-placeholder-icons.ps1

Write-Host "=== 플레이스홀더 아이콘 생성 ===" -ForegroundColor Green
Write-Host "개발/테스트용 기본 아이콘 생성" -ForegroundColor Cyan

# ImageMagick 설치 확인
function Test-Command($cmdname) {
    return [bool](Get-Command -Name $cmdname -ErrorAction SilentlyContinue)
}

# 아이콘 폴더 경로
$iconPath = "assets\icons"

# 폴더 생성
if (-not (Test-Path $iconPath)) {
    New-Item -ItemType Directory -Path $iconPath -Force | Out-Null
    Write-Host "아이콘 폴더 생성: $iconPath" -ForegroundColor Yellow
}

# ImageMagick 확인
if (-not (Test-Command magick)) {
    Write-Host "ImageMagick이 설치되지 않았습니다." -ForegroundColor Red
    Write-Host "간단한 텍스트 기반 ICO 파일을 생성합니다..." -ForegroundColor Yellow

    # 기본 텍스트 플레이스홀더 생성
    $placeholderContent = @"
; 플레이스홀더 아이콘 파일
; 실제 배포 전에 적절한 ICO 파일로 교체해주세요.

이 파일은 개발용 플레이스홀더입니다.
Windows ICO 형식의 실제 아이콘이 필요합니다.
"@

    # 각 아이콘 파일 생성
    @("icon.ico", "tray_recording.ico", "tray_waiting.ico", "tray_error.ico") | ForEach-Object {
        $filePath = Join-Path $iconPath $_
        $placeholderContent | Out-File -FilePath $filePath -Encoding UTF8
        Write-Host "생성됨: $filePath (텍스트 플레이스홀더)" -ForegroundColor Gray
    }

    Write-Host "`n⚠ 주의사항:" -ForegroundColor Yellow
    Write-Host "- 생성된 파일들은 텍스트 플레이스홀더입니다" -ForegroundColor White
    Write-Host "- 실제 빌드/배포 전에 적절한 ICO 파일로 교체해야 합니다" -ForegroundColor White
    Write-Host "- msix 패키징 시 실제 아이콘이 필요합니다" -ForegroundColor White

} else {
    Write-Host "ImageMagick 발견! 실제 아이콘 생성 중..." -ForegroundColor Green

    # 메인 앱 아이콘 (파란색, 마이크 심볼)
    $mainIconCmd = @"
magick -size 256x256 xc:blue -fill white -font Arial -pointsize 120 -gravity center -annotate +0+0 "🎤" "$iconPath\icon.ico"
"@

    # 녹음 중 트레이 아이콘 (빨간색)
    $recordingIconCmd = @"
magick -size 64x64 xc:red -fill white -font Arial -pointsize 32 -gravity center -annotate +0+0 "●" "$iconPath\tray_recording.ico"
"@

    # 대기 중 트레이 아이콘 (초록색)
    $waitingIconCmd = @"
magick -size 64x64 xc:green -fill white -font Arial -pointsize 32 -gravity center -annotate +0+0 "⏸" "$iconPath\tray_waiting.ico"
"@

    # 오류 상태 트레이 아이콘 (노란색)
    $errorIconCmd = @"
magick -size 64x64 xc:yellow -fill black -font Arial -pointsize 32 -gravity center -annotate +0+0 "⚠" "$iconPath\tray_error.ico"
"@

    try {
        Invoke-Expression $mainIconCmd
        Write-Host "✓ 메인 아이콘 생성: icon.ico" -ForegroundColor Green

        Invoke-Expression $recordingIconCmd
        Write-Host "✓ 녹음 중 아이콘 생성: tray_recording.ico" -ForegroundColor Green

        Invoke-Expression $waitingIconCmd
        Write-Host "✓ 대기 중 아이콘 생성: tray_waiting.ico" -ForegroundColor Green

        Invoke-Expression $errorIconCmd
        Write-Host "✓ 오류 상태 아이콘 생성: tray_error.ico" -ForegroundColor Green

        Write-Host "`n✅ 모든 아이콘이 생성되었습니다!" -ForegroundColor Green

    } catch {
        Write-Error "아이콘 생성 중 오류: $_"
        Write-Host "수동으로 아이콘 파일들을 추가해주세요." -ForegroundColor Yellow
    }
}

# 생성된 파일 목록 표시
Write-Host "`n📁 생성된 아이콘 파일들:" -ForegroundColor Blue
Get-ChildItem $iconPath -Filter "*.ico" | ForEach-Object {
    $size = [math]::Round($_.Length / 1KB, 1)
    Write-Host "  $($_.Name) (${size} KB)" -ForegroundColor White
}

Write-Host "`n🔧 권장사항:" -ForegroundColor Yellow
Write-Host "- 전문적인 아이콘 제작 도구 사용 (예: Icon Workshop, GIMP)" -ForegroundColor White
Write-Host "- 멀티 해상도 지원 (16x16, 32x32, 48x48, 256x256)" -ForegroundColor White
Write-Host "- 의료/녹음 관련 심볼 사용" -ForegroundColor White
Write-Host "- 일관된 색상 스킴 적용" -ForegroundColor White

Write-Host "`n플레이스홀더 아이콘 생성 완료!" -ForegroundColor Green