# 아이보틀 진료 녹음 PRD

**제품명**: 아이보틀 진료 녹음 (Eyebottle Medical Recorder)  
**버전**: 1.1 (Flutter 전환)  
**작성일**: 2025-08-24  
**상태**: MVP 1차 구현 완료 · 고도화 진행 중 (2025-09-16 기준)

---

## 1. 제품 개요

### 1.1 목적 및 비전
- **목적**: 진료 중 환자와의 대화를 자동으로 녹음하고 체계적으로 관리하는 데스크톱 애플리케이션
- **비전**: 완전 자동화된 무료 진료 녹음 솔루션으로 의료진의 기록 작성 시간을 획기적으로 단축
- **핵심 가치**: 자동화, 편의성, 비용 효율성

### 1.2 타겟 사용자
- **주 사용자**: 개인 의원 및 소규모 병원 의료진
- **부 사용자**: 간호사, 의료 보조 인력
- **사용 환경**: Windows 데스크톱 환경

### 1.3 차별화 요소
- **진료 시간표 기반 완전 자동화**: 다른 녹음 앱에서 찾을 수 없는 의료 특화 기능
- **완전 무료 운영**: OneDrive 개인 계정 활용으로 추가 비용 없음
- **의료 환경 최적화**: 10분 단위 분할, VAD 무음 감지 등 진료실 특성 반영
- **3클릭 설정**: 복잡한 설정 없이 즉시 사용 가능

### 1.4 성공 지표
- **안정성**: 8시간 연속 무중단 녹음
- **사용성**: 설정 완료까지 3클릭 이내
- **효율성**: VAD로 파일 용량 50% 절약
- **비용**: 월 운영비 0원 달성

---

## 2. 핵심 기능 명세

### 2.1 자동 녹음 시스템

#### 2.1.1 진료 시간표 기반 스케줄링
```javascript
// 진료 시간표 예시
const schedule = {
  월요일: {
    morning: { start: "09:00", end: "13:00" },
    afternoon: { start: "14:00", end: "18:00" },
  },
  화요일: {
    morning: { start: "09:00", end: "13:00" },
    afternoon: { start: "14:00", end: "18:00" },
  },
  // ...
};
```
- **자동 시작/종료**: 설정된 진료 시간에 자동으로 녹음 시작/종료
- **점심시간 제외**: 기본 오전(09:00~13:00) / 오후(14:00~18:00) 구간 사이에 자동 휴식
- **오전/오후 분할**: 오전·오후 진료 구간을 개별 설정해 점심시간을 자동으로 비운다.
- **휴진일 설정**: 특정 날짜 예외 처리
- **유연한 스케줄**: 요일별 다른 시간표 설정 가능

#### 2.1.2 스마트 파일 관리
- **10분 단위 자동 분할**: 긴 녹음을 관리하기 쉬운 단위로 분할
- **체계적 파일명**: `2025-08-24_14-30_진료녹음.m4a` 형식
- **자동 압축**: AAC-LC 64kbps(M4A)로 용량 최적화 (플랫폼 기본 인코더 활용)
- **저용량 품질 프리셋**: 64/48/32kbps AAC-LC 프로필을 제공해 진료실 환경과 저장 용량에 맞춰 선택 가능
- **OneDrive 동기화**: 로컬 저장 후 개인 OneDrive 폴더로 자동 백업

### 2.2 실시간 모니터링

#### 2.2.1 마이크 상태 감시
- **연결 상태 확인**: 마이크 연결 끊김 자동 감지
- **볼륨 레벨 미터**: 실시간 입력 레벨 시각화
- **입력 레벨 모니터링**: 실시간 볼륨 미터로 상태 확인(자동 경고는 향후 추가)
- **자동 진단 임계값**: RMS 0.04 이상을 정상, 0.018~0.04는 주의로 판단해 안내 메시지 표시
- **dBFS·SNR 기반 점검**: 3초 샘플에서 평균 레벨(dBFS)과 신호대잡음비(SNR)를 계산해 조용한 진료실에서도 정상 판정 제공
- **시스템 트레이 표시**: 녹음 상태를 트레이 아이콘으로 확인

