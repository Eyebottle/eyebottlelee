import 'dart:async';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:window_manager/window_manager.dart';
import 'services/settings_service.dart';
import 'ui/screens/main_screen.dart';
import 'ui/style/app_theme.dart';

void main(List<String> args) async {
  // 전역 에러 핸들러 설정
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Flutter 프레임워크 에러 핸들러
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('Flutter Error: ${details.exception}');
      debugPrint('StackTrace: ${details.stack}');
    };

    // 부팅 시 자동 시작 여부 확인
    final isAutostart = args.contains('--autostart');

    await _initializeApp(isAutostart: isAutostart);
  }, (error, stack) {
    // Zone에서 캐치되지 않은 에러
    debugPrint('Uncaught Error: $error');
    debugPrint('StackTrace: $stack');
  });
}

Future<void> _initializeApp({required bool isAutostart}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows Desktop 초기화
  await windowManager.ensureInitialized();

  const initialSize = Size(660, 980);
  const minimumSize = Size(640, 900);

  WindowOptions windowOptions = const WindowOptions(
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
    debugPrint('Autostart mode: shouldStartMinimized=$shouldStartMinimized');
  }

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (shouldStartMinimized) {
      // 백그라운드로 시작 (트레이만 표시)
      await windowManager.hide();
      debugPrint('Started minimized to tray');
    } else {
      // 정상적으로 창 표시
      await windowManager.show();
      await windowManager.focus();
    }
  });

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!shouldStartMinimized) {
      await _applyWindowMetrics(
          initialSize: initialSize, minimumSize: minimumSize);
    }
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

    if (ratio > 1.01 || ratio < 0.99) {
      // DPI 제대로 반영된 것 같으면 더 시도하지 않음
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
