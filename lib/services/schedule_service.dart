import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cron/cron.dart';
import '../models/schedule_model.dart';
import 'logging_service.dart';

class ScheduleService {
  final Cron _cron = Cron();
  WeeklySchedule? _currentSchedule;
  final LoggingService _logging = LoggingService();

  ScheduleService() {
    unawaited(_logging.ensureInitialized());
  }

  // 콜백 함수들
  Function()? onRecordingStart;
  Function()? onRecordingStop;

  /// 진료 시간표 적용
  void applySchedule(WeeklySchedule schedule) {
    // 기존 스케줄 정리
    _cron.close();
    _currentSchedule = schedule;

    // 새 스케줄 등록
    _registerCronJobs(schedule);
    _logging.info('새로운 진료 시간표 적용 완료');
  }

  /// 크론 작업 등록
  void _registerCronJobs(WeeklySchedule schedule) {
    for (final daySchedule in schedule.weekDays.entries) {
      final weekDay = daySchedule.key;
      final dayConfig = daySchedule.value;

      if (dayConfig.isWorkingDay) {
        // 진료 시작 스케줄
        _scheduleStartJob(weekDay, dayConfig.startTime);

        // 점심시간 시작 (녹음 중지)
        if (dayConfig.lunchStart != null) {
          _scheduleStopJob(weekDay, dayConfig.lunchStart!);
        }

        // 점심시간 종료 (녹음 재시작)
        if (dayConfig.lunchEnd != null) {
          _scheduleStartJob(weekDay, dayConfig.lunchEnd!);
        }

        // 진료 종료 스케줄
        _scheduleStopJob(weekDay, dayConfig.endTime);
      }
    }
  }

  /// 녹음 시작 스케줄 등록
  void _scheduleStartJob(int weekDay, TimeOfDay timeOfDay) {
    final cronExpression = _buildCronExpression(weekDay, timeOfDay);

    _cron.schedule(Schedule.parse(cronExpression), () {
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
    if (_currentSchedule == null) return false;

    final now = DateTime.now();
    final currentDay = now.weekday % 7; // DateTime.weekday는 1=월요일, 7=일요일
    final currentTime = TimeOfDay(hour: now.hour, minute: now.minute);

    final daySchedule = _currentSchedule!.weekDays[currentDay];
    if (daySchedule == null || !daySchedule.isWorkingDay) return false;

    // 기본 진료 시간 체크
    if (!_isTimeInRange(currentTime, daySchedule.startTime, daySchedule.endTime)) {
      return false;
    }

    // 점심시간 체크
    if (daySchedule.lunchStart != null && daySchedule.lunchEnd != null) {
      if (_isTimeInRange(currentTime, daySchedule.lunchStart!, daySchedule.lunchEnd!)) {
        return false; // 점심시간이므로 근무 시간이 아님
      }
    }

    return true;
  }

  /// 시간 범위 체크
  bool _isTimeInRange(TimeOfDay current, TimeOfDay start, TimeOfDay end) {
    final currentMinutes = current.hour * 60 + current.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
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

      if (daySchedule != null && daySchedule.isWorkingDay) {
        final startTime = daySchedule.startTime;
        final workingDateTime = DateTime(
          checkDate.year,
          checkDate.month,
          checkDate.day,
          startTime.hour,
          startTime.minute,
        );

        // 오늘이면 현재 시간 이후인지 체크
        if (i == 0 && workingDateTime.isBefore(now)) {
          continue;
        }

        return workingDateTime;
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
    _cron.close();
  }
}
