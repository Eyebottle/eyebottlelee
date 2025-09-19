import 'package:flutter/material.dart';
import '../../models/schedule_model.dart';
import '../../services/settings_service.dart';
import '../style/app_spacing.dart';
import 'app_section_card.dart';

class ScheduleConfigWidget extends StatefulWidget {
  final VoidCallback? onSaved;
  const ScheduleConfigWidget({super.key, this.onSaved});

  @override
  State<ScheduleConfigWidget> createState() => _ScheduleConfigWidgetState();
}

class _ScheduleConfigWidgetState extends State<ScheduleConfigWidget> {
  late WeeklySchedule _schedule;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _schedule = _getDefaultSchedule();
    _loadPersistedSchedule();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.of(context).size;
    final maxWidth = mediaSize.width * 0.9;
    final maxHeight = mediaSize.height * 0.8;

    return AlertDialog(
      title: const Text('진료 시간표 설정'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth.clamp(0.0, 420.0),
          maxHeight: maxHeight,
        ),
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: ListView.separated(
            controller: _scrollController,
            shrinkWrap: true,
            itemCount: 7,
            padding: const EdgeInsets.only(right: AppSpacing.xs, bottom: AppSpacing.sm),
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, index) => _buildDayScheduleCard(index + 1),
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

    return AppSectionCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Checkbox(
                value: daySchedule.isWorkingDay,
                onChanged: (value) => _toggleWorkingDay(weekDay, value ?? false),
              ),
              const Text('근무일'),
            ],
          ),

          if (daySchedule.isWorkingDay) ...[
            const SizedBox(height: AppSpacing.sm),
            _ResponsiveFieldRow(
              label: '진료시간',
              controls: [
                _buildTimeButton(
                  context,
                  daySchedule.startTime,
                  (time) => _updateStartTime(weekDay, time),
                ),
                const Text('~'),
                _buildTimeButton(
                  context,
                  daySchedule.endTime,
                  (time) => _updateEndTime(weekDay, time),
                ),
              ],
            ),
            if (daySchedule.lunchStart != null)
              const SizedBox(height: AppSpacing.sm),
            _ResponsiveFieldRow(
              label: '점심시간',
              leading: Checkbox(
                value: daySchedule.lunchStart != null,
                onChanged: (value) => _toggleLunchTime(weekDay, value ?? false),
              ),
              controls: daySchedule.lunchStart == null
                  ? [const Text('미사용')]
                  : [
                      _buildTimeButton(
                        context,
                        daySchedule.lunchStart!,
                        (time) => _updateLunchStart(weekDay, time),
                      ),
                      const Text('~'),
                      _buildTimeButton(
                        context,
                        daySchedule.lunchEnd!,
                        (time) => _updateLunchEnd(weekDay, time),
                      ),
                    ],
            ),
          ],
        ],
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
  Future<void> _saveSchedule() async {
    try {
      await SettingsService().saveSchedule(_schedule);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('진료 시간표가 저장되었습니다.')),
        );
      }
      widget.onSaved?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    }
  }

  Future<void> _loadPersistedSchedule() async {
    final saved = await SettingsService().loadSchedule();
    if (!mounted) return;
    if (saved != null) {
      setState(() => _schedule = saved);
    }
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

class _ResponsiveFieldRow extends StatelessWidget {
  const _ResponsiveFieldRow({
    required this.label,
    required this.controls,
    this.leading,
  });

  final String label;
  final List<Widget> controls;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 300;
        final labelWidget = Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        );
        final controlsWrap = Wrap(
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: controls,
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[
                    SizedBox(height: 24, child: leading!),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  labelWidget,
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              controlsWrap,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              SizedBox(height: 24, child: leading!),
              const SizedBox(width: AppSpacing.xs),
            ],
            SizedBox(
              width: 80,
              child: labelWidget,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: controlsWrap),
          ],
        );
      },
    );
  }
}
