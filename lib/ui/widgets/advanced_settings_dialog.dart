import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import '../../services/settings_service.dart';

class AdvancedSettingsDialog extends StatefulWidget {
  const AdvancedSettingsDialog({super.key});

  @override
  State<AdvancedSettingsDialog> createState() => _AdvancedSettingsDialogState();
}

class _AdvancedSettingsDialogState extends State<AdvancedSettingsDialog> {
  bool _vadEnabled = true;
  double _vadThreshold = 0.01;
  bool _launchAtStartup = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = SettingsService();
    final (vadEnabled, vadThreshold) = await settings.getVad();
    final launch = await settings.getLaunchAtStartup();
    if (!mounted) return;
    setState(() {
      _vadEnabled = vadEnabled;
      _vadThreshold = vadThreshold;
      _launchAtStartup = launch;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('고급 설정'),
      content: _loading
          ? const SizedBox(width: 320, height: 120, child: Center(child: CircularProgressIndicator()))
          : SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // VAD
                  SwitchListTile(
                    title: const Text('VAD(무음 자동 스킵) 사용'),
                    value: _vadEnabled,
                    onChanged: (v) => setState(() => _vadEnabled = v),
                  ),
                  ListTile(
                    title: const Text('VAD 임계값'),
                    subtitle: Slider(
                      value: _vadThreshold.clamp(0.001, 0.2),
                      min: 0.001,
                      max: 0.1,
                      divisions: 99,
                      label: _vadThreshold.toStringAsFixed(3),
                      onChanged: _vadEnabled ? (v) => setState(() => _vadThreshold = v) : null,
                    ),
                  ),
                  const Divider(height: 24),

                  // Launch at startup
                  CheckboxListTile(
                    title: const Text('Windows 로그인 시 자동 실행'),
                    value: _launchAtStartup,
                    onChanged: (v) => setState(() => _launchAtStartup = v ?? true),
                    subtitle: const Text('개발 단계에서는 실행 경로에 따라 동작이 제한될 수 있습니다.'),
                  ),
                ],
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

    // 베타: Windows에서만 자동 실행 등록 시도
    if (!kIsWeb && Platform.isWindows) {
      try {
        // appPath는 배포 후 실제 exe로 교체 필요
        await LaunchAtStartup.instance.setup(appName: 'Eyebottle Medical Recorder');
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
