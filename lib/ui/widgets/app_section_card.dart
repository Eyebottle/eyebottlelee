import 'package:flutter/material.dart';

import '../style/app_spacing.dart';

/// 화면 곳곳에서 동일한 여백을 적용하기 위한 공용 카드 래퍼.
class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.child,
    this.margin = EdgeInsets.zero,
    this.padding = AppPadding.card,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
