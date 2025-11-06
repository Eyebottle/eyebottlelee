// 로그와 시스템 정보를 모아 사용자에게 진단 힌트를 주는 다이얼로그입니다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/logging_service.dart';

/// 진단 정보 다이얼로그 - 로그, 시스템 정보, 복사 기능 제공
class DiagnosticInfoDialog extends StatefulWidget {
  const DiagnosticInfoDialog({super.key});

  @override
  State<DiagnosticInfoDialog> createState() => _DiagnosticInfoDialogState();
}

class _DiagnosticInfoDialogState extends State<DiagnosticInfoDialog> {
  final LoggingService _logging = LoggingService();

  String _logDirectory = '로그 경로 확인 중...';
  String? _currentLogFile;
  List<File> _logFiles = [];
  bool _isLoading = true;
  String _diagnosticInfo = '';

  @override
  void initState() {
    super.initState();
    _loadDiagnosticInfo();
  }

  Future<void> _loadDiagnosticInfo() async {
    setState(() => _isLoading = true);

    try {
      // 1. 로그 정보 수집
      final logDir = await _logging.getLogDirectoryPath();
      final currentLog = await _logging.getCurrentLogFilePath();
      final logFiles = await _logging.getLogFiles();

      // 2. 시스템 정보 수집
      final packageInfo = await PackageInfo.fromPlatform();
      final osInfo = Platform.operatingSystem;
      final osVersion = Platform.operatingSystemVersion;

      // 3. 진단 정보 문자열 생성
      final buffer = StringBuffer();
      buffer.writeln('=== 아이보틀 진료녹음 진단 정보 ===\n');

      buffer.writeln('■ 앱 정보');
      buffer.writeln('  - 버전: ${packageInfo.version}');
      buffer.writeln('  - 빌드 번호: ${packageInfo.buildNumber}');
      buffer.writeln('  - 패키지명: ${packageInfo.packageName}\n');

      buffer.writeln('■ 시스템 정보');
      buffer.writeln('  - 운영체제: $osInfo');
      buffer.writeln('  - OS 버전: $osVersion');
      buffer.writeln('  - CPU 코어: ${Platform.numberOfProcessors}개\n');

      buffer.writeln('■ 로그 정보');
      buffer.writeln('  - 로그 디렉터리: $logDir');
      buffer.writeln('  - 현재 로그 파일: ${currentLog ?? "없음"}');
      buffer.writeln('  - 저장된 로그 파일 수: ${logFiles.length}개\n');

      if (logFiles.isNotEmpty) {
        buffer.writeln('  로그 파일 목록:');
        for (var i = 0; i < logFiles.length && i < 10; i++) {
          final file = logFiles[i];
          final stat = file.statSync();
          final sizeKB = (stat.size / 1024).toStringAsFixed(1);
          final modified = _formatDateTime(stat.modified);
          final name = file.uri.pathSegments.last;
          buffer.writeln('    ${i + 1}. $name ($sizeKB KB, $modified)');
        }
      }

      setState(() {
        _logDirectory = logDir;
        _currentLogFile = currentLog;
        _logFiles = logFiles;
        _diagnosticInfo = buffer.toString();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _diagnosticInfo = '진단 정보 수집 실패: $e';
        _isLoading = false;
      });
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _diagnosticInfo));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('진단 정보가 클립보드에 복사되었습니다'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openLogDirectory() async {
    try {
      final uri = Uri.file(_logDirectory);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그 폴더를 열 수 없습니다')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('폴더 열기 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 700,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '🔍 진단 정보',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '로그 파일과 시스템 정보를 확인하고 지원팀에 전달할 수 있습니다.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // 진단 정보 내용
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _diagnosticInfo,
                          style: const TextStyle(
                            fontFamily: 'Consolas',
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // 버튼들
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _openLogDirectory,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('로그 폴더 열기'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _copyToClipboard,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('진단 정보 복사'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
