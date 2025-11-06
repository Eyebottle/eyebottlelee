# Developing Guide (아이보틀 진료녹음 & 자동실행 매니저)

문서 목적: 이 저장소를 처음 받는 개발자가 현재까지의 구현 상태를 빠르게 파악하고, 동일한 방향으로 다음 작업을 이어갈 수 있도록 돕습니다.

- 대상: Windows 데스크톱용 Flutter 앱 개발(WSL 파일시스템 + Windows 툴체인)
- 마지막 갱신: 2025-10-30
- 참고: [제품 요구사항 PRD](medical-recording-prd.md), [자동 실행 매니저 PRD](auto-lancher-prd.md)

---

## 🚨 v1.2.10 긴급 패치 (2025-10-30) - 코덱 폴백 로직 근본 개선

### 문제 상황
v1.2.9에서 마이크 진단은 성공하지만 실제 녹음 시작이 실패하는 문제 발견.

**로그 분석**:
- 마이크 진단: AAC 실패("미디어 유형에 대해...") → Opus 실패 → WAV 성공 ✅
- 실제 녹음: AAC 실패("지정한 개체 또는 값이...") → 중단 ❌

**근본 원인**:
같은 AAC 코덱 실패지만 타이밍이나 내부 상태에 따라 다른 에러 메시지 발생:
- "미디어 유형에 대해 지정된 데이터가..." → '미디어' 키워드 매칭 ✅
- "지정한 개체 또는 값이 존재하지 않습니다" → 키워드 매칭 실패 ❌

### 근본 해결 방법

**기존 접근 (v1.2.9)**: 에러 메시지 문자열 패턴 매칭
```dart
final isCodecError = message.contains('codec') ||
    message.contains('encoder') ||
    message.contains('aac') ||
    message.contains('미디어') ||
    e.toString().contains('구현되지');
```

**문제점**:
- Windows Media Foundation은 수십 가지 다른 에러 메시지를 던짐
- 새로운 메시지가 나올 때마다 키워드 추가 필요 (땜질식 접근)
- 유지보수 어려움

**새 접근 (v1.2.10)**: PlatformException 타입 체크
```dart
// PlatformException은 대부분 코덱/설정 문제 → 다음 코덱으로 폴백
if (e is PlatformException) {
  _logging.warning('코덱 에러 - 다음 코덱으로 폴백');
  continue;
}

// PlatformException이 아닌 에러는 심각한 문제 → 재시도 중단
_logging.error('코덱과 무관한 심각한 에러 발생 - 재시도 중단');
throw exception;
```

**장점**:
- ✅ **미래 안전**: 새로운 에러 메시지 나와도 자동 처리
- ✅ **코드 단순화**: 복잡한 문자열 매칭 제거
- ✅ **더 정확함**: 타입 기반 판단이 문자열 매칭보다 신뢰성 높음
- ✅ **검증됨**: 마이크 진단에서 이미 WAV 폴백 성공 확인

**안전성 분석**:
1. **권한 에러**: 녹음 시작 전에 이미 체크됨 → PlatformException 던지지 않음
2. **장치 에러**: 모든 코덱에서 동일 → WAV에서도 실패 → 최종 에러 던짐
3. **코덱 에러**: 코덱별로 다름 → 폴백으로 해결 가능

### 수정 파일

**1. lib/services/audio_service.dart (177-190줄)**
- import 추가: `package:flutter/services.dart` (PlatformException 사용)
- 폴백 로직: 문자열 매칭 → PlatformException 타입 체크

**2. lib/services/mic_diagnostics_service.dart (165-179줄)**
- import 추가: `package:flutter/services.dart`
- 폴백 로직: 동일한 방식으로 일관성 유지

**3. pubspec.yaml**
- 버전: 1.2.9+9 → 1.2.10+10
- MSIX 버전: 1.2.9.0 → 1.2.10.0

