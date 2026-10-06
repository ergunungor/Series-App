import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Kiremit hero yüzeyi: dikey gradyan, sağ üstten gelen yumuşak ışık (üst
/// kenarda şeffafa solar), alt köşeleri yuvarlak, renkli alt gölge ve üstte
/// bounce (aşağı çekme) için aynı renkte uzun blok. İçeriği ve iç boşluğu
/// çağıran verir; [heroKey] kaydırmada durum çubuğu rengini ölçmek için
/// `HeroStatusBarScope` ile kullanılır.
class KiremitHeroSurface extends StatelessWidget {
  final GlobalKey heroKey;
  final Widget child;
  final double bottomRadius;

  const KiremitHeroSurface({
    super.key,
    required this.heroKey,
    required this.child,
    this.bottomRadius = 32,
  });

  // Işığın üstten ne kadarlık kısmında (hero yüksekliğinin oranı) soluk başladığı.
  static const double _glowFadeStop = 0.4;

  @override
  Widget build(BuildContext context) {
    final hero = Container(
      key: heroKey,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.homeHero, AppColors.homeHeroDeep],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(bottomRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.homeHeroDeep.withValues(alpha: 0.5),
            blurRadius: 40,
            spreadRadius: -18,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Sağ üstten gelen yumuşak ışık. Üst kenarda şeffafa solar: aşağı
          // çekince hero'nun üstündeki düz renkli bloğa kesiksiz bağlanır.
          Positioned.fill(
            child: IgnorePointer(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback:
                    (rect) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black],
                      stops: [0, _glowFadeStop],
                    ).createShader(rect),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.95, -0.6),
                      radius: 1.35,
                      colors: [
                        AppColors.homeHeroGlow,
                        AppColors.homeHeroGlow.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -MediaQuery.sizeOf(context).height,
          left: 0,
          right: 0,
          height: MediaQuery.sizeOf(context).height,
          child: const ColoredBox(color: AppColors.homeHero),
        ),
        hero,
      ],
    );
  }
}
