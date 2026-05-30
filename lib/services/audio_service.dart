import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'settings_service.dart';
import 'logging_service.dart';
import 'audio_converter_service.dart';
import '../models/recording_profile.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  Timer? _segmentTimer;
  final LoggingService _logging = LoggingService();
  final AudioConverterService _audioConverterService = AudioConverterService();

  bool _isRecording = false;
  bool _isDisposed = false; // dispose 여부 플래그
  bool _vadEnabled = true;
  double vadThreshold = 0.006; // RMS 기반 VAD 임계값
  int _silenceMs = 0;
  bool _pausedByVad = false;
  Timer? _resumeTimer;
  // 보관 주기 (기본 7일)
  Duration? retention;
  RecordingProfile _profile =
      RecordingProfile.presets[RecordingQualityProfile.balanced]!;

  DateTime? _currentSegmentStartedAt;
  double _makeupGainDb = 0.0;

  // 콜백 함수들
  Function(double)? onAmplitudeChanged;
  Function(String)? onFileSegmentCreated;
  Function(DateTime startTime)? onRecordingStarted;
  Function(DateTime startTime, DateTime stopTime, Duration recordedDuration)?
      onRecordingStopped;

  bool get isRecording => _isRecording;
  bool get vadEnabled => _vadEnabled;
  DateTime? _sessionStartTime;

  // 지원되는 코덱 저장
  AudioEncoder? _supportedEncoder;
  bool _encoderChecked = false;
  AudioEncoder? _currentEncoder;

  AudioService() {
    unawaited(_logging.ensureInitialized());
  }

  /// 지원되는 코덱 확인 및 선택
  Future<AudioEncoder> _selectSupportedEncoder({
    Set<AudioEncoder> excludeEncoders = const {},
  }) async {
    if (_encoderChecked && _supportedEncoder != null) {
      if (!excludeEncoders.contains(_supportedEncoder)) {
        _logging.info('💡 캐시된 코덱 사용: ${_supportedEncoder!.name}');
        return _supportedEncoder!;
      }
      _logging.info(
          '💡 캐시된 코덱 ${_supportedEncoder!.name}이(가) 제외 대상이므로 캐시를 무효화합니다.');
      _encoderChecked = false;
      _supportedEncoder = null;
    }

    _logging.info('🔍 지원되는 코덱 확인 중...');

    // 코덱 우선순위: AAC > Opus > WAV
    final encodersToTry = <AudioEncoder>[
      AudioEncoder.aacLc,
      AudioEncoder.opus,
      AudioEncoder.wav,
    ];

    for (final encoder in encodersToTry) {
      if (excludeEncoders.contains(encoder)) {
        _logging.info('  - ${encoder.name}: 제외 목록에 있어 건너뜁니다');
        continue;
      }
      try {
        final isSupported = await _recorder.isEncoderSupported(encoder);

        if (isSupported) {
          _supportedEncoder = encoder;
          _encoderChecked = true;
          _logging.info('✅ 선택된 코덱: ${encoder.name}');
          return encoder;
        }
      } catch (e) {
        _logging.warning('코덱 ${encoder.name} 확인 중 에러: $e');
      }
    }

    // 최후의 수단: WAV (제외되지 않은 경우)
    if (!excludeEncoders.contains(AudioEncoder.wav)) {
      _logging.error('❌ 지원되는 코덱을 찾을 수 없습니다. WAV를 강제 사용합니다.');
      _supportedEncoder = AudioEncoder.wav;
      _encoderChecked = true;
      return AudioEncoder.wav;
    }

    throw Exception('지원되는 코덱을 찾을 수 없습니다 (exclude=${excludeEncoders.map((e) => e.name).join(', ')})');
  }

  /// 녹음 시작
  Future<void> startRecording(
      {Duration segmentDuration = const Duration(minutes: 10)}) async {
    _logging.info('🎙️ 녹음 시작 요청 (세그먼트 주기: ${segmentDuration.inMinutes}분)');

    try {
      // 1. 권한 확인
      _logging.info('📋 마이크 권한 확인 중...');
      final hasPermission = await _recorder.hasPermission();
      _logging.info('권한 상태: hasPermission=$hasPermission');

      if (hasPermission == false) {
        _logging.warning('⚠️ 마이크 권한 거부됨');
        throw Exception('마이크 권한이 필요합니다. 시스템 설정을 확인해주세요.');
      }

      // 2. 녹음 설정 정보 출력
      _logging.info('🎚️ 녹음 설정:');
      _logging.info('  - 프로필: ${_profile.id.name}');
      _logging.info('  - 비트레이트: ${_profile.bitRate} bps');
      _logging.info('  - 샘플레이트: ${_profile.sampleRate} Hz');
      _logging.info('  - 메이크업 게인: ${_makeupGainDb.toStringAsFixed(1)} dB');
      _logging.info('  - VAD 활성화: $_vadEnabled');
      if (_vadEnabled) {
        _logging.info('  - VAD 임계값: ${vadThreshold.toStringAsFixed(4)}');
      }

      // 3. 녹음 시작 (폴백 로직 포함)
      _logging.info('🔴 녹음 시작 시도...');

      bool recordingStarted = false;
      Exception? lastError;

      final attemptedEncoders = <AudioEncoder>{};

      while (!recordingStarted) {
        RecordConfig config;
        AudioEncoder encoder;

        try {
          config = await _buildRecordConfig(excludeEncoders: attemptedEncoders);
          encoder = config.encoder;
        } on Exception catch (e, st) {
          _logging.error('사용할 코덱을 선택하지 못했습니다', error: e, stackTrace: st);
          lastError = e;
          break;
        }

        attemptedEncoders.add(encoder);
        final filePath = await _generateFilePathForEncoder(encoder);

        try {
          await _recorder.start(
            config,
            path: filePath,
          );

          _logging.info('✅ 녹음 시작 성공 (코덱: ${encoder.name})');
          _currentSegmentStartedAt = DateTime.now();
          recordingStarted = true;
          _currentEncoder = encoder;
          _supportedEncoder = encoder;
          _encoderChecked = true;
        } catch (e, st) {
          final exception = e is Exception ? e : Exception(e.toString());
          lastError = exception;
          _logging.error('[시도 ${attemptedEncoders.length}] 녹음 시작 실패 (${encoder.name})',
              error: e, stackTrace: st);

          // PlatformException은 대부분 코덱/설정 문제 → 다음 코덱으로 폴백
          if (e is PlatformException) {
            _logging.warning('코덱 에러 - 다음 코덱으로 폴백');
            _encoderChecked = false;
            if (_supportedEncoder == encoder) {
              _supportedEncoder = null;
            }
            _currentEncoder = null;
            continue;
          }

          // PlatformException이 아닌 에러는 심각한 문제 → 재시도 중단
          _logging.error('코덱과 무관한 심각한 에러 발생 - 재시도 중단');
          throw exception;
        }
      }

      // 모든 재시도 실패 시
      if (!recordingStarted) {
        _logging.error('모든 코덱으로 녹음 시작 실패');
        throw lastError ?? Exception('녹음 시작 실패');
      }

      _isRecording = true;

      // 5. 세그먼트 타이머 시작
      _logging.info('⏰ 세그먼트 타이머 시작 (${segmentDuration.inMinutes}분 주기)');
      _startSegmentTimer(segmentDuration);

      // 6. 진폭 모니터링 시작
      _logging.info('📊 진폭 모니터링 시작');
      _startAmplitudeMonitoring();

      final startedAt = DateTime.now();
      _sessionStartTime = startedAt;
      if (onRecordingStarted != null) {
        onRecordingStarted!(startedAt);
      }

      // 7. 보관 정책 적용
      _logging.info('🧹 보관 정책 적용 중...');
      unawaited(_pruneOldFiles());

      _logging.info('✅ 녹음 준비 완료');
    } catch (e, st) {
      _isRecording = false;
      _logging.error('❌ 녹음 시작 중 예외 발생', error: e, stackTrace: st);
      _logging.error('에러 타입: ${e.runtimeType}');
      _logging.error('에러 메시지: $e');
      throw Exception('녹음 시작 실패: $e');
    }
  }

  /// 녹음 중지
  Future<String?> stopRecording() async {
    _logging.info('⏹️ 녹음 중지 요청');

    try {
      final stoppedAt = DateTime.now();
      final startTime = _sessionStartTime;
      final currentEncoder = _currentEncoder;

      // 1. 타이머 먼저 취소 (새 세그먼트 생성 방지)
      _logging.info('🧹 타이머 정리 중...');
      _segmentTimer?.cancel();
      _logging.info('✅ 타이머 취소 완료');

      // 2. 녹음 중지
      _logging.info('🛑 녹음 중지 시도...');
      final filePath = await _recorder.stop();
      _logging.info('✅ 녹음 중지 완료');
      _isRecording = false;
      _currentEncoder = null;

      // 3. 스트림 정리
      _logging.info('🧹 스트림 정리 중...');
      _amplitudeSubscription?.cancel();
      _logging.info('✅ 리소스 정리 완료');

      // 4. 세션 통계
      if (startTime != null) {
        final duration = stoppedAt.difference(startTime);
        _logging.info('📊 세션 통계:');
        _logging.info('  - 시작 시각: ${startTime.toIso8601String()}');
        _logging.info('  - 종료 시각: ${stoppedAt.toIso8601String()}');
        _logging.info('  - 총 녹음 시간: ${_formatDuration(duration)}');

        if (onRecordingStopped != null && duration > Duration.zero) {
          onRecordingStopped!(startTime, stoppedAt, duration);
        }
      }
      _sessionStartTime = null;

      // 5. 파일 정보 및 WAV 변환
      if (filePath != null) {
        _logging.info('📁 마지막 세그먼트: $filePath');
        final file = File(filePath);
        if (await file.exists()) {
          final fileSize = await file.length();
          _logging.info('  - 파일 크기: ${_formatBytes(fileSize)}');
        }
        final segmentDuration = _estimateSegmentDuration(stoppedAt);
        unawaited(
          _logSegmentMetadata(
            filePath,
            segmentDuration,
            encoder: currentEncoder,
          ),
        );

        // WAV 자동 변환 (마지막 파일도 변환)
        if (currentEncoder == AudioEncoder.wav) {
          _logging.info('💡 마지막 WAV 파일 변환 예약');
          unawaited(_scheduleWavConversion(filePath, skipRecordingCheck: true));
        }
      }
      _currentSegmentStartedAt = null;

      // 6. 보관 정책 적용 (백그라운드 — 녹음 중지 반환을 막지 않음. splitSegment와 동일)
      _logging.info('🧹 보관 정책 적용 중...');
      unawaited(_pruneOldFiles());

      _logging.info('✅ 녹음 중지 완료');
      return filePath;
    } catch (e, st) {
      _logging.error('❌ 녹음 중지 중 예외 발생', error: e, stackTrace: st);
      _logging.error('에러 타입: ${e.runtimeType}');
      _logging.error('에러 메시지: $e');
      throw Exception('녹음 중지 실패: $e');
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours시간 $minutes분 $seconds초';
    } else if (minutes > 0) {
      return '$minutes분 $seconds초';
    } else {
      return '$seconds초';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  /// 파일 세그먼트 분할
  Future<void> splitSegment() async {
    if (!_isRecording) return;

    try {
      // 현재 녹음 중지
      final segmentStopTime = DateTime.now();
      final completedEncoder = _currentEncoder;
      final completedPath = await _recorder.stop();

      // 완료된 파일 콜백 호출
      if (completedPath != null && onFileSegmentCreated != null) {
        onFileSegmentCreated!(completedPath);
      }
      if (completedPath != null) {
        _logging.info('세그먼트 저장 완료');
        _logging.debug('완료된 세그먼트 경로: $completedPath');
        final segmentDuration = _estimateSegmentDuration(segmentStopTime);
        unawaited(
          _logSegmentMetadata(
            completedPath,
            segmentDuration,
            encoder: completedEncoder,
          ),
        );
      }

      // 새로운 세그먼트로 즉시 재시작
      final config = await _buildRecordConfig();
      final newEncoder = config.encoder;
      final newFilePath = await _generateFilePathForEncoder(newEncoder);
      _currentSegmentStartedAt = DateTime.now();
      await _recorder.start(
        config,
        path: newFilePath,
      );
      _currentEncoder = newEncoder;

      _logging.debug('새 세그먼트 시작: $newFilePath');

      // WAV 자동 변환 로직 (조건부 실행)
      // 세그먼트 분할 시에는 녹음이 계속 진행 중이지만,
      // 녹음 중지 직전에 분할된 파일도 변환되어야 하므로 skipRecordingCheck: true 사용
      if (completedEncoder == AudioEncoder.wav && completedPath != null) {
        unawaited(_scheduleWavConversion(completedPath, skipRecordingCheck: true));
      }

      // 보관 정책 적용 (백그라운드)
      unawaited(_pruneOldFiles());
    } catch (e) {
      _logging.error('세그먼트 분할 실패', error: e);
    }
  }

  /// WAV 파일 변환 스케줄링
  ///
  /// **동작:**
  /// 1. 설정에서 자동 변환 활성화 확인
  /// 2. 지연 시간만큼 대기 (녹음 안정화)
  /// 3. 여전히 녹음 중인지 확인 (skipRecordingCheck가 false인 경우)
  /// 4. ffmpeg를 사용하여 WAV → AAC/Opus 변환
  ///
  /// **매개변수:**
  /// - `wavPath`: 변환할 WAV 파일 경로
  /// - `skipRecordingCheck`: true면 녹음 중지 여부와 관계없이 변환 (기본값: false)
  Future<void> _scheduleWavConversion(String wavPath, {bool skipRecordingCheck = false}) async {
    try {
      // 설정 로드
      final settings = SettingsService();
      final isEnabled = await settings.isWavAutoConvertEnabled();

      if (!isEnabled) {
        _logging.debug('WAV 자동 변환 비활성화됨 - 변환 건너뜀');
        return;
      }

      final delaySeconds = await settings.getConversionDelay();
      final targetEncoder = await settings.getWavTargetEncoder();

      _logging.info(
        'WAV 변환 예약: ${path.basename(wavPath)} → ${targetEncoder.name} '
        '(${delaySeconds}초 후 시작)',
      );

      // 지연 실행 (녹음 안정화 시간 확보)
      Future.delayed(Duration(seconds: delaySeconds), () async {
        // dispose된 경우 변환 건너뜀
        if (_isDisposed) {
          _logging.debug('서비스 dispose됨 - WAV 변환 건너뜀: ${path.basename(wavPath)}');
          return;
        }

        // 안전성 체크: 여전히 녹음 중인가? (skipRecordingCheck가 false인 경우만)
        if (!skipRecordingCheck && !_isRecording) {
          _logging.warning('녹음 중지됨 - WAV 변환 취소: ${path.basename(wavPath)}');
          return;
        }

        try {
          _logging.info('WAV 변환 시작: ${path.basename(wavPath)}');

          final outputPath = await _audioConverterService.convertWavToEncoded(
            wavPath: wavPath,
            targetEncoder: targetEncoder,
            bitRate: _profile.bitRate,
            sampleRate: _profile.sampleRate,
            deleteOriginal: true, // 변환 성공 시 원본 삭제
          );

          if (outputPath != null) {
            _logging.info('변환 완료: ${path.basename(outputPath)}');
          } else {
            _logging.warning('변환 실패: 원본 유지됨 (${path.basename(wavPath)})');
          }
        } catch (e, stackTrace) {
          _logging.error('WAV 변환 예외', error: e, stackTrace: stackTrace);
        }
      });
    } catch (e, stackTrace) {
      _logging.error('WAV 변환 스케줄링 실패', error: e, stackTrace: stackTrace);
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
      final adjustedLevel = _applyMakeupGain(level);

      // UI 콜백 호출
      if (onAmplitudeChanged != null) {
        onAmplitudeChanged!(adjustedLevel);
      }

      // 간단한 VAD 로직 (선택적)
      if (_vadEnabled) _processVAD(adjustedLevel);
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

    // 감마 보정 적용: 작은 소리를 더 잘 보이게 함
    // pow(x, 0.3)은 작은 값을 크게, 큰 값은 적당히 유지
    // 예: 0.01 -> 0.22, 0.1 -> 0.50, 0.5 -> 0.81
    normalized = math.pow(normalized, 0.3).toDouble();

    return normalized.clamp(0.0, 1.0);
  }

  /// Voice Activity Detection 처리
  void _processVAD(double level) {
    const windowMs = 200; // onAmplitudeChanged 주기와 동일
    const silenceHoldMs = 4000; // 4초 무음 시 일시정지
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
          if (_isDisposed) return;
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
      _pauseByVad();
    }
  }

  /// VAD에 의한 일시정지 (안전하게 처리)
  Future<void> _pauseByVad() async {
    if (_isDisposed || _pausedByVad) return;
    try {
      await _recorder.pause();
      _pausedByVad = true;
      _logging.debug('VAD: 무음 지속으로 녹음 일시정지');
    } catch (e) {
      _logging.error('VAD 일시정지 실패', error: e);
      // 실패해도 상태는 변경하지 않음
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

  void configureRecordingProfile(RecordingQualityProfile profileId) {
    _profile = RecordingProfile.resolve(profileId);
    _logging.info(
      '녹음 품질 프로필 변경: ${_profile.id.name} (bitRate=${_profile.bitRate}, sampleRate=${_profile.sampleRate})',
    );
  }

  RecordingProfile get currentProfile => _profile;

  void configureMakeupGain(double gainDb) {
    final normalized = gainDb.clamp(0, 12).toDouble();
    _makeupGainDb = normalized;
    _logging.info('메이크업 게인 설정: ${_makeupGainDb.toStringAsFixed(1)} dB');
  }

  /// 파일 경로 생성
  Future<String> getResolvedSaveRootPath() async {
    final directory = await _getRecordingDirectory();
    return directory.path;
  }

  Future<String> _generateFilePathForEncoder(AudioEncoder encoder) async {
    final dateDirectory = await getTodayRecordingDirectory();
    final now = DateTime.now();
    final extension = _extensionForEncoder(encoder);

    final filename =
        '${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}_'
        '${_twoDigits(now.hour)}-${_twoDigits(now.minute)}-${_twoDigits(now.second)}-${_threeDigits(now.millisecond)}_진료녹음$extension';
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
        if (entity is File) {
          final lowerPath = entity.path.toLowerCase();
          final isAudioFile = lowerPath.endsWith('.m4a') ||
              lowerPath.endsWith('.opus') ||
              lowerPath.endsWith('.wav');
          if (!isAudioFile) {
            continue;
          }

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

  String _extensionForEncoder(AudioEncoder encoder) {
    switch (encoder) {
      case AudioEncoder.aacLc:
      case AudioEncoder.aacEld:
      case AudioEncoder.aacHe:
        return '.m4a';
      case AudioEncoder.opus:
        return '.opus';
      case AudioEncoder.wav:
        return '.wav';
      default:
        return '.m4a'; // 기본값은 AAC 계열
    }
  }

  /// 리소스 정리
  void dispose() {
    _isDisposed = true;
    _isRecording = false;
    _amplitudeSubscription?.cancel();
    _segmentTimer?.cancel();
    _resumeTimer?.cancel();
    _audioConverterService.cancelAll(); // 대기 중인 변환 작업 취소
    unawaited(_recorder.dispose());
  }

  Future<RecordConfig> _buildRecordConfig(
      {Set<AudioEncoder> excludeEncoders = const {}}) async {
    final encoder =
        await _selectSupportedEncoder(excludeEncoders: excludeEncoders);
    final config = RecordConfig(
      encoder: encoder,
      bitRate: _profile.bitRate,
      sampleRate: _profile.sampleRate,
      numChannels: 1,
      // autoGain 제거 - AAC 코덱 호환성 개선
      // mic_diagnostics_service와 동일한 설정 사용
    );
    return config;
  }

  Duration? _estimateSegmentDuration(DateTime stopTime) {
    final startedAt = _currentSegmentStartedAt;
    if (startedAt == null) {
      return null;
    }
    final duration = stopTime.difference(startedAt);
    if (duration.isNegative) {
      return null;
    }
    return duration;
  }

  Future<void> _logSegmentMetadata(String filePath, Duration? duration,
      {AudioEncoder? encoder}) async {
    try {
      final file = File(filePath);
      final bytes = await file.length();
      final sizeInMb = bytes / (1024 * 1024);
      final durationText =
          duration == null ? 'unknown' : '${duration.inSeconds}s';

      final codecLabel = (encoder ?? _currentEncoder)?.name ?? 'unknown';

      _logging.debug(
        '세그먼트 메타: profile=${_profile.id.name}, codec=$codecLabel, bitRate=${_profile.bitRate}, sampleRate=${_profile.sampleRate}, gain=${_makeupGainDb.toStringAsFixed(1)}dB, duration=$durationText, size=${sizeInMb.toStringAsFixed(2)} MB',
      );
    } catch (e) {
      _logging.debug('세그먼트 메타 기록 실패: $e');
    }
  }

  double _applyMakeupGain(double level) {
    if (_makeupGainDb <= 0) {
      return level;
    }
    final linear = math.pow(10, _makeupGainDb / 20).toDouble();
    final amplified = (level * linear).clamp(0.0, 1.0);
    return amplified;
  }
}
