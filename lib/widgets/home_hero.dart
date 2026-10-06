import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'pressable_scale.dart';
import 'series_wordmark.dart';

/// Ana Sayfa'nın tam ekran hero'su: ekranın tepesine (durum çubuğunun arkasına)
/// uzanır; selamlama, sıradaki antrenman, başlat butonu ve opsiyonel hafta
/// şeridini tek kiremit yüzeyde toplar.
///
/// [workoutName] null ise antrenman bloğu çizilmez (yükleniyorsa iskelet,
/// değilse yalnızca selamlama).
class HomeHero extends StatelessWidget {
  final GlobalKey heroKey;
  final String firstName;
  final bool isLoading;
  final String? workoutName;
  final int exerciseCount;
  final int durationMin;
  final VoidCallback? onStart;

  /// Butonun altında gösterilen alan (hafta şeridi).
  final Widget? footer;

  const HomeHero({
    super.key,
    required this.heroKey,
    required this.firstName,
    required this.isLoading,
    this.workoutName,
    this.exerciseCount = 0,
    this.durationMin = 0,
    this.onStart,
    this.footer,
  });

  static const double _pagePadding = 20;
  static const double _radius = 32;
  static const double _ctaHeight = 54;
  // Işığın üstten ne kadarlık kısmında (hero yüksekliğinin oranı) soluk başladığı.
  static const double _glowFadeStop = 0.4;
  static const Duration _switchDuration = Duration(milliseconds: 350);

  @override
  Widget build(BuildContext context) {
    final hasWorkout = workoutName != null;

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
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(_radius),
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
          // çekince (refresh/bounce) hero'nun üstündeki düz renkli bloğa
          // bıçak gibi bir kesik olmadan bağlanır.
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
          Padding(
            padding: EdgeInsets.fromLTRB(
              _pagePadding,
              MediaQuery.paddingOf(context).top + 12,
              _pagePadding,
              hasWorkout || isLoading ? 20 : 28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SeriesWordmark(
                  color: AppColors.onHeroDark.withValues(alpha: 0.9),
                ),
                const SizedBox(height: 22),
                Text(
                  'Hoş geldin',
                  style: AppTypography.body18Medium.copyWith(
                    color: AppColors.onHeroDark.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                  opacity: firstName.isEmpty ? 0 : 1,
                  child: Text(
                    // Boşken de bir satır yüksekliği korunsun diye ' ' kullanıyoruz
                    firstName.isEmpty ? ' ' : firstName,
                    style: AppTypography.heading1.copyWith(
                      color: AppColors.onHeroDark,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: _switchDuration,
                  child:
                      isLoading
                          ? const _WorkoutSkeleton()
                          : hasWorkout
                          ? _WorkoutBlock(
                            name: workoutName!,
                            exerciseCount: exerciseCount,
                            durationMin: durationMin,
                            onStart: onStart,
                            footer: footer,
                          )
                          : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Üst kenar boşluğa çekilince (bounce) hero'nun üstü açık kalmasın diye
    // aynı renkte uzun bir blok.
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

class _WorkoutBlock extends StatelessWidget {
  final String name;
  final int exerciseCount;
  final int durationMin;
  final VoidCallback? onStart;
  final Widget? footer;

  const _WorkoutBlock({
    required this.name,
    required this.exerciseCount,
    required this.durationMin,
    required this.onStart,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final metaStyle = AppTypography.body12Regular.copyWith(
      color: AppColors.onHeroDark.withValues(alpha: 0.7),
    );
    return Column(
      key: const ValueKey('workout_block'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 26),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.accentGold,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              'SIRADAKİ ANTRENMAN',
              style: AppTypography.body12Medium.copyWith(
                color: AppColors.onHeroDark.withValues(alpha: 0.65),
                fontSize: 10,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.heading1.copyWith(
            color: AppColors.onHeroDark,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (exerciseCount > 0) ...[
              Icon(
                Icons.fitness_center_rounded,
                size: 14,
                color: AppColors.onHeroDark.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 5),
              Text('$exerciseCount hareket', style: metaStyle),
            ],
            if (exerciseCount > 0 && durationMin > 0) const SizedBox(width: 14),
            if (durationMin > 0) ...[
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: AppColors.onHeroDark.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 5),
              Text('$durationMin dk', style: metaStyle),
            ],
          ],
        ),
        const SizedBox(height: 18),
        PressableScale(
          onTap: onStart,
          child: Container(
            height: HomeHero._ctaHeight,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentGold,
              borderRadius: BorderRadius.circular(HomeHero._ctaHeight / 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentGold.withValues(alpha: 0.38),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _PlayOutlineIcon(size: 22, color: AppColors.espresso),
                const SizedBox(width: 8),
                Text(
                  'Antrenmanı Başlat',
                  style: AppTypography.body16Medium.copyWith(
                    color: AppColors.espresso,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (footer != null) ...[const SizedBox(height: 20), footer!],
      ],
    );
  }
}

/// Antrenman bloğunun yaklaşık ölçülerinde iskelet; layout zıplamasın diye
/// satır yükseklikleri gerçek blokla aynı.
class _WorkoutSkeleton extends StatelessWidget {
  const _WorkoutSkeleton();

  Widget _bar(double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(height / 2 > 10 ? 10 : height / 2),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      key: const ValueKey('workout_skeleton'),
      baseColor: AppColors.onHeroDark.withValues(alpha: 0.1),
      highlightColor: AppColors.onHeroDark.withValues(alpha: 0.24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 26),
          SizedBox(
            height: 20,
            child: Align(alignment: Alignment.centerLeft, child: _bar(150, 10)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 30,
            child: Align(alignment: Alignment.centerLeft, child: _bar(230, 24)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 20,
            child: Align(alignment: Alignment.centerLeft, child: _bar(160, 12)),
          ),
          const SizedBox(height: 18),
          Container(
            height: HomeHero._ctaHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(HomeHero._ctaHeight / 2),
            ),
          ),
        ],
      ),
    );
  }
}

/// İnce çizgili, yuvarlak köşeli "oynat" ikonu (Tabler `player-play` ile aynı
/// çizim): 24'lük bir alanda `M7 4v16l13-8z`, 2 kalınlığında yuvarlak uçlu çizgi.
class _PlayOutlineIcon extends StatelessWidget {
  final double size;
  final Color color;

  const _PlayOutlineIcon({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _PlayOutlinePainter(color),
    );
  }
}

class _PlayOutlinePainter extends CustomPainter {
  final Color color;

  _PlayOutlinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final path =
        Path()
          ..moveTo(7 * scale, 4 * scale)
          ..lineTo(7 * scale, 20 * scale)
          ..lineTo(20 * scale, 12 * scale)
          ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_PlayOutlinePainter old) => old.color != color;
}
