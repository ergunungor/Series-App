import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/otp_input.dart';

class VerificationScreen extends StatefulWidget {
  final String fullName;
  final String email;

  const VerificationScreen({
    super.key,
    required this.fullName,
    required this.email,
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  bool _isLoading = false;
  String _otpCode = '';
  // Hata olunca alanları sallamak için artan sayaç (yalnızca görsel).
  int _shakeCount = 0;

  Future<void> _verifyCode() async {
    if (_otpCode.length < 6) {
      setState(() => _shakeCount++);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen 6 haneli kodu eksiksiz girin.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Supabase'e kodu doğrulat
      final res = await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.signup,
        email: widget.email,
        token: _otpCode,
      );

      final user = res.user;

      if (user != null) {
        // 2. Kod doğruysa kullanıcıyı profiles tablomuza kaydet
        await Supabase.instance.client.from('profiles').insert({
          'id': user.id,
          'full_name': widget.fullName,
          'email': widget.email,
        });

        // 3. İşlem başarılıysa Ana Sayfaya yönlendir
        if (mounted) {
          context.go('/home');
        }
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _shakeCount++);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _shakeCount++);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Doğrulama sırasında bir hata oluştu.')),
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
      title: 'E-mail Doğrulama',
      onBack: () => context.pop(),
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: widget.email,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const TextSpan(
                text: ' adresinize gelen\ndoğrulama kodunu giriniz.',
              ),
            ],
          ),
          style: AppTypography.body16Regular.copyWith(
            color: AppColors.textTertiary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        AuthShake(
          trigger: _shakeCount,
          // YENİ: length parametresini 6 yaptık
          child: OtpInput(
            length: 6,
            onCompleted: (code) {
              setState(() => _otpCode = code);
              _verifyCode(); // Kullanıcı 6. rakamı girince otomatik doğrula
            },
          ),
        ),
        const SizedBox(height: 28),
        AppButton(
          text: _isLoading ? 'DOĞRULANIYOR...' : 'DEVAM ET',
          showIcon: false,
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _verifyCode,
        ),
      ],
    );
  }
}
