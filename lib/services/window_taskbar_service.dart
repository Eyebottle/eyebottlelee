import 'package:window_manager/window_manager.dart';

import 'logging_service.dart';

class WindowTaskbarService {
  WindowTaskbarService._internal();

  static final WindowTaskbarService _instance =
      WindowTaskbarService._internal();

  factory WindowTaskbarService() => _instance;

  final LoggingService _logging = LoggingService();

  Future<void> showMainWindow({bool focus = true}) async {
    try {
      await windowManager.setSkipTaskbar(false);
      final isMinimized = await windowManager.isMinimized();
      if (isMinimized) {
        await windowManager.restore();
      }
      await windowManager.show();
      if (focus) {
        await windowManager.focus();
      }
    } catch (e, stackTrace) {
      _logging.warning('창 표시 실패', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> hideToTray() async {
    try {
      await windowManager.hide();
      await windowManager.setSkipTaskbar(true);
    } catch (e, stackTrace) {
      _logging.warning('창 숨김 실패', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> setTaskbarVisible(bool visible) async {
    try {
      await windowManager.setSkipTaskbar(!visible);
    } catch (e, stackTrace) {
      _logging.warning('작업표시줄 상태 변경 실패', error: e, stackTrace: stackTrace);
    }
  }
}
