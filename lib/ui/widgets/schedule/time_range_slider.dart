import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isEditMode = false;

  // TextField controllers
  late TextEditingController _startHourController;
  late TextEditingController _startMinuteController;
  late TextEditingController _endHourController;
  late TextEditingController _endMinuteController;

  @override
  void initState() {
    super.initState();
    _startHourController = TextEditingController();
    _startMinuteController = TextEditingController();
    _endHourController = TextEditingController();
    _endMinuteController = TextEditingController();
    _updateValues();
    _updateTextFields();
  }

  @override
  void didUpdateWidget(TimeRangeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.start != widget.start || oldWidget.end != widget.end) {
      _updateValues();
      _updateTextFields();
    }
  }

  @override
  void dispose() {
    _startHourController.dispose();
    _startMinuteController.dispose();
    _endHourController.dispose();
    _endMinuteController.dispose();
    super.dispose();
  }

  void _updateValues() {
    _startValue = _timeToMinutes(widget.start).toDouble();
    _endValue = _timeToMinutes(widget.end).toDouble();
  }

  void _updateTextFields() {
    _startHourController.text = widget.start.hour.toString().padLeft(2, '0');
    _startMinuteController.text =
        widget.start.minute.toString().padLeft(2, '0');
    _endHourController.text = widget.end.hour.toString().padLeft(2, '0');
    _endMinuteController.text = widget.end.minute.toString().padLeft(2, '0');
  }

  void _applyTextFieldChanges() {
    final startHour = int.tryParse(_startHourController.text)?.clamp(
          widget.minTime.hour,
          widget.maxTime.hour,
        ) ??
        widget.start.hour;
    final startMinute =
        int.tryParse(_startMinuteController.text)?.clamp(0, 59) ??
            widget.start.minute;
    final endHour = int.tryParse(_endHourController.text)?.clamp(
          widget.minTime.hour,
          widget.maxTime.hour,
        ) ??
        widget.end.hour;
    final endMinute = int.tryParse(_endMinuteController.text)?.clamp(0, 59) ??
        widget.end.minute;

    // 30분 단위로 스냅
    final snappedStartMinute = (startMinute / 30).round() * 30;
    final snappedEndMinute = (endMinute / 30).round() * 30;

    final newStart =
        TimeOfDay(hour: startHour, minute: snappedStartMinute % 60);
    final newEnd = TimeOfDay(hour: endHour, minute: snappedEndMinute % 60);

    // 유효성 검증: 시작 < 종료
    final startMinutes = _timeToMinutes(newStart);
    final endMinutes = _timeToMinutes(newEnd);

    if (startMinutes < endMinutes) {
      widget.onChanged(TimeRange(start: newStart, end: newEnd));
    } else {
      // 잘못된 입력 시 원래대로 복원
      _updateTextFields();
    }
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTimeChip(
              _minutesToTime(_startValue.toInt()),
              AppColors.primary,
              _startHourController,
              _startMinuteController,
              isStart: true,
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
              _endHourController,
              _endMinuteController,
              isStart: false,
            ),
            // 편집 모드일 때만 확인 버튼 표시
            if (_isEditMode) ...[
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 24,
                ),
                onPressed: () {
                  setState(() {
                    _applyTextFieldChanges();
                    _isEditMode = false;
                  });
                },
                tooltip: '확인',
              ),
            ],
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

  Widget _buildTimeChip(
    TimeOfDay time,
    Color color,
    TextEditingController hourController,
    TextEditingController minuteController, {
    required bool isStart,
  }) {
    return InkWell(
      onTap: _isEditMode
          ? null
          : () {
              setState(() {
                _isEditMode = true;
              });
            },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isEditMode ? color : color.withOpacity(0.3),
            width: _isEditMode ? 2 : 1,
          ),
        ),
        child: _isEditMode
            ? _buildTimeInput(hourController, minuteController, color)
            : Text(
                _formatTime(time),
                style: AppTypography.headlineSmall.copyWith(
                  fontSize: 28,
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontFamily: AppTypography.latinFontFamily,
                ),
              ),
      ),
    );
  }

  Widget _buildTimeInput(
    TextEditingController hourController,
    TextEditingController minuteController,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 시간 입력
        SizedBox(
          width: 42,
          height: 40,
          child: TextField(
            controller: hourController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 2,
            style: AppTypography.headlineSmall.copyWith(
              fontSize: 24,
              color: color,
              fontWeight: FontWeight.w800,
              fontFamily: AppTypography.latinFontFamily,
            ),
            decoration: InputDecoration(
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color, width: 2),
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _HourInputFormatter(
                widget.minTime.hour,
                widget.maxTime.hour,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            ':',
            style: AppTypography.headlineSmall.copyWith(
              fontSize: 24,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        // 분 입력
        SizedBox(
          width: 42,
          height: 40,
          child: TextField(
            controller: minuteController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 2,
            style: AppTypography.headlineSmall.copyWith(
              fontSize: 24,
              color: color,
              fontWeight: FontWeight.w800,
              fontFamily: AppTypography.latinFontFamily,
            ),
            decoration: InputDecoration(
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color, width: 2),
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _MinuteInputFormatter(),
            ],
          ),
        ),
      ],
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

/// 시간 입력 포맷터 (0-23 범위 제한)
class _HourInputFormatter extends TextInputFormatter {
  _HourInputFormatter(this.minHour, this.maxHour);

  final int minHour;
  final int maxHour;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final value = int.tryParse(newValue.text);
    if (value == null) {
      return oldValue;
    }

    // 첫 자리가 3 이상이면 차단 (최대 23)
    if (newValue.text.length == 1 && value > 2) {
      return oldValue;
    }

    // 두 자리 입력 시 범위 체크
    if (newValue.text.length == 2 && (value < minHour || value > maxHour)) {
      return oldValue;
    }

    return newValue;
  }
}

/// 분 입력 포맷터 (0-59 범위 제한)
class _MinuteInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final value = int.tryParse(newValue.text);
    if (value == null) {
      return oldValue;
    }

    // 첫 자리가 6 이상이면 차단 (최대 59)
    if (newValue.text.length == 1 && value > 5) {
      return oldValue;
    }

    // 두 자리 입력 시 0-59 범위 체크
    if (newValue.text.length == 2 && value > 59) {
      return oldValue;
    }

    return newValue;
  }
}
