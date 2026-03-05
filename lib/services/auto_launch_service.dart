import 'dart:io' show Platform;

import 'logging_service.dart';
import 'settings_service.dart';
import 'startup_task_service.dart';
import '../utils/win32_package_identity.dart';

/// Windows 자동 시작 설정을 관리합니다.
///
/// **v1.3.16: WinRT StartupTask API로 근본 교체**
///
/// - `launch_at_startup` 패키지 완전 제거 (MSIX 크래시 원인)
/// - Windows runner C++ Platform Channel을 통해 WinRT StartupTask API 직접 호출
/// - StartupTask 상태 조회, 활성화, 비활성화 모두 앱 내에서 제어 가능
class AutoLaunchService {
  AutoLaunchService._internal();

  static final AutoLaunchService _instance = AutoLaunchService._internal();

  factory AutoLaunchService() => _instance;

  final SettingsService _settings = SettingsService();
  final LoggingService _logging = LoggingService();
  final StartupTaskService _startupTask = StartupTaskService();

  /// 시작 시 저장된 설정을 읽고 StartupTask 상태를 동기화합니다.
  Future<bool> applySavedPreference() async {
    if (!Platform.isWindows) {
      _logging.debug(
          'AutoLaunchService: Non-Windows platform, skipping setup.');
      return true;
    }

    try {
      final startMinimized = await _settings.getStartMinimizedOnBoot();
      final state = await _startupTask.getState();
      _logging.info(
        'AutoLaunchService: startMinimizedOnBoot=$startMinimized, '
        'startupTaskState=$state',
      );
      return true;
    } catch (e, stackTrace) {
      _logging.warning(
        '자동 실행 설정 읽기 실패',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// WinRT StartupTask 활성화 요청.
  ///
  /// 반환값: 최종 상태 문자열 (enabled, disabled, disabledByUser 등)
  Future<String> enable() async {
    try {
      final result = await _startupTask.enable();
      _logging.info('AutoLaunchService: enable → $result');

      // 설정에도 반영
      await _settings.setLaunchAtStartup(true);
      return result;
    } catch (e, stackTrace) {
      _logging.warning('StartupTask 활성화 실패',
          error: e, stackTrace: stackTrace);
      return 'error';
    }
  }

  /// WinRT StartupTask 비활성화.
  Future<String> disable() async {
    try {
      final result = await _startupTask.disable();
      _logging.info('AutoLaunchService: disable → $result');

      // 설정에도 반영
      await _settings.setLaunchAtStartup(false);
      return result;
    } catch (e, stackTrace) {
      _logging.warning('StartupTask 비활성화 실패',
          error: e, stackTrace: stackTrace);
      return 'error';
    }
  }

  /// 현재 StartupTask 활성 여부.
  Future<bool> isEnabled() async {
    return await _startupTask.isEnabled();
  }

  /// 현재 StartupTask 상태 문자열.
  Future<String> getState() async {
    return await _startupTask.getState();
  }

  /// 사용자가 Windows 설정에서 직접 비활성화했는지.
  /// 이 상태에서는 앱이 다시 활성화할 수 없습니다.
  Future<bool> isDisabledByUser() async {
    return await _startupTask.isDisabledByUser();
  }

  /// 진단 정보 스냅샷을 반환합니다.
  Future<AutoLaunchStatusSnapshot> getStatusSnapshot() async {
    final startMinimized = await _settings.getStartMinimizedOnBoot();
    final state = await _startupTask.getState();
    final isPackaged = await _startupTask.isPackaged();

    String? packageFamilyName;
    try {
      packageFamilyName = tryGetPackageFamilyName(logging: _logging);
    } catch (e) {
      _logging.warning('PackageFamilyName 조회 실패: $e');
    }

    return AutoLaunchStatusSnapshot(
      startMinimizedOnBoot: startMinimized,
      isPackaged: isPackaged,
      packageFamilyName: packageFamilyName,
      startupTaskState: state,
      startupTaskEnabled:
          state == 'enabled' || state == 'enabledByPolicy',
    );
  }
}

class AutoLaunchStatusSnapshot {
  const AutoLaunchStatusSnapshot({
    required this.startMinimizedOnBoot,
    required this.isPackaged,
    required this.packageFamilyName,
    required this.startupTaskState,
    required this.startupTaskEnabled,
  });

  final bool startMinimizedOnBoot;
  final bool isPackaged;
  final String? packageFamilyName;
  final String startupTaskState;
  final bool startupTaskEnabled;
}
