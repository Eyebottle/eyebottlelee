import 'dart:async';

import 'package:cron/cron.dart';
import 'package:flutter/material.dart';
import '../models/schedule_model.dart';
import 'logging_service.dart';

class ScheduleService {
  Cron _cron = Cron();
  WeeklySchedule? _currentSchedule;
  final LoggingService _logging = LoggingService();
  bool _isDisposed = false;

  ScheduleService() {
    unawaited(_logging.ensureInitialized());
  }

  // 콜백 함수들
  Function()? onRecordingStart;
  Function()? onRecordingStop;

  /// 진료 시간표 적용
  Future<void> applySchedule(WeeklySchedule schedule) async {
    _logging.info('📅 새로운 진료 시간표 적용 시작');
    await _resetCron();
    _currentSchedule = schedule;

    // 스케줄 내용 로깅
    for (var entry in schedule.weekDays.entries) {
      final day = entry.key;
      final daySchedule = entry.value;
      _logging.info('  ${_dayName(day)}요일: $daySchedule');
    }

    // 새 스케줄 등록
    _registerCronJobs(schedule);
    _logging.info('✅ 새로운 진료 시간표 적용 완료');
  }

  Future<void> _resetCron() async {
    _cron.close();
    // 기존 스케줄이 완전히 취소될 때까지 대기
    await Future.delayed(const Duration(milliseconds: 200));
    _cron = Cron();
  }

  /// 크론 작업 등록
  void _registerCronJobs(WeeklySchedule schedule) {
    for (final entry in schedule.weekDays.entries) {
      final weekDay = entry.key;
      final dayConfig = entry.value;

      if (!dayConfig.hasWorkingSession) continue;

      for (final slot in dayConfig.sessions) {
        _scheduleStartJob(weekDay, slot.start);
        _scheduleStopJob(weekDay, slot.end);
      }
    }
  }

  /// 녹음 시작 스케줄 등록
  void _scheduleStartJob(int weekDay, TimeOfDay timeOfDay) {
    final cronExpression = _buildCronExpression(weekDay, timeOfDay);

    _cron.schedule(Schedule.parse(cronExpression), () {
      if (_isDisposed) return;
      _logging.info('스케줄된 녹음 시작 트리거');
      _logging.debug('요일=$weekDay, 시각=${_formatTime(timeOfDay)}');
      if (onRecordingStart != null) {
        onRecordingStart!();
      }
    });
  }

  /// 녹음 중지 스케줄 등록
  void _scheduleStopJob(int weekDay, TimeOfDay timeOfDay) {
    final cronExpression = _buildCronExpression(weekDay, timeOfDay);

    _cron.schedule(Schedule.parse(cronExpression), () {
      if (_isDisposed) return;
      _logging.info('스케줄된 녹음 중지 트리거');
      _logging.debug('요일=$weekDay, 시각=${_formatTime(timeOfDay)}');
      if (onRecordingStop != null) {
        onRecordingStop!();
      }
    });
  }

  /// 크론 표현식 생성
  String _buildCronExpression(int weekDay, TimeOfDay timeOfDay) {
    // 크론 형식: 분 시 일 월 요일
    // 요일: 0=일요일, 1=월요일, ..., 6=토요일
    return '${timeOfDay.minute} ${timeOfDay.hour} * * $weekDay';
  }

  /// 현재 진료 시간인지 확인
  bool isCurrentlyWorkingTime() {
    if (_currentSchedule == null) {
      _logging.debug('isCurrentlyWorkingTime: 스케줄이 없음');
      return false;
    }

    final now = DateTime.now();
    final currentDay = now.weekday % 7; // DateTime.weekday는 1=월요일, 7=일요일
    final currentTime = TimeOfDay(hour: now.hour, minute: now.minute);

    final daySchedule = _currentSchedule!.weekDays[currentDay];
    if (daySchedule == null) {
      return false;
    }

    return daySchedule.isTimeInWorkingHours(currentTime);
  }

  String _dayName(int dayIndex) {
    const days = ['일', '월', '화', '수', '목', '금', '토'];
    return days[dayIndex];
  }

  /// 다음 진료 시작 시간 가져오기
  DateTime? getNextWorkingTime() {
    if (_currentSchedule == null) return null;

    final now = DateTime.now();

    // 오늘부터 7일 후까지 체크
    for (int i = 0; i < 7; i++) {
      final checkDate = now.add(Duration(days: i));
      final weekDay = checkDate.weekday % 7;
      final daySchedule = _currentSchedule!.weekDays[weekDay];

      if (daySchedule != null && daySchedule.hasWorkingSession) {
        for (final slot in daySchedule.sessions) {
          final workingDateTime = DateTime(
            checkDate.year,
            checkDate.month,
            checkDate.day,
            slot.start.hour,
            slot.start.minute,
          );

          if (i == 0 && workingDateTime.isBefore(now)) {
            continue;
          }

          return workingDateTime;
        }
      }
    }

    return null;
  }

  /// 시간 포맷팅
  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// 서비스 정리
  void dispose() {
    _isDisposed = true;
    _cron.close();
  }
}
