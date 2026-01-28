import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:window_manager/window_manager.dart';
import 'services/auto_launch_service.dart';
import 'services/logging_service.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
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

    await NotificationService().ensureInitialized();

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

// NOTE: _isRecentSystemBoot() and _parseWindowsDateTime() were removed in v1.3.8.
// MSIX 환경에서 PowerShell/WMIC 호출이 샌드박스 제한으로 실패하는 문제가 있어,
// --autostart 인자 기반 감지로 전환했습니다. (A안+C안 적용)

Future<void> _initializeApp({
  required LoggingService logging,
  required bool hasAutostartArg,
}) async {
  // WidgetsFlutterBinding은 main()에서 이미 초기화됨

  // Windows Desktop 초기화
  await windowManager.ensureInitialized();

  const initialSize = Size(660, 980);
  const minimumSize = Size(640, 900);

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

  if (hasAutostartArg && !launchAtStartup) {
    logging.warning(
        'Autostart launch detected but setting is OFF. Exiting immediately.');
    try {
      await AutoLaunchService().apply(false);
    } catch (e, stackTrace) {
      logging.warning('자동 실행 비활성화 시도 실패', error: e, stackTrace: stackTrace);
    }
    exit(0);
  }

  // 부팅 자동 실행일 때도 사용자가 선택한 창 표시/숨김 옵션을 따름
  final shouldStartMinimized = hasAutostartArg
      ? startMinimizedOnBoot
      : (launchAtStartup && startMinimizedOnBoot);

  // 전역 플래그 설정 (main_screen.dart에서 참조)
  gStartedInBackground = shouldStartMinimized;

  logging.info('Background start decision: launchAtStartup=$launchAtStartup, '
      'startMinimizedOnBoot=$startMinimizedOnBoot → shouldStartMinimized=$shouldStartMinimized');

  final windowOptions = WindowOptions(
    size: initialSize,
    minimumSize: minimumSize,
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: shouldStartMinimized,
    titleBarStyle: TitleBarStyle.normal,
    title: '아이보틀 진료녹음 & 자동실행 매니저',
  );

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
      logging.error('Window initialization failed',
          error: e, stackTrace: stackTrace);
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
