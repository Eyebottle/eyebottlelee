import 'package:flutter/material.dart';
import '../../style/app_colors.dart';
import '../../style/app_typography.dart';

/// 아이보틀 앱의 표준 버튼 위젯
///
/// Material 3 디자인 시스템을 따르는 일관된 버튼 스타일을 제공합니다.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.icon,
  }) : _type = _ButtonType.filled;

  const AppButton.primary({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.icon,
  }) : _type = _ButtonType.filled;

  const AppButton.secondary({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.icon,
  }) : _type = _ButtonType.outlined;

  const AppButton.text({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.icon,
  }) : _type = _ButtonType.text;

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final IconData? icon;
  final _ButtonType _type;

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      return _buildIconButton(context);
    }
    return _buildButton(context);
  }

  Widget _buildButton(BuildContext context) {
    switch (_type) {
      case _ButtonType.filled:
        return FilledButton(
          onPressed: onPressed,
          style: style ?? _getDefaultFilledStyle(AppColors.primary),
          child: child,
        );

      case _ButtonType.outlined:
        return OutlinedButton(
          onPressed: onPressed,
          style: style ?? _getDefaultOutlinedStyle(AppColors.primary),
          child: child,
        );

      case _ButtonType.text:
        return TextButton(
          onPressed: onPressed,
          style: style ?? _getDefaultTextStyle(AppColors.primary),
          child: child,
        );
    }
  }

  Widget _buildIconButton(BuildContext context) {
    switch (_type) {
      case _ButtonType.filled:
        return FilledButton.icon(
          onPressed: onPressed,
          style: style ?? _getDefaultFilledStyle(AppColors.primary),
          icon: Icon(icon),
          label: child,
        );

      case _ButtonType.outlined:
        return OutlinedButton.icon(
          onPressed: onPressed,
          style: style ?? _getDefaultOutlinedStyle(AppColors.primary),
          icon: Icon(icon),
          label: child,
        );

      case _ButtonType.text:
        return TextButton.icon(
          onPressed: onPressed,
          style: style ?? _getDefaultTextStyle(AppColors.primary),
          icon: Icon(icon),
          label: child,
        );
    }
  }

  static ButtonStyle _getDefaultFilledStyle(Color color) {
    return FilledButton.styleFrom(
      backgroundColor: color,
      foregroundColor: AppColors.textOnPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: AppTypography.labelLarge,
      elevation: 0,
    );
  }

  static ButtonStyle _getDefaultOutlinedStyle(Color color) {
    return OutlinedButton.styleFrom(
      foregroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      side: BorderSide(color: color, width: 1.5),
      textStyle: AppTypography.labelLarge,
    );
  }

  static ButtonStyle _getDefaultTextStyle(Color color) {
    return TextButton.styleFrom(
      foregroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: AppTypography.labelLarge,
    );
  }
}

enum _ButtonType {
  filled,
  outlined,
  text,
}