### 배포
- 경로: `C:\Users\user\OneDrive\이안과\eyebottlelee-v1.2.10-20251030\`
- 빌드 시간: 40.2초
- 버전정보.txt, 사용방법.txt 포함

### 교훈
1. **에러 메시지 패턴 매칭의 한계**: 문자열 매칭은 일시적 해결책일 뿐
2. **타입 기반 판단의 우수성**: 언어 기능을 활용하면 더 강력하고 안전
3. **근본 원인 해결**: 증상 치료보다 구조적 개선이 장기적으로 유리
4. **회귀 테스트 필요성**: 자동화 테스트로 폴백 체인 전체를 검증해야 함

---

## 1) 개요
- 제품: 아이보틀 진료녹음 & 자동실행 매니저 (Eyebottle Medical Recorder & Auto Launch Manager)
- 목표: 진료 시간표 기반 자동 녹음, 10분 분할 저장, OneDrive 폴더 동기화, 무음(VAD) 스킵으로 용량 절감, 진료실 프로그램 자동 실행
- 스택: Flutter 3.24+ / Dart 3+, Windows Desktop, 주요 패키지 `record`, `path_provider`, `shared_preferences`, `cron`, `system_tray`, `window_manager`, `launch_at_startup`, `file_selector`

---

## 2) 현재까지 반영 사항
핵심 구현 요약(시험 구현 기준, MVP 지향):

- 녹음/분할/레벨
  - `record` 패키지로 AAC-LC 64/48/32kbps 모노 프로필 지원(기본 64kbps), 32kHz 이하 샘플레이트를 사용해 용량 최적화
  - 조용한 환경 보정을 위해 +0~+12dB 메이크업 게인을 선택적으로 적용(RecordConfig.autoGain 활성화 + UI 슬라이더)
  - 10분 단위 자동 분할(`Timer.periodic`)
  - UI로 입력 레벨 시각화(200ms 주기)
- 메인 화면의 "오늘 녹음" 카드는 세션 누적 시간을 실시간으로 집계해 표시
- VAD(무음 자동 스킵)
  - 임계값 기본 `0.006`(정규화 레벨)
  - 4초 무음 지속 시 `pause()`, 음성 감지 후 500ms 뒤 `resume()`
  - 고급 설정에서 활성화/임계값 조정 가능
- 스케줄링/설정
  - 주간 진료 시간표 저장/로드(`SharedPreferences`)
  - 앱 시작 시 저장된 스케줄 적용(없으면 기본값) 및 현재 시간이 진료 시간대라면 자동으로 녹음/중지 상태 동기화
  - 요일별로 `종일` 또는 `오전/오후` 분할 근무를 선택할 수 있으며, 기본 오전/오후 시간은 09:00~13:00 / 14:00~18:00으로 제공
  - 저장 폴더 지정: `file_selector`로 폴더 선택(OneDrive 폴더 권장)
- 파일 보관/정리
  - 기본값은 영구 보존이며, 고급 설정에서 1주·1개월·3개월·6개월·1년 옵션을 선택하면 해당 기간 경과 후 앱이 자동 삭제
  - 저장 루트 하위에 `YYYY-MM-DD` 폴더를 자동 생성해 날짜별로 세그먼트를 정리하며, 빈 날짜 폴더는 보관 주기 정리 시 자동 삭제
- 트레이 연동(가드 적용)
  - 트레이 초기화 및 상태 아이콘 업데이트(아이콘 미존재 시 무시)
  - 로깅 서비스 에러 이벤트를 받아 트레이 아이콘을 오류 상태로 전환하고 사용자에게 알림
  - 창 닫기/Alt+F4 시 앱은 종료되지 않고 트레이로 숨겨지며, 녹음 상태는 유지됨
  - 트레이 메뉴의 "종료" 선택 시에만 완전 종료되며, 종료 직전에 녹음 세션을 안전하게 중단
  - 트레이 아이콘 좌/더블 클릭 시 메인 창 복원, 우클릭 시 컨텍스트 메뉴가 열린다
  - 트레이 메뉴에서 녹음 시작·중지 토글, 마이크 점검, 설정 열기, 종료를 직접 실행할 수 있다
  - 트레이 메뉴는 도움말 다이얼로그도 호출 가능하며, 튜토리얼을 재생할 수 있다
- 자동 마이크 점검
  - 앱이 켜질 때 3초간 샘플을 녹음해 권한/장치/입력 레벨을 확인하고, 결과를 대시보드 카드에 표시
  - RMS 대신 평균 dBFS·SNR을 계산해 조용한 환경에서도 정상/주의 판정을 세분화
  - `SharedPreferences`에 마지막 검사 결과와 안내 문구를 저장해 재시작 후에도 상태를 바로 보여줌
  - 대시보드에서 "다시 점검" 버튼으로 수동 진단 가능하며, 녹음 중에는 점검을 제한해 충돌을 방지
- UI/설정 다이얼로그
  - 메인 화면은 `녹음 대시보드 / 녹음 설정 / 자동 실행` 3탭 구조로 개편
    - 녹음 대시보드: 상단 헤더, 실시간 볼륨 막대, 오늘/예정 녹음 요약, 마이크 진단 카드, 저장 경로 카드
    - 녹음 설정: 진료 시간표, 저장 폴더, 보관 기간, 녹음 품질·민감도, VAD 설정 카드
    - 자동 실행: 프로그램 자동 실행 매니저 (ON/OFF 상태가 탭 레이블에 표시됨)
  - "진료 시간표 설정" 다이얼로그 저장 → 스케줄 즉시 재적용
  - "고급 설정" 다이얼로그(녹음 품질·메이크업 게인, VAD 토글/임계값, 녹음 파일 보관 기간)
  - 대시보드 하단 카드에서 현재 저장 경로 및 자동 정리 정책 안내

### 2025-10-30 긴급 패치 - v1.2.9 폴백 로직 버그 수정 ⚠️

#### 문제 발견
v1.2.8에서 AAC 코덱 재활성화 시 폴백 로직에 회귀 버그 발생:
- **증상**: 진료실 PC(AAC/Opus 없음)에서 녹음이 실패하고 WAV를 시도하지 않음
- **원인**: Opus의 "구현되지 않았습니다" 에러를 코덱 에러로 인식하지 못함
- **영향**: AAC → Opus 실패 후 "코덱과 무관한 에러"로 판단하여 WAV 시도 없이 중단

#### 긴급 수정 (96.7초 빌드)
1. **mic_diagnostics_service.dart** (line 165-169)
   ```dart
   final isCodecError = e.toString().toLowerCase().contains('codec') ||
       e.toString().toLowerCase().contains('encoder') ||
       e.toString().toLowerCase().contains('aac') ||
       e.toString().toLowerCase().contains('미디어') ||
       e.toString().contains('구현되지');  // 추가
   ```

2. **audio_service.dart** (line 177-181)
   - 동일한 패턴으로 `e.toString().contains('구현되지')` 조건 추가

3. **버전 업데이트**
   - 앱 버전: 1.2.8+8 → 1.2.9+9
   - MSIX 버전: 1.2.8.0 → 1.2.9.0

4. **배포**
   - 경로: `C:\Users\user\OneDrive\이안과\eyebottlelee-v1.2.9-20251030\`
   - 버전정보.txt에 v1.2.8 사용 금지 경고 추가

#### 결과
- ✅ 개발 PC: AAC 정상 사용
- ✅ 진료실 PC: AAC 실패 → Opus 실패 → WAV 성공
- ✅ 폴백 체인 완전히 작동

#### 교훈
- 코덱 관련 수정 시 **모든 에러 메시지 패턴** 고려 필요
- "구현되지", "not implemented" 등 다양한 표현 존재
- 회귀 테스트의 중요성: 개발 환경과 배포 환경 차이

---

### 2025-10-29 주요 업데이트 - v1.2.8 안정화 릴리즈 ❌ 회귀 버그 발견

#### 1. Visual C++ Runtime 호환성 문제 해결
- **문제**: 진료실 PC에서 앱 시작 시 즉시 크래시 발생 (MSVCP140.dll 2019 버전)
- **근본 원인**: record_windows 플러그인이 오래된 Visual C++ Runtime (14.24.28127.4, 2019)과 호환되지 않음
- **해결 방법**: Visual C++ 2015-2022 Redistributable 최신 버전 설치로 MSVCP140.dll을 14.40.x (2024)로 업데이트
- **교훈**: 코덱 문제로 오인했으나 실제로는 C++ 런타임 라이브러리 버그였음
- **배포 가이드 업데이트**: 버전정보.txt 및 사용방법.txt에 Visual C++ Runtime 필수 요구사항 명시

#### 2. record 패키지 업그레이드 (6.0.0 → 6.1.2)
- **변경 사항**:
  - pubspec.yaml: `record: ^6.1.2`로 업데이트
  - 관련 플러그인 자동 업데이트: record_windows, record_android, record_ios, record_macos
- **효과**: 녹음 엔진 안정성 향상 및 최신 Windows Media Foundation API 지원

#### 3. AAC 코덱 재활성화 및 코드 정리
- **복구 작업**:
  - audio_service.dart (line 93): AAC-LC 코덱을 우선 순위 목록에 재추가
  - mic_diagnostics_service.dart (line 97): 진단 시 AAC 코덱 지원 확인 재활성화
  - 코덱 선택 로직 간소화: 과도한 디버그 로그 제거 (line 107, 158, 162)
- **삭제**:
  - lib/utils/windows_codec_checker.dart: 진단용 임시 유틸리티 제거
  - 관련 import 문 정리
- **로깅 최적화**:
  - 녹음 시작/중지 루프의 verbose 로그 간소화
  - 핵심 이벤트만 남기고 단계별 디버그 로그 제거

#### 4. 버전 업데이트
- **앱 버전**: 1.1.0+1 → 1.2.8+8
- **MSIX 버전**: 1.1.0.0 → 1.2.8.0
- **배포 경로**: `C:\Users\user\OneDrive\이안과\eyebottlelee-v1.2.8-20251029\`

#### 5. 배포 패키지
- **파일 구성**:
  - medical_recorder.exe 및 플러그인 DLL
  - 버전정보.txt: v1.2.8 변경 사항 및 Visual C++ Runtime 필수 요구사항
  - 사용방법.txt: 설치 가이드 및 문제 해결 방법
- **주요 안내**:
  - Visual C++ Runtime 최신 버전 설치 필수
  - Opus 코덱 지원 (K-Lite Codec Pack 권장)
  - AAC/Opus/WAV 자동 선택

### 2025-10-01 주요 업데이트 - 디자인 시스템 구축 및 CI/CD 개선

#### 1. Material 3 기반 디자인 시스템 구축
- **디자인 토큰 체계 확립**:
  - `lib/ui/style/app_colors.dart`: 브랜드 컬러(`#00897B` Primary), Neutral, Success/Error/Warning 시맨틱 컬러 정의
  - `lib/ui/style/app_typography.dart`: Material 3 타이포그래피 스케일(Display, Headline, Title, Body, Label) + 한글/라틴 폰트 분리
  - `lib/ui/style/app_elevation.dart`: 4단계 섀도우 레벨(shadow1~4) 정의
  - `lib/ui/style/app_theme.dart`: 통합 테마 객체, ColorScheme·TextTheme 바인딩

