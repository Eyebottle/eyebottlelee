import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/mic_diagnostic_result.dart';
import 'logging_service.dart';

class MicDiagnosticsService {
  MicDiagnosticsService();

  final LoggingService _logging = LoggingService();

  Future<MicDiagnosticResult> runDiagnostic({
    Duration sampleDuration = const Duration(seconds: 3),
    Duration ambientWindow = const Duration(milliseconds: 500),
  }) async {
    final timestamp = DateTime.now();
    final recorder = AudioRecorder();
    StreamSubscription<Amplitude>? subscription;
    String? tempFilePath;
    final samples = <_AmplitudeSample>[];
    double peakLinear = 0.0;

    _logging.info('🎤 마이크 진단 시작: sampleDuration=${sampleDuration.inSeconds}초');

    try {
      // 1. 권한 체크
      _logging.info('📋 권한 체크 중...');
      final hasPermission = await recorder.hasPermission();
      _logging.info('권한 상태: hasPermission=$hasPermission');

      if (hasPermission == false) {
        _logging.warning('⚠️ 마이크 권한 거부됨');
        return MicDiagnosticResult(
          timestamp: timestamp,
          status: MicDiagnosticStatus.permissionDenied,
          message: '마이크 권한이 꺼져 있어요. Windows 설정 > 개인정보 보호 > 마이크에서 권한을 켜주세요.',
          hints: const [
            'Windows 설정 > 개인정보 보호 > 마이크',
            '앱 목록에서 "아이보틀 진료 녹음"을 허용',
          ],
        );
      }

      // 2. 장치 목록 확인
      _logging.info('🔍 입력 장치 검색 중...');
      final devices = await recorder.listInputDevices();
      _logging.info('발견된 입력 장치: ${devices.length}개');

      if (devices.isNotEmpty) {
        for (var i = 0; i < devices.length; i++) {
          final device = devices[i];
          _logging.info('  장치 #$i: id=${device.id}, label=${device.label}');
        }
      }

      if (devices.isEmpty) {
        _logging.warning('⚠️ 입력 장치를 찾을 수 없음');
        return MicDiagnosticResult(
          timestamp: timestamp,
          status: MicDiagnosticStatus.noInputDevice,
          message: '녹음 가능한 마이크를 찾지 못했어요. USB 케이블이나 블루투스 연결을 다시 확인해주세요.',
          hints: const [
            '마이크 전원이 켜져 있는지 확인',
            'Windows 소리 설정에서 입력 장치 선택',
          ],
        );
      }

      // 3. 임시 파일 경로 설정
      final tempDir = await getTemporaryDirectory();
      final tempFileBaseName =
          'mic_diag_${timestamp.millisecondsSinceEpoch}';

      // 4. 진폭 모니터링 시작
      _logging.info('📊 진폭 모니터링 시작...');
      subscription = recorder
          .onAmplitudeChanged(const Duration(milliseconds: 160))
          .listen((amp) {
        final normalized = _normalizeAmplitude(amp);
        final now = DateTime.now();
        samples.add(_AmplitudeSample(now, normalized));
        if (normalized > peakLinear) {
          peakLinear = normalized;
        }
      });

      // 5. 코덱 선택
      _logging.info('지원되는 코덱 확인 중...');

      AudioEncoder? selectedEncoder;
      final encodersToTry = <AudioEncoder>[
        AudioEncoder.aacLc,
        AudioEncoder.opus,
        AudioEncoder.wav,
      ];

      for (final encoder in encodersToTry) {
        try {
          final isSupported = await recorder.isEncoderSupported(encoder);
          if (isSupported) {
            selectedEncoder = encoder;
            _logging.info('선택된 코덱: ${encoder.name}');
            break;
          }
        } catch (e) {
          _logging.warning('코덱 ${encoder.name} 확인 중 에러: $e');
        }
      }

      if (selectedEncoder == null) {
        _logging.error('❌ 지원되는 코덱을 찾을 수 없습니다');
        return MicDiagnosticResult(
          timestamp: timestamp,
          status: MicDiagnosticStatus.failure,
          message: '지원되는 오디오 코덱을 찾을 수 없어요.',
          hints: const [
            'Windows Media Feature Pack 설치를 확인해주세요',
            '시스템을 재시작해보세요',
          ],
        );
      }

      // 6. 녹음 시작 (폴백 로직 포함)
      bool recordingStarted = false;
      Exception? lastError;

      // 최대 3번 재시도 (선택된 코덱이 실패하면 다음 코덱으로)
      final fallbackEncoders = <AudioEncoder>[
        selectedEncoder,
        ...encodersToTry.where((e) => e != selectedEncoder),
      ];

      for (int attempt = 0;
          attempt < fallbackEncoders.length && !recordingStarted;
          attempt++) {
        final encoder = fallbackEncoders[attempt];
        try {
          tempFilePath = path.join(
            tempDir.path,
            '${tempFileBaseName}${_extensionForEncoder(encoder)}',
          );

          await recorder.start(
            RecordConfig(
              encoder: encoder,
              bitRate: 64000,
              sampleRate: 44100,
            ),
            path: tempFilePath,
          );

          recordingStarted = true;
          _logging.info('✅ 녹음 시작 성공 (코덱: ${encoder.name})');
          break;
        } catch (e, st) {
          lastError = e is Exception ? e : Exception(e.toString());
          _logging.error('[시도 ${attempt + 1}] 녹음 실패 (${encoder.name})', error: e, stackTrace: st);

          // PlatformException은 대부분 코덱/설정 문제 → 다음 코덱으로 폴백
          if (e is PlatformException && attempt < fallbackEncoders.length - 1) {
            _logging.warning('코덱 에러 - 다음 코덱으로 폴백 (${fallbackEncoders[attempt + 1].name})');
            final currentPath = tempFilePath;
            if (currentPath != null) {
              final file = File(currentPath);
              if (await file.exists()) {
                unawaited(file.delete());
              }
            }
            tempFilePath = null;
          } else if (e is! PlatformException) {
            // PlatformException이 아닌 에러는 심각한 문제 → 재시도 중단
            _logging.error('❌ 코덱과 무관한 심각한 에러 발생 - 재시도 중단');
            break;
          }
        }
      }

      // 모든 재시도 실패 시
      if (!recordingStarted) {
        _logging.error('❌ 모든 코덱으로 녹음 시작 실패');

        // 에러 메시지 상세화
        String detailedMessage = '마이크 녹음을 시작할 수 없어요.';
        List<String> errorHints = [];

        if (lastError != null) {
          final errorMsg = lastError.toString().toLowerCase();
          if (errorMsg.contains('codec') || errorMsg.contains('encoder') || errorMsg.contains('aac')) {
            detailedMessage = '오디오 인코더 초기화에 실패했어요.';
            errorHints = [
              'Windows Media Feature Pack이 설치되어 있는지 확인해주세요',
              'Windows 버전이 N 또는 KN 에디션인 경우 별도 설치가 필요합니다',
              '시스템을 재시작한 후 다시 시도해보세요',
            ];
          } else if (errorMsg.contains('permission')) {
            detailedMessage = '마이크 권한 문제가 발생했어요.';
            errorHints = [
              'Windows 설정에서 마이크 권한을 확인해주세요',
              '다른 앱이 마이크를 사용 중인지 확인해주세요',
            ];
          } else {
            errorHints = [
              '마이크가 다른 프로그램에서 사용 중일 수 있습니다',
              '마이크를 다시 연결해보세요',
              '시스템을 재시작해보세요',
            ];
          }
        }

        return MicDiagnosticResult(
          timestamp: timestamp,
          status: MicDiagnosticStatus.failure,
          message: detailedMessage,
          hints: errorHints.isNotEmpty ? errorHints : const ['로그 파일을 확인해주세요'],
        );
      }

      // 7. 샘플 수집
      _logging.info('⏱️ ${sampleDuration.inSeconds}초 동안 샘플 수집 중...');
      await Future<void>.delayed(sampleDuration);

      // 8. 녹음 중지
      _logging.info('⏹️ 녹음 중지 중...');
      await recorder.stop();
      _logging.info('✅ 녹음 중지 완료');

      await subscription.cancel();
      subscription = null;

      if (tempFilePath != null) {
        final file = File(tempFilePath);
        if (await file.exists()) {
          unawaited(file.delete());
        }
      }

      // 9. 데이터 검증
      if (!peakLinear.isFinite || peakLinear.isNaN) {
        peakLinear = 0.0;
      }
      _logging.info('📈 수집된 샘플: ${samples.length}개, 피크 레벨: ${peakLinear.toStringAsFixed(4)}');

      // 10. 메트릭 계산
      _logging.info('🧮 메트릭 계산 중...');
      final metrics = _calculateMetrics(
        samples: samples,
        sampleWindow: sampleDuration,
        ambientWindow: ambientWindow,
      );

      _logging.info('📊 계산된 메트릭:');
      _logging.info('  - signalRms: ${metrics.signalRms.toStringAsFixed(4)}');
      _logging.info('  - signalDb: ${metrics.signalDb.toStringAsFixed(2)} dB');
      _logging.info('  - ambientDb: ${metrics.ambientDb.toStringAsFixed(2)} dB');
      _logging.info('  - SNR: ${metrics.snrDb.toStringAsFixed(2)} dB');

      // 11. 상태 판정
      _logging.info('🔍 상태 판정 중...');
      final decision = _classify(metrics);
      _logging.info('✅ 판정 결과: ${decision.status.name} - ${decision.message}');

      if (decision.status == MicDiagnosticStatus.ok) {
        return MicDiagnosticResult(
          timestamp: timestamp,
          status: MicDiagnosticStatus.ok,
          peakRms: metrics.signalRms,
          peakDb: metrics.signalDb,
          ambientDb: metrics.ambientDb,
          snrDb: metrics.snrDb,
          message: decision.message,
        );
      }

      return MicDiagnosticResult(
        timestamp: timestamp,
        status: decision.status,
        peakRms: metrics.signalRms,
        peakDb: metrics.signalDb,
        ambientDb: metrics.ambientDb,
        snrDb: metrics.snrDb,
        message: decision.message,
        hints: decision.hints,
      );
    } catch (e, stackTrace) {
      _logging.error('❌ 마이크 진단 중 예외 발생', error: e, stackTrace: stackTrace);
      _logging.error('에러 타입: ${e.runtimeType}');
      _logging.error('에러 메시지: $e');

      // 에러 타입별 힌트 제공
      String detailedMessage = '예상치 못한 오류가 발생했어요.';
      List<String> errorHints = [
        '로그 파일을 확인해주세요',
        '앱을 재시작한 후 다시 시도해보세요',
      ];

      if (e.toString().contains('permission') ||
          e.toString().contains('Permission')) {
        detailedMessage = '마이크 권한 문제가 발생했어요.';
        errorHints = [
          'Windows 설정에서 마이크 권한을 확인해주세요',
          '앱을 재시작한 후 다시 시도해보세요',
        ];
      } else if (e.toString().contains('device') ||
          e.toString().contains('Device')) {
        detailedMessage = '마이크 장치를 초기화하는 중 문제가 발생했어요.';
        errorHints = [
          '마이크를 다시 연결해보세요',
          'Windows 사운드 설정에서 기본 장치를 확인해주세요',
        ];
      } else if (e.toString().contains('codec') ||
          e.toString().contains('encoder')) {
        detailedMessage = '오디오 인코더 초기화에 실패했어요.';
        errorHints = [
          'Windows Media Feature Pack이 설치되어 있는지 확인해주세요',
          '시스템을 재시작해보세요',
        ];
      }

      return MicDiagnosticResult(
        timestamp: timestamp,
        status: MicDiagnosticStatus.failure,
        message: detailedMessage,
        hints: errorHints,
      );
    } finally {
      try {
        await recorder.stop();
      } catch (_) {}
      try {
        await recorder.dispose();
      } catch (_) {}
      await subscription?.cancel();
      if (tempFilePath != null) {
        final file = File(tempFilePath);
        if (await file.exists()) {
          unawaited(file.delete());
        }
      }
    }
  }

