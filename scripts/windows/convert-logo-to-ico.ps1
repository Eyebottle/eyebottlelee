# 로고를 ICO 파일로 변환하는 스크립트
# WebP/PNG 이미지를 다양한 크기의 ICO로 변환

param(
    [string]$InputImage = "assets\images\eyebottle-logo.png",
    [string]$OutputIco = "assets\icons\icon.ico"
)

Write-Host "아이보틀 로고 → ICO 변환 스크립트" -ForegroundColor Cyan
Write-Host "입력: $InputImage" -ForegroundColor White
Write-Host "출력: $OutputIco" -ForegroundColor White

# 입력 파일 확인
if (-not (Test-Path $InputImage)) {
    Write-Host "❌ 입력 파일을 찾을 수 없습니다: $InputImage" -ForegroundColor Red
    exit 1
}

# 출력 디렉토리 생성
$outputDir = Split-Path $OutputIco -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    Write-Host "✅ 출력 디렉토리 생성: $outputDir" -ForegroundColor Green
}

# .NET System.Drawing 사용
Add-Type -AssemblyName System.Drawing

try {
    # 원본 이미지 로드
    $sourceImage = [System.Drawing.Image]::FromFile((Resolve-Path $InputImage).Path)
    Write-Host "✅ 원본 이미지 로드 완료: $($sourceImage.Width)x$($sourceImage.Height)" -ForegroundColor Green

    # ICO 파일에 포함할 크기들 (Windows 권장 크기)
    $sizes = @(16, 32, 48, 64, 128, 256)

    # 임시 Bitmap들을 저장할 배열
    $bitmaps = @()

    Write-Host "이미지 크기 조정 중..." -ForegroundColor Yellow

    foreach ($size in $sizes) {
        $bitmap = New-Object System.Drawing.Bitmap($size, $size)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

        # 고품질 리샘플링 설정
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

        # 이미지 그리기
        $graphics.DrawImage($sourceImage, 0, 0, $size, $size)
        $graphics.Dispose()

        $bitmaps += $bitmap
        Write-Host "  ✓ ${size}x${size}" -ForegroundColor Gray
    }

    # ICO 파일 생성
    Write-Host "ICO 파일 생성 중..." -ForegroundColor Yellow

    # 메모리 스트림 생성
    $memoryStream = New-Object System.IO.MemoryStream

    # ICO 헤더 작성
    $writer = New-Object System.IO.BinaryWriter($memoryStream)
    $writer.Write([UInt16]0)  # Reserved (must be 0)
    $writer.Write([UInt16]1)  # Type (1 = ICO)
    $writer.Write([UInt16]$bitmaps.Count)  # Number of images

    # 각 이미지의 디렉토리 엔트리 작성
    $offset = 6 + (16 * $bitmaps.Count)  # 헤더 + 디렉토리 엔트리들

    $imageDataList = @()

    foreach ($bitmap in $bitmaps) {
        # PNG로 인코딩
        $pngStream = New-Object System.IO.MemoryStream
        $bitmap.Save($pngStream, [System.Drawing.Imaging.ImageFormat]::Png)
        $imageData = $pngStream.ToArray()
        $pngStream.Dispose()

        $imageDataList += $imageData

        # 디렉토리 엔트리
        $writer.Write([byte]$bitmap.Width)      # Width
        $writer.Write([byte]$bitmap.Height)     # Height
        $writer.Write([byte]0)                  # Color palette (0 = no palette)
        $writer.Write([byte]0)                  # Reserved
        $writer.Write([UInt16]1)                # Color planes
        $writer.Write([UInt16]32)               # Bits per pixel
        $writer.Write([UInt32]$imageData.Length) # Image data size
        $writer.Write([UInt32]$offset)          # Offset to image data

        $offset += $imageData.Length
    }

    # 이미지 데이터 작성
    foreach ($imageData in $imageDataList) {
        $writer.Write($imageData)
    }

    # 파일로 저장
    $fileStream = [System.IO.File]::Create((Join-Path (Get-Location) $OutputIco))
    $memoryStream.WriteTo($fileStream)
    $fileStream.Close()
    $memoryStream.Close()

    # 리소스 정리
    foreach ($bitmap in $bitmaps) {
        $bitmap.Dispose()
    }
    $sourceImage.Dispose()

    $outputFile = Get-Item $OutputIco
    Write-Host "✅ ICO 파일 생성 완료!" -ForegroundColor Green
    Write-Host "   파일: $OutputIco" -ForegroundColor White
    Write-Host "   크기: $([math]::Round($outputFile.Length / 1KB, 2)) KB" -ForegroundColor White
    Write-Host "   포함된 크기: $($sizes -join ', ')" -ForegroundColor White

} catch {
    Write-Host "❌ 오류 발생: $_" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host "`n완료! 🎉" -ForegroundColor Green
