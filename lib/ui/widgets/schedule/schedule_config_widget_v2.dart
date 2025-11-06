import 'package:flutter/material.dart';
import '../../../models/schedule_model.dart';
import '../../../services/settings_service.dart';
import '../../style/app_colors.dart';
import '../../style/app_typography.dart';
import '../../style/app_elevation.dart';
import '../common/app_button.dart';
import 'weekly_calendar_grid.dart';
import 'day_detail_editor.dart';
import 'schedule_templates.dart';

/// 진료 시간표 설정 위젯 (V2 - 개선된 버전)
///
/// 좌측에 주간 그리드, 우측에 상세 편집 패널을 배치한 개선된 UI입니다.
/// 템플릿 기능과 타임라인 슬라이더로 사용성이 크게 향상되었습니다.
class ScheduleConfigWidgetV2 extends StatefulWidget {
  const ScheduleConfigWidgetV2({super.key, this.onSaved});

  final VoidCallback? onSaved;

  @override
  State<ScheduleConfigWidgetV2> createState() => _ScheduleConfigWidgetV2State();
}

class _ScheduleConfigWidgetV2State extends State<ScheduleConfigWidgetV2> {
  final SettingsService _settings = SettingsService();
  late WeeklySchedule _schedule;
  int? _selectedDayIndex;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final saved = await _settings.loadSchedule();
    setState(() {
      _schedule = saved ?? WeeklySchedule.defaultSchedule();
      _selectedDayIndex = 1; // 월요일 기본 선택 (0=일요일)
      _isLoading = false;
    });
  }

  void _updateDaySchedule(int dayIndex, DaySchedule daySchedule) {
    setState(() {
      _schedule = _schedule.copyWith(
        weekDays: {
          ..._schedule.weekDays,
          dayIndex: daySchedule,
        },
      );
    });
  }

  Future<void> _applyTemplate() async {
    final template = await ScheduleTemplateSelector.show(context);
    if (template != null) {
      setState(() {
        _schedule = template.schedule;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${template.name}" 템플릿이 적용되었습니다')),
      );
    }
  }

  Future<void> _save() async {
    try {
      await _settings.saveSchedule(_schedule);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('진료 시간표가 저장되었습니다')),
      );
      widget.onSaved?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.of(context).size;
    final isWideScreen = mediaSize.width > 1000;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isWideScreen ? 40 : 24,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isWideScreen ? 1200 : 900,
          maxHeight: mediaSize.height * 0.9,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 헤더
            _buildHeader(),

            const Divider(height: 1),

            // 메인 콘텐츠
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : isWideScreen
                      ? _buildWideLayout()
                      : _buildNarrowLayout(),
            ),

            const Divider(height: 1),

            // 하단 액션 바
            _buildActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.calendar_month, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '진료 시간표 설정',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '요일별 진료 시간을 설정하세요',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
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
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 좌측: 주간 그리드
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border(
                right: BorderSide(color: AppColors.surfaceBorder),
              ),
            ),
            child: WeeklyCalendarGrid(
              schedule: _schedule,
              selectedDayIndex: _selectedDayIndex,
              onDaySelected: (index) {
                setState(() => _selectedDayIndex = index);
              },
            ),
          ),
        ),

        // 우측: 상세 편집
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.all(24),
            child: _selectedDayIndex != null
                ? DayDetailEditor(
                    dayIndex: _selectedDayIndex!,
                    daySchedule: _schedule.weekDays[_selectedDayIndex!] ??
                        DaySchedule.rest(),
                    onScheduleChanged: (daySchedule) {
                      _updateDaySchedule(_selectedDayIndex!, daySchedule);
                    },
                  )
                : Center(
                    child: Text(
                      '요일을 선택하세요',
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WeeklyCalendarGrid(
            schedule: _schedule,
            selectedDayIndex: _selectedDayIndex,
            onDaySelected: (index) {
              setState(() => _selectedDayIndex = index);
            },
          ),
          if (_selectedDayIndex != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                ),
              ),
              child: DayDetailEditor(
                dayIndex: _selectedDayIndex!,
                daySchedule: _schedule.weekDays[_selectedDayIndex!] ??
                    DaySchedule.rest(),
                onScheduleChanged: (daySchedule) {
                  _updateDaySchedule(_selectedDayIndex!, daySchedule);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          AppButton.secondary(
            onPressed: _applyTemplate,
            icon: Icons.category,
            child: const Text('빠른 설정'),
          ),
          const Spacer(),
          AppButton.text(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          const SizedBox(width: 12),
          AppButton.primary(
            onPressed: _save,
            icon: Icons.check,
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}
