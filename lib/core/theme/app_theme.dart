import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finora/core/theme/app_colors.dart';
import 'package:finora/core/theme/app_typography.dart';
import 'package:finora/core/theme/app_spacing.dart';

class AppTheme {
  AppTheme._();

  /// The top navigation bar wears the user's accent colour in *every* theme,
  /// so the app keeps one identity in light, dark and system mode. Applied at
  /// the theme level so plain `AppBar`s pick it up without touching each page.
  static AppBarTheme _accentAppBar(Color accent) => AppBarTheme(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: AppTypography.textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          // Accents are dark enough that light status-bar icons always read.
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      );

  /// Light theme, optionally tinted with the user's accent.
  static ThemeData light({Color? accent}) => accent == null
      ? lightTheme
      : lightTheme.copyWith(
          appBarTheme: _accentAppBar(accent),
        );

  /// Dark theme, optionally tinted with the user's accent.
  static ThemeData dark({Color? accent}) => accent == null
      ? darkTheme
      : darkTheme.copyWith(
          appBarTheme: _accentAppBar(accent),
        );

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          primaryContainer: AppColors.primaryContainer,
          onPrimaryContainer: AppColors.primary,
          secondary: AppColors.secondary,
          onSecondary: Colors.white,
          secondaryContainer: AppColors.secondaryContainer,
          onSecondaryContainer: AppColors.secondary,
          tertiary: AppColors.tertiary,
          tertiaryContainer: AppColors.tertiaryContainer,
          surface: AppColors.surfaceLight,
          onSurface: AppColors.onSurfaceLight,
          surfaceContainerHighest: AppColors.surfaceVariantLight,
          onSurfaceVariant: AppColors.onSurfaceVariantLight,
          outline: AppColors.outlineLight,
          outlineVariant: AppColors.outlineVariantLight,
          error: AppColors.error,
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: AppColors.backgroundLight,
        textTheme: AppTypography.textTheme,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surfaceLight,
          foregroundColor: AppColors.onSurfaceLight,
          elevation: 0,
          scrolledUnderElevation: 1,
          shadowColor: AppColors.outlineVariantLight,
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
        ),
        cardTheme: const CardThemeData(
          color: AppColors.surfaceLight,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.cardRadius,
            side: BorderSide(color: AppColors.outlineVariantLight),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
            padding: AppSpacing.buttonPadding,
            textStyle: AppTypography.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            minimumSize: const Size(double.infinity, 52),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
            padding: AppSpacing.buttonPadding,
            minimumSize: const Size(double.infinity, 52),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: AppSpacing.buttonPadding,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceVariantLight,
          border: OutlineInputBorder(
            borderRadius: AppRadius.buttonRadius,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.buttonRadius,
            borderSide: const BorderSide(color: AppColors.outlineLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.buttonRadius,
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppRadius.buttonRadius,
            borderSide: const BorderSide(color: AppColors.error),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.md,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surfaceLight,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.onSurfaceVariantLight,
          elevation: 8,
          type: BottomNavigationBarType.fixed,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.dividerLight,
          thickness: 1,
          space: 1,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceVariantLight,
          selectedColor: AppColors.primaryContainer,
          labelStyle: AppTypography.textTheme.labelMedium,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.chipRadius),
          side: const BorderSide(color: AppColors.outlineLight),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
          contentTextStyle: AppTypography.textTheme.bodyMedium?.copyWith(
            color: Colors.white,
          ),
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryLight,
          onPrimary: Colors.white,
          primaryContainer: Color(0xFF1B3A5C),
          onPrimaryContainer: AppColors.primaryLight,
          secondary: AppColors.secondary,
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFF1A4733),
          onSecondaryContainer: AppColors.secondaryLight,
          tertiary: AppColors.tertiary,
          tertiaryContainer: Color(0xFF5A3D00),
          surface: AppColors.surfaceDark,
          onSurface: AppColors.onSurfaceDark,
          surfaceContainerHighest: AppColors.surfaceVariantDark,
          onSurfaceVariant: AppColors.onSurfaceVariantDark,
          outline: AppColors.outlineDark,
          outlineVariant: AppColors.outlineVariantDark,
          error: AppColors.error,
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: AppColors.backgroundDark,
        textTheme: AppTypography.textTheme,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surfaceDark,
          foregroundColor: AppColors.onSurfaceDark,
          elevation: 0,
          scrolledUnderElevation: 1,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
        cardTheme: const CardThemeData(
          color: AppColors.surfaceDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.cardRadius,
            side: BorderSide(color: AppColors.outlineDark),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryLight,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
            padding: AppSpacing.buttonPadding,
            minimumSize: const Size(double.infinity, 52),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceVariantDark,
          border: OutlineInputBorder(
            borderRadius: AppRadius.buttonRadius,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.buttonRadius,
            borderSide: const BorderSide(color: AppColors.outlineDark),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.buttonRadius,
            borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.md,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surfaceDark,
          selectedItemColor: AppColors.primaryLight,
          unselectedItemColor: AppColors.onSurfaceVariantDark,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.dividerDark,
          thickness: 1,
          space: 1,
        ),
      );
}
