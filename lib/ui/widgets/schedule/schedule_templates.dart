import 'package:flutter/material.dart';
import '../../../models/schedule_model.dart';
import '../../style/app_colors.dart';
import '../../style/app_typography.dart';

/// 진료 시간표 템플릿
///
/// 자주 사용하는 스케줄 패턴을 빠르게 적용할 수 있습니다.
class ScheduleTemplate {
  const ScheduleTemplate({
    required this.name,
    required this.description,
    required this.icon,
    required this.schedule,
  });

  final String name;
  final String description;
  final IconData icon;
  final WeeklySchedule schedule;

  /// 평일만 근무 (월~금 09:00-18:00)
  static ScheduleTemplate get weekdaysOnly => ScheduleTemplate(
        name: '평일만 근무',
        description: '월~금 09:00-18:00',
        icon: Icons.business_center,
        schedule: WeeklySchedule(weekDays: {
          0: DaySchedule.fullDay(
            start: const TimeOfDay(hour: 9, minute: 0),
            end: const TimeOfDay(hour: 18, minute: 0),
          ),
          1: DaySchedule.fullDay(
            start: const TimeOfDay(hour: 9, minute: 0),
            end: const TimeOfDay(hour: 18, minute: 0),
          ),
          2: DaySchedule.fullDay(
            start: const TimeOfDay(hour: 9, minute: 0),
            end: const TimeOfDay(hour: 18, minute: 0),
          ),
          3: DaySchedule.fullDay(
            start: const TimeOfDay(hour: 9, minute: 0),
            end: const TimeOfDay(hour: 18, minute: 0),
          ),
          4: DaySchedule.fullDay(
            start: const TimeOfDay(hour: 9, minute: 0),
            end: const TimeOfDay(hour: 18, minute: 0),
          ),
          5: DaySchedule.rest(),
          6: DaySchedule.rest(),
        }),
      );

  /// 반나절 진료 (월~금 09:00-13:00)
  static ScheduleTemplate get halfDay => ScheduleTemplate(
        name: '반나절 진료',
        description: '월~금 09:00-13:00',
        icon: Icons.wb_sunny_outlined,
        schedule: WeeklySchedule(weekDays: {
          0: DaySchedule.fullDay(
            start: const TimeOfDay(hour: 9, minute: 0),
            end: const TimeOfDay(hour: 13, minute: 0),
          ),
          1: DaySchedule.fullDay(
            start: const TimeOfDay(hour: 9, minute: 0),
            end: const TimeOfDay(hour: 13, minute: 0),
          ),
          2: DaySchedule.fullDay(
            start: const TimeOfDay(hour: 9, minute: 0),
            end: const TimeOfDay(hour: 13, minute: 0),
          ),
          3: DaySchedule.fullDay(
            start: const TimeOfDay(hour: 9, minute: 0),
            end: const TimeOfDay(hour: 13, minute: 0),
          ),
          4: DaySchedule.fullDay(
            start: const TimeOfDay(hour: 9, minute: 0),
            end: const TimeOfDay(hour: 13, minute: 0),
          ),
          5: DaySchedule.rest(),
          6: DaySchedule.rest(),
        }),
      );

  /// 오전·오후 분리 (월~금 09:00-13:00, 14:00-18:00)
  static ScheduleTemplate get splitShift => ScheduleTemplate(
        name: '오전·오후 분리',
        description: '월~금 09:00-13:00, 14:00-18:00',
        icon: Icons.schedule,
        schedule: WeeklySchedule(weekDays: {
          for (int i = 0; i < 5; i++)
            i: DaySchedule(
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
            ),
          5: DaySchedule.rest(),
          6: DaySchedule.rest(),
        }),
      );

  /// 토요일 반일 (월~금 종일, 토 오전만)
  static ScheduleTemplate get saturdayHalf => ScheduleTemplate(
        name: '토요일 반일',
        description: '월~금 종일, 토 09:00-13:00',
        icon: Icons.weekend,
        schedule: WeeklySchedule(weekDays: {
          0: DaySchedule.fullDay(
            start: const TimeOfDay(hour: 9, minute: 0),
            end: const TimeOfDay(hour: 18, minute: 0),
          ),
          1: DaySchedule.fullDay(
            start: const TimeOfDay(hour: 9, minute: 0),
            end: const TimeOfDay(hour: 18, minute: 0),
          ),
          2: DaySchedule.fullDay(
            start: const TimeOfDay(hour: 9, minute: 0),
            end: const TimeOfDay(hour: 18, minute: 0),
          ),
          3: DaySchedule.fullDay(
            start: const TimeOfDay(hour: 9, minute: 0),
            end: const TimeOfDay(hour: 18, minute: 0),
          ),
          4: DaySchedule.fullDay(
            start: const TimeOfDay(hour: 9, minute: 0),
            end: const TimeOfDay(hour: 18, minute: 0),
          ),
          5: DaySchedule.fullDay(
            start: const TimeOfDay(hour: 9, minute: 0),
            end: const TimeOfDay(hour: 13, minute: 0),
          ),
          6: DaySchedule.rest(),
        }),
      );

  /// 모든 템플릿 목록
  static List<ScheduleTemplate> get all => [
        weekdaysOnly,
        halfDay,
        splitShift,
        saturdayHalf,
      ];
}

/// 템플릿 선택 다이얼로그
class ScheduleTemplateSelector extends StatelessWidget {
  const ScheduleTemplateSelector({
    super.key,
    required this.onTemplateSelected,
  });

  final ValueChanged<ScheduleTemplate> onTemplateSelected;

  static Future<ScheduleTemplate?> show(BuildContext context) {
    return showDialog<ScheduleTemplate>(
      context: context,
      builder: (context) => ScheduleTemplateSelector(
        onTemplateSelected: (template) {
          Navigator.of(context).pop(template);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '빠른 설정',
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '자주 사용하는 스케줄 패턴을 선택하세요',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 템플릿 목록
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: ScheduleTemplate.all.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final template = ScheduleTemplate.all[index];
                  return _TemplateCard(
                    template: template,
                    onTap: () => onTemplateSelected(template),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.onTap,
  });

  final ScheduleTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Row(
            children: [
              // 아이콘
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  template.icon,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),

              const SizedBox(width: 16),

              // 텍스트
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      template.description,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // 화살표
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
