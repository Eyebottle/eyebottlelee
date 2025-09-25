import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../models/mic_diagnostic_result.dart';
import '../../models/schedule_model.dart';
import '../../services/audio_service.dart';
import '../../services/logging_service.dart';
import '../../services/schedule_service.dart';
import '../../services/settings_service.dart';
import '../../services/tray_service.dart';
import '../../services/mic_diagnostics_service.dart';
import '../widgets/advanced_settings_dialog.dart';
import '../widgets/animated_volume_meter.dart';
import '../widgets/schedule_config_widget.dart';

const _backgroundColor = Color(0xFFF6F7F8);
const _primaryColor = Color(0xFF1193D4);
const _textMuted = Color(0xFF4A5860);
const _cardBorder = Color(0xFFE7EFF3);

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  static const _volumeHistoryLimit = 48;

  final AudioService _audioService = AudioService();
  final ScheduleService _scheduleService = ScheduleService();
  final SettingsService _settings = SettingsService();
  final TrayService _trayService = TrayService();
  final LoggingService _loggingService = LoggingService();
  final MicDiagnosticsService _micDiagnosticsService = MicDiagnosticsService();

  late final TabController _tabController;

  bool _isRecording = false;
  double _volumeLevel = 0.0;
  List<double> _volumeHistory = const [];
  String _todayRecordingTime = '0시간 0분';
  Duration _todayDuration = Duration.zero;
  DateTime? _currentSessionStart;
  Timer? _sessionTicker;
  String _currentDayKey = '';
  String _currentSaveFolder = '경로 확인 중...';
  WeeklySchedule? _currentSchedule;
  MicDiagnosticResult? _lastMicDiagnostic;
  bool _micDiagnosticRunning = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _loggingService.ensureInitialized();
    } catch (e) {
      if (mounted) {
        Future.microtask(() {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('로그 초기화 실패: $e')),
          );
        });
      }
    }
    _loggingService.addErrorListener(_handleLoggingError);

    _audioService.onAmplitudeChanged = (level) {
      if (!mounted) return;
      setState(() {
        _volumeLevel = level.clamp(0.0, 1.0);
        final history = List<double>.from(_volumeHistory)..add(_volumeLevel);
        _volumeHistory = history.length > _volumeHistoryLimit
            ? history.sublist(history.length - _volumeHistoryLimit)
            : history;
      });
    };

    _audioService.onFileSegmentCreated = (filePath) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('분할 저장됨: ${filePath.split('/').last}')),
      );
    };

    _audioService.onRecordingStarted = (startTime) {
      if (!mounted) return;
      setState(() {
        _currentSessionStart = startTime;
        _isRecording = true;
      });
      _startSessionTicker();
      _updateTodayRecordingDisplay();
    };

    _audioService.onRecordingStopped =
        (startTime, stopTime, recordedDuration) async {
      _sessionTicker?.cancel();
      _sessionTicker = null;
      if (mounted) {
        setState(() {
          _currentSessionStart = null;
          _isRecording = false;
        });
      }
      await _recordSessionDuration(startTime, stopTime);
    };

    _scheduleService.onRecordingStart =
        () => _startRecording(showFeedback: false);
    _scheduleService.onRecordingStop =
        () => _stopRecording(showFeedback: false);

    final savedSchedule = await _settings.loadSchedule();
    final schedule = savedSchedule ?? WeeklySchedule.defaultSchedule();
    _scheduleService.applySchedule(schedule);
    if (mounted) {
      setState(() => _currentSchedule = schedule);
    }

    final (vadEnabled, vadThreshold) = await _settings.getVad();
    _audioService.configureVad(enabled: vadEnabled, threshold: vadThreshold);

    final retention = await _settings.getRetentionDuration();
    _audioService.configureRetention(retention);

    final storedDiagnostic = await _settings.loadMicDiagnosticResult();
    if (mounted) {
      setState(() {
        _lastMicDiagnostic = storedDiagnostic;
      });
    }

    try {
      await _trayService.initialize();
      _trayService.onStartRecording = () => _startRecording();
      _trayService.onStopRecording = () => _stopRecording();
      _trayService.onShowWindow = () => _bringToFront();
    } catch (_) {}

    await _loadTodayRecordingDuration();
    await _syncRecordingWithSchedule(initial: true);
    await _refreshSaveFolderDisplay();
    await _runMicDiagnostic(initial: true);
  }

  @override
  void dispose() {
    _sessionTicker?.cancel();
    _tabController.dispose();
    _audioService.dispose();
    _trayService.dispose();
    _loggingService.removeErrorListener(_handleLoggingError);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 620,
              maxWidth: 960,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: _buildHeader(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildTabBar(),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _DashboardTab(
                        isRecording: _isRecording,
                        todayRecordingTime: _todayRecordingTime,
                        plannedSessions: _plannedSessionsForToday(),
                        saveFolder: _currentSaveFolder,
                        volumeLevel: _volumeLevel,
                        volumeHistory: _volumeHistory,
                        lastDiagnostic: _lastMicDiagnostic,
                        diagnosticInProgress: _micDiagnosticRunning,
                        onRunDiagnostic: () => _runMicDiagnostic(),
                        onStartRecording: () => _startRecording(),
                        onPauseRecording: () => _pauseRecording(),
                        onStopRecording: () => _stopRecording(),
                        onSyncSchedule: () => _syncRecordingWithSchedule(),
                      ),
                      _SettingsTab(
                        onOpenSchedule: () => _showScheduleDialog(),
                        onOpenSaveFolder: () => _showFolderDialog(),
                        onOpenVad: () => _openVadSettings(),
                        onOpenRetention: () => _openRetentionSettings(),
                        onOpenAutoLaunch: () => _openAutoLaunchSettings(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final subtitle = _isRecording ? '녹음이 진행 중입니다' : '대시보드에서 상태를 확인하세요';
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _primaryColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.mic_none, color: Colors.white),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '아이보틀 진료 녹음기',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF101C22),
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: _textMuted,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('사용법은 준비 중입니다.')),
            );
          },
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('사용법'),
          style: TextButton.styleFrom(foregroundColor: _primaryColor),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: TabBar(
        controller: _tabController,
        padding: EdgeInsets.zero,
        labelPadding: EdgeInsets.zero,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _primaryColor.withAlpha((0.12 * 255).round()),
        ),
        indicatorPadding: const EdgeInsets.all(4),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: _primaryColor,
        unselectedLabelColor: _textMuted,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        tabs: const [
          Tab(child: Center(child: Text('대시보드'))),
          Tab(child: Center(child: Text('설정'))),
        ],
      ),
    );
  }

  Future<void> _showScheduleDialog() async {
    await showDialog<Widget>(
      context: context,
      builder: (context) => ScheduleConfigWidget(
        onSaved: () async {
          final saved = await _settings.loadSchedule();
          if (saved != null) {
            _scheduleService.applySchedule(saved);
            if (mounted) {
              setState(() => _currentSchedule = saved);
            }
            await _syncRecordingWithSchedule(initial: false);
          }
        },
      ),
    );
  }

  Future<void> _showFolderDialog() async {
    final selectedPath = await getDirectoryPath();
    if (selectedPath != null) {
      await _settings.setSaveFolder(selectedPath);
      await _refreshSaveFolderDisplay();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 폴더가 설정되었습니다: $selectedPath')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('폴더 선택이 취소되었습니다. 다시 시도해주세요.')),
    );
  }

  Future<void> _openVadSettings() async {
    final result = await AdvancedSettingsDialog.show(
      context,
      AdvancedSettingSection.vad,
    );
    if (result == 'saved') {
      final (enabled, threshold) = await _settings.getVad();
      _audioService.configureVad(enabled: enabled, threshold: threshold);
    }
  }

  Future<void> _openRetentionSettings() async {
    final result = await AdvancedSettingsDialog.show(
      context,
      AdvancedSettingSection.retention,
    );
    if (result == 'saved') {
      final retention = await _settings.getRetentionDuration();
      _audioService.configureRetention(retention);
    }
  }

  Future<void> _openAutoLaunchSettings() async {
    await AdvancedSettingsDialog.show(
      context,
      AdvancedSettingSection.autoLaunch,
    );
  }

  Future<void> _refreshSaveFolderDisplay() async {
    try {
      final path = await _audioService.getResolvedSaveRootPath();
      if (!mounted) return;
      setState(() {
        _currentSaveFolder = path;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentSaveFolder = '경로를 확인할 수 없습니다: $e';
      });
    }
  }

  Future<void> _startRecording({bool showFeedback = true}) async {
    if (_audioService.isRecording) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 녹음 중입니다.')),
        );
      }
      return;
    }

    try {
      await _audioService.startRecording();
      if (!mounted) return;
      setState(() {
        _isRecording = true;
      });
      unawaited(_trayService.updateTrayIcon(TrayIconState.recording));
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('녹음을 시작했습니다.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('녹음 시작 실패: $e')),
      );
    }
  }

  Future<void> _pauseRecording() async {
    if (!_audioService.isRecording) {
      return;
    }
    try {
      await _audioService.pauseRecording();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('녹음을 일시정지했습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일시정지 실패: $e')),
      );
    }
  }

  Future<void> _stopRecording({bool showFeedback = true}) async {
    if (!_audioService.isRecording) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('현재 녹음 중이 아닙니다.')),
        );
      }
      return;
    }

    try {
      await _audioService.stopRecording();
      if (!mounted) return;
      setState(() {
        _isRecording = false;
      });
      unawaited(_trayService.updateTrayIcon(TrayIconState.waiting));
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('녹음을 중지했습니다.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('녹음 중지 실패: $e')),
      );
    }
  }

  void _bringToFront() {
    () async {
      try {
        final isMinimized = await windowManager.isMinimized();
        if (isMinimized) {
          await windowManager.restore();
        }
        await windowManager.show();
        await windowManager.focus();
      } catch (e) {
        _loggingService.warning('창 포커스 이동 실패', error: e);
      }
    }();
  }

  Future<void> _loadTodayRecordingDuration() async {
    final now = DateTime.now();
    final duration = await _settings.getRecordingDuration(now);
    if (!mounted) return;
    _currentDayKey = _dayKey(now);
    setState(() {
      _todayDuration = duration;
      _todayRecordingTime =
          _formatDuration(duration + _currentRunningDuration());
    });
  }

  Future<void> _recordSessionDuration(
      DateTime startTime, DateTime stopTime) async {
    var segmentStart = startTime;
    while (segmentStart.isBefore(stopTime)) {
      final dayStart =
          DateTime(segmentStart.year, segmentStart.month, segmentStart.day);
      final nextDay = dayStart.add(const Duration(days: 1));
      final segmentEnd = stopTime.isBefore(nextDay) ? stopTime : nextDay;
      final delta = segmentEnd.difference(segmentStart);
      if (delta > Duration.zero) {
        await _settings.addRecordingDuration(segmentStart, delta);
      }
      segmentStart = segmentEnd;
    }

    await _loadTodayRecordingDuration();
  }

  void _startSessionTicker() {
    _sessionTicker?.cancel();
    _sessionTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTodayRecordingDisplay();
    });
  }

  void _updateTodayRecordingDisplay() {
    if (!mounted) return;
    final now = DateTime.now();
    if (_dayKey(now) != _currentDayKey) {
      unawaited(_loadTodayRecordingDuration());
      return;
    }
    final displayDuration = _todayDuration + _currentRunningDuration();
    setState(() {
      _todayRecordingTime = _formatDuration(displayDuration);
    });
  }

  Duration _currentRunningDuration() {
    if (_currentSessionStart == null) return Duration.zero;
    return DateTime.now().difference(_currentSessionStart!);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String _dayKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _syncRecordingWithSchedule({bool initial = false}) async {
    final shouldRecord = _scheduleService.isCurrentlyWorkingTime();

    if (shouldRecord && !_audioService.isRecording) {
      await _startRecording(showFeedback: !initial);
    } else if (!shouldRecord && _audioService.isRecording) {
      await _stopRecording(showFeedback: !initial);
    }
  }

  Future<void> _runMicDiagnostic({bool initial = false}) async {
    if (_micDiagnosticRunning) return;
    if (!initial && _audioService.isRecording) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('녹음 중에는 마이크 점검을 할 수 없습니다. 녹음을 멈추고 다시 시도하세요.'),
          ),
        );
      }
      return;
    }

    if (mounted) {
      setState(() => _micDiagnosticRunning = true);
    }

    final result = await _micDiagnosticsService.runDiagnostic();
    _loggingService.info(
      'Mic diagnostic result: ${result.status.name} (peak=${result.peakRms?.toStringAsFixed(3) ?? 'n/a'})',
    );
    await _settings.saveMicDiagnosticResult(result);
    if (mounted) {
      setState(() {
        _lastMicDiagnostic = result;
        _micDiagnosticRunning = false;
      });
    }

    if (!initial && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? '마이크 점검이 완료되었습니다.')),
      );
    }
  }

  void _handleLoggingError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    unawaited(_trayService.updateTrayIcon(TrayIconState.error));
    unawaited(_trayService.showNotification('녹음 오류', message));
  }

  List<String> _plannedSessionsForToday() {
    final schedule = _currentSchedule;
    if (schedule == null) return const [];
    final now = DateTime.now();
    final weekdayIndex = now.weekday % 7;
    final daySchedule = schedule.weekDays[weekdayIndex] ?? DaySchedule.rest();
    if (!daySchedule.isWorkingDay || daySchedule.sessions.isEmpty) {
      return const ['오늘은 녹음 일정이 없습니다.'];
    }

    final isSplit = daySchedule.sessions.length > 1;
    final lines = <String>[];
    for (var i = 0; i < daySchedule.sessions.length; i++) {
      final session = daySchedule.sessions[i];
      final prefix = isSplit
          ? (session.start.hour < 12
              ? '오전'
              : (session.start.hour < 18 ? '오후' : '세션 ${i + 1}'))
          : '세션';
      lines.add(
          '$prefix: ${_formatTime(session.start)} - ${_formatTime(session.end)}');
    }
    return lines;
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({
    required this.isRecording,
    required this.todayRecordingTime,
    required this.plannedSessions,
    required this.saveFolder,
    required this.volumeLevel,
    required this.volumeHistory,
    required this.lastDiagnostic,
    required this.diagnosticInProgress,
    required this.onRunDiagnostic,
    required this.onStartRecording,
    required this.onPauseRecording,
    required this.onStopRecording,
    required this.onSyncSchedule,
  });

  final bool isRecording;
  final String todayRecordingTime;
  final List<String> plannedSessions;
  final String saveFolder;
  final double volumeLevel;
  final List<double> volumeHistory;
  final MicDiagnosticResult? lastDiagnostic;
  final bool diagnosticInProgress;
  final Future<void> Function() onRunDiagnostic;
  final Future<void> Function() onStartRecording;
  final Future<void> Function() onPauseRecording;
  final Future<void> Function() onStopRecording;
  final Future<void> Function() onSyncSchedule;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDiagnosticCard(context),
          const SizedBox(height: 16),
          _buildRecordingCard(context),
          const SizedBox(height: 16),
          _buildInfoCard(context),
        ],
      ),
    );
  }

  Widget _buildDiagnosticCard(BuildContext context) {
    final theme = Theme.of(context);
    final diagnostic = lastDiagnostic;
    final status = diagnostic?.status;

    final (Color badgeColor, IconData badgeIcon, String badgeText) = switch (status) {
      MicDiagnosticStatus.ok => (const Color(0xFF2E7D32), Icons.check_circle, '마이크 정상'),
      MicDiagnosticStatus.lowInput =>
        (const Color(0xFFFFA000), Icons.hearing, '입력이 약함'),
      MicDiagnosticStatus.permissionDenied =>
        (const Color(0xFFD32F2F), Icons.lock, '권한 필요'),
      MicDiagnosticStatus.noInputDevice =>
        (const Color(0xFFD32F2F), Icons.headset_off, '장치 없음'),
      MicDiagnosticStatus.recorderBusy =>
        (const Color(0xFFFF7043), Icons.pause_circle, '녹음 중'),
      MicDiagnosticStatus.failure =>
        (const Color(0xFFD32F2F), Icons.error, '점검 실패'),
      null => (const Color(0xFF546E7A), Icons.mic, '점검 대기'),
    };

    final message = diagnostic?.message ??
        '창이 열릴 때 자동으로 마이크 상태를 확인합니다. "다시 점검"을 눌러 수동으로 점검할 수 있어요.';
    final hints = diagnostic?.hints ?? const <String>[];
    final peak = diagnostic?.peakRms;
    final lastTimeText = diagnostic == null
        ? '최근 기록 없음'
        : '최근 점검: ${_formatDateTime(diagnostic.timestamp)}';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(badgeIcon, color: badgeColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      badgeText,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: badgeColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                lastTimeText,
                style: theme.textTheme.bodySmall?.copyWith(color: _textMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(color: _textMuted),
          ),
          if (peak != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Text(
                    '최고 입력 레벨',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: peak.clamp(0.0, 1.0),
                        backgroundColor: const Color(0xFFE8EEF2),
                        color: badgeColor,
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${(peak * 100).clamp(0, 100).toStringAsFixed(0)}%'),
                ],
              ),
            ),
          if (hints.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '다음 단계를 확인해 보세요:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...hints.map(
                    (hint) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(
                            child: Text(
                              hint,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              FilledButton.icon(
                onPressed: diagnosticInProgress ? null : onRunDiagnostic,
                icon: const Icon(Icons.refresh),
                label: Text(diagnosticInProgress ? '점검 중...' : '다시 점검'),
              ),
              if (diagnosticInProgress) ...[
                const SizedBox(width: 16),
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }

  Widget _buildRecordingCard(BuildContext context) {
    final theme = Theme.of(context);
    final statusText = isRecording ? '녹음 진행 중' : '대기 중';
    final statusColor = isRecording ? _primaryColor : _textMuted;
    final indicatorColor = isRecording ? _primaryColor : _textMuted;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
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
          Column(
            children: [
              Text(
                statusText,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LiveIndicator(color: indicatorColor),
                  const SizedBox(width: 8),
                  Text(
                    isRecording ? '실시간' : '대기 중',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: indicatorColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          AnimatedVolumeMeter(
            history: volumeHistory,
            maxHeight: 120,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  title: '오늘의 녹음 시간',
                  value: todayRecordingTime,
                  alignment: TextAlign.left,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SummaryTile(
                  title: '예정 녹음 시간',
                  valueLines: plannedSessions,
                  alignment: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
                      onPressed: isRecording ? () => onPauseRecording() : null,
                      icon: const Icon(Icons.pause),
                      label: const Text('일시정지'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: _textMuted,
                        disabledForegroundColor:
                            _textMuted.withAlpha((0.4 * 255).round()),
                      ),
                    ),
                  ),
                  SizedBox(
                    width:
                        isWide ? constraints.maxWidth / 2 - 8 : double.infinity,
                    child: FilledButton.icon(
                      onPressed: () =>
                          isRecording ? onStopRecording() : onStartRecording(),
                      icon: Icon(
                          isRecording ? Icons.stop : Icons.fiber_manual_record),
                      label: Text(isRecording ? '중지' : '녹음 시작'),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            isRecording ? Colors.redAccent : _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: () => onSyncSchedule(),
              icon: const Icon(Icons.sync),
              label: const Text('스케줄과 동기화'),
              style: TextButton.styleFrom(
                foregroundColor: _primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '저장 위치',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF101C22),
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            saveFolder,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '녹음 파일은 날짜별 하위 폴더에 자동 정리됩니다.',
            style: theme.textTheme.bodySmall?.copyWith(color: _textMuted),
          ),
        ],
      ),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({
    required this.onOpenSchedule,
    required this.onOpenSaveFolder,
    required this.onOpenVad,
    required this.onOpenRetention,
    required this.onOpenAutoLaunch,
  });

  final Future<void> Function() onOpenSchedule;
  final Future<void> Function() onOpenSaveFolder;
  final Future<void> Function() onOpenVad;
  final Future<void> Function() onOpenRetention;
  final Future<void> Function() onOpenAutoLaunch;

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
                title: '스케줄 설정',
                description: '진료/녹음 시간을 관리합니다.',
                onTap: onOpenSchedule,
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
                description: '녹음 파일 저장 폴더를 변경합니다.',
                onTap: onOpenSaveFolder,
              ),
              SettingsDestination(
                icon: Icons.history,
                title: '저장 기간',
                description: '녹음 파일의 보관 기간을 설정합니다.',
                onTap: onOpenRetention,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: '고급 설정',
            items: [
              SettingsDestination(
                icon: Icons.mic,
                title: '음성 활동 감지 (VAD)',
                description: '음성이 감지될 때만 녹음하도록 설정합니다.',
                onTap: onOpenVad,
              ),
              SettingsDestination(
                icon: Icons.play_circle,
                title: '윈도우 시작 시 자동 실행',
                description: '컴퓨터 시작 시 앱을 자동으로 실행합니다.',
                onTap: onOpenAutoLaunch,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SettingsDestination {
  SettingsDestination({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Future<void> Function() onTap;
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
        border: Border.all(color: _cardBorder),
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
          ...items.map((item) => _SettingsTile(item: item)).toList(),
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
    return InkWell(
      onTap: () => item.onTap(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _primaryColor.withAlpha((0.12 * 255).round()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: _primaryColor),
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
                      color: _textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _textMuted),
          ],
        ),
      ),
    );
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
            color: _textMuted,
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
