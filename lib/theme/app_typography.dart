import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static TextStyle _manrope({
    required double fontSize,
    required FontWeight fontWeight,
    required double height,
    Color color = AppColors.textPrimary,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height / fontSize,
      color: color,
    );
  }

  static TextStyle get heading1 =>
      _manrope(fontSize: 28, fontWeight: FontWeight.w600, height: 38);
  static TextStyle get heading2 =>
      _manrope(fontSize: 24, fontWeight: FontWeight.w500, height: 26);
  static TextStyle get heading3 =>
      _manrope(fontSize: 22, fontWeight: FontWeight.w500, height: 26);

  static TextStyle get body18Medium =>
      _manrope(fontSize: 18, fontWeight: FontWeight.w500, height: 20);
  static TextStyle get body16Medium =>
      _manrope(fontSize: 16, fontWeight: FontWeight.w500, height: 20);
  static TextStyle get body16Regular =>
      _manrope(fontSize: 16, fontWeight: FontWeight.w400, height: 20);
  static TextStyle get body14Medium =>
      _manrope(fontSize: 14, fontWeight: FontWeight.w500, height: 20);
  static TextStyle get body14Regular =>
      _manrope(fontSize: 14, fontWeight: FontWeight.w400, height: 20);
  static TextStyle get body12Medium =>
      _manrope(fontSize: 12, fontWeight: FontWeight.w500, height: 20);
  static TextStyle get body12Regular =>
      _manrope(fontSize: 12, fontWeight: FontWeight.w400, height: 20);
  static TextStyle get wordmark => _manrope(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    height: 38,
    color: AppColors.brandTertiary,
  );
}
