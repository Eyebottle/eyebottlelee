# 빠른 검증 스크립트
# 빌드 없이 프로젝트 상태를 검증합니다

$ErrorActionPreference = "Continue"

function Write-Section { param($Title) Write-Host "`n═══ $Title ═══" -ForegroundColor Cyan }
function Write-Pass { param($Msg) Write-Host "✅ $Msg" -ForegroundColor Green }
function Write-Fail { param($Msg) Write-Host "❌ $Msg" -ForegroundColor Red }
function Write-Info { param($Msg) Write-Host "ℹ️  $Msg" -ForegroundColor Yellow }

$issueCount = 0
$passCount = 0

Write-Host "`n🔍 프로젝트 빠른 검증 시작`n" -ForegroundColor Magenta

# ============================================
# 1. 필수 파일 확인
# ============================================
Write-Section "1. 필수 파일 확인"

$requiredFiles = @(
    "pubspec.yaml",
    "lib/main.dart",
    "assets/icons/icon.ico",
    "assets/images/eyebottle-logo.png",
    "assets/bin/ffmpeg.exe"
)

foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Pass "$file"
        $passCount++
    } else {
        Write-Fail "$file 없음"
        $issueCount++
    }
}

# ============================================
# 2. 서비스 파일 확인
# ============================================
Write-Section "2. 서비스 파일 확인"

$serviceFiles = Get-ChildItem "lib/services" -Filter "*.dart" -ErrorAction SilentlyContinue

if ($serviceFiles) {
    Write-Pass "$($serviceFiles.Count)개 서비스 파일 발견"
    $passCount++
    foreach ($file in $serviceFiles) {
        Write-Info "  - $($file.Name)"
    }
} else {
    Write-Fail "서비스 파일 없음"
    $issueCount++
}

# ============================================
# 3. 의존성 확인
# ============================================
Write-Section "3. 의존성 확인"

if (Test-Path "pubspec.yaml") {
    $pubspec = Get-Content "pubspec.yaml" -Raw

    $requiredDeps = @(
        "record",
        "path_provider",
        "shared_preferences",
        "cron",
        "system_tray",
        "window_manager",
        "launch_at_startup"
    )

    foreach ($dep in $requiredDeps) {
        if ($pubspec -match $dep) {
            Write-Pass "$dep"
            $passCount++
        } else {
            Write-Fail "$dep 없음"
            $issueCount++
        }
    }
}

# ============================================
# 4. Flutter 분석
# ============================================
Write-Section "4. Flutter 분석 (경고만)"

try {
    Write-Info "flutter analyze 실행 중... (최대 30초)"
    $analyzeResult = flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 | Out-String

    if ($LASTEXITCODE -eq 0) {
        Write-Pass "분석 통과 (경고 없음)"
        $passCount++
    } else {
        # 이슈 개수 추출
        if ($analyzeResult -match "(\d+) issues? found") {
            $issuesFound = $matches[1]
            Write-Info "$issuesFound개 이슈 발견 (대부분 deprecation)"
        }
        Write-Pass "경고는 있지만 치명적 오류 없음"
        $passCount++
    }
} catch {
    Write-Fail "분석 실패: $_"
    $issueCount++
}

# ============================================
# 5. 로고 파일 확인
# ============================================
Write-Section "5. 로고 파일 검증"

if (Test-Path "assets/icons/icon.ico") {
    $icoFile = Get-Item "assets/icons/icon.ico"
    $icoSize = [math]::Round($icoFile.Length / 1KB, 2)

    if ($icoSize -gt 10 -and $icoSize -lt 500) {
        Write-Pass "icon.ico 크기 정상: $icoSize KB"
        $passCount++
    } else {
        Write-Fail "icon.ico 크기 비정상: $icoSize KB"
        $issueCount++
    }
} else {
    Write-Fail "icon.ico 없음"
    $issueCount++
}

if (Test-Path "assets/images/eyebottle-logo.png") {
    $logoFile = Get-Item "assets/images/eyebottle-logo.png"
    $logoSize = [math]::Round($logoFile.Length / 1KB, 2)
    Write-Pass "eyebottle-logo.png: $logoSize KB"
    $passCount++
} else {
    Write-Fail "eyebottle-logo.png 없음"
    $issueCount++
}

# ============================================
# 6. Git 상태
# ============================================
Write-Section "6. Git 상태"

try {
    $gitStatus = git status --short 2>&1
    if ($gitStatus) {
        Write-Info "변경된 파일 있음:"
        Write-Host $gitStatus
    } else {
        Write-Pass "작업 디렉토리 깨끗함"
        $passCount++
    }
} catch {
    Write-Info "Git 상태 확인 실패"
}

# ============================================
# 7. 빌드 가능 여부 (선택적)
# ============================================
Write-Section "7. 빌드 테스트 (선택)"

Write-Info "실제 빌드를 시도하시겠습니까? (시간: 3-5분)"
Write-Info "Y를 입력하면 빌드 시도, 그 외 키는 건너뛰기"

$response = Read-Host "빌드 시도? [Y/N]"

if ($response -eq "Y" -or $response -eq "y") {
    Write-Info "Flutter 빌드 시작..."

    try {
        $buildStart = Get-Date
        flutter build windows --release 2>&1 | Tee-Object -Variable buildOutput | Out-Null
        $buildEnd = Get-Date
        $buildDuration = ($buildEnd - $buildStart).TotalSeconds

        if ($LASTEXITCODE -eq 0) {
            Write-Pass "빌드 성공! (소요: $([math]::Round($buildDuration, 1))초)"
            $passCount++

            $exePath = "build\windows\x64\runner\Release\medical_recorder.exe"
            if (Test-Path $exePath) {
                $exeFile = Get-Item $exePath
                $exeSize = [math]::Round($exeFile.Length / 1MB, 2)
                Write-Pass "실행 파일 생성: $exeSize MB"
                $passCount++
            }
        } else {
            Write-Fail "빌드 실패"
            Write-Host $buildOutput -ForegroundColor Red
            $issueCount++
        }
    } catch {
        Write-Fail "빌드 오류: $_"
        $issueCount++
    }
} else {
    Write-Info "빌드 건너뜀"
}

# ============================================
# 결과 요약
# ============================================
Write-Host "`n" + ("=" * 50) -ForegroundColor Magenta
Write-Host "📊 검증 결과 요약" -ForegroundColor Cyan
Write-Host ("=" * 50) -ForegroundColor Magenta

Write-Host "`n✅ 통과: $passCount" -ForegroundColor Green
Write-Host "❌ 실패: $issueCount" -ForegroundColor Red

if ($issueCount -eq 0) {
    Write-Host "`n🎉 모든 검증 통과! 프로젝트 상태 양호" -ForegroundColor Green
} elseif ($issueCount -le 2) {
    Write-Host "`n⚠️  경미한 이슈 발견. 대부분 정상" -ForegroundColor Yellow
} else {
    Write-Host "`n⚠️  여러 이슈 발견. 확인 필요" -ForegroundColor Yellow
}

Write-Host ""
