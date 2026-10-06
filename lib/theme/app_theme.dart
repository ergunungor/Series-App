import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.homeHero,
        primary: AppColors.homeHero,
        surface: AppColors.background,
      ),
      textTheme: TextTheme(
        headlineLarge: AppTypography.heading1,
        headlineMedium: AppTypography.heading2,
        headlineSmall: AppTypography.heading3,
        bodyLarge: AppTypography.body16Regular,
        bodyMedium: AppTypography.body14Regular,
        bodySmall: AppTypography.body12Regular,
      ),
      // Tüm uygulamadaki varsayılan snackbar'lar: koyu espresso, yuvarlak,
      // yüzen; eylem rengi altın. Ekranlar kendi rengini isterse yine verebilir.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.espresso,
        elevation: 6,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        contentTextStyle: AppTypography.body14Medium.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: AppColors.accentGold,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.homeHero,
        selectionColor: AppColors.homeHero.withValues(alpha: 0.2),
        selectionHandleColor: AppColors.homeHero,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.homeHero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
      ),
    );
  }
}
