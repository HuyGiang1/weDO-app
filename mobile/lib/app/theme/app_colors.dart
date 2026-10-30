import 'package:flutter/material.dart';

/// Light-theme compatibility tokens. New widgets use Theme.of(context).colorScheme.
/// Canonical visual policy: docs/DESIGN_SYSTEM.md.
abstract final class AppColors {
  // Brand & Primary
  static const Color primary = Color(0xFF0A0A0A);
  static const Color primaryContainer = Color(0xFF171717);
  static const Color onPrimaryContainer = Color(0xFFFAFAFA);
  static const Color primaryFixed = Color(0xFFF5F5F5);
  static const Color primaryFixedDim = Color(0xFFE5E5E5);
  static const Color primaryShadow = Color(0x00000000);
  static const Color softShadow = Color(0x00000000);
  static const Color softVioletShadow = Color(0x00000000);

  // Secondary
  static const Color secondary = Color(0xFF525252);
  static const Color secondaryContainer = Color(0xFFF5F5F5);

  // Background & Surfaces
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundGradientStart = Color(0xFFFFFFFF);
  static const Color backgroundGradientEnd = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFFAFAFA);
  static const Color surfaceContainer = Color(0xFFF5F5F5);
  static const Color surfaceContainerHigh = Color(0xFFE5E5E5);
  static const Color surfaceContainerHighest = Color(0xFFD4D4D4);

  // Typography & Content
  static const Color onSurface = Color(0xFF0A0A0A);
  static const Color onSurfaceVariant = Color(0xFF737373);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Inputs & Validation
  static const Color inputBackground = Color(0xFFFAFAFA);
  static const Color error = Color(0xFFB91C1C);
  static const Color errorContainer = Color(0xFFFEF2F2);
  static const Color onError = Color(0xFFFFFFFF);

  // Outlines / Borders
  static const Color outline = Color(0xFF737373);
  static const Color outlineVariant = Color(0xFFE5E5E5);
}
