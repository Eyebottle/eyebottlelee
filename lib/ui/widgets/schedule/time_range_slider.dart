import 'package:flutter/material.dart';
import '../../../utils/time_format.dart';
import '../../style/app_colors.dart';
import '../../style/app_typography.dart';

/// 타임라인 슬라이더 시간 선택 위젯
///
/// 드래그로 시작/종료 시간을 직관적으로 조절하거나, 시간 칩을 눌러 12시간제
/// 시간 선택기(showTimePicker)로 정밀 입력할 수 있습니다. 30분 단위로 스냅됩니다.
class TimeRangeSlider extends StatefulWidget {
  const TimeRangeSlider({
    super.key,
    required this.start,
    required this.end,
    required this.onChanged,
    this.minTime = const TimeOfDay(hour: 6, minute: 0),
    this.maxTime = const TimeOfDay(hour: 23, minute: 0),
    this.snapInterval = 30,
    this.label,
  });

  final TimeOfDay start;
  final TimeOfDay end;
  final ValueChanged<TimeRange> onChanged;
  final TimeOfDay minTime;
  final TimeOfDay maxTime;
  final int snapInterval; // 분 단위 스냅
  final String? label;

  @override
  State<TimeRangeSlider> createState() => _TimeRangeSliderState();
}

class _TimeRangeSliderState extends State<TimeRangeSlider> {
  late double _startValue;
  late double _endValue;

  @override
  void initState() {
    super.initState();
    _updateValues();
  }

  @override
  void didUpdateWidget(TimeRangeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.start != widget.start || oldWidget.end != widget.end) {
      _updateValues();
    }
  }

  void _updateValues() {
    _startValue = _timeToMinutes(widget.start).toDouble();
    _endValue = _timeToMinutes(widget.end).toDouble();
  }

  int _timeToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  TimeOfDay _minutesToTime(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

  int _snapToInterval(double value) {
    final rounded = (value / widget.snapInterval).round() * widget.snapInterval;
    return rounded.clamp(
      _timeToMinutes(widget.minTime),
      _timeToMinutes(widget.maxTime),
    );
  }

  /// 시간 칩을 눌렀을 때: 12시간제 시간 선택기로 정밀 입력받는다.
  /// 결과는 30분 단위로 스냅하고 시작<종료·범위 제약을 검증해 적용한다.
  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? widget.start : widget.end,
      helpText: isStart ? '시작 시간 선택' : '종료 시간 선택',
      // 기기 설정과 무관하게 항상 오전/오후 12시간제로 표시.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked == null) return;

    final snapped = _minutesToTime(_snapToInterval(_timeToMinutes(picked).toDouble()));
    final newStart = isStart ? snapped : widget.start;
    final newEnd = isStart ? widget.end : snapped;

    // 시작 < 종료가 아니면 적용하지 않는다(잘못된 범위 방지).
    if (_timeToMinutes(newStart) >= _timeToMinutes(newEnd)) return;

    widget.onChanged(TimeRange(start: newStart, end: newEnd));
  }

  @override
  Widget build(BuildContext context) {
    final minMinutes = _timeToMinutes(widget.minTime);
    final maxMinutes = _timeToMinutes(widget.maxTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 시간 표시 (탭하면 12시간제 선택기)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTimeChip(
              _minutesToTime(_startValue.toInt()),
              AppColors.primary,
              () => _pickTime(isStart: true),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(
                Icons.arrow_forward,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ),
            _buildTimeChip(
              _minutesToTime(_endValue.toInt()),
              AppColors.primary,
              () => _pickTime(isStart: false),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // 타임라인 슬라이더
        SizedBox(
          height: 60,
          child: Stack(
            children: [
              // 배경 트랙
              Positioned(
                left: 0,
                right: 0,
                top: 28,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.neutral200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 선택된 범위 트랙
              Positioned(
                left: (_startValue - minMinutes) /
                        (maxMinutes - minMinutes) *
                        (MediaQuery.of(context).size.width - 80) +
                    20,
                right: (maxMinutes - _endValue) /
                        (maxMinutes - minMinutes) *
                        (MediaQuery.of(context).size.width - 80) +
                    20,
                top: 28,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 슬라이더
              Positioned.fill(
                child: RangeSlider(
                  values: RangeValues(_startValue, _endValue),
                  min: minMinutes.toDouble(),
                  max: maxMinutes.toDouble(),
                  divisions: (maxMinutes - minMinutes) ~/ widget.snapInterval,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.neutral200,
                  onChanged: (values) {
                    setState(() {
                      _startValue = values.start;
                      _endValue = values.end;
                    });
                  },
                  onChangeEnd: (values) {
                    final snappedStart = _snapToInterval(values.start);
                    final snappedEnd = _snapToInterval(values.end);

                    setState(() {
                      _startValue = snappedStart.toDouble();
                      _endValue = snappedEnd.toDouble();
                    });

                    widget.onChanged(TimeRange(
                      start: _minutesToTime(snappedStart),
                      end: _minutesToTime(snappedEnd),
                    ));
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // 시간 눈금 (12시간제)
        _buildTimeScale(minMinutes, maxMinutes),
      ],
    );
  }

  Widget _buildTimeChip(TimeOfDay time, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          formatHm12(time),
          style: AppTypography.headlineSmall.copyWith(
            fontSize: 24,
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeScale(int minMinutes, int maxMinutes) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (int h = minMinutes ~/ 60; h <= maxMinutes ~/ 60; h += 2)
          Text(
            formatHourLabel12(h),
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }
}

/// 시간 범위 모델
class TimeRange {
  const TimeRange({
    required this.start,
    required this.end,
  });

  final TimeOfDay start;
  final TimeOfDay end;
}
