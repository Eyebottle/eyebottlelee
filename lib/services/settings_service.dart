import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/schedule_model.dart';

class SettingsService {
  static const _keyScheduleJson = 'weekly_schedule_json';
  static const _keySaveFolder = 'save_folder';
  static const _keyLaunchAtStartup = 'launch_at_startup';
  static const _keyVadEnabled = 'vad_enabled';
  static const _keyVadThreshold = 'vad_threshold';
  static const _keyDailyRecordingSeconds = 'daily_recording_seconds';
  static const _keyRetentionDays = 'retention_days';

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
    final threshold = prefs.getDouble(_keyVadThreshold) ?? 0.01;
    return (enabled, threshold);
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
}