#### 2.2.2 Voice Activity Detection (VAD)
```javascript
// VAD 구현 예시
const vadConfig = {
  threshold: 0.01,       // 음성 감지 임계값 (RMS 기반)
  silenceDuration: 3000, // 3초 무음 시 일시정지
  resumeDelay: 500       // 음성 감지 시 재개 지연
};
```
- **무음 자동 스킵**: RMS 레벨이 임계값(기본 0.01) 미만으로 3초 지속 시 일시정지
- **조용한 환경 최적화**: 기본 임계값을 0.006으로 낮추고 4초 무음 후 일시정지해 작은 목소리도 안정적으로 기록
- **용량 절약**: 실제 대화만 녹음하여 파일 크기 50% 절약(측정 진행 중)
- **에너지 기반 감지**: 간단하고 빠른 RMS 기반 구현
- **사용자 조정 가능**: VAD 토글 및 임계값 슬라이더 제공

### 2.3 사용자 인터페이스

#### 2.3.1 메인 화면
```
┌─────────────────────────────────────┐
│  아이보틀 진료 녹음                  │
├─────────────────────────────────────┤
│                                     │
│  🎤 [●] 녹음 중 (14:30 시작)        │
│  📊 ████████░░ 볼륨 레벨            │
│  💾 오늘 녹음: 3시간 25분            │
│                                     │
│  📅 진료 시간표 설정                │
│  📁 저장 폴더 설정                  │
│  ⚙️  고급 설정                     │
│                                     │
│  [일시정지] [중지] [설정]            │
│                                     │
└─────────────────────────────────────┘
```

- **도움말 & 튜토리얼**: 헤더와 트레이 메뉴에서 사용법 다이얼로그와 쇼케이스 튜토리얼 실행 가능

#### 2.3.2 시스템 트레이
- **상태 아이콘**: 녹음 중(빨강), 대기(초록), 오류(노랑)
- **우클릭 메뉴**: 빠른 시작/정지, 설정, 종료
- **최소화 지원**: 창 닫아도 백그라운드에서 계속 동작

### 2.4 파일 저장 및 관리

#### 2.4.1 로컬 저장
- **임시 저장소**: `C:\Users\[사용자]\AppData\Local\EyebottleRecorder\temp\`
- **최종 저장소**: 사용자 지정 폴더 (기본: OneDrive 연동 폴더)
- **백업 정책**: 로컬 7일 보관 후 자동 정리

#### 2.4.2 OneDrive 동기화
```javascript
// OneDrive 폴더 설정 예시
const saveConfig = {
  localPath: 'C:\\Users\\UserName\\Documents\\진료녹음\\',
  oneDrivePath: 'C:\\Users\\UserName\\OneDrive\\진료녹음\\',
  autoSync: true
};
```
- **폴더 기반 동기화**: API 없이 OneDrive 동기화 폴더 활용
- **자동 업로드**: 파일 생성 시 OneDrive가 자동으로 클라우드 동기화
- **오프라인 지원**: 네트워크 끊김 시 로컬 저장, 연결 시 자동 동기화

### 2.5 구현 현황 요약 (2025-09-16)
- **완료**: 진료 시간표 기반 자동 시작/중지, 10분 단위 분할, VAD 기반 무음 일시정지(임계값 0.01), 저장 폴더 지정/SharedPreferences 연동, 시스템 트레이 초기화 및 상태 전환(아이콘 파일 필요).
- **부분 구현**: 오늘 누적 녹음 시간 표시는 UI 플레이스홀더 수준(실제 집계 로직 미구현), OneDrive 동기화는 사용자가 OneDrive 폴더를 선택해 동기화 클라이언트에 위임(상태 감시는 미구현).
- **미구현/향후 과제**: 알림(Toast), 오류 경고 노출, 휴진일 예외, 글로벌 단축키, 동기화 지연 감지, 장기 보관 정책 설정 UI, 자동 실행 경로 고정 및 실패 피드백.

---

## 3. 기술 아키텍처 (Flutter 전환)

### 3.1 핵심 기술 스택

#### 3.1.1 플랫폼 및 프레임워크
```json
{
  "platform": "Windows Desktop (개발: Windows + WSL 파일시스템)",
  "framework": "Flutter 3.24+",
  "language": "Dart 3.0+",
  "toolchain": "Windows 10/11 + Visual Studio C++ Desktop",
  "preview": "Android Studio / Windows 데스크톱 디바이스"
}
```

#### 3.1.2 주요 라이브러리 (pubspec.yaml)
```yaml
dependencies:
  flutter:
    sdk: flutter
  # 오디오 녹음/레벨
  record: ^6.1.1            # Windows/Android/iOS/macOS 지원, AAC/WAV 등
  # 파일/저장/설정
  path_provider: ^2.1.4
  shared_preferences: ^2.3.2
  # 스케줄링
  cron: ^0.5.1
  # 데스크톱 통합
  system_tray: ^2.0.3
  window_manager: ^0.5.1
  launch_at_startup: ^0.5.1 # Windows 시작프로그램 등록
  permission_handler: ^11.3.1
  # 유틸
  logger: ^2.4.0
  package_info_plus: ^8.0.1

