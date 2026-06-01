import 'package:flutter/material.dart';

/// 시:분을 24시간 'HH:mm' 형식으로 포맷한다(2자리 0채움).
/// 시간표/대시보드 곳곳에 흩어져 있던 동일 구현을 하나로 모은 것.
String formatHm(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
