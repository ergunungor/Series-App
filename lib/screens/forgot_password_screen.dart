import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // EKLENDİ
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_input.dart';
import '../widgets/app_button.dart';
import '../widgets/auth_scaffold.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  // Hata olunca alanları sallamak için artan sayaç (yalnızca görsel).
  int _shakeCount = 0;

  Future<void> _sendResetCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _shakeCount++);
      return;
    }

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
        setState(() => _shakeCount++);
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
    return AuthScaffold(
      title: 'Şifremi Unuttum',
      onBack: () => context.pop(),
      children: [
        AuthShake(
          trigger: _shakeCount,
          child: AppInput(
            controller: _emailController,
            hintText: 'E-mail Adresiniz',
            prefixIcon: Icons.mail_outline,
          ),
        ),
        const SizedBox(height: 18),
        AppButton(
          text: _isLoading ? 'KOD GÖNDERİLİYOR...' : 'KOD GÖNDER',
          showIcon: false,
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _sendResetCode,
        ),
      ],
    );
  }
}
