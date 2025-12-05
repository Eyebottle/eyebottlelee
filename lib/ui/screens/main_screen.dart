import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:window_manager/window_manager.dart';

import '../../services/auto_launch_service.dart';
import '../../services/auto_launch_manager_service.dart';
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
import '../widgets/schedule/schedule_config_widget_v2.dart';
import '../widgets/help/help_center_dialog.dart';
import '../widgets/launch_manager_widget.dart';
import '../widgets/diagnostic_info_dialog.dart';
import '../../models/recording_profile.dart';
import '../style/app_colors.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin, WindowListener {
  static const _volumeHistoryLimit = 48;

  final AudioService _audioService = AudioService();
  final ScheduleService _scheduleService = ScheduleService();
  final SettingsService _settings = SettingsService();
  final TrayService _trayService = TrayService();
  final LoggingService _loggingService = LoggingService();
  final MicDiagnosticsService _micDiagnosticsService = MicDiagnosticsService();
  final AutoLaunchManagerService _autoLaunchManagerService =
      AutoLaunchManagerService();

  final GlobalKey _tutorialRecordingKey = GlobalKey();
  final GlobalKey _tutorialDiagnosticKey = GlobalKey();
  final GlobalKey _tutorialScheduleKey = GlobalKey();
  final GlobalKey _tutorialTrayKey = GlobalKey();
  final GlobalKey _settingsScheduleKey = GlobalKey();
  final GlobalKey _settingsSaveKey = GlobalKey();
  final GlobalKey _settingsRetentionKey = GlobalKey();
  final GlobalKey _settingsVadKey = GlobalKey();
  final GlobalKey _settingsAudioQualityKey = GlobalKey();
  final GlobalKey _launchSwitchKey = GlobalKey();
  final GlobalKey _launchAddButtonKey = GlobalKey();
  final GlobalKey _launchTestButtonKey = GlobalKey();

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
  bool _vadEnabled = true;
  bool _autoLaunchEnabled = false;
  bool _startMinimizedOnBoot = false;
  Duration? _retentionDuration;
  RecordingQualityProfile _recordingProfile = RecordingQualityProfile.balanced;
  double _makeupGainDb = 0.0;
  bool _hasShownTrayReminder = false;
  bool _isHiddenToTray = false;
  bool _isHidingToTray = false; // 트레이 숨김 진행 중 플래그
  bool _shutdownRequested = false;
  Timer? _autoLaunchDelayTimer; // 자동 실행 매니저 지연 타이머

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _tabController = TabController(length: 3, vsync: this);
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

    try {
      await windowManager.setPreventClose(true);
      await windowManager.setSkipTaskbar(false);
    } catch (e, stackTrace) {
      _loggingService.warning('창 닫힘 방지 초기화 실패',
          error: e, stackTrace: stackTrace);
    }

    try {
      await AutoLaunchService().applySavedPreference();
    } catch (e, stackTrace) {
      _loggingService.warning('자동 실행 설정 동기화 실패',
          error: e, stackTrace: stackTrace);
      if (mounted) {
        Future.microtask(() {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('자동 실행 설정을 동기화하지 못했습니다: $e')),
          );
        });
      }
    }

    // 자동 실행 매니저 초기화 및 프로그램 실행
    try {
      final launchManagerSettings =
          await _autoLaunchManagerService.loadSettings();
      if (launchManagerSettings.autoLaunchEnabled &&
          launchManagerSettings.enabledPrograms.isNotEmpty) {
        // 앱 시작 5초 후에 프로그램 자동 실행
        _autoLaunchDelayTimer = Timer(const Duration(seconds: 5), () async {
          if (!mounted) return;
          try {
            await _autoLaunchManagerService.executePrograms();
          } catch (e, stackTrace) {
            _loggingService.warning('자동 실행 매니저 실행 실패',
                error: e, stackTrace: stackTrace);
          }
        });
      }
    } catch (e, stackTrace) {
      _loggingService.warning('자동 실행 매니저 초기화 실패',
          error: e, stackTrace: stackTrace);
    }

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
      unawaited(_trayService.setRecordingState(true));
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
      unawaited(_trayService.setRecordingState(false));
      await _recordSessionDuration(startTime, stopTime);
    };

    _scheduleService.onRecordingStart =
        () => _startRecording(showFeedback: false);
    _scheduleService.onRecordingStop =
        () => _stopRecording(showFeedback: false);

    final savedSchedule = await _settings.loadSchedule();
    final schedule = savedSchedule ?? WeeklySchedule.defaultSchedule();
    await _scheduleService.applySchedule(schedule);
    if (mounted) {
      setState(() => _currentSchedule = schedule);
    }

    final (vadEnabled, vadThreshold) = await _settings.getVad();
    _audioService.configureVad(enabled: vadEnabled, threshold: vadThreshold);
    if (mounted) {
      setState(() {
        _vadEnabled = vadEnabled;
      });
    }

    final profile = await _settings.getRecordingProfile();
    _audioService.configureRecordingProfile(profile);
    final gainDb = await _settings.getMakeupGainDb();
    _audioService.configureMakeupGain(gainDb);
    if (mounted) {
      setState(() {
        _recordingProfile = profile;
        _makeupGainDb = gainDb;
      });
    }

    final retention = await _settings.getRetentionDuration();
    _audioService.configureRetention(retention);
    if (mounted) {
      setState(() {
        _retentionDuration = retention;
      });
    }

    final launchAtStartup = await _settings.getLaunchAtStartup();
    final startMinimized = await _settings.getStartMinimizedOnBoot();
    if (mounted) {
      setState(() {
        _autoLaunchEnabled = launchAtStartup;
        _startMinimizedOnBoot = startMinimized;
      });
    }

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
      _trayService.onExit = () => _handleTrayExit();
      _trayService.onRunDiagnostic = () => _runMicDiagnostic();
      _trayService.onOpenHelp = () => HelpCenterDialog.show(
            context,
            onStartDashboardTutorial: _startDashboardTutorial,
            onStartSettingsTutorial: _startSettingsTutorial,
            onStartAutoLaunchTutorial: _startAutoLaunchTutorial,
          );
      await _trayService.setRecordingState(_audioService.isRecording);
    } catch (e, stackTrace) {
      _loggingService.warning('시스템 트레이 초기화 실패 (앱은 계속 실행됨)',
          error: e, stackTrace: stackTrace);
      // 시스템 트레이 실패는 치명적이지 않으므로 앱 계속 실행
    }

    await _loadTodayRecordingDuration();
    await _syncRecordingWithSchedule(initial: true);
    await _refreshSaveFolderDisplay();

    try {
      await _runMicDiagnostic(initial: true);
    } catch (e, stackTrace) {
      _loggingService.warning('초기 마이크 진단 실패',
          error: e, stackTrace: stackTrace);
      // 마이크 진단 실패는 치명적이지 않으므로 앱 계속 실행
    }
  }

  @override
  void dispose() {
    _sessionTicker?.cancel();
    _autoLaunchDelayTimer?.cancel();
    _tabController.dispose();
    _audioService.dispose();
    _scheduleService.dispose();
    _trayService.dispose();
    _loggingService.removeErrorListener(_handleLoggingError);
    windowManager.removeListener(this);
    unawaited(windowManager.setPreventClose(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
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
                        volumeLevel: _volumeLevel,
                        volumeHistory: _volumeHistory,
                        lastDiagnostic: _lastMicDiagnostic,
                        diagnosticInProgress: _micDiagnosticRunning,
                        onRunDiagnostic: () => _runMicDiagnostic(),
                        onShowDiagnosticInfo: _showDiagnosticInfo,
                        onStartRecording: () => _startRecording(),
                        onStopRecording: () => _stopRecording(),
                        onSyncSchedule: () => _syncRecordingWithSchedule(),
                        recordingShowcaseKey: _tutorialRecordingKey,
                        diagnosticShowcaseKey: _tutorialDiagnosticKey,
                        scheduleShowcaseKey: _tutorialScheduleKey,
                        trayShowcaseKey: _tutorialTrayKey,
                      ),
                      _SettingsTab(
                        onOpenSchedule: () => _showScheduleDialog(),
                        onOpenSaveFolder: () => _showFolderDialog(),
                        onOpenVad: () => _openVadSettings(),
                        onOpenRetention: () => _openRetentionSettings(),
                        onOpenAudioQuality: () => _openAudioQualitySettings(),
                        onOpenWavConversion: () => _openWavConversionSettings(),
                        onOpenStartup: () => _openStartupSettings(),
                        scheduleShowcaseKey: _settingsScheduleKey,
                        saveFolderShowcaseKey: _settingsSaveKey,
                        retentionShowcaseKey: _settingsRetentionKey,
                        vadShowcaseKey: _settingsVadKey,
                        audioQualityShowcaseKey: _settingsAudioQualityKey,
                        saveFolder: _currentSaveFolder,
                        vadEnabled: _vadEnabled,
                        launchAtStartup: _autoLaunchEnabled,
                        startMinimizedOnBoot: _startMinimizedOnBoot,
                        retentionDuration: _retentionDuration,
                        recordingProfile: _recordingProfile,
                        makeupGainDb: _makeupGainDb,
                      ),
                      _LaunchManagerTab(
                        onAutoLaunchChanged: (enabled) {
                          setState(() => _autoLaunchEnabled = enabled);
                        },
                        switchShowcaseKey: _launchSwitchKey,
                        addButtonShowcaseKey: _launchAddButtonKey,
                        testButtonShowcaseKey: _launchTestButtonKey,
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
            color: AppColors.primary,
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
                '아이보틀 진료녹음 & 자동실행 매니저',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF101C22),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () => HelpCenterDialog.show(
            context,
            onStartDashboardTutorial: _startDashboardTutorial,
            onStartSettingsTutorial: _startSettingsTutorial,
            onStartAutoLaunchTutorial: _startAutoLaunchTutorial,
          ),
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('도움말'),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: TabBar(
        controller: _tabController,
        padding: EdgeInsets.zero,
        labelPadding: EdgeInsets.zero,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.primaryContainer,
        ),
        indicatorPadding: const EdgeInsets.all(4),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        tabs: [
          const Tab(child: Center(child: Text('녹음 대시보드'))),
          const Tab(child: Center(child: Text('녹음 설정'))),
          Tab(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('자동 실행'),
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _autoLaunchEnabled
                          ? const Color(0xFF2E7D32)
                          : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _autoLaunchEnabled ? 'ON' : 'OFF',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _autoLaunchEnabled
                          ? const Color(0xFF2E7D32)
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showScheduleDialog() async {
    await showDialog<Widget>(
      context: context,
      builder: (context) => ScheduleConfigWidgetV2(
        onSaved: () async {
          final saved = await _settings.loadSchedule();
          if (saved != null) {
            await _scheduleService.applySchedule(saved);
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
      if (mounted) {
        setState(() {
          _vadEnabled = enabled;
        });
      }
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
      if (mounted) {
        setState(() {
          _retentionDuration = retention;
        });
      }
    }
  }

  Future<void> _openAudioQualitySettings() async {
    final result = await AdvancedSettingsDialog.show(
      context,
      AdvancedSettingSection.audioQuality,
    );
    if (result == 'saved') {
      final profile = await _settings.getRecordingProfile();
      final gainDb = await _settings.getMakeupGainDb();
      _audioService.configureRecordingProfile(profile);
      _audioService.configureMakeupGain(gainDb);
      if (mounted) {
        setState(() {
          _recordingProfile = profile;
          _makeupGainDb = gainDb;
        });
      }
    }
  }

  Future<void> _openWavConversionSettings() async {
    final result = await AdvancedSettingsDialog.show(
      context,
      AdvancedSettingSection.wavConversion,
    );
    if (result == 'saved') {
      // WAV 변환 설정은 AudioService에서 매번 확인하므로
      // 여기서 별도로 설정할 것이 없습니다
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WAV 자동 변환 설정이 저장되었습니다')),
        );
      }
    }
  }

  Future<void> _openStartupSettings() async {
    final result = await AdvancedSettingsDialog.show(
      context,
      AdvancedSettingSection.startupSettings,
    );
    if (result == 'saved') {
      final launchAtStartup = await _settings.getLaunchAtStartup();
      final startMinimized = await _settings.getStartMinimizedOnBoot();
      if (mounted) {
        setState(() {
          _autoLaunchEnabled = launchAtStartup;
          _startMinimizedOnBoot = startMinimized;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Windows 시작 설정이 저장되었습니다')),
        );
      }
    }
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
      unawaited(_trayService.setRecordingState(true));
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
      unawaited(_trayService.setRecordingState(false));
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

  /// 창을 전면으로 가져오는 메서드
  ///
  /// 트레이에서 창을 복원할 때 사용됩니다.
  Future<void> _bringToFront() async {
    // 숨기는 중이면 완료될 때까지 대기
    if (_isHidingToTray) {
      _loggingService.debug('트레이 숨김 진행 중 - 완료 대기');
      // 최대 500ms 대기
      for (var i = 0; i < 10 && _isHidingToTray; i++) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    try {
      // 작업표시줄에 먼저 표시
      await windowManager.setSkipTaskbar(false);

      // 최소화 상태면 복원
      final isMinimized = await windowManager.isMinimized();
      if (isMinimized) {
        await windowManager.restore();
      }

      // 창 표시 및 포커스
      await windowManager.show();
      await windowManager.focus();

      _isHiddenToTray = false;
      _loggingService.info('창이 전면으로 복원되었습니다.');
    } catch (e, stackTrace) {
      _loggingService.warning('창 포커스 이동 실패', error: e, stackTrace: stackTrace);
    }
  }

  void _handleTrayExit() {
    if (_shutdownRequested) return;
    _shutdownRequested = true;

    () async {
      try {
        if (_audioService.isRecording) {
          await _stopRecording(showFeedback: false);
        }
      } catch (e, stackTrace) {
        _loggingService.error('종료 전 녹음 중지 실패',
            error: e, stackTrace: stackTrace);
      }

      windowManager.removeListener(this);
      await windowManager.setPreventClose(false);
      await windowManager.setSkipTaskbar(false);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      try {
        await windowManager.close();
      } catch (e, stackTrace) {
        _loggingService.error('창 종료 실패', error: e, stackTrace: stackTrace);
      }
    }();
  }

  @override
  void onWindowClose() {
    // 이미 종료 요청되었거나 숨김 진행 중이면 무시
    if (_shutdownRequested || _isHidingToTray || _isHiddenToTray) {
      return;
    }

    // 트레이로 숨기기 시작
    _hideToTray();
  }

  /// 창을 트레이로 숨기는 메서드
  ///
  /// 비동기 작업을 안전하게 처리하고 상태를 정확히 관리합니다.
  Future<void> _hideToTray() async {
    if (_isHidingToTray || _isHiddenToTray) return;
    _isHidingToTray = true;

    try {
      // 먼저 창을 숨기고, 그 다음 작업표시줄에서 제거
      await windowManager.hide();
      await windowManager.setSkipTaskbar(true);
      _isHiddenToTray = true;
      _loggingService.info('창이 트레이로 숨겨졌습니다.');

      // 첫 번째 트레이 숨김 시 시스템 알림 표시 (SnackBar 대신 트레이 알림)
      if (!_hasShownTrayReminder) {
        _hasShownTrayReminder = true;
        await _trayService.showNotification(
          '아이보틀 진료녹음',
          '앱이 백그라운드에서 계속 실행됩니다. 트레이 아이콘으로 다시 열 수 있어요.',
        );
      }
    } catch (e, stackTrace) {
      _loggingService.error('창 숨김 실패', error: e, stackTrace: stackTrace);
      // 실패 시 상태 복구
      _isHiddenToTray = false;
    } finally {
      _isHidingToTray = false;
    }
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

  void _startDashboardTutorial() {
    final showCase = ShowCaseWidget.of(context);
    if (showCase == null) return;

    if (_tabController.index != 0) {
      _tabController.animateTo(0);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showCase.startShowCase([
        _tutorialRecordingKey,
        _tutorialDiagnosticKey,
        _tutorialScheduleKey,
        _tutorialTrayKey,
      ]);
    });
  }

  void _startSettingsTutorial() {
    final showCase = ShowCaseWidget.of(context);
    if (showCase == null) return;

    void startShowcase() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showCase.startShowCase([
          _settingsScheduleKey,
          _settingsSaveKey,
          _settingsRetentionKey,
          _settingsAudioQualityKey,
          _settingsVadKey,
        ]);
      });
    }

    if (_tabController.index != 1) {
      _tabController.animateTo(1);
      Future.delayed(const Duration(milliseconds: 300), startShowcase);
    } else {
      startShowcase();
    }
  }

  void _startAutoLaunchTutorial() {
    final showCase = ShowCaseWidget.of(context);
    if (showCase == null) return;

    void startShowcase() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showCase.startShowCase([
          _launchSwitchKey,
          _launchAddButtonKey,
          _launchTestButtonKey,
        ]);
      });
    }

    if (_tabController.index != 2) {
      _tabController.animateTo(2);
      Future.delayed(const Duration(milliseconds: 300), startShowcase);
    } else {
      startShowcase();
    }
  }

  Future<void> _syncRecordingWithSchedule({bool initial = false}) async {
    final shouldRecord = _scheduleService.isCurrentlyWorkingTime();

    if (shouldRecord && !_audioService.isRecording) {
      await _startRecording(showFeedback: !initial);
    } else if (!shouldRecord && _audioService.isRecording) {
      await _stopRecording(showFeedback: !initial);
    }
  }

  void _showDiagnosticInfo() {
    showDialog(
      context: context,
      builder: (context) => const DiagnosticInfoDialog(),
    );
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
      'Mic diagnostic result: ${result.status.name} (signalDb=${result.peakDb?.toStringAsFixed(1) ?? 'n/a'}, snr=${result.snrDb?.toStringAsFixed(1) ?? 'n/a'})',
    );
    await _settings.saveMicDiagnosticResult(result);
    if (mounted) {
      setState(() {
        _lastMicDiagnostic = result;
        _micDiagnosticRunning = false;
      });
    }

    if (!initial && mounted) {
      // 에러 상태 확인
      final bool hasIssue = result.status == MicDiagnosticStatus.failure ||
          result.status == MicDiagnosticStatus.noSignal ||
          result.status == MicDiagnosticStatus.lowInput ||
          result.status == MicDiagnosticStatus.permissionDenied ||
          result.status == MicDiagnosticStatus.noInputDevice;

      if (hasIssue) {
        // 에러 발생: 로그 확인 안내
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '마이크 문제가 감지되었습니다. 아래 "📋 에러 로그 확인" 버튼을 눌러 로그를 수집해주세요.',
            ),
            backgroundColor: const Color(0xFFFF6B6B),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '확인',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      } else {
        // 정상: 일반 완료 메시지
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? '마이크 점검이 완료되었습니다.')),
        );
      }
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
        color: const Color(0xFF0F7ABF).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0F7ABF).withOpacity(0.25)),
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
        color: color.withOpacity(0.12),
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
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
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
                      : AppColors.textSecondary.withOpacity(0.12),
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
