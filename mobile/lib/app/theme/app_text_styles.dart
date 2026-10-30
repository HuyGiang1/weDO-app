import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Isolated typography styles for WeDo auth screens.
///
/// Note: Custom font packages (Inter / Plus Jakarta Sans) are not yet bundled.
/// System font fallbacks are used while preserving exact scale, weight, and line-height.
abstract final class AppTextStyles {
  static AppTypography of(BuildContext context) =>
      AppTypography(Theme.of(context).colorScheme);
  static const TextStyle brand = TextStyle(
    fontSize: 40.0,
    fontWeight: FontWeight.w800,
    color: AppColors.primary,
    letterSpacing: -0.5,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 28.0,
    fontWeight: FontWeight.w700,
    height: 34.0 / 28.0,
    color: AppColors.onSurface,
    letterSpacing: -0.3,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w400,
    height: 28.0 / 18.0,
    color: AppColors.onSurfaceVariant,
  );

  static const TextStyle buttonPrimary = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w600,
    color: AppColors.onPrimary,
    letterSpacing: 0.2,
  );

  static const TextStyle buttonSecondary = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
    letterSpacing: 0.2,
  );

  static const TextStyle label = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurfaceVariant,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurfaceVariant,
  );

  static const TextStyle link = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );

  static const TextStyle input = TextStyle(
    fontSize: 15.0,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );

  static const TextStyle inputHint = TextStyle(
    fontSize: 15.0,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurfaceVariant,
  );
}

class AppTypography {
  final ColorScheme colors;
  const AppTypography(this.colors);
  TextStyle get brand => AppTextStyles.brand.copyWith(color: colors.primary);
  TextStyle get headline =>
      AppTextStyles.headline.copyWith(color: colors.onSurface);
  TextStyle get subtitle =>
      AppTextStyles.subtitle.copyWith(color: colors.onSurfaceVariant);
  TextStyle get buttonPrimary =>
      AppTextStyles.buttonPrimary.copyWith(color: colors.onPrimary);
  TextStyle get buttonSecondary =>
      AppTextStyles.buttonSecondary.copyWith(color: colors.primary);
  TextStyle get label => AppTextStyles.label.copyWith(color: colors.onSurface);
  TextStyle get bodyMedium =>
      AppTextStyles.bodyMedium.copyWith(color: colors.onSurfaceVariant);
  TextStyle get bodySmall =>
      AppTextStyles.bodySmall.copyWith(color: colors.onSurfaceVariant);
  TextStyle get link => AppTextStyles.link.copyWith(color: colors.primary);
  TextStyle get input => AppTextStyles.input.copyWith(color: colors.onSurface);
  TextStyle get inputHint =>
      AppTextStyles.inputHint.copyWith(color: colors.onSurfaceVariant);
}
