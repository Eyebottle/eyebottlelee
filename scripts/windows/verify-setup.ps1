# 아이보틀 진료 녹음 - 개발 환경 검증 스크립트
# PowerShell에서 실행: .\scripts\windows\verify-setup.ps1

Write-Host "=== 아이보틀 진료 녹음 개발 환경 검증 ===" -ForegroundColor Green
Write-Host "Flutter Windows Desktop 환경 상태 확인" -ForegroundColor Cyan

# 표준 버전 정의
$ExpectedFlutterVersion = "3.35.3"

# 함수 정의
function Test-Command($cmdname) {
    return [bool](Get-Command -Name $cmdname -ErrorAction SilentlyContinue)
}

function Test-Path-Safe($path) {
    try {
        return Test-Path $path
    } catch {
        return $false
    }
}

function Get-VersionInfo($command, $versionArg = "--version") {
    try {
        $output = & $command $versionArg 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $output | Select-Object -First 1
        }
        return "버전 확인 실패"
    } catch {
        return "실행 실패"
    }
}

$allPassed = $true

# 1. Flutter SDK 검증
Write-Host "`n1. Flutter SDK 확인..." -ForegroundColor Blue
if (Test-Command flutter) {
    $flutterVersion = Get-VersionInfo "flutter"
    Write-Host "✓ Flutter 설치됨: $flutterVersion" -ForegroundColor Green

    # 버전 일치 여부 확인
    try {
        $joined = ($flutterVersion | Out-String)
        $m = [regex]::Match($joined, "\d+\.\d+\.\d+")
        if ($m.Success -and $m.Value -ne $ExpectedFlutterVersion) {
            Write-Host "⚠ Flutter 표준 버전과 불일치: 현재 $($m.Value), 표준 $ExpectedFlutterVersion" -ForegroundColor Yellow
            Write-Host "   표준으로 맞추기: .\\scripts\\windows\\setup-dev.ps1 -ForceFlutter -FlutterVersion $ExpectedFlutterVersion" -ForegroundColor Gray
            $allPassed = $false
        }
    } catch {}

    # Flutter Doctor 실행
    Write-Host "Flutter Doctor 실행 중..." -ForegroundColor Yellow
    & flutter doctor -v

    # Windows Desktop 활성화 확인
    $config = & flutter config 2>$null
    if ($config -match "enable-windows-desktop: true") {
        Write-Host "✓ Windows Desktop 활성화됨" -ForegroundColor Green
    } else {
        Write-Host "⚠ Windows Desktop 비활성화" -ForegroundColor Yellow
        Write-Host "실행: flutter config --enable-windows-desktop" -ForegroundColor Gray
        $allPassed = $false
    }
} else {
    Write-Host "❌ Flutter가 설치되지 않았거나 PATH에 없습니다" -ForegroundColor Red
    $allPassed = $false
}

# 2. Dart SDK 검증
Write-Host "`n2. Dart SDK 확인..." -ForegroundColor Blue
if (Test-Command dart) {
    $dartVersion = Get-VersionInfo "dart"
    Write-Host "✓ Dart 설치됨: $dartVersion" -ForegroundColor Green
} else {
    Write-Host "❌ Dart가 설치되지 않았거나 PATH에 없습니다" -ForegroundColor Red
    $allPassed = $false
}

# 3. Visual Studio Build Tools 검증
Write-Host "`n3. Visual Studio Build Tools 확인..." -ForegroundColor Blue
$vsPath = "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"
$vsBuildToolsPath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"

if ((Test-Path-Safe $vsPath) -or (Test-Path-Safe $vsBuildToolsPath)) {
    Write-Host "✓ Visual Studio Build Tools 설치됨" -ForegroundColor Green
} else {
    Write-Host "❌ Visual Studio Build Tools가 설치되지 않았습니다" -ForegroundColor Red
    Write-Host "C++ 워크로드가 포함된 Visual Studio 2022가 필요합니다" -ForegroundColor Gray
    $allPassed = $false
}

# 4. Android Studio 확인 (선택사항)
Write-Host "`n4. Android Studio 확인..." -ForegroundColor Blue
$studioPath1 = "${env:ProgramFiles}\Android\Android Studio\bin\studio64.exe"
$studioPath2 = "${env:LOCALAPPDATA}\Programs\Android Studio\bin\studio64.exe"

if ((Test-Path-Safe $studioPath1) -or (Test-Path-Safe $studioPath2)) {
    Write-Host "✓ Android Studio 설치됨" -ForegroundColor Green
} else {
    Write-Host "⚠ Android Studio가 설치되지 않았습니다 (권장사항)" -ForegroundColor Yellow
}

