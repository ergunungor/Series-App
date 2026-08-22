import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_logo.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

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
