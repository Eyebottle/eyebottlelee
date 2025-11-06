# Phase 2 자동화 테스트 스크립트
# 설명: 주요 기능을 자동으로 테스트하고 결과를 리포트합니다

param(
    [int]$RecordingDurationSeconds = 120,  # 기본 녹음 시간 (2분)
    [string]$OutputDir = "test-results"
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# 색상 출력 함수
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }
function Write-Section { param($Message) Write-Host "`n═══════════════════════════════════════" -ForegroundColor Magenta; Write-Host "  $Message" -ForegroundColor Magenta; Write-Host "═══════════════════════════════════════`n" -ForegroundColor Magenta }

# 결과 저장용 변수
$TestResults = @{
    StartTime = Get-Date
    SystemInfo = @{}
    Tests = @()
    Issues = @()
}

# ============================================
# 1. 시스템 정보 수집
# ============================================
Write-Section "1. 시스템 정보 수집"

try {
    $osInfo = Get-CimInstance Win32_OperatingSystem
    $cpuInfo = Get-CimInstance Win32_Processor
    $memInfo = Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum

    $TestResults.SystemInfo = @{
        OS = "$($osInfo.Caption) (Build $($osInfo.BuildNumber))"
        CPU = $cpuInfo.Name
        RAM = "{0:N2} GB" -f ($memInfo.Sum / 1GB)
        Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    Write-Success "Windows: $($TestResults.SystemInfo.OS)"
    Write-Success "CPU: $($TestResults.SystemInfo.CPU)"
    Write-Success "RAM: $($TestResults.SystemInfo.RAM)"
} catch {
    Write-Error "시스템 정보 수집 실패: $_"
    $TestResults.Issues += "시스템 정보 수집 실패"
}

# ============================================
# 2. 빌드 디렉토리 확인
# ============================================
Write-Section "2. 빌드 확인"

$buildPath = "build\windows\x64\runner\Release\medical_recorder.exe"

if (Test-Path $buildPath) {
    Write-Success "빌드 파일 존재: $buildPath"
    $exeInfo = Get-Item $buildPath
    Write-Info "파일 크기: $([math]::Round($exeInfo.Length / 1MB, 2)) MB"
    Write-Info "수정 날짜: $($exeInfo.LastWriteTime)"
} else {
    Write-Warning "빌드 파일 없음. Release 빌드 실행 중..."

    try {
        $buildOutput = flutter build windows --release 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "빌드 완료"
        } else {
            Write-Error "빌드 실패"
            Write-Host $buildOutput
            $TestResults.Issues += "빌드 실패"
            exit 1
        }
    } catch {
        Write-Error "빌드 중 오류: $_"
        $TestResults.Issues += "빌드 오류: $_"
        exit 1
    }
}

# ============================================
# 3. 저장 폴더 준비
# ============================================
Write-Section "3. 테스트 환경 준비"

$testSaveFolder = Join-Path $env:TEMP "eyebottlelee-test-recordings"
if (Test-Path $testSaveFolder) {
    Write-Info "기존 테스트 폴더 정리 중..."
    Remove-Item $testSaveFolder -Recurse -Force
}
New-Item -ItemType Directory -Path $testSaveFolder -Force | Out-Null
Write-Success "테스트 저장 폴더: $testSaveFolder"

# ============================================
# 4. 앱 실행
# ============================================
Write-Section "4. 앱 실행"

Write-Info "앱 실행 중... (창이 나타날 때까지 대기)"
$process = Start-Process -FilePath $buildPath -PassThru -WindowStyle Normal

if ($process) {
    Write-Success "앱 실행됨 (PID: $($process.Id))"
    Start-Sleep -Seconds 5  # 앱 초기화 대기
} else {
    Write-Error "앱 실행 실패"
    $TestResults.Issues += "앱 실행 실패"
    exit 1
}

# ============================================
# 5. 초기 메모리/CPU 측정
# ============================================
Write-Section "5. 초기 성능 측정"

Start-Sleep -Seconds 3

try {
    $proc = Get-Process -Id $process.Id -ErrorAction Stop
    $initialMemoryMB = [math]::Round($proc.WorkingSet64 / 1MB, 2)
    $initialCPU = $proc.CPU

    Write-Success "초기 메모리: $initialMemoryMB MB"
    Write-Info "프로세스 시작 시간: $($proc.StartTime)"

    $TestResults.Tests += @{
        Name = "초기 메모리"
        Value = "$initialMemoryMB MB"
        Status = if ($initialMemoryMB -lt 300) { "Pass" } else { "Warning" }
    }
} catch {
    Write-Warning "프로세스 정보 가져오기 실패: $_"
}

# ============================================
# 6. 녹음 테스트 안내
# ============================================
Write-Section "6. 수동 작업 필요"

