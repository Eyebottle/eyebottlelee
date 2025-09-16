# 아이보틀 진료 녹음 - Windows 개발 환경 자동 설치 스크립트
# PowerShell (관리자 권한)에서 실행: .\scripts\windows\setup-dev.ps1

param(
    [string]$FlutterPath = "C:\flutter",
    [string]$FlutterVersion = "3.35.3",
    [string]$StudioPath = $null,
    [string]$StudioSha256 = "e9c127638428cc4298f98529c1b582dbca100c98dbf4792dc95e92d2f19918c5",
    [switch]$SkipStudio = $false,
    [switch]$SkipFlutter = $false,
    [switch]$SkipVisualStudio = $false,
    [switch]$ForceFlutter = $false
)

Write-Host "=== 아이보틀 진료 녹음 개발 환경 설치 ===" -ForegroundColor Green
Write-Host "PRD v1.1 기반 Flutter Windows Desktop 환경 구성" -ForegroundColor Cyan

# 관리자 권한 확인
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "이 스크립트는 관리자 권한이 필요합니다. PowerShell을 관리자로 실행해주세요."
    exit 1
}

# 함수 정의
function Test-Command($cmdname) {
    return [bool](Get-Command -Name $cmdname -ErrorAction SilentlyContinue)
}

function Download-File($url, $output) {
    Write-Host "다운로드 중: $url" -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $url -OutFile $output -UseBasicParsing
        return $true
    } catch {
        Write-Error "다운로드 실패: $_"
        return $false
    }
}

function Test-FileHash($filePath, $expectedHash) {
    if (-not (Test-Path $filePath)) {
        return $false
    }
    $actualHash = (Get-FileHash -Path $filePath -Algorithm SHA256).Hash
    return $actualHash -eq $expectedHash
}

# 1. Chocolatey 설치 (패키지 관리자)
Write-Host "`n1. Chocolatey 패키지 관리자 확인/설치..." -ForegroundColor Blue
if (-not (Test-Command choco)) {
    Write-Host "Chocolatey 설치 중..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

    if (-not (Test-Command choco)) {
        Write-Error "Chocolatey 설치 실패"
        exit 1
    }
} else {
    Write-Host "✓ Chocolatey 이미 설치됨" -ForegroundColor Green
}

# 2. Git 설치
Write-Host "`n2. Git 확인/설치..." -ForegroundColor Blue
if (-not (Test-Command git)) {
    Write-Host "Git 설치 중..." -ForegroundColor Yellow
    choco install git -y
} else {
    Write-Host "✓ Git 이미 설치됨" -ForegroundColor Green
}

# 3. Visual Studio 2022 Build Tools 설치
if (-not $SkipVisualStudio) {
    Write-Host "`n3. Visual Studio 2022 Build Tools 확인/설치..." -ForegroundColor Blue

    # Visual Studio 설치 확인
    $vsPath = "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"
    $vsBuildToolsPath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"

    if (-not ((Test-Path $vsPath) -or (Test-Path $vsBuildToolsPath))) {
        Write-Host "Visual Studio Build Tools 설치 중..." -ForegroundColor Yellow
        choco install visualstudio2022buildtools --package-parameters "--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended" -y

        # 대안: Community 버전 설치
        if (-not (Test-Path $vsBuildToolsPath)) {
            Write-Host "Visual Studio Community 2022 설치 중..." -ForegroundColor Yellow
            choco install visualstudio2022community --package-parameters "--add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended" -y
        }
    } else {
        Write-Host "✓ Visual Studio C++ Build Tools 이미 설치됨" -ForegroundColor Green
    }
} else {
    Write-Host "3. Visual Studio 설치 건너뜀 (-SkipVisualStudio)" -ForegroundColor Gray
}

