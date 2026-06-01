import 'package:flutter_test/flutter_test.dart';
import 'package:medical_recorder/models/schedule_model.dart';
import 'package:medical_recorder/ui/widgets/schedule/schedule_templates.dart';

void main() {
  group('ScheduleTemplate 요일 매핑 (0=일, 1=월 … 6=토)', () {
    test('평일만 근무: 월~금 점심분리 근무, 토·일 휴무 (오프바이원 회귀 방지)', () {
      final w = ScheduleTemplate.weekdaysOnly.schedule.weekDays;
      // 과거 버그: 0=월 착각으로 일·월·화·수·목 근무 + 금·토 휴무가 됐었다.
      expect(w[0]!.isWorkingDay, false, reason: '일요일은 반드시 휴무');
      expect(w[5]!.isWorkingDay, true, reason: '금요일은 반드시 근무');
      expect(w[6]!.isWorkingDay, false, reason: '토요일 휴무');
      for (int d = 1; d <= 5; d++) {
        expect(w[d]!.isWorkingDay, true, reason: 'day $d 근무');
        expect(w[d]!.mode, ScheduleMode.split, reason: 'day $d 점심분리');
        expect(w[d]!.sessions.length, 2, reason: 'day $d 오전/오후 2구간');
        expect(w[d]!.sessions[0].endMinutes, 13 * 60); // 오전 종료 13:00
        expect(w[d]!.sessions[1].startMinutes, 14 * 60); // 오후 시작 14:00
      }
    });

    test('평일 + 토요일 반일: 토(6) 근무 09-13, 일(0) 휴무', () {
      final w = ScheduleTemplate.weekdaysWithSaturday.schedule.weekDays;
      expect(w[6]!.isWorkingDay, true, reason: '토요일 반일 근무');
      expect(w[6]!.sessions.length, 1);
      expect(w[6]!.sessions[0].endMinutes, 13 * 60);
      expect(w[0]!.isWorkingDay, false, reason: '일요일 휴무');
      expect(w[5]!.isWorkingDay, true, reason: '금요일 근무');
      expect(w[1]!.mode, ScheduleMode.split, reason: '평일은 점심분리');
    });

    test('반나절 진료: 월~금 오전만(09-13), 주말 휴무', () {
      final w = ScheduleTemplate.halfDay.schedule.weekDays;
      for (int d = 1; d <= 5; d++) {
        expect(w[d]!.sessions.length, 1);
        expect(w[d]!.sessions[0].endMinutes, 13 * 60);
      }
      expect(w[0]!.isWorkingDay, false);
      expect(w[6]!.isWorkingDay, false);
    });

    test('종일 연속: 월~금 단일 09-18 구간(점심 미분리), 주말 휴무', () {
      final w = ScheduleTemplate.continuousFullDay.schedule.weekDays;
      for (int d = 1; d <= 5; d++) {
        expect(w[d]!.sessions.length, 1);
        expect(w[d]!.sessions[0].startMinutes, 9 * 60);
        expect(w[d]!.sessions[0].endMinutes, 18 * 60);
      }
      expect(w[0]!.isWorkingDay, false);
      expect(w[6]!.isWorkingDay, false);
    });

    test('템플릿은 4개', () {
      expect(ScheduleTemplate.all.length, 4);
    });
  });
}
