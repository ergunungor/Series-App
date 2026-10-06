import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_input.dart';
import '../widgets/app_button.dart';
import '../widgets/auth_scaffold.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Form verilerini tutacağımız controller'lar
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _isLoading = false; // Butona basılınca yükleniyor animasyonu/engeli için
  bool _rememberMe = false;
  // Hata olunca alanları sallamak için artan sayaç (yalnızca görsel).
  int _shakeCount = 0;

  @override
  void dispose() {
    // Hafıza sızıntısını önlemek için sayfadan çıkıldığında temizliyoruz
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    // 1. Şifrelerin eşleşip eşleşmediğini kontrol et
    if (_passwordController.text != _passwordConfirmController.text) {
      setState(() => _shakeCount++);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şifreler birbiriyle eşleşmiyor!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Sadece Auth üzerinden kayıt ol, kod maile gitsin.
      // BURADAN İNSERT İŞLEMİNİ TAMAMEN KALDIRDIK!
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // 3. İşlem başarılıysa, profili OLUŞTURMADAN doğrudan doğrulama ekranına git.
      if (mounted) {
        context.push(
          '/verification',
          extra: {
            'fullName': _nameController.text.trim(),
            'email': _emailController.text.trim(),
          },
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _shakeCount++);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      debugPrint('KAYIT HATASI: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kayıt olurken beklenmeyen bir hata oluştu.'),
          ),
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
      title: 'Kayıt Ol',
      onBack: () => context.pop(),
      children: [
        AuthShake(
          trigger: _shakeCount,
          child: Column(
            children: [
              AppInput(
                controller: _nameController,
                hintText: 'Ad Soyad',
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 12),
              AppInput(
                controller: _emailController,
                hintText: 'E-mail Adresiniz',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.mail_outline,
              ),
              const SizedBox(height: 12),
              AppInput(
                controller: _passwordController,
                hintText: 'Şifre',
                prefixIcon: Icons.lock_outline,
                isPassword: true,
              ),
              const SizedBox(height: 12),
              AppInput(
                controller: _passwordConfirmController,
                hintText: 'Şifreyi Tekrar Giriniz',
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
          text: _isLoading ? 'KAYDEDİLİYOR...' : 'KAYIT OL',
          showIcon: false,
          isLoading: _isLoading,
          // Yükleniyorsa butona tekrar basılmasını engelle, değilse fonksiyonu çağır
          onPressed: _isLoading ? null : _signUp,
        ),
        const SizedBox(height: 16),
        const AuthDivider(label: 'Zaten hesabınız var mı?'),
        const SizedBox(height: 16),
        AppButton(
          text: 'GİRİŞ YAP',
          variant: AppButtonVariant.outlined,
          showIcon: false,
          onPressed: () {
            context.go('/login');
          }, // Giriş ekranına geçiş
        ),
      ],
    );
  }
}
