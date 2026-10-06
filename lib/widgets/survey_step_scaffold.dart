import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';
import 'kiremit_hero_surface.dart';
import 'pressable_scale.dart';
import 'reveal.dart';
import 'series_wordmark.dart';

/// Anket adımlarının ortak iskeleti: üstte ışıklı kiremit hero (wordmark, kapat
/// butonu, segmentli ilerleme, adım etiketi ve beyaz büyük soru), altında krem
/// zeminde kaydırılan içerik ve en altta Geri / İleri.
class SurveyStepScaffold extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final String question;
  final Widget content;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final VoidCallback? onExit; // Çarpı butonu için yeni callback
  final String nextLabel;

  const SurveyStepScaffold({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.question,
    required this.content,
    required this.onNext,
    this.onBack,
    this.onExit,
    this.nextLabel = 'İleri',
  });

  static const double _pagePadding = 20;
  static const double _topBarHeight = 44;
  static const Duration _revealDuration = Duration(milliseconds: 500);

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Hero koyu: durum çubuğu simgeleri açık.
      value: SystemUiOverlayStyle.light,
      child: Column(
        children: [
          KiremitHeroSurface(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                _pagePadding,
                MediaQuery.paddingOf(context).top + 8,
                _pagePadding,
                26,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: _topBarHeight,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SeriesWordmark(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        if (onExit != null)
                          Positioned(
                            right: 0,
                            child: PressableScale(
                              pressedScale: 0.92,
                              onTap: onExit,
                              child: Container(
                                width: _topBarHeight,
                                height: _topBarHeight,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 22,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SegmentedProgress(current: currentStep, total: totalSteps),
                  const SizedBox(height: 20),
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
                        'ADIM ${currentStep + 1} / $totalSteps',
                        style: AppTypography.body12Medium.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 10,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Reveal(
                    duration: _revealDuration,
                    child: Text(
                      question,
                      style: AppTypography.heading1.copyWith(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                _pagePadding,
                24,
                _pagePadding,
                16,
              ),
              child: Reveal(
                delay: const Duration(milliseconds: 100),
                duration: _revealDuration,
                child: content,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              _pagePadding,
              4,
              _pagePadding,
              bottomSafe > 0 ? bottomSafe : 20,
            ),
            child: Row(
              children: [
                if (onBack != null) ...[
                  _BackButton(onTap: onBack!),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: AppButton(
                    text: nextLabel,
                    onPressed: onNext,
                    showIcon: nextLabel == 'İleri',
                    icon: Icons.chevron_right_rounded,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Adım başına bir segment: tamamlanan ve mevcut adım altın dolu (akıcı uzar).
class _SegmentedProgress extends StatelessWidget {
  final int current;
  final int total;

  const _SegmentedProgress({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: i <= current ? 1 : 0),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder:
                    (context, value, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Container(
                        height: 4,
                        color: Colors.white.withValues(alpha: 0.2),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: value,
                          heightFactor: 1,
                          child: const ColoredBox(color: AppColors.accentGold),
                        ),
                      ),
                    ),
              ),
            ),
          ),
      ],
    );
  }
}

/// "Geri" butonu: beyaz pill, ince çerçeve, kiremit yazı.
class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.96,
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderSubtle, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.chevron_left_rounded,
              color: AppColors.homeHero,
              size: 22,
            ),
            const SizedBox(width: 2),
            Text(
              'Geri',
              style: AppTypography.body16Medium.copyWith(
                color: AppColors.homeHero,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
