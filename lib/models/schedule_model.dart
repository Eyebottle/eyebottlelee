import 'package:flutter/material.dart';

/// 주간 진료 시간표 모델
class WeeklySchedule {
  final Map<int, DaySchedule> weekDays; // 0=일요일, 1=월요일, ..., 6=토요일

  WeeklySchedule({required this.weekDays});

  /// JSON에서 생성
  factory WeeklySchedule.fromJson(Map<String, dynamic> json) {
    final Map<int, DaySchedule> weekDays = {};

    for (int i = 0; i <= 6; i++) {
      final dayData = json['day_$i'];
      if (dayData != null) {
        weekDays[i] = DaySchedule.fromJson(dayData);
      } else {
        weekDays[i] = DaySchedule.rest();
      }
    }

    return WeeklySchedule(weekDays: weekDays);
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {};

    for (int i = 0; i <= 6; i++) {
      json['day_$i'] = weekDays[i]?.toJson();
    }

    return json;
  }

  /// 기본 스케줄 생성 (월-금 9-18시, 점심 12-13시)
  factory WeeklySchedule.defaultSchedule() {
    return WeeklySchedule(
      weekDays: {
        0: DaySchedule.rest(), // 일요일
        1: DaySchedule.working( // 월요일
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 18, minute: 0),
          lunchStart: const TimeOfDay(hour: 12, minute: 0),
          lunchEnd: const TimeOfDay(hour: 13, minute: 0),
        ),
        2: DaySchedule.working( // 화요일
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 18, minute: 0),
          lunchStart: const TimeOfDay(hour: 12, minute: 0),
          lunchEnd: const TimeOfDay(hour: 13, minute: 0),
        ),
        3: DaySchedule.working( // 수요일
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 18, minute: 0),
          lunchStart: const TimeOfDay(hour: 12, minute: 0),
          lunchEnd: const TimeOfDay(hour: 13, minute: 0),
        ),
        4: DaySchedule.working( // 목요일
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 18, minute: 0),
          lunchStart: const TimeOfDay(hour: 12, minute: 0),
          lunchEnd: const TimeOfDay(hour: 13, minute: 0),
        ),
        5: DaySchedule.working( // 금요일
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 18, minute: 0),
          lunchStart: const TimeOfDay(hour: 12, minute: 0),
          lunchEnd: const TimeOfDay(hour: 13, minute: 0),
        ),
        6: DaySchedule.rest(), // 토요일
      },
    );
  }

  /// 복사본 생성
  WeeklySchedule copyWith({Map<int, DaySchedule>? weekDays}) {
    return WeeklySchedule(
      weekDays: weekDays ?? Map.from(this.weekDays),
    );
  }
}

/// 일일 진료 스케줄 모델
class DaySchedule {
  final bool isWorkingDay;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final TimeOfDay? lunchStart;
  final TimeOfDay? lunchEnd;

  const DaySchedule({
    required this.isWorkingDay,
    required this.startTime,
    required this.endTime,
    this.lunchStart,
    this.lunchEnd,
  });

  /// 근무일 생성
  factory DaySchedule.working({
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    TimeOfDay? lunchStart,
    TimeOfDay? lunchEnd,
  }) {
    return DaySchedule(
      isWorkingDay: true,
      startTime: startTime,
      endTime: endTime,
      lunchStart: lunchStart,
      lunchEnd: lunchEnd,
    );
  }

  /// 휴무일 생성
  factory DaySchedule.rest() {
    return const DaySchedule(
      isWorkingDay: false,
      startTime: TimeOfDay(hour: 0, minute: 0),
      endTime: TimeOfDay(hour: 0, minute: 0),
    );
  }

  /// JSON에서 생성
  factory DaySchedule.fromJson(Map<String, dynamic> json) {
    return DaySchedule(
      isWorkingDay: json['isWorkingDay'] ?? false,
      startTime: _timeFromJson(json['startTime']),
      endTime: _timeFromJson(json['endTime']),
      lunchStart: json['lunchStart'] != null ? _timeFromJson(json['lunchStart']) : null,
      lunchEnd: json['lunchEnd'] != null ? _timeFromJson(json['lunchEnd']) : null,
    );
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'isWorkingDay': isWorkingDay,
      'startTime': _timeToJson(startTime),
      'endTime': _timeToJson(endTime),
      'lunchStart': lunchStart != null ? _timeToJson(lunchStart!) : null,
      'lunchEnd': lunchEnd != null ? _timeToJson(lunchEnd!) : null,
    };
  }

  /// 복사본 생성
  DaySchedule copyWith({
    bool? isWorkingDay,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    TimeOfDay? lunchStart,
    TimeOfDay? lunchEnd,
  }) {
    return DaySchedule(
      isWorkingDay: isWorkingDay ?? this.isWorkingDay,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      lunchStart: lunchStart ?? this.lunchStart,
      lunchEnd: lunchEnd ?? this.lunchEnd,
    );
  }

  /// 시간 범위 내인지 확인
  bool isTimeInWorkingHours(TimeOfDay time) {
    if (!isWorkingDay) return false;

    final timeMinutes = time.hour * 60 + time.minute;
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;

    // 기본 근무 시간 범위 체크
    if (timeMinutes < startMinutes || timeMinutes > endMinutes) {
      return false;
    }

    // 점심시간 체크
    if (lunchStart != null && lunchEnd != null) {
      final lunchStartMinutes = lunchStart!.hour * 60 + lunchStart!.minute;
      final lunchEndMinutes = lunchEnd!.hour * 60 + lunchEnd!.minute;

      if (timeMinutes >= lunchStartMinutes && timeMinutes <= lunchEndMinutes) {
        return false; // 점심시간이므로 근무 시간이 아님
      }
    }

    return true;
  }

  /// 시간 JSON 변환 헬퍼
  static TimeOfDay _timeFromJson(Map<String, dynamic> json) {
    return TimeOfDay(
      hour: json['hour'] ?? 0,
      minute: json['minute'] ?? 0,
    );
  }

  static Map<String, dynamic> _timeToJson(TimeOfDay time) {
    return {
      'hour': time.hour,
      'minute': time.minute,
    };
  }

  @override
  String toString() {
    if (!isWorkingDay) return '휴무';

    String schedule = '${_formatTime(startTime)} ~ ${_formatTime(endTime)}';
    if (lunchStart != null && lunchEnd != null) {
      schedule += ' (점심: ${_formatTime(lunchStart!)} ~ ${_formatTime(lunchEnd!)})';
    }
    return schedule;
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// 녹음 세션 모델
class RecordingSession {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final List<String> filePaths;
  final bool isActive;

  const RecordingSession({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.filePaths,
    required this.isActive,
  });

  /// 세션 지속 시간
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// JSON에서 생성
  factory RecordingSession.fromJson(Map<String, dynamic> json) {
    return RecordingSession(
      id: json['id'],
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      filePaths: List<String>.from(json['filePaths'] ?? []),
      isActive: json['isActive'] ?? false,
    );
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'filePaths': filePaths,
      'isActive': isActive,
    };
  }

  /// 복사본 생성
  RecordingSession copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    List<String>? filePaths,
    bool? isActive,
  }) {
    return RecordingSession(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      filePaths: filePaths ?? List.from(this.filePaths),
      isActive: isActive ?? this.isActive,
    );
  }
}
