part of 'main_screen.dart';

/// 자동 실행 매니저 탭
class _LaunchManagerTab extends StatelessWidget {
  const _LaunchManagerTab({
    required this.onAutoLaunchChanged,
    this.switchShowcaseKey,
    this.addButtonShowcaseKey,
    this.testButtonShowcaseKey,
  });

  final void Function(bool enabled) onAutoLaunchChanged;
  final GlobalKey? switchShowcaseKey;
  final GlobalKey? addButtonShowcaseKey;
  final GlobalKey? testButtonShowcaseKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use scrollable layout on small screens
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 간단한 헤더
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.rocket_launch,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '자동 실행 매니저',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2329),
                        ),
                      ),
                      Text(
                        '진료실에서 자주 사용하는 프로그램들을 앱 시작 시 자동으로 실행합니다',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // LaunchManagerWidget
            Expanded(
              child: LaunchManagerWidget(
                onAutoLaunchChanged: onAutoLaunchChanged,
                switchShowcaseKey: switchShowcaseKey,
                addButtonShowcaseKey: addButtonShowcaseKey,
                testButtonShowcaseKey: testButtonShowcaseKey,
              ),
            ),
          ],
        );

        // Wrap in scrollable container for small screens
        if (constraints.maxHeight < 480) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              height: 600, // Minimum height for proper layout
              child: content,
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(24),
          child: content,
        );
      },
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({
    required this.onOpenSchedule,
    required this.onOpenSaveFolder,
    required this.onOpenVad,
    required this.onOpenRetention,
    required this.onOpenAudioQuality,
    required this.onOpenWavConversion,
    required this.onOpenStartup,
    required this.scheduleShowcaseKey,
    required this.saveFolderShowcaseKey,
    required this.retentionShowcaseKey,
    required this.vadShowcaseKey,
    required this.audioQualityShowcaseKey,
    required this.saveFolder,
    required this.vadEnabled,
    required this.launchAtStartup,
    required this.startMinimizedOnBoot,
    required this.retentionDuration,
    required this.recordingProfile,
    required this.makeupGainDb,
  });

  final Future<void> Function() onOpenSchedule;
  final Future<void> Function() onOpenSaveFolder;
  final Future<void> Function() onOpenVad;
  final Future<void> Function() onOpenRetention;
  final Future<void> Function() onOpenAudioQuality;
  final Future<void> Function() onOpenWavConversion;
  final Future<void> Function() onOpenStartup;
  final GlobalKey scheduleShowcaseKey;
  final GlobalKey saveFolderShowcaseKey;
  final GlobalKey retentionShowcaseKey;
  final GlobalKey vadShowcaseKey;
  final GlobalKey audioQualityShowcaseKey;
  final String saveFolder;
  final bool vadEnabled;
  final bool launchAtStartup;
  final bool startMinimizedOnBoot;
  final Duration? retentionDuration;
  final RecordingQualityProfile recordingProfile;
  final double makeupGainDb;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingsSection(
            title: '스케줄 설정',
            items: [
              SettingsDestination(
                icon: Icons.schedule,
                title: '진료 시간표',
                description: '자동 녹음 시간을 설정합니다.',
                onTap: onOpenSchedule,
                showcaseKey: scheduleShowcaseKey,
                showcaseDescription: '진료 시간표에서 오전/오후 구간을 조정해 자동 녹음 시간을 관리하세요.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: '저장 설정',
            items: [
              SettingsDestination(
                icon: Icons.folder_open,
                title: '저장 위치',
                description: saveFolder,
                onTap: onOpenSaveFolder,
                showcaseKey: saveFolderShowcaseKey,
                showcaseDescription: '녹음 파일을 저장할 폴더(예: OneDrive)를 지정합니다.',
              ),
              SettingsDestination(
                icon: Icons.history,
                title: '보관 기간',
                description: '오래된 파일을 자동으로 정리합니다.',
                statusText: _formatRetentionLabel(retentionDuration),
                onTap: onOpenRetention,
                showcaseKey: retentionShowcaseKey,
                showcaseDescription: '자동 보관 기간을 설정해 오래된 파일을 정리할 수 있습니다.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: '고급 설정',
            items: [
              SettingsDestination(
                icon: Icons.graphic_eq,
                title: '녹음 품질',
                description: '용량 절감 및 마이크 민감도를 조절합니다.',
                statusText: _formatAudioQualityStatus(
                  recordingProfile,
                  makeupGainDb,
                ),
                onTap: onOpenAudioQuality,
                showcaseKey: audioQualityShowcaseKey,
                showcaseDescription:
                    '저장 공간이 부족하거나 조용한 환경이라면 녹음 품질과 마이크 민감도를 여기서 조정하세요.',
              ),
              SettingsDestination(
                icon: Icons.mic,
                title: '무음 감지 (VAD)',
                description: '음성이 감지될 때만 녹음합니다.',
                statusText: vadEnabled ? '켜짐' : '꺼짐',
                onTap: onOpenVad,
                showcaseKey: vadShowcaseKey,
                showcaseDescription:
                    '무음 감지 민감도를 조정해 조용한 환경에서도 녹음이 잘 이어지도록 설정하세요.',
              ),
              SettingsDestination(
                icon: Icons.transform,
                title: 'WAV 자동 변환',
                description: 'AAC/Opus로 변환하여 용량 75% 절감합니다.',
                onTap: onOpenWavConversion,
              ),
              SettingsDestination(
                icon: Icons.power_settings_new,
                title: 'Windows 시작',
                description: '부팅 시 자동 실행 및 백그라운드 시작합니다.',
                statusText: !launchAtStartup
                    ? '꺼짐'
                    : startMinimizedOnBoot
                        ? '켜짐 · 백그라운드'
                        : '켜짐 · 창 표시',
                onTap: onOpenStartup,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatAudioQualityStatus(
  RecordingQualityProfile profile,
  double makeupGainDb,
) {
  final preset = RecordingProfile.resolve(profile);
  final gainText = makeupGainDb <= 0.05
      ? '게인 0 dB'
      : '게인 +${makeupGainDb.toStringAsFixed(1)} dB';
  return '${preset.label} · $gainText';
}

class SettingsDestination {
  SettingsDestination({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.statusText,
    this.showcaseKey,
    this.showcaseDescription,
  });

  final IconData icon;
  final String title;
  final String description;
  final Future<void> Function() onTap;
  final String? statusText;
  final GlobalKey? showcaseKey;
  final String? showcaseDescription;
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<SettingsDestination> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF101C22),
              ),
            ),
          ),
          ...items.map((item) => _SettingsTile(item: item)),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.item});

  final SettingsDestination item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget content = InkWell(
      onTap: () => item.onTap(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF101C22),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (item.statusText != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.statusText == '켜짐'
                      ? AppColors.primaryContainer
                      : AppColors.textSecondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.statusText!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: item.statusText == '켜짐'
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );

    if (item.showcaseKey != null && item.showcaseDescription != null) {
      content = Showcase(
        key: item.showcaseKey!,
        description: item.showcaseDescription!,
        child: content,
      );
    }

    return content;
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.title,
    this.value,
    this.valueLines,
    this.alignment = TextAlign.left,
  });

  final String title;
  final String? value;
  final List<String>? valueLines;
  final TextAlign alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = valueLines;
    return Column(
      crossAxisAlignment: alignment == TextAlign.left
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        if (value != null)
          Text(
            value!,
            textAlign: alignment,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF101C22),
            ),
          )
        else if (lines != null && lines.isNotEmpty)
          Column(
            crossAxisAlignment: alignment == TextAlign.left
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: lines
                .map(
                  (line) => Text(
                    line,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF101C22),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _LiveIndicator extends StatefulWidget {
  const _LiveIndicator({required this.color});

  final Color color;

  @override
  State<_LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<_LiveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      lowerBound: 0.4,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _controller.value,
          child: child,
        );
      },
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

