import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:window_manager/window_manager.dart';
import 'services/settings_service.dart';
import 'services/logging_service.dart';
import 'ui/screens/main_screen.dart';
import 'ui/style/app_theme.dart';

/// 백그라운드(트레이) 모드로 시작했는지 여부
///
/// main.dart에서 설정되고, main_screen.dart에서 참조하여
/// setSkipTaskbar 호출 충돌을 방지합니다.
///
/// **사용 예:**
/// ```dart
/// if (!gStartedInBackground) {
///   await windowManager.setSkipTaskbar(false);
/// }
/// ```
bool gStartedInBackground = false;

void main(List<String> args) async {
  // 전역 에러 핸들러 설정
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 로깅 서비스 초기화 (부팅 로그 확보용)
    final logging = LoggingService();
    await logging.ensureInitialized();

    // Flutter 프레임워크 에러 핸들러
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      logging.error('Flutter Error',
          error: details.exception, stackTrace: details.stack);
    };

    // 부팅 시 자동 시작 여부 확인
    //
    // **v1.3.8 변경사항 (A안+C안 적용):**
    // - MSIX 환경에서 PowerShell/WMIC 호출이 실패하는 문제 해결
    // - _isRecentSystemBoot() 의존성 제거, 설정값 기반으로 단순화
    // - --autostart 인자는 참고용 로그로만 사용
    //
    // **로직:**
    // - --autostart 인자 존재(=부팅 자동 실행으로 시작) → 무조건 백그라운드 시작
    //   (부팅 시 창이 뜨는 스트레스를 원천 차단)
    // - 그 외(사용자가 직접 실행) → startMinimizedOnBoot=true AND launchAtStartup=true일 때만 백그라운드
    final hasAutostartArg = args.contains('--autostart');

    logging.info('Startup args: $args, hasAutostartArg=$hasAutostartArg');

    await _initializeApp(logging: logging, hasAutostartArg: hasAutostartArg);
  }, (error, stack) {
    // Zone에서 캐치되지 않은 에러
    debugPrint('Uncaught Error: $error');
    debugPrint('StackTrace: $stack');
    // LoggingService가 초기화되지 않았을 수도 있으므로 안전하게 시도
    try {
      LoggingService().error('Uncaught Error', error: error, stackTrace: stack);
    } catch (_) {}
  });
}

/// 시스템 부팅 후 일정 시간(10분) 내에 앱이 시작되었는지 확인
///
/// Windows에서 시스템 업타임을 확인하여 부팅 직후 StartupTask로
/// 실행되었는지 감지합니다. MSIX StartupTask에서 command-line 인자가
/// 전달되지 않는 버그를 우회하기 위한 방법입니다.
///
/// **변경 이력:**
/// - v1.3.5: 3분 → 10분으로 완화 (느린 PC, 로그인 지연 대응)
///
/// 두 가지 방법을 순차적으로 시도:
/// 1. PowerShell로 LastBootUpTime 조회 (정확함)
/// 2. wmic로 시스템 업타임 조회 (fallback)
Future<bool> _isRecentSystemBoot() async {
  if (!Platform.isWindows) return false;

  // 10분으로 완화: 느린 PC, 로그인 지연, 여러 시작프로그램 대기 등 고려
  const bootThreshold = Duration(minutes: 10);

  // 방법 1: PowerShell 사용
  try {
    final result = await Process.run(
      'powershell',
      ['-NoProfile', '-Command', '(Get-CimInstance Win32_OperatingSystem).LastBootUpTime'],
      runInShell: true,
    ).timeout(const Duration(seconds: 5));

    if (result.exitCode == 0) {
      final output = result.stdout.toString().trim();
      if (output.isNotEmpty) {
        final bootTime = _parseWindowsDateTime(output);
        if (bootTime != null) {
          final timeSinceBoot = DateTime.now().difference(bootTime);
          debugPrint('PowerShell boot check: bootTime=$bootTime, timeSinceBoot=$timeSinceBoot');
          return timeSinceBoot <= bootThreshold;
        }
      }
    }
  } catch (e) {
    debugPrint('PowerShell boot check failed: $e');
  }

  // 방법 2: wmic 사용 (fallback)
  try {
    final result = await Process.run(
      'wmic',
      ['os', 'get', 'lastbootuptime'],
      runInShell: true,
    ).timeout(const Duration(seconds: 5));

    if (result.exitCode == 0) {
      final output = result.stdout.toString().trim();
      // wmic 출력 예: "LastBootUpTime\n20251205093012.500000+540"
      final match = RegExp(r'(\d{14})').firstMatch(output);
      if (match != null) {
        final wmicTime = match.group(1)!;
        // 형식: YYYYMMDDHHMMSS
        final bootTime = DateTime(
          int.parse(wmicTime.substring(0, 4)),   // year
          int.parse(wmicTime.substring(4, 6)),   // month
          int.parse(wmicTime.substring(6, 8)),   // day
          int.parse(wmicTime.substring(8, 10)),  // hour
          int.parse(wmicTime.substring(10, 12)), // minute
          int.parse(wmicTime.substring(12, 14)), // second
        );
        final timeSinceBoot = DateTime.now().difference(bootTime);
        debugPrint('WMIC boot check: bootTime=$bootTime, timeSinceBoot=$timeSinceBoot');
        return timeSinceBoot <= bootThreshold;
      }
    }
  } catch (e) {
    debugPrint('WMIC boot check failed: $e');
  }

  // 모든 방법 실패 시 false 반환 (안전하게 일반 모드로 시작)
  debugPrint('All boot time detection methods failed');
  return false;
}