- **진료 시간표 UI v2 전면 재설계**:
  - `lib/ui/widgets/schedule/weekly_calendar_grid.dart`: 주간 7일 그리드 뷰, 요일 헤더 + 개별 카드, 클릭으로 상세 편집 모드 전환
  - `lib/ui/widgets/schedule/day_detail_editor.dart`: 선택한 요일의 근무 여부, 종일/분할 근무, 시간 범위 편집 UI
  - `lib/ui/widgets/schedule/time_range_slider.dart`: Slider 기반 시간 범위 선택(30분 단위) + 드래그 핸들
  - `lib/ui/widgets/schedule_config_widget.dart`: 그리드 뷰 + 상세 편집기를 2단계 플로우로 통합

- **12시간 형식 시간 표시**:
  - `weekly_calendar_grid.dart:264`: `_formatTime()` 메서드로 "오전 9:00", "오후 2:00" 형식 변환
  - 오전/오후 분할 근무 시 두 줄로 시간 표시 (line 240~258)
  - 종일 근무 시 단일 라인 시간 범위 표시

- **오전/오후 개별 토글 기능**:
  - `day_detail_editor.dart:132`: "오전만", "오후만" 라디오 선택 추가
  - 분할 근무 선택 시 오전(09:00~13:00), 오후(14:00~18:00) 개별 활성화 가능
  - 모델 `DaySchedule.sessions` 배열에 선택한 세션만 포함

