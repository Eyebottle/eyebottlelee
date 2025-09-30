import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/launch_program.dart';
import '../models/launch_manager_settings.dart';
import 'logging_service.dart';
import 'settings_service.dart';

/// 프로그램 실행 상태를 나타내는 열거형
enum LaunchExecutionStatus {
  idle,       // 대기 상태
  running,    // 실행 중
  completed,  // 완료
  failed,     // 실패
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

  static final AutoLaunchManagerService _instance = AutoLaunchManagerService._internal();

  factory AutoLaunchManagerService() => _instance;

  final LoggingService _logging = LoggingService();
  final SettingsService _settings = SettingsService();

  // 실행 진행 상황 스트림
  final StreamController<LaunchExecutionProgress> _progressController =
      StreamController<LaunchExecutionProgress>.broadcast();

  Stream<LaunchExecutionProgress> get progressStream => _progressController.stream;

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

    try {
      _isExecuting = true;
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
        final program = programs[i];

        _updateProgress(LaunchExecutionStatus.running, i, programs.length,
            currentProgram: program,
            message: '${program.name} 실행 중... (${i + 1}/${programs.length})');

        final success = await _launchProgram(program);

        if (success) {
          successCount++;
          _logging.info('프로그램 실행 성공: ${program.name}');

          // 마지막 실행 시간 업데이트 및 저장
          final updatedProgram = program.copyWith(lastExecuted: DateTime.now());
          final updatedSettings = settings.updateProgram(updatedProgram);
          await saveSettings(updatedSettings);
        } else {
          failureCount++;
          _logging.error('프로그램 실행 실패: ${program.name}');

          if (!settings.retryOnFailure) {
            // 재시도 옵션이 비활성화된 경우 다음 프로그램으로 계속
            continue;
          }
        }

        // 마지막 프로그램이 아닌 경우 대기
        if (i < programs.length - 1) {
          _logging.debug('${program.delaySeconds}초 대기 중...');
          await Future.delayed(Duration(seconds: program.delaySeconds));
        }
      }

      final totalPrograms = programs.length;
      final completionMessage = '완료: $successCount개, 실패: $failureCount개';

      _updateProgress(LaunchExecutionStatus.completed, totalPrograms, totalPrograms,
          message: completionMessage);

      _logging.info('프로그램 자동 실행 완료. $completionMessage');

    } catch (e, stackTrace) {
      _logging.error('프로그램 자동 실행 중 오류 발생', error: e, stackTrace: stackTrace);
      _updateProgress(LaunchExecutionStatus.failed, 0, 0,
          errorMessage: '실행 중 오류가 발생했습니다: $e');
    } finally {
      _isExecuting = false;
    }
  }

  /// 개별 프로그램 실행
  Future<bool> _launchProgram(LaunchProgram program) async {
    try {
      // 파일 존재 여부 확인
      _logging.debug('프로그램 실행 검증 시작: ${program.name}');
      _logging.debug('  - 경로: ${program.path}');
      _logging.debug('  - 인수: ${program.arguments}');
      _logging.debug('  - 작업 디렉터리: ${program.workingDirectory ?? "(없음)"}');
      _logging.debug('  - 배치 파일 여부: ${program.isBatchFile}');

      if (!program.isValid) {
        _logging.error('프로그램 파일을 찾을 수 없습니다: ${program.path}');
        _logging.error('  - File.existsSync() = false');
        return false;
      }

      _logging.info('프로그램 실행 시도: ${program.name} (${program.path})');

      // 실행 파일 여부 확인
      final isExecutable = program.isExecutable;
      final isShortcut = program.isShortcut;

      if (!isExecutable) {
        _logging.debug('문서 파일 감지 - Windows 기본 프로그램으로 실행');
      } else if (isShortcut) {
        _logging.debug('바로가기 파일 감지 - cmd.exe로 실행');
      }

      // Process.start로 프로그램 실행
      final String executable;
      final List<String> args;

      if (!isExecutable || isShortcut) {
        // 문서 파일 또는 바로가기는 cmd /c start로 실행
        // 빈 문자열("")은 창 제목을 지정하는 것으로, 경로에 공백이 있어도 올바르게 동작
        executable = 'cmd.exe';
        args = ['/c', 'start', '""', program.path, ...program.arguments];
      } else {
        // 실행 파일은 직접 실행
        executable = program.path;
        args = program.arguments;
      }

      _logging.debug('실행 명령: $executable ${args.join(" ")}');

      final process = await Process.start(
        executable,
        args,
        workingDirectory: program.workingDirectory?.isNotEmpty == true
            ? program.workingDirectory
            : null,
        mode: ProcessStartMode.detached,
        runInShell: true, // cmd.exe 사용 시 항상 true
      );

      _logging.info('프로그램 실행 성공: ${program.name} (PID: ${process.pid})');
      return true;

    } catch (e, stackTrace) {
      _logging.error('프로그램 실행 실패: ${program.name}');
      _logging.error('  - 에러 타입: ${e.runtimeType}');
      _logging.error('  - 에러 메시지: $e');
      _logging.error('  - 경로: ${program.path}');
      _logging.error('  - 스택트레이스: $stackTrace');
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

    _progressController.add(_currentProgress);
  }

  /// 실행 중단
  void cancel() {
    if (_isExecuting) {
      _logging.info('프로그램 자동 실행이 취소되었습니다.');
      _isExecuting = false;
      _updateProgress(LaunchExecutionStatus.idle, 0, 0,
          message: '실행이 취소되었습니다.');
    }
  }

  /// 서비스 종료 시 리소스 정리
  void dispose() {
    _progressController.close();
  }
}