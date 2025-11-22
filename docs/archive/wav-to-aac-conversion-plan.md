# WAV → AAC/Opus 변환 기능 구현 계획

**작성일**: 2025-10-30  
**목적**: 진료실 PC에서 WAV만 사용 가능한 상황에서 파일 크기를 줄이기 위한 사후 변환 기능  
**상태**: 계획 단계 (미구현)

---

## 📋 기술적 가능성 분석

### ✅ 가능함

**이유**:
1. **기존 구조 활용 가능**: `splitSegment()`에서 세그먼트 완료 시 `onFileSegmentCreated` 콜백이 이미 호출됨
2. **Windows 표준 도구**: `ffmpeg`가 Windows에서 안정적으로 작동하며, 무료 오픈소스
3. **비동기 처리**: 백그라운드 변환으로 녹음 중단 없이 처리 가능
4. **파일 시스템 접근**: Dart의 `Process` 및 `File` API로 외부 프로세스 실행 및 파일 관리 가능

**제약사항**:
- ⚠️ **ffmpeg 배포 필요**: Windows 실행 파일(`ffmpeg.exe`)을 앱과 함께 배포해야 함
- ⚠️ **변환 시간**: WAV 파일 크기에 따라 변환 시간 소요 (10분 녹음 기준 약 1~3초 예상)
- ⚠️ **CPU 사용량**: 변환 중 CPU 사용량 증가 (백그라운드 처리로 영향 최소화)

---

## 🎯 구현 계획

### Phase 1: 기본 변환 기능 (v1.3.0)

#### 1.1 변환 서비스 생성

**파일**: `lib/services/audio_converter_service.dart`

**기능**:
- ffmpeg 프로세스 실행 및 관리
- WAV → AAC/Opus 변환 (비동기)
- 변환 큐 관리 (동시 변환 개수 제한)
- 변환 진행률 추적 (선택적)
- 에러 처리 및 로깅
- 프로세스 우선순위 낮추기 (녹음 우선 보장)

**주요 메서드**:
```dart
class AudioConverterService {
  /// WAV 파일을 AAC/Opus로 변환
  Future<String?> convertWavToEncoded({
    required String wavPath,
    required AudioEncoder targetEncoder, // AAC 또는 Opus
    required int bitRate,
    required int sampleRate,
    bool deleteOriginal = false, // 원본 삭제 여부
  });
  
  /// ffmpeg 설치 여부 확인
  Future<bool> isFfmpegAvailable();
  
  /// 배치 변환 (여러 파일)
  Future<List<String>> convertBatch({
    required List<String> wavPaths,
    required AudioEncoder targetEncoder,
    required int bitRate,
    required int sampleRate,
  });
  
  /// 변환 큐 상태 확인
  int getQueueLength();
  
  /// 변환 중인지 확인
  bool isConverting();
}
```

#### 1.2 변환 시점 결정

**옵션 A: 세그먼트 완료 직후 변환** (권장)
- 장점: 즉시 압축, 디스크 공간 절약
- 단점: CPU 사용량 증가, 변환 실패 시 원본 손실 위험
- 구현: `splitSegment()` 메서드에서 WAV 파일 생성 시 자동 변환 트리거

**옵션 B: 배치 변환 (오전/오후 종료 후)**
- 장점: CPU 부하 분산, 변환 실패 시 원본 보존
- 단점: 변환 전까지 디스크 공간 사용량 큼
- 구현: 스케줄 서비스에서 진료 종료 시점 감지 후 배치 변환

**옵션 C: 사용자 수동 변환**
- 장점: 사용자 제어, 선택적 변환
- 단점: 수동 작업 필요
- 구현: UI에 "WAV 파일 변환" 버튼 추가

**최종 결정**: **옵션 A + 옵션 C 조합**
- 기본: 세그먼트 완료 직후 자동 변환 (설정에서 활성화 시)
- 백업: 수동 변환 버튼 제공 (자동 변환 실패 시 대응)

#### 1.3 설정 추가

**위치**: 고급 설정 다이얼로그 (`lib/ui/widgets/advanced_settings_dialog.dart`)

