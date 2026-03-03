// MS Store 제출용 스크린샷 자동 캡처 테스트
// 실행: flutter test integration_test/screenshot_test.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medical_recorder/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // 스크린샷 저장 디렉토리
  final screenshotDir = Directory('screenshots');
  if (!screenshotDir.existsSync()) {
    screenshotDir.createSync(recursive: true);
  }

  group('MS Store 스크린샷 캡처', () {
    testWidgets('1. Dashboard - 메인 대시보드', (WidgetTester tester) async {
      // 앱 시작
      app.main([]);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 대시보드 탭 선택 (이미 기본 탭일 수 있음)
      final dashboardTab = find.text('대시보드');
      if (dashboardTab.evaluate().isNotEmpty) {
        await tester.tap(dashboardTab);
        await tester.pumpAndSettle();
      }

      // 녹음 시작 (선택적)
      final startButton = find.byIcon(Icons.mic);
      if (startButton.evaluate().isNotEmpty) {
        await tester.tap(startButton);
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }

      // 스크린샷 캡처
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();

      final screenshot = await binding.takeScreenshot('screenshot-1-dashboard');
      final file = File('screenshots/screenshot-1-dashboard.png');
      await file.writeAsBytes(screenshot);

      print('✓ Dashboard 스크린샷 저장: ${file.path}');
    });

    testWidgets('2. Schedule - 진료 시간표', (WidgetTester tester) async {
      app.main([]);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 녹음 설정 탭 선택
      final settingsTab = find.text('녹음 설정');
      if (settingsTab.evaluate().isNotEmpty) {
        await tester.tap(settingsTab);
        await tester.pumpAndSettle();
      }

      // 스크린샷 캡처
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();

      final screenshot = await binding.takeScreenshot('screenshot-2-schedule');
      final file = File('screenshots/screenshot-2-schedule.png');
      await file.writeAsBytes(screenshot);

      print('✓ Schedule 스크린샷 저장: ${file.path}');
    });

    testWidgets('3. Advanced Settings - 고급 설정', (WidgetTester tester) async {
      app.main([]);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 녹음 설정 탭으로 이동
      final settingsTab = find.text('녹음 설정');
      if (settingsTab.evaluate().isNotEmpty) {
        await tester.tap(settingsTab);
        await tester.pumpAndSettle();
      }

      // 고급 설정 버튼 찾기 및 클릭
      final advancedButton = find.text('고급 설정');
      if (advancedButton.evaluate().isNotEmpty) {
        await tester.tap(advancedButton);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // 스크린샷 캡처 (다이얼로그 포함)
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();

        final screenshot =
            await binding.takeScreenshot('screenshot-3-advanced-settings');
        final file = File('screenshots/screenshot-3-advanced-settings.png');
        await file.writeAsBytes(screenshot);

        print('✓ Advanced Settings 스크린샷 저장: ${file.path}');

        // 다이얼로그 닫기
        await tester.tapAt(const Offset(10, 10)); // 바깥 클릭
        await tester.pumpAndSettle();
      }
    });

    testWidgets('4. Auto Launch - 자동 실행', (WidgetTester tester) async {
      app.main([]);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 자동 실행 탭 선택
      final autoLaunchTab = find.text('자동 실행');
      if (autoLaunchTab.evaluate().isNotEmpty) {
        await tester.tap(autoLaunchTab);
        await tester.pumpAndSettle();
      }

      // 스크린샷 캡처
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();

      final screenshot =
          await binding.takeScreenshot('screenshot-4-auto-launch');
      final file = File('screenshots/screenshot-4-auto-launch.png');
      await file.writeAsBytes(screenshot);

      print('✓ Auto Launch 스크린샷 저장: ${file.path}');
    });

    testWidgets('5. Help - 도움말 센터', (WidgetTester tester) async {
      app.main([]);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 도움말 버튼 찾기 (? 아이콘)
      final helpButton = find.byIcon(Icons.help_outline);
      if (helpButton.evaluate().isNotEmpty) {
        await tester.tap(helpButton);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // 스크린샷 캡처 (다이얼로그 포함)
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();

        final screenshot = await binding.takeScreenshot('screenshot-5-help');
        final file = File('screenshots/screenshot-5-help.png');
        await file.writeAsBytes(screenshot);

        print('✓ Help 스크린샷 저장: ${file.path}');
      }
    });
  });
}
