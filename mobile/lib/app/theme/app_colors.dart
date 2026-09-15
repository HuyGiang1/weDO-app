import 'package:flutter/material.dart';

/// Minimal color tokens used across WeDo auth screens.
abstract final class AppColors {
  // Brand & Primary
  static const Color primary = Color(0xFF630ED4);
  static const Color primaryContainer = Color(0xFF7C3AED);
  static const Color onPrimaryContainer = Color(0xFFEDE0FF);
  static const Color primaryFixed = Color(0xFFEADDFF);
  static const Color primaryFixedDim = Color(0xFFD2BBFF);
  static const Color primaryShadow = Color(0x33630ED4); // rgba(99, 14, 212, 0.20)
  static const Color softShadow = Color(0x0B630ED4); // rgba(99, 14, 212, 0.04)
  static const Color softVioletShadow = Color(0x0A7C3AED); // rgba(124, 58, 237, 0.04)

  // Secondary
  static const Color secondary = Color(0xFF006B5F);
  static const Color secondaryContainer = Color(0xFF62FAE3);

  // Background & Surfaces
  static const Color background = Color(0xFFF7F9FB);
  static const Color backgroundGradientStart = Color(0xFFF7F9FB);
  static const Color backgroundGradientEnd = Color(0xFFEADDFF);
  static const Color surface = Color(0xFFF7F9FB);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF2F4F6);
  static const Color surfaceContainer = Color(0xFFECEEF0);
  static const Color surfaceContainerHigh = Color(0xFFE6E8EA);
  static const Color surfaceContainerHighest = Color(0xFFE0E3E5);

  // Typography & Content
  static const Color onSurface = Color(0xFF191C1E);
  static const Color onSurfaceVariant = Color(0xFF4A4455);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Inputs & Validation
  static const Color inputBackground = Color(0xFFF2F4F6);
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onError = Color(0xFFFFFFFF);

  // Outlines / Borders
  static const Color outline = Color(0xFF7B7487);
  static const Color outlineVariant = Color(0xFFCCC3D8);
}
