import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'ui/screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows Desktop 초기화
  await windowManager.ensureInitialized();

  const initialSize = Size(650, 840);
  const minimumSize = Size(620, 780);

  WindowOptions windowOptions = const WindowOptions(
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: '아이보틀 진료 녹음',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    print('[Window] waitUntilReadyToShow');
    await windowManager.show();
    await windowManager.focus();
  });

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    print('[Window] addPostFrameCallback');
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
    print('[Window] attempt ${attempt + 1} dpr=$ratio');

    await windowManager.setMinimumSize(minimumSize);
    await windowManager.setSize(initialSize);
    await windowManager.center();
    await _logWindowState('applySize attempt ${attempt + 1}', ratio: ratio);

    if (ratio > 1.01 || ratio < 0.99) {
      // DPI 제대로 반영된 것 같으면 더 시도하지 않음
      break;
    }
  }
}

Future<void> _logWindowState(String label, {double? ratio}) async {
  final bounds = await windowManager.getBounds();
  final size = await windowManager.getSize();
  final position = await windowManager.getPosition();
  final devicePixelRatio = ratio ?? await windowManager.getDevicePixelRatio();

  print('[Window][$label] ratio=$devicePixelRatio '
      'size=${size.width}×${size.height} '
      'bounds=${bounds.size.width}×${bounds.size.height} '
      'pos=${position.dx},${position.dy}');
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
