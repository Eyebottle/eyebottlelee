// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:record/record.dart';

import '../../services/auto_launch_service.dart';
import '../../services/settings_service.dart';
import '../../models/recording_profile.dart';

enum RetentionOption { forever, week, month, threeMonths, sixMonths, year }

enum AdvancedSettingSection { audioQuality, vad, retention, wavConversion }

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
  double _vadThreshold = 0.006;
  bool _launchAtStartup = true;
  bool _loading = true;
  RetentionOption _retentionOption = RetentionOption.forever;
  VadPreset? _vadPreset;
  RecordingQualityProfile _recordingProfile = RecordingQualityProfile.balanced;
  double _makeupGainDb = 0.0;
  // WAV 자동 변환 관련
  bool _wavAutoConvertEnabled = false;
  AudioEncoder _wavTargetEncoder = AudioEncoder.aacLc;
  int _conversionDelay = 5;

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
    final profile = await settings.getRecordingProfile();
    final gainDb = await settings.getMakeupGainDb();
    // WAV 자동 변환 설정 로드
    final wavAutoConvert = await settings.isWavAutoConvertEnabled();
    final wavTarget = await settings.getWavTargetEncoder();
    final conversionDelay = await settings.getConversionDelay();
    if (!mounted) return;
    setState(() {
      _vadEnabled = vadEnabled;
      _vadThreshold = vadThreshold;
      _launchAtStartup = launch;
      _retentionOption = _optionFromDuration(retention);
      _vadPreset = _presetFromThreshold(_vadThreshold);
      _recordingProfile = profile;
      _makeupGainDb = gainDb;
      _wavAutoConvertEnabled = wavAutoConvert;
      _wavTargetEncoder = wavTarget;
      _conversionDelay = conversionDelay;
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
      AdvancedSettingSection.audioQuality => (
          '녹음 품질 · 마이크 보정',
          '녹음 파일 용량과 조용한 환경에서의 입력 민감도를 동시에 조절합니다.'
        ),
      AdvancedSettingSection.vad => (
          '무음 감지 설정',
          '말이 끊어졌을 때 자동으로 녹음을 멈추고, 다시 말하면 이어서 녹음되도록 민감도를 조절합니다.'
        ),
      AdvancedSettingSection.retention => (
          '녹음 파일 보관 기간',
          '선택한 기간이 지나면 녹음 파일을 자동으로 정리합니다.'
        ),
      AdvancedSettingSection.wavConversion => (
          'WAV 파일 자동 변환',
          'WAV 파일을 AAC/Opus로 자동 변환하여 용량을 75% 이상 절감합니다.'
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
      case AdvancedSettingSection.audioQuality:
        final selectedProfile = RecordingProfile.resolve(_recordingProfile);
        return _SettingsCard(
          icon: Icons.graphic_eq,
          title: '녹음 품질과 민감도',
          description:
              '녹음 파일 용량을 줄이거나 조용한 진료실에서도 작은 목소리를 안정적으로 녹음할 수 있도록 민감도를 조정합니다. 변경 후에는 짧게 테스트 녹음을 진행해 주세요.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '녹음 품질',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: RecordingQualityProfile.values.map((profile) {
                  final preset = RecordingProfile.resolve(profile);
                  final selected = _recordingProfile == profile;
                  return ChoiceChip(
                    label: Text(preset.label),
                    selected: selected,
                    onSelected: (value) {
                      if (!value) return;
                      setState(() => _recordingProfile = profile);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Text(
                selectedProfile.description,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              Text(
                '조용한 환경 보정 (+${_makeupGainDb.toStringAsFixed(1)} dB)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Slider(
                value: _makeupGainDb,
                max: 12,
                divisions: 24,
                label: '+${_makeupGainDb.toStringAsFixed(1)} dB',
                onChanged: (value) {
                  setState(
                    () =>
                        _makeupGainDb = double.parse(value.toStringAsFixed(1)),
                  );
                },
              ),
              Text(
                _makeupGainDb <= 0.05
                    ? '게인 0 dB: 원본 입력을 그대로 사용합니다.'
                    : '게인 +${_makeupGainDb.toStringAsFixed(1)} dB: 조용한 환경에서 입력 신호를 살짝 키웁니다.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade600),
              ),
            ],
          ),
        );
      case AdvancedSettingSection.vad:
        return _SettingsCard(
          icon: Icons.mic,
          title: '무음 감지(자동 일시정지)',
          description:
              '값을 낮출수록 작은 소리에도 녹음이 이어지고, 값을 높이면 큰 소리에서만 녹음이 유지됩니다. 진료실이 조용한 경우 0.004~0.006, 복도나 대기실 소음이 들어오는 경우 0.012 이상을 권장합니다. 설정 후 짧게 테스트 녹음을 진행해 주세요.',
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
                    label: const Text('표준 환경 (권장 0.006)'),
                    selected: _vadPreset == VadPreset.standard,
                    onSelected: (selected) {
                      if (!selected) return;
                      setState(() {
                        _vadPreset = VadPreset.standard;
                        _vadThreshold = 0.006;
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
                          _vadThreshold = double.parse(v.toStringAsFixed(3));
                          _vadPreset = _presetFromThreshold(_vadThreshold);
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
      case AdvancedSettingSection.wavConversion:
        return _SettingsCard(
          icon: Icons.transform,
          title: 'WAV 파일 자동 변환',
          description:
              'AAC나 Opus로 직접 녹음할 수 없는 PC에서 WAV로 녹음된 파일을 자동으로 압축 포맷으로 변환합니다. '
              'AAC/Opus로 직접 녹음 가능한 경우 이 기능은 자동으로 건너뜁니다.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('WAV 자동 변환 활성화'),
                subtitle: const Text('용량 큰 WAV 파일을 75% 이상 절감'),
                value: _wavAutoConvertEnabled,
                onChanged: (v) => setState(() => _wavAutoConvertEnabled = v),
              ),
              if (_wavAutoConvertEnabled) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  '변환 포맷',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('AAC (권장)'),
                      selected: _wavTargetEncoder == AudioEncoder.aacLc,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _wavTargetEncoder = AudioEncoder.aacLc);
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Opus'),
                      selected: _wavTargetEncoder == AudioEncoder.opus,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _wavTargetEncoder = AudioEncoder.opus);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _wavTargetEncoder == AudioEncoder.aacLc
                      ? 'AAC: 대부분의 플레이어와 호환되며 안정적입니다 (.m4a)'
                      : 'Opus: 더 나은 음질과 압축률을 제공합니다 (.opus)',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                Text(
                  '변환 지연 시간 ($_conversionDelay초)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '녹음 안정화를 위해 세그먼트 분할 후 변환 시작까지 대기합니다',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                Slider(
                  value: _conversionDelay.toDouble(),
                  min: 3,
                  max: 15,
                  divisions: 12,
                  label: '$_conversionDelay초',
                  onChanged: (value) {
                    setState(() => _conversionDelay = value.toInt());
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '변환은 백그라운드에서 조용히 진행되며, 실패 시 원본 WAV 파일이 보존됩니다',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.blue.shade900,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
    }
  }

  Future<void> _save() async {
    final settings = SettingsService();
    await settings.setRecordingProfile(_recordingProfile);
    await settings.setMakeupGainDb(_makeupGainDb);
    await settings.setVad(enabled: _vadEnabled, threshold: _vadThreshold);
    await settings.setLaunchAtStartup(_launchAtStartup);
    await settings.setRetentionDuration(_durationForOption(_retentionOption));
    // WAV 자동 변환 설정 저장
    await settings.setWavAutoConvertEnabled(_wavAutoConvertEnabled);
    await settings.setWavTargetEncoder(_wavTargetEncoder);
    await settings.setConversionDelay(_conversionDelay);

    if (!kIsWeb) {
      try {
        await AutoLaunchService().apply(_launchAtStartup);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('자동 실행 설정 적용 중 오류가 발생했습니다: $e'),
            ),
          );
        }
      }
    }

    if (mounted) {
      Navigator.of(context).pop('saved');
    }
  }
}

enum VadPreset { quiet, standard, noisy }

VadPreset? _presetFromThreshold(double threshold) {
  if ((threshold - 0.004).abs() < 0.0005) return VadPreset.quiet;
  if ((threshold - 0.006).abs() < 0.0005) return VadPreset.standard;
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