dev_dependencies:
  msix: ^3.16.7             # Windows 패키징 (MSIX)
```

#### 3.1.3 개발 환경 (WSL + Android Studio)
- 코드 저장소는 WSL(예: `/home/<user>/projects/eyebottlelee`)에 유지.
- Android Studio(Windows)에서 `\\wsl$\<배포판>\home\<user>\projects\eyebottlelee` 경로를 직접 열어 개발/미리보기.
- Flutter SDK와 Visual Studio C++ 툴체인은 Windows에 설치하고, `flutter config --enable-windows-desktop` 설정.
- 미리보기/디버깅은 Android Studio에서 `Windows (desktop)` 디바이스 또는 Android 에뮬레이터를 사용.

### 3.2 시스템 아키텍처

#### 3.2.1 앱 구조
```
Flutter App
├── UI Layer (Material 3 Widgets)
├── State (Provider/Riverpod 중 택1)
├── Services
│   ├── AudioService (record)
│   ├── ScheduleService (cron)
│   ├── FileService (path_provider)
│   └── TrayService (system_tray / window_manager)
└── Platform (Windows APIs via plugins)
```

#### 3.2.2 데이터 플로우
```
[마이크 입력]
    ↓ record (Windows Media Foundation)
[오디오 스트림/레벨]
    ↓ (선택) VAD 처리 (RMS 임계값)
[무음 구간 스킵]
    ↓ 인코딩 (AAC-LC 64kbps, M4A)
[10분 단위 분할 저장]
    ↓ OneDrive 동기화 폴더
[클라우드 백업]
```

### 3.3 핵심 모듈 설계 (Dart)

#### 3.3.1 AudioService (녹음/분할/VAD/레벨)
```dart
class AudioService {
  final _recorder = Record();
  StreamSubscription<Amplitude>? _ampSub;
  Timer? _segmentTimer;
  bool _vadEnabled = true;
  double vadThreshold = 0.006; // RMS 근사값 기준

  Future<void> start({required String path, Duration segment = const Duration(minutes: 10)}) async {
    // Windows에선 OS 권한 창이 없을 수 있음. 공통 처리 유지.
    final hasPermission = await _recorder.hasPermission();
    if (hasPermission ?? true) {
      await _recorder.start(
        path: path,
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        numChannels: 1,
        samplingRate: 16000,
      );

      _segmentTimer = Timer.periodic(segment, (_) => split());

      _ampSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 200)).listen((amp) {
        // UI에 레벨 반영
        // 간단 VAD: 평균 레벨이 임계치 미만이면 일시 정지/재개 로직
        if (_vadEnabled) {
          final level = (amp.current ?? 0).abs() / 32768.0; // 정규화 근사
          // VAD 로직은 MVP에선 모니터링/표시 중심, 실제 일시정지는 선택 적용
        }
      });
    }
  }

  Future<void> split() async {
    final wasRecording = await _recorder.isRecording();
    if (wasRecording) {
      final currentPath = await _recorder.stop();
      // 새 파일 경로 생성 후 즉시 재시작
      final nextPath = _FileNamer.nextSegmentPath(baseDir: await _defaultDir());
      await _recorder.start(
        path: nextPath,
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        numChannels: 1,
        samplingRate: 16000,
      );
      // currentPath를 FileService에 전달해 후처리(인덱싱/정리)
    }
  }

  Future<void> stop() async {
    await _recorder.stop();
    await _ampSub?.cancel();
    _segmentTimer?.cancel();
  }

  Future<String> _defaultDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'EyebottleRecorder');
  }
}
```

#### 3.3.2 ScheduleService (진료 시간표 기반 크론)
```dart
class ScheduleService {
  final _cron = Cron();

