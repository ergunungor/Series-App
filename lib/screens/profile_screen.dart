import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/detail_hero.dart' show HeroStatusBarScope;
import '../widgets/kiremit_hero_surface.dart';
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
      body: HeroStatusBarScope(
        builder:
            (context, heroKey) => CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: _buildScreenHero(heroKey)),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
      ),
    );
  }

  // Tam ekran antrasit hero: wordmark, başlık satırı ve hesap kimliği (avatar,
  // isim, e-posta).
  Widget _buildScreenHero(GlobalKey heroKey) {
    return KiremitHeroSurface(
      heroKey: heroKey,
      topColor: AppColors.profileHero,
      bottomColor: AppColors.profileHeroDeep,
      glowColor: AppColors.profileGlow,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _pagePadding,
          MediaQuery.paddingOf(context).top + 12,
          _pagePadding,
          32,
        ),
        child: Column(
          children: [
            SeriesWordmark(color: Colors.white.withValues(alpha: 0.9)),
            // Diğer sekmelerle aynı başlık konumu (wordmark + 16 boşluk).
            const SizedBox(height: 16),
            ScreenTitleBlock(
              eyebrow: 'Hesap',
              title: 'Profil',
              titleColor: Colors.white,
              eyebrowColor: Colors.white.withValues(alpha: 0.65),
            ),
            const SizedBox(height: 28),
            AnimatedSwitcher(
              duration: _switchDuration,
              child:
                  _isLoading
                      ? const _ProfileSkeleton()
                      : _ProfileIdentity(
                        initials: _initials,
                        name:
                            _fullName.isEmpty ? 'İsimsiz Kullanıcı' : _fullName,
                        email: _email,
                      ),
            ),
          ],
        ),
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

/// Hero içindeki hesap kimliği: altın halkalı avatar, isim ve e-posta.
class _ProfileIdentity extends StatelessWidget {
  final String initials;
  final String name;
  final String email;

  const _ProfileIdentity({
    required this.initials,
    required this.name,
    required this.email,
  });

  static const double avatarSize = 76;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('profile_identity'),
      children: [
        Container(
          width: avatarSize,
          height: avatarSize,
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
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.body14Regular.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

/// Kimlik yüklenirken: koyu zeminde silik shimmer (avatar ve iki satır).
class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(height / 2 > 8 ? 8 : height / 2),
      ),
    );

    return Shimmer.fromColors(
      key: const ValueKey('profile_skeleton'),
      baseColor: Colors.white.withValues(alpha: 0.1),
      highlightColor: Colors.white.withValues(alpha: 0.24),
      child: Column(
        children: [
          Container(
            width: _ProfileIdentity.avatarSize,
            height: _ProfileIdentity.avatarSize,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 16),
          // Yüklenmiş içerikle aynı yükseklikler: isim 26, e-posta 20.
          SizedBox(height: 26, child: Center(child: bar(160, 18))),
          const SizedBox(height: 4),
          SizedBox(height: 20, child: Center(child: bar(200, 12))),
        ],
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
