import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

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

    try {
      final hasPermission = await recorder.hasPermission();
      if (hasPermission == false) {
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

      final devices = await recorder.listInputDevices();
      if (devices == null || devices.isEmpty) {
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

      final tempDir = await getTemporaryDirectory();
      tempFilePath = path.join(
        tempDir.path,
        'mic_diag_${timestamp.millisecondsSinceEpoch}.m4a',
      );

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

      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
        ),
        path: tempFilePath,
      );

      await Future<void>.delayed(sampleDuration);
      await recorder.stop();
      await subscription.cancel();
      subscription = null;

      if (tempFilePath != null) {
        final file = File(tempFilePath);
        if (await file.exists()) {
          unawaited(file.delete());
        }
      }

      if (!peakLinear.isFinite || peakLinear.isNaN) {
        peakLinear = 0.0;
      }

      final metrics = _calculateMetrics(
        samples: samples,
        sampleWindow: sampleDuration,
        ambientWindow: ambientWindow,
      );

      final decision = _classify(metrics);

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
      _logging.error('마이크 진단 실패', error: e, stackTrace: stackTrace);
      return MicDiagnosticResult(
        timestamp: timestamp,
        status: MicDiagnosticStatus.failure,
        message: '예상치 못한 오류가 발생했어요. 다시 시도하거나 지원 팀에 문의해 주세요.',
      );
    } finally {
      try {
        await recorder.stop();
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
      final description =
          quietButClear
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
