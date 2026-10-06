import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_logo.dart';
import 'pressable_scale.dart';

/// Hero panelindeki tek bir rakam: büyük değer + küçük etiket.
class DetailHeroStat {
  final String value;
  final String label;

  const DetailHeroStat(this.value, this.label);
}

/// Detay ekranlarının koyu hero paneli: geri butonu, opsiyonel sağ eylem, başlık,
/// opsiyonel alt satır ve rakam şeridi. Alt köşeler 32, silik logo filigranı,
/// üstte bounce (aşağı çekme) için aynı renkte uzun blok.
///
/// Durum çubuğu rengini hero kaybolunca koyuya çevirmek için ekranın kaydırılan
/// alanını [HeroStatusBarScope] ile sarın ve [heroKey]'i oradan alın.
class DetailHero extends StatelessWidget {
  final GlobalKey heroKey;
  final List<Color> gradientColors;
  final VoidCallback onBack;
  final Widget? trailing;
  final String title;
  final int? titleMaxLines;
  final String? subtitle;
  final List<DetailHeroStat> stats;

  const DetailHero({
    super.key,
    required this.heroKey,
    required this.gradientColors,
    required this.onBack,
    required this.title,
    required this.stats,
    this.trailing,
    this.titleMaxLines,
    this.subtitle,
  });

  static const double _pagePadding = 16;
  static const double _radius = 32;
  static const double _bottomPadding = 28;
  static const double _buttonSize = 44;

  @override
  Widget build(BuildContext context) {
    final hero = Container(
      key: heroKey,
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.fromLTRB(
        _pagePadding,
        MediaQuery.paddingOf(context).top + 12,
        _pagePadding,
        _bottomPadding,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradientColors,
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(_radius),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -32,
            bottom: -44,
            child: Opacity(
              opacity: 0.06,
              child: const AppLogo(explicitSize: 190, type: AppLogoType.light),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PressableScale(
                    pressedScale: 0.92,
                    onTap: onBack,
                    child: Container(
                      width: _buttonSize,
                      height: _buttonSize,
                      decoration: BoxDecoration(
                        color: AppColors.onHeroDark.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.back,
                        size: 20,
                        color: AppColors.onHeroDark,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 28),
              Text(
                title,
                maxLines: titleMaxLines,
                overflow: titleMaxLines == null ? null : TextOverflow.ellipsis,
                style: AppTypography.heading1.copyWith(
                  color: AppColors.onHeroDark,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: AppTypography.body14Regular.copyWith(
                    color: AppColors.onHeroDark.withValues(alpha: 0.7),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              IntrinsicHeight(
                child: Row(
                  children: [
                    for (var i = 0; i < stats.length; i++) ...[
                      if (i > 0) const _StatDivider(),
                      _Stat(stat: stats[i], isFirst: i == 0),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // Üst kenar boşluğa çekilince (bounce) hero'nun üstü açık kalmasın diye
    // hero'nun üstüne aynı renkte uzun bir blok ekliyoruz. Normalde ekran
    // dışında, sadece aşağı çekilirken görünür.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -MediaQuery.sizeOf(context).height,
          left: 0,
          right: 0,
          height: MediaQuery.sizeOf(context).height,
          child: ColoredBox(color: gradientColors.first),
        ),
        hero,
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final DetailHeroStat stat;
  final bool isFirst;

  const _Stat({required this.stat, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(left: isFirst ? 0 : 14, right: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stat.value,
              style: AppTypography.heading2.copyWith(
                color: AppColors.onHeroDark,
                fontWeight: FontWeight.w700,
                height: 1,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              stat.label,
              style: AppTypography.body12Regular.copyWith(
                color: AppColors.onHeroDark.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.5,
      color: AppColors.onHeroDark.withValues(alpha: 0.18),
    );
  }
}

/// Kaydırılan içeriği sarar: hero ekranın üstünden çıkınca durum çubuğu
/// simgelerini açıktan koyuya çevirir. [builder] hero'ya verilecek
/// [GlobalKey]'i alır.
class HeroStatusBarScope extends StatefulWidget {
  final Widget Function(BuildContext context, GlobalKey heroKey) builder;

  const HeroStatusBarScope({super.key, required this.builder});

  @override
  State<HeroStatusBarScope> createState() => _HeroStatusBarScopeState();
}

class _HeroStatusBarScopeState extends State<HeroStatusBarScope> {
  final GlobalKey _heroKey = GlobalKey();
  bool _isStatusBarLight = true;

  bool _handleScroll(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification || notification.depth != 0) {
      return false;
    }
    final heroHeight = _heroKey.currentContext?.size?.height;
    if (heroHeight == null) return false;

    final isLight =
        notification.metrics.pixels <
        heroHeight - MediaQuery.paddingOf(context).top;
    if (isLight != _isStatusBarLight) {
      setState(() => _isStatusBarLight = isLight);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Hero durum çubuğunun arkasındayken açık, liste altına geçince koyu
      value:
          _isStatusBarLight
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScroll,
        child: widget.builder(context, _heroKey),
      ),
    );
  }
}
