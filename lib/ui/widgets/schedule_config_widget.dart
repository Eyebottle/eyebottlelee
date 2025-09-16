import 'package:flutter/material.dart';
import '../../models/schedule_model.dart';
import '../../services/schedule_service.dart';

class ScheduleConfigWidget extends StatefulWidget {
  const ScheduleConfigWidget({super.key});

  @override
  State<ScheduleConfigWidget> createState() => _ScheduleConfigWidgetState();
}

class _ScheduleConfigWidgetState extends State<ScheduleConfigWidget> {
  late WeeklySchedule _schedule;

  @override
  void initState() {
    super.initState();
    _schedule = _getDefaultSchedule();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('진료 시간표 설정'),
      content: SizedBox(
        width: 400,
        height: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 요일별 설정
              for (int weekDay = 1; weekDay <= 7; weekDay++)
                _buildDayScheduleCard(weekDay),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _saveSchedule,
          child: const Text('저장'),
        ),
      ],
    );
  }

  /// 요일별 스케줄 카드 생성
  Widget _buildDayScheduleCard(int weekDay) {
    final dayName = _getDayName(weekDay);
    final daySchedule = _schedule.weekDays[weekDay % 7] ?? DaySchedule.rest();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 요일 제목과 근무일 체크박스
            Row(
              children: [
                Text(
                  dayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Checkbox(
                  value: daySchedule.isWorkingDay,
                  onChanged: (value) => _toggleWorkingDay(weekDay, value ?? false),
                ),
                const Text('근무일'),
              ],
            ),

            if (daySchedule.isWorkingDay) ...[
              const SizedBox(height: 8),

              // 진료 시간 설정
              Row(
                children: [
                  const Text('진료시간: '),
                  _buildTimeButton(
                    context,
                    daySchedule.startTime,
                    (time) => _updateStartTime(weekDay, time),
                  ),
                  const Text(' ~ '),
                  _buildTimeButton(
                    context,
                    daySchedule.endTime,
                    (time) => _updateEndTime(weekDay, time),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 점심시간 설정
              Row(
                children: [
                  Checkbox(
                    value: daySchedule.lunchStart != null,
                    onChanged: (value) => _toggleLunchTime(weekDay, value ?? false),
                  ),
                  const Text('점심시간: '),
                  if (daySchedule.lunchStart != null) ...[
                    _buildTimeButton(
                      context,
                      daySchedule.lunchStart!,
                      (time) => _updateLunchStart(weekDay, time),
                    ),
                    const Text(' ~ '),
                    _buildTimeButton(
                      context,
                      daySchedule.lunchEnd!,
                      (time) => _updateLunchEnd(weekDay, time),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 시간 선택 버튼
  Widget _buildTimeButton(
    BuildContext context,
    TimeOfDay time,
    Function(TimeOfDay) onTimeChanged,
  ) {
    return OutlinedButton(
      onPressed: () => _selectTime(context, time, onTimeChanged),
      child: Text(_formatTime(time)),
    );
  }

  /// 시간 선택 다이얼로그
  Future<void> _selectTime(
    BuildContext context,
    TimeOfDay initialTime,
    Function(TimeOfDay) onTimeChanged,
  ) async {
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (time != null) {
      onTimeChanged(time);
    }
  }

  /// 근무일 토글
  void _toggleWorkingDay(int weekDay, bool isWorking) {
    setState(() {
      if (isWorking) {
        _schedule.weekDays[weekDay % 7] = DaySchedule.working(
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 18, minute: 0),
        );
      } else {
        _schedule.weekDays[weekDay % 7] = DaySchedule.rest();
      }
    });
  }

  /// 점심시간 토글
  void _toggleLunchTime(int weekDay, bool hasLunch) {
    setState(() {
      final daySchedule = _schedule.weekDays[weekDay % 7]!;
      if (hasLunch) {
        _schedule.weekDays[weekDay % 7] = daySchedule.copyWith(
          lunchStart: const TimeOfDay(hour: 12, minute: 0),
          lunchEnd: const TimeOfDay(hour: 13, minute: 0),
        );
      } else {
        _schedule.weekDays[weekDay % 7] = daySchedule.copyWith(
          lunchStart: null,
          lunchEnd: null,
        );
      }
    });
  }

  /// 시작 시간 업데이트
  void _updateStartTime(int weekDay, TimeOfDay time) {
    setState(() {
      final daySchedule = _schedule.weekDays[weekDay % 7]!;
      _schedule.weekDays[weekDay % 7] = daySchedule.copyWith(startTime: time);
    });
  }

  /// 종료 시간 업데이트
  void _updateEndTime(int weekDay, TimeOfDay time) {
    setState(() {
      final daySchedule = _schedule.weekDays[weekDay % 7]!;
      _schedule.weekDays[weekDay % 7] = daySchedule.copyWith(endTime: time);
    });
  }

  /// 점심 시작 시간 업데이트
  void _updateLunchStart(int weekDay, TimeOfDay time) {
    setState(() {
      final daySchedule = _schedule.weekDays[weekDay % 7]!;
      _schedule.weekDays[weekDay % 7] = daySchedule.copyWith(lunchStart: time);
    });
  }

  /// 점심 종료 시간 업데이트
  void _updateLunchEnd(int weekDay, TimeOfDay time) {
    setState(() {
      final daySchedule = _schedule.weekDays[weekDay % 7]!;
      _schedule.weekDays[weekDay % 7] = daySchedule.copyWith(lunchEnd: time);
    });
  }

  /// 스케줄 저장
  void _saveSchedule() {
    // TODO: SharedPreferences에 저장
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('진료 시간표가 저장되었습니다.')),
    );
  }

  /// 기본 스케줄 반환
  WeeklySchedule _getDefaultSchedule() {
    return WeeklySchedule(
      weekDays: {
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
        0: DaySchedule.rest(), // 일요일
      },
    );
  }

  /// 요일명 반환
  String _getDayName(int weekDay) {
    switch (weekDay) {
      case 1: return '월요일';
      case 2: return '화요일';
      case 3: return '수요일';
      case 4: return '목요일';
      case 5: return '금요일';
      case 6: return '토요일';
      case 7: return '일요일';
      default: return '';
    }
  }

  /// 시간 포맷팅
  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}