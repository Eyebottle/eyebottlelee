import 'package:flutter/material.dart';

import '../../models/schedule_model.dart';
import '../../services/settings_service.dart';
import '../style/app_spacing.dart';
import 'app_section_card.dart';

enum DaySessionMode { fullDay, split }

class ScheduleConfigWidget extends StatefulWidget {
  const ScheduleConfigWidget({super.key, this.onSaved});

  final VoidCallback? onSaved;

  @override
  State<ScheduleConfigWidget> createState() => _ScheduleConfigWidgetState();
}

class _ScheduleConfigWidgetState extends State<ScheduleConfigWidget> {
  late WeeklySchedule _schedule;
  late Map<int, _DayEditorState> _editorStates;
  final ScrollController _scrollController = ScrollController();
  final SettingsService _settings = SettingsService();

  @override
  void initState() {
    super.initState();
    _schedule = _defaultSchedule();
    _editorStates = _buildEditorStates(_schedule);
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
    final maxWidth = (mediaSize.width * 0.9).clamp(320.0, 420.0);
    final maxHeight = (mediaSize.height * 0.8).clamp(360.0, 560.0);

    return AlertDialog(
      title: const Text('진료 시간표 설정'),
      content: SizedBox(
        width: maxWidth,
        height: maxHeight,
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.only(right: AppSpacing.xs, bottom: AppSpacing.sm),
            itemCount: 7,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, index) => _buildDayCard(index + 1),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('저장'),
        ),
      ],
    );
  }

  Future<void> _loadPersistedSchedule() async {
    final saved = await _settings.loadSchedule();
    if (!mounted) return;
    if (saved != null) {
      setState(() {
        _schedule = saved;
        _editorStates = _buildEditorStates(saved);
      });
    }
  }

  Widget _buildDayCard(int weekDay) {
    final index = weekDay % 7;
    final editor = _editorStates[index]!;
    final dayName = _dayName(weekDay);

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
              Switch(
                value: editor.working,
                onChanged: (value) => _onWorkingChanged(index, value),
              ),
              Text(editor.working ? '근무' : '휴무'),
            ],
          ),
          if (editor.working) ...[
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<DaySessionMode>(
              segments: const [
                ButtonSegment(value: DaySessionMode.fullDay, label: Text('종일')),
                ButtonSegment(value: DaySessionMode.split, label: Text('오전/오후')),
              ],
              selected: {editor.mode},
              onSelectionChanged: (values) => _onModeChanged(index, values.first),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (editor.mode == DaySessionMode.fullDay)
              _FullDayEditor(
                state: editor,
                onStartChanged: (time) => _onFullDayChanged(index, start: time),
                onEndChanged: (time) => _onFullDayChanged(index, end: time),
              )
            else
              _SplitEditor(
                state: editor,
                onToggleMorning: (enabled) => _onSessionToggle(index, morning: enabled),
                onToggleAfternoon: (enabled) => _onSessionToggle(index, afternoon: enabled),
                onMorningStart: (time) => _onSessionTimeChanged(index, morningStart: time),
                onMorningEnd: (time) => _onSessionTimeChanged(index, morningEnd: time),
                onAfternoonStart: (time) => _onSessionTimeChanged(index, afternoonStart: time),
                onAfternoonEnd: (time) => _onSessionTimeChanged(index, afternoonEnd: time),
              ),
          ],
        ],
      ),
    );
  }

  void _onWorkingChanged(int dayIndex, bool value) {
    setState(() {
      final editor = _editorStates[dayIndex]!;
      editor.working = value;
      if (!value) {
        editor.mode = DaySessionMode.fullDay;
      } else if (editor.mode == DaySessionMode.split && !editor.hasEnabledSplitSession) {
        editor.morningEnabled = true;
      }
      _schedule = _schedule.copyWith(
        weekDays: {
          ..._schedule.weekDays,
          dayIndex: editor.toSchedule(),
        },
      );
    });
  }

  void _onModeChanged(int dayIndex, DaySessionMode mode) {
    setState(() {
      final editor = _editorStates[dayIndex]!;
      editor.mode = mode;
      if (mode == DaySessionMode.fullDay) {
        editor.ensureFullDayDefaults();
      } else {
        editor.ensureSplitDefaults();
      }
      _schedule = _schedule.copyWith(
        weekDays: {
          ..._schedule.weekDays,
          dayIndex: editor.toSchedule(),
        },
      );
    });
  }

  void _onFullDayChanged(int dayIndex, {TimeOfDay? start, TimeOfDay? end}) {
    final editor = _editorStates[dayIndex]!;
    setState(() {
      if (start != null) editor.fullDayStart = start;
      if (end != null) editor.fullDayEnd = end;
      _schedule = _schedule.copyWith(
        weekDays: {
          ..._schedule.weekDays,
          dayIndex: editor.toSchedule(),
        },
      );
    });
  }

  void _onSessionToggle(int dayIndex, {bool? morning, bool? afternoon}) {
    final editor = _editorStates[dayIndex]!;
    setState(() {
      if (morning != null) editor.morningEnabled = morning;
      if (afternoon != null) editor.afternoonEnabled = afternoon;
      if (!editor.morningEnabled && !editor.afternoonEnabled) {
        editor.morningEnabled = true;
      }
      _schedule = _schedule.copyWith(
        weekDays: {
          ..._schedule.weekDays,
          dayIndex: editor.toSchedule(),
        },
      );
    });
  }

  void _onSessionTimeChanged(
    int dayIndex, {
    TimeOfDay? morningStart,
    TimeOfDay? morningEnd,
    TimeOfDay? afternoonStart,
    TimeOfDay? afternoonEnd,
  }) {
    final editor = _editorStates[dayIndex]!;
    setState(() {
      if (morningStart != null) editor.morningStart = morningStart;
      if (morningEnd != null) editor.morningEnd = morningEnd;
      if (afternoonStart != null) editor.afternoonStart = afternoonStart;
      if (afternoonEnd != null) editor.afternoonEnd = afternoonEnd;
      _schedule = _schedule.copyWith(
        weekDays: {
          ..._schedule.weekDays,
          dayIndex: editor.toSchedule(),
        },
      );
    });
  }

  Future<void> _save() async {
    final updated = WeeklySchedule(weekDays: {
      for (final entry in _editorStates.entries) entry.key: entry.value.toSchedule(),
    });

    try {
      await _settings.saveSchedule(updated);
      if (!mounted) return;
      setState(() => _schedule = updated);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('진료 시간표가 저장되었습니다.')),
      );
      widget.onSaved?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('스케줄 저장 실패: $e')),
      );
    }
  }

  Map<int, _DayEditorState> _buildEditorStates(WeeklySchedule schedule) {
    final map = <int, _DayEditorState>{};
    for (int i = 0; i <= 6; i++) {
      map[i] = _DayEditorState.fromSchedule(schedule.weekDays[i] ?? DaySchedule.rest());
    }
    return map;
  }

  WeeklySchedule _defaultSchedule() {
    return WeeklySchedule.defaultSchedule();
  }

  String _dayName(int weekDay) {
    switch (weekDay) {
      case 1:
        return '월요일';
      case 2:
        return '화요일';
      case 3:
        return '수요일';
      case 4:
        return '목요일';
      case 5:
        return '금요일';
      case 6:
        return '토요일';
      case 7:
        return '일요일';
      default:
        return '일요일';
    }
  }
}

