import 'package:flutter/material.dart';
import '../../style/app_colors.dart';
import '../../style/app_typography.dart';

/// 타임라인 슬라이더 시간 선택 위젯
///
/// 드래그로 시작/종료 시간을 직관적으로 조절할 수 있습니다.
/// 30분 단위로 스냅되며, 시각적으로 시간 범위를 확인할 수 있습니다.
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

  int _timeToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  TimeOfDay _minutesToTime(int minutes) {
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  int _snapToInterval(double value) {
    final rounded = (value / widget.snapInterval).round() * widget.snapInterval;
    return rounded.clamp(
      _timeToMinutes(widget.minTime),
      _timeToMinutes(widget.maxTime),
    );
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

        // 시간 표시
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildTimeChip(
              '시작',
              _formatTime(_minutesToTime(_startValue.toInt())),
              AppColors.primary,
            ),
            Icon(
              Icons.arrow_forward,
              size: 20,
              color: AppColors.textSecondary,
            ),
            _buildTimeChip(
              '종료',
              _formatTime(_minutesToTime(_endValue.toInt())),
              AppColors.primary,
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

        // 시간 눈금
        _buildTimeScale(minMinutes, maxMinutes),
      ],
    );
  }

  Widget _buildTimeChip(String label, String time, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            time,
            style: AppTypography.titleMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontFamily: AppTypography.latinFontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeScale(int minMinutes, int maxMinutes) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (int h = minMinutes ~/ 60; h <= maxMinutes ~/ 60; h += 2)
          Text(
            '${h.toString().padLeft(2, '0')}:00',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontFamily: AppTypography.latinFontFamily,
            ),
          ),
      ],
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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