  void apply(WeeklySchedule schedule, void Function() onStart, void Function() onStop) {
    _cron.close();
    // 요일/시간대 별 시작/종료 작업 등록 (예: 월-금 09:00~18:00, 점심 제외)
    for (final job in schedule.toCronJobs()) {
      _cron.schedule(job.startExpr, onStart);
      _cron.schedule(job.stopExpr, onStop);
    }
  }
}
```

#### 3.3.3 TrayService / WindowService
```dart
class TrayService {
  Future<void> init() async {
    await SystemTray().initSystemTray(
      title: '아이보틀 진료 녹음',
      toolTip: '상태 표시',
      iconPath: 'assets/icon.ico',
    );
    // 메뉴: 시작/일시정지/중지/설정/종료
  }
}
```

### 3.4 권한/보안
- Windows: 마이크 권한은 OS 수준 관리. `record.hasPermission()`은 플랫폼별 동작 차이가 있음. UI에서 장치 탐지/레벨 표시로 사전 검증 제공.
- 저장: `path_provider`로 앱 데이터 폴더 사용, 사용자 지정 시 OneDrive 동기화 폴더 권장.
- 자동 시작: `launch_at_startup`로 Run 레지스트리 등록.

---

## 4. 사용자 경험 설계

### 4.1 초기 설정 플로우

#### 4.1.1 온보딩 프로세스 (3단계)
```
단계 1: 진료 시간표 설정
┌─────────────────────────────────────┐
│  진료 시간표를 설정해주세요          │
├─────────────────────────────────────┤
│  월요일: [09:00] - [18:00]          │
│  화요일: [09:00] - [18:00]          │
│  ...                                │
│  점심시간: [12:00] - [13:00]        │
│                                     │
│  [다음 단계]                        │
└─────────────────────────────────────┘

단계 2: 저장 폴더 선택
┌─────────────────────────────────────┐
│  녹음 파일을 저장할 폴더를 선택하세요 │
├─────────────────────────────────────┤
│  📁 C:\Users\Doctor\OneDrive\진료녹음 │
│                                     │
│  ☐ OneDrive 동기 상태 확인(가이드)   │
│  ✅ 윈도우 시작 시 자동 실행 토글     │
│                                     │
│  [폴더 변경] [완료]                  │
└─────────────────────────────────────┘

※ OneDrive 동기화는 사용자가 OneDrive 폴더를 선택하고 클라이언트가 동작한다는 전제이며, 앱 내 실시간 동기 상태 감지는 향후 추가 예정이다.