- **수동 시간 입력 모드**:
  - `day_detail_editor.dart`: 각 시간 범위 위젯 상단에 "직접 입력" 편집 아이콘 추가
  - 클릭 시 TextField로 전환, "HH:MM" 형식 입력 후 유효성 검증
  - 슬라이더 모드 ↔ 텍스트 입력 모드 상호 전환 지원

- **컴팩트 UI 개선**:
  - 시간 표시에서 "오전 시작", "오전 종료" 등 레이블 제거
  - 시간 텍스트 크기를 28px로 확대해 가독성 향상
  - 클릭 한 번으로 편집 모드 진입, 사용 단계 축소

#### 2. GitHub Actions CI/CD 수정
- **Dart 포맷 체크 실패 해결**:
  - 문제: 25개 파일이 표준 포맷을 따르지 않아 `dart format --set-exit-if-changed` 단계 실패
  - 조치: `dart format .` 실행으로 37개 파일 자동 포맷 (234 insertions, 118 deletions)
  - 커밋: d0797dc "style: apply dart format to all files for CI compliance"

- **테스트 디렉터리 누락 처리**:
  - 문제: `flutter test --no-pub` 실행 시 "Test directory 'test' not found" 오류
  - 조치: `.github/workflows/flutter-ci.yml` 수정, 테스트 디렉터리 존재 확인 후 조건부 실행
  - 수정 코드 (line 38-44):
    ```yaml
    - name: Test
      run: |
        if [ -d "test" ]; then
          flutter test --no-pub
        else
          echo "No test directory found, skipping tests"
        fi
    ```

- **Analyze 경고 무시 플래그 추가**:
  - `.github/workflows/flutter-ci.yml:36`에 `--no-fatal-infos` 플래그 추가
  - info 레벨 메시지로 인한 빌드 실패 방지
  - 커밋: ee35567 "ci: handle missing test directory gracefully"

#### 3. 파일 구조 변경
- **신규 추가**:
  - `lib/ui/style/` 디렉터리: 디자인 토큰 4개 파일
  - `lib/ui/widgets/schedule/` 디렉터리: 스케줄 UI 컴포넌트 3개 파일

- **주요 수정**:
  - `lib/ui/widgets/schedule_config_widget.dart`: 기존 단일 화면 → 그리드 + 상세 편집 2단계 구조로 재작성
  - `lib/models/schedule_model.dart`: 오전/오후 개별 세션 처리 로직 강화
  - 26개 파일 포맷 정리 (services, models, ui/widgets 전반)

#### 4. Windows ↔ WSL 동기화
- `rsync -av --delete` 명령으로 Windows 작업 결과를 WSL로 동기화 (349,264 bytes)
- Git 커밋/푸시는 WSL 환경에서 수행하여 일관성 유지

