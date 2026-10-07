import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_logo.dart';
import 'pressable_scale.dart';
import 'reveal.dart';

/// Giriş/kayıt/şifre ekranlarının ortak iskeleti: üstte ışıklı kiremit hero
/// (cam karoda logo + SERIES), altında üst köşeleri 32 yuvarlak krem kart.
/// Klavye açılınca hero küçülür; kartın içindeki öğeler sırayla belirir.
class AuthScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;

  /// Verilirse hero'nun sol üstünde geri butonu çıkar.
  final VoidCallback? onBack;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.children,
    this.onBack,
  });

  static const double _sheetRadius = 32;
  static const double _heroHeight = 280;
  static const double _heroHeightKeyboard = 172;
  static const double _pagePadding = 20;
  static const Duration _layoutDuration = Duration(milliseconds: 320);
  // Aralık öğeleri (SizedBox) de sayıldığı için kısa tutuluyor.
  static const Duration _revealStagger = Duration(milliseconds: 55);
  static const Duration _revealDuration = Duration(milliseconds: 500);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboardOpen = mq.viewInsets.bottom > 0;
    final heroHeight = keyboardOpen ? _heroHeightKeyboard : _heroHeight;

    return Scaffold(
      backgroundColor: AppColors.homeHeroDeep,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        // Hero koyu olduğu için durum çubuğu simgeleri açık.
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: _layoutDuration,
              curve: Curves.easeOutCubic,
              top: 0,
              left: 0,
              right: 0,
              height: heroHeight,
              child: _Hero(
                keyboardOpen: keyboardOpen,
                topInset: mq.padding.top,
                onBack: onBack,
              ),
            ),
            AnimatedPositioned(
              duration: _layoutDuration,
              curve: Curves.easeOutCubic,
              top: heroHeight - _sheetRadius,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(_sheetRadius),
                  ),
                ),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    _pagePadding,
                    28,
                    _pagePadding,
                    mq.padding.bottom + 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Reveal(
                        duration: _revealDuration,
                        child: Text(
                          title,
                          style: AppTypography.heading1.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      for (var i = 0; i < children.length; i++)
                        Reveal(
                          delay: _revealStagger * (i + 1),
                          duration: _revealDuration,
                          child: children[i],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final bool keyboardOpen;
  final double topInset;
  final VoidCallback? onBack;

  const _Hero({
    required this.keyboardOpen,
    required this.topInset,
    required this.onBack,
  });

  static const double _logoTile = 76;
  static const double _logoTileSmall = 52;

  @override
  Widget build(BuildContext context) {
    final tile = keyboardOpen ? _logoTileSmall : _logoTile;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.homeHero, AppColors.homeHeroDeep],
        ),
      ),
      child: Stack(
        children: [
          // Sağ üstten gelen yumuşak ışık
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.95, -0.9),
                  radius: 1.2,
                  colors: [
                    AppColors.homeHeroGlow,
                    AppColors.homeHeroGlow.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          if (onBack != null)
            Positioned(
              left: 16,
              top: topInset + 8,
              child: PressableScale(
                pressedScale: 0.92,
                onTap: onBack,
                child: Container(
                  width: 44,
                  height: 44,
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
            ),
          Padding(
            // Alttaki kart 32px üstüne biniyor; içerik görünür alanda ortalansın.
            padding: EdgeInsets.only(
              top: topInset,
              bottom: AuthScaffold._sheetRadius,
            ),
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutBack,
                builder:
                    (context, t, child) => Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.8 + 0.2 * t,
                        child: child,
                      ),
                    ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: AuthScaffold._layoutDuration,
                      curve: Curves.easeOutCubic,
                      width: tile,
                      height: tile,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.onHeroDark.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(tile * 0.3),
                        border: Border.all(
                          color: AppColors.onHeroDark.withValues(alpha: 0.18),
                        ),
                      ),
                      child: AppLogo(
                        explicitSize: tile * 0.56,
                        type: AppLogoType.light,
                      ),
                    ),
                    AnimatedSize(
                      duration: AuthScaffold._layoutDuration,
                      curve: Curves.easeOutCubic,
                      child:
                          keyboardOpen
                              ? const SizedBox(width: double.infinity)
                              : Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Text(
                                  'SERIES',
                                  style: AppTypography.body14Medium.copyWith(
                                    color: AppColors.onHeroDark.withValues(
                                      alpha: 0.9,
                                    ),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 6,
                                  ),
                                ),
                              ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Alt öğeyi [trigger] her arttığında kısa bir yatay titremeyle sallar (hata
/// geri bildirimi).
class AuthShake extends StatefulWidget {
  final int trigger;
  final Widget child;

  const AuthShake({super.key, required this.trigger, required this.child});

  @override
  State<AuthShake> createState() => _AuthShakeState();
}

class _AuthShakeState extends State<AuthShake>
    with SingleTickerProviderStateMixin {
  static const Duration _duration = Duration(milliseconds: 420);
  static const double _amplitude = 8;
  static const int _wiggles = 3;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
  );

  @override
  void didUpdateWidget(AuthShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) {
      HapticFeedback.mediumImpact();
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        // Sönümlenen sinüs: başta güçlü, sonda sıfır.
        final t = _controller.value;
        final dx = math.sin(t * math.pi * 2 * _wiggles) * (1 - t) * _amplitude;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}

/// "veya" ayırıcı: iki ince çizgi arasında silik metin.
class AuthDivider extends StatelessWidget {
  final String label;

  const AuthDivider({super.key, this.label = 'veya'});

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(height: 1, color: AppColors.borderSubtle),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: AppTypography.body12Regular.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ),
        line,
      ],
    );
  }
}
