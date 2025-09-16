import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'settings_service.dart';

class AudioService {
  final Record _recorder = Record();
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  Timer? _segmentTimer;

  bool _isRecording = false;
  bool _vadEnabled = true;
  double vadThreshold = 0.01; // RMS 기반 VAD 임계값
  int _silenceMs = 0;
  bool _pausedByVad = false;
  Timer? _resumeTimer;
  String? _currentFilePath;

  // 보관 주기 (기본 7일)
  Duration retention = const Duration(days: 7);

  // 콜백 함수들
  Function(double)? onAmplitudeChanged;
  Function(String)? onFileSegmentCreated;

  bool get isRecording => _isRecording;

  /// 녹음 시작
  Future<void> startRecording({Duration segmentDuration = const Duration(minutes: 10)}) async {
    try {
      // 권한 확인
      if (await _recorder.hasPermission()) {
        final filePath = await _generateFilePath();
        _currentFilePath = filePath;

        await _recorder.start(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          numChannels: 1,
          samplingRate: 16000,
          path: filePath,
        );

        _isRecording = true;

        // 10분 단위 세그먼트 타이머 시작
        _startSegmentTimer(segmentDuration);

        // 오디오 레벨 모니터링 시작
        _startAmplitudeMonitoring();

        // 보관 정책 적용
        unawaited(_pruneOldFiles());

        debugPrint('녹음 시작: $filePath');
      } else {
        throw Exception('마이크 권한이 필요합니다.');
      }
    } catch (e) {
      _isRecording = false;
      throw Exception('녹음 시작 실패: $e');
    }
  }

  /// 녹음 일시정지
  Future<void> pauseRecording() async {
    try {
      await _recorder.pause();
      debugPrint('녹음 일시정지됨');
    } catch (e) {
      throw Exception('녹음 일시정지 실패: $e');
    }
  }

  /// 녹음 재개
  Future<void> resumeRecording() async {
    try {
      await _recorder.resume();
      debugPrint('녹음 재개됨');
    } catch (e) {
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

      // 보관 정책 적용
      await _pruneOldFiles();

      debugPrint('녹음 중지됨: $filePath');
      return filePath;
    } catch (e) {
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

      // 새로운 세그먼트로 즉시 재시작
      final newFilePath = await _generateFilePath();
      _currentFilePath = newFilePath;

      await _recorder.start(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        numChannels: 1,
        samplingRate: 16000,
        path: newFilePath,
      );

      // 보관 정책 적용 (백그라운드)
      unawaited(_pruneOldFiles());

      debugPrint('새 세그먼트 시작: $newFilePath');
    } catch (e) {
      debugPrint('세그먼트 분할 실패: $e');
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
      final level = (amplitude.current ?? 0).abs() / 32768.0; // 정규화

      // UI 콜백 호출
      if (onAmplitudeChanged != null) {
        onAmplitudeChanged!(level);
      }

      // 간단한 VAD 로직 (선택적)
      if (_vadEnabled) _processVAD(level);
    });
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
        _resumeTimer = Timer(const Duration(milliseconds: resumeDelayMs), () async {
          try {
            await _recorder.resume();
            _pausedByVad = false;
            debugPrint('VAD: 음성 감지로 녹음 재개');
          } catch (e) {
            debugPrint('VAD 재개 실패: $e');
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
          debugPrint('VAD: 무음 지속으로 녹음 일시정지');
        } catch (e) {
          debugPrint('VAD 일시정지 실패: $e');
        }
      }();
    }
  }

  /// 외부에서 VAD 구성 적용
  void configureVad({required bool enabled, required double threshold}) {
    _vadEnabled = enabled;
    vadThreshold = threshold;
  }

  /// 파일 경로 생성
  Future<String> _generateFilePath() async {
    final directory = await _getRecordingDirectory();
    final now = DateTime.now();
    final filename = '${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}_'
        '${_twoDigits(now.hour)}-${_twoDigits(now.minute)}_진료녹음.m4a';
    return path.join(directory.path, filename);
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
      final dir = await _getRecordingDirectory();
      if (!await dir.exists()) return;

      final now = DateTime.now();
      final threshold = now.subtract(retention);

      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.m4a')) {
          final stat = await entity.stat();
          final modified = stat.modified;
          if (modified.isBefore(threshold)) {
            try {
              await entity.delete();
              debugPrint('보관기간 경과 파일 삭제: ${path.basename(entity.path)}');
            } catch (e) {
              debugPrint('파일 삭제 실패: ${entity.path} - $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('보관 파일 정리 실패: $e');
    }
  }

  /// 두 자리 숫자 포맷
  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  /// 리소스 정리
  void dispose() {
    _amplitudeSubscription?.cancel();
    _segmentTimer?.cancel();
    _resumeTimer?.cancel();
    _recorder.dispose();
  }
}
