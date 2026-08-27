import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/app_confirm_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _fullName = '';
  String _email = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final response =
          await Supabase.instance.client
              .from('profiles')
              .select('full_name')
              .eq('id', user.id)
              .single();
      if (mounted) {
        setState(() {
          _fullName = response['full_name'] as String? ?? '';
          _email = user.email ?? '';
          _isLoading = false;
        });
      }
    } catch (error) {
      debugPrint('Profil çekme hatası: $error');
      if (mounted) {
        setState(() {
          _email = user.email ?? '';
          _isLoading = false;
        });
      }
    }
  }

  String get _initials {
    final trimmed = _fullName.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Future<void> _handleLogout() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Çıkış Yap',
      message: 'Hesabından çıkış yapmak istediğine emin misin?',
      confirmLabel: 'Çıkış Yap',
      isDestructive: true,
    );
    if (confirmed) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              const AppTopBar(),
              const SizedBox(height: 28),
              if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Container(
                        width: 96,
                        height: 96,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.brandTertiary,
                          border: Border.all(
                            color: AppColors.brandSecondary,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          _initials,
                          style: AppTypography.heading1.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _fullName.isEmpty ? 'İsimsiz Kullanıcı' : _fullName,
                        style: AppTypography.heading2.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _email,
                        style: AppTypography.body14Regular.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _handleLogout,
                          icon: const Icon(Icons.logout, color: Colors.red),
                          label: Text(
                            'Çıkış Yap',
                            style: AppTypography.body16Medium.copyWith(
                              color: Colors.red,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