단계 3: 설정 완료
┌─────────────────────────────────────┐
│  🎉 설정이 완료되었습니다!           │
├─────────────────────────────────────┤
│  내일부터 진료 시간에 자동으로       │
│  녹음이 시작됩니다.                 │
│                                     │
│  💡 시스템 트레이에서 상태를         │
│     확인할 수 있습니다.             │
│                                     │
│  [테스트 녹음] [완료]               │
└─────────────────────────────────────┘
```

### 4.2 일상 사용 시나리오 (목표)

※ 1차 MVP에는 진료 전 알림/일일 요약 알림/트레이 색상 전환/글로벌 단축키가 포함되어 있지 않으며, 아래 시나리오는 향후 확장 목표를 설명한다.

#### 4.2.1 자동 운영 모드
1. **아침 8:55**: (계획) 시스템이 진료 시작 5분 전 알림 표시
2. **오전 9:00**: 자동으로 녹음 시작, (계획) 트레이 아이콘 빨간색 변경
3. **오전 9:10**: 첫 번째 10분 파일 자동 저장, 새 녹음 세션 시작
4. **점심시간**: 자동 중단, (계획) 트레이 아이콘 회색 변경
5. **오후 1:00**: 자동 재개
6. **오후 6:00**: 자동 종료, (계획) 하루 녹음 요약 알림

#### 4.2.2 수동 제어
- **긴급 중단**: 트레이 아이콘 우클릭 → "일시정지" (아이콘 파일 배포 필요)
- **중요 구간 마킹**: (계획) Ctrl+M 단축키로 현재 시점 마킹
- **즉시 녹음**: 진료 시간 외에도 수동 녹음 가능

### 4.3 문제 상황 대응

#### 4.3.1 오류 처리
```dart
// 오류 상황별 사용자 알림 (예시)
const errorMessages = {
  'microphoneNotFound': '마이크를 찾을 수 없습니다. 연결을 확인해주세요.',
  'diskSpaceLow': '저장 공간이 부족합니다. 파일을 정리해주세요.',
  'oneDriveNotSynced': 'OneDrive 동기화가 지연되고 있습니다.',
  'recordingInterrupted': '녹음이 중단되었습니다. 다시 시작하시겠습니까?'
};
```

※ 오류 메시지 매핑은 향후 구현 예정인 알림/로그 시스템을 위한 사전 정의 단계이다.

#### 4.3.2 복구 메커니즘
- **자동 재시작**: (계획) 오류 발생 시 30초 후 자동 재시도
- **백업 저장**: (계획) OneDrive 동기화 실패 시 로컬 백업 폴더에 저장
- **상태 복원**: SharedPreferences로 기본 설정은 복원, 세션 상태 복원은 향후 과제

---

## 5. 개발 계획

### 5.1 단계별 구현 로드맵

#### 5.1.1 Week 1: 기본 기능 구현 (Flutter)
```dart
// 구현 목표
final week1Goals = {
  '기본녹음': 'record 패키지로 녹음 시작/정지',
  '파일분할': '10분 단위 자동 분할 메커니즘',
  '마이크모니터링': 'onAmplitudeChanged 기반 레벨 표시',
  '기본UI': 'Material 3 메인 화면 및 조작 버튼'
};
```
- **상태**: 2025-09-16 기준 완료 (기능 호출 및 UI 확인)

#### 5.1.2 Week 2: 자동화 시스템
```dart
final week2Goals = {
  '진료시간표': '요일별 시간 설정 UI 및 저장',
  '스케줄링': 'cron 패키지 기반 자동 시작/종료',
  '시스템트레이': 'system_tray + window_manager 통합',
  '자동시작': 'launch_at_startup로 부팅 시 자동 실행'
};
```
- **상태**: 스케줄/트레이 적용 완료, 자동 실행은 개발 경로 제약으로 베타(추가 검증 필요)

#### 5.1.3 Week 3: 최적화 기능
```dart
final week3Goals = {
  'VAD구현': 'RMS 임계값 기반 간단 VAD (옵션)',
  '파일압축': 'AAC-LC 64kbps(M4A) 인코딩 최적화',
  'OneDrive연동': '동기화 폴더 기반 자동 업로드',
  '설정관리': 'shared_preferences 기반 설정 저장/불러오기'
};
```
- **상태**: VAD·압축·설정 저장 구현, OneDrive 동기 상태 감시는 미구현(폴더 지정만 지원)

#### 5.1.4 Week 4: 완성 및 배포
```dart
final week4Goals = {
  '품질보장': '8시간 연속 녹음 테스트',
  '패키징': 'flutter build windows + msix',
  '문서화': '사용자 매뉴얼 및 설치 가이드',
  '배포준비': 'GitHub Releases 업로드'
};
```
- **상태**: 진행 예정 (테스트 자동화/CI·MSIX 패키징 미착수)

### 5.2 기술적 고려사항

#### 5.2.1 성능 최적화
- **메모리 관리**: 10분 세그먼트 재시작 시 자동 초기화(추가 모니터링 필요)
- **CPU 사용량**: VAD 간소화로 평균 부하 낮음(지표 수집 예정)
- **디스크 I/O**: 기본 파일 쓰기 사용(배치 최적화는 향후 검토)

#### 5.2.2 안정성 보장
- **예외 처리**: 주요 녹음/파일 작업에 try-catch 적용(세부 오류 메시지 추가 예정)
- **상태 저장**: 스케줄/VAD/폴더 설정은 SharedPreferences에 저장, 녹음 세션 상태는 향후 과제
- **로그 시스템**: `logger` 패키지 의존성 추가, 실제 로깅 구성은 TODO

### 5.3 테스트 계획

#### 5.3.1 단위 테스트
- AudioRecorder 클래스 테스트
- ScheduleManager 기능 테스트  
- VADProcessor 성능 테스트
- FileManager 안정성 테스트

#### 5.3.2 통합 테스트
- 8시간 연속 녹음 안정성 테스트
- OneDrive 동기화 신뢰성 테스트
- 시스템 재시작 후 복원 테스트
- 다양한 마이크 호환성 테스트

---

## 6. 배포 및 유지보수

### 6.1 배포 전략

#### 6.1.1 패키징
```yaml
# pubspec.yaml (발췌)
dev_dependencies:
  msix: ^3.16.7

