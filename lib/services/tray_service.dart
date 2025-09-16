import 'package:flutter/foundation.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

enum TrayIconState { recording, waiting, error }

class TrayService {
  final SystemTray _systemTray = SystemTray();
  bool _isInitialized = false;

  // 콜백 함수들
  Function()? onStartRecording;
  Function()? onStopRecording;
  Function()? onShowWindow;
  Function()? onExit;

  /// 시스템 트레이 초기화
  Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      await _systemTray.initSystemTray(
        title: '아이보틀 진료 녹음',
        toolTip: '진료 녹음 대기 중',
        iconPath: _getIconPath(TrayIconState.waiting),
      );

      await _setupTrayMenu();
      _isInitialized = true;

      debugPrint('시스템 트레이가 초기화되었습니다.');
    } catch (e) {
      debugPrint('시스템 트레이 초기화 실패: $e');
    }
  }

  /// 트레이 메뉴 설정
  Future<void> _setupTrayMenu() async {
    final Menu menu = Menu();

    await menu.buildFrom([
      MenuItemLabel(
        label: '창 보기',
        onClicked: (menuItem) => _showMainWindow(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: '녹음 시작',
        onClicked: (menuItem) => _handleStartRecording(),
      ),
      MenuItemLabel(
        label: '녹음 중지',
        onClicked: (menuItem) => _handleStopRecording(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: '설정',
        onClicked: (menuItem) => _showSettings(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: '종료',
        onClicked: (menuItem) => _handleExit(),
      ),
    ]);

    await _systemTray.setContextMenu(menu);
  }

  /// 트레이 아이콘 상태 업데이트
  Future<void> updateTrayIcon(TrayIconState state) async {
    if (!_isInitialized) return;

    try {
      final iconPath = _getIconPath(state);
      final toolTip = _getToolTip(state);

      await _systemTray.setImage(iconPath);
      await _systemTray.setToolTip(toolTip);

      debugPrint('트레이 아이콘 상태 업데이트: $state');
    } catch (e) {
      debugPrint('트레이 아이콘 업데이트 실패: $e');
    }
  }

  /// 상태별 아이콘 경로 반환
  String _getIconPath(TrayIconState state) {
    switch (state) {
      case TrayIconState.recording:
        return 'assets/icons/tray_recording.ico';
      case TrayIconState.waiting:
        return 'assets/icons/tray_waiting.ico';
      case TrayIconState.error:
        return 'assets/icons/tray_error.ico';
    }
  }

  /// 상태별 툴팁 반환
  String _getToolTip(TrayIconState state) {
    switch (state) {
      case TrayIconState.recording:
        return '아이보틀 진료 녹음 - 녹음 중';
      case TrayIconState.waiting:
        return '아이보틀 진료 녹음 - 대기 중';
      case TrayIconState.error:
        return '아이보틀 진료 녹음 - 오류 발생';
    }
  }

  /// 메인 창 보이기
  void _showMainWindow() {
    try {
      windowManager.show();
      windowManager.focus();
      if (onShowWindow != null) {
        onShowWindow!();
      }
    } catch (e) {
      debugPrint('메인 창 표시 실패: $e');
    }
  }

  /// 녹음 시작 처리
  void _handleStartRecording() {
    if (onStartRecording != null) {
      onStartRecording!();
    }
  }

  /// 녹음 중지 처리
  void _handleStopRecording() {
    if (onStopRecording != null) {
      onStopRecording!();
    }
  }

  /// 설정 창 표시
  void _showSettings() {
    _showMainWindow(); // 현재는 메인 창으로 이동
  }

  /// 앱 종료 처리
  void _handleExit() {
    if (onExit != null) {
      onExit!();
    }
  }

  /// 알림 표시
  Future<void> showNotification(String title, String message) async {
    try {
      // TODO: 알림 구현 (향후 추가)
      debugPrint('알림: $title - $message');
    } catch (e) {
      debugPrint('알림 표시 실패: $e');
    }
  }

  /// 서비스 정리
  void dispose() {
    try {
      _systemTray.destroy();
      _isInitialized = false;
      debugPrint('시스템 트레이가 정리되었습니다.');
    } catch (e) {
      debugPrint('시스템 트레이 정리 실패: $e');
    }
  }
}