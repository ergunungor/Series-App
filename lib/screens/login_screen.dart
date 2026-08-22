import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_input.dart';
import '../widgets/app_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _rememberMe = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Kullanıcı Girişi',
                  textAlign: TextAlign.center,
                  style: AppTypography.heading1.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                AppInput(
                  hintText: 'E-mail Adresiniz',
                  prefixIcon: Icons.mail_outline,
                ),
                const SizedBox(height: 16),
                AppInput(
                  hintText: 'Şifre',
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged:
                                (v) => setState(() => _rememberMe = v ?? false),
                            side: BorderSide(color: AppColors.brandSecondary),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Beni hatırla',
                          style: AppTypography.body12Medium.copyWith(
                            color: AppColors.brandSecondary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Şifremi unuttum',
                      style: AppTypography.body12Medium.copyWith(
                        color: AppColors.brandSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppButton(text: 'GİRİŞ YAP', showIcon: false, onPressed: () {}),
                const SizedBox(height: 16),
                Text(
                  'veya',
                  textAlign: TextAlign.center,
                  style: AppTypography.body12Medium.copyWith(
                    color: AppColors.brandSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: 'KAYIT OL',
                  variant: AppButtonVariant.outlined,
                  showIcon: false,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
