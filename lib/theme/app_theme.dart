import 'package:flutter/material.dart';
import 'package:boy_barbershop/theme/app_colors.dart';

/// Central [ThemeData] — use [MaterialApp.theme] only; avoid ad-hoc colors in widgets.
abstract final class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.light(
      primary: AppColors.brown,
      onPrimary: AppColors.dirtyWhite,
      primaryContainer: AppColors.brownContainer,
      onPrimaryContainer: AppColors.onBrownContainer,
      secondary: AppColors.blueAccent,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.blueContainer,
      onSecondaryContainer: AppColors.onBlueContainer,
      tertiary: AppColors.blueAccent,
      onTertiary: Colors.white,
      surface: AppColors.dirtyWhite,
      onSurface: AppColors.brownDark,
      surfaceContainerHighest: AppColors.dirtyWhiteDim,
      outline: AppColors.outlineMuted,
      outlineVariant: AppColors.brownContainer,
      error: const Color(0xFFB3261E),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.dirtyWhite,
      splashFactory: InkSplash.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.dirtyWhite,
        foregroundColor: AppColors.brownDark,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: scheme.onPrimary,
          backgroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.secondary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.75)),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return TextStyle(color: scheme.secondary, fontWeight: FontWeight.w600);
          }
          return TextStyle(color: scheme.onSurface.withValues(alpha: 0.75));
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.brownDark,
        contentTextStyle: const TextStyle(color: AppColors.dirtyWhite),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.secondary,
        circularTrackColor: scheme.secondary.withValues(alpha: 0.2),
      ),
    );
  }
}
