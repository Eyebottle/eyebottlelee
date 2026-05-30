import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart'; // ValueListenable (material show-list 미포함)
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:window_manager/window_manager.dart';

import '../../main.dart' show gStartedInBackground; // 백그라운드 시작 플래그
import '../../services/auto_launch_service.dart';
import '../../services/auto_launch_manager_service.dart';
import '../../models/mic_diagnostic_result.dart';
import '../../models/schedule_model.dart';
import '../../services/audio_service.dart';
import '../../services/logging_service.dart';
import '../../services/schedule_service.dart';
import '../../services/settings_service.dart';
import '../../services/tray_service.dart';
import '../../services/window_taskbar_service.dart';
import '../../services/mic_diagnostics_service.dart';
import '../widgets/advanced_settings_dialog.dart';
import '../widgets/animated_volume_meter.dart';
import '../widgets/schedule/schedule_config_widget_v2.dart';
import '../widgets/help/help_center_dialog.dart';
import '../widgets/launch_manager_widget.dart';
import '../widgets/diagnostic_info_dialog.dart';
import '../../models/recording_profile.dart';
import '../style/app_colors.dart';

// 위젯/다이얼로그는 같은 라이브러리의 part 파일로 분리(가독성). private 심볼·임포트 공유.
part 'main_screen_dashboard.dart';
part 'main_screen_tabs.dart';
part 'main_screen_diagnostics.dart';

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
  // 볼륨 파형 히스토리. ValueNotifier로 분리해 녹음 중 파형 갱신이 화면 전체를
  // setState로 리빌드하지 않도록 한다(_DashboardTab은 ValueListenableBuilder로 소비).
  final ValueNotifier<List<double>> _volumeHistory =
      ValueNotifier<List<double>>(const []);
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
  bool _startMinimizedOnBoot = false;
  bool _autoLaunchEnabled = false; // 자동 실행 매니저 (별도 기능)
  bool _isPackaged = false;
  String? _packageFamilyName;
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
      // 백그라운드로 시작한 경우에는 skipTaskbar 상태 유지
      // (main.dart에서 setSkipTaskbar(true)로 설정됨)
      if (!gStartedInBackground) {
        await WindowTaskbarService().setTaskbarVisible(true);
      } else {
        // v1.3.17: native main.cpp가 --autostart일 때 Show()를 호출하지 않으므로
        // 평상시엔 여기서 isVisible=false 입니다. 아래는 위젯 트리 빌드 과정에서
        // 드물게 창이 다시 떠오르는 경우를 대비한 안전망(backup)이며, 정상
        // 경로에서는 발동하지 않습니다. (이전 v1.3.11 race 대응 코드의 잔존)
        final isVisible = await windowManager.isVisible();
        if (isVisible) {
          _loggingService.info(
              'initServices: 백그라운드 시작인데 창이 보임 감지(안전망 발동), 재숨김 처리');
          await windowManager.hide();
          await windowManager.setSkipTaskbar(true);
        }
      }
      _loggingService
          .info('Window init: gStartedInBackground=$gStartedInBackground');
    } catch (e, stackTrace) {
      _loggingService.warning('창 닫힘 방지 초기화 실패',
          error: e, stackTrace: stackTrace);
    }

    // v1.3.16: WinRT StartupTask API로 자동 실행 상태 확인
    try {
      await AutoLaunchService().applySavedPreference();

      // Fetch startup status snapshot for diagnostics
      final statusSnapshot = await AutoLaunchService().getStatusSnapshot();
      if (mounted) {
        setState(() {
          _isPackaged = statusSnapshot.isPackaged;
          _packageFamilyName = statusSnapshot.packageFamilyName;
          _autoLaunchEnabled = statusSnapshot.startupTaskEnabled;
        });
      }
    } catch (e, stackTrace) {
      _loggingService.warning('자동 실행 설정 읽기 실패',
          error: e, stackTrace: stackTrace);
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
      // 파형만 갱신(setState 없음) — 녹음 중 초당 ~5회 전체 트리 리빌드 제거.
      final sample = level.clamp(0.0, 1.0);
      final history = List<double>.from(_volumeHistory.value)..add(sample);
      _volumeHistory.value = history.length > _volumeHistoryLimit
          ? history.sublist(history.length - _volumeHistoryLimit)
          : history;
    };

    _audioService.onFileSegmentCreated = (filePath) {
      if (!mounted) return;
      // context 사용 전 안전하게 microtask로 지연
      Future.microtask(() {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('분할 저장됨: ${filePath.split('/').last}')),
        );
      });
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

    final startMinimized = await _settings.getStartMinimizedOnBoot();
    if (mounted) {
      setState(() {
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
      _trayService.onOpenHelp = () {
        if (!mounted) return;
        HelpCenterDialog.show(
          context,
          onStartDashboardTutorial: _startDashboardTutorial,
          onStartSettingsTutorial: _startSettingsTutorial,
          onStartAutoLaunchTutorial: _startAutoLaunchTutorial,
        );
      };
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
      _loggingService.warning('초기 마이크 진단 실패', error: e, stackTrace: stackTrace);
      // 마이크 진단 실패는 치명적이지 않으므로 앱 계속 실행
    }
  }

  @override
  void dispose() {
    _sessionTicker?.cancel();
    _autoLaunchDelayTimer?.cancel();
    _tabController.dispose();
    _volumeHistory.dispose();
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
                        launchAtStartup: _autoLaunchEnabled, // WinRT StartupTask 상태
                        startMinimizedOnBoot: _startMinimizedOnBoot,
                        retentionDuration: _retentionDuration,
                        recordingProfile: _recordingProfile,
                        makeupGainDb: _makeupGainDb,
                        startupStatusMismatch: false,
                        onShowStartupDiagnostics: _showStartupDiagnostics,
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
      final startMinimized = await _settings.getStartMinimizedOnBoot();
      if (mounted) {
        setState(() {
          _startMinimizedOnBoot = startMinimized;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Windows 시작 설정이 저장되었습니다')),
        );
      }
    }
  }

  void _showStartupDiagnostics() async {
    // Get log path from logging service
    String logPath;
    try {
      logPath = await _loggingService.getLogDirectoryPath();
    } catch (_) {
      logPath = r'C:\Users\<user>\Documents\EyebottleRecorder\logs';
    }

    if (!mounted) return;
    StartupDiagnosticsDialog.show(
      context,
      expectedEnabled: true, // Windows StartupTask로 관리
      actualEnabled: null, // OS 상태 직접 확인 불가 (네이티브 API 제거)
      isPackaged: _isPackaged,
      packageFamilyName: _packageFamilyName,
      logPath: logPath,
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
      await WindowTaskbarService().showMainWindow();

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
      await WindowTaskbarService().setTaskbarVisible(true);
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
      await WindowTaskbarService().hideToTray();
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

    MicDiagnosticResult result;
    try {
      result = await _micDiagnosticsService.runDiagnostic();
    } catch (e, stackTrace) {
      _loggingService.error('마이크 진단 중 예외 발생', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() => _micDiagnosticRunning = false);
      }
      if (!initial && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('마이크 진단 실패: $e')),
        );
      }
      return;
    }
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
