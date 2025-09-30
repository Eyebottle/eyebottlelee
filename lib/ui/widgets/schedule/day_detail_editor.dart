import 'package:flutter/material.dart';
import '../../../models/schedule_model.dart';
import '../../style/app_colors.dart';
import '../../style/app_typography.dart';
import '../../style/app_spacing.dart';
import '../common/app_card.dart';
import 'time_range_slider.dart';

/// 요일별 상세 편집 패널
///
/// 선택된 요일의 진료 시간을 상세하게 편집할 수 있습니다.
class DayDetailEditor extends StatelessWidget {
  const DayDetailEditor({
    super.key,
    required this.dayIndex,
    required this.daySchedule,
    required this.onScheduleChanged,
  });

  final int dayIndex;
  final DaySchedule daySchedule;
  final ValueChanged<DaySchedule> onScheduleChanged;

  @override
  Widget build(BuildContext context) {
    final weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: daySchedule.isWorkingDay
                      ? AppColors.primary.withOpacity(0.12)
                      : AppColors.neutral200.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    weekdays[dayIndex][0],
                    style: AppTypography.titleLarge.copyWith(
                      color: daySchedule.isWorkingDay
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weekdays[dayIndex],
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      daySchedule.isWorkingDay ? '근무일로 설정됨' : '휴무일로 설정됨',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 근무 여부 토글
          AppCard.level1(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '근무일 설정',
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        daySchedule.isWorkingDay
                            ? '이 날은 진료를 합니다'
                            : '이 날은 휴무입니다',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: daySchedule.isWorkingDay,
                  onChanged: (value) {
                    if (value) {
                      // 근무일로 변경 - 기본 종일 근무
                      onScheduleChanged(DaySchedule.fullDay(
                        start: const TimeOfDay(hour: 9, minute: 0),
                        end: const TimeOfDay(hour: 18, minute: 0),
                      ));
                    } else {
                      // 휴무일로 변경
                      onScheduleChanged(DaySchedule.rest());
                    }
                  },
                ),
              ],
            ),
          ),

          if (daySchedule.isWorkingDay) ...[
            const SizedBox(height: 16),

            // 모드 선택 (종일 / 오전·오후)
            AppCard.level1(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '진료 방식',
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ScheduleMode>(
                    segments: const [
                      ButtonSegment(
                        value: ScheduleMode.fullDay,
                        label: Text('종일'),
                        icon: Icon(Icons.schedule, size: 18),
                      ),
                      ButtonSegment(
                        value: ScheduleMode.split,
                        label: Text('오전·오후'),
                        icon: Icon(Icons.splitscreen, size: 18),
                      ),
                    ],
                    selected: {daySchedule.mode},
                    onSelectionChanged: (selection) {
                      final mode = selection.first;
                      if (mode == ScheduleMode.fullDay) {
                        onScheduleChanged(DaySchedule.fullDay(
                          start: const TimeOfDay(hour: 9, minute: 0),
                          end: const TimeOfDay(hour: 18, minute: 0),
                        ));
                      } else {
                        onScheduleChanged(DaySchedule(
                          isWorkingDay: true,
                          mode: ScheduleMode.split,
                          sessions: [
                            WorkingSession(
                              start: const TimeOfDay(hour: 9, minute: 0),
                              end: const TimeOfDay(hour: 13, minute: 0),
                            ),
                            WorkingSession(
                              start: const TimeOfDay(hour: 14, minute: 0),
                              end: const TimeOfDay(hour: 18, minute: 0),
                            ),
                          ],
                        ));
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 시간 설정
            AppCard.level1(
              padding: const EdgeInsets.all(20),
              child: daySchedule.mode == ScheduleMode.fullDay
                  ? _buildFullDayEditor(daySchedule)
                  : _buildSplitEditor(daySchedule),
            ),
          ],

          const SizedBox(height: 80), // 하단 여백
        ],
      ),
    );
  }

  Widget _buildFullDayEditor(DaySchedule schedule) {
    final session = schedule.sessions.firstOrNull ??
        WorkingSession(
          start: const TimeOfDay(hour: 9, minute: 0),
          end: const TimeOfDay(hour: 18, minute: 0),
        );

    return TimeRangeSlider(
      label: '진료 시간',
      start: session.start,
      end: session.end,
      onChanged: (range) {
        onScheduleChanged(DaySchedule.fullDay(
          start: range.start,
          end: range.end,
        ));
      },
    );
  }

  Widget _buildSplitEditor(DaySchedule schedule) {
    final morning = schedule.sessions.length > 0
        ? schedule.sessions[0]
        : WorkingSession(
            start: const TimeOfDay(hour: 9, minute: 0),
            end: const TimeOfDay(hour: 13, minute: 0),
          );

    final afternoon = schedule.sessions.length > 1
        ? schedule.sessions[1]
        : WorkingSession(
            start: const TimeOfDay(hour: 14, minute: 0),
            end: const TimeOfDay(hour: 18, minute: 0),
          );

    return Column(
      children: [
        TimeRangeSlider(
          label: '오전 진료',
          start: morning.start,
          end: morning.end,
          maxTime: const TimeOfDay(hour: 14, minute: 0),
          onChanged: (range) {
            onScheduleChanged(DaySchedule(
              isWorkingDay: true,
              mode: ScheduleMode.split,
              sessions: [
                WorkingSession(start: range.start, end: range.end),
                afternoon,
              ],
            ));
          },
        ),
        const SizedBox(height: 24),
        TimeRangeSlider(
          label: '오후 진료',
          start: afternoon.start,
          end: afternoon.end,
          minTime: const TimeOfDay(hour: 12, minute: 0),
          onChanged: (range) {
            onScheduleChanged(DaySchedule(
              isWorkingDay: true,
              mode: ScheduleMode.split,
              sessions: [
                morning,
                WorkingSession(start: range.start, end: range.end),
              ],
            ));
          },
        ),
      ],
    );
  }
}