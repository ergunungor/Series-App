import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_input.dart';
import '../widgets/app_button.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController =
      TextEditingController(); // YENİ: Tekrar şifresi için controller
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController
        .dispose(); // YENİ: Bellek sızıntısını önlemek için
    super.dispose();
  }

  Future<void> _verifyAndUpdatePassword() async {
    final code = _codeController.text.trim();
    final newPassword = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // 1. Doğrulama: Kod 6 haneli mi?
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen 6 haneli kodu eksiksiz girin.')),
      );
      return;
    }

    // 2. Doğrulama: Şifre en az 6 karakter mi?
    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yeni şifreniz en az 6 karakter olmalıdır.'),
        ),
      );
      return;
    }

    // 3. Doğrulama: Şifreler eşleşiyor mu? (YENİ)
    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şifreler birbiriyle eşleşmiyor.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Önce 6 haneli OTP kodunu doğrula
      await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.recovery,
        email: widget.email,
        token: code,
      );

      // Kod doğruysa şifreyi güncelle
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Şifren başarıyla güncellendi! Giriş yapabilirsin.'),
          ),
        );
        context.go('/login');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kod hatalı veya süresi dolmuş.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // YENİ: Klavye açıldığında ekranın kayabilmesi için eklendi
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Yeni Şifre Belirle',
                  style: AppTypography.heading1.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.email} adresine gönderilen 6 haneli kodu gir.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body12Medium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                AppInput(
                  controller: _codeController,
                  hintText: '6 Haneli Kod',
                  prefixIcon: Icons.security,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                AppInput(
                  controller: _passwordController,
                  hintText: 'Yeni Şifre',
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                ),
                const SizedBox(height: 16),
                // YENİ: Şifre Tekrar Alanı
                AppInput(
                  controller: _confirmPasswordController,
                  hintText: 'Yeni Şifre (Tekrar)',
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                ),
                const SizedBox(height: 24),
                AppButton(
                  text: _isLoading ? 'GÜNCELLENİYOR...' : 'ŞİFREYİ GÜNCELLE',
                  showIcon: false,
                  onPressed: _isLoading ? null : _verifyAndUpdatePassword,
                ),
                const SizedBox(height: 24), // Alt boşluk
              ],
            ),
          ),
        ),
      ),
    );
  }
}