# 5. Git 확인
Write-Host "`n5. Git 확인..." -ForegroundColor Blue
if (Test-Command git) {
    $gitVersion = Get-VersionInfo "git"
    Write-Host "✓ Git 설치됨: $gitVersion" -ForegroundColor Green
} else {
    Write-Host "⚠ Git이 설치되지 않았습니다 (권장사항)" -ForegroundColor Yellow
}

# 6. WSL 프로젝트 경로 확인
Write-Host "`n6. WSL 프로젝트 경로 확인..." -ForegroundColor Blue
$wslProjectPath = "\\wsl$\Ubuntu\home\usereyebottle\projects\eyebottlelee"
if (Test-Path-Safe $wslProjectPath) {
    Write-Host "✓ WSL 프로젝트 경로 접근 가능: $wslProjectPath" -ForegroundColor Green

    # pubspec.yaml 존재 확인
    $pubspecPath = "$wslProjectPath\pubspec.yaml"
    if (Test-Path-Safe $pubspecPath) {
        Write-Host "✓ Flutter 프로젝트 구조 확인됨" -ForegroundColor Green
    } else {
        Write-Host "❌ pubspec.yaml을 찾을 수 없습니다" -ForegroundColor Red
        $allPassed = $false
    }
} else {
    Write-Host "❌ WSL 프로젝트 경로에 접근할 수 없습니다" -ForegroundColor Red
    Write-Host "WSL Ubuntu가 실행 중인지 확인하세요" -ForegroundColor Gray
    $allPassed = $false
}

# 7. Flutter 패키지 의존성 확인
Write-Host "`n7. Flutter 패키지 확인..." -ForegroundColor Blue
if ((Test-Command flutter) -and (Test-Path-Safe $wslProjectPath)) {
    try {
        Set-Location $wslProjectPath
        Write-Host "flutter pub deps 실행 중..." -ForegroundColor Yellow
        $pubResult = & flutter pub deps --style=compact 2>$null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Flutter 패키지 의존성 확인됨" -ForegroundColor Green
        } else {
            Write-Host "⚠ 패키지 의존성 문제 발견" -ForegroundColor Yellow
            Write-Host "실행 권장: flutter pub get" -ForegroundColor Gray
        }
    } catch {
        Write-Host "⚠ 패키지 확인 중 오류 발생" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ Flutter 또는 프로젝트 경로 문제로 패키지 확인 불가" -ForegroundColor Red
}

# 8. 빌드 테스트 (옵션)
Write-Host "`n8. 빌드 테스트 (옵션)..." -ForegroundColor Blue
$buildTest = Read-Host "Windows 빌드 테스트를 진행하시겠습니까? (y/N)"
if ($buildTest -eq "y" -or $buildTest -eq "Y") {
    if ((Test-Command flutter) -and (Test-Path-Safe $wslProjectPath)) {
        try {
            Set-Location $wslProjectPath
            Write-Host "flutter build windows --debug 실행 중..." -ForegroundColor Yellow
            & flutter build windows --debug

            if ($LASTEXITCODE -eq 0) {
                Write-Host "✓ Windows 빌드 성공" -ForegroundColor Green
            } else {
                Write-Host "❌ Windows 빌드 실패" -ForegroundColor Red
                $allPassed = $false
            }
        } catch {
            Write-Host "❌ 빌드 실행 중 오류 발생" -ForegroundColor Red
            $allPassed = $false
        }
    }
}

# 결과 요약
Write-Host "`n============== 검증 결과 요약 ==============" -ForegroundColor Cyan
if ($allPassed) {
    Write-Host "🎉 모든 필수 구성 요소가 올바르게 설치되었습니다!" -ForegroundColor Green
    Write-Host ""
    Write-Host "다음 단계:" -ForegroundColor Yellow
    Write-Host "1. Android Studio 실행" -ForegroundColor White
    Write-Host "2. Open → $wslProjectPath" -ForegroundColor White
    Write-Host "3. Flutter/Dart 플러그인 설치" -ForegroundColor White
    Write-Host "4. flutter pub get 실행" -ForegroundColor White
    Write-Host "5. 디바이스를 'Windows (desktop)'으로 선택 후 실행" -ForegroundColor White
} else {
    Write-Host "⚠ 일부 구성 요소에 문제가 있습니다." -ForegroundColor Yellow
    Write-Host "위의 오류 메시지를 확인하고 해결해주세요." -ForegroundColor Gray
    Write-Host ""
    Write-Host "자동 설치 스크립트 실행:" -ForegroundColor Yellow
    Write-Host ".\scripts\windows\setup-dev.ps1" -ForegroundColor White
}
Write-Host "===============================================" -ForegroundColor Cyan

Write-Host "`n검증 스크립트 실행 완료!" -ForegroundColor Green