# 4. Flutter SDK 설치
if (-not $SkipFlutter) {
    Write-Host "`n4. Flutter SDK 확인/설치..." -ForegroundColor Blue

    if (Test-Command flutter -and -not $ForceFlutter) {
        $existing = $(flutter --version 2>$null)
        Write-Host "✓ Flutter 이미 설치됨: $existing" -ForegroundColor Green

        # 버전 불일치 경고
        try {
            $joined = ($existing | Out-String)
            $m = [regex]::Match($joined, "\d+\.\d+\.\d+")
            if ($m.Success -and $m.Value -ne $FlutterVersion) {
                Write-Warning "설치된 Flutter 버전($($m.Value))이 표준 버전($FlutterVersion)과 다릅니다."
                Write-Host "표준으로 맞추려면: .\\scripts\\windows\\setup-dev.ps1 -ForceFlutter -FlutterVersion $FlutterVersion" -ForegroundColor Gray
            }
        } catch {}
    } else {
        Write-Host "Flutter SDK 설치 중..." -ForegroundColor Yellow

        # Flutter SDK 다운로드
        $flutterZip = "$env:TEMP\flutter_windows.zip"
        $flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_${FlutterVersion}-stable.zip"

        if (Download-File $flutterUrl $flutterZip) {
            # 압축 해제
            if (Test-Path $FlutterPath) {
                Remove-Item $FlutterPath -Recurse -Force
            }
            Expand-Archive -Path $flutterZip -DestinationPath (Split-Path $FlutterPath) -Force
            Remove-Item $flutterZip

            # PATH 환경변수 추가
            $flutterBin = "$FlutterPath\bin"
            $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
            if ($currentPath -notlike "*$flutterBin*") {
                Write-Host "Flutter를 시스템 PATH에 추가 중..." -ForegroundColor Yellow
                [Environment]::SetEnvironmentVariable("Path", "$currentPath;$flutterBin", "Machine")
                $env:Path += ";$flutterBin"
            }

            Write-Host "✓ Flutter SDK 설치 완료 (버전: $FlutterVersion)" -ForegroundColor Green
        } else {
            Write-Error "Flutter SDK 다운로드 실패"
            exit 1
        }
    }

    # Flutter Windows Desktop 활성화
    Write-Host "Flutter Windows Desktop 활성화 중..." -ForegroundColor Yellow
    & flutter config --enable-windows-desktop

} else {
    Write-Host "4. Flutter 설치 건너뜀 (-SkipFlutter)" -ForegroundColor Gray
}

# 5. Android Studio 설치
if (-not $SkipStudio) {
    Write-Host "`n5. Android Studio 확인/설치..." -ForegroundColor Blue

    $studioInstalled = Test-Path "${env:ProgramFiles}\Android\Android Studio\bin\studio64.exe"
    $studioInstalled = $studioInstalled -or (Test-Path "${env:LOCALAPPDATA}\Programs\Android Studio\bin\studio64.exe")

    if ($studioInstalled) {
        Write-Host "✓ Android Studio 이미 설치됨" -ForegroundColor Green
    } else {
        if ($StudioPath -and (Test-Path $StudioPath)) {
            # 로컬 파일 사용
            Write-Host "로컬 Android Studio 설치 파일 사용: $StudioPath" -ForegroundColor Yellow

            # SHA-256 검증
            if (Test-FileHash $StudioPath $StudioSha256) {
                Write-Host "✓ SHA-256 검증 통과" -ForegroundColor Green
                Start-Process -FilePath $StudioPath -ArgumentList "/S" -Wait
            } else {
                Write-Warning "SHA-256 해시가 일치하지 않습니다. 계속 진행하시겠습니까? (y/N)"
                $response = Read-Host
                if ($response -eq "y" -or $response -eq "Y") {
                    Start-Process -FilePath $StudioPath -ArgumentList "/S" -Wait
                } else {
                    Write-Error "Android Studio 설치 중단"
                    exit 1
                }
            }
        } else {
            # Chocolatey로 설치
            Write-Host "Android Studio 설치 중..." -ForegroundColor Yellow
            choco install androidstudio -y
        }
    }
} else {
    Write-Host "5. Android Studio 설치 건너뜀 (-SkipStudio)" -ForegroundColor Gray
}

# 6. 환경 검증
Write-Host "`n6. 개발 환경 검증..." -ForegroundColor Blue
Write-Host "Flutter Doctor 실행 중..." -ForegroundColor Yellow

# PATH 새로고침
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

if (Test-Command flutter) {
    & flutter doctor -v
    Write-Host "`n✓ Flutter 환경 검증 완료" -ForegroundColor Green
} else {
    Write-Warning "Flutter 명령어를 찾을 수 없습니다. 시스템을 재시작한 후 다시 시도해주세요."
}

# 7. WSL 프로젝트 경로 안내
Write-Host "`n7. 다음 단계 안내" -ForegroundColor Blue
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "개발 환경 설치가 완료되었습니다!" -ForegroundColor Green
Write-Host ""
Write-Host "📁 WSL 프로젝트 경로:" -ForegroundColor Yellow
Write-Host "   \\wsl$\Ubuntu\home\usereyebottle\projects\eyebottlelee" -ForegroundColor White
Write-Host ""
Write-Host "🚀 다음 단계:" -ForegroundColor Yellow
Write-Host "   1. Android Studio 실행" -ForegroundColor White
Write-Host "   2. 'Open' → 위 WSL 경로 입력" -ForegroundColor White
Write-Host "   3. Flutter/Dart 플러그인 설치 (Android Studio에서 안내)" -ForegroundColor White
Write-Host "   4. 터미널에서 'flutter pub get' 실행" -ForegroundColor White
Write-Host "   5. 디바이스를 'Windows (desktop)'으로 선택 후 실행" -ForegroundColor White
Write-Host ""
Write-Host "🔧 문제 해결:" -ForegroundColor Yellow
Write-Host "   - flutter doctor 실행하여 환경 확인" -ForegroundColor White
Write-Host "   - 시스템 재시작 후 PATH 환경변수 적용" -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Cyan

Write-Host "`n설치 스크립트 실행 완료!" -ForegroundColor Green
