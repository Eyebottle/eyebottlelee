import 'package:flutter/material.dart';
import '../../style/app_colors.dart';
import '../../style/app_elevation.dart';

/// 아이보틀 앱의 표준 카드 위젯
///
/// Material 3 디자인 시스템을 따르는 재사용 가능한 카드 컴포넌트입니다.
/// 3가지 elevation 레벨을 제공하여 UI 계층 구조를 명확히 합니다.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.elevation = 1,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.border,
    this.onTap,
    this.shadows,
  });

  /// Elevation Level 1 카드 (기본)
  /// 사용처: 정보 표시, 일반 카드
  const AppCard.level1({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.border,
    this.onTap,
  })  : elevation = 1,
        shadows = null;

  /// Elevation Level 2 카드 (강조)
  /// 사용처: 주요 카드, 활성 요소
  const AppCard.level2({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.border,
    this.onTap,
  })  : elevation = 2,
        shadows = null;

  /// Elevation Level 3 카드 (부상)
  /// 사용처: 다이얼로그 내부 카드, 중요한 요소
  const AppCard.level3({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.border,
    this.onTap,
  })  : elevation = 3,
        shadows = null;

  /// Primary 색상 강조 카드
  const AppCard.primary({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.onTap,
  })  : elevation = 2,
        color = null,
        border = null,
        shadows = null;

  /// 카드 내용
  final Widget child;

  /// Elevation 레벨 (1-3)
  final int elevation;

  /// 카드 내부 여백
  final EdgeInsetsGeometry? padding;

  /// 카드 외부 여백
  final EdgeInsetsGeometry? margin;

  /// 카드 모서리 둥글기
  final BorderRadius? borderRadius;

  /// 카드 배경색
  final Color? color;

  /// 카드 테두리
  final BoxBorder? border;

  /// 탭 이벤트 핸들러
  final VoidCallback? onTap;

  /// 커스텀 그림자 (null이면 elevation 기반 자동 설정)
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(20);
    final effectiveColor = color ?? AppColors.surface;
    final effectivePadding = padding ?? const EdgeInsets.all(20);
    final effectiveShadows = shadows ?? AppElevation.getShadow(elevation);

    Widget content = Container(
      padding: effectivePadding,
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: effectiveBorderRadius,
        border: border ??
            Border.all(
              color: AppColors.surfaceBorder,
              width: 1,
            ),
        boxShadow: effectiveShadows,
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveBorderRadius,
          child: content,
        ),
      );
    }

    return content;
  }
}