**새 설정 항목**:
```
☐ WAV 파일 자동 변환 활성화
  목표 코덱: [AAC ▼] [Opus ▼]
  비트레이트: [64 kbps ▼] (현재 녹음 프로필과 동일)
  
  ℹ️ 진료실 PC에서 WAV만 사용 가능한 경우, 녹음 후 자동으로 압축 형식으로 변환합니다.
  ⚠️ 변환 실패 시 원본 WAV 파일이 유지됩니다.
```

**설정 저장**:
- `SettingsService`에 변환 설정 추가
- 키: `wav_auto_convert_enabled`, `wav_target_encoder`, `wav_target_bitrate`

#### 1.4 AudioService 통합

**수정 위치**: `lib/services/audio_service.dart`

**변경 사항**:
1. `AudioConverterService` 인스턴스 추가
2. `splitSegment()` 메서드 수정:
   ```dart
   // WAV 파일이고 자동 변환 설정이 활성화된 경우
   if (completedEncoder == AudioEncoder.wav && 
       _settingsService.isWavAutoConvertEnabled()) {
     // 새 녹음 안정화를 위해 5초 대기 후 변환 시작
     Future.delayed(const Duration(seconds: 5), () {
       unawaited(_audioConverterService.convertWavToEncoded(
         wavPath: completedPath!,
         targetEncoder: _settingsService.getWavTargetEncoder(),
         bitRate: _profile.bitRate,
         sampleRate: _profile.sampleRate,
         deleteOriginal: true, // 변환 성공 시 원본 삭제
       ));
     });
   }
   ```
   
   **지연 실행 이유**:
   - 새 녹음 세션 안정화 시간 확보
   - 디스크 I/O 경쟁 최소화
   - CPU 리소스 분산

#### 1.5 ffmpeg 배포

**방법**: 앱 패키지에 포함
- 경로: `assets/tools/ffmpeg.exe` 또는 `data/tools/ffmpeg.exe`
- 첫 실행 시 앱 데이터 디렉터리로 복사 (`path_provider` 사용)
- 또는 앱과 같은 폴더에 `ffmpeg.exe` 배치

**다운로드 위치**:
- https://www.gyan.dev/ffmpeg/builds/ (Windows 빌드)
- 또는 https://ffmpeg.org/download.html#build-windows

**라이선스**: LGPL/GPL (상업적 사용 가능)

---

### Phase 2: UI 개선 및 오류 처리 (v1.3.1)

#### 2.1 변환 상태 표시

**대시보드 카드 추가**:
- "WAV 변환 중: 3개 파일 대기 중..."
- 변환 완료 시 스낵바 알림

#### 2.2 오류 처리 강화

- ffmpeg 미설치 감지 및 안내 메시지
- 변환 실패 시 원본 WAV 유지
- 변환 실패 로그 기록

#### 2.3 수동 변환 기능

**설정 탭에 버튼 추가**:
- "WAV 파일 변환" 버튼
- 대화상자에서 변환할 파일 선택 또는 전체 변환
- 진행률 표시

---

### Phase 3: 최적화 (v1.3.2)

#### 3.1 변환 큐 관리

- 동시 변환 개수 제한 (최대 1개) - 진료실 PC 성능 고려
- 우선순위 큐 (최신 파일 우선)
- 큐 상태 모니터링 및 UI 표시

#### 3.2 변환 품질 설정

- 비트레이트 조정 (64/48/32 kbps)
- 샘플레이트 유지 또는 다운샘플링

---

## 📐 기술 스펙

### ffmpeg 명령어 예시

**WAV → AAC (M4A)**:
```bash
ffmpeg.exe -i input.wav -c:a aac -b:a 64k -ar 44100 -y output.m4a
```

**WAV → Opus**:
```bash
ffmpeg.exe -i input.wav -c:a libopus -b:a 64k -ar 44100 -y output.opus
```

