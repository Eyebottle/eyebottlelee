import 'dart:async';
import 'package:flutter/material.dart';

import '../../models/schedule_model.dart';
import '../../services/audio_service.dart';
import '../../services/schedule_service.dart';
import '../../services/settings_service.dart';
import '../../services/tray_service.dart';
import '../../services/logging_service.dart';
import '../widgets/recording_status_widget.dart';
import '../widgets/schedule_config_widget.dart';
import '../widgets/volume_meter_widget.dart';
import '../widgets/advanced_settings_dialog.dart';
import 'package:file_selector/file_selector.dart';


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final AudioService _audioService = AudioService();
  final ScheduleService _scheduleService = ScheduleService();
  final SettingsService _settings = SettingsService();
  final TrayService _trayService = TrayService();
  final LoggingService _loggingService = LoggingService();

  bool _isRecording = false;
  double _volumeLevel = 0.0;
  String _todayRecordingTime = '0시간 0분';
  Duration _todayDuration = Duration.zero;
  DateTime? _currentSessionStart;
  Timer? _sessionTicker;
  String _currentDayKey = '';

  @override
  void initState() {
    super.initState();
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

    // 오디오 레벨 콜백 → UI 반영
    _audioService.onAmplitudeChanged = (level) {
      if (!mounted) return;
      setState(() => _volumeLevel = level.clamp(0.0, 1.0));
    };

    // 세그먼트 파일 생성 콜백 (선택적 안내)
    _audioService.onFileSegmentCreated = (filePath) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('분할 저장됨: ${filePath.split('/').last}')),
      );
    };

    _audioService.onRecordingStarted = (startTime) {
      _currentSessionStart = startTime;
      _startSessionTicker();
      _updateTodayRecordingDisplay();
    };

    _audioService.onRecordingStopped = (startTime, stopTime, recordedDuration) async {
      _sessionTicker?.cancel();
      _sessionTicker = null;
      _currentSessionStart = null;
      await _recordSessionDuration(startTime, stopTime);
    };

    // 스케줄 서비스: 자동 시작/종료 연동
    _scheduleService.onRecordingStart = () => _startRecording();
    _scheduleService.onRecordingStop = () => _stopRecording();

    // 저장된 스케줄을 우선 적용, 없으면 기본값
    final saved = await _settings.loadSchedule();
    final schedule = saved ?? WeeklySchedule.defaultSchedule();
    _scheduleService.applySchedule(schedule);

    // VAD 설정 적용
    final (vadEnabled, vadThreshold) = await _settings.getVad();
    _audioService.configureVad(enabled: vadEnabled, threshold: vadThreshold);

    // 트레이 초기화 (아이콘 파일이 없으면 내부적으로 실패할 수 있음 → 무시)
    try {
      await _trayService.initialize();
      _trayService.onStartRecording = () => _startRecording();
      _trayService.onStopRecording = () => _stopRecording();
      _trayService.onShowWindow = () => _bringToFront();
    } catch (_) {}

    await _loadTodayRecordingDuration();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('아이보틀 진료 녹음'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 녹음 상태 표시
            RecordingStatusWidget(
              isRecording: _isRecording,
              startTime: _isRecording ? DateTime.now() : null,
            ),
            const SizedBox(height: 16),

            // 볼륨 레벨 미터
            VolumeMeterWidget(volumeLevel: _volumeLevel),
            const SizedBox(height: 16),

            // 오늘 녹음 시간 (추후 계산 로직 연결 예정)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.storage, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      '오늘 녹음: $_todayRecordingTime',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 설정 버튼들
            ElevatedButton.icon(
              onPressed: () => _showScheduleDialog(),
              icon: const Icon(Icons.calendar_today),
              label: const Text('진료 시간표 설정'),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: () => _showFolderDialog(),
              icon: const Icon(Icons.folder),
              label: const Text('저장 폴더 설정'),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: () => _showAdvancedSettings(),
              icon: const Icon(Icons.settings),
              label: const Text('고급 설정'),
            ),
            const SizedBox(height: 32),

            // 제어 버튼들
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isRecording ? _pauseRecording : null,
                  child: const Text('일시정지'),
                ),
                ElevatedButton(
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecording
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_isRecording ? '중지' : '시작'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showScheduleDialog() {
    showDialog(
      context: context,
      builder: (context) => ScheduleConfigWidget(
        onSaved: () async {
          // 저장된 스케줄 재적용
          final saved = await _settings.loadSchedule();
          if (saved != null) {
            _scheduleService.applySchedule(saved);
          }
        },
      ),
    );
  }

  Future<void> _showFolderDialog() async {
    final selectedPath = await getDirectoryPath();
    if (selectedPath != null) {
      await _settings.setSaveFolder(selectedPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 폴더가 설정되었습니다: ' + selectedPath)),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('폴더 선택이 취소되었습니다. 다시 시도해주세요.')),
    );
  }


  Future<void> _showAdvancedSettings() async {
    final result = await showDialog(
      context: context,
      builder: (context) => const AdvancedSettingsDialog(),
    );
    if (result == 'saved') {
      final (enabled, threshold) = await _settings.getVad();
      _audioService.configureVad(enabled: enabled, threshold: threshold);
    }
  }

  Future<void> _startRecording() async {
    try {
      await _audioService.startRecording();
      if (!mounted) return;
      setState(() {
        _isRecording = true;
      });
      unawaited(_trayService.updateTrayIcon(TrayIconState.recording));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('녹음을 시작했습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('녹음 시작 실패: $e')),
      );
    }
  }

  Future<void> _pauseRecording() async {
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

  Future<void> _stopRecording() async {
    try {
      await _audioService.stopRecording();
      if (!mounted) return;
      setState(() {
        _isRecording = false;
      });
      unawaited(_trayService.updateTrayIcon(TrayIconState.waiting));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('녹음을 중지했습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('녹음 중지 실패: $e')),
      );
    }
  }

  void _bringToFront() {
    // TODO: window_manager를 이용해 창을 전면으로 가져오기 (필요 시)
  }

  @override
  void dispose() {
    _sessionTicker?.cancel();
    _audioService.dispose();
    _trayService.dispose();
    _loggingService.removeErrorListener(_handleLoggingError);
    super.dispose();
  }

  Future<void> _loadTodayRecordingDuration() async {
    final now = DateTime.now();
    final duration = await _settings.getRecordingDuration(now);
    if (!mounted) return;
    _currentDayKey = _dayKey(now);
    setState(() {
      _todayDuration = duration;
      _todayRecordingTime = _formatDuration(duration + _currentRunningDuration());
    });
  }

  Future<void> _recordSessionDuration(DateTime startTime, DateTime stopTime) async {
    var segmentStart = startTime;
    while (segmentStart.isBefore(stopTime)) {
      final dayStart = DateTime(segmentStart.year, segmentStart.month, segmentStart.day);
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
    return '${hours}시간 ${minutes}분';
  }

  String _dayKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _handleLoggingError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