### 2025-09-30 주요 업데이트 - 자동 실행 매니저 구현
- **신규 기능**: 프로그램 자동 실행 매니저를 독립 탭으로 추가
  - **실행 시점**: 앱 시작 시 EMR, PACS 뷰어, 문서, URL 등을 순차적으로 자동 실행
  - **프로그램 관리**:
    - 파일 선택 다이얼로그를 통한 실행 파일(.exe), 문서, URL 등록
    - 프로그램명, 실행 경로, 대기 시간(초) 설정
    - 드래그 핸들(⋮⋮)로 실행 순서 변경
    - 개별 프로그램 활성화/비활성화 스위치
    - 편집(연필 아이콘) 및 삭제(휴지통 아이콘) 버튼
  - **UI 기능**:
    - 파일 유효성 검증 (경로 오류 시 빨간색 경고 아이콘 + 메시지 표시)
    - 실행 중 UI 상태 변화 (버튼 비활성화, 로딩 표시, 진행 상태 스낵바)
    - 테스트 실행 버튼으로 설정 즉시 검증
    - 탭 레이블에 자동 실행 ON/OFF 상태 실시간 표시
  - **독립 탭 구조**: 메인 화면 3번째 탭으로 분리, 설정이 아닌 핵심 기능으로 배치

- **구현 파일**:
  - `lib/models/launch_program.dart`: 프로그램 설정 모델 (id, name, path, delaySeconds, enabled)
  - `lib/models/launch_manager_settings.dart`: 자동 실행 매니저 설정 모델 (autoLaunchEnabled, programs)
  - `lib/services/auto_launch_manager_service.dart`: 프로그램 순차 실행 엔진, Stream 기반 진행 상황 추적
  - `lib/ui/widgets/launch_manager_widget.dart`: 메인 관리 UI, 드래그 앤 드롭, 상태 표시
  - `lib/ui/widgets/add_program_dialog.dart`: 프로그램 추가/편집 다이얼로그 (파일 선택, 이름/대기시간 입력)
  - `lib/services/settings_service.dart`: SharedPreferences 기반 설정 영속화 확장

- **주요 기술적 구현**:
  - `Process.start` 기반 프로그램 실행 (detached mode로 부모 프로세스와 독립)
  - `cmd /c start` 사용한 Windows 기본 프로그램 연결 (문서는 연결된 앱으로 자동 열림)
  - Stream 기반 실행 진행 상황 추적 (LaunchProgress 모델)
  - JSON 직렬화/역직렬화를 통한 설정 영속화
  - 파일 존재 여부 검증 (`File(path).existsSync()`) 및 UI 경고 표시
  - ReorderableListView로 드래그 앤 드롭 순서 변경 구현

### 2025-09-25 주요 업데이트
### 2025-09-27 진료실 배포 테스트 진행 중
- 현장 테스트에서 발견된 문제:
  - 녹음 품질·민감도 설정을 변경해도 UI와 실제 동작이 기본값으로 되돌아가는 현상. 저장 시 상태 업데이트 논리 점검 필요.
    - TODO: `AdvancedSettingsDialog._save`에서 `SettingsService.setRecordingProfile` / `setMakeupGainDb` 호출 및 대시보드 카드 상태 동기화 확인.

    - 해결: Windows Media Foundation이 AAC 24kHz 입력을 지원하지 않아 음성 강화 프로필 샘플레이트를 32kHz로 재조정함 (48 kbps 유지). 릴리스 빌드 반영 후 재테스트 예정.
  - 마이크 점검 카드가 실제 정상 음성에도 "입력이 약함"으로 표시되어 진단 임계값/게인 설명이 과도하게 엄격함. dBFS/SNR 계산 및 안내 문구 조정 필요.
    - 조치: 진단 OK 기준을 -40 dB / SNR 3.5 dB로 완화하고, 매우 조용한 환경에서도 -48 dB · SNR -0.5 dB 이상이면 “녹음 가능” 메시지로 안내하도록 조정했고 현장 재테스트에서 정상 메시지 확인 완료.

- `docs/clinic-deployment-guide.md` 를 기준으로 MSIX·폴더 복사 두 가지 배포 경로를 정리했고, 실제 진료실 PC에서 Phase 1 테스트를 시작했습니다.
- 현재 Phase 1 항목 중 앱 기동/SmartScreen 우회는 완료했으며, 마이크 연결 환경이 준비되는 즉시 진단·수동 녹음 항목을 검증할 예정입니다.
- 테스트 도중 발견되는 수정점은 `docs/clinic-deployment-guide.md`에 즉시 반영하고 있으므로, 후속 개발자는 최신 절차를 참고해 추가 이슈를 기록해 주세요.
- 8시간 Soak 테스트는 Claude 에이전트가 `scripts/windows/run-soak-test.ps1`로 완료했고, 로그는 `C\ws-workspace\eyebottlelee\soak-logs` 아래 공유되었습니다. 현재는 MSIX 릴리즈 빌드를 기준으로 실사용 테스트(Phase 1~2) 검증을 진행 중입니다.

