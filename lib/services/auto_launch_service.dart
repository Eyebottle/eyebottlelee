import 'dart:async';
import 'dart:io' show Platform;

import 'package:launch_at_startup/launch_at_startup.dart';

import 'logging_service.dart';
import 'settings_service.dart';
import '../utils/win32_package_identity.dart';

/// Handles Windows auto-start registration in a single place.
class AutoLaunchService {
  AutoLaunchService._internal();

  static final AutoLaunchService _instance = AutoLaunchService._internal();

  factory AutoLaunchService() => _instance;

  final LaunchAtStartup _launcher = LaunchAtStartup.instance;
  final SettingsService _settings = SettingsService();
  final LoggingService _logging = LoggingService();

  static const String _autostartArg = '--autostart';

  Future<void>? _setupFuture;
  bool _setupCompleted = false;

  /// Applies the persisted auto-launch preference on startup.
  Future<bool> applySavedPreference() async {
    if (!Platform.isWindows) {
      _logging
          .debug('AutoLaunchService: Non-Windows platform, skipping setup.');
      return true;
    }

    final enabled = await _settings.getLaunchAtStartup();
    return _apply(enabled, source: 'startup-sync');
  }

  /// Updates the auto-launch registration to match the provided state.
  Future<bool> apply(bool enabled) async {
    if (!Platform.isWindows) {
      _logging
          .debug('AutoLaunchService: Non-Windows platform, apply() ignored.');
      return true;
    }
    return _apply(enabled, source: 'user-setting');
  }

  /// Returns current OS startup enabled state, or null if unavailable.
  Future<bool?> getCurrentEnabled() async {
    if (!Platform.isWindows) return null;

    try {
      await _ensureSetup();
    } catch (e, stackTrace) {
      _logging.warning('자동 실행 상태 조회 준비 실패', error: e, stackTrace: stackTrace);
      return null;
    }

    try {
      return await _invokeLauncher(() => _launcher.isEnabled());
    } catch (e, stackTrace) {
      _logging.warning('자동 실행 상태 조회 실패', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<AutoLaunchStatusSnapshot> getStatusSnapshot() async {
    final expected = await _settings.getLaunchAtStartup();
    final actual = await getCurrentEnabled();
    final packageFamilyName = tryGetPackageFamilyName(logging: _logging);
    return AutoLaunchStatusSnapshot(
      expectedEnabled: expected,
      actualEnabled: actual,
      isPackaged: packageFamilyName != null && packageFamilyName.isNotEmpty,
      packageFamilyName: packageFamilyName,
    );
  }

  Future<bool> _apply(bool enabled, {required String source}) async {
    try {
      await _ensureSetup();
    } catch (e, stackTrace) {
      _logging.error(
        '자동 실행 설정 준비 중 오류 (source=$source)',
        error: e,
        stackTrace: stackTrace,
      );
      // 초기화 실패 시 더 진행하지 않음
      return false;
    }

    try {
      // 현재 상태 확인 (불필요한 API 호출 방지)
      final isEnabled = await _invokeLauncher(() => _launcher.isEnabled());

      if (enabled) {
        if (!isEnabled) {
          await _invokeLauncher(() => _launcher.enable());
          _logging.info('자동 실행이 활성화되었습니다. (source=$source)');
        } else {
          _logging.debug('자동 실행이 이미 활성화되어 있습니다. (source=$source)');
        }
      } else {
        if (isEnabled) {
          await _invokeLauncher(() => _launcher.disable());
          _logging.info('자동 실행이 비활성화되었습니다. (source=$source)');
        } else {
          _logging.debug('자동 실행이 이미 비활성화되어 있습니다. (source=$source)');
        }
      }

      final verified = await _invokeLauncher(() => _launcher.isEnabled());
      if (verified != enabled) {
        _logging.warning(
            '자동 실행 상태 불일치: expected=$enabled actual=$verified (source=$source)');
        return false;
      }
      return true;
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
      final packageFamilyName = tryGetPackageFamilyName(logging: _logging);
      try {
        // --autostart 플래그: 부팅 시 백그라운드 시작 기능을 위해 필요
        //
        // ✅ MSIX(Store)에서는 packageName(PackageFamilyName)이 있어야
        // StartupTask API로 enable/disable이 가능합니다.
        //
        // ✅ 패키지 앱이 아닌(폴더 복사 실행 등) 경우에는 packageName이 없으므로,
        // packageName 없이 setup을 호출해 레지스트리 방식(가능한 환경)으로 동작하게 합니다.
        if (packageFamilyName != null) {
          await _invokeLauncher(() => _launcher.setup(
                appName: 'Eyebottle Medical Recorder',
                appPath: exePath,
                args: const <String>[_autostartArg],
                packageName: packageFamilyName,
              ));
        } else {
          _logging.warning(
            'PackageFamilyName을 찾지 못했습니다. (MSIX가 아닌 실행일 수 있음) '
            '레지스트리 방식으로 setup을 시도합니다.',
          );
          await _invokeLauncher(() => _launcher.setup(
                appName: 'Eyebottle Medical Recorder',
                appPath: exePath,
                args: const <String>[_autostartArg],
              ));
        }
        _setupCompleted = true;
        _logging.debug(
          '자동 실행 등록 준비 완료 (path=$exePath, pkg=$packageFamilyName)',
        );
      } catch (e, stackTrace) {
        _setupCompleted = false;
        _setupFuture = null;
        _logging.error(
          '자동 실행 초기화 실패 (path=$exePath, pkg=$packageFamilyName)',
          error: e,
          stackTrace: stackTrace,
        );
        rethrow;
      }
    }();

    return _setupFuture!;
  }

  Future<T> _invokeLauncher<T>(FutureOr<T> Function() action) async {
    final result = action();
    if (result is Future) {
      return await result;
    }
    return result;
  }
}

class AutoLaunchStatusSnapshot {
  const AutoLaunchStatusSnapshot({
    required this.expectedEnabled,
    required this.actualEnabled,
    required this.isPackaged,
    required this.packageFamilyName,
  });

  final bool expectedEnabled;
  final bool? actualEnabled;
  final bool isPackaged;
  final String? packageFamilyName;
}
