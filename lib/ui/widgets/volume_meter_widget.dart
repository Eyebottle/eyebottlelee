import 'package:flutter/material.dart';

class VolumeMeterWidget extends StatelessWidget {
  final double volumeLevel; // 0.0 ~ 1.0 범위

  const VolumeMeterWidget({
    super.key,
    required this.volumeLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            Row(
              children: [
                const Icon(Icons.graphic_eq, size: 20),
                const SizedBox(width: 8),
                Text(
                  '볼륨 레벨',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 볼륨 미터 바
            Container(
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: LinearProgressIndicator(
                  value: volumeLevel,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getVolumeColor(context, volumeLevel),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 볼륨 수치 및 상태 표시
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(volumeLevel * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  _getVolumeStatusText(volumeLevel),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _getVolumeColor(context, volumeLevel),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 볼륨 레벨에 따른 색상 반환
  Color _getVolumeColor(BuildContext context, double level) {
    if (level < 0.1) {
      return Theme.of(context).colorScheme.error; // 너무 낮음 (빨강)
    } else if (level < 0.3) {
      return Colors.orange; // 낮음 (주황)
    } else if (level < 0.8) {
      return Theme.of(context).colorScheme.primary; // 적정 (파랑)
    } else {
      return Colors.amber; // 높음 (노랑)
    }
  }

  /// 볼륨 상태 텍스트 반환
  String _getVolumeStatusText(double level) {
    if (level < 0.1) {
      return '너무 낮음';
    } else if (level < 0.3) {
      return '낮음';
    } else if (level < 0.8) {
      return '적정';
    } else {
      return '높음';
    }
  }
}