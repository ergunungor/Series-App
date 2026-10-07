import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_logo.dart';
import '../widgets/kiremit_hero_surface.dart';
import '../widgets/reveal.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Giriş ekranındaki hero logo karosuyla aynı boyut: splash → login geçişinde
  // logo aynı yerde, aynı büyüklükte kalır gibi görünür.
  static const double _logoTile = 76;
  static const Duration _introDuration = Duration(milliseconds: 900);

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
    final height = MediaQuery.sizeOf(context).height;

    return Scaffold(
      backgroundColor: AppColors.homeHeroDeep,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        // Zemin koyu kiremit: durum çubuğu simgeleri açık.
        value: SystemUiOverlayStyle.light,
        child: KiremitHeroSurface(
          bottomRadius: 0,
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: _introDuration,
                        curve: Curves.easeOutCubic,
                        builder: (context, t, _) {
                          // Logo karosu küçükten büyüyüp oturur, "SERIES"
                          // yazısının harf aralığı açılarak belirir.
                          final tile = Curves.easeOutBack.transform(t);
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Opacity(
                                opacity: t.clamp(0.0, 1.0),
                                child: Transform.scale(
                                  scale: 0.8 + 0.2 * tile,
                                  child: Container(
                                    width: _logoTile,
                                    height: _logoTile,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColors.onHeroDark.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        _logoTile * 0.3,
                                      ),
                                      border: Border.all(
                                        color: AppColors.onHeroDark.withValues(
                                          alpha: 0.18,
                                        ),
                                      ),
                                    ),
                                    child: const AppLogo(
                                      explicitSize: _logoTile * 0.56,
                                      type: AppLogoType.light,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Opacity(
                                opacity: Curves.easeIn.transform(t),
                                child: Text(
                                  'SERIES',
                                  style: AppTypography.body14Medium.copyWith(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2 + 6 * t,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
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
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'SERIES',
                            style: AppTypography.body12Medium.copyWith(
                              color: AppColors.accentGold,
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
          ),
        ),
      ),
    );
  }
}