**파라미터 설명**:
- `-i input.wav`: 입력 파일
- `-c:a aac`: 오디오 코덱 (AAC)
- `-c:a libopus`: 오디오 코덱 (Opus)
- `-b:a 64k`: 비트레이트
- `-ar 44100`: 샘플레이트
- `-y`: 출력 파일 덮어쓰기

### 파일 크기 예상

**10분 녹음 기준** (모노, 16kHz):
- WAV: 약 **19 MB** (무압축)
- AAC 64kbps: 약 **4.8 MB** (약 75% 절감)
- Opus 64kbps: 약 **4.5 MB** (약 76% 절감)

**하루 8시간 녹음 기준**:
- WAV: 약 **912 MB** (약 0.9 GB)
- AAC 64kbps: 약 **230 MB** (약 77% 절감)
- Opus 64kbps: 약 **216 MB** (약 76% 절감)

---

## 🔄 구현 순서

### 1단계: 기본 변환 기능 (1주)
- [ ] `AudioConverterService` 클래스 생성
- [ ] ffmpeg 프로세스 실행 로직 구현
- [ ] `splitSegment()`에 변환 로직 통합
- [ ] 기본 설정 항목 추가

### 2단계: 테스트 및 검증 (3일)
- [ ] 개발 PC에서 WAV → AAC 변환 테스트
- [ ] 진료실 PC에서 실제 환경 테스트
- [ ] 파일 크기 및 품질 확인

### 3단계: UI 및 오류 처리 (3일)
- [ ] 변환 상태 표시 UI 추가
- [ ] ffmpeg 미설치 감지 및 안내
- [ ] 수동 변환 버튼 추가

### 4단계: 배포 준비 (2일)
- [ ] ffmpeg.exe 패키지에 포함
- [ ] 문서 업데이트 (`docs/user-guide.md`)
- [ ] 버전 업데이트 (v1.3.0)

---

## ⚠️ 고려사항

### 1. 동시성 문제: 녹음 + 변환 동시 실행

**우려사항**:
- 세그먼트 분할 시 새 녹음 시작과 변환이 동시에 실행됨
- 진료실 PC는 오래된 하드웨어일 가능성 높음
- CPU/디스크 I/O 경쟁으로 녹음 품질 저하 가능성

**현재 코드 분석**:
```dart
// splitSegment() 메서드 구조
1. 현재 녹음 중지 (동기) - 약 10ms
2. 파일 콜백 호출 (비동기, unawaited)
3. 새 녹음 시작 (동기) - 약 50ms
4. 보관 정책 적용 (비동기, unawaited)
```

**해결 방안**:

**방안 A: 변환 지연 실행** (권장)
- 새 녹음 시작 완료 후 5~10초 대기 후 변환 시작
- 녹음 안정화 시간 확보
- 구현: `Future.delayed(Duration(seconds: 5))` 후 변환 트리거

**방안 B: 변환 우선순위 낮추기**
- Windows 프로세스 우선순위를 "낮음"으로 설정
- 녹음 프로세스 우선 보장
- 구현: `Process.start()` 시 `runInShell: false` 및 우선순위 설정

**방안 C: 변환 큐 시스템**
- 동시 변환 개수 제한 (최대 1개)
- 새 녹음 시작 중에는 변환 대기
- 구현: 변환 큐에서 녹음 상태 확인 후 실행

**최종 결정**: **방안 A + 방안 C 조합**
- 기본: 새 녹음 시작 후 5초 대기
- 추가: 변환 큐로 동시 변환 제한 (최대 1개)

### 2. 진료실 PC 환경 호환성

**우려사항**:
- 코덱 문제로 WAV만 사용 가능한 PC
- Windows Media Foundation과 무관한 ffmpeg 사용 가능 여부

**분석**:
- ✅ **ffmpeg는 Windows Media Foundation과 독립적**
  - ffmpeg는 자체 코덱 라이브러리 사용
  - Windows Media Foundation 미설치 환경에서도 작동
  - 단, ffmpeg.exe 파일이 필요함