msix_config:
  display_name: 아이보틀 진료 녹음
  publisher_display_name: Eyebottle
  identity_name: kr.eyebottle.medical_recorder
  msix_version: 1.1.0.0
  logo_path: assets/icons/icon.ico
  capabilities:
    - microphone
    - internetClient

# 빌드/패키징
$ flutter build windows --release
$ dart run msix:create
```

#### 6.1.2 배포 채널
- **GitHub Releases**: 주요 버전 릴리스
- **아이보틀 웹사이트**: 다운로드 페이지 제공
- **직접 배포**: USB/이메일을 통한 개인 배포

### 6.2 업데이트 관리

#### 6.2.1 버전 정책
```javascript
// 시맨틱 버저닝
const versionPolicy = {
  major: "주요 기능 추가 또는 호환성 변경",
  minor: "새 기능 추가 (하위 호환)",
  patch: "버그 수정 및 성능 개선"
};
```

#### 6.2.2 자동 업데이트 (향후)
- 현재: 수동 다운로드 방식
- 향후: MSIX 배포 채널/winget 등록 검토
- 보안: 코드 서명(Windows 코드 서명 인증서) 적용 후 자동 업데이트 채널 구성

### 6.3 사용자 지원

#### 6.3.1 문서화
- **설치 가이드**: 스크린샷 포함 단계별 설치 방법
- **사용자 매뉴얼**: 주요 기능 사용법
- **FAQ**: 자주 묻는 질문과 해결책
- **문제 해결 가이드**: 일반적인 오류 상황 대응법

#### 6.3.2 피드백 수집
- **앱 내 피드백**: 설정 화면에서 피드백 전송 기능
- **GitHub Issues**: 버그 리포트 및 기능 요청
- **직접 연락**: 이메일을 통한 개인 지원

---

## 7. 성공 평가 및 향후 계획

### 7.1 단기 목표 (1개월)

#### 7.1.1 MVP 완성
- [x] 기본 녹음 기능 구현
- [x] 10분 단위 파일 분할
- [x] 진료 시간표 자동화
- [x] OneDrive 폴더 동기화
- [x] 안정적인 8시간 연속 녹음

#### 7.1.2 성능 지표
- **안정성**: 99% 업타임 (8시간 중 57분 이상)
- **정확성**: 녹음 누락 0%
- **효율성**: VAD로 평균 50% 용량 절약
- **사용성**: 평균 설정 시간 3분 이내

### 7.2 중기 계획 (3-6개월)

#### 7.2.1 기능 확장
```javascript
// 추가 예정 기능
const futureFeatures = {
  선택적STT: "OpenAI Whisper API 연동 (선택적)",
  검색기능: "녹음 파일 내용 검색",
  태그시스템: "중요 구간 마킹 및 분류",
  통계대시보드: "일일/주간/월간 녹음 통계"
};
```

#### 7.2.2 플랫폼 확장
- **macOS/리눅스**: Flutter Desktop 확장 고려
- **웹 버전**: 간단한 관리 인터페이스 (Flutter Web, 관리자용)
- **모바일 앱**: 보조 도구로 활용 (원격 제어/상태 확인)

### 7.3 장기 비전 (1년+)

#### 7.3.1 상업화 준비
- **보안 강화**: HIPAA 준수 수준 보안 구현
- **다중 사용자**: 병원 단위 계정 관리
- **클라우드 서비스**: 전용 클라우드 스토리지 제공
- **API 제공**: 타 의료 시스템 연동

#### 7.3.2 수익 모델
```javascript
// 수익화 방안
const businessModel = {
  freemium: {
    무료: "기본 녹음 + OneDrive 연동",
    유료: "STT + 검색 + 클라우드 스토리지"
  },
  enterprise: {
    개인: "월 9,900원 (STT 포함)",
    병원: "월 29,900원 (다중 사용자)"
  }
};
```

---

## 8. 결론

### 8.1 프로젝트 요약
아이보틀 진료 녹음은 의료진의 실제 니즈에서 시작된 실용적인 솔루션입니다. 진료 시간표 기반 완전 자동화를 통해 별도 조작 없이도 모든 진료 대화를 안전하게 기록하고 관리할 수 있습니다.

### 8.2 핵심 가치 제안
- **완전 자동화**: 설정 후 개입 없는 자동 운영
- **비용 효율성**: 월 운영비 0원의 무료 솔루션  
- **의료 특화**: 진료실 환경에 최적화된 기능들
- **즉시 사용**: 복잡한 설정 없이 3분 내 사용 시작

### 8.3 차별화 포인트
기존 녹음 앱들이 수동 조작에 의존하는 반면, 아이보틀 진료 녹음은 의료진의 워크플로우를 깊이 이해한 자동화 솔루션입니다. 이를 통해 진료에만 집중할 수 있는 환경을 제공합니다.

### 8.4 기대 효과
- **시간 절약**: 녹음 조작에 소요되는 시간 제거
- **기록 완성도**: 누락 없는 완전한 진료 기록
- **업무 효율성**: 진료 후 차트 작성 시간 단축
- **환자 만족도**: 진료에 더 집중할 수 있는 환경

이 PRD를 바탕으로 4주 내에 완성도 높은 MVP를 개발하여, 의료진의 진료 기록 작성 부담을 근본적으로 해결하고자 합니다.

---

## 9. WSL + Android Studio 개발 환경

### 9.1 원칙
- 빌드/실행은 Windows의 Flutter 툴체인으로 수행하고, 코드는 WSL 파일시스템에 보관합니다.
- Android Studio(Windows)로 `\\wsl$` 경로의 프로젝트를 직접 열어 Hot Reload/디버깅합니다.

### 9.2 준비 절차 (Windows)
- Flutter SDK 설치 후 채널: stable, `flutter doctor` 통과.
- Visual Studio 2022: "Desktop development with C++" 워크로드 설치.
- `flutter config --enable-windows-desktop` 활성화.
- Android Studio에 Flutter/Dart 플러그인 설치 및 Flutter SDK 경로 지정.

### 9.3 실행/미리보기
- 디바이스 선택: `Windows (desktop)` 또는 Android 에뮬레이터.
- 실행: `flutter run -d windows` 또는 IDE Run. Hot Reload로 UI 변경 사항 확인.

### 9.4 파일/경로 가이드
- 기본 저장 경로는 `path_provider`의 앱 문서 디렉터리 사용.
- OneDrive 동기화 폴더 선택 시 Windows 사용자 프로필 하위의 OneDrive 경로를 UI로 선택하도록 제공.
- 런타임(Windows 앱)에서 WSL 내부 경로를 직접 접근하지 않습니다.

---

**문서 버전**: 1.1  
**최종 수정**: 2025-09-13  
**작성자**: 아이보틀 개발팀  
**승인자**: 이안과 원장