class _FullDayEditor extends StatelessWidget {
  const _FullDayEditor({
    required this.state,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  final _DayEditorState state;
  final ValueChanged<TimeOfDay> onStartChanged;
  final ValueChanged<TimeOfDay> onEndChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('근무 시간'),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: _TimeButton(
                label: '시작',
                time: state.fullDayStart,
                onPressed: () async {
                  final picked = await _pickTime(context, state.fullDayStart);
                  if (picked != null) onStartChanged(picked);
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _TimeButton(
                label: '종료',
                time: state.fullDayEnd,
                onPressed: () async {
                  final picked = await _pickTime(context, state.fullDayEnd);
                  if (picked != null) onEndChanged(picked);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<TimeOfDay?> _pickTime(BuildContext context, TimeOfDay initial) {
    return showTimePicker(context: context, initialTime: initial);
  }
}

class _SplitEditor extends StatelessWidget {
  const _SplitEditor({
    required this.state,
    required this.onToggleMorning,
    required this.onToggleAfternoon,
    required this.onMorningStart,
    required this.onMorningEnd,
    required this.onAfternoonStart,
    required this.onAfternoonEnd,
  });

  final _DayEditorState state;
  final ValueChanged<bool> onToggleMorning;
  final ValueChanged<bool> onToggleAfternoon;
  final ValueChanged<TimeOfDay> onMorningStart;
  final ValueChanged<TimeOfDay> onMorningEnd;
  final ValueChanged<TimeOfDay> onAfternoonStart;
  final ValueChanged<TimeOfDay> onAfternoonEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SessionRow(
          label: '오전 진료',
          enabled: state.morningEnabled,
          onToggle: onToggleMorning,
          start: state.morningStart,
          end: state.morningEnd,
          onStartPressed: () async {
            final picked = await _pickTime(context, state.morningStart);
            if (picked != null) onMorningStart(picked);
          },
          onEndPressed: () async {
            final picked = await _pickTime(context, state.morningEnd);
            if (picked != null) onMorningEnd(picked);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        _SessionRow(
          label: '오후 진료',
          enabled: state.afternoonEnabled,
          onToggle: onToggleAfternoon,
          start: state.afternoonStart,
          end: state.afternoonEnd,
          onStartPressed: () async {
            final picked = await _pickTime(context, state.afternoonStart);
            if (picked != null) onAfternoonStart(picked);
          },
          onEndPressed: () async {
            final picked = await _pickTime(context, state.afternoonEnd);
            if (picked != null) onAfternoonEnd(picked);
          },
        ),
      ],
    );
  }

  Future<TimeOfDay?> _pickTime(BuildContext context, TimeOfDay initial) {
    return showTimePicker(context: context, initialTime: initial);
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.label,
    required this.enabled,
    required this.onToggle,
    required this.start,
    required this.end,
    required this.onStartPressed,
    required this.onEndPressed,
  });

  final String label;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final TimeOfDay start;
  final TimeOfDay end;
  final Future<void> Function() onStartPressed;
  final Future<void> Function() onEndPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: enabled,
              onChanged: (value) => onToggle(value ?? false),
            ),
            Text(label),
          ],
        ),
        if (enabled)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: _TimeButton(
                    label: '시작',
                    time: start,
                    onPressed: onStartPressed,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _TimeButton(
                    label: '종료',
                    time: end,
                    onPressed: onEndPressed,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.time,
    required this.onPressed,
  });

  final String label;
  final TimeOfDay time;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final formatted = _formatTime(time);
    return OutlinedButton(
      onPressed: () => onPressed(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          const SizedBox(width: AppSpacing.xs),
          Text(formatted, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _DayEditorState {
  _DayEditorState({
    required this.working,
    required this.mode,
    required this.fullDayStart,
    required this.fullDayEnd,
    required this.morningEnabled,
    required this.morningStart,
    required this.morningEnd,
    required this.afternoonEnabled,
    required this.afternoonStart,
    required this.afternoonEnd,
  });

  bool working;
  DaySessionMode mode;
  TimeOfDay fullDayStart;
  TimeOfDay fullDayEnd;
  bool morningEnabled;
  TimeOfDay morningStart;
  TimeOfDay morningEnd;
  bool afternoonEnabled;
  TimeOfDay afternoonStart;
  TimeOfDay afternoonEnd;

  bool get hasEnabledSplitSession => morningEnabled || afternoonEnabled;

  factory _DayEditorState.fromSchedule(DaySchedule schedule) {
    const defaultMorningStart = TimeOfDay(hour: 9, minute: 0);
    const defaultMorningEnd = TimeOfDay(hour: 12, minute: 0);
    const defaultAfternoonStart = TimeOfDay(hour: 13, minute: 0);
    const defaultAfternoonEnd = TimeOfDay(hour: 18, minute: 0);

    if (!schedule.isWorkingDay || schedule.sessions.isEmpty) {
      return _DayEditorState(
        working: false,
        mode: DaySessionMode.fullDay,
        fullDayStart: const TimeOfDay(hour: 9, minute: 0),
        fullDayEnd: const TimeOfDay(hour: 18, minute: 0),
        morningEnabled: true,
        morningStart: defaultMorningStart,
        morningEnd: defaultMorningEnd,
        afternoonEnabled: true,
        afternoonStart: defaultAfternoonStart,
        afternoonEnd: defaultAfternoonEnd,
      );
    }

    final sessions = List<WorkingSession>.from(schedule.sessions)
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    final isSplit = schedule.mode == ScheduleMode.split || sessions.length > 1;

    if (!isSplit) {
      final slot = sessions.first;
      return _DayEditorState(
        working: true,
        mode: DaySessionMode.fullDay,
        fullDayStart: slot.start,
        fullDayEnd: slot.end,
        morningEnabled: true,
        morningStart: defaultMorningStart,
        morningEnd: defaultMorningEnd,
        afternoonEnabled: true,
        afternoonStart: defaultAfternoonStart,
        afternoonEnd: defaultAfternoonEnd,
      );
    }

    final morningSlot = sessions.isNotEmpty ? sessions.first : null;
    final afternoonSlot = sessions.length > 1 ? sessions[1] : null;
    final inferredMorning = morningSlot != null && morningSlot.start.hour < 12;

    return _DayEditorState(
      working: true,
      mode: DaySessionMode.split,
      fullDayStart: const TimeOfDay(hour: 9, minute: 0),
      fullDayEnd: const TimeOfDay(hour: 18, minute: 0),
      morningEnabled: inferredMorning,
      morningStart: inferredMorning ? morningSlot!.start : defaultMorningStart,
      morningEnd: inferredMorning ? morningSlot!.end : defaultMorningEnd,
      afternoonEnabled: afternoonSlot != null || !inferredMorning,
      afternoonStart: (afternoonSlot ?? morningSlot ?? WorkingSession(
        start: defaultAfternoonStart,
        end: defaultAfternoonEnd,
      )).start,
      afternoonEnd: (afternoonSlot ?? morningSlot ?? WorkingSession(
        start: defaultAfternoonStart,
        end: defaultAfternoonEnd,
      )).end,
    );
  }

  void ensureFullDayDefaults() {
    if (!working) {
      working = true;
    }
  }

  void ensureSplitDefaults() {
    if (!working) {
      working = true;
    }
    if (!hasEnabledSplitSession) {
      morningEnabled = true;
      afternoonEnabled = true;
    }
  }

  DaySchedule toSchedule() {
    if (!working) {
      return DaySchedule.rest();
    }

    if (mode == DaySessionMode.fullDay) {
      return DaySchedule.fullDay(start: fullDayStart, end: fullDayEnd);
    }

    final slots = <WorkingSession>[];
    if (morningEnabled) {
      slots.add(WorkingSession(start: morningStart, end: morningEnd));
    }
    if (afternoonEnabled) {
      slots.add(WorkingSession(start: afternoonStart, end: afternoonEnd));
    }

    if (slots.isEmpty) {
      return DaySchedule.rest();
    }

    return DaySchedule(isWorkingDay: true, sessions: slots, mode: ScheduleMode.split);
  }
}

String _formatTime(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
