import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auto_launch_service.dart';
import '../../services/logging_service.dart';
import '../../services/settings_service.dart';
import '../../utils/win32_package_identity.dart';

/// 부팅 자동시작 / StartupTask / 로깅 상태를 한눈에 보여주는 진단 패널.
///
/// v1.3.4부터 환경에 따라 간헐적으로 재발하던 "부팅 시 백그라운드 시작" 문제를
/// 사용자가 1분 안에 캡처해 공유할 수 있도록, 부팅 결정 이력·StartupTask 상태·
/// 로그 위치를 모아서 보여주고, 로그 폴더 열기 / 진단 정보 복사 버튼을 제공한다.
class StartupDiagnosticsSection extends StatefulWidget {
  const StartupDiagnosticsSection({super.key});

  @override
  State<StartupDiagnosticsSection> createState() =>
      _StartupDiagnosticsSectionState();
}

class _StartupDiagnosticsSectionState extends State<StartupDiagnosticsSection> {
  final _settings = SettingsService();
  final _logging = LoggingService();

  bool _loading = true;
  _DiagnosticsData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    AutoLaunchStatusSnapshot? snapshot;
    try {
      snapshot = await AutoLaunchService().getStatusSnapshot();
    } catch (_) {
      snapshot = null;
    }

    final launchAtStartup = await _settings.getLaunchAtStartup();
    final startMinimizedOnBoot = await _settings.getStartMinimizedOnBoot();
    final bootHistory = await _settings.getBootDecisionHistory();

    // 로그 디렉터리는 LoggingService가 이미 해석해둔 값을 우선 사용하고,
    // 없으면 직접 해석을 시도한다.
    String? logDirPath = _logging.resolvedLogDirPath;
    String? logDirSource = _logging.resolvedLogDirSource;
    if (logDirPath == null) {
      try {
        logDirPath = await _logging.getLogDirectoryPath();
        logDirSource = _logging.resolvedLogDirSource;
      } catch (_) {
        logDirPath = null;
      }
    }

    String? packageFamilyName = snapshot?.packageFamilyName;
    packageFamilyName ??= () {
      try {
        return tryGetPackageFamilyName(logging: _logging);
      } catch (_) {
        return null;
      }
    }();

    if (!mounted) return;
    setState(() {
      _loading = false;
      _data = _DiagnosticsData(
        snapshot: snapshot,
        launchAtStartup: launchAtStartup,
        startMinimizedOnBoot: startMinimizedOnBoot,
        bootHistory: bootHistory,
        logDirPath: logDirPath,
        logDirSource: logDirSource,
        packageFamilyName: packageFamilyName,
      );
    });
  }

  Future<void> _openLogFolder() async {
    final dir = _data?.logDirPath;
    if (dir == null) {
      _toast('로그 폴더 경로를 찾을 수 없습니다');
      return;
    }
    try {
      await Process.run('explorer', [dir]);
    } catch (e) {
      _toast('로그 폴더 열기 실패: $e');
    }
  }

  Future<void> _copyDiagnostics() async {
    final text = _data?.toReportText() ?? '진단 정보 없음';
    await Clipboard.setData(ClipboardData(text: text));
    _toast('진단 정보를 클립보드에 복사했습니다');
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(Icons.bug_report_outlined,
              color: theme.colorScheme.primary),
          title: Text(
            '진단 정보',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: const Text(
            '자동시작이 이상하게 동작하면 여기서 상태를 확인하고 복사해 공유하세요',
          ),
          onExpansionChanged: (expanded) {
            if (expanded) _load();
          },
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _buildRows(theme),
              const SizedBox(height: 12),
              _buildBootHistory(theme),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _openLogFolder,
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('로그 폴더 열기'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _copyDiagnostics,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('진단 정보 복사'),
                  ),
                  TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('새로고침'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRows(ThemeData theme) {
    final d = _data!;
    final s = d.snapshot;
    final rows = <(String, String)>[
      ('패키지 환경', s == null
          ? '조회 실패'
          : (s.isPackaged ? 'MSIX 패키지' : '비패키지(개발)')),
      ('패키지 식별자', d.packageFamilyName ?? '-'),
      ('StartupTask 상태', s?.startupTaskState ?? '조회 실패'),
      ('자동 실행(설정 저장값)', d.launchAtStartup ? 'ON' : 'OFF'),
      ('부팅 시 백그라운드 시작', d.startMinimizedOnBoot ? 'ON' : 'OFF'),
      ('로그 위치 단계', d.logDirSource ?? '-'),
      ('로그 폴더', d.logDirPath ?? '해석 실패'),
    ];

    return Column(
      children: rows
          .map((row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        row.$1,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    Expanded(
                      child: SelectableText(
                        row.$2,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildBootHistory(ThemeData theme) {
    final history = _data!.bootHistory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '최근 부팅 결정 이력',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        if (history.isEmpty)
          Text(
            '아직 기록이 없습니다 (다음 부팅부터 기록됩니다)',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          )
        else
          ...history.take(5).map((e) {
            final ts = e['timestamp']?.toString() ?? '?';
            final hasAuto = e['hasAutostart'] == true;
            final minimized = e['shouldStartMinimized'] == true;
            final label = minimized
                ? '트레이로 시작'
                : (hasAuto ? '자동시작-창표시' : '수동-창표시');
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '• $ts → $label',
                style: theme.textTheme.bodySmall,
              ),
            );
          }),
      ],
    );
  }
}

class _DiagnosticsData {
  _DiagnosticsData({
    required this.snapshot,
    required this.launchAtStartup,
    required this.startMinimizedOnBoot,
    required this.bootHistory,
    required this.logDirPath,
    required this.logDirSource,
    required this.packageFamilyName,
  });

  final AutoLaunchStatusSnapshot? snapshot;
  final bool launchAtStartup;
  final bool startMinimizedOnBoot;
  final List<Map<String, dynamic>> bootHistory;
  final String? logDirPath;
  final String? logDirSource;
  final String? packageFamilyName;

  String toReportText() {
    final buffer = StringBuffer()
      ..writeln('=== 아이보틀 진료녹음 진단 정보 ===')
      ..writeln('패키지 환경: '
          '${snapshot == null ? "조회 실패" : (snapshot!.isPackaged ? "MSIX" : "비패키지")}')
      ..writeln('패키지 식별자: ${packageFamilyName ?? "-"}')
      ..writeln('StartupTask 상태: ${snapshot?.startupTaskState ?? "조회 실패"}')
      ..writeln('자동 실행(설정 저장값): ${launchAtStartup ? "ON" : "OFF"}')
      ..writeln('부팅 시 백그라운드 시작: ${startMinimizedOnBoot ? "ON" : "OFF"}')
      ..writeln('로그 위치 단계: ${logDirSource ?? "-"}')
      ..writeln('로그 폴더: ${logDirPath ?? "해석 실패"}')
      ..writeln('--- 최근 부팅 결정 이력 ---');
    if (bootHistory.isEmpty) {
      buffer.writeln('(기록 없음)');
    } else {
      for (final e in bootHistory) {
        buffer.writeln(
          '${e['timestamp']} | args=${e['args']} | '
          'hasAutostart=${e['hasAutostart']} | '
          'startMinimizedOnBoot=${e['startMinimizedOnBoot']} | '
          'shouldStartMinimized=${e['shouldStartMinimized']}',
        );
      }
    }
    return buffer.toString();
  }
}
