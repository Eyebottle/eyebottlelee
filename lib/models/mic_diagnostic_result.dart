import 'dart:convert';

enum MicDiagnosticStatus {
  ok,
  lowInput,
  noSignal,
  permissionDenied,
  noInputDevice,
  recorderBusy,
  failure,
}

/// 진단 상태가 "사용자 조치가 필요한 문제"인지 여부.
/// 여러 화면에서 동일하게 쓰던 5개 상태 OR 목록을 한 곳으로 모은다.
extension MicDiagnosticStatusProblem on MicDiagnosticStatus {
  bool get isProblem =>
      this == MicDiagnosticStatus.failure ||
      this == MicDiagnosticStatus.noSignal ||
      this == MicDiagnosticStatus.lowInput ||
      this == MicDiagnosticStatus.permissionDenied ||
      this == MicDiagnosticStatus.noInputDevice;
}

class MicDiagnosticResult {
  MicDiagnosticResult({
    required this.timestamp,
    required this.status,
    this.peakRms,
    this.peakDb,
    this.ambientDb,
    this.snrDb,
    this.message,
    this.hints = const <String>[],
  });

  final DateTime timestamp;
  final MicDiagnosticStatus status;
  final double? peakRms;
  final double? peakDb;
  final double? ambientDb;
  final double? snrDb;
  final String? message;
  final List<String> hints;

  bool get isSuccess => status == MicDiagnosticStatus.ok;

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'peakRms': peakRms,
      'peakDb': peakDb,
      'ambientDb': ambientDb,
      'snrDb': snrDb,
      'message': message,
      'hints': hints,
    };
  }

  static MicDiagnosticResult? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final statusName = json['status'] as String?;
    final status = MicDiagnosticStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => MicDiagnosticStatus.failure,
    );
    return MicDiagnosticResult(
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      status: status,
      peakRms: (json['peakRms'] as num?)?.toDouble(),
      peakDb: (json['peakDb'] as num?)?.toDouble(),
      ambientDb: (json['ambientDb'] as num?)?.toDouble(),
      snrDb: (json['snrDb'] as num?)?.toDouble(),
      message: json['message'] as String?,
      hints: ((json['hints'] as List?)?.cast<String>()) ?? const <String>[],
    );
  }

  static MicDiagnosticResult? fromJsonString(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return fromJson(json.decode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  String toJsonString() => json.encode(toJson());
}
