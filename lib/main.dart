import 'dart:async';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:window_manager/window_manager.dart';
import 'services/logging_service.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'ui/screens/main_screen.dart';
import 'ui/style/app_theme.dart';
import 'utils/win32_uptime.dart';

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
  // **v1.3.18: --autostart 인자에만 의존하지 않도록 보강**
  //
  // 진료실 Windows 10 Home PC에서, 백그라운드 시작을 켜고 재부팅했는데도 창이
  // 떴고 부팅 이력의 args가 비어 있었다(hasAutostart=false). 원인은 MSIX
  // StartupTask의 uap10:Parameters("--autostart")가 해당 환경에서 실제 argv로
  // 전달되지 않는 것. (full-trust 앱은 활성화 파이프라인이 아니라 CreateProcess로
  // 실행되며, uap10:Parameters는 Windows 10 1903+에서만 동작 보장)
  //
  // **트레이 숨김 조건 (v1.3.18):**
  //   shouldStartMinimized = startMinimizedOnBoot && isLikelyBootLaunch
  //   isLikelyBootLaunch    = hasAutostart || (시스템 부팅 후 경과 < 5분)
  //
  // - hasAutostart: 인자가 전달되는 환경에서는 정확한 신호(부팅 즉시 확정).
  // - 부팅 후 경과 시간: 인자가 안 오는 환경의 보조 신호. 로그인 직후
  //   StartupTask 실행이면 경과가 짧다. 진료 중 수동 실행은 경과가 길어 창 표시.
  //
  // **창 표시 제어(v1.3.18):** native(main.cpp)는 더 이상 Show()를 호출하지 않고,
  // 가시성을 전적으로 여기 Dart에서 제어한다(window_manager 권장 패턴). 따라서
  // 창은 항상 hidden으로 생성되며:
  //   - shouldStartMinimized=true  → setSkipTaskbar(true)만 (계속 트레이 전용)
  //   - shouldStartMinimized=false → show()+focus()로 명시 표시
  // 이로써 native Show()와 Dart hide() 사이의 race(창 깜빡임)가 원천 제거된다.
  // ============================================================

  final hasAutostart = args.contains('--autostart');
  final settings = SettingsService();
  final startMinimizedOnBoot = await settings.getStartMinimizedOnBoot();

  // 부팅/로그인 직후 자동시작인지 추정하는 보조 신호 (위 주석 참고).
  final uptime = systemUptime();
  const bootWindow = Duration(minutes: 5);
  final withinBootWindow = uptime != null && uptime < bootWindow;
  final isLikelyBootLaunch = hasAutostart || withinBootWindow;

  final shouldStartMinimized = startMinimizedOnBoot && isLikelyBootLaunch;

  // 전역 플래그 설정 (main_screen.dart에서 참조)
  gStartedInBackground = shouldStartMinimized;

  logging.info(
    'Background start decision: '
    'hasAutostart=$hasAutostart, '
    'uptime=${uptime?.inSeconds}s, '
    'withinBootWindow=$withinBootWindow, '
    'isLikelyBootLaunch=$isLikelyBootLaunch, '
    'startMinimizedOnBoot=$startMinimizedOnBoot → '
    'shouldStartMinimized=$shouldStartMinimized',
  );

  // 부팅 결정을 영구 이력으로 저장 (진단 패널에서 확인)
  await settings.appendBootDecision(
    hasAutostart: hasAutostart,
    startMinimizedOnBoot: startMinimizedOnBoot,
    shouldStartMinimized: shouldStartMinimized,
    uptimeSeconds: uptime?.inSeconds,
    isLikelyBootLaunch: isLikelyBootLaunch,
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
    // v1.3.18: native(main.cpp)는 더 이상 Show()를 호출하지 않으므로, 창은 항상
    // hidden 상태로 생성된다. 가시성은 여기서 전적으로 결정한다.
    if (shouldStartMinimized) {
      // 백그라운드 시작: 트레이만. 창은 이미 hidden이므로 skipTaskbar만 설정.
      await windowManager.setSkipTaskbar(true);
      logging.info('Started minimized to tray (background mode)');
    } else {
      // 일반 실행: 창을 명시적으로 표시 (native가 띄우지 않으므로 필수).
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
