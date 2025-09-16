import 'package:flutter/material.dart';
import '../../services/audio_service.dart';
import '../../services/schedule_service.dart';
import '../../models/schedule_model.dart';
import '../widgets/recording_status_widget.dart';
import '../widgets/volume_meter_widget.dart';
import '../widgets/schedule_config_widget.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final AudioService _audioService = AudioService();
  final ScheduleService _scheduleService = ScheduleService();

  bool _isRecording = false;
  double _volumeLevel = 0.0;
  String _todayRecordingTime = '0시간 0분';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
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

    // 스케줄 서비스: 자동 시작/종료 연동
    _scheduleService.onRecordingStart = () => _startRecording();
    _scheduleService.onRecordingStop = () => _stopRecording();

    // 기본 진료 스케줄 적용 (월-금 09:00~18:00, 점심 12:00~13:00)
    final defaultSchedule = WeeklySchedule.defaultSchedule();
    _scheduleService.applySchedule(defaultSchedule);
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

            // 오늘 녹음 시간
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
      builder: (context) => const ScheduleConfigWidget(),
    );
  }

  void _showFolderDialog() {
    // TODO: 폴더 선택 다이얼로그 구현
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('저장 폴더 설정 기능 준비 중입니다.')),
    );
  }

  void _showAdvancedSettings() {
    // TODO: 고급 설정 다이얼로그 구현
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('고급 설정 기능 준비 중입니다.')),
    );
  }

  Future<void> _startRecording() async {
    try {
      await _audioService.startRecording();
      setState(() {
        _isRecording = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('녹음을 시작했습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('녹음 시작 실패: $e')),
      );
    }
  }

  Future<void> _pauseRecording() async {
    try {
      await _audioService.pauseRecording();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('녹음을 일시정지했습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일시정지 실패: $e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioService.stopRecording();
      setState(() {
        _isRecording = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('녹음을 중지했습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('녹음 중지 실패: $e')),
      );
    }
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }
}
