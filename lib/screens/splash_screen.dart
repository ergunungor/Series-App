import 'dart:async'; // Timer için gerekli
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // Sayfa geçişi için gerekli
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_logo.dart';

// SplashScreen'i StatefulWidget yaptık ki initState kullanabilelim
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Ekran açıldıktan 2 saniye (2000 ms) sonra login ekranına geç
    Timer(const Duration(seconds: 2), () {
      // Eğer sayfa hala ekrandaysa geçiş yap (güvenlik kontrolü)
      if (mounted) {
        // AppRouter'da tanımladığımız o özel 500ms'lik geçiş tetiklenecek
        context.go('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: AppLogoSize.large, type: AppLogoType.dark),
            const SizedBox(height: 32),
            Text('SERIES', style: AppTypography.wordmark),
          ],
        ),
      ),
    );
  }
}
