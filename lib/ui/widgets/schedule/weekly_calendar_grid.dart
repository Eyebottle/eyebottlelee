import 'package:flutter/material.dart';
import '../../../models/schedule_model.dart';
import '../../style/app_colors.dart';
import '../../style/app_typography.dart';
import '../../style/app_elevation.dart';

/// 주간 캘린더 그리드 위젯
///
/// 7일의 진료 스케줄을 한눈에 보여주는 그리드 뷰입니다.
/// 각 요일을 클릭하면 상세 편집 모드로 전환됩니다.
class WeeklyCalendarGrid extends StatelessWidget {
  const WeeklyCalendarGrid({
    super.key,
    required this.schedule,
    required this.selectedDayIndex,
    required this.onDaySelected,
  });

  final WeeklySchedule schedule;
  final int? selectedDayIndex;
  final ValueChanged<int> onDaySelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 헤더
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '주간 진료 시간표',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        // 그리드
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceBorder),
            boxShadow: AppElevation.shadow1,
          ),
          child: Column(
            children: [
              // 요일 헤더
              _buildWeekdayHeader(),

              const Divider(height: 1),

              // 각 요일 카드
              for (int i = 0; i < 7; i++) _buildDayCard(i),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeader() {
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          // 요일 이름 열
          SizedBox(
            width: 60,
            child: Text(
              '요일',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // 근무 여부
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                '근무',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // 시간
          Expanded(
            flex: 3,
            child: Center(
              child: Text(
                '진료 시간',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(int dayIndex) {
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final daySchedule = schedule.weekDays[dayIndex] ?? DaySchedule.rest();
    final isSelected = selectedDayIndex == dayIndex;
    final isWorking = daySchedule.isWorkingDay;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onDaySelected(dayIndex),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryContainer
                : Colors.transparent,
            border: Border(
              bottom: dayIndex < 6
                  ? BorderSide(color: AppColors.neutral100)
                  : BorderSide.none,
            ),
          ),
          child: Row(
            children: [
              // 요일 표시
              SizedBox(
                width: 60,
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isWorking
                            ? AppColors.primary.withOpacity(0.1)
                            : AppColors.neutral200.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          weekdays[dayIndex],
                          style: AppTypography.labelLarge.copyWith(
                            color: isWorking
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 근무 여부 표시
              Expanded(
                flex: 1,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isWorking
                          ? AppColors.success.withOpacity(0.12)
                          : AppColors.neutral200.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isWorking ? '근무' : '휴무',
                      style: AppTypography.labelSmall.copyWith(
                        color: isWorking
                            ? AppColors.success
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              // 시간 표시
              Expanded(
                flex: 3,
                child: _buildTimeDisplay(daySchedule),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeDisplay(DaySchedule daySchedule) {
    if (!daySchedule.isWorkingDay || daySchedule.sessions.isEmpty) {
      return Center(
        child: Text(
          '-',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textDisabled,
          ),
        ),
      );
    }

    final sessions = daySchedule.sessions;

    if (sessions.length == 1) {
      // 종일 근무
      final session = sessions.first;
      return Center(
        child: Text(
          '${_formatTime(session.start)} - ${_formatTime(session.end)}',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontFamily: AppTypography.latinFontFamily,
          ),
        ),
      );
    } else {
      // 분할 근무 (오전·오후)
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '오전',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(sessions[0].start),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontFamily: AppTypography.latinFontFamily,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.more_vert,
              size: 16,
              color: AppColors.textDisabled,
            ),
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '오후',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sessions.length > 1
                      ? _formatTime(sessions[1].start)
                      : '-',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontFamily: AppTypography.latinFontFamily,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}