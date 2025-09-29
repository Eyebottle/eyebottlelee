import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
}
