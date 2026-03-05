import 'dart:async';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:window_manager/window_manager.dart';
import 'services/logging_service.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'ui/screens/main_screen.dart';
import 'ui/style/app_theme.dart';

/// 백그라운드(트레이) 모드로 시작했는지 여부
///
/// main.dart에서 설정되고, main_screen.dart에서 참조하여
/// setSkipTaskbar 호출 충돌을 방지합니다.
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

    logging.info('Startup args: $args');

    await _initializeApp(args: args, logging: logging);
  }, (error, stack) {
    // Zone에서 캐치되지 않은 에러
    debugPrint('Uncaught Error: $error');
    debugPrint('StackTrace: $stack');
    try {
      LoggingService().error('Uncaught Error', error: error, stackTrace: stack);
    } catch (_) {}
  });
}

Future<void> _initializeApp({
  required List<String> args,
  required LoggingService logging,
}) async {
  // Windows Desktop 초기화
  await windowManager.ensureInitialized();

  const initialSize = Size(660, 980);
  const minimumSize = Size(640, 900);

  // ============================================================
  // 부팅 시 백그라운드로 시작할지 결정 (v1.3.16)
  // ============================================================
  //
  // **v1.3.16: WinRT StartupTask API로 근본 교체**
  //
  // MSIX manifest의 StartupTask 설정:
  //   task_id: EyebottleMedicalRecorder
  //   parameters: "--autostart"
  //
  // Windows가 StartupTask로 앱을 실행할 때만 --autostart 인자가 전달됩니다.
  // 사용자가 시작 메뉴에서 수동 실행할 때는 인자가 없습니다.
  //
  // 자동 실행 ON/OFF는 WinRT StartupTask API (Platform Channel)로 제어합니다.
  // → lib/services/startup_task_service.dart
  // → windows/runner/startup_task_handler.cpp
  //
  // **트레이 숨김 조건:**
  // 1. --autostart 인자가 있음 (StartupTask에 의한 실행)
  // 2. startMinimizedOnBoot = true (사용자가 백그라운드 시작을 원함)
  //
  // 수동 실행(인자 없음) → 항상 창 표시
  // ============================================================

  final hasAutostart = args.contains('--autostart');
  final settings = SettingsService();
  final launchAtStartup = await settings.getLaunchAtStartup();
  final startMinimizedOnBoot = await settings.getStartMinimizedOnBoot();

  final shouldStartMinimized =
      hasAutostart && launchAtStartup && startMinimizedOnBoot;

  // 전역 플래그 설정 (main_screen.dart에서 참조)
  gStartedInBackground = shouldStartMinimized;

  logging.info(
    'Background start decision: '
    'hasAutostart=$hasAutostart, '
    'launchAtStartup=$launchAtStartup, '
    'startMinimizedOnBoot=$startMinimizedOnBoot → '
    'shouldStartMinimized=$shouldStartMinimized',
  );

  // ============================================================
  // WindowOptions를 사용하여 waitUntilReadyToShow()로 창 초기화
  // ============================================================
  // !! 중요 !!
  // windowManager.setSize(), setTitle() 등을 ensureInitialized() 직후에
  // 직접 호출하면 window_manager_plugin.dll에서 Access Violation(0xc0000005)
  // 크래시가 발생합니다.
  //
  // 반드시 waitUntilReadyToShow()의 콜백 안에서 창 조작을 해야 합니다.
  // ============================================================

  const windowOptions = WindowOptions(
    size: initialSize,
    minimumSize: minimumSize,
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: '아이보틀 진료녹음 & 자동실행 매니저',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (shouldStartMinimized) {
      // 부팅 직후 + 백그라운드 시작: 창 숨기고 트레이만 표시
      await windowManager.setSkipTaskbar(true);
      await windowManager.hide();
      logging.info('Started minimized to tray (background mode)');
    } else {
      // 일반 실행: 창 표시
      await windowManager.show();
      await windowManager.focus();
      logging.info('Started normally (visible window)');
    }
  });

  runApp(
    ShowCaseWidget(
      builder: (context) => const MedicalRecorderApp(),
    ),
  );
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
