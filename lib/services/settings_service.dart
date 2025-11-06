import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart';

import '../models/mic_diagnostic_result.dart';
import '../models/schedule_model.dart';
import '../models/recording_profile.dart';
import '../models/launch_manager_settings.dart';

class SettingsService {
  static const _keyScheduleJson = 'weekly_schedule_json';
  static const _keySaveFolder = 'save_folder';
  static const _keyLaunchAtStartup = 'launch_at_startup';
  static const _keyVadEnabled = 'vad_enabled';
  static const _keyVadThreshold = 'vad_threshold';
  static const _keyDailyRecordingSeconds = 'daily_recording_seconds';
  static const _keyRetentionDays = 'retention_days';
  static const _keyMicDiagnostic = 'last_mic_diagnostic';
  static const _keyRecordingProfile = 'recording_profile';
  static const _keyMakeupGainDb = 'makeup_gain_db';
  static const _keyLaunchManagerSettings = 'launch_manager_settings';
  // WAV 자동 변환 관련 설정
  static const _keyWavAutoConvertEnabled = 'wav_auto_convert_enabled';
  static const _keyWavTargetEncoder = 'wav_target_encoder';
  static const _keyConversionDelay = 'conversion_delay_seconds';

  Future<void> saveSchedule(WeeklySchedule schedule) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(schedule.toJson());
    await prefs.setString(_keyScheduleJson, jsonStr);
  }

  Future<WeeklySchedule?> loadSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyScheduleJson);
    if (jsonStr == null) return null;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return WeeklySchedule.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> setSaveFolder(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySaveFolder, path);
  }

  Future<String?> getSaveFolder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySaveFolder);
  }

  Future<void> setLaunchAtStartup(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLaunchAtStartup, value);
  }

  Future<bool> getLaunchAtStartup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLaunchAtStartup) ?? true;
  }

  Future<void> setVad(
      {required bool enabled, required double threshold}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVadEnabled, enabled);
    await prefs.setDouble(_keyVadThreshold, threshold);
  }

  Future<(bool enabled, double threshold)> getVad() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyVadEnabled) ?? true;
    final threshold = prefs.getDouble(_keyVadThreshold) ?? 0.006;
    return (enabled, threshold);
  }

  Future<void> setRecordingProfile(RecordingQualityProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRecordingProfile, profile.name);
  }

  Future<RecordingQualityProfile> getRecordingProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyRecordingProfile);
    if (saved != null) {
      for (final entry in RecordingQualityProfile.values) {
        if (entry.name == saved) {
          return entry;
        }
      }
    }
    return RecordingQualityProfile.balanced;
  }

  Future<void> setMakeupGainDb(double gainDb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyMakeupGainDb, gainDb);
  }

  Future<double> getMakeupGainDb() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyMakeupGainDb) ?? 0.0;
  }

  Future<Duration> getRecordingDuration(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final map =
        _decodeDailyDurations(prefs.getString(_keyDailyRecordingSeconds));
    final key = _dateKey(date);
    final seconds = map[key] ?? 0.0;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  Future<void> setRetentionDuration(Duration? duration) async {
    final prefs = await SharedPreferences.getInstance();
    if (duration == null) {
      await prefs.setInt(_keyRetentionDays, -1);
    } else {
      await prefs.setInt(_keyRetentionDays, duration.inDays);
    }
  }

  Future<Duration?> getRetentionDuration() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_keyRetentionDays);
    if (saved == null || saved < 0) {
      return null; // 영구 보존
    }
    return Duration(days: saved);
  }

  Future<void> saveMicDiagnosticResult(MicDiagnosticResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMicDiagnostic, result.toJsonString());
  }

  Future<MicDiagnosticResult?> loadMicDiagnosticResult() async {
    final prefs = await SharedPreferences.getInstance();
    return MicDiagnosticResult.fromJsonString(
      prefs.getString(_keyMicDiagnostic),
    );
  }

  Future<void> addRecordingDuration(DateTime date, Duration duration) async {
    if (duration <= Duration.zero) return;

    final prefs = await SharedPreferences.getInstance();
    final map =
        _decodeDailyDurations(prefs.getString(_keyDailyRecordingSeconds));
    final key = _dateKey(date);
    final seconds = map[key] ?? 0.0;
    map[key] = seconds + duration.inMilliseconds / 1000;

    _pruneOldEntries(map);
    await prefs.setString(_keyDailyRecordingSeconds, jsonEncode(map));
  }

  Map<String, double> _decodeDailyDurations(String? jsonStr) {
    if (jsonStr == null) return {};
    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      return decoded.map((key, value) {
        if (value is num) {
          return MapEntry(key, value.toDouble());
        }
        return MapEntry(key, 0.0);
      });
    } catch (_) {
      return {};
    }
  }

  void _pruneOldEntries(Map<String, double> map, {int keepDays = 14}) {
    final threshold = DateTime.now().subtract(Duration(days: keepDays));
    map.removeWhere((key, value) {
      try {
        final date = DateTime.parse(key);
        return date
            .isBefore(DateTime(threshold.year, threshold.month, threshold.day));
      } catch (_) {
        return true;
      }
    });
  }

  String _dateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.toIso8601String().split('T').first;
  }

  /// 자동 실행 매니저 설정 저장
  Future<void> setLaunchManagerSettings(LaunchManagerSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(settings.toJson());
    await prefs.setString(_keyLaunchManagerSettings, jsonStr);
  }

  /// 자동 실행 매니저 설정 로드
  Future<LaunchManagerSettings> getLaunchManagerSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyLaunchManagerSettings);

    if (jsonStr == null) {
      // 기본 설정 반환
      return LaunchManagerSettings.defaultSettings();
    }

    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final settings = LaunchManagerSettings.fromJson(map);

      // 버전 마이그레이션 수행
      return settings.migrate();
    } catch (e) {
      // JSON 파싱 실패 시 기본 설정 반환
      return LaunchManagerSettings.defaultSettings();
    }
  }

  // ========== WAV 자동 변환 관련 설정 ==========

  /// WAV 자동 변환 활성화 여부 설정
  ///
  /// **기본값:** true (Windows AAC/Opus 불안정성 대응)
  Future<void> setWavAutoConvertEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyWavAutoConvertEnabled, value);
  }

  /// WAV 자동 변환 활성화 여부 가져오기
  ///
  /// **반환값:** true = 자동 변환 활성화 (기본값), false = 비활성화
  Future<bool> isWavAutoConvertEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyWavAutoConvertEnabled) ?? true; // 기본값 true로 변경
  }

  /// WAV 변환 목표 인코더 설정
  ///
  /// **매개변수:**
  /// - `encoder`: AudioEncoder.aacLc 또는 AudioEncoder.opus
  ///
  /// **기본값:** AudioEncoder.aacLc (더 널리 호환됨)
  Future<void> setWavTargetEncoder(AudioEncoder encoder) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWavTargetEncoder, encoder.name);
  }

  /// WAV 변환 목표 인코더 가져오기
  ///
  /// **반환값:**
  /// - AudioEncoder.aacLc (기본값)
  /// - AudioEncoder.opus
  Future<AudioEncoder> getWavTargetEncoder() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyWavTargetEncoder);

    if (saved == 'opus') {
      return AudioEncoder.opus;
    }

    // 기본값은 AAC (호환성이 더 좋음)
    return AudioEncoder.aacLc;
  }

  /// 변환 지연 시간 설정 (초)
  ///
  /// **매개변수:**
  /// - `seconds`: 세그먼트 분할 후 변환 시작까지 대기 시간 (초)
  ///
  /// **권장값:** 5초 (녹음 안정화 시간 확보)
  Future<void> setConversionDelay(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyConversionDelay, seconds);
  }

  /// 변환 지연 시간 가져오기 (초)
  ///
  /// **반환값:** 지연 시간 (초), 기본값 5초
  Future<int> getConversionDelay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyConversionDelay) ?? 5;
  }
}
