import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // --- Semantic palet: espresso + altın (11.1) ---
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEFEBE6);
  static const Color border = Color(0xFFE8E4DF);

  static const Color primary = Color(0xFF2B1B14);
  static const Color primaryDeep = Color(0xFF120A07);
  static const Color onPrimary = Color(0xFFFFF4E0);

  static const Color accent = Color(0xFFE3B55B);
  static const Color accentTint = Color(0xFFF3E4C4);
  static const Color accentDeep = Color(0xFFA87A22);
  static const Color onAccent = primary;

  static const Color success = Color(0xFF3E7B52);
  static const Color warning = accentDeep;
  static const Color error = Color(0xFFB3261E);

  // Antrenmanlar ekranı (ardıç yeşili)
  static const Color workoutsHero = Color(0xFF24382E);
  static const Color workoutsHeroDeep = Color(0xFF141F19);
  static const Color workoutsAccent = Color(0xFF2F5D46);

  // --- Eski palet (migrasyon bitince silinecek) ---
  static const Color brandPrimary = Color(0xFF960000); // ana bordo
  static const Color brandSecondary = Color(0xFFD8D8D8);
  static const Color brandTertiary = Color(0xFF5B1805);

  static const Color textPrimary = Color(0xFF360000);
  static const Color textSecondary = Color(0xFFCB0000);
  static const Color textTertiary = Color(0xFF818181);

  static const Color background = Color(0xFFF5F3F0);
  static const Color white = surface;
  static const Color streak = Color(0xFFFF3C00);
  static const Color progressTrack = Color(0xFFD9D9D9);
  static const Color navSelectedBg = Color(0xFFEDEDED);

  // Hero kart gradient başlangıcı (bitişi: brandTertiary)
  static const Color heroGradientStart = Color(0xFF8A2A20);

  // Nötr katman tonları (ikon karoları, buton zeminleri, hairline çizgiler)
  static const Color fillSubtle = surfaceMuted;
  static const Color borderSubtle = border;

  // Eski isimler (geçiş boyunca takma ad). Ekranlar yeni isimlere taşındıkça silinecek.
  static const Color heroDarkStart = primary;
  static const Color heroDarkEnd = primaryDeep;
  static const Color accentGold = accent;
  static const Color onHeroDark = onPrimary;
  static const Color espresso = primary;
  static const Color goldTint = accentTint;
  static const Color goldDeep = accentDeep;
}
