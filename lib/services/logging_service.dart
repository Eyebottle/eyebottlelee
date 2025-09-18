import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

typedef LoggingErrorHandler = void Function(String message);

/// 애플리케이션 전역 로깅 서비스를 담당한다.
class LoggingService {
  LoggingService._internal();

  static final LoggingService _instance = LoggingService._internal();

  factory LoggingService() => _instance;

  final List<LoggingErrorHandler> _errorHandlers = [];

  Logger? _logger;
  _DailyRotatingFileOutput? _fileOutput;
  Future<void>? _initializationFuture;

  /// 로거 초기화를 보장한다. 반복 호출 시 최초 초기화 완료 여부만 기다린다.
  Future<void> ensureInitialized() {
    if (_logger != null) {
      return Future.value();
    }

    if (_initializationFuture != null) {
      return _initializationFuture!;
    }

    _initializationFuture = _createLogger();
    return _initializationFuture!;
  }

  Future<void> _createLogger() async {
    try {
      final logDirectory = await _resolveLogDirectory();
      _fileOutput = _DailyRotatingFileOutput(
        directory: logDirectory,
        retention: const Duration(days: 14),
        onWriteError: _notifyError,
      );

      _logger = Logger(
        level: Level.debug,
        printer: PrettyPrinter(
          methodCount: 0,
          errorMethodCount: 4,
          lineLength: 110,
          colors: false,
          printEmojis: true,
          noBoxingByDefault: true,
        ),
        output: _fileOutput,
        filter: ProductionFilter(),
      );

      _logger!.i('LoggingService initialized at ${logDirectory.path}');
    } catch (e, stackTrace) {
      debugPrint('로그 초기화 실패: $e');
      _notifyError('로그 초기화 실패: $e');
      _initializationFuture = null;
      Error.throwWithStackTrace(e, stackTrace);
    }
  }

  /// 오류 리스너 등록
  void addErrorListener(LoggingErrorHandler handler) {
    if (!_errorHandlers.contains(handler)) {
      _errorHandlers.add(handler);
    }
  }

  /// 오류 리스너 제거
  void removeErrorListener(LoggingErrorHandler handler) {
    _errorHandlers.remove(handler);
  }

  /// 디버그 레벨 기록
  void debug(String message, {Object? error, StackTrace? stackTrace}) {
    _log(Level.debug, message, error: error, stackTrace: stackTrace);
  }

  /// 정보 레벨 기록
  void info(String message, {Object? error, StackTrace? stackTrace}) {
    _log(Level.info, message, error: error, stackTrace: stackTrace);
  }

  /// 경고 레벨 기록
  void warning(String message, {Object? error, StackTrace? stackTrace}) {
    _log(Level.warning, message, error: error, stackTrace: stackTrace);
  }

  /// 오류 레벨 기록
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _log(Level.error, message, error: error, stackTrace: stackTrace);
  }

  /// Logger 리소스 정리 (테스트/종료 시)
  Future<void> dispose() async {
    await _fileOutput?.close();
    _fileOutput = null;
    _logger = null;
    _initializationFuture = null;
  }

  void _log(
    Level level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (_logger == null) {
      if (kDebugMode) {
        debugPrint('[${level.name}] $message');
        if (error != null) {
          debugPrint('error: $error');
        }
        if (stackTrace != null) {
          debugPrint(stackTrace.toString());
        }
      }
      return;
    }

    try {
      _logger!.log(
        level,
        message,
        error: error,
        stackTrace: stackTrace,
      );
    } catch (e) {
      _notifyError('로그 기록 실패: $e');
    }
  }

  Future<Directory> _resolveLogDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final logDir = Directory(path.join(appDocDir.path, 'EyebottleRecorder', 'logs'));
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    return logDir;
  }

  void _notifyError(String message) {
    for (final handler in List<LoggingErrorHandler>.from(_errorHandlers)) {
      try {
        handler(message);
      } catch (_) {
        // UI 측 콜백 실패는 무시
      }
    }
  }
}

class _DailyRotatingFileOutput extends LogOutput {
  _DailyRotatingFileOutput({
    required this.directory,
    required this.retention,
    required this.onWriteError,
  }) {
    _pruneOldLogs();
  }

  final Directory directory;
  final Duration retention;
  final void Function(String message) onWriteError;

  IOSink? _sink;
  String? _currentDateKey;

  @override
  void output(OutputEvent event) {
    for (final line in event.lines) {
      _write(line);
    }
  }

  Future<void> close() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }

  void _write(String line) {
    final now = DateTime.now();
    final dateKey = _dateKey(now);

    try {
      if (_currentDateKey != dateKey || _sink == null) {
        _rotateSink(dateKey);
      }

      final timestamp = now.toIso8601String();
      final formatted = '[$timestamp] $line';

      // 콘솔 출력(디버그 빌드)
      if (kDebugMode) {
        debugPrint(formatted);
      }

      _sink?.writeln(formatted);
    } catch (e) {
      onWriteError('로그 파일 기록 실패: $e');
    }
  }

  void _rotateSink(String newDateKey) {
    _sink?.flush();
    _sink?.close();

    final fileName = 'eyebottle_$newDateKey.log';
    final file = File(path.join(directory.path, fileName));
    try {
      _sink = file.openWrite(mode: FileMode.append);
      _currentDateKey = newDateKey;
      _pruneOldLogs();
    } catch (e) {
      onWriteError('로그 파일 열기 실패: $e');
      _sink = null;
    }
  }

  void _pruneOldLogs() {
    try {
      final threshold = DateTime.now().subtract(retention);
      final entries = directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.log'));

      for (final entry in entries) {
        final stat = entry.statSync();
        if (stat.modified.isBefore(threshold)) {
          entry.deleteSync();
        }
      }
    } catch (e) {
      onWriteError('오래된 로그 삭제 실패: $e');
    }
  }

  String _dateKey(DateTime time) {
    final y = time.year.toString().padLeft(4, '0');
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }
}