/// Windows PowerShell 날짜 문자열 파싱
DateTime? _parseWindowsDateTime(String dateStr) {
  try {
    // 다양한 형식 시도
    // 형식 1: "12/5/2025 12:00:00 PM" (영어 로케일)
    // 형식 2: "2025년 12월 5일 오후 12:00:00" (한국어 로케일)
    // 형식 3: "2025-12-05 12:00:00" (ISO 형식)

    // ISO 형식 시도
    final isoMatch = RegExp(r'(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})').firstMatch(dateStr);
    if (isoMatch != null) {
      return DateTime(
        int.parse(isoMatch.group(1)!),
        int.parse(isoMatch.group(2)!),
        int.parse(isoMatch.group(3)!),
        int.parse(isoMatch.group(4)!),
        int.parse(isoMatch.group(5)!),
        int.parse(isoMatch.group(6)!),
      );
    }

    // 영어 로케일 형식 시도 (MM/DD/YYYY HH:MM:SS AM/PM)
    final usMatch = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{2}):(\d{2})\s*(AM|PM)?', caseSensitive: false).firstMatch(dateStr);
    if (usMatch != null) {
      var hour = int.parse(usMatch.group(4)!);
      final ampm = usMatch.group(7)?.toUpperCase();
      if (ampm == 'PM' && hour != 12) hour += 12;
      if (ampm == 'AM' && hour == 12) hour = 0;

      return DateTime(
        int.parse(usMatch.group(3)!),
        int.parse(usMatch.group(1)!),
        int.parse(usMatch.group(2)!),
        hour,
        int.parse(usMatch.group(5)!),
        int.parse(usMatch.group(6)!),
      );
    }

    // 한국어 로케일 형식 시도 (요일 포함 가능: "2025년 12월 2일 화요일 오전 9:30:12")
    final koMatch = RegExp(r'(\d{4})년\s*(\d{1,2})월\s*(\d{1,2})일\s*(?:\S*요일)?\s*(오전|오후)?\s*(\d{1,2}):(\d{2}):(\d{2})').firstMatch(dateStr);
    if (koMatch != null) {
      var hour = int.parse(koMatch.group(5)!);
      final ampm = koMatch.group(4);
      if (ampm == '오후' && hour != 12) hour += 12;
      if (ampm == '오전' && hour == 12) hour = 0;

      return DateTime(
        int.parse(koMatch.group(1)!),
        int.parse(koMatch.group(2)!),
        int.parse(koMatch.group(3)!),
        hour,
        int.parse(koMatch.group(6)!),
        int.parse(koMatch.group(7)!),
      );
    }

    return null;
  } catch (e) {
    return null;
  }
}

