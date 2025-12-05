import 'dart:async';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:window_manager/window_manager.dart';
import 'services/settings_service.dart';
import 'services/logging_service.dart';
import 'ui/screens/main_screen.dart';
import 'ui/style/app_theme.dart';

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
    final isAutostart = args.contains('--autostart');
    if (isAutostart) {
      logging.info('앱이 자동 실행 모드(--autostart)로 시작되었습니다.');
    } else {
      logging.info('앱이 일반 모드로 시작되었습니다. args=$args');
    }

    await _initializeApp(isAutostart: isAutostart, logging: logging);
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

Future<void> _initializeApp(
    {required bool isAutostart, required LoggingService logging}) async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // 부팅 시 자동 시작이고, 백그라운드 시작 설정이 활성화된 경우
  bool shouldStartMinimized = false;
  if (isAutostart) {
    final settings = SettingsService();
    shouldStartMinimized = await settings.getStartMinimizedOnBoot();
    logging.info('Autostart check: shouldStartMinimized=$shouldStartMinimized');
  }

  windowManager.waitUntilReadyToShow(windowOptions, () async {
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
