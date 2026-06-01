import 'package:flutter/material.dart';

/// 시:분을 24시간 'HH:mm' 형식으로 포맷한다(2자리 0채움).
/// 로그 등 비표시 용도로 사용한다(사용자 표시는 [formatHm12] 권장).
String formatHm(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

/// 시:분을 12시간제 '오전/오후 h:mm'로 포맷한다. 예: 오후 2:30, 오전 9:00.
/// 시간표 UI 표시는 이 형식으로 통일한다(주간 캘린더·요약·편집기 동일).
String formatHm12(TimeOfDay time) {
  final period = time.hour < 12 ? '오전' : '오후';
  final h = time.hour % 12 == 0 ? 12 : time.hour % 12;
  return '$period $h:${time.minute.toString().padLeft(2, '0')}';
}

/// 정시(0-23)를 12시간제 짧은 라벨로. 예: 9→'오전 9', 14→'오후 2', 12→'오후 12'.
/// 슬라이더 눈금 등 분이 항상 00인 자리에 쓴다.
String formatHourLabel12(int hour24) {
  final period = hour24 < 12 ? '오전' : '오후';
  final h = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '$period $h';
}