Future<void> _initializeApp({
  required LoggingService logging,
  required bool hasAutostartArg,
}) async {
  // WidgetsFlutterBinding은 main()에서 이미 초기화됨

  // Windows Desktop 초기화
  await windowManager.ensureInitialized();

  const initialSize = Size(660, 980);
  const minimumSize = Size(640, 900);

  WindowOptions windowOptions = const WindowOptions(
    size: initialSize,
    minimumSize: minimumSize,
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: '아이보틀 진료녹음 & 자동실행 매니저',
  );

  // ============================================================
  // 부팅 시 백그라운드로 시작할지 결정 (v1.3.8 A안+C안)
  // ============================================================
  //
  // **핵심 원칙:**
  // 설정값이 진실의 원천. 외부 프로세스 호출(PowerShell/WMIC) 없이
  // SharedPreferences에 저장된 값만으로 결정합니다.
  //
  // **로직:**
  // - launchAtStartup=true AND startMinimizedOnBoot=true → 백그라운드 시작
  // - 그 외 → 창 표시
  //
  // **주의:**
  // 이 방식은 "수동으로 앱을 실행해도 백그라운드로 시작"될 수 있습니다.
  // 하지만 사용자가 설정에서 명시적으로 둘 다 켜놓은 상태이므로,
  // 의도된 동작으로 간주합니다. 창을 보려면 트레이 아이콘을 클릭하면 됩니다.
  //
  // ============================================================
  final settings = SettingsService();
  final launchAtStartup = await settings.getLaunchAtStartup();
  final startMinimizedOnBoot = await settings.getStartMinimizedOnBoot();

  // 부팅 자동 실행이면 무조건 트레이로 (사용자 체감 최우선)
  final shouldStartMinimized = hasAutostartArg
      ? true
      : (launchAtStartup && startMinimizedOnBoot);

  // 전역 플래그 설정 (main_screen.dart에서 참조)
  gStartedInBackground = shouldStartMinimized;

  logging.info('Background start decision: launchAtStartup=$launchAtStartup, '
      'startMinimizedOnBoot=$startMinimizedOnBoot → shouldStartMinimized=$shouldStartMinimized');

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    try {
      if (shouldStartMinimized) {
        // 백그라운드로 시작 (트레이만 표시)
        await windowManager.hide();
        await windowManager.setSkipTaskbar(true);
        logging.info('Started minimized to tray (background mode)');
      } else {
        // 정상적으로 창 표시
        await windowManager.setSkipTaskbar(false);
        await windowManager.show();
        await windowManager.focus();
        logging.info('Started normally (visible window)');
      }
    } catch (e, stackTrace) {
      logging.error('Window initialization failed', error: e, stackTrace: stackTrace);
    }
  });

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // 백그라운드 시작이어도 창 크기는 설정 (숨겨진 상태에서도 크기 설정 가능)
    await _applyWindowMetrics(
        initialSize: initialSize, minimumSize: minimumSize);
  });

  runApp(
    ShowCaseWidget(
      builder: (context) => const MedicalRecorderApp(),
    ),
  );
}

Future<void> _applyWindowMetrics({
  required Size initialSize,
  required Size minimumSize,
}) async {
  // DPI 스케일링이 즉시 적용되지 않는 경우가 있어 약간의 지연 후 재시도
  // (window_manager 이슈 대응)
  for (var attempt = 0; attempt < 5; attempt++) {
    if (attempt > 0) {
      await Future.delayed(const Duration(milliseconds: 120));
    } else {
      await Future.delayed(const Duration(milliseconds: 60));
    }

    final ratio = await windowManager.getDevicePixelRatio();

    await windowManager.setMinimumSize(minimumSize);
    await windowManager.setSize(initialSize);
    await windowManager.center();

    // DPI가 정상 범위(1.0 근처)가 아니거나, High DPI 환경에서 안정화되었는지 체크
    // 1.01/0.99는 부동소수점 오차 고려
    if (ratio > 1.01 || ratio < 0.99) {
      // DPI 값이 안정적인지 확인 (실제로는 OS 스케일에 따라 다름)
      // 여기서는 "값이 읽혀졌다"는 것을 간접 확인함
      break;
    }
  }
}

class MedicalRecorderApp extends StatelessWidget {
  const MedicalRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '아이보틀 진료녹음 & 자동실행 매니저',
      theme: AppTheme.lightTheme,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
