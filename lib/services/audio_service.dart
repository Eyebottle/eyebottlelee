import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class AudioService {
  final Record _recorder = Record();
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  Timer? _segmentTimer;

  bool _isRecording = false;
  bool _vadEnabled = true;
  double vadThreshold = 0.01; // RMS 기반 VAD 임계값
  String? _currentFilePath;

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
      if (_vadEnabled) {
        _processVAD(level);
      }
    });
  }

  /// Voice Activity Detection 처리
  void _processVAD(double level) {
    // MVP에서는 단순히 레벨 모니터링 위주
    // 향후 무음 구간 스킵 로직 추가 가능
    if (level < vadThreshold) {
      // 무음 구간 감지됨
      debugPrint('무음 구간 감지: $level');
    }
  }

  /// 파일 경로 생성
  Future<String> _generateFilePath() async {
    final directory = await _getRecordingDirectory();
    final now = DateTime.now();
    final filename = '${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}_'
        '${_twoDigits(now.hour)}-${_twoDigits(now.minute)}_진료녹음.m4a';
    return path.join(directory.path, filename);
  }

  /// 녹음 저장 디렉토리 가져오기
  Future<Directory> _getRecordingDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final recordingDir = Directory(path.join(appDir.path, 'EyebottleRecorder'));

    if (!await recordingDir.exists()) {
      await recordingDir.create(recursive: true);
    }

    return recordingDir;
  }

  /// 두 자리 숫자 포맷
  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  /// 리소스 정리
  void dispose() {
    _amplitudeSubscription?.cancel();
    _segmentTimer?.cancel();
    _recorder.dispose();
  }
}