# ffmpeg 설정 가이드

WAV 파일 자동 변환 기능을 사용하기 위해서는 ffmpeg 실행 파일이 필요합니다.

## 📥 ffmpeg 다운로드

### 방법 1: 공식 빌드 다운로드 (권장)

1. **ffmpeg Windows 빌드 다운로드**
   - 링크: https://github.com/BtbN/FFmpeg-Builds/releases
   - 파일명: `ffmpeg-master-latest-win64-gpl.zip` (약 100MB)

2. **압축 해제**
   ```
   ffmpeg-master-latest-win64-gpl/
   └── bin/
       ├── ffmpeg.exe  ← 이 파일 필요
       ├── ffplay.exe
       └── ffprobe.exe
   ```

3. **ffmpeg.exe 복사**
   - `bin/ffmpeg.exe` 파일을 프로젝트 폴더로 복사
   - 대상 경로: `assets/bin/ffmpeg.exe`

### 방법 2: 직접 빌드 (고급 사용자)

ffmpeg를 직접 빌드하고 싶다면 공식 가이드를 참고하세요:
- https://ffmpeg.org/download.html#build-windows

---

## 📁 프로젝트에 추가

### 1. assets 폴더 생성

프로젝트 루트에서:
```bash
mkdir -p assets/bin
```

### 2. ffmpeg.exe 복사

다운로드한 `ffmpeg.exe`를 `assets/bin/` 폴더에 복사:

```
프로젝트/
├── assets/
│   └── bin/
│       └── ffmpeg.exe  ← 여기에 복사
├── lib/
├── pubspec.yaml
└── ...
```

### 3. pubspec.yaml 확인

`pubspec.yaml`의 `flutter > assets` 섹션에 다음 경로가 포함되어 있는지 확인:

```yaml
flutter:
  assets:
    - assets/images/
    - assets/icons/
    - assets/bin/ffmpeg.exe  # ← 이 줄이 있어야 함
```

---

## ✅ 동작 확인

### 앱 첫 실행 시

앱이 시작되면 `AudioConverterService`가 자동으로:
1. `assets/bin/ffmpeg.exe`를 앱 데이터 폴더로 복사
2. `ffmpeg -version` 명령으로 정상 작동 확인
3. 로그에 ffmpeg 버전 정보 출력

### 로그 확인

앱 실행 후 로그 파일에서 다음 메시지를 확인:
```
INFO: ffmpeg 발견: C:\Users\...\AppData\Local\...\ffmpeg.exe
INFO: ffmpeg 버전: ffmpeg version N-XXXXX-...
```

### 문제 해결

**ffmpeg를 찾을 수 없다는 에러:**
- `assets/bin/ffmpeg.exe` 파일이 존재하는지 확인
- `pubspec.yaml`에 경로가 올바르게 등록되었는지 확인
- `flutter clean && flutter build windows` 실행 후 재시도

**ffmpeg 실행 실패:**
- Windows Defender 또는 백신 프로그램이 차단하는지 확인
- ffmpeg.exe가 손상되지 않았는지 확인 (다시 다운로드)

---

## 📝 라이선스 정보

### ffmpeg 라이선스

- **라이선스**: LGPL 2.1+ 또는 GPL 2+ (빌드에 따라 다름)
- **상업적 사용**: 가능 (LGPL 준수 필요)
- **의무 사항**:
  - ffmpeg 사용 사실 고지
  - LGPL 라이선스 문구 포함
  - 소스 코드 제공 의무 없음 (동적 링크 사용 시)

### 프로젝트에서의 사용

본 프로젝트는 ffmpeg를 **별도의 실행 파일**로 사용하므로:
- ✅ 소스 코드 공개 의무 없음
- ✅ 상업적 사용 가능
- ⚠️ ffmpeg 사용 사실 및 라이선스 고지 필요

### 라이선스 고지 방법

앱의 "정보" 또는 "라이선스" 섹션에 다음 내용 포함:

```
이 소프트웨어는 FFmpeg를 사용합니다.
FFmpeg is licensed under the LGPL v2.1+
https://ffmpeg.org/legal.html
```

---

## 🔧 개발자 참고사항

### ffmpeg 명령어

AudioConverterService에서 사용하는 명령어:

```bash
# AAC 변환
ffmpeg -i input.wav -c:a aac -b:a 64000 -ar 44100 -y output.m4a

# Opus 변환
ffmpeg -i input.wav -c:a libopus -b:a 64000 -ar 44100 -y output.opus
```

### 매개변수 설명

- `-i input.wav`: 입력 파일
- `-c:a aac|libopus`: 오디오 코덱
- `-b:a 64000`: 비트레이트 (64kbps)
- `-ar 44100`: 샘플레이트 (44.1kHz)
- `-y`: 기존 파일 덮어쓰기

### 변환 성능

**예상 변환 시간** (10분 WAV 파일 기준):
- 저사양 PC (Core i3 2세대, HDD): ~3초
- 중급 PC (Core i5 8세대, SSD): ~1초
- 고사양 PC (Core i7 12세대, NVMe): ~0.5초

**파일 크기 절감:**
- WAV (16-bit PCM, 44.1kHz): ~19MB (10분)
- AAC (64kbps): ~4.8MB (10분) → **75% 절감**
- Opus (64kbps): ~4.8MB (10분) → **75% 절감**

---

## 🚀 배포 시 주의사항

### 1. 앱 크기 증가

- ffmpeg.exe 포함 시 앱 크기 +100MB
- MSIX 패키지 크기에 영향

### 2. Windows Defender

- 처음 실행 시 Windows Defender가 ffmpeg.exe 검사 가능
- 몇 초 지연 발생 가능 (정상)

### 3. 사용자 안내

사용자 매뉴얼에 다음 내용 포함 권장:
- WAV 자동 변환 기능 설명
- 첫 변환 시 약간의 지연 가능성
- 변환 실패 시 원본 파일 보존됨을 안내

---

## 📞 문제 발생 시

문제가 지속되면 다음 정보와 함께 문의:
1. 앱 로그 파일
2. Windows 버전
3. ffmpeg 버전
4. 오류 메시지

---

**최종 수정일:** 2025-01-04
**문서 버전:** 1.0.0
