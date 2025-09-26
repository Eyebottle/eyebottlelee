import 'dart:math' as math;

import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);
    final bars = _buildBars();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.colorScheme.outlineVariant
                .withAlpha((0.4 * 255).round())),
      ),
      child: SizedBox(
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
      return const Color(0xFF34C759); // green
    } else if (value < 0.7) {
      return const Color(0xFFFFC107); // amber
    } else {
      return const Color(0xFFE53935); // red
    }
  }
}
