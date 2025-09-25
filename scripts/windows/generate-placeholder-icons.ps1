<#
 .SYNOPSIS
  Eyebottle icon generator for development and release builds.

 .DESCRIPTION
  Creates Windows ICO assets from the official Eyebottle logo. Requires
  ImageMagick (`magick`) to be installed and available on PATH. If ImageMagick
  is missing or the logo file cannot be found, the script falls back to
  lightweight text placeholders so that the build can still proceed, but it
  warns the developer to supply real icons before release.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-Command {
    param([Parameter(Mandatory = $true)][string]$Name)
    return [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function New-PlaceholderIcons {
    param(
        [string]$IconDirectory
    )

    Write-Warning 'ImageMagick을 찾을 수 없습니다. 텍스트 플레이스홀더를 생성합니다.'
    $placeholder = @"
; 아이보틀 진료 녹음 - 아이콘 플레이스홀더
; ImageMagick을 설치하고 공식 로고를 사용해 실제 ICO 파일로 교체해주세요.
"@

    foreach ($name in @('icon.ico', 'tray_recording.ico', 'tray_waiting.ico', 'tray_error.ico')) {
        $path = Join-Path $IconDirectory $name
        $placeholder | Out-File -FilePath $path -Encoding UTF8
        Write-Host "생성됨 (플레이스홀더): $path" -ForegroundColor DarkGray
    }

    Write-Host "⚠ 실제 배포 전에는 진짜 ICO 아이콘이 필요합니다." -ForegroundColor Yellow
}

function Invoke-MagickCommand {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Description
    )

    Write-Host "- $Description" -ForegroundColor Cyan
    & magick @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "magick 명령이 실패했습니다 (exit code: $LASTEXITCODE)"
    }
}

function New-TrayIcon {
    param(
        [string]$LogoPath,
        [string]$TargetPath,
        [string]$BadgeColor,
        [string]$BadgeLabel
    )

    $args = @(
        $LogoPath,
        '-resize', '64x64',
        '-background', 'none',
        '-gravity', 'center',
        '-extent', '64x64',
        '(',
            '-size', '18x18',
            'xc:none',
            '-fill', $BadgeColor,
            '-draw', 'circle 9,9 9,1',
        ')',
        '-gravity', 'southeast',
        '-geometry', '+6+6',
        '-compose', 'over',
        '-composite',
        '-define', 'icon:auto-resize=64,48,32,24,16',
        $TargetPath
    )

    Invoke-MagickCommand -Arguments $args -Description "트레이 아이콘 생성: $BadgeLabel"
}

Write-Host "=== 아이보틀 아이콘 생성 ===" -ForegroundColor Green

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
$iconDir = Join-Path $repoRoot 'assets' 'icons'
$logoPath = Join-Path $repoRoot 'assets' 'logos' 'eyebottle-logo.png'

if (-not (Test-Path $iconDir)) {
    New-Item -ItemType Directory -Path $iconDir | Out-Null
    Write-Host "아이콘 폴더 생성: $iconDir" -ForegroundColor Yellow
}

if (-not (Test-Command -Name 'magick')) {
    New-PlaceholderIcons -IconDirectory $iconDir
    return
}

if (-not (Test-Path $logoPath)) {
    Write-Warning "로고 파일을 찾을 수 없습니다: $logoPath"
    New-PlaceholderIcons -IconDirectory $iconDir
    return
}

Write-Host "ImageMagick 감지됨. 로고 기반 ICO를 생성합니다." -ForegroundColor Green

$mainIconPath = Join-Path $iconDir 'icon.ico'
Invoke-MagickCommand -Description '앱 아이콘 생성 (멀티 해상도)' -Arguments @(
    $logoPath,
    '-background', 'none',
    '-alpha', 'set',
    '-define', 'icon:auto-resize=256,192,128,96,64,48,32,24,16',
    $mainIconPath
)

New-TrayIcon -LogoPath $logoPath -TargetPath (Join-Path $iconDir 'tray_recording.ico') -BadgeColor '#FF4D4F' -BadgeLabel '녹음 중(R)'
New-TrayIcon -LogoPath $logoPath -TargetPath (Join-Path $iconDir 'tray_waiting.ico') -BadgeColor '#2CC38E' -BadgeLabel '대기 중'
New-TrayIcon -LogoPath $logoPath -TargetPath (Join-Path $iconDir 'tray_error.ico') -BadgeColor '#FFC53D' -BadgeLabel '오류'

Write-Host "\n📁 생성된 아이콘 파일:" -ForegroundColor Blue
Get-ChildItem $iconDir -Filter '*.ico' | Sort-Object Name | ForEach-Object {
    $sizeKB = [math]::Round($_.Length / 1KB, 1)
    Write-Host "  $($_.Name) (${sizeKB} KB)" -ForegroundColor White
}

Write-Host "\n✅ 아이콘 생성 완료" -ForegroundColor Green
Write-Host "필요 시 $iconDir 경로의 ICO를 교체하거나 세부 조정하세요." -ForegroundColor Yellow

