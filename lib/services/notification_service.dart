import 'dart:async';
import 'dart:io' show Platform;

import 'logging_service.dart';

/// Windows 토스트 알림 서비스.
///
/// flutter_local_notifications 17.x는 Windows를 지원하지 않으므로,
/// 현재는 로깅만 수행합니다. 추후 19+ 버전 업그레이드 또는
/// win32 네이티브 토스트 API 구현 시 실제 알림을 표시합니다.
class NotificationService {
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  final LoggingService _logging = LoggingService();

  bool _initialized = false;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    _logging.info(
        'NotificationService initialized (stub - no Windows support in flutter_local_notifications 17.x)');
  }

  /// 알림 표시.
  ///
  /// 현재는 로깅만 수행합니다. 추후 Windows 토스트 API 구현 예정.
  Future<void> show({
    required String title,
    required String message,
    String? payload,
  }) async {
    if (!Platform.isWindows) return;

    await ensureInitialized();

    // TODO: flutter_local_notifications 19+ 또는 win32 토스트 API로 구현
    // 현재는 로깅으로 대체
    _logging.info('Notification: $title - $message');
  }
}