- ✅ **진료실 PC에서도 작동 가능**
  - 녹음 코덱 문제 (Windows Media Foundation) ≠ 변환 도구 문제 (ffmpeg)
  - Visual C++ Runtime은 이미 설치됨 (v1.2.8에서 해결)
  - ffmpeg는 추가 DLL 의존성 없이 단일 실행 파일로 동작 가능

**필수 조건**:
- ffmpeg.exe 파일 배포 필요
- 진료실 PC에 복사 가능한 디스크 공간 (약 100MB)

### 3. 성능 영향 평가

**예상 시나리오 (10분 녹음 기준)**:

| 작업 | CPU 사용량 | 디스크 I/O | 소요 시간 |
|------|-----------|-----------|----------|
| 녹음 중지 | 낮음 | 읽기 (1MB) | ~10ms |
| 새 녹음 시작 | 낮음 | 쓰기 준비 | ~50ms |
| **변환 시작** | **중간 (20-30%)** | **읽기+쓰기 (19MB)** | **1-3초** |
| 녹음 진행 중 | 매우 낮음 | 쓰기 (연속) | 연속 |

**진료실 PC 성능 가정**:
- CPU: Intel Core i3/i5 2세대 이상 (2010년대 초)
- RAM: 4GB 이상
- 디스크: HDD (SSD 아님)

**예상 영향**:
- ✅ **녹음 품질**: 영향 없음 (변환은 별도 프로세스)
- ⚠️ **CPU 사용량**: 변환 중 20-30% 증가 (백그라운드 처리)
- ⚠️ **디스크 쓰기**: 변환 중 디스크 읽기/쓰기로 인한 약간의 지연 가능
- ✅ **전체 안정성**: 5초 지연으로 녹음 안정화 후 변환 시작하면 문제 없음

### 4. ffmpeg 라이선스
- **LGPL/GPL**: 상용 배포 가능하나 라이선스 고지 필요
- **대안**: 앱 내에서 다운로드 링크 제공 (사용자가 직접 설치)

### 5. 변환 실패 시나리오
- **원본 보존**: 변환 실패 시 항상 원본 WAV 유지
- **재시도 로직**: 변환 실패 시 자동 재시도 (최대 3회)
- **수동 변환**: 자동 변환 실패 시 사용자가 수동으로 변환 가능

### 6. 디스크 공간 관리
- **변환 전**: 원본 WAV + 변환 파일 공존 (일시적)
- **변환 후**: 원본 삭제 시 공간 확보
- **정책**: 변환 완료 후 원본 삭제 (설정에서 선택 가능)

### 7. 성능 최적화 방안
- **변환 지연**: 새 녹음 시작 후 5초 대기
- **변환 큐**: 동시 변환 개수 제한 (최대 1개)
- **프로세스 우선순위**: 변환 프로세스를 "낮음"으로 설정
- **디스크 I/O 모니터링**: 변환 중 디스크 사용량 높으면 대기

---

## 📊 성공 지표

### 기능 완성도
- [ ] WAV 파일 자동 변환 정상 작동
- [ ] 변환 실패 시 원본 보존
- [ ] ffmpeg 미설치 시 안내 메시지 표시

### 성능 지표
- **변환 시간**: 10분 녹음 파일 기준 3초 이내
- **CPU 사용량**: 변환 중 20-30% 증가 (백그라운드, 5초 지연 적용)
- **파일 크기**: WAV 대비 70% 이상 절감
- **녹음 영향**: 없음 (변환 지연 및 큐 관리로 최소화)

### 사용자 경험
- [ ] 자동 변환 활성화 시 사용자 개입 없이 작동
- [ ] 변환 상태를 UI에서 확인 가능
- [ ] 수동 변환 기능으로 제어 가능

---

## 🔗 참고 자료

- [FFmpeg 공식 문서](https://ffmpeg.org/documentation.html)
- [FFmpeg Windows 빌드](https://www.gyan.dev/ffmpeg/builds/)
- [Dart Process API](https://api.dart.dev/stable/dart-io/Process-class.html)

---

**다음 단계**: Phase 1 구현 시작 전에 사용자 피드백 수집 및 기술 검증 (ffmpeg 배포 방법 최종 결정)

