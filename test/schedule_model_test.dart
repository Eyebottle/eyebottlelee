import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_recorder/models/schedule_model.dart';

TimeOfDay t(int h, int m) => TimeOfDay(hour: h, minute: m);

void main() {
  group('DaySchedule 직렬화 라운드트립', () {
    test('종일 근무일은 라운드트립에서 보존된다', () {
      final day = DaySchedule.fullDay(start: t(9, 0), end: t(18, 0));
      final round = DaySchedule.fromJson(day.toJson());

      expect(round.isWorkingDay, true);
      expect(round.mode, ScheduleMode.fullDay);
      expect(round.sessions.length, 1);
      expect(round.sessions[0].startMinutes, 9 * 60);
      expect(round.sessions[0].endMinutes, 18 * 60);
    });

    test('오전·오후 split은 두 세션과 mode가 보존된다', () {
      final day = DaySchedule.split(
        morning: const WorkingSession(
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 12, minute: 0)),
        afternoon: const WorkingSession(
            start: TimeOfDay(hour: 13, minute: 0),
            end: TimeOfDay(hour: 18, minute: 0)),
      );
      final round = DaySchedule.fromJson(day.toJson());

      expect(round.mode, ScheduleMode.split);
      expect(round.sessions.length, 2);
      expect(round.sessions[0].startMinutes, 9 * 60);
      expect(round.sessions[1].endMinutes, 18 * 60);
    });

    test('휴무일은 라운드트립에서 보존된다', () {
      final round = DaySchedule.fromJson(DaySchedule.rest().toJson());
      expect(round.isWorkingDay, false);
      expect(round.sessions, isEmpty);
    });

    test('오후 단독 split도 세션이 유실되지 않는다', () {
      final day = DaySchedule.split(
        morning: null,
        afternoon: const WorkingSession(
            start: TimeOfDay(hour: 14, minute: 0),
            end: TimeOfDay(hour: 18, minute: 0)),
      );
      final round = DaySchedule.fromJson(day.toJson());

      expect(round.sessions.length, 1);
      expect(round.sessions[0].startMinutes, 14 * 60);
      expect(round.mode, ScheduleMode.split);
    });

    test('정오를 넘겨 끝나는 오전 세션(9:00-14:30)도 라운드트립에서 보존된다 (드롭 버그 회귀 방지)',
        () {
      final day = DaySchedule.split(
        morning: const WorkingSession(
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 14, minute: 30)),
        afternoon: const WorkingSession(
            start: TimeOfDay(hour: 15, minute: 0),
            end: TimeOfDay(hour: 19, minute: 0)),
      );
      final round = DaySchedule.fromJson(day.toJson());

      expect(round.sessions.length, 2,
          reason: '비표준 경계 세션도 직렬화에서 유실되면 안 된다');
      expect(round.sessions[0].endMinutes, 14 * 60 + 30);
      expect(round.sessions[1].startMinutes, 15 * 60);
    });

    test('레거시 점심 분리 포맷(startTime/endTime/lunch)을 두 세션 split으로 변환한다', () {
      final legacy = <String, dynamic>{
        'isWorkingDay': true,
        'startTime': {'hour': 9, 'minute': 0},
        'endTime': {'hour': 18, 'minute': 0},
        'lunchStart': {'hour': 12, 'minute': 0},
        'lunchEnd': {'hour': 13, 'minute': 0},
      };
      final day = DaySchedule.fromJson(legacy);

      expect(day.isWorkingDay, true);
      expect(day.sessions.length, 2);
      expect(day.mode, ScheduleMode.split);
      expect(day.sessions[0].startMinutes, 9 * 60);
      expect(day.sessions[0].endMinutes, 12 * 60);
      expect(day.sessions[1].startMinutes, 13 * 60);
      expect(day.sessions[1].endMinutes, 18 * 60);
    });

    test('레거시 단일 구간 포맷을 종일 근무로 변환한다', () {
      final legacy = <String, dynamic>{
        'isWorkingDay': true,
        'startTime': {'hour': 10, 'minute': 0},
        'endTime': {'hour': 17, 'minute': 0},
      };
      final day = DaySchedule.fromJson(legacy);

      expect(day.sessions.length, 1);
      expect(day.mode, ScheduleMode.fullDay);
      expect(day.sessions[0].startMinutes, 10 * 60);
    });
  });

  group('WeeklySchedule 직렬화 라운드트립', () {
    test('기본 스케줄이 라운드트립에서 동등하게 보존된다', () {
      final original = WeeklySchedule.defaultSchedule();
      final round = WeeklySchedule.fromJson(original.toJson());

      for (int i = 0; i <= 6; i++) {
        final a = original.weekDays[i]!;
        final b = round.weekDays[i]!;
        expect(b.isWorkingDay, a.isWorkingDay, reason: 'day $i 근무여부');
        expect(b.mode, a.mode, reason: 'day $i mode');
        expect(b.sessions.length, a.sessions.length, reason: 'day $i 세션 수');
        for (int s = 0; s < a.sessions.length; s++) {
          expect(b.sessions[s].startMinutes, a.sessions[s].startMinutes);
          expect(b.sessions[s].endMinutes, a.sessions[s].endMinutes);
        }
      }
    });

    test('누락된 요일 키는 휴무일로 채워진다', () {
      final schedule = WeeklySchedule.fromJson(<String, dynamic>{});
      for (int i = 0; i <= 6; i++) {
        expect(schedule.weekDays[i]!.isWorkingDay, false);
      }
    });
  });
}
