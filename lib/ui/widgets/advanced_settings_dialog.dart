import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import '../../services/settings_service.dart';
import '../style/app_spacing.dart';
import 'app_section_card.dart';

class AdvancedSettingsDialog extends StatefulWidget {
  const AdvancedSettingsDialog({super.key});

  @override
  State<AdvancedSettingsDialog> createState() => _AdvancedSettingsDialogState();
}

enum RetentionOption { forever, week, month, threeMonths, sixMonths, year }

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
    final maxWidth = (mediaSize.width * 0.9).clamp(0.0, 360.0);
    final maxHeight = mediaSize.height * 0.7;

    return AlertDialog(
      title: const Text('고급 설정'),
      content: _loading
          ? const SizedBox(
              width: 320,
              height: 120,
              child: Center(child: CircularProgressIndicator()))
          : ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('VAD(무음 자동 스킵) 사용'),
                            value: _vadEnabled,
                            onChanged: (v) => setState(() => _vadEnabled = v),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const Text('VAD 임계값'),
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
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '값을 낮출수록 조용한 소리까지 감지하고, 높일수록 큰 소리에서만 녹음이 이어집니다. 환경 소음이 많다면 값을 조금 높여주세요.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('녹음 파일 자동 삭제 기간'),
                          const SizedBox(height: AppSpacing.sm),
                          DropdownButton<RetentionOption>(
                            value: _retentionOption,
                            items: RetentionOption.values
                                .map(
                                  (option) => DropdownMenuItem(
                                    value: option,
                                    child: Text(_labelForOption(option)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _retentionOption = value);
                              }
                            },
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '기본값은 영구 보존이며, 선택한 기간이 지나면 앱이 날짜별 폴더를 포함해 자동 정리합니다.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppSectionCard(
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Windows 로그인 시 자동 실행'),
                        value: _launchAtStartup,
                        onChanged: (v) =>
                            setState(() => _launchAtStartup = v ?? true),
                        subtitle:
                            const Text('개발 단계에서는 실행 경로에 따라 동작이 제한될 수 있습니다.'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('저장'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final settings = SettingsService();
    await settings.setVad(enabled: _vadEnabled, threshold: _vadThreshold);
    await settings.setLaunchAtStartup(_launchAtStartup);
    await settings.setRetentionDuration(_durationForOption(_retentionOption));

    // 베타: Windows에서만 자동 실행 등록 시도
    if (!kIsWeb && Platform.isWindows) {
      try {
        // appPath는 배포 후 실제 exe로 교체 필요
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
        // 개발 환경에서는 실패할 수 있으므로 사용자에게만 안내
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
      return '1주 후 자동 삭제';
    case RetentionOption.month:
      return '1개월 후 자동 삭제';
    case RetentionOption.threeMonths:
      return '3개월 후 자동 삭제';
    case RetentionOption.sixMonths:
      return '6개월 후 자동 삭제';
    case RetentionOption.year:
      return '1년 후 자동 삭제';
  }
}
