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
        1: DaySchedule.split(
          morning: WorkingSession(
            start: const TimeOfDay(hour: 9, minute: 0),
            end: const TimeOfDay(hour: 13, minute: 0),
          ),
          afternoon: WorkingSession(
            start: const TimeOfDay(hour: 14, minute: 0),
            end: const TimeOfDay(hour: 18, minute: 0),
          ),
        ),
        2: DaySchedule.split(
          morning: WorkingSession(
            start: const TimeOfDay(hour: 9, minute: 0),
            end: const TimeOfDay(hour: 12, minute: 0),
          ),
          afternoon: WorkingSession(
            start: const TimeOfDay(hour: 13, minute: 0),
            end: const TimeOfDay(hour: 18, minute: 0),
          ),
        ),
        3: DaySchedule.split(
          morning: WorkingSession(
            start: const TimeOfDay(hour: 9, minute: 0),
            end: const TimeOfDay(hour: 12, minute: 0),
          ),
          afternoon: WorkingSession(
            start: const TimeOfDay(hour: 13, minute: 0),
            end: const TimeOfDay(hour: 18, minute: 0),
          ),
        ),
        4: DaySchedule.split(
          morning: WorkingSession(
            start: const TimeOfDay(hour: 9, minute: 0),
            end: const TimeOfDay(hour: 12, minute: 0),
          ),
          afternoon: WorkingSession(
            start: const TimeOfDay(hour: 13, minute: 0),
            end: const TimeOfDay(hour: 18, minute: 0),
          ),
        ),
        5: DaySchedule.split(
          morning: WorkingSession(
            start: const TimeOfDay(hour: 9, minute: 0),
            end: const TimeOfDay(hour: 12, minute: 0),
          ),
          afternoon: WorkingSession(
            start: const TimeOfDay(hour: 13, minute: 0),
            end: const TimeOfDay(hour: 18, minute: 0),
          ),
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

enum ScheduleMode { fullDay, split }

/// 일일 진료 스케줄 모델
class DaySchedule {
  final bool isWorkingDay;
  final List<WorkingSession> sessions;
  final ScheduleMode mode;

  const DaySchedule({
    required this.isWorkingDay,
    required this.sessions,
    this.mode = ScheduleMode.fullDay,
  });

  /// 오전/오후 구간을 모두 활성화한 근무일
  factory DaySchedule.split({
    WorkingSession? morning,
    WorkingSession? afternoon,
  }) {
    final slots = <WorkingSession>[];
    if (morning != null) slots.add(morning);
    if (afternoon != null) slots.add(afternoon);
    return DaySchedule(
      isWorkingDay: slots.isNotEmpty,
      sessions: slots,
      mode: ScheduleMode.split,
    );
  }

  /// 종일 근무일
  factory DaySchedule.fullDay({
    required TimeOfDay start,
    required TimeOfDay end,
  }) {
    return DaySchedule(
      isWorkingDay: true,
      sessions: [WorkingSession(start: start, end: end)],
      mode: ScheduleMode.fullDay,
    );
  }

  /// 휴무일 생성
  factory DaySchedule.rest() {
    return const DaySchedule(isWorkingDay: false, sessions: [], mode: ScheduleMode.fullDay);
  }

  /// JSON에서 생성 (레거시 호환)
  factory DaySchedule.fromJson(Map<String, dynamic> json) {
    final slotsJson = json['slots'];
    if (slotsJson is List) {
      final slots = slotsJson
          .map((e) => WorkingSession.fromJson(Map<String, dynamic>.from(e)))
          .whereType<WorkingSession>()
          .toList()
        ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
      final isWorking = json['isWorkingDay'] ?? slots.isNotEmpty;
      final modeValue = json['mode'];
      final mode = modeValue is String && modeValue == ScheduleMode.split.name
          ? ScheduleMode.split
          : (slots.length > 1 ? ScheduleMode.split : ScheduleMode.fullDay);
      return DaySchedule(isWorkingDay: isWorking, sessions: slots, mode: mode);
    }

    // 레거시 필드 변환
    final isWorking = json['isWorkingDay'] ?? false;
    if (!isWorking) return DaySchedule.rest();

    final start = _timeFromJson(json['startTime']);
    final end = _timeFromJson(json['endTime']);
    final lunchStart = json['lunchStart'] != null ? _timeFromJson(json['lunchStart']) : null;
    final lunchEnd = json['lunchEnd'] != null ? _timeFromJson(json['lunchEnd']) : null;

    final slots = <WorkingSession>[];
    if (lunchStart != null && lunchEnd != null) {
      slots.add(WorkingSession(start: start, end: lunchStart));
      slots.add(WorkingSession(start: lunchEnd, end: end));
    } else {
      slots.add(WorkingSession(start: start, end: end));
    }

    final mode = slots.length > 1 ? ScheduleMode.split : ScheduleMode.fullDay;
    return DaySchedule(isWorkingDay: true, sessions: slots, mode: mode);
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'isWorkingDay': isWorkingDay,
      'slots': sessions.map((e) => e.toJson()).toList(),
      'mode': mode.name,
    };
  }

  /// 복사본 생성
  DaySchedule copyWith({
    bool? isWorkingDay,
    List<WorkingSession>? sessions,
    ScheduleMode? mode,
  }) {
    return DaySchedule(
      isWorkingDay: isWorkingDay ?? this.isWorkingDay,
      sessions: sessions ?? List<WorkingSession>.from(this.sessions),
      mode: mode ?? this.mode,
    );
  }

  bool get hasWorkingSession => isWorkingDay && sessions.isNotEmpty;

  /// 시간 범위 내인지 확인
  bool isTimeInWorkingHours(TimeOfDay time) {
    if (!hasWorkingSession) return false;
    return sessions.any((slot) => slot.contains(time));
  }

  /// 첫 번째 세션의 시작 시각 (없으면 null)
  TimeOfDay? get startTime => hasWorkingSession ? sessions.first.start : null;

  /// 마지막 세션의 종료 시각 (없으면 null)
  TimeOfDay? get endTime => hasWorkingSession ? sessions.last.end : null;

  /// 시간 JSON 변환 헬퍼
  static TimeOfDay _timeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const TimeOfDay(hour: 0, minute: 0);
    }
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
    if (!isWorkingDay || sessions.isEmpty) return '휴무';
    final ranges = sessions
        .map((slot) => '${_formatTime(slot.start)}~${_formatTime(slot.end)}')
        .join(', ');
    return ranges;
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class WorkingSession {
  final TimeOfDay start;
  final TimeOfDay end;

  const WorkingSession({required this.start, required this.end});

  factory WorkingSession.fromJson(Map<String, dynamic> json) {
    final startJson = json['start'];
    final endJson = json['end'];
    if (startJson == null || endJson == null) {
      throw const FormatException('Invalid slot json');
    }
    return WorkingSession(
      start: DaySchedule._timeFromJson(Map<String, dynamic>.from(startJson)),
      end: DaySchedule._timeFromJson(Map<String, dynamic>.from(endJson)),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': DaySchedule._timeToJson(start),
      'end': DaySchedule._timeToJson(end),
    };
  }

  int get startMinutes => start.hour * 60 + start.minute;
  int get endMinutes => end.hour * 60 + end.minute;

  bool contains(TimeOfDay time) {
    final minutes = time.hour * 60 + time.minute;
    return minutes >= startMinutes && minutes <= endMinutes;
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
