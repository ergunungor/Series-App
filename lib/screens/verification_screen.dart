import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_button.dart';
import '../widgets/otp_input.dart';

class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 52),
              const AppLogo(size: AppLogoSize.medium, type: AppLogoType.dark),
              const SizedBox(height: 32),
              Text(
                'E-mail Doğrulama',
                textAlign: TextAlign.center,
                style: AppTypography.heading1.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'E-m ail adresinize gelen doğrulama kodunu\ngiriniz.',
                textAlign: TextAlign.center,
                style: AppTypography.body16Regular.copyWith(
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 24),
              OtpInput(onCompleted: (code) {}),
              const Spacer(),
              AppButton(text: 'DEVAM ET', showIcon: false, onPressed: () {}),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