Write-Host @"
🎙️  다음 단계를 수행해주세요:

1. 앱 창에서 '녹음 시작' 버튼 클릭
2. $RecordingDurationSeconds 초 동안 대기 (타이머가 자동으로 측정합니다)
3. 녹음이 자동으로 중지될 때까지 대기

📝 확인 사항:
   - 볼륨 미터가 반응하는지
   - 녹음 시간이 표시되는지
   - 오류 메시지가 없는지

아무 키나 눌러서 녹음을 시작했다고 알려주세요...
"@ -ForegroundColor Yellow

$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Write-Info "녹음 모니터링 시작..."

$recordingStartTime = Get-Date

# ============================================
# 7. 녹음 중 성능 모니터링
# ============================================
Write-Section "7. 녹음 중 모니터링 ($RecordingDurationSeconds초)"

$measurements = @()
$checkInterval = 10  # 10초마다 체크

for ($i = 0; $i -lt $RecordingDurationSeconds; $i += $checkInterval) {
    Start-Sleep -Seconds $checkInterval

    try {
        $proc = Get-Process -Id $process.Id -ErrorAction Stop
        $memoryMB = [math]::Round($proc.WorkingSet64 / 1MB, 2)
        $cpuPercent = [math]::Round(($proc.CPU / ((Get-Date) - $proc.StartTime).TotalSeconds) * 100 / $env:NUMBER_OF_PROCESSORS, 2)

        $measurements += @{
            Time = $i + $checkInterval
            MemoryMB = $memoryMB
            CPU = $cpuPercent
        }

        Write-Info "$($i + $checkInterval)초: 메모리 = $memoryMB MB, CPU = $cpuPercent%"
    } catch {
        Write-Warning "프로세스가 종료되었거나 측정 실패"
        break
    }
}

Write-Host "`n녹음 중지를 눌러주세요. 완료 후 아무 키나 누르세요..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# ============================================
# 8. 파일 생성 확인
# ============================================
Write-Section "8. 파일 생성 확인"

Write-Info "사용자 문서 폴더에서 녹음 파일 검색 중..."
Write-Info "(기본 경로 또는 설정된 저장 위치)"

Start-Sleep -Seconds 5  # WAV → AAC 변환 대기

# 가능한 저장 경로들
$possiblePaths = @(
    (Join-Path $env:APPDATA "EyebottleRecorder"),
    (Join-Path $env:USERPROFILE "OneDrive\진료녹음"),
    (Join-Path ([Environment]::GetFolderPath('MyDocuments')) "EyebottleRecorder")
)

$foundFiles = @()

foreach ($basePath in $possiblePaths) {
    if (Test-Path $basePath) {
        Write-Info "경로 확인: $basePath"
        $files = Get-ChildItem -Path $basePath -Recurse -Include *.m4a,*.opus,*.wav -ErrorAction SilentlyContinue

        foreach ($file in $files) {
            # 방금 생성된 파일만 확인 (최근 5분 이내)
            if ($file.LastWriteTime -gt (Get-Date).AddMinutes(-5)) {
                $foundFiles += $file
                Write-Success "발견: $($file.Name)"
                Write-Info "  크기: $([math]::Round($file.Length / 1MB, 2)) MB"
                Write-Info "  경로: $($file.DirectoryName)"
            }
        }
    }
}

if ($foundFiles.Count -gt 0) {
    Write-Success "총 $($foundFiles.Count)개 파일 생성 확인"

    # AAC/Opus 변환 확인
    $convertedFiles = $foundFiles | Where-Object { $_.Extension -in @('.m4a', '.opus') }
    $wavFiles = $foundFiles | Where-Object { $_.Extension -eq '.wav' }

    if ($convertedFiles.Count -gt 0) {
        Write-Success "WAV → AAC/Opus 변환 성공 ($($convertedFiles.Count)개)"
    }

    if ($wavFiles.Count -gt 0) {
        Write-Warning "WAV 파일이 남아있음 ($($wavFiles.Count)개)"
        Write-Info "변환 대기 중이거나 변환 실패일 수 있습니다"
    }

    $TestResults.Tests += @{
        Name = "파일 생성"
        Value = "$($foundFiles.Count)개 파일"
        Status = "Pass"
    }

    $TestResults.Tests += @{
        Name = "WAV 변환"
        Value = "$($convertedFiles.Count)개 변환됨"
        Status = if ($wavFiles.Count -eq 0) { "Pass" } else { "Warning" }
    }
} else {
    Write-Error "녹음 파일을 찾을 수 없습니다"
    $TestResults.Issues += "녹음 파일 미생성"
}

# ============================================
# 9. 최종 성능 측정
# ============================================
Write-Section "9. 최종 성능 측정"

