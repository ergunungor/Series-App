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
        seedColor: AppColors.brandPrimary,
        primary: AppColors.brandPrimary,
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
    );
  }
}
