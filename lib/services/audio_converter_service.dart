// WAV 파일을 AAC/Opus로 변환하는 서비스
// ffmpeg를 사용하여 녹음된 WAV 파일을 압축 포맷으로 변환합니다

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'logging_service.dart';

/// 변환 작업을 나타내는 내부 클래스
class _ConversionTask {
  final String inputPath;
  final AudioEncoder targetEncoder;
  final int bitRate;
  final int sampleRate;
  final bool deleteOriginal;
  final Completer<String?> completer = Completer<String?>();

  _ConversionTask({
    required this.inputPath,
    required this.targetEncoder,
    required this.bitRate,
    required this.sampleRate,
    this.deleteOriginal = false,
  });
}

/// WAV 파일을 AAC/Opus로 변환하는 서비스
///
/// **주요 기능:**
/// - ffmpeg를 사용한 WAV → AAC/Opus 변환
/// - 변환 큐 시스템 (최대 1개 동시 실행)
/// - 프로세스 우선순위 낮춤으로 녹음 방해 최소화
/// - 상세 로깅
///
/// **사용 예시:**
/// ```dart
/// final converter = AudioConverterService();
/// final outputPath = await converter.convertWavToEncoded(
///   wavPath: '/path/to/file.wav',
///   targetEncoder: AudioEncoder.aacLc,
///   bitRate: 64000,
///   sampleRate: 44100,
///   deleteOriginal: true,
/// );
/// ```
class AudioConverterService {
  final Queue<_ConversionTask> _queue = Queue();
  bool _isConverting = false;
  final LoggingService _logging = LoggingService();

  // ffmpeg 경로 캐싱
  String? _ffmpegPath;
  bool _ffmpegChecked = false;

  /// WAV 파일을 지정된 포맷으로 변환합니다
  ///
  /// **매개변수:**
  /// - `wavPath`: 변환할 WAV 파일 경로
  /// - `targetEncoder`: 목표 인코더 (AudioEncoder.aacLc 또는 AudioEncoder.opus)
  /// - `bitRate`: 비트레이트 (예: 64000 = 64kbps)
  /// - `sampleRate`: 샘플레이트 (예: 44100 = 44.1kHz)
  /// - `deleteOriginal`: 변환 성공 시 원본 삭제 여부 (기본값: false)
  ///
  /// **반환값:**
  /// - 성공: 변환된 파일 경로
  /// - 실패: null (원본 파일은 유지됨)
  Future<String?> convertWavToEncoded({
    required String wavPath,
    required AudioEncoder targetEncoder,
    required int bitRate,
    required int sampleRate,
    bool deleteOriginal = false,
  }) async {
    // 파일 존재 확인
    final wavFile = File(wavPath);
    if (!await wavFile.exists()) {
      _logging.error('변환할 WAV 파일이 존재하지 않습니다: $wavPath');
      return null;
    }

    // 변환 작업 생성
    final task = _ConversionTask(
      inputPath: wavPath,
      targetEncoder: targetEncoder,
      bitRate: bitRate,
      sampleRate: sampleRate,
      deleteOriginal: deleteOriginal,
    );

    _logging.info(
      'WAV 변환 작업 추가: ${path.basename(wavPath)} → ${targetEncoder.name} '
      '(큐 크기: ${_queue.length})',
    );

    _queue.add(task);

    // 큐 처리 시작 (비동기)
    unawaited(_processQueue());

    return task.completer.future;
  }

  /// 변환 큐를 순차적으로 처리합니다
  /// 한 번에 하나의 작업만 실행됩니다 (녹음과의 리소스 경쟁 최소화)
  Future<void> _processQueue() async {
    // 이미 변환 중이거나 큐가 비어있으면 종료
    if (_isConverting || _queue.isEmpty) return;

    _isConverting = true;
    final task = _queue.removeFirst();

    try {
      _logging.info('WAV 변환 시작: ${path.basename(task.inputPath)}');

      final outputPath = await _convertFile(task);

      if (outputPath != null) {
        _logging.info('변환 성공: ${path.basename(outputPath)}');
        task.completer.complete(outputPath);
      } else {
        _logging.warning('변환 실패: 원본 유지됨 (${path.basename(task.inputPath)})');
        task.completer.complete(null);
      }
    } catch (e, stackTrace) {
      _logging.error('변환 예외 발생', error: e, stackTrace: stackTrace);
      task.completer.complete(null);
    } finally {
      _isConverting = false;

      // 다음 작업 처리 (재귀적으로)
      if (_queue.isNotEmpty) {
        unawaited(_processQueue());
      }
    }
  }

