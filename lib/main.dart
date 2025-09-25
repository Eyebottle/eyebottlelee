import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'ui/screens/main_screen.dart';

void main() async {
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
    title: '아이보틀 진료 녹음',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await _applyWindowMetrics(
        initialSize: initialSize, minimumSize: minimumSize);
  });

  runApp(const MedicalRecorderApp());
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
      title: '아이보틀 진료 녹음',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
