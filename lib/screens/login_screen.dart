import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_input.dart';
import '../widgets/app_button.dart';
import '../widgets/auth_scaffold.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  // Hata olunca alanları sallamak için artan sayaç (yalnızca görsel).
  int _shakeCount = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _shakeCount++);
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', _rememberMe);

      if (mounted) {
        context.go('/home'); // Başarılıysa Ana Sayfaya
      }
    } on AuthException catch (_) {
      if (mounted) {
        setState(() => _shakeCount++);
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
    return AuthScaffold(
      title: 'Kullanıcı Girişi',
      children: [
        AuthShake(
          trigger: _shakeCount,
          child: Column(
            children: [
              AppInput(
                controller: _emailController, // EKLENDİ
                hintText: 'E-mail Adresiniz',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.mail_outline,
              ),
              const SizedBox(height: 12),
              AppInput(
                controller: _passwordController, // EKLENDİ
                hintText: 'Şifre',
                prefixIcon: Icons.lock_outline,
                isPassword: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _rememberMe = !_rememberMe),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged:
                          (v) => setState(() => _rememberMe = v ?? false),
                      activeColor: AppColors.homeHero,
                      side: const BorderSide(
                        color: AppColors.textTertiary,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Beni hatırla',
                    style: AppTypography.body12Medium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push('/forgot-password'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Şifremi unuttum',
                  style: AppTypography.body12Medium.copyWith(
                    color: AppColors.homeHero,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        AppButton(
          text: _isLoading ? 'GİRİŞ YAPILIYOR...' : 'GİRİŞ YAP',
          showIcon: false,
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _signIn, // EKLENDİ
        ),
        const SizedBox(height: 16),
        const AuthDivider(),
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
    );
  }
}
