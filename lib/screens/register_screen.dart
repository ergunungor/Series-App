import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_input.dart';
import '../widgets/app_button.dart';
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
                  'Kayıt Ol',
                  textAlign: TextAlign.center,
                  style: AppTypography.heading1.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                AppInput(
                  controller: _nameController,
                  hintText: 'Ad Soyad',
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                AppInput(
                  controller: _emailController,
                  hintText: 'E-mail Adresiniz',
                  prefixIcon: Icons.mail_outline,
                ),
                const SizedBox(height: 16),
                AppInput(
                  controller: _passwordController,
                  hintText: 'Şifre',
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                ),
                const SizedBox(height: 16),
                AppInput(
                  controller: _passwordConfirmController,
                  hintText: 'Şifreyi Tekrar Giriniz',
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
                  text: _isLoading ? 'KAYDEDİLİYOR...' : 'KAYIT OL',
                  showIcon: false,
                  // Yükleniyorsa butona tekrar basılmasını engelle, değilse fonksiyonu çağır
                  onPressed: _isLoading ? null : _signUp,
                ),
                const SizedBox(height: 16),
                Text(
                  'Zaten hesabınız var mı?',
                  textAlign: TextAlign.center,
                  style: AppTypography.body12Medium.copyWith(
                    color: AppColors.brandSecondary,
                  ),
                ),
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
            ),
          ),
        ),
      ),
    );
  }
}