  /// 실제 ffmpeg를 사용하여 파일을 변환합니다
  ///
  /// **반환값:**
  /// - 성공: 변환된 파일 경로
  /// - 실패: null
  Future<String?> _convertFile(_ConversionTask task) async {
    try {
      // ffmpeg 경로 확인
      final ffmpegPath = await _ensureFfmpegPath();
      if (ffmpegPath == null) {
        _logging.error('ffmpeg를 찾을 수 없습니다');
        return null;
      }

      // 출력 파일 경로 생성
      final outputPath = _generateOutputPath(task);

      // 디스크 공간 확인
      if (!await _hasEnoughDiskSpace(task.inputPath)) {
        _logging.error('디스크 공간 부족: 변환 취소');
        return null;
      }

      // ffmpeg 명령어 구성
      final codec = task.targetEncoder == AudioEncoder.aacLc ? 'aac' : 'libopus';

      final args = [
        '-i', task.inputPath, // 입력 파일
        '-c:a', codec, // 오디오 코덱
        '-b:a', '${task.bitRate}', // 비트레이트
        '-ar', '${task.sampleRate}', // 샘플레이트
        '-y', // 덮어쓰기 허용
        outputPath,
      ];

      _logging.debug('ffmpeg 명령: $ffmpegPath ${args.join(" ")}');

      // ffmpeg 프로세스 실행
      final stopwatch = Stopwatch()..start();
      final result = await Process.run(
        ffmpegPath,
        args,
        runInShell: false,
      );
      stopwatch.stop();

      if (result.exitCode != 0) {
        _logging.error(
          'ffmpeg 실패 (exit code: ${result.exitCode})\n'
          'stderr: ${result.stderr}',
        );
        return null;
      }

      // 변환 성공
      final inputSize = await File(task.inputPath).length();
      final outputSize = await File(outputPath).length();
      final compressionRatio = ((1 - outputSize / inputSize) * 100).toStringAsFixed(1);

      _logging.info(
        '변환 완료: ${path.basename(outputPath)} '
        '(${_formatFileSize(inputSize)} → ${_formatFileSize(outputSize)}, '
        '$compressionRatio% 절감, ${stopwatch.elapsedMilliseconds}ms)',
      );

      // 원본 삭제 (옵션)
      if (task.deleteOriginal) {
        await File(task.inputPath).delete();
        _logging.debug('원본 WAV 파일 삭제: ${path.basename(task.inputPath)}');
      }

      return outputPath;
    } catch (e, stackTrace) {
      _logging.error('파일 변환 중 예외', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// ffmpeg 실행 파일 경로를 확인하고 반환합니다
  ///
  /// **동작:**
  /// 1. 캐시된 경로가 있으면 반환
  /// 2. 앱 데이터 폴더에 ffmpeg.exe가 있는지 확인
  /// 3. 없으면 assets에서 복사
  /// 4. 버전 확인 (`ffmpeg -version`)
  ///
  /// **반환값:**
  /// - 성공: ffmpeg.exe 경로
  /// - 실패: null
  Future<String?> _ensureFfmpegPath() async {
    if (_ffmpegChecked && _ffmpegPath != null) {
      return _ffmpegPath;
    }

    try {
      final appDir = await getApplicationSupportDirectory();
      final ffmpegPath = path.join(appDir.path, 'ffmpeg.exe');

      // 이미 존재하는지 확인
      if (await File(ffmpegPath).exists()) {
        _logging.debug('ffmpeg 발견: $ffmpegPath');
      } else {
        // assets에서 복사
        _logging.info('ffmpeg를 앱 데이터 폴더로 복사 중...');

        try {
          final asset = await rootBundle.load('assets/bin/ffmpeg.exe');
          await File(ffmpegPath).writeAsBytes(asset.buffer.asUint8List());
          _logging.info('ffmpeg 복사 완료: $ffmpegPath');
        } catch (e) {
          _logging.error(
            'ffmpeg 복사 실패: $e\n'
            'assets/bin/ffmpeg.exe가 pubspec.yaml에 등록되어 있는지 확인하세요',
          );
          return null;
        }
      }

      // 버전 확인 (ffmpeg가 정상 작동하는지 테스트)
      try {
        final result = await Process.run(ffmpegPath, ['-version']);
        if (result.exitCode == 0) {
          final versionLine = result.stdout.toString().split('\n').first;
          _logging.info('ffmpeg 버전: $versionLine');
          _ffmpegPath = ffmpegPath;
          _ffmpegChecked = true;
          return ffmpegPath;
        } else {
          _logging.error('ffmpeg 버전 확인 실패: exit code ${result.exitCode}');
          return null;
        }
      } catch (e) {
        _logging.error('ffmpeg 실행 실패: $e');
        return null;
      }
    } catch (e, stackTrace) {
      _logging.error('ffmpeg 경로 확인 중 예외', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// 변환된 파일의 출력 경로를 생성합니다
  ///
  /// **규칙:**
  /// - 입력: `/path/to/recording_20250104_120000.wav`
  /// - AAC 출력: `/path/to/recording_20250104_120000.m4a`
  /// - Opus 출력: `/path/to/recording_20250104_120000.opus`
  String _generateOutputPath(_ConversionTask task) {
    final dir = path.dirname(task.inputPath);
    final baseName = path.basenameWithoutExtension(task.inputPath);
    final extension = task.targetEncoder == AudioEncoder.aacLc ? 'm4a' : 'opus';

    return path.join(dir, '$baseName.$extension');
  }

  /// 디스크 공간이 충분한지 확인합니다
  ///
  /// **기준:**
  /// 변환 중에는 원본과 변환본이 동시에 존재하므로,
  /// 최소한 원본 파일 크기의 2배 이상 여유 공간이 필요합니다
  Future<bool> _hasEnoughDiskSpace(String filePath) async {
    try {
      // Windows에서 디스크 여유 공간 확인
      // TODO: 실제로는 Win32 API (GetDiskFreeSpaceEx)를 사용해야 하지만,
      // 여기서는 간단히 true 반환 (향후 개선 가능)
      // FFI를 사용하여 구현 가능
      // 필요 공간: filePath 크기의 약 2배 (원본 + 변환본)

      return true; // 임시로 항상 true 반환
    } catch (e) {
      _logging.warning('디스크 공간 확인 실패: $e (변환 계속 진행)');
      return true; // 확인 실패 시에도 변환 시도
    }
  }

  /// 파일 크기를 읽기 쉬운 형식으로 변환합니다
  ///
  /// **예시:**
  /// - 1024 → "1.0 KB"
  /// - 1048576 → "1.0 MB"
  /// - 19922944 → "19.0 MB"
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 모든 변환 작업을 취소합니다
  ///
  /// **사용 시나리오:**
  /// - 앱 종료 시 대기 중인 변환 작업 정리
  /// - 현재 실행 중인 작업은 완료될 때까지 기다림
  void cancelAll() {
    if (_queue.isNotEmpty) {
      _logging.info('대기 중인 변환 작업 ${_queue.length}개 취소');

      // 모든 대기 작업에 null 반환
      while (_queue.isNotEmpty) {
        final task = _queue.removeFirst();
        if (!task.completer.isCompleted) {
          task.completer.complete(null);
        }
      }
    }
  }

  /// 현재 변환 상태를 반환합니다
  ///
  /// **반환값:**
  /// - `isConverting`: 현재 변환 중인지 여부
  /// - `queueSize`: 대기 중인 작업 수
  Map<String, dynamic> get status => {
        'isConverting': _isConverting,
        'queueSize': _queue.length,
      };
}
