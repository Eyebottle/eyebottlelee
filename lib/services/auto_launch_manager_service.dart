import 'dart:async';

import '../models/launch_program.dart';
import '../models/launch_manager_settings.dart';
import '../utils/win32_shell_execute.dart';
import 'logging_service.dart';
import 'settings_service.dart';

/// 프로그램 실행 상태를 나타내는 열거형
enum LaunchExecutionStatus {
  idle, // 대기 상태
  running, // 실행 중
  completed, // 완료
  failed, // 실패
}

/// 프로그램 실행 진행 상황을 나타내는 모델
class LaunchExecutionProgress {
  const LaunchExecutionProgress({
    required this.status,
    required this.currentIndex,
    required this.totalCount,
    this.currentProgram,
    this.message,
    this.errorMessage,
  });

  final LaunchExecutionStatus status;
  final int currentIndex;
  final int totalCount;
  final LaunchProgram? currentProgram;
  final String? message;
  final String? errorMessage;

  double get progress {
    if (totalCount == 0) return 0.0;
    return currentIndex / totalCount;
  }

  bool get isCompleted => status == LaunchExecutionStatus.completed;
  bool get isFailed => status == LaunchExecutionStatus.failed;
  bool get isRunning => status == LaunchExecutionStatus.running;
}

/// 자동 실행 매니저 서비스 - 프로그램 순차 실행을 담당
class AutoLaunchManagerService {
  AutoLaunchManagerService._internal();

  static final AutoLaunchManagerService _instance =
      AutoLaunchManagerService._internal();

  factory AutoLaunchManagerService() => _instance;

  final LoggingService _logging = LoggingService();
  final SettingsService _settings = SettingsService();

  // 실행 진행 상황 스트림
  final StreamController<LaunchExecutionProgress> _progressController =
      StreamController<LaunchExecutionProgress>.broadcast();

  Stream<LaunchExecutionProgress> get progressStream =>
      _progressController.stream;

  bool _isCancelled = false; // 취소 요청 플래그
  bool _isDisposed = false; // dispose 여부

  LaunchExecutionProgress _currentProgress = const LaunchExecutionProgress(
    status: LaunchExecutionStatus.idle,
    currentIndex: 0,
    totalCount: 0,
  );

  LaunchExecutionProgress get currentProgress => _currentProgress;

  bool _isExecuting = false;

  /// 현재 실행 중인지 확인
  bool get isExecuting => _isExecuting;

  /// 자동 실행 매니저 설정 로드
  Future<LaunchManagerSettings> loadSettings() async {
    return await _settings.getLaunchManagerSettings();
  }

  /// 자동 실행 매니저 설정 저장
  Future<void> saveSettings(LaunchManagerSettings settings) async {
    await _settings.setLaunchManagerSettings(settings);
  }

  /// 등록된 프로그램들을 순차적으로 실행
  Future<void> executePrograms() async {
    if (_isExecuting) {
      _logging.warning('프로그램 실행이 이미 진행 중입니다.');
      return;
    }

    // 각 프로그램의 마지막 실행 시각을 메모리에 모았다가, 루프 종료(또는 취소·예외)
    // 후 한 번만 저장한다. 매 프로그램마다 저장하던 기존 방식은 O(n) 디스크 쓰기 +
    // 실행 도중 사용자의 설정 편집을 통째로 덮어쓰는 lost-update 경합이 있었다.
    final executedTimes = <String, DateTime>{};
    try {
      _isExecuting = true;
      _isCancelled = false;
      await _logging.ensureInitialized();

      final settings = await loadSettings();

      if (!settings.autoLaunchEnabled) {
        _logging.info('자동 실행이 비활성화되어 있습니다.');
        return;
      }

      final programs = settings.enabledPrograms;

      if (programs.isEmpty) {
        _logging.info('실행할 프로그램이 없습니다.');
        _updateProgress(LaunchExecutionStatus.completed, 0, 0,
            message: '실행할 프로그램이 없습니다.');
        return;
      }

      _logging.info('프로그램 자동 실행을 시작합니다. 총 ${programs.length}개');
      _updateProgress(LaunchExecutionStatus.running, 0, programs.length,
          message: '자동 실행을 시작합니다.');

      int successCount = 0;
      int failureCount = 0;

      for (int i = 0; i < programs.length; i++) {
        // 취소 요청 확인
        if (_isCancelled) {
          _logging.info('사용자에 의해 실행이 취소되었습니다.');
          await _persistLastExecuted(executedTimes);
          _updateProgress(LaunchExecutionStatus.idle, i, programs.length,
              message: '실행이 취소되었습니다. (완료: $successCount개, 실패: $failureCount개)');
          return;
        }

        final program = programs[i];

        _updateProgress(LaunchExecutionStatus.running, i, programs.length,
            currentProgram: program,
            message: '${program.name} 실행 중... (${i + 1}/${programs.length})');

        final success = await _launchProgram(program);

        if (success) {
          successCount++;
          _logging.info('프로그램 실행 성공: ${program.name}');
          // 저장은 루프 종료 후 한 번에 (위 executedTimes 주석 참고).
          executedTimes[program.id] = DateTime.now();
        } else {
          failureCount++;
          _logging.error('프로그램 실행 실패: ${program.name}');
          // 실패해도 다음 프로그램으로 계속 진행
        }

        // 마지막 프로그램이 아닌 경우 대기 (취소 확인 포함)
        if (i < programs.length - 1 && !_isCancelled) {
          _logging.debug('${program.delaySeconds}초 대기 중...');
          await _delayWithCancelCheck(program.delaySeconds);
        }
      }

      final totalPrograms = programs.length;
      final completionMessage = '완료: $successCount개, 실패: $failureCount개';

      await _persistLastExecuted(executedTimes);

      _updateProgress(
          LaunchExecutionStatus.completed, totalPrograms, totalPrograms,
          message: completionMessage);

      _logging.info('프로그램 자동 실행 완료. $completionMessage');
    } catch (e, stackTrace) {
      _logging.error('프로그램 자동 실행 중 오류 발생', error: e, stackTrace: stackTrace);
      await _persistLastExecuted(executedTimes);
      _updateProgress(LaunchExecutionStatus.failed, 0, 0,
          errorMessage: '실행 중 오류가 발생했습니다: $e');
    } finally {
      _isExecuting = false;
      _isCancelled = false;
    }
  }

