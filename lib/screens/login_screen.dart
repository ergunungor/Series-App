import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_input.dart';
import '../widgets/app_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen e-posta ve şifrenizi girin.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        context.go('/home'); // Başarılıysa Ana Sayfaya
      }
    } on AuthException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Giriş başarısız: Lütfen bilgilerinizi kontrol edin.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Beklenmeyen bir hata oluştu.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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
                  controller: _emailController, // EKLENDİ
                  hintText: 'E-mail Adresiniz',
                  prefixIcon: Icons.mail_outline,
                ),
                const SizedBox(height: 16),
                AppInput(
                  controller: _passwordController, // EKLENDİ
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
                AppButton(
                  text: _isLoading ? 'GİRİŞ YAPILIYOR...' : 'GİRİŞ YAP',
                  showIcon: false,
                  onPressed: _isLoading ? null : _signIn, // EKLENDİ
                ),
                const SizedBox(height: 16),
                Text(
                  'veya', // ... (tasarım kodları aynı kalıyor)
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: 'KAYIT OL',
                  variant: AppButtonVariant.outlined,
                  showIcon: false,
                  onPressed: () {
                    context.push('/register'); // YENİ: Kayıt ekranına geçiş
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
