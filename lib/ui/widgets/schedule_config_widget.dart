import 'package:flutter/material.dart';

import '../../models/schedule_model.dart';
import '../../services/settings_service.dart';
import '../style/app_spacing.dart';
import '../style/app_colors.dart';

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
    final maxWidth = (mediaSize.width * 0.8).clamp(360.0, 540.0);
    final maxHeight = (mediaSize.height * 0.82).clamp(420.0, 640.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '진료 시간표 설정',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '요일별 근무 여부와 진료 시간을 설정하세요.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  itemCount: 7,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (_, index) => _buildDayCard(index + 1),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('저장'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outlineVariant.withAlpha(60);
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayName,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      editor.working ? '근무를 설정하세요' : '휴무일로 설정되어 있습니다',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: editor.working,
                onChanged: (value) => _onWorkingChanged(index, value),
              ),
            ],
          ),
          if (editor.working) ...[
            const SizedBox(height: 16),
            SegmentedButton<DaySessionMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: DaySessionMode.fullDay,
                  label: Text('종일'),
                ),
                ButtonSegment(
                  value: DaySessionMode.split,
                  label: Text('오전·오후'),
                ),
              ],
              selected: {editor.mode},
              onSelectionChanged: (selection) =>
                  _onModeChanged(index, selection.first),
            ),
            const SizedBox(height: 20),
            if (editor.mode == DaySessionMode.fullDay)
              _FullDayEditor(
                state: editor,
                onStartChanged: (time) => _onFullDayChanged(index, start: time),
                onEndChanged: (time) => _onFullDayChanged(index, end: time),
              )
            else
              _SplitEditor(
                state: editor,
                onToggleMorning: (enabled) =>
                    _onSessionToggle(index, morning: enabled),
                onToggleAfternoon: (enabled) =>
                    _onSessionToggle(index, afternoon: enabled),
                onMorningStart: (time) =>
                    _onSessionTimeChanged(index, morningStart: time),
                onMorningEnd: (time) =>
                    _onSessionTimeChanged(index, morningEnd: time),
                onAfternoonStart: (time) =>
                    _onSessionTimeChanged(index, afternoonStart: time),
                onAfternoonEnd: (time) =>
                    _onSessionTimeChanged(index, afternoonEnd: time),
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
      } else if (editor.mode == DaySessionMode.split &&
          !editor.hasEnabledSplitSession) {
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
      for (final entry in _editorStates.entries)
        entry.key: entry.value.toSchedule(),
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
      map[i] = _DayEditorState.fromSchedule(
          schedule.weekDays[i] ?? DaySchedule.rest());
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
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '근무 시간',
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
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
      mainAxisSize: MainAxisSize.min,
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
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Switch.adaptive(
              value: enabled,
              onChanged: (value) => onToggle(value),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        if (enabled)
          Padding(
            padding: const EdgeInsets.only(left: 4.0, top: 6.0),
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
    final textTheme = Theme.of(context).textTheme;
    return FilledButton.tonal(
      onPressed: () => onPressed(),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: textTheme.labelSmall
                  ?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            formatted,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
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
    final morningSession = (morningSlot != null && morningSlot.start.hour < 12)
        ? morningSlot
        : null;
    final morningStartTime = morningSession?.start ?? defaultMorningStart;
    final morningEndTime = morningSession?.end ?? defaultMorningEnd;
    final fallbackSession = afternoonSlot ??
        morningSession ??
        WorkingSession(
          start: defaultAfternoonStart,
          end: defaultAfternoonEnd,
        );

    return _DayEditorState(
      working: true,
      mode: DaySessionMode.split,
      fullDayStart: const TimeOfDay(hour: 9, minute: 0),
      fullDayEnd: const TimeOfDay(hour: 18, minute: 0),
      morningEnabled: morningSession != null,
      morningStart: morningStartTime,
      morningEnd: morningEndTime,
      afternoonEnabled: afternoonSlot != null || morningSession == null,
      afternoonStart: fallbackSession.start,
      afternoonEnd: fallbackSession.end,
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

    return DaySchedule(
        isWorkingDay: true, sessions: slots, mode: ScheduleMode.split);
  }
}

String _formatTime(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
