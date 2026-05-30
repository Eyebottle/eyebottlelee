part of 'main_screen.dart';

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({
    required this.isRecording,
    required this.todayRecordingTime,
    required this.plannedSessions,
    required this.volumeLevel,
    required this.volumeHistory,
    required this.lastDiagnostic,
    required this.diagnosticInProgress,
    required this.onRunDiagnostic,
    required this.onShowDiagnosticInfo,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onSyncSchedule,
    required this.recordingShowcaseKey,
    required this.diagnosticShowcaseKey,
    required this.scheduleShowcaseKey,
    required this.trayShowcaseKey,
  });

  final bool isRecording;
  final String todayRecordingTime;
  final List<String> plannedSessions;
  final double volumeLevel;
  final List<double> volumeHistory;
  final MicDiagnosticResult? lastDiagnostic;
  final bool diagnosticInProgress;
  final Future<void> Function() onRunDiagnostic;
  final void Function() onShowDiagnosticInfo;
  final Future<void> Function() onStartRecording;
  final Future<void> Function() onStopRecording;
  final Future<void> Function() onSyncSchedule;
  final GlobalKey recordingShowcaseKey;
  final GlobalKey diagnosticShowcaseKey;
  final GlobalKey scheduleShowcaseKey;
  final GlobalKey trayShowcaseKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 900;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 2단 그리드 레이아웃 (와이드 스크린) 또는 수직 레이아웃 (좁은 화면)
              if (isWideScreen)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 좌측: 녹음 상태 카드 (60%)
                    Expanded(
                      flex: 60,
                      child: Showcase(
                        key: recordingShowcaseKey,
                        description:
                            '녹음 상태 카드에서 현재 녹음 여부를 확인하고 수동으로 시작/중지할 수 있습니다.',
                        child: _buildRecordingCard(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 우측: 마이크 진단 간소화 카드 (40%)
                    Expanded(
                      flex: 40,
                      child: Showcase(
                        key: diagnosticShowcaseKey,
                        description:
                            '앱 시작 시 마이크 입력 레벨을 자동으로 점검합니다. 정상 기준은 RMS 0.04 이상이며, 문제 발생 시 힌트를 확인하세요.',
                        child: _buildDiagnosticCardCompact(context),
                      ),
                    ),
                  ],
                )
              else
                // 좁은 화면: 기존 수직 레이아웃
                Column(
                  children: [
                    Showcase(
                      key: recordingShowcaseKey,
                      description:
                          '녹음 상태 카드에서 현재 녹음 여부를 확인하고 수동으로 시작/중지할 수 있습니다.',
                      child: _buildRecordingCard(context),
                    ),
                    const SizedBox(height: 16),
                    Showcase(
                      key: diagnosticShowcaseKey,
                      description:
                          '앱 시작 시 마이크 입력 레벨을 자동으로 점검합니다. 정상 기준은 RMS 0.04 이상이며, 문제 발생 시 힌트를 확인하세요.',
                      child: _buildDiagnosticCard(context),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Showcase(
                key: trayShowcaseKey,
                description:
                    '창을 닫으면 앱은 트레이에서 계속 실행됩니다. 좌/더블클릭으로 창을 복원하고 우클릭 메뉴로 기능을 제어하세요.',
                child: _buildTrayInfoBanner(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiagnosticInfoButton({
    required BuildContext context,
    required MicDiagnosticStatus? status,
    required VoidCallback onPressed,
  }) {
    // 에러/경고 상태 확인
    final bool hasIssue = status == MicDiagnosticStatus.failure ||
        status == MicDiagnosticStatus.noSignal ||
        status == MicDiagnosticStatus.lowInput ||
        status == MicDiagnosticStatus.permissionDenied ||
        status == MicDiagnosticStatus.noInputDevice;

    if (hasIssue) {
      // 에러 상태: 경고 스타일 버튼
      return FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B6B), // 경고 빨간색
          foregroundColor: Colors.white,
        ),
        icon: const Icon(Icons.error_outline, size: 18),
        label: const Text(
          '📋 에러 로그 확인',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      );
    } else {
      // 정상 상태: 일반 OutlinedButton
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.bug_report, size: 18),
        label: const Text(
          '진단 정보',
          style: TextStyle(fontSize: 14),
        ),
      );
    }
  }

  Widget _buildDiagnosticCardCompact(BuildContext context) {
    final theme = Theme.of(context);
    final diagnostic = lastDiagnostic;
    final status = diagnostic?.status;

    final visuals = _diagnosticVisuals(status);
    final primaryMessage = _diagnosticPrimaryMessage(status);
    final signalDb = diagnostic?.peakDb;
    final levelPercent =
        signalDb == null ? null : ((signalDb + 60) / 60).clamp(0.0, 1.0);
    final signalText =
        signalDb == null ? null : '${signalDb.toStringAsFixed(1)} dBFS';
    final lastTimeText =
        diagnostic == null ? '미점검' : _formatShortDateTime(diagnostic.timestamp);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더
          Row(
            children: [
              Icon(
                Icons.mic,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '마이크 진단',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF101C22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 상태 뱃지
          _StatusBadge(
            color: visuals.color,
            icon: visuals.icon,
            label: visuals.label,
          ),
          const SizedBox(height: 12),

          // 상태 메시지
          Text(
            primaryMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: visuals.color,
            ),
          ),
          const SizedBox(height: 16),

          // 레벨 바
          if (levelPercent != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F6F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '평균 레벨',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        signalText ?? '- dBFS',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: visuals.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: levelPercent,
                      backgroundColor: const Color(0xFFE0E7EC),
                      color: visuals.color,
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 마지막 점검 시간
          Text(
            '최근 점검: $lastTimeText',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // 진단 버튼
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 40,
                child: FilledButton.icon(
                  onPressed: diagnosticInProgress ? null : onRunDiagnostic,
                  icon: diagnosticInProgress
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(
                    diagnosticInProgress ? '점검 중…' : '다시 점검',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: _buildDiagnosticInfoButton(
                  context: context,
                  status: status,
                  onPressed: onShowDiagnosticInfo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticCard(BuildContext context) {
    final theme = Theme.of(context);
    final diagnostic = lastDiagnostic;
    final status = diagnostic?.status;

    final visuals = _diagnosticVisuals(status);
    final primaryMessage = _diagnosticPrimaryMessage(status);
    final detailMessage = _diagnosticDetailMessage(status, diagnostic?.message);
    final hints = _diagnosticHints(status, diagnostic?.hints);
    final signalDb = diagnostic?.peakDb;
    final ambientDb = diagnostic?.ambientDb;
    final snrDb = diagnostic?.snrDb;
    final levelPercent =
        signalDb == null ? null : ((signalDb + 60) / 60).clamp(0.0, 1.0);
    final signalText =
        signalDb == null ? null : '${signalDb.toStringAsFixed(1)} dBFS';
    final snrText = snrDb == null ? null : '${snrDb.toStringAsFixed(1)} dB';
    final lastTimeText = diagnostic == null
        ? '최근 점검 기록 없음'
        : _formatShortDateTime(diagnostic.timestamp);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusBadge(
                color: visuals.color,
                icon: visuals.icon,
                label: visuals.label,
              ),
              const Spacer(),
              Text(
                lastTimeText,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            primaryMessage,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: visuals.color,
            ),
          ),
          if (detailMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              detailMessage,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (levelPercent != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F6F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    '평균 레벨',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: levelPercent,
                        backgroundColor: const Color(0xFFE0E7EC),
                        color: visuals.color,
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    signalText ?? '- dBFS',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: visuals.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (ambientDb != null || snrText != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (ambientDb != null)
                    Text(
                      '실내 소음 ${ambientDb.toStringAsFixed(1)} dBFS',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (ambientDb != null && snrText != null)
                    const SizedBox(width: 12),
                  if (snrText != null)
                    Text(
                      'SNR $snrText',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ],
          ],
          if (hints.isNotEmpty) ...[
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '빠른 해결 방법',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                ...hints.map(
                  (hint) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle,
                            size: 14, color: visuals.color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            hint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 38,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: diagnosticInProgress ? null : onRunDiagnostic,
              icon: diagnosticInProgress
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Icon(Icons.refresh),
              label: Text(diagnosticInProgress ? '점검 중…' : '다시 점검'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrayInfoBanner(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F7ABF).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0F7ABF).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.system_update_tv,
              color: Color(0xFF0F7ABF), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '창을 닫으면 트레이에서 계속 실행됩니다. 트레이 아이콘으로 복원하거나 우클릭 메뉴로 기능을 제어할 수 있어요.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF0F7ABF),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _DiagnosticVisuals _diagnosticVisuals(MicDiagnosticStatus? status) {
    return switch (status) {
      MicDiagnosticStatus.ok => _DiagnosticVisuals(
          label: '정상',
          color: const Color(0xFF2E7D32),
          icon: Icons.check_circle),
      MicDiagnosticStatus.lowInput => _DiagnosticVisuals(
          label: '입력이 약함', color: const Color(0xFFFFA000), icon: Icons.hearing),
      MicDiagnosticStatus.noSignal => _DiagnosticVisuals(
          label: '신호 없음', color: const Color(0xFFD32F2F), icon: Icons.mic_off),
      MicDiagnosticStatus.permissionDenied => _DiagnosticVisuals(
          label: '권한 필요', color: const Color(0xFFD32F2F), icon: Icons.lock),
      MicDiagnosticStatus.noInputDevice => _DiagnosticVisuals(
          label: '장치 없음',
          color: const Color(0xFFD32F2F),
          icon: Icons.headset_off),
      MicDiagnosticStatus.recorderBusy => _DiagnosticVisuals(
          label: '녹음 중',
          color: const Color(0xFFFF7043),
          icon: Icons.pause_circle),
      MicDiagnosticStatus.failure => _DiagnosticVisuals(
          label: '점검 실패', color: const Color(0xFFD32F2F), icon: Icons.error),
      null => _DiagnosticVisuals(
          label: '점검 대기', color: const Color(0xFF546E7A), icon: Icons.mic),
    };
  }

  String _diagnosticPrimaryMessage(MicDiagnosticStatus? status) {
    return switch (status) {
      MicDiagnosticStatus.ok => '마이크가 정상으로 동작 중입니다.',
      MicDiagnosticStatus.lowInput => '마이크 입력이 거의 감지되지 않습니다.',
      MicDiagnosticStatus.noSignal => '마이크 신호가 전혀 감지되지 않습니다.',
      MicDiagnosticStatus.permissionDenied => '마이크 권한이 꺼져 있어요.',
      MicDiagnosticStatus.noInputDevice => '사용 가능한 마이크가 연결되지 않았어요.',
      MicDiagnosticStatus.recorderBusy => '녹음이 진행 중이라 점검을 잠시 중단했어요.',
      MicDiagnosticStatus.failure => '점검을 완료하지 못했습니다.',
      null => '아직 점검 결과가 없습니다.',
    };
  }

  String? _diagnosticDetailMessage(
    MicDiagnosticStatus? status,
    String? originalMessage,
  ) {
    return switch (status) {
      MicDiagnosticStatus.ok => '필요 시 "다시 점검"으로 상태를 재확인할 수 있어요.',
      MicDiagnosticStatus.lowInput => '마이크 위치나 입력 볼륨을 조정한 뒤 다시 점검해 주세요.',
      MicDiagnosticStatus.noSignal => '마이크가 PC에 제대로 연결되어 있는지 확인해 주세요.',
      MicDiagnosticStatus.permissionDenied =>
        'Windows 설정 > 개인정보 보호 > 마이크에서 권한을 허용해주세요.',
      MicDiagnosticStatus.noInputDevice =>
        'USB/블루투스 연결을 확인하고 기본 입력 장치를 선택해 주세요.',
      MicDiagnosticStatus.recorderBusy =>
        '녹음이 끝난 뒤 다시 점검을 실행하면 정확한 상태를 볼 수 있습니다.',
      MicDiagnosticStatus.failure => originalMessage,
      null => '창이 열리면 자동으로 마이크 상태를 점검합니다.',
    };
  }

  List<String> _diagnosticHints(
    MicDiagnosticStatus? status,
    List<String>? rawHints,
  ) {
    if (rawHints != null && rawHints.isNotEmpty) {
      return rawHints.take(2).toList();
    }

    return switch (status) {
      MicDiagnosticStatus.lowInput => [
          '마이크와의 거리를 한 뼘 안쪽으로 조정하세요.',
          'Windows 입력 볼륨을 70% 이상으로 맞춰 주세요.'
        ],
      MicDiagnosticStatus.noSignal => [
          '마이크 케이블이 PC에 제대로 꽂혀 있는지 확인하세요.',
          'USB 마이크라면 다른 포트에 연결해보세요.'
        ],
      MicDiagnosticStatus.permissionDenied => [
          'Windows 설정 > 개인정보 보호 > 마이크에서 권한을 허용하세요.',
          '앱 목록에서 "아이보틀 진료 녹음"을 켭니다.'
        ],
      MicDiagnosticStatus.noInputDevice => [
          'USB·블루투스 케이블 연결을 확인하세요.',
          'Windows 소리 설정에서 기본 입력 장치를 선택하세요.'
        ],
      MicDiagnosticStatus.failure => [
          '앱을 재실행한 뒤 다시 점검을 시도해 보세요.',
          '그래도 실패하면 지원팀에 로그와 함께 문의해주세요.'
        ],
      MicDiagnosticStatus.recorderBusy => ['현재 녹음을 중지한 뒤 점검을 다시 실행하세요.'],
      _ => const [],
    };
  }

  String _formatShortDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final date =
        '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  Widget _buildRecordingCard(BuildContext context) {
    final theme = Theme.of(context);
    final statusText = isRecording ? '녹음 중' : '대기 중';
    final statusColor =
        isRecording ? AppColors.primary : AppColors.textSecondary;
    final indicatorColor =
        isRecording ? AppColors.primary : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C101C22),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '녹음 상태',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF101C22),
                ),
              ),
              const Spacer(),
              _LiveIndicator(color: indicatorColor),
              const SizedBox(width: 6),
              Text(
                statusText,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedVolumeMeter(
            history: volumeHistory,
            maxHeight: 60,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  title: '오늘의 녹음 시간',
                  value: todayRecordingTime,
                  alignment: TextAlign.left,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Showcase(
                  key: scheduleShowcaseKey,
                  description: '예정된 진료 세션을 확인하고 필요 시 설정 탭에서 시간표를 수정하세요.',
                  child: _SummaryTile(
                    title: '예정 녹음 시간',
                    valueLines: plannedSessions,
                    alignment: TextAlign.right,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 480;
              return Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  SizedBox(
                    width:
                        isWide ? constraints.maxWidth / 2 - 8 : double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (isRecording) {
                          onStopRecording();
                        } else {
                          onStartRecording();
                        }
                      },
                      icon: Icon(
                          isRecording ? Icons.stop : Icons.fiber_manual_record),
                      label: Text(isRecording ? '중지' : '녹음 시작'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor:
                            isRecording ? Colors.redAccent : AppColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width:
                        isWide ? constraints.maxWidth / 2 - 8 : double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        onSyncSchedule();
                      },
                      icon: const Icon(Icons.sync),
                      label: const Text('스케줄 동기화'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.color,
    required this.icon,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

String _formatRetentionLabel(Duration? duration) {
  if (duration == null) return '영구';
  final days = duration.inDays;
  switch (days) {
    case 7:
      return '1주일';
    case 30:
      return '1개월';
    case 90:
      return '3개월';
    case 180:
      return '6개월';
    case 365:
      return '1년';
    default:
      if (days % 30 == 0) {
        return '${(days / 30).round()}개월';
      }
      if (days % 7 == 0) {
        return '${(days / 7).round()}주';
      }
      return '${days}일';
  }
}

class _DiagnosticVisuals {
  const _DiagnosticVisuals({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;
}