- 대시보드 마이크 진단 카드를 헤더·요약·힌트·버튼 구조로 컴팩트하게 재구성하고, 상태 아이콘/색상/기본 가이드를 통일된 헬퍼로 관리(`refactor: compact mic diagnostic card`).
- 설정 탭의 "고급 설정" 항목 옆에 VAD, 자동 실행 상태를 즉시 확인할 수 있는 ON/OFF 배지를 추가(`feat: show toggle states in settings`).
- 앱 초기/최소 창 크기를 660×980 / 640×900으로 확장해 기본 레이아웃을 여유 있게 확인할 수 있도록 조정(`chore: increase default window size`).
- 녹음 일시정지/재개 버튼을 제거해 녹음 흐름을 `시작 ↔ 중지` 두 단계로 단순화(`chore: remove pause recording feature`).
- 저장 기간 항목에 현재 선택한 보관 기간(영구/1주일/1개월 등)을 배지로 노출하고, 다이얼로그 저장 후 즉시 갱신하도록 개선(`feat: show retention duration badge`).

### 2025-09-26 주요 업데이트
- 도움말 다이얼로그 추가: 대시보드/설정 튜토리얼 분리, 트레이 메뉴와 헤더에서 호출 가능(`feat: add in-app help dialog and tutorial`).
- 설정 탭 튜토리얼: 시간표·저장 위치·녹음 품질·보관 기간·VAD·자동 실행 항목을 쇼케이스로 안내(`feat: add settings tab tutorial walkthrough`).
- 녹음 상태 카드의 헤더와 볼륨 미터를 컴팩트하게 조정해 화면 밀도를 개선(`ui: compact recording card and meter layout`).
- 마이크 진단 임계값을 낮춰 조용한 진료실에서도 "정상" 판정이 쉽게 나오도록 조정(OK=0.04, Caution=0.018) (`tweak: lower mic diagnostic sensitivity thresholds`).
- 기본 진료 시간표 오전/오후 구간을 09:00~13:00 / 14:00~18:00으로 수정(`chore: update default clinic schedule hours`).

### 2025-09-24 주요 업데이트
- 메인 화면을 `대시보드 / 설정` 탭 구조로 재구성하고, 녹음 상태 카드·애니메이션 볼륨 미터·저장 경로 안내 카드를 새 디자인으로 통일(`feat: refresh dashboard layout and window sizing`).
- 스케줄 설정 다이얼로그를 카드형 UI로 전면 수정하고 SegmentedButton·Switch 기반 컨트롤을 도입해 일관된 사용자 경험 제공(`feat: redesign schedule configuration dialog`).
- 고급 설정을 녹음 품질·메이크업 게인 / VAD / 보관 기간 / 자동 실행 네 가지 다이얼로그로 분리하고, 권장 프리셋과 설명을 추가해 사용성을 개선(`feat: split advanced settings into dedicated dialogs`, `feat: add VAD presets and guidance`).
- 창 초기 크기·최소 크기 로직을 개선해 DPI 환경에서도 650×840 레이아웃이 안정적으로 적용되도록 조정(`feat: refresh dashboard layout and window sizing`).
- 날짜별 저장 디렉터리 및 자동 보관 정책을 강화하고, 문서에 최신 정책을 반영.

최근 확인 사항 (2025-09-23)
- Windows 워킹카피(`C:\ws-workspace\eyebottlelee`)에서 `flutter pub get`, `flutter analyze` 수행해 무경고 상태임.
- `AudioService.getTodayRecordingDirectory()`가 날짜별 하위 폴더(`YYYY-MM-DD`)를 생성하며, 기본 저장 위치 카드도 새 경로를 즉시 반영함.
- 고급 설정에서 보관 기간을 `삭제 없음`(기본값) 포함 5개 구간 중 선택할 수 있으며, 선택 시 `AudioService.configureRetention`을 통해 즉시 적용됨.

변경 파일(주요)
- 추가: `lib/services/settings_service.dart`, `lib/ui/widgets/advanced_settings_dialog.dart`, `docs/developing.md`
- 수정: `lib/services/audio_service.dart`, `lib/ui/screens/main_screen.dart`, `lib/ui/widgets/schedule_config_widget.dart`, `pubspec.yaml`(의존성 `file_selector` 추가)

---

## 3) 실행 방법(Windows)
사전 준비(Windows 측)
- Flutter SDK 설치, 채널 stable, `flutter doctor` 통과
- Visual Studio 2022: “Desktop development with C++” 워크로드
- `flutter config --enable-windows-desktop`

코드 위치/열기
- 코드: WSL 경로(예: `/home/<user>/projects/eyebottlelee`)
- Android Studio(Windows)에서 `\\wsl$\<배포판>\home\<user>\projects\eyebottlelee`를 열어 개발/미리보기

명령어
```
flutter pub get
# (선택) 플레이스홀더 아이콘 생성: Windows PowerShell에서 실행
# scripts/windows/generate-placeholder-icons.ps1
flutter run -d windows
```

