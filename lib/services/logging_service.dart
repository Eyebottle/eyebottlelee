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

  /// 마지막으로 해석된 로그 디렉터리 경로 (진단 패널 표시용)
  String? _resolvedLogDirPath;

  /// 로그 디렉터리 해석에 사용된 fallback 단계
  /// (documents / support / localappdata / temp) — 진단 패널 표시용
  String? _resolvedLogDirSource;

  /// 마지막으로 해석된 로그 디렉터리 경로 (없으면 null)
  String? get resolvedLogDirPath => _resolvedLogDirPath;

  /// 로그 디렉터리 해석 단계 (없으면 null)
  String? get resolvedLogDirSource => _resolvedLogDirSource;

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
        level: Level.info,  // debug → info로 변경하여 디버그 로그 제거
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

      _logger!.i('LoggingService initialized at ${logDirectory.path} '
          '(source=$_resolvedLogDirSource)');
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

  /// 로그 디렉터리 경로 반환
  Future<String> getLogDirectoryPath() async {
    final logDirectory = await _resolveLogDirectory();
    return logDirectory.path;
  }

  /// 현재 로그 파일 경로 반환
  Future<String?> getCurrentLogFilePath() async {
    try {
      final logDirectory = await _resolveLogDirectory();
      final now = DateTime.now();
      final dateKey = _dateKey(now);
      final fileName = 'eyebottle_$dateKey.log';
      final filePath = path.join(logDirectory.path, fileName);
      final file = File(filePath);
      if (await file.exists()) {
        return filePath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 모든 로그 파일 목록 반환 (최신순)
  Future<List<File>> getLogFiles() async {
    try {
      final logDirectory = await _resolveLogDirectory();
      final entries = logDirectory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.log'))
          .toList();

      // 수정 시간 기준 내림차순 정렬
      entries.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      return entries;
    } catch (e) {
      return [];
    }
  }

  String _dateKey(DateTime time) {
    final y = time.year.toString().padLeft(4, '0');
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    return '$y$m$d';
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

  /// 로그 디렉터리를 해석한다.
  ///
  /// MSIX 컨테이너 환경에서는 `getApplicationDocumentsDirectory()`의 Documents
  /// 리디렉션이 환경에 따라 실패하거나 쓰기 불가한 경로를 반환하는 사례가
  /// 확인됐다(진료실 PC에서 부팅 모드 로그가 전혀 남지 않음). 단일 경로에
  /// 의존하면 그 환경에서 진단 자체가 불가능해지므로, 쓰기 가능한 디렉터리를
  /// 찾을 때까지 우선순위대로 시도한다:
  ///   1) Documents/EyebottleRecorder/logs   (기존 동작, 1순위)
  ///   2) ApplicationSupport/logs            (MSIX 안전, 항상 쓰기 가능)
  ///   3) %LOCALAPPDATA%/EyebottleRecorder/logs
  ///   4) 시스템 임시 디렉터리/EyebottleRecorder/logs (최후의 보루)
  ///
  /// 어느 단계가 채택됐는지 [_resolvedLogDirSource]에 기록해 진단 패널에서
  /// 확인할 수 있게 한다.
  Future<Directory> _resolveLogDirectory() async {
    final candidates = <_LogDirCandidate>[
      _LogDirCandidate('documents', () async {
        final dir = await getApplicationDocumentsDirectory();
        return path.join(dir.path, 'EyebottleRecorder', 'logs');
      }),
      _LogDirCandidate('support', () async {
        final dir = await getApplicationSupportDirectory();
        return path.join(dir.path, 'logs');
      }),
      _LogDirCandidate('localappdata', () async {
        final base = Platform.environment['LOCALAPPDATA'];
        if (base == null || base.isEmpty) {
          throw StateError('LOCALAPPDATA not set');
        }
        return path.join(base, 'EyebottleRecorder', 'logs');
      }),
      _LogDirCandidate('temp', () async {
        return path.join(
            Directory.systemTemp.path, 'EyebottleRecorder', 'logs');
      }),
    ];

    Object? lastError;
    for (final candidate in candidates) {
      try {
        final resolvedPath = await candidate.resolve();
        final logDir = Directory(resolvedPath);
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }
        // 실제로 쓰기 가능한지 검증 (생성됐다고 쓰기 가능한 건 아님)
        await _assertWritable(logDir);

        _resolvedLogDirPath = logDir.path;
        _resolvedLogDirSource = candidate.source;
        if (candidate.source != 'documents') {
          // fallback 발동 사실을 stdout/DebugView로도 남긴다.
          debugPrint(
              '[LoggingService] log dir fallback → ${candidate.source}: ${logDir.path}');
        }
        return logDir;
      } catch (e) {
        lastError = e;
        debugPrint(
            '[LoggingService] log dir candidate "${candidate.source}" 실패: $e');
      }
    }

    // 모든 후보 실패 — 호출부에서 catch 하도록 throw
    throw StateError('로그 디렉터리 해석 실패 (모든 후보 소진): $lastError');
  }

  /// 디렉터리에 실제로 파일을 쓸 수 있는지 검증한다.
  Future<void> _assertWritable(Directory dir) async {
    final probe = File(path.join(dir.path, '.write_probe'));
    await probe.writeAsString('ok', flush: true);
    try {
      await probe.delete();
    } catch (_) {
      // 삭제 실패는 무시 (쓰기 자체는 성공)
    }
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

/// 로그 디렉터리 후보 하나. [resolve]는 후보 경로 문자열을 반환하며,
/// 실패 시 예외를 던져 다음 후보로 넘어가게 한다.
class _LogDirCandidate {
  _LogDirCandidate(this.source, this.resolve);

  final String source;
  final Future<String> Function() resolve;
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
