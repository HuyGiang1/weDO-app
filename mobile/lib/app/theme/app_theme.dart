import 'package:flutter/material.dart';

import '../navigation/page_transitions.dart';

abstract final class AppUi {
  static const double fieldRadius = 12;
  static const double cardRadius = 12;
  static const double touchTarget = 48;
  static const gap = EdgeInsets.all(16);
}

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color success, warning;
  const AppSemanticColors({required this.success, required this.warning});
  static AppSemanticColors of(BuildContext context) =>
      Theme.of(context).extension<AppSemanticColors>() ??
      (Theme.of(context).brightness == Brightness.dark
          ? const AppSemanticColors(
              success: Color(0xFF8BD8AE),
              warning: Color(0xFFF0CA79),
            )
          : const AppSemanticColors(
              success: Color(0xFF246B45),
              warning: Color(0xFF865B13),
            ));
  @override
  AppSemanticColors copyWith({Color? success, Color? warning}) =>
      AppSemanticColors(
        success: success ?? this.success,
        warning: warning ?? this.warning,
      );
  @override
  AppSemanticColors lerp(covariant AppSemanticColors? other, double t) =>
      other == null
      ? this
      : AppSemanticColors(
          success: Color.lerp(success, other.success, t)!,
          warning: Color.lerp(warning, other.warning, t)!,
        );
}

abstract final class AppTheme {
  static final light = build(Brightness.light);
  static final dark = build(Brightness.dark);
  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors = (dark ? const ColorScheme.dark() : const ColorScheme.light())
        .copyWith(
          primary: dark ? const Color(0xFFFAFAFA) : const Color(0xFF0A0A0A),
          onPrimary: dark ? const Color(0xFF0A0A0A) : const Color(0xFFFFFFFF),
          primaryContainer: dark
              ? const Color(0xFF262626)
              : const Color(0xFFF5F5F5),
          onPrimaryContainer: dark
              ? const Color(0xFFFAFAFA)
              : const Color(0xFF0A0A0A),
          secondary: dark ? const Color(0xFFD4D4D4) : const Color(0xFF525252),
          onSecondary: dark ? const Color(0xFF0A0A0A) : const Color(0xFFFFFFFF),
          secondaryContainer: dark
              ? const Color(0xFF262626)
              : const Color(0xFFF5F5F5),
          onSecondaryContainer: dark
              ? const Color(0xFFFAFAFA)
              : const Color(0xFF0A0A0A),
          tertiary: dark ? const Color(0xFFD4D4D4) : const Color(0xFF525252),
          onTertiary: dark ? const Color(0xFF0A0A0A) : const Color(0xFFFFFFFF),
          tertiaryContainer: dark
              ? const Color(0xFF262626)
              : const Color(0xFFF5F5F5),
          onTertiaryContainer: dark
              ? const Color(0xFFFAFAFA)
              : const Color(0xFF0A0A0A),
          surface: dark ? const Color(0xFF111111) : const Color(0xFFFFFFFF),
          surfaceContainerLowest: dark
              ? const Color(0xFF111111)
              : const Color(0xFFFFFFFF),
          surfaceContainerLow: dark
              ? const Color(0xFF171717)
              : const Color(0xFFFAFAFA),
          surfaceContainer: dark
              ? const Color(0xFF1F1F1F)
              : const Color(0xFFF5F5F5),
          surfaceContainerHigh: dark
              ? const Color(0xFF262626)
              : const Color(0xFFE5E5E5),
          surfaceContainerHighest: dark
              ? const Color(0xFF333333)
              : const Color(0xFFD4D4D4),
          onSurface: dark ? const Color(0xFFFAFAFA) : const Color(0xFF0A0A0A),
          onSurfaceVariant: dark
              ? const Color(0xFFA3A3A3)
              : const Color(0xFF737373),
          outline: dark ? const Color(0xFF737373) : const Color(0xFF737373),
          outlineVariant: dark
              ? const Color(0xFF2E2E2E)
              : const Color(0xFFE5E5E5),
          inverseSurface: dark
              ? const Color(0xFFFAFAFA)
              : const Color(0xFF111111),
          onInverseSurface: dark
              ? const Color(0xFF0A0A0A)
              : const Color(0xFFFAFAFA),
          inversePrimary: dark
              ? const Color(0xFF0A0A0A)
              : const Color(0xFFFAFAFA),
          error: dark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
          onError: dark ? const Color(0xFF450A0A) : const Color(0xFFFFFFFF),
          errorContainer: dark
              ? const Color(0xFF450A0A)
              : const Color(0xFFFEF2F2),
          onErrorContainer: dark
              ? const Color(0xFFFECACA)
              : const Color(0xFF7F1D1D),
          surfaceBright: dark ? const Color(0xFF262626) : const Color(0xFFFFFFFF),
      surfaceDim: dark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA),
      primaryFixed: const Color(0xFFF5F5F5), primaryFixedDim: const Color(0xFFE5E5E5),
      onPrimaryFixed: const Color(0xFF0A0A0A), onPrimaryFixedVariant: const Color(0xFF525252),
      secondaryFixed: const Color(0xFFF5F5F5), secondaryFixedDim: const Color(0xFFE5E5E5),
      onSecondaryFixed: const Color(0xFF0A0A0A), onSecondaryFixedVariant: const Color(0xFF525252),
      tertiaryFixed: const Color(0xFFF5F5F5), tertiaryFixedDim: const Color(0xFFE5E5E5),
      onTertiaryFixed: const Color(0xFF0A0A0A), onTertiaryFixedVariant: const Color(0xFF525252),
      surfaceTint: Colors.transparent,
          shadow: Colors.transparent,
        );
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppUi.fieldRadius),
          borderSide: BorderSide(color: color, width: width),
        );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
    );
    return base.copyWith(
      pageTransitionsTheme: appPageTransitions,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFFFFFFF),
      extensions: [
        AppSemanticColors(
          success: dark ? const Color(0xFF8BD8AE) : const Color(0xFF246B45),
          warning: dark ? const Color(0xFFF0CA79) : const Color(0xFF865B13),
        ),
      ],
      textTheme: base.textTheme.copyWith(
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 22,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          height: 1.45,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: dark
            ? const Color(0xFF0A0A0A)
            : const Color(0xFFFFFFFF),
        foregroundColor: colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      iconTheme: IconThemeData(size: 22, color: colors.onSurfaceVariant),
      textSelectionTheme: TextSelectionThemeData(cursorColor: colors.primary, selectionColor: colors.primary.withValues(alpha: .16), selectionHandleColor: colors.primary),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        selectedItemColor: colors.onSurface,
        unselectedItemColor: colors.onSurfaceVariant,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
        elevation: 0,
        showUnselectedLabels: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLowest,
        border: border(colors.outlineVariant),
        enabledBorder: border(colors.outlineVariant),
        focusedBorder: border(colors.primary, 1.8),
        disabledBorder: border(colors.outlineVariant.withValues(alpha: .6)),
        errorBorder: border(colors.error),
        focusedErrorBorder: border(colors.error, 1.8),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        labelStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
        floatingLabelStyle: TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
        helperMaxLines: 3,
        errorMaxLines: 3,
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUi.cardRadius),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.onSurfaceVariant,
        textColor: colors.onSurface,
        minTileHeight: 56,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          elevation: 0,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: BorderSide(color: colors.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceContainerLowest,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: .6,
        space: 1,
      ),
    );
  }
}
