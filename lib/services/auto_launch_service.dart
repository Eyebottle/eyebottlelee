import 'dart:async';
import 'dart:io' show Platform;

import 'package:launch_at_startup/launch_at_startup.dart';

import 'logging_service.dart';
import 'settings_service.dart';

/// Handles Windows auto-start registration in a single place.
class AutoLaunchService {
  AutoLaunchService._internal();

  static final AutoLaunchService _instance = AutoLaunchService._internal();

  factory AutoLaunchService() => _instance;

  final LaunchAtStartup _launcher = LaunchAtStartup.instance;
  final SettingsService _settings = SettingsService();
  final LoggingService _logging = LoggingService();

  Future<void>? _setupFuture;
  bool _setupCompleted = false;

  /// Applies the persisted auto-launch preference on startup.
  Future<void> applySavedPreference() async {
    if (!Platform.isWindows) {
      _logging
          .debug('AutoLaunchService: Non-Windows platform, skipping setup.');
      return;
    }

    final enabled = await _settings.getLaunchAtStartup();
    await _apply(enabled, source: 'startup-sync');
  }

  /// Updates the auto-launch registration to match the provided state.
  Future<void> apply(bool enabled) async {
    if (!Platform.isWindows) {
      _logging
          .debug('AutoLaunchService: Non-Windows platform, apply() ignored.');
      return;
    }
    await _apply(enabled, source: 'user-setting');
  }

  Future<void> _apply(bool enabled, {required String source}) async {
    try {
      await _ensureSetup();
    } catch (e, stackTrace) {
      _logging.error(
        '자동 실행 설정 준비 중 오류 (source=$source)',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }

    try {
      if (enabled) {
        await _invokeLauncher(() => _launcher.enable());
        _logging.info('자동 실행이 활성화되었습니다. (source=$source)');
      } else {
        await _invokeLauncher(() => _launcher.disable());
        _logging.info('자동 실행이 비활성화되었습니다. (source=$source)');
      }
    } catch (e, stackTrace) {
      _logging.error(
        '자동 실행 상태 변경 실패 (enabled=$enabled, source=$source)',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _ensureSetup() {
    if (_setupCompleted) {
      return Future<void>.value();
    }

    if (_setupFuture != null) {
      return _setupFuture!;
    }

    _setupFuture = () async {
      if (!Platform.isWindows) {
        _setupCompleted = true;
        return;
      }

      final exePath = Platform.resolvedExecutable;
      try {
        await _invokeLauncher(() => _launcher.setup(
              appName: 'Eyebottle Medical Recorder',
              appPath: exePath,
              args: const <String>[],
            ));
        _setupCompleted = true;
        _logging.debug('자동 실행 등록 준비 완료 (path=$exePath)');
      } catch (e, stackTrace) {
        _setupCompleted = false;
        _setupFuture = null;
        _logging.error(
          '자동 실행 초기화 실패 (path=$exePath)',
          error: e,
          stackTrace: stackTrace,
        );
        rethrow;
      }
    }();

    return _setupFuture!;
  }

  Future<void> _invokeLauncher(FutureOr<void> Function() action) async {
    final result = action();
    if (result is Future) {
      await result;
    }
  }
}
