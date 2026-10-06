import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // --- Zemin, yüzey ve metin ---
  static const Color background = Color(0xFFF5F3F0); // sıcak nötr zemin
  static const Color textPrimary = Color(0xFF2B1B14); // espresso
  static const Color textTertiary = Color(0xFF818181);

  // Nötr katman tonları (ikon karoları, buton zeminleri, hairline çizgiler)
  static const Color fillSubtle = Color(0xFFEFEBE6);
  static const Color borderSubtle = Color(0xFFE8E4DF);

  // --- Durum renkleri ---
  static const Color success = Color(0xFF3E7B52);
  static const Color error = Color(0xFFB3261E);

  // --- Espresso ve altın ailesi (Programlar, vurgu rengi) ---
  static const Color espresso = Color(0xFF2B1B14);
  static const Color heroDarkStart = espresso;
  static const Color heroDarkEnd = Color(0xFF120A07);
  static const Color espressoGlow = Color(0xFF4A2A1D);
  static const Color accentGold = Color(0xFFE3B55B);
  static const Color goldTint = Color(0xFFF3E4C4);
  static const Color goldDeep = Color(0xFFA87A22);
  static const Color onHeroDark = Color(0xFFFFF4E0);

  // --- Ana Sayfa, auth ve antrenman esnası: kiremit (marka rengi) ---
  static const Color homeHeroGlow = Color(0xFFA5392B);
  static const Color homeHero = Color(0xFF7A2418);
  static const Color homeHeroDeep = Color(0xFF47130C);

  // --- Antrenmanlar: ardıç yeşili ---
  static const Color workoutsHero = Color(0xFF24382E);
  static const Color workoutsHeroDeep = Color(0xFF141F19);
  static const Color workoutsAccent = Color(0xFF2F5D46);
  static const Color workoutsTint = Color(0xFFE4EEE8);

  // --- Profil: sıcak antrasit ---
  static const Color profileHero = Color(0xFF25262B);
  static const Color profileHeroDeep = Color(0xFF17181C);
}