  static const double _normalThresholdDb = -24.0;
  static const double _quietOkThresholdDb = -40.0;
  static const double _quietSnrAllowanceDb = 3.5;
  static const double _quietAcceptableDb = -48.0;
  static const double _snrToleranceDb = -0.5;
  static const double _minDb = -80.0;

  static const double _noSignalThresholdDb = -70.0;
  static const double _extremeLowThresholdDb = -60.0;

  double _normalizeAmplitude(Amplitude amplitude) {
    double sample = amplitude.current;
    if (sample == 0 && amplitude.max != 0) {
      sample = amplitude.max;
    }

    if (sample <= 0) {
      return math.pow(10, sample / 20).toDouble().clamp(0.0, 1.0);
    }

    if (sample <= 1.0) {
      return sample.clamp(0.0, 1.0);
    }

    final normalized = sample / 32768.0;
    if (!normalized.isFinite || normalized.isNaN) {
      return 0.0;
    }
    return normalized.clamp(0.0, 1.0);
  }

  _DiagnosticMetrics _calculateMetrics({
    required List<_AmplitudeSample> samples,
    required Duration sampleWindow,
    required Duration ambientWindow,
  }) {
    if (samples.isEmpty) {
      return const _DiagnosticMetrics.zero();
    }

    final startTime = samples.first.timestamp;
    final ambientDeadline = startTime.add(ambientWindow);

    final ambientValues = <double>[];
    final signalValues = <double>[];

    for (final sample in samples) {
      if (sample.timestamp.isBefore(ambientDeadline)) {
        ambientValues.add(sample.value);
      } else {
        signalValues.add(sample.value);
      }
    }

    if (signalValues.isEmpty) {
      signalValues.addAll(ambientValues);
    }

    final ambientRms = _rms(ambientValues);
    final signalRms = _rms(signalValues);

    final ambientDb = _toDb(ambientRms);
    final signalDb = _toDb(signalRms);
    final snrDb = _snrDb(signalRms, ambientRms);

    return _DiagnosticMetrics(
      signalRms: signalRms,
      ambientRms: ambientRms,
      signalDb: signalDb,
      ambientDb: ambientDb,
      snrDb: snrDb,
    );
  }