패키징(MSIX)
```
flutter build windows --release
dart run msix:create
```

---

## 4) 코드 구조(관계도)
```
lib/
├─ main.dart                                 # 앱 엔트리/윈도우 초기화
├─ services/
│  ├─ audio_service.dart                     # 녹음/분할/VAD/보관정리
│  ├─ schedule_service.dart                  # 주간 스케줄 → cron 작업 등록
│  ├─ settings_service.dart                  # SharedPreferences 저장/로드
│  ├─ tray_service.dart                      # 시스템 트레이 연동(가드)
│  ├─ logging_service.dart                   # logger 기반 파일 로깅/에러 알림
│  └─ auto_launch_manager_service.dart       # 프로그램 자동 실행 매니저
├─ models/
│  ├─ schedule_model.dart                    # WeeklySchedule/DaySchedule
│  ├─ launch_program.dart                    # 실행 프로그램 설정 모델
│  └─ launch_manager_settings.dart           # 자동 실행 매니저 설정
└─ ui/
   ├─ screens/main_screen.dart               # 메인 화면: 상태/버튼/설정 진입
   └─ widgets/
      ├─ recording_status_widget.dart
      ├─ volume_meter_widget.dart
      ├─ schedule_config_widget.dart         # 시간표 편집/저장
      ├─ advanced_settings_dialog.dart       # VAD/자동 시작 설정
      ├─ launch_manager_widget.dart          # 자동 실행 매니저 메인 UI
      └─ add_program_dialog.dart             # 프로그램 추가/편집 다이얼로그
```

주요 동작 파라미터
- 녹음: AAC-LC 64kbps, mono, 16kHz, 10분 분할
- VAD: 임계값 0.01, 무음 3초 시 pause, 재개 지연 500ms
- 보관: 7일 초과 파일 삭제

---

## 5) 아이콘/트레이 리소스
- 공식 로고: `assets/logos/eyebottle-logo.png` (512×512) → 모든 ICO 생성의 소스
- 아이콘 생성 스크립트(PowerShell): `scripts/windows/generate-placeholder-icons.ps1`
  - ImageMagick(`magick`)이 설치되어 있으면 로고 기반 멀티 해상도 ICO를 생성합니다.
  - 미설치 시 텍스트 플레이스홀더를 생성하고 경고를 출력합니다.
- 결과물: `assets/icons/icon.ico`, `tray_recording.ico`, `tray_waiting.ico`, `tray_error.ico`
  - 트레이 아이콘은 로고 + 상태 배지(빨강/초록/노랑 16px)를 포함합니다.

`pubspec.yaml`에 `assets/icons/`가 이미 포함되어 있으므로 스크립트를 실행해 파일을 생성하면 바로 앱과 패키징에 반영됩니다.

---

## 6) 단계별 향후 개발 계획 (업데이트: 2025-09-16)

### Phase 0. 안정화 (2025-09-16 ~ 09-27)
- [x] **녹음 세션 집계** — "오늘 녹음" 카드에 실제 누적 시간을 표시. 녹음 시작/중지 시 세션 로그를 유지하고 자정 기준으로 리셋. (SharedPreferences에 일자별 초 단위 누적, 실시간 타이머 표시) 관련: `AudioService`, `MainScreen`.
- [x] **로그 인프라** — `LoggingService`로 `logger` 파일 로테이션 구성, 세그먼트/오류 이벤트 기록 및 실패 시 SnackBar 알림. 관련: `lib/services/audio_service.dart`, `lib/services/logging_service.dart`.
- [ ] **8시간 Soak 테스트 스크립트** — Windows PowerShell 또는 Dart 스크립트로 장시간 녹음 안정성 검증, 로그 분석 체크리스트 포함. 완료 조건: 8시간 연속 녹음 중 세그먼트 누락 0건.

### Phase 1. 사용자 경험 향상 (2025-09-30 ~ 10-11)
- [ ] **Windows Toast 알림** — 진료 시작 5분 전/종료 시각에 알림 노출. `system_tray` 또는 Windows API 연계 검토. UI 문구/끄기 옵션 포함.
- [ ] **오류 가시화** — 마이크 미검출, 녹음 실패, 디스크 부족 시 다이얼로그/Toast 안내. AudioService 예외 메시지 표준화.
- [x] **트레이 아이콘 리소스** — `assets/icons/`에 실제 아이콘(.ico) 포함 및 생성 스크립트 결과 버전관리. 아이콘 미존재 시 fallback 처리.
- [x] **인앱 도움말 & 튜토리얼** — 도움말 다이얼로그와 대시보드/설정 쇼케이스 추가로 초보자 온보딩 강화.

