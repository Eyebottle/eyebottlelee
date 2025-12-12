import 'dart:async';
import 'dart:io' show Platform;

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
// win32 패키지에서 필요한 상수만 import
import 'package:win32/win32.dart'
    show
        APPMODEL_ERROR_NO_PACKAGE,
        ERROR_INSUFFICIENT_BUFFER,
        ERROR_SUCCESS,
        WCHAR;

import 'logging_service.dart';
import 'settings_service.dart';

// kernel32.dll에서 GetCurrentPackageFamilyName을 직접 로드
// (win32 패키지 5.x에서는 이 함수가 export되지 않음)
final _kernel32 = DynamicLibrary.open('kernel32.dll');

/// GetCurrentPackageFamilyName 함수 시그니처
/// LONG GetCurrentPackageFamilyName(UINT32 *length, PWSTR familyName);
final _getCurrentPackageFamilyName = _kernel32.lookupFunction<
    Int32 Function(Pointer<Uint32> length, Pointer<Utf16> familyName),
    int Function(
        Pointer<Uint32> length, Pointer<Utf16> familyName)>('GetCurrentPackageFamilyName');

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
      // 초기화 실패 시 더 진행하지 않음
      return;
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
      final packageFamilyName = _tryGetCurrentPackageFamilyName();
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

  /// 현재 프로세스가 MSIX(패키지 앱)로 실행 중이면 PackageFamilyName을 반환합니다.
  ///
  /// - **입력**: 없음
  /// - **출력**: PackageFamilyName 문자열 또는 null(패키지 앱이 아님)
  /// - **예외**: 던지지 않음 (실패 시 null 반환)
  ///
  /// 쉬운 비유:
  /// - “앱의 주민등록번호” 같은 값입니다. MS Store로 설치된 앱은 이 값으로
  ///   StartupTask(시작프로그램)를 켜고 끄는 것을 식별합니다.
  String? _tryGetCurrentPackageFamilyName() {
    if (!Platform.isWindows) return null;

    final length = calloc<Uint32>();
    try {
      // 1) 필요한 버퍼 길이를 먼저 알아냅니다.
      var rc = _getCurrentPackageFamilyName(length, nullptr.cast<Utf16>());

      // 패키지 앱이 아닌 경우 (일반 exe 직접 실행)
      if (rc == APPMODEL_ERROR_NO_PACKAGE) {
        return null;
      }

      // 버퍼가 부족하면 length에 필요한 크기가 들어옵니다.
      if (rc != ERROR_INSUFFICIENT_BUFFER) {
        // 어떤 이유로든 실패하면 null (앱은 계속 동작해야 하므로)
        _logging.warning('GetCurrentPackageFamilyName(1) failed: rc=$rc');
        return null;
      }

      final buffer = calloc<WCHAR>(length.value);
      try {
        rc = _getCurrentPackageFamilyName(length, buffer.cast<Utf16>());
        if (rc != ERROR_SUCCESS) {
          _logging.warning('GetCurrentPackageFamilyName(2) failed: rc=$rc');
          return null;
        }
        final name = buffer.cast<Utf16>().toDartString();
        return name.isEmpty ? null : name;
      } finally {
        calloc.free(buffer);
      }
    } catch (e) {
      _logging.warning('PackageFamilyName detection failed', error: e);
      return null;
    } finally {
      calloc.free(length);
    }
  }

  Future<T> _invokeLauncher<T>(FutureOr<T> Function() action) async {
    final result = action();
    if (result is Future) {
      return await result;
    }
    return result;
  }
}
