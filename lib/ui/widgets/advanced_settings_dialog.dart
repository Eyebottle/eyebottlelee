import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import '../../services/settings_service.dart';

enum RetentionOption { forever, week, month, threeMonths, sixMonths, year }

enum AdvancedSettingSection { vad, retention, autoLaunch }

class AdvancedSettingsDialog extends StatefulWidget {
  const AdvancedSettingsDialog({super.key, required this.section});

  final AdvancedSettingSection section;

  static Future<String?> show(
    BuildContext context,
    AdvancedSettingSection section,
  ) {
    return showDialog(
      context: context,
      builder: (context) => AdvancedSettingsDialog(section: section),
    );
  }

  @override
  State<AdvancedSettingsDialog> createState() => _AdvancedSettingsDialogState();
}

class _AdvancedSettingsDialogState extends State<AdvancedSettingsDialog> {
  bool _vadEnabled = true;
  double _vadThreshold = 0.01;
  bool _launchAtStartup = true;
  bool _loading = true;
  RetentionOption _retentionOption = RetentionOption.forever;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = SettingsService();
    final (vadEnabled, vadThreshold) = await settings.getVad();
    final launch = await settings.getLaunchAtStartup();
    final retention = await settings.getRetentionDuration();
    if (!mounted) return;
    setState(() {
      _vadEnabled = vadEnabled;
      _vadThreshold = vadThreshold;
      _launchAtStartup = launch;
      _retentionOption = _optionFromDuration(retention);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.of(context).size;
    final maxWidth = (mediaSize.width * 0.8).clamp(360.0, 520.0);
    final maxHeight = (mediaSize.height * 0.82).clamp(420.0, 640.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: _loading
            ? const SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: _buildSectionContent(context),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('닫기'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _save,
                          child: const Text('저장'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final (title, description) = switch (widget.section) {
      AdvancedSettingSection.vad => (
          'VAD 설정',
          '무음 감지 민감도를 조정해 진료 환경에 맞게 최적화하세요.'
        ),
      AdvancedSettingSection.retention => (
          '녹음 파일 보관 기간',
          '선택한 기간이 지나면 녹음 파일을 자동으로 정리합니다.'
        ),
      AdvancedSettingSection.autoLaunch => (
          'Windows 자동 실행',
          '로그인 시 앱을 자동으로 실행할지 여부를 설정합니다.'
        ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey.shade600),
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

  Widget _buildSectionContent(BuildContext context) {
    switch (widget.section) {
      case AdvancedSettingSection.vad:
        return _SettingsCard(
          icon: Icons.mic,
          title: 'VAD (무음 자동 스킵)',
          description:
              '값을 낮출수록 조용한 소리까지 감지하고, 값을 높이면 큰 소리에서만 녹음이 이어집니다. 환경 소음이 많다면 값을 조금 높여주세요.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('VAD 사용'),
                value: _vadEnabled,
                onChanged: (v) => setState(() => _vadEnabled = v),
              ),
              const SizedBox(height: 12),
              Text(
                'VAD 임계값',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              Slider(
                value: _vadThreshold.clamp(0.001, 0.2),
                min: 0.001,
                max: 0.1,
                divisions: 99,
                label: _vadThreshold.toStringAsFixed(3),
                onChanged: _vadEnabled
                    ? (v) => setState(() => _vadThreshold = v)
                    : null,
              ),
            ],
          ),
        );
      case AdvancedSettingSection.retention:
        return _SettingsCard(
          icon: Icons.history,
          title: '녹음 파일 자동 삭제 기간',
          description: '선택한 기간이 지나면 앱이 날짜별 폴더를 포함해 자동으로 정리합니다.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: RetentionOption.values
                .map(
                  (option) => ChoiceChip(
                    label: Text(_labelForOption(option)),
                    selected: _retentionOption == option,
                    onSelected: (_) =>
                        setState(() => _retentionOption = option),
                  ),
                )
                .toList(),
          ),
        );
      case AdvancedSettingSection.autoLaunch:
        return _SettingsCard(
          icon: Icons.play_circle,
          title: 'Windows 로그인 시 자동 실행',
          description: '개발 단계에서는 실행 경로에 따라 동작이 제한될 수 있습니다.',
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('자동 실행 사용'),
            value: _launchAtStartup,
            onChanged: (v) => setState(() => _launchAtStartup = v),
          ),
        );
    }
  }

  Future<void> _save() async {
    final settings = SettingsService();
    await settings.setVad(enabled: _vadEnabled, threshold: _vadThreshold);
    await settings.setLaunchAtStartup(_launchAtStartup);
    await settings.setRetentionDuration(_durationForOption(_retentionOption));

    if (!kIsWeb && Platform.isWindows) {
      try {
        final exePath = Platform.resolvedExecutable;
        LaunchAtStartup.instance.setup(
          appName: 'Eyebottle Medical Recorder',
          appPath: exePath,
          args: const <String>[],
        );
        if (_launchAtStartup) {
          await LaunchAtStartup.instance.enable();
        } else {
          await LaunchAtStartup.instance.disable();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('자동 실행 설정 적용 중 오류가 발생했습니다: $e')),
          );
        }
      }
    }

    if (mounted) {
      Navigator.of(context).pop('saved');
    }
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: theme.colorScheme.outlineVariant.withAlpha(60)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

RetentionOption _optionFromDuration(Duration? duration) {
  if (duration == null) return RetentionOption.forever;
  switch (duration.inDays) {
    case 7:
      return RetentionOption.week;
    case 30:
      return RetentionOption.month;
    case 90:
      return RetentionOption.threeMonths;
    case 180:
      return RetentionOption.sixMonths;
    case 365:
      return RetentionOption.year;
    default:
      return RetentionOption.forever;
  }
}

Duration? _durationForOption(RetentionOption option) {
  switch (option) {
    case RetentionOption.forever:
      return null;
    case RetentionOption.week:
      return const Duration(days: 7);
    case RetentionOption.month:
      return const Duration(days: 30);
    case RetentionOption.threeMonths:
      return const Duration(days: 90);
    case RetentionOption.sixMonths:
      return const Duration(days: 180);
    case RetentionOption.year:
      return const Duration(days: 365);
  }
}

String _labelForOption(RetentionOption option) {
  switch (option) {
    case RetentionOption.forever:
      return '삭제 없음 (영구 보존)';
    case RetentionOption.week:
      return '1주';
    case RetentionOption.month:
      return '1개월';
    case RetentionOption.threeMonths:
      return '3개월';
    case RetentionOption.sixMonths:
      return '6개월';
    case RetentionOption.year:
      return '1년';
  }
}
