import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'settings_service.dart';
import 'logging_service.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  Timer? _segmentTimer;
  final LoggingService _logging = LoggingService();

  bool _isRecording = false;
  bool _vadEnabled = true;
  double vadThreshold = 0.01; // RMS 기반 VAD 임계값
  int _silenceMs = 0;
  bool _pausedByVad = false;
  Timer? _resumeTimer;
  // 보관 주기 (기본 7일)
  Duration? retention;

  // 콜백 함수들
  Function(double)? onAmplitudeChanged;
  Function(String)? onFileSegmentCreated;
  Function(DateTime startTime)? onRecordingStarted;
  Function(DateTime startTime, DateTime stopTime, Duration recordedDuration)?
      onRecordingStopped;

  bool get isRecording => _isRecording;
  DateTime? _sessionStartTime;

  AudioService() {
    unawaited(_logging.ensureInitialized());
  }

  /// 녹음 시작
  Future<void> startRecording(
      {Duration segmentDuration = const Duration(minutes: 10)}) async {
    try {
      // 권한 확인 (Windows 등에서 null이 반환되면 허용으로 간주)
      final hasPermission = await _recorder.hasPermission();
      if (hasPermission == false) {
        throw Exception('마이크 권한이 필요합니다. 시스템 설정을 확인해주세요.');
      }

      final filePath = await _generateFilePath();
      await _recorder.start(
        _buildRecordConfig(),
        path: filePath,
      );

      _isRecording = true;

      // 10분 단위 세그먼트 타이머 시작
      _startSegmentTimer(segmentDuration);

      // 오디오 레벨 모니터링 시작
      _startAmplitudeMonitoring();

      final startedAt = DateTime.now();
      _sessionStartTime = startedAt;
      if (onRecordingStarted != null) {
        onRecordingStarted!(startedAt);
      }

      // 보관 정책 적용
      unawaited(_pruneOldFiles());

      _logging.info('녹음 시작');
      _logging.debug('녹음 파일 경로: $filePath');
    } catch (e) {
      _isRecording = false;
      _logging.error('녹음 시작 실패', error: e);
      throw Exception('녹음 시작 실패: $e');
    }
  }

  /// 녹음 일시정지
  Future<void> pauseRecording() async {
    try {
      await _recorder.pause();
      _logging.info('녹음 일시정지됨');
    } catch (e) {
      _logging.error('녹음 일시정지 실패', error: e);
      throw Exception('녹음 일시정지 실패: $e');
    }
  }

  /// 녹음 재개
  Future<void> resumeRecording() async {
    try {
      await _recorder.resume();
      _logging.info('녹음 재개됨');
    } catch (e) {
      _logging.error('녹음 재개 실패', error: e);
      throw Exception('녹음 재개 실패: $e');
    }
  }

  /// 녹음 중지
  Future<String?> stopRecording() async {
    try {
      final filePath = await _recorder.stop();
      _isRecording = false;

      // 타이머 및 스트림 정리
      _segmentTimer?.cancel();
      _amplitudeSubscription?.cancel();

      final startTime = _sessionStartTime;
      final stopTime = DateTime.now();
      if (startTime != null) {
        final duration = stopTime.difference(startTime);
        if (onRecordingStopped != null && duration > Duration.zero) {
          onRecordingStopped!(startTime, stopTime, duration);
        }
      }
      _sessionStartTime = null;

      // 보관 정책 적용
      await _pruneOldFiles();

      _logging.info('녹음 중지됨');
      if (filePath != null) {
        _logging.debug('마지막 세그먼트 경로: $filePath');
      }
      return filePath;
    } catch (e) {
      _logging.error('녹음 중지 실패', error: e);
      throw Exception('녹음 중지 실패: $e');
    }
  }

  /// 파일 세그먼트 분할
  Future<void> splitSegment() async {
    if (!_isRecording) return;

    try {
      // 현재 녹음 중지
      final completedPath = await _recorder.stop();

      // 완료된 파일 콜백 호출
      if (completedPath != null && onFileSegmentCreated != null) {
        onFileSegmentCreated!(completedPath);
      }
      if (completedPath != null) {
        _logging.info('세그먼트 저장 완료');
        _logging.debug('완료된 세그먼트 경로: $completedPath');
      }

      // 새로운 세그먼트로 즉시 재시작
      final newFilePath = await _generateFilePath();
      await _recorder.start(
        _buildRecordConfig(),
        path: newFilePath,
      );

      _logging.debug('새 세그먼트 시작: $newFilePath');

      // 보관 정책 적용 (백그라운드)
      unawaited(_pruneOldFiles());
    } catch (e) {
      _logging.error('세그먼트 분할 실패', error: e);
    }
  }

  /// 세그먼트 타이머 시작
  void _startSegmentTimer(Duration duration) {
    _segmentTimer = Timer.periodic(duration, (_) => splitSegment());
  }

  /// 오디오 레벨 모니터링 시작
  void _startAmplitudeMonitoring() {
    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 200))
        .listen((amplitude) {
      final level = _normalizeAmplitude(amplitude);

      // UI 콜백 호출
      if (onAmplitudeChanged != null) {
        onAmplitudeChanged!(level);
      }

      // 간단한 VAD 로직 (선택적)
      if (_vadEnabled) _processVAD(level);
    });
  }

  double _normalizeAmplitude(Amplitude amplitude) {
    double sample = amplitude.current;
    if (sample == 0 && amplitude.max != 0) {
      sample = amplitude.max;
    }
    double normalized;

    if (sample <= 0) {
      // record 패키지는 dB(-160~0) 값을 반환할 수 있으므로 0~1로 변환
      normalized = math.pow(10, sample / 20).toDouble();
    } else if (sample <= 1.0) {
      normalized = sample;
    } else {
      normalized = sample / 32768.0;
    }

    if (normalized.isNaN || !normalized.isFinite) {
      return 0.0;
    }
    return normalized.clamp(0.0, 1.0);
  }

  /// Voice Activity Detection 처리
  void _processVAD(double level) {
    const windowMs = 200; // onAmplitudeChanged 주기와 동일
    const silenceHoldMs = 3000; // 3초 무음 시 일시정지
    const resumeDelayMs = 500; // 재개 지연

    // 무음 누적/해제
    if (level < vadThreshold) {
      _silenceMs += windowMs;
    } else {
      _silenceMs = 0;
      if (_pausedByVad) {
        _resumeTimer?.cancel();
        _resumeTimer =
            Timer(const Duration(milliseconds: resumeDelayMs), () async {
          try {
            await _recorder.resume();
            _pausedByVad = false;
            _logging.debug('VAD: 음성 감지로 녹음 재개');
          } catch (e) {
            _logging.error('VAD 재개 실패', error: e);
          }
        });
      }
    }

    // 일정 무음 지속 시 일시정지
    if (!_pausedByVad && _silenceMs >= silenceHoldMs) {
      _resumeTimer?.cancel();
      _silenceMs = 0;
      () async {
        try {
          await _recorder.pause();
          _pausedByVad = true;
          _logging.debug('VAD: 무음 지속으로 녹음 일시정지');
        } catch (e) {
          _logging.error('VAD 일시정지 실패', error: e);
        }
      }();
    }
  }

  /// 외부에서 VAD 구성 적용
  void configureVad({required bool enabled, required double threshold}) {
    _vadEnabled = enabled;
    vadThreshold = threshold;
    _logging.info('VAD 설정 변경 (enabled=$enabled, threshold=$threshold)');
  }

  /// 보관 주기 구성 (null 이면 영구 보존)
  void configureRetention(Duration? duration) {
    retention = duration;
    if (duration == null) {
      _logging.info('보관 주기 설정: 영구 보존');
    } else {
      _logging.info('보관 주기 설정: ${duration.inDays}일');
    }
  }

  /// 파일 경로 생성
  Future<String> getResolvedSaveRootPath() async {
    final directory = await _getRecordingDirectory();
    return directory.path;
  }

  Future<String> _generateFilePath() async {
    final dateDirectory = await getTodayRecordingDirectory();
    final now = DateTime.now();

    final filename =
        '${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}_'
        '${_twoDigits(now.hour)}-${_twoDigits(now.minute)}-${_twoDigits(now.second)}-${_threeDigits(now.millisecond)}_진료녹음.m4a';
    return path.join(dateDirectory.path, filename);
  }

  /// 오늘 날짜 기준 녹음 폴더를 생성/반환한다.
  Future<Directory> getTodayRecordingDirectory() async {
    final baseDirectory = await _getRecordingDirectory();
    final now = DateTime.now();
    final dateFolderName =
        '${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}';
    final dateDirectory =
        Directory(path.join(baseDirectory.path, dateFolderName));
    if (!await dateDirectory.exists()) {
      await dateDirectory.create(recursive: true);
    }
    return dateDirectory;
  }

  /// 녹음 저장 디렉토리 가져오기 (설정 폴더 우선)
  Future<Directory> _getRecordingDirectory() async {
    final settings = SettingsService();
    final saved = await settings.getSaveFolder();
    if (saved != null && saved.isNotEmpty) {
      final dir = Directory(saved);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }

    // 기본 앱 문서 디렉토리 하위 폴더
    final appDir = await getApplicationDocumentsDirectory();
    final recordingDir = Directory(path.join(appDir.path, 'EyebottleRecorder'));

    if (!await recordingDir.exists()) {
      await recordingDir.create(recursive: true);
    }

    return recordingDir;
  }

  /// 오래된 파일 정리 (보관 주기 초과 파일 삭제)
  Future<void> _pruneOldFiles() async {
    try {
      if (retention == null) {
        return;
      }
      final dir = await _getRecordingDirectory();
      if (!await dir.exists()) return;

      final now = DateTime.now();
      final threshold = now.subtract(retention!);

      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.m4a')) {
          final stat = await entity.stat();
          final modified = stat.modified;
          if (modified.isBefore(threshold)) {
            try {
              await entity.delete();
              _logging.debug('보관기간 경과 파일 삭제: ${path.basename(entity.path)}');
            } catch (e) {
              _logging.error('파일 삭제 실패: ${entity.path}', error: e);
            }
          }
        }
      }

      final basePath = dir.path;
      await _removeEmptyDirectories(dir, basePath: basePath);
    } catch (e) {
      _logging.error('보관 파일 정리 실패', error: e);
    }
  }

  Future<void> _removeEmptyDirectories(Directory directory,
      {required String basePath}) async {
    final entities = await directory.list(followLinks: false).toList();
    for (final entity in entities) {
      if (entity is Directory) {
        await _removeEmptyDirectories(entity, basePath: basePath);
      }
    }

    if (directory.path == basePath) {
      return;
    }

    bool isEmpty = false;
    try {
      isEmpty = await directory.list(followLinks: false).isEmpty;
    } catch (_) {
      // 리스트 실패 시 건너뛴다.
      return;
    }

    if (isEmpty) {
      try {
        await directory.delete();
      } catch (_) {
        // 삭제 실패는 무시 (다음 정리 주기에 재시도)
      }
    }
  }

  /// 두 자리 숫자 포맷
  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  String _threeDigits(int n) => n.toString().padLeft(3, '0');

  /// 리소스 정리
  void dispose() {
    _amplitudeSubscription?.cancel();
    _segmentTimer?.cancel();
    _resumeTimer?.cancel();
    unawaited(_recorder.dispose());
  }

  RecordConfig _buildRecordConfig() {
    return const RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 128000,
      sampleRate: 44100,
      numChannels: 1,
    );
  }
}
