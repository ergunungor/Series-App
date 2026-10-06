import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/reveal.dart';
import '../widgets/screen_title_block.dart';
import '../widgets/series_wordmark.dart';
import '../widgets/app_bottom_nav.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Diğer sekmelerle aynı yatay sayfa boşluğu ve giriş ritmi.
  static const double _pagePadding = 16;
  static const double _navBarClearance = AppBottomNav.clearance;
  static const double _cardRadius = 24;
  static const double _groupGap = 16;
  static const Duration _revealDuration = Duration(milliseconds: 500);
  static const Duration _revealStagger = Duration(milliseconds: 100);
  static const Duration _switchDuration = Duration(milliseconds: 350);

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

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Hesabı Sil',
      message:
          'Hesabını ve tüm verilerini kalıcı olarak silmek istediğine emin misin? Bu işlem geri alınamaz.',
      confirmLabel: 'Hesabımı Sil',
      isDestructive: true,
    );

    if (confirmed) {
      try {
        setState(() => _isLoading = true);

        // Supabase'deki RPC fonksiyonumuzu tetikliyoruz
        await Supabase.instance.client.rpc('delete_user_account');

        // Oturumu kapatıp login sayfasına atıyoruz
        await Supabase.instance.client.auth.signOut();

        if (mounted) context.go('/login');
      } catch (e) {
        debugPrint('Hesap silme hatası: $e');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hesap silinirken bir hata oluştu.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          const SliverSafeArea(
            sliver: SliverToBoxAdapter(child: SizedBox(height: 12)),
            bottom: false,
          ),
          const SliverToBoxAdapter(child: SeriesWordmark()),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(_pagePadding, 16, _pagePadding, 16),
              child: ScreenTitleBlock(eyebrow: 'Hesap', title: 'Profil'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: _pagePadding,
              vertical: 16,
            ),
            sliver: SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: _switchDuration,
                child:
                    _isLoading
                        ? const _ProfileSkeleton(radius: _cardRadius)
                        : _ProfileCard(
                          initials: _initials,
                          name:
                              _fullName.isEmpty
                                  ? 'İsimsiz Kullanıcı'
                                  : _fullName,
                          email: _email,
                          radius: _cardRadius,
                        ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              _pagePadding,
              8,
              _pagePadding,
              MediaQuery.paddingOf(context).bottom + _navBarClearance,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Reveal(
                  delay: _revealStagger,
                  duration: _revealDuration,
                  child: _ActionGroup(
                    radius: _cardRadius,
                    children: [
                      _ActionRow(
                        icon: CupertinoIcons.square_arrow_right,
                        label: 'Çıkış Yap',
                        onTap: _handleLogout,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: _groupGap),
                // Yıkıcı eylem ayrı grupta ve kırmızı: yanlışlıkla çıkışla
                // karışmasın (App Store için Hesabı Sil zorunlu).
                Reveal(
                  delay: _revealStagger * 2,
                  duration: _revealDuration,
                  child: _ActionGroup(
                    radius: _cardRadius,
                    children: [
                      _ActionRow(
                        icon: CupertinoIcons.trash,
                        label: 'Hesabı Sil',
                        color: AppColors.error,
                        showChevron: false,
                        onTap: _handleDeleteAccount,
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _whiteCard(double radius) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ],
);

class _ProfileCard extends StatelessWidget {
  final String initials;
  final String name;
  final String email;
  final double radius;

  const _ProfileCard({
    required this.initials,
    required this.name,
    required this.email,
    required this.radius,
  });

  static const double _avatarSize = 72;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('profile_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.profileHero, AppColors.profileHeroDeep],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.profileHero.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: _avatarSize,
            height: _avatarSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.onHeroDark.withValues(alpha: 0.1),
              border: Border.all(
                color: AppColors.accentGold.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              initials,
              style: AppTypography.heading1.copyWith(
                color: AppColors.accentGold,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.heading2.copyWith(
              color: AppColors.onHeroDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body14Regular.copyWith(
              color: AppColors.onHeroDark.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  final double radius;

  const _ProfileSkeleton({required this.radius});

  // Yüklenmiş kartın yaklaşık yüksekliği (24 + 72 + 16 + 26 + 4 + 20 + 24).
  static const double _height = 186;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      key: const ValueKey('profile_skeleton'),
      baseColor: AppColors.borderSubtle,
      highlightColor: Colors.white,
      child: Container(
        height: _height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _ActionGroup extends StatelessWidget {
  final double radius;
  final List<Widget> children;

  const _ActionGroup({required this.radius, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _whiteCard(radius),
      child: Column(children: children),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool showChevron;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.textPrimary,
    this.showChevron = true,
  });

  static const double _height = 64;
  static const double _iconTile = 36;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.98,
      onTap: onTap,
      child: Container(
        height: _height,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Container(
              width: _iconTile,
              height: _iconTile,
              decoration: const BoxDecoration(
                color: AppColors.fillSubtle,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTypography.body16Medium.copyWith(color: color),
              ),
            ),
            if (showChevron)
              const Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}
