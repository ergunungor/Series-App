import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
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
                child: _Reveal(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppLogo(
                        size: AppLogoSize.large,
                        type: AppLogoType.dark,
                      ),
                      const SizedBox(height: 32),
                      Text('SERIES', style: AppTypography.wordmark),
                    ],
                  ),
                ),
              ),
            ),
            // En altta imza alanı, logodan biraz sonra belirir
            _Reveal(
              delay: const Duration(milliseconds: 500),
              offsetY: 8,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'POWERED BY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.0,
                        color: AppColors.textTertiary.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SERIES',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: AppColors.brandPrimary,
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

class _Reveal extends StatelessWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  const _Reveal({
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 700),
    this.offsetY = 12,
  });

  @override
  Widget build(BuildContext context) {
    // TweenAnimationBuilder'da gecikme yok; bu yüzden toplam süreyi uzatıp
    // eğrinin ilk kısmını (gecikme payını) Interval ile boş bırakıyoruz.
    final total = delay + duration;
    final curve = Interval(
      delay.inMilliseconds / total.inMilliseconds,
      1.0,
      curve: Curves.easeOutCubic,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: total,
      curve: curve,
      child: child,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * offsetY),
            child: child,
          ),
        );
      },
    );
  }
}
