import 'package:flutter/services.dart';

/// WinRT StartupTask API를 Platform Channel로 호출하는 서비스.
///
/// Windows runner의 C++ 코드(startup_task_handler.cpp)와 통신하여
/// MSIX StartupTask를 직접 제어합니다.
///
/// 지원 메서드:
///   - [getState]: 현재 StartupTask 상태 조회
///   - [enable]:   StartupTask 활성화 요청
///   - [disable]:  StartupTask 비활성화
///   - [isPackaged]: MSIX 패키지 환경 여부 확인
class StartupTaskService {
  static const _channel = MethodChannel('eyebottle/startup_task');

  /// 싱글톤
  static final StartupTaskService _instance = StartupTaskService._();
  factory StartupTaskService() => _instance;
  StartupTaskService._();

  /// 현재 StartupTask 상태를 반환합니다.
  ///
  /// 반환값:
  ///   - `enabled`: 활성화됨
  ///   - `disabled`: 앱에서 비활성화됨
  ///   - `disabledByUser`: 사용자가 Windows 설정에서 비활성화
  ///   - `disabledByPolicy`: 그룹 정책에 의해 비활성화
  ///   - `enabledByPolicy`: 그룹 정책에 의해 활성화
  ///   - `notPackaged`: MSIX 패키지가 아님 (개발 환경)
  ///   - `unavailable`: StartupTask를 찾을 수 없음
  ///   - `error`: API 호출 실패
  Future<String> getState() async {
    try {
      final result = await _channel.invokeMethod<String>('getState');
      return result ?? 'error';
    } on PlatformException catch (e) {
      return 'error:${e.code}';
    } on MissingPluginException {
      // 플러그인 미등록 (비-Windows 환경 또는 개발 모드)
      return 'notPackaged';
    }
  }

  /// StartupTask를 활성화합니다.
  ///
  /// 반환값: 활성화 후 상태 문자열 (보통 `enabled`)
  /// 참고: `disabledByUser` 상태인 경우 Windows가 사용자에게 확인 다이얼로그를 표시합니다.
  Future<String> enable() async {
    try {
      final result = await _channel.invokeMethod<String>('enable');
      return result ?? 'error';
    } on PlatformException catch (e) {
      return 'error:${e.code}';
    } on MissingPluginException {
      return 'notPackaged';
    }
  }

  /// StartupTask를 비활성화합니다.
  ///
  /// 반환값: `disabled` (성공 시)
  Future<String> disable() async {
    try {
      final result = await _channel.invokeMethod<String>('disable');
      return result ?? 'error';
    } on PlatformException catch (e) {
      return 'error:${e.code}';
    } on MissingPluginException {
      return 'notPackaged';
    }
  }

  /// MSIX 패키지 환경인지 확인합니다.
  Future<bool> isPackaged() async {
    try {
      final result = await _channel.invokeMethod<bool>('isPackaged');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// StartupTask가 활성화되어 있는지 편의 메서드.
  Future<bool> isEnabled() async {
    final state = await getState();
    return state == 'enabled' || state == 'enabledByPolicy';
  }

  /// 사용자가 Windows 설정에서 직접 비활성화했는지 확인.
  /// 이 상태에서는 앱이 직접 다시 활성화할 수 없고,
  /// 사용자가 Windows 설정에서 다시 켜야 합니다.
  Future<bool> isDisabledByUser() async {
    final state = await getState();
    return state == 'disabledByUser';
  }
}
