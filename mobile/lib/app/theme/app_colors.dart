import 'package:flutter/material.dart';

/// Minimal color tokens used across WeDo auth screens.
abstract final class AppColors {
  // Brand & Primary
  static const Color primary = Color(0xFF630ED4);
  static const Color primaryShadow = Color(0x33630ED4); // rgba(99, 14, 212, 0.20)

  // Background & Surfaces
  static const Color backgroundGradientStart = Color(0xFFF7F9FB);
  static const Color backgroundGradientEnd = Color(0xFFEADDFF);
  static const Color surface = Color(0xFFFFFFFF);

  // Typography & Content
  static const Color onSurface = Color(0xFF191C1E);
  static const Color onSurfaceVariant = Color(0xFF4A4455);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Inputs & Validation
  static const Color inputBackground = Color(0xFFF2F4F6);
  static const Color error = Color(0xFFBA1A1A);

  // Outlines / Borders
  static const Color outlineVariant = Color(0xFFCCC3D8);
}
