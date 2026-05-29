# 부팅 시 백그라운드 시작 기능 수정 기록

> **버전:** v1.3.8
> **작성일:** 2025-12-10
> **상태:** 해결됨

---

## 문제 요약

**증상:** Windows 시작 시 "자동 실행 + 백그라운드 시작" 설정을 모두 켜도 **항상 창이 뜸**

**영향 범위:** MSIX/Microsoft Store 배포 버전

---

## 원인 분석

### 문제점 1: `setSkipTaskbar` 호출 충돌 (핵심 원인)

```
main.dart:248         → await windowManager.setSkipTaskbar(true);  // 백그라운드 시작 시
main_screen.dart:111  → await windowManager.setSkipTaskbar(false); // 항상 실행됨!
```

**흐름:**
1. `main.dart`에서 `shouldStartMinimized=true` → `hide()` + `setSkipTaskbar(true)` 실행
2. `runApp()` → `MainScreen` 생성 → `initState()` → `_initializeServices()`
3. `_initializeServices()`가 **무조건** `setSkipTaskbar(false)` 호출
4. 작업표시줄에 앱이 다시 나타남 → 사용자가 "창이 뜬다"고 인식

### 문제점 2: `_isRecentSystemBoot()` MSIX 환경 실패

PowerShell/WMIC 명령이 MSIX 샌드박스에서 차단될 수 있음:

```dart
// MSIX 앱에서 외부 프로세스 실행 제한
final result = await Process.run(
  'powershell',
  ['-NoProfile', '-Command', '(Get-CimInstance Win32_OperatingSystem).LastBootUpTime'],
  runInShell: true,
);
```

- PowerShell 실행 실패 → catch로 떨어짐
- WMIC 실행 실패 → catch로 떨어짐
- `return false` → `isAutostart = false` → **창 표시**

### 문제점 3: 설정 저장소 경로 불일치 가능성

MSIX 앱의 샌드박스 환경에서:
- UI에서 설정 저장 → 경로 A
- StartupTask로 실행 시 설정 로드 → 경로 B (다를 수 있음)

---

## 해결 방안 (A안 + C안 조합)

### 핵심 원칙

> **"설정값이 진실의 원천"**
>
> 외부 프로세스 호출(PowerShell/WMIC)에 의존하지 않고,
> SharedPreferences에 저장된 값만으로 결정합니다.

### 변경 사항

#### 1. 전역 플래그 추가 (`main.dart`)

```dart
/// 백그라운드(트레이) 모드로 시작했는지 여부
bool gStartedInBackground = false;
```

#### 2. 설정값 기반 단순화 (`main.dart`)

**Before:**
```dart
final isAutostart = hasAutostartArg || await _isRecentSystemBoot();
if (isAutostart) {
  shouldStartMinimized = startMinimizedOnBoot;
} else if (launchAtStartup && startMinimizedOnBoot) {
  final isRecentBoot = await _isRecentSystemBoot();
  if (isRecentBoot) shouldStartMinimized = true;
}
```

**After:**
```dart
// 설정값 기반으로 단순하게 결정
final shouldStartMinimized = launchAtStartup && startMinimizedOnBoot;
gStartedInBackground = shouldStartMinimized;
```

#### 3. 조건부 `setSkipTaskbar` 호출 (`main_screen.dart`)

**Before:**
```dart
await windowManager.setSkipTaskbar(false); // 항상 실행
```

**After:**
```dart
if (!gStartedInBackground) {
  await windowManager.setSkipTaskbar(false);
}
```

---

## 동작 흐름도

```
[앱 시작]
    ↓
[설정 로드]
├── launchAtStartup = true
└── startMinimizedOnBoot = true
    ↓
[shouldStartMinimized = true]
    ↓
[gStartedInBackground = true]
    ↓
[windowManager.hide() + setSkipTaskbar(true)]
    ↓
[runApp() → MainScreen]
    ↓
[_initializeServices()]
├── gStartedInBackground == true
└── setSkipTaskbar(false) 호출 안 함!
    ↓
[트레이에서만 실행됨] ✅
```

---

## 주의사항

### 수동 실행 시에도 백그라운드로 시작됨

이 방식은 **수동으로 앱을 실행해도 백그라운드로 시작**될 수 있습니다.

하지만:
- 사용자가 설정에서 명시적으로 둘 다 켜놓은 상태
- 의도된 동작으로 간주
- 창을 보려면 **트레이 아이콘을 클릭**하면 됨

### 설정 조합별 동작

| launchAtStartup | startMinimizedOnBoot | 결과 |
|:---------------:|:--------------------:|:----:|
| OFF | OFF | 창 표시 |
| ON | OFF | 창 표시 |
| OFF | ON | 창 표시 |
| ON | ON | **백그라운드** |

---

## 테스트 체크리스트

### 필수 테스트

- [ ] 설정: 자동실행 ON + 백그라운드 ON → 재부팅 → 트레이만 표시
- [ ] 설정: 자동실행 ON + 백그라운드 OFF → 재부팅 → 창 표시
- [ ] 설정: 자동실행 OFF → 수동 실행 → 창 표시
- [ ] 트레이 아이콘 클릭 → 창 복원
- [ ] 창 X 버튼 → 트레이로 숨김 (종료 아님)

### 로그 확인 위치

```
C:\Users\<사용자>\AppData\Local\아이보틀\logs\
```

또는 MSIX 앱:
```
C:\Users\<사용자>\AppData\Local\Packages\<앱ID>\LocalCache\Local\아이보틀\logs\
```

### 확인할 로그 메시지

```
Background start decision: launchAtStartup=true, startMinimizedOnBoot=true → shouldStartMinimized=true
Window init: gStartedInBackground=true
Started minimized to tray (background mode)
```

---

## 히스토리

| 버전 | 날짜 | 변경 내용 |
|:----:|:----:|----------|
| v1.3.4 | 2025-12-05 | 최초 구현 (--autostart 인자 기반) |
| v1.3.5 | 2025-12-06 | _isRecentSystemBoot() 추가 (부팅 10분 기준) |
| v1.3.7 | 2025-12-09 | 로그 강화, 타임아웃 조정 |
| v1.3.8 | 2025-12-10 | **A안+C안 적용**: 설정값 기반 단순화, 전역 플래그 도입 |

---

## 관련 파일

- `lib/main.dart` - 앱 초기화, 백그라운드 시작 결정
- `lib/ui/screens/main_screen.dart` - UI 초기화, setSkipTaskbar 호출
- `lib/services/settings_service.dart` - 설정 저장/로드
- `lib/services/tray_service.dart` - 트레이 아이콘 관리

---

## 다음 작업 (TODO)

> **중요:** MSIX 샌드박스 환경 테스트는 **MS Store 설치 버전**에서만 가능

1. **버전 업데이트**
   - `pubspec.yaml` 버전 → 1.3.8

2. **빌드**
   ```powershell
   # Windows에서 실행
   flutter build windows --release
   dart run msix:create
   ```

3. **MS Store 제출**
   - Partner Center에서 MSIX 업로드
   - 인증 통과 대기

4. **스토어에서 설치 후 테스트**
   - 설정: 자동실행 ON + 백그라운드 ON
   - PC 재부팅
   - 트레이만 표시되는지 확인

5. **로그 확인**
   ```
   Background start decision: ... shouldStartMinimized=true
   Window init: gStartedInBackground=true
   Started minimized to tray
   ```
