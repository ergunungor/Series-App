import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_button.dart';
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

  Future<void> _verifyCode() async {
    if (_otpCode.length < 6) {
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
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
                '${widget.email} adresinize gelen\ndoğrulama kodunu giriniz.',
                textAlign: TextAlign.center,
                style: AppTypography.body16Regular.copyWith(
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 24),
              // YENİ: length parametresini 6 yaptık
              OtpInput(
                length: 6,
                onCompleted: (code) {
                  setState(() => _otpCode = code);
                  _verifyCode(); // Kullanıcı 6. rakamı girince otomatik doğrula
                },
              ),
              const Spacer(),
              AppButton(
                text: _isLoading ? 'DOĞRULANIYOR...' : 'DEVAM ET',
                showIcon: false,
                onPressed: _isLoading ? null : _verifyCode,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
