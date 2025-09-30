import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../style/app_colors.dart';
import '../style/app_elevation.dart';

class AnimatedVolumeMeter extends StatelessWidget {
  const AnimatedVolumeMeter({
    super.key,
    required this.history,
    this.barCount = 24,
    this.maxHeight = 96,
  });

  final List<double> history;
  final int barCount;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final bars = _buildBars();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: AppElevation.shadow1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 레벨 표시
          Row(
            children: [
              Icon(
                Icons.graphic_eq,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '볼륨 레벨',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              _buildLevelIndicator(),
            ],
          ),
          const SizedBox(height: 12),
          // 파형
          SizedBox(
            height: maxHeight,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: bars,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelIndicator() {
    final currentLevel = history.isNotEmpty ? history.last : 0.0;
    final levelText = currentLevel < 0.35
        ? '낮음'
        : currentLevel < 0.7
            ? '적정'
            : '높음';
    final levelColor = AppColors.getVolumeColor(currentLevel);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: levelColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        levelText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: levelColor,
        ),
      ),
    );
  }

  List<Widget> _buildBars() {
    final clampedHistory = history.length > barCount
        ? history.sublist(history.length - barCount)
        : List<double>.from(history);
    final padded = List<double>.filled(
      barCount - clampedHistory.length,
      0.0,
      growable: true,
    )..addAll(clampedHistory);
    final bars = <Widget>[];
    for (var i = 0; i < barCount; i++) {
      final value = padded[i].clamp(0.0, 1.0);
      final color = _colorForValue(value);
      final height = math.max(value * maxHeight, 4.0);
      bars.add(
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      );
    }
    return bars;
  }

  Color _colorForValue(double value) {
    if (value < 0.35) {
      return AppColors.volumeLow;
    } else if (value < 0.7) {
      return AppColors.volumeMedium;
    } else {
      return AppColors.volumeHigh;
    }
  }
}