try {
    $proc = Get-Process -Id $process.Id -ErrorAction Stop
    $finalMemoryMB = [math]::Round($proc.WorkingSet64 / 1MB, 2)
    $memoryIncrease = $finalMemoryMB - $initialMemoryMB

    Write-Success "최종 메모리: $finalMemoryMB MB"
    Write-Info "메모리 증가: $memoryIncrease MB"

    if ($memoryIncrease -gt 50) {
        Write-Warning "메모리 증가량이 큽니다 (50MB 이상)"
        $TestResults.Issues += "메모리 증가 과다: $memoryIncrease MB"
    }

    $TestResults.Tests += @{
        Name = "메모리 누수 체크"
        Value = "$memoryIncrease MB 증가"
        Status = if ($memoryIncrease -lt 50) { "Pass" } else { "Warning" }
    }
} catch {
    Write-Warning "최종 측정 실패"
}

# 평균 CPU 계산
if ($measurements.Count -gt 0) {
    $avgCPU = ($measurements | Measure-Object -Property CPU -Average).Average
    Write-Info "평균 CPU 사용량: $([math]::Round($avgCPU, 2))%"

    $TestResults.Tests += @{
        Name = "평균 CPU"
        Value = "$([math]::Round($avgCPU, 2))%"
        Status = if ($avgCPU -lt 10) { "Pass" } else { "Warning" }
    }
}

# ============================================
# 10. 앱 종료
# ============================================
Write-Section "10. 앱 종료"

try {
    if (!$process.HasExited) {
        Write-Info "앱을 정상 종료 중..."
        $process.CloseMainWindow() | Out-Null
        Start-Sleep -Seconds 3

        if (!$process.HasExited) {
            Write-Warning "정상 종료 실패. 강제 종료합니다..."
            $process.Kill()
        }
    }
    Write-Success "앱 종료 완료"
} catch {
    Write-Warning "앱 종료 중 오류: $_"
}

# ============================================
# 11. 결과 리포트 생성
# ============================================
Write-Section "11. 결과 리포트"

$TestResults.EndTime = Get-Date
$TestResults.Duration = ($TestResults.EndTime - $TestResults.StartTime).ToString("hh\:mm\:ss")

# 콘솔 출력
Write-Host "`n📊 테스트 요약`n" -ForegroundColor Cyan

Write-Host "시스템 정보:" -ForegroundColor White
Write-Host "  OS: $($TestResults.SystemInfo.OS)"
Write-Host "  CPU: $($TestResults.SystemInfo.CPU)"
Write-Host "  RAM: $($TestResults.SystemInfo.RAM)"
Write-Host ""

Write-Host "테스트 결과:" -ForegroundColor White
foreach ($test in $TestResults.Tests) {
    $color = switch ($test.Status) {
        "Pass" { "Green" }
        "Warning" { "Yellow" }
        "Fail" { "Red" }
        default { "White" }
    }
    $icon = switch ($test.Status) {
        "Pass" { "✅" }
        "Warning" { "⚠️" }
        "Fail" { "❌" }
        default { "ℹ️" }
    }
    Write-Host "  $icon $($test.Name): $($test.Value)" -ForegroundColor $color
}

if ($TestResults.Issues.Count -gt 0) {
    Write-Host "`n발견된 이슈:" -ForegroundColor Red
    foreach ($issue in $TestResults.Issues) {
        Write-Host "  - $issue" -ForegroundColor Red
    }
} else {
    Write-Host "`n✅ 이슈 없음" -ForegroundColor Green
}

Write-Host "`n테스트 소요 시간: $($TestResults.Duration)`n" -ForegroundColor Cyan

# JSON 파일로 저장
$outputPath = "test-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$TestResults | ConvertTo-Json -Depth 10 | Out-File $outputPath -Encoding UTF8
Write-Success "결과 저장: $outputPath"

# ============================================
# 12. 수동 테스트 안내
# ============================================
Write-Section "12. 다음 단계: 수동 테스트"

Write-Host @"
🔍 다음 항목들은 직접 확인이 필요합니다:

✋ UI 테스트:
   - 볼륨 미터 반응 확인
   - 버튼 클릭 반응
   - 다이얼로그 표시

🎵 음질 테스트:
   - 녹음 파일 재생
   - 음질 확인
   - 잡음 여부 확인

⚙️ 고급 기능:
   - 시간표 설정 및 자동 녹음
   - 자동 실행 매니저
   - 시스템 트레이 메뉴
   - 도움말 및 튜토리얼

📋 자세한 내용은 docs/test-checklist-phase2.md 참조

"@ -ForegroundColor Yellow

Write-Host "`n테스트가 완료되었습니다! 🎉`n" -ForegroundColor Green
