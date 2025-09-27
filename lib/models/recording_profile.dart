enum RecordingQualityProfile {
  balanced,
  speechOptimized,
  storageSaver,
}

class RecordingProfile {
  const RecordingProfile({
    required this.id,
    required this.label,
    required this.description,
    required this.bitRate,
    required this.sampleRate,
  });

  final RecordingQualityProfile id;
  final String label;
  final String description;
  final int bitRate;
  final int sampleRate;

  static const Map<RecordingQualityProfile, RecordingProfile> presets = {
    RecordingQualityProfile.balanced: RecordingProfile(
      id: RecordingQualityProfile.balanced,
      label: '표준 음성 (64 kbps)',
      description: '일반 진료실 환경에 맞춘 기본 음질/용량 균형',
      bitRate: 64000,
      sampleRate: 32000,
    ),
    RecordingQualityProfile.speechOptimized: RecordingProfile(
      id: RecordingQualityProfile.speechOptimized,
      label: '음성 강화 (48 kbps)',
      description: '조용한 환경에서 음성 위주로 저장 공간 절약',
      bitRate: 48000,
      sampleRate: 32000,
    ),
    RecordingQualityProfile.storageSaver: RecordingProfile(
      id: RecordingQualityProfile.storageSaver,
      label: '최대 절약 (32 kbps)',
      description: '장기 보관용, 가장 작은 파일 크기',
      bitRate: 32000,
      sampleRate: 16000,
    ),
  };

  static RecordingProfile resolve(RecordingQualityProfile id) {
    return presets[id] ?? presets[RecordingQualityProfile.balanced]!;
  }
}
