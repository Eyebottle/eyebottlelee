import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/schedule_model.dart';

class SettingsService {
  static const _keyScheduleJson = 'weekly_schedule_json';
  static const _keySaveFolder = 'save_folder';
  static const _keyLaunchAtStartup = 'launch_at_startup';
  static const _keyVadEnabled = 'vad_enabled';
  static const _keyVadThreshold = 'vad_threshold';

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

  Future<void> setVad({required bool enabled, required double threshold}) async {
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
}
