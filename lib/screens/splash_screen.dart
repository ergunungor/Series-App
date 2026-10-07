import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_logo.dart';
import '../widgets/reveal.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const double _logoSize = 120;
  static const Duration _introDuration = Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        final hasSession = Supabase.instance.client.auth.currentSession != null;
        context.go(hasSession ? '/home' : '/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Logonun tam ekranın ortasında kalmasını sağlayan esnek alan
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo kendi renklerinde, yumuşakça belirir (fade + 12px).
                    Reveal(
                      duration: _introDuration,
                      child: const AppLogo(
                        explicitSize: _logoSize,
                        type: AppLogoType.dark,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Reveal(
                      delay: const Duration(milliseconds: 150),
                      duration: _introDuration,
                      child: Padding(
                        // Harf aralığı son harften sonra da boşluk bırakır;
                        // aynı miktar soldan eklenerek optik ortalanıyor.
                        padding: const EdgeInsets.only(left: 7),
                        child: Text(
                          'SERIES',
                          style: AppTypography.body14Medium.copyWith(
                            color: AppColors.homeHeroDeep,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // En altta imza alanı, logodan biraz sonra belirir
            Reveal(
              delay: const Duration(milliseconds: 500),
              offsetY: 8,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'POWERED BY',
                      style: AppTypography.body12Medium.copyWith(
                        color: AppColors.textTertiary.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SERIES',
                      style: AppTypography.body12Medium.copyWith(
                        color: AppColors.homeHero,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