  _DiagnosticDecision _classify(_DiagnosticMetrics metrics) {
    final signalDb = metrics.signalDb;
    final snrDb = metrics.snrDb;

    if (signalDb < _noSignalThresholdDb) {
      return _DiagnosticDecision(
        status: MicDiagnosticStatus.noSignal,
        message: '마이크 신호가 전혀 감지되지 않아요. 마이크가 연결되어 있는지 확인해주세요.',
        hints: const [
          '마이크 케이블이 PC에 제대로 꽂혀 있는지 확인',
          'USB 마이크라면 다른 포트에 연결해보세요',
          '블루투스 마이크라면 페어링 상태 확인',
        ],
      );
    }

    if (signalDb < _extremeLowThresholdDb) {
      return _DiagnosticDecision(
        status: MicDiagnosticStatus.lowInput,
        message: '소리가 거의 들어오지 않아요. 마이크 음소거 스위치나 볼륨을 확인하세요.',
        hints: const [
          '헤드셋 음소거 스위치 해제',
          'Windows 입력 장치 볼륨을 높여주세요',
          '마이크를 입 가까이에 두고 말해보세요',
        ],
      );
    }

    final quietButClear =
        signalDb >= _quietOkThresholdDb && snrDb >= _quietSnrAllowanceDb;
    final quietButAcceptable =
        signalDb >= _quietAcceptableDb && snrDb >= _snrToleranceDb;
    final normalLevel = signalDb >= _normalThresholdDb;

    if (normalLevel || quietButClear || quietButAcceptable) {
      final description = quietButClear
          ? '조용한 환경이지만 음성이 또렷하게 감지되고 있어요.'
          : quietButAcceptable
              ? '녹음은 가능하지만 입력이 다소 낮아요. 필요하면 마이크 위치나 볼륨을 조금만 조정해 주세요.'
              : '마이크 입력이 정상이에요.';
      return _DiagnosticDecision(
        status: MicDiagnosticStatus.ok,
        message: description,
      );
    }

    if (signalDb >= _quietOkThresholdDb) {
      return _DiagnosticDecision(
        status: MicDiagnosticStatus.lowInput,
        message: '입력 레벨이 조금 낮아요. 마이크 위치나 볼륨을 조정해 주세요.',
        hints: const [
          '마이크를 입 가까이에 두고 말해보세요.',
          'Windows 입력 장치 볼륨을 조금 높여주세요.',
        ],
      );
    }

    return _DiagnosticDecision(
      status: MicDiagnosticStatus.lowInput,
      message: '마이크 연결이나 음소거 스위치를 확인하세요.',
      hints: const [
        '마이크 케이블과 연결 상태 확인',
        '헤드셋 음소거 스위치 해제',
        'Windows 입력 장치 설정에서 기본 장치 확인',
      ],
    );
  }