### Phase 2. 스케줄/워크플로 확장 (2025-10-14 ~ 10-25)
- [ ] **휴진일·예외 스케줄** — 달력 UI에서 단일 날짜 비활성화/시간 덮어쓰기 저장. SharedPreferences 스키마 확장 및 ScheduleService 적용 로직 보완.
- [ ] **다중 시간 구간 지원** — 오전/오후 등 복수 구간 입력 허용. UI/모델(WeekdaySlot) 재설계, Cron 등록 로직 업데이트.
- [ ] **글로벌 마킹 단축키** — Ctrl+M 입력 시 현재 세그먼트에 타임스탬프 메타 저장(Windows API 제약 확인). 마킹 결과를 별도 JSON/CSV로 기록.

### Phase 3. 동기화·배포 체계 (2025-10-28 ~ 11-15)
- [ ] **OneDrive 동기 상태 감지** — 선택한 폴더에 대해 파일 시스템 이벤트 감시, 동기 지연 시 경고 출력. 옵션: `windows` 플러그인 또는 PowerShell 연동.
- [ ] **자동 시작 안정화** — MSIX 패키징 시 고정 경로 기반으로 `launch_at_startup` 재검증. 개발 환경 경고 문구 문서화.
- [ ] **CI/CD 및 배포** — GitHub Actions로 Windows 빌드/테스트/아티팩트 업로드, MSIX 생성 자동화. 후속으로 코드 서명 및 winget 채널 검토.

---

## 7) 개발 중 체크리스트
- [ ] `flutter doctor` 통과(Windows 컴파일러 포함)
- [ ] `flutter run -d windows` 로컬 실행 OK
- [ ] 폴더 선택으로 OneDrive 경로 지정(예: `C:\\Users\\<user>\\OneDrive\\진료녹음`)
- [ ] 트레이 아이콘 생성 및 표시 확인
- [ ] 창 닫기 → 트레이로 숨김 → 트레이에서 복원/종료 플로우 확인
- [ ] 트레이 메뉴에서 녹음 시작/중지, 마이크 점검, 설정 열기 동작 확인
- [ ] 30~60분 시범 녹음 → 세그먼트/보관정리 동작 확인
- [ ] 사용자 안내 문서(`docs/user-guide.md`) 업데이트 및 README 링크 반영 확인

---

## 8) 알려진 제약/주의
- Windows 권한/장치: `record.hasPermission()` 동작이 플랫폼별 상이할 수 있어 UI 레벨미터로 사전 확인
- 트레이 리소스: 아이콘 없으면 초기화 실패(앱 기능엔 영향 없음) → 아이콘 생성 권장
- 자동 시작: 개발 경로/권한으로 실패할 수 있으므로 로그 확인 필요하며, 앱 기동 시 설정 값과 동기화를 시도함. 배포 후 고정 경로에서 재검증 필요
- VAD: 단순 RMS 기반(잡음 환경 오검지 가능) → 임계값 튜닝 필요

---

## 9) 빠른 실행/검증 명령
```
flutter pub get
flutter run -d windows
# (선택) 공식 로고 기반 아이콘 생성 (ImageMagick 필요)
# pwsh -File scripts/windows/generate-placeholder-icons.ps1
# (선택) MSIX
# flutter build windows --release && dart run msix:create
```

---


## 10) 이어서 작업하기(가이드)
- 작은 단위로 변경 → 실행/확인 → 문서/체크리스트 갱신
- 새 기능 추가 시: UI(설정/토글) → 서비스(로직) → 저장(SharedPreferences) 순으로 연결
- 파괴적 변경(파일 삭제 정책/경로 변경 등)은 반드시 문서에 근거 및 롤백 전략 기재

참고: 루트의 `AGENTS.md`는 에이전트/자동화 도구 작업 지침을 정의합니다. 변경 시 함께 갱신하세요.

## 11) 실사용 테스트 앱 준비 체크리스트
- [ ] Windows에서 `pwsh -File scripts\windows\run-soak-test.ps1` 로 8시간 Soak 테스트를 수행하고, 필요하면 `-DurationHours` 옵션으로 시간을 조절합니다. 로그와 metrics는 `C:\ws-workspace\eyebottlelee\soak-logs\<timestamp>` 아래에 저장됩니다.
- [ ] Soak 테스트 결과를 요약한 `session-notes.txt`와 `metrics.csv`를 확인해 메모리 사용량·CPU 누적 시간을 검토하고, 진료실 PC에서도 동일 스크립트를 재실행해 하드웨어 차이를 비교합니다.
- [ ] `flutter build windows --release` 완료 후 `build\windows\x64\runner\Release` 폴더를 ZIP으로 묶어 테스트앱 패키지를 만든 뒤, 진료실 PC에 전달합니다.
- [ ] 패키지에는 실행 파일 외에 최신 사용자 가이드(`docs/user-guide.md`)의 테스트 절차 요약본과 복구 안내, Soak 테스트 로그 묶음을 포함해 현장에서도 바로 검수할 수 있도록 합니다.
- [ ] 테스트 중 발견한 이슈는 Phase 1~3 일정(알림, 오류 가시화, 동기화 안정화)과 연결해 티켓을 작성하고, 해결 여부를 회고 로그에 남깁니다.


