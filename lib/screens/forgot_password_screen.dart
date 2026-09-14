import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // EKLENDİ
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_input.dart';
import '../widgets/app_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendResetCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      // Deeplink (redirectTo) tamamen kaldırıldı
      await Supabase.instance.client.auth.resetPasswordForEmail(email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '6 haneli şifre sıfırlama kodu e-postana gönderildi.',
            ),
          ),
        );
        // E-posta adresini doğrulama ekranına taşıyoruz
        context.push('/reset-password', extra: email);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bir hata oluştu, tekrar dene.')),
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Şifremi Unuttum',
                  style: AppTypography.heading1.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                AppInput(
                  controller: _emailController,
                  hintText: 'E-mail Adresiniz',
                  prefixIcon: Icons.mail_outline,
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: _isLoading ? 'KOD GÖNDERİLİYOR...' : 'KOD GÖNDER',
                  showIcon: false,
                  onPressed: _isLoading ? null : _sendResetCode,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
