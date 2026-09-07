import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Isolated typography styles for WeDo auth screens.
///
/// Note: Custom font packages (Inter / Plus Jakarta Sans) are not yet bundled.
/// System font fallbacks are used while preserving exact scale, weight, and line-height.
abstract final class AppTextStyles {
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
}
