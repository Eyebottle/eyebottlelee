# 저장기간 정리 기능 테스트 스크립트
# 용도: 2주 전 날짜의 더미 녹음 파일을 생성하여 저장기간 자동 정리 기능을 테스트합니다.

param(
    [string]$RecordingPath = "$env:USERPROFILE\OneDrive\진료녹음",
    [int]$DaysAgo = 14
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "저장기간 정리 기능 테스트 - 더미 파일 생성" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 저장 경로 확인
if (-not (Test-Path $RecordingPath)) {
    Write-Host "⚠️  녹음 저장 폴더가 없습니다: $RecordingPath" -ForegroundColor Yellow
    Write-Host "기본 폴더를 생성합니다..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $RecordingPath -Force | Out-Null
}

Write-Host "📂 녹음 저장 경로: $RecordingPath" -ForegroundColor Green
Write-Host "📅 더미 파일 날짜: $DaysAgo일 전" -ForegroundColor Green
Write-Host ""

# 테스트용 날짜 설정
$oldDate = (Get-Date).AddDays(-$DaysAgo)
$folderName = $oldDate.ToString('yyyy-MM-dd')
$testFolder = Join-Path $RecordingPath $folderName

# 테스트 폴더 생성
Write-Host "📁 테스트 폴더 생성 중..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $testFolder -Force | Out-Null

# 더미 녹음 파일 3개 생성
Write-Host "🎵 더미 녹음 파일 생성 중..." -ForegroundColor Cyan
Write-Host ""

$fileCount = 3
1..$fileCount | ForEach-Object {
    $timestamp = $oldDate.AddHours($_ * 2).ToString('HHmmss')
    $fileName = "rec_${folderName}_${timestamp}.m4a"
    $filePath = Join-Path $testFolder $fileName

    # 더미 데이터 생성 (실제 오디오 파일처럼 보이게)
    $dummyData = "DUMMY AUDIO FILE - TEST DATA FOR RETENTION CLEANUP" * 1000
    [System.IO.File]::WriteAllText($filePath, $dummyData)

    # 파일 수정 시간을 과거로 변경
    $file = Get-Item $filePath
    $file.LastWriteTime = $oldDate.AddHours($_ * 2)
    $file.CreationTime = $oldDate.AddHours($_ * 2)

    $fileSize = [math]::Round($file.Length / 1KB, 2)
    Write-Host "  ✅ $fileName" -ForegroundColor Green
    Write-Host "     크기: ${fileSize} KB | 수정일: $($file.LastWriteTime)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✅ 테스트 준비 완료!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 다음 단계:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. 아이보틀 진료 녹음 앱 실행" -ForegroundColor White
Write-Host ""
Write-Host "  2. 설정 탭 > '녹음 파일 보관 기간' 클릭" -ForegroundColor White
Write-Host ""
Write-Host "  3. '1주일' 선택 후 '저장' 버튼 클릭" -ForegroundColor White
Write-Host ""
Write-Host "  4. 대시보드 탭 > '녹음 시작' 버튼 클릭" -ForegroundColor White
Write-Host "     (또는 '녹음 중지' 버튼 - 이미 녹음 중이면)" -ForegroundColor Gray
Write-Host ""
Write-Host "  5. 로그 확인:" -ForegroundColor White
Write-Host "     - '보관기간 경과 파일 삭제' 메시지 확인" -ForegroundColor Gray
Write-Host ""
Write-Host "  6. 파일 탐색기로 확인:" -ForegroundColor White
Write-Host "     - 경로: $testFolder" -ForegroundColor Gray
Write-Host "     - 폴더가 삭제되었으면 ✅ 테스트 성공!" -ForegroundColor Gray
Write-Host "     - 파일이 남아있으면 ❌ 테스트 실패 (로그 확인 필요)" -ForegroundColor Gray
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
