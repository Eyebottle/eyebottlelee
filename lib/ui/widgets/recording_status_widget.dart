import 'package:flutter/material.dart';

class RecordingStatusWidget extends StatelessWidget {
  final bool isRecording;
  final DateTime? startTime;

  const RecordingStatusWidget({
    super.key,
    required this.isRecording,
    this.startTime,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isRecording
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // 녹음 상태 아이콘
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              child: Icon(
                isRecording ? Icons.mic : Icons.mic_off,
                size: 32,
                color: isRecording
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),

            // 상태 텍스트
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRecording ? '🎤 [●] 녹음 중' : '🎤 [⏸] 대기 중',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isRecording
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  if (startTime != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '시작 시간: ${_formatTime(startTime!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),

            // 녹음 상태 표시 점
            if (isRecording) _buildRecordingIndicator(context),
          ],
        ),
      ),
    );
  }

  /// 녹음 중 표시 점 (애니메이션)
  Widget _buildRecordingIndicator(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0.3, end: 1.0),
      builder: (context, value, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context)
                .colorScheme
                .error
                .withValues(alpha: value.clamp(0.0, 1.0).toDouble()),
          ),
        );
      },
      onEnd: () {
        // 애니메이션 반복을 위해 setState 호출 필요 (StatefulWidget으로 변경 시)
      },
    );
  }

  /// 시간 포맷팅
  String _formatTime(DateTime time) {
    return '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');
}
