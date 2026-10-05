import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color brandPrimary = Color(0xFF960000); // ana bordo
  static const Color brandSecondary = Color(0xFFD8D8D8);
  static const Color brandTertiary = Color(0xFF5B1805);

  static const Color textPrimary = Color(0xFF360000);
  static const Color textSecondary = Color(0xFFCB0000);
  static const Color textTertiary = Color(0xFF818181);

  static const Color background = Color(0xFFF5F3F0);
  static const Color white = Color(0xFFFFFFFF);
  static const Color streak = Color(0xFFFF3C00);
  static const Color progressTrack = Color(0xFFD9D9D9);
  static const Color navSelectedBg = Color(0xFFEDEDED);

  // Hero kart gradient başlangıcı (bitişi: brandTertiary)
  static const Color heroGradientStart = Color(0xFFB3241B);

  // Nötr katman tonları (ikon karoları, buton zeminleri, hairline çizgiler)
  static const Color fillSubtle = Color(0xFFEFEBE6);
  static const Color borderSubtle = Color(0xFFE8E4DF);

  // Programlar ekranı hero kartı (espresso ve altın)
  static const Color heroDarkStart = Color(0xFF2B1B14);
  static const Color heroDarkEnd = Color(0xFF120A07);
  static const Color accentGold = Color(0xFFE3B55B);
  static const Color onHeroDark = Color(0xFFFFF4E0);

  // Programlar kartları (hero ile aynı espresso/altın ailesi)
  static const Color espresso = heroDarkStart;
  static const Color goldTint = Color(0xFFF3E4C4);
  static const Color goldDeep = Color(0xFFA87A22);
}
