// ignore_for_file: invalid_use_of_protected_member

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
  VadPreset? _vadPreset;

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
      _vadPreset = _presetFromThreshold(_vadThreshold);
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
          '무음 감지 설정',
          '말이 끊어졌을 때 자동으로 녹음을 멈추고, 다시 말하면 이어서 녹음되도록 민감도를 조절합니다.'
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
          title: '무음 감지(자동 일시정지)',
          description:
              '값을 낮출수록 작은 소리에도 녹음이 이어지고, 값을 높이면 큰 소리에서만 녹음이 유지됩니다. 진료실이 조용한 경우 낮은 값(0.004), 복도나 대기실 소음이 들어오는 경우 높은 값(0.020)을 권장합니다. 설정 후 짧은 테스트 녹음을 꼭 진행해 보세요.',
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
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('주변 조용 (권장 0.004)'),
                    selected: _vadPreset == VadPreset.quiet,
                    onSelected: (selected) {
                      if (!selected) return;
                      setState(() {
                        _vadPreset = VadPreset.quiet;
                        _vadThreshold = 0.004;
                      });
                    },
                  ),
                  ChoiceChip(
                    label: const Text('주변 혼잡 (권장 0.020)'),
                    selected: _vadPreset == VadPreset.noisy,
                    onSelected: (selected) {
                      if (!selected) return;
                      setState(() {
                        _vadPreset = VadPreset.noisy;
                        _vadThreshold = 0.02;
                      });
                    },
                  ),
                ],
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
                    ? (v) => setState(() {
                          _vadThreshold = v;
                          _vadPreset = null;
                        })
                    : null,
              ),
            ],
          ),
        );
      case AdvancedSettingSection.retention:
        return _SettingsCard(
          icon: Icons.history,
          title: '녹음 파일 자동 삭제 기간',
          description: '기본값은 영구 보존이며, 선택한 기간이 지나면 앱이 날짜별 폴더를 포함해 자동으로 정리합니다.',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: RetentionOption.values.map((option) {
              final (label, detail) = _retentionDetails(option);
              return RadioListTile<RetentionOption>(
                contentPadding: EdgeInsets.zero,
                title: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: detail == null
                    ? null
                    : Text(detail,
                        style: Theme.of(context).textTheme.bodySmall),
                value: option,
                groupValue: _retentionOption,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _retentionOption = value);
                  }
                },
              );
            }).toList(),
          ),
        );
      case AdvancedSettingSection.autoLaunch:
        return _SettingsCard(
          icon: Icons.play_circle,
          title: 'Windows 로그인 시 자동 실행',
          description:
              'Windows 로그인 시 앱을 자동으로 실행합니다. 만약 자동 실행이 동작하지 않으면 Windows 설정 > 앱 > 시작 프로그램에서 “Eyebottle Medical Recorder” 항목을 켜고, 조직 정책으로 차단된 경우 IT 담당자에게 예외 설정을 요청하세요.',
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('자동 실행 사용'),
            subtitle: const Text(
              '로그인 후 자동 실행이 되지 않으면 Windows 시작 프로그램 설정에서 항목을 활성화하거나 IT 담당자에게 예외 승인을 요청하세요.',
            ),
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

enum VadPreset { quiet, noisy }

VadPreset? _presetFromThreshold(double threshold) {
  if ((threshold - 0.004).abs() < 0.0005) return VadPreset.quiet;
  if ((threshold - 0.020).abs() < 0.0005) return VadPreset.noisy;
  return null;
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

(String, String?) _retentionDetails(RetentionOption option) {
  switch (option) {
    case RetentionOption.forever:
      return (
        '삭제 없음 (영구 보존)',
        '기본값입니다. 모든 녹음 파일을 수동으로 정리할 때까지 보관합니다.',
      );
    case RetentionOption.week:
      return ('1주', '최근 진료만 확인할 때 권장합니다.');
    case RetentionOption.month:
      return ('1개월', '일반적인 진료 기록 보관 기간에 적합합니다.');
    case RetentionOption.threeMonths:
      return ('3개월', '분기별 보고나 검토를 준비할 때 유용합니다.');
    case RetentionOption.sixMonths:
      return ('6개월', '반기 단위로 정리하는 환경에 적합합니다.');
    case RetentionOption.year:
      return ('1년', '장기 보관이 필요할 때 사용하세요.');
  }
}
