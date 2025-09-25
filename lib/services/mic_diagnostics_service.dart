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
  }) async {
    final timestamp = DateTime.now();
    final recorder = AudioRecorder();
    StreamSubscription<Amplitude>? subscription;
    String? tempFilePath;
    double peakLevel = 0.0;

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
        if (normalized > peakLevel) {
          peakLevel = normalized;
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

      if (!peakLevel.isFinite || peakLevel.isNaN) {
        peakLevel = 0.0;
      }

      if (peakLevel >= _okThreshold) {
        return MicDiagnosticResult(
          timestamp: timestamp,
          status: MicDiagnosticStatus.ok,
          peakRms: peakLevel,
          message: '마이크 입력이 정상이에요.',
        );
      }

      if (peakLevel >= _cautionThreshold) {
        return MicDiagnosticResult(
          timestamp: timestamp,
          status: MicDiagnosticStatus.lowInput,
          peakRms: peakLevel,
          message: '입력 레벨이 조금 낮아요. 마이크 위치나 볼륨을 조정해 주세요.',
          hints: const [
            '마이크와 거리를 조금 더 가깝게 설정',
            'Windows 입력 장치 볼륨을 높임',
          ],
        );
      }

      return MicDiagnosticResult(
        timestamp: timestamp,
        status: MicDiagnosticStatus.lowInput,
        peakRms: peakLevel,
        message: '소리가 거의 들어오지 않아요. 마이크 연결이나 음소거 스위치를 확인하세요.',
        hints: const [
          '마이크 케이블과 연결 상태 확인',
          '헤드셋 음소거 스위치 해제',
          'Windows 입력 장치 설정에서 기본 장치 확인',
        ],
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

  // 진료실 환경의 상대적으로 작은 음성을 고려해 임계값을 낮춘다.
  static const double _okThreshold = 0.04;
  static const double _cautionThreshold = 0.018;

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
}
