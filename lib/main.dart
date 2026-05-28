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
  // 부팅 시 백그라운드로 시작할지 결정 (v1.3.17 — 구조 단순화)
  // ============================================================
  //
  // **v1.3.16: WinRT StartupTask API로 근본 교체**
  // **v1.3.17: 부팅-트레이 race 제거 + 조건 단순화**
  //
  // MSIX manifest의 StartupTask 설정:
  //   task_id: EyebottleMedicalRecorder
  //   parameters: "--autostart"
  //
  // Windows가 StartupTask로 앱을 실행할 때만 --autostart 인자가 전달됩니다.
  // 사용자가 시작 메뉴에서 수동 실행할 때는 인자가 없습니다.
  //
  // **왜 launchAtStartup(SharedPreferences) 체크를 뺐나 (v1.3.17):**
  // --autostart 인자가 OS에서 전달됐다는 것 자체가 이미 Windows StartupTask가
  // 활성화돼 있다는 증거입니다. launch_at_startup SharedPreferences 값을 추가로
  // AND 조건에 넣으면, MSIX 컨테이너에서 SharedPreferences 읽기가 실패하거나
  // 기본값(false)이 반환될 때 사용자가 켜둔 "백그라운드 시작"이 조용히 깨졌습니다.
  // → 부팅 결정에서는 launchAtStartup을 제거하고 두 조건만 봅니다.
  //
  // **트레이 숨김 조건 (이중 AND):**
  // 1. --autostart 인자가 있음 (StartupTask에 의한 실행)
  // 2. startMinimizedOnBoot = true (사용자가 백그라운드 시작을 원함)
  //
  // 수동 실행(인자 없음) → 항상 창 표시
  //
  // native(main.cpp)는 --autostart일 때 Show()를 호출하지 않으므로, 자동시작
  // 경로에서는 창이 처음부터 hidden 상태입니다. 따라서:
  //   - 백그라운드 시작: setSkipTaskbar(true)만, show() 안 함
  //   - 자동시작인데 백그라운드 OFF: 명시적으로 show()+focus() 필요
  //   - 수동 실행: native가 이미 Show 했으나 일관성을 위해 show()+focus()
  // ============================================================

  final hasAutostart = args.contains('--autostart');
  final settings = SettingsService();
  final startMinimizedOnBoot = await settings.getStartMinimizedOnBoot();

  final shouldStartMinimized = hasAutostart && startMinimizedOnBoot;

  // 전역 플래그 설정 (main_screen.dart에서 참조)
  gStartedInBackground = shouldStartMinimized;

  logging.info(
    'Background start decision: '
    'hasAutostart=$hasAutostart, '
    'startMinimizedOnBoot=$startMinimizedOnBoot → '
    'shouldStartMinimized=$shouldStartMinimized',
  );

  // v1.3.17: 부팅 결정을 영구 이력으로 저장 (진단 패널에서 확인)
  await settings.appendBootDecision(
    hasAutostart: hasAutostart,
    startMinimizedOnBoot: startMinimizedOnBoot,
    shouldStartMinimized: shouldStartMinimized,
    args: args,
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
      // 부팅 직후 + 백그라운드 시작: 트레이만 표시.
      // native(main.cpp)가 --autostart일 때 Show()를 호출하지 않으므로 창은
      // 이미 hidden 상태입니다. hide()를 다시 부를 필요가 없어졌습니다.
      await windowManager.setSkipTaskbar(true);
      logging.info('Started minimized to tray (background mode)');
    } else {
      // 일반 실행 또는 자동시작-백그라운드OFF: 창을 명시적으로 표시.
      // 자동시작 경로는 native가 창을 숨겨둔 상태이므로 show()가 반드시 필요.
      await windowManager.setSkipTaskbar(false);
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