  double _rms(List<double> values) {
    if (values.isEmpty) {
      return 0.0;
    }
    var sumSquares = 0.0;
    for (final value in values) {
      sumSquares += value * value;
    }
    return math.sqrt(sumSquares / values.length);
  }

  double _toDb(double rms) {
    if (rms <= 0) {
      return _minDb;
    }
    return 20 * (math.log(rms) / math.ln10);
  }

  double _snrDb(double signalRms, double ambientRms) {
    final epsilon = 1e-9;
    return 20 *
        (math.log((signalRms + epsilon) / (ambientRms + epsilon)) / math.ln10);
  }

  String _extensionForEncoder(AudioEncoder encoder) {
    switch (encoder) {
      case AudioEncoder.aacLc:
        return '.m4a';
      case AudioEncoder.opus:
        return '.opus';
      case AudioEncoder.wav:
        return '.wav';
      default:
        return '.m4a';
    }
  }
}

class _AmplitudeSample {
  _AmplitudeSample(this.timestamp, this.value);

  final DateTime timestamp;
  final double value;
}

class _DiagnosticMetrics {
  const _DiagnosticMetrics({
    required this.signalRms,
    required this.ambientRms,
    required this.signalDb,
    required this.ambientDb,
    required this.snrDb,
  });

  const _DiagnosticMetrics.zero()
      : signalRms = 0.0,
        ambientRms = 0.0,
        signalDb = MicDiagnosticsService._minDb,
        ambientDb = MicDiagnosticsService._minDb,
        snrDb = 0.0;

  final double signalRms;
  final double ambientRms;
  final double signalDb;
  final double ambientDb;
  final double snrDb;
}

class _DiagnosticDecision {
  const _DiagnosticDecision({
    required this.status,
    required this.message,
    this.hints = const <String>[],
  });

  final MicDiagnosticStatus status;
  final String message;
  final List<String> hints;
}