  /// 모아둔 lastExecuted 값을 한 번에 저장한다.
  ///
  /// 실행 도중 사용자가 UI에서 프로그램을 추가/삭제/재정렬했을 수 있으므로,
  /// 시작 시점 스냅샷을 통째로 덮어쓰지 않고 최신 설정을 다시 읽어 id가 일치하는
  /// 항목의 lastExecuted만 병합한다. (lost-update 방지)
  Future<void> _persistLastExecuted(Map<String, DateTime> executed) async {
    if (executed.isEmpty) return;
    try {
      var latest = await loadSettings();
      for (final entry in executed.entries) {
        final idx = latest.programs.indexWhere((p) => p.id == entry.key);
        if (idx < 0) continue; // 실행 도중 사용자가 삭제한 프로그램
        latest = latest.updateProgram(
          latest.programs[idx].copyWith(lastExecuted: entry.value),
        );
      }
      await saveSettings(latest);
    } catch (e, stackTrace) {
      _logging.warning('lastExecuted 저장 실패', error: e, stackTrace: stackTrace);
    }
  }

  /// 취소 가능한 대기
  ///
  /// 1초 단위로 취소 여부를 확인하면서 대기합니다.
  Future<void> _delayWithCancelCheck(int seconds) async {
    for (int i = 0; i < seconds; i++) {
      if (_isCancelled) return;
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  /// 개별 프로그램 실행 (Windows 셸 ShellExecuteEx 사용)
  ///
  /// 실행 파일(.exe), 바로가기(.lnk), 배치(.bat/.cmd), 문서, URL을 모두 셸이
  /// 알맞게 처리하며, 프로그램별 [WindowState]를 창 표시 방식으로 반영한다.
  Future<bool> _launchProgram(LaunchProgram program) async {
    try {
      _logging.debug('프로그램 실행 검증 시작: ${program.name}');
      _logging.debug('  - 경로: ${program.path}');
      _logging.debug('  - 인수: ${program.arguments}');
      _logging.debug('  - 작업 디렉터리: ${program.workingDirectory ?? "(없음)"}');
      _logging.debug('  - 창 상태: ${program.windowState.name}');

      if (!program.isValid) {
        _logging.error('프로그램 파일을 찾을 수 없습니다: ${program.path}');
        return false;
      }

      _logging.info(
          '프로그램 실행 시도(ShellExecuteEx): ${program.name} (${program.path})');

      final result = shellExecuteProgram(
        path: program.path,
        arguments: program.arguments,
        workingDirectory: program.workingDirectory,
        windowState: program.windowState,
        logging: _logging,
      );

      if (result.success) {
        _logging.info(
            '프로그램 실행 성공: ${program.name} (hInstApp: ${result.hInstApp})');
        return true;
      }

      _logging.error(
          '프로그램 실행 실패: ${program.name} (errorCode: ${result.errorCode})');
      return false;
    } catch (e, stackTrace) {
      _logging.error('프로그램 실행 실패: ${program.name}',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 단일 프로그램 테스트 실행
  Future<bool> testLaunchProgram(LaunchProgram program) async {
    await _logging.ensureInitialized();
    _logging.info('프로그램 테스트 실행: ${program.name}');

    return await _launchProgram(program);
  }

  /// 실행 진행 상황 업데이트
  void _updateProgress(
    LaunchExecutionStatus status,
    int currentIndex,
    int totalCount, {
    LaunchProgram? currentProgram,
    String? message,
    String? errorMessage,
  }) {
    _currentProgress = LaunchExecutionProgress(
      status: status,
      currentIndex: currentIndex,
      totalCount: totalCount,
      currentProgram: currentProgram,
      message: message,
      errorMessage: errorMessage,
    );

    // StreamController가 닫히지 않은 경우에만 전송
    if (!_isDisposed && !_progressController.isClosed) {
      _progressController.add(_currentProgress);
    }
  }

  /// 실행 중단
  ///
  /// 현재 실행 중인 프로그램은 완료되지만, 다음 프로그램은 실행되지 않습니다.
  /// 대기 중인 delay도 즉시 중단됩니다.
  void cancel() {
    if (_isExecuting) {
      _logging.info('프로그램 자동 실행 취소 요청됨');
      _isCancelled = true;
      // 실제 상태 업데이트는 executePrograms 루프에서 처리
    }
  }

  /// 서비스 종료 시 리소스 정리
  void dispose() {
    _isDisposed = true;
    _isCancelled = true;
    _progressController.close();
  }
}
