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
    // **v1.3.14 변경사항:**
    // - --autostart 인자 존재(=MSIX 부팅 자동 실행) → 백그라운드(트레이) 시작
    // - --autostart 인자 없음(=사용자 수동 실행) → 무조건 창 표시
    // - 수동 실행 시 설정값에 관계없이 항상 창을 보여줌 (v1.3.13 버그 수정)
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
  // 부팅 시 백그라운드로 시작할지 결정 (v1.3.14)
  // ============================================================
  //
  // **핵심 원칙:**
  // 1. windowManager.waitUntilReadyToShow()를 반드시 사용한다!
  //    (직접 호출하면 window_manager_plugin.dll이 크래시함)
  //
  // **주의: MSIX의 uap10:Parameters**
  // MSIX 패키지에서는 uap10:Parameters="--autostart"가 Application 요소에
  // 적용되므로, StartupTask뿐 아니라 시작 메뉴 클릭 등 **모든 실행**에
  // --autostart 인자가 붙습니다.
  //
  // 따라서 --autostart만으로 "부팅 시 자동 실행"을 판단할 수 없습니다.
  // 대신: launchAtStartup=ON + startMinimizedOnBoot=ON 일 때만 트레이 숨김.
  //
  // ============================================================
  final settings = SettingsService();
  final launchAtStartup = await settings.getLaunchAtStartup();
  final startMinimizedOnBoot = await settings.getStartMinimizedOnBoot();

  // ★★★ 핵심 로직 ★★★
  // 트레이로 숨기려면 3가지 조건이 모두 충족되어야 함:
  // 1. --autostart 인자 있음 (MSIX에서는 항상 true — 방어적 체크)
  // 2. launchAtStartup = true (사용자가 자동 실행을 켜놓았음)
  // 3. startMinimizedOnBoot = true (사용자가 백그라운드 시작을 원함)
  //
  // 하나라도 false면 → 창을 보여준다!
  final shouldStartMinimized =
      hasAutostartArg && launchAtStartup && startMinimizedOnBoot;

  // 전역 플래그 설정 (main_screen.dart에서 참조)
  gStartedInBackground = shouldStartMinimized;

  logging.info('Background start decision: hasAutostartArg=$hasAutostartArg, '
      'launchAtStartup=$launchAtStartup, '
      'startMinimizedOnBoot=$startMinimizedOnBoot → '
      'shouldStartMinimized=$shouldStartMinimized');

  // ============================================================
  // WindowOptions를 사용하여 waitUntilReadyToShow()로 창 초기화
  // ============================================================
  // !! 중요 !!
  // windowManager.setSize(), setTitle() 등을 ensureInitialized() 직후에
  // 직접 호출하면 window_manager_plugin.dll에서 Access Violation(0xc0000005)
  // 크래시가 발생합니다.
  //
  // 반드시 waitUntilReadyToShow()의 콜백 안에서 창 조작을 해야 합니다.
  // (v1.3.4에서 정상 작동하던 패턴 복원)
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
      // --autostart + 백그라운드 시작: 창 숨기고 트레이만 표시
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
