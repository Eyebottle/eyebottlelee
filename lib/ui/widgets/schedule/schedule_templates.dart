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

  // ── 요일 인덱스 규약: 0=일, 1=월, 2=화, 3=수, 4=목, 5=금, 6=토 ──
  // (schedule_model.weekDays / schedule_service 크론과 동일. 과거 템플릿이 0=월로
  //  착각해 "금요일 휴무·일요일 근무"로 어긋났던 버그를 이 헬퍼로 바로잡는다.)

  /// 월~금(1~5)에 [build]로 만든 근무일을 넣고, 일(0)·토(6)는 휴무로 둔 주간 맵.
  /// build를 요일마다 새로 호출해 세션 리스트를 공유하지 않는다.
  static Map<int, DaySchedule> _mondayToFriday(DaySchedule Function() build) => {
        0: DaySchedule.rest(),
        for (int day = 1; day <= 5; day++) day: build(),
        6: DaySchedule.rest(),
      };

  static DaySchedule _fullDay(int startH, int endH) => DaySchedule.fullDay(
        start: TimeOfDay(hour: startH, minute: 0),
        end: TimeOfDay(hour: endH, minute: 0),
      );

  /// 오전/오후로 나뉜 근무일 (점심시간은 두 구간 사이로 빠진다).
  static DaySchedule _split(
          int mStartH, int mEndH, int aStartH, int aEndH) =>
      DaySchedule(
        isWorkingDay: true,
        mode: ScheduleMode.split,
        sessions: [
          WorkingSession(
            start: TimeOfDay(hour: mStartH, minute: 0),
            end: TimeOfDay(hour: mEndH, minute: 0),
          ),
          WorkingSession(
            start: TimeOfDay(hour: aStartH, minute: 0),
            end: TimeOfDay(hour: aEndH, minute: 0),
          ),
        ],
      );

  /// 평일만 근무 (월~금 09:00-13:00 / 14:00-18:00, 점심 13-14)
  static ScheduleTemplate get weekdaysOnly => ScheduleTemplate(
        name: '평일만 근무',
        description: '월~금 09:00-13:00, 14:00-18:00',
        icon: Icons.business_center,
        schedule: WeeklySchedule(
          weekDays: _mondayToFriday(() => _split(9, 13, 14, 18)),
        ),
      );

  /// 평일 + 토요일 반일 (월~금 점심분리, 토 오전 반일)
  static ScheduleTemplate get weekdaysWithSaturday => ScheduleTemplate(
        name: '평일 + 토요일 반일',
        description: '월~금 09:00-18:00(점심 13-14), 토 09:00-13:00',
        icon: Icons.weekend,
        schedule: WeeklySchedule(
          weekDays: {
            ..._mondayToFriday(() => _split(9, 13, 14, 18)),
            6: _fullDay(9, 13), // 토요일 반일 (일요일은 휴무 유지)
          },
        ),
      );

  /// 반나절 진료 (월~금 오전만 09:00-13:00)
  static ScheduleTemplate get halfDay => ScheduleTemplate(
        name: '반나절 진료',
        description: '월~금 09:00-13:00 (오전만)',
        icon: Icons.wb_sunny_outlined,
        schedule: WeeklySchedule(
          weekDays: _mondayToFriday(() => _fullDay(9, 13)),
        ),
      );

  /// 종일 연속 (월~금 09:00-18:00, 점심시간도 끊지 않고 녹음)
  static ScheduleTemplate get continuousFullDay => ScheduleTemplate(
        name: '종일 연속',
        description: '월~금 09:00-18:00 (점심시간도 녹음)',
        icon: Icons.timelapse,
        schedule: WeeklySchedule(
          weekDays: _mondayToFriday(() => _fullDay(9, 18)),
        ),
      );

  /// 모든 템플릿 목록 (흔한 순서)
  static List<ScheduleTemplate> get all => [
        weekdaysOnly,
        weekdaysWithSaturday,
        halfDay,
        continuousFullDay,
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
