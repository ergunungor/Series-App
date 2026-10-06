import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';
import 'gradient_progress_bar.dart';
import 'pressable_scale.dart';
import 'reveal.dart';
import 'series_wordmark.dart';

/// Anket adımlarının ortak iskeleti: üstte wordmark ve kapat butonu, ilerleme
/// çubuğu ve "Adım n / m", büyük soru, kaydırılan içerik, altta Geri ve İleri.
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
    return SafeArea(
      child: Padding(
        // Üst boşluk diğer ekranlarla (Ana Sayfa) aynı 12.
        padding: const EdgeInsets.fromLTRB(_pagePadding, 12, _pagePadding, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: _topBarHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const SeriesWordmark(),
                  if (onExit != null)
                    Positioned(
                      right: 0,
                      child: PressableScale(
                        pressedScale: 0.92,
                        onTap: onExit,
                        child: Container(
                          width: _topBarHeight,
                          height: _topBarHeight,
                          decoration: const BoxDecoration(
                            color: AppColors.fillSubtle,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 22,
                            color: AppColors.homeHero,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GradientProgressBar(value: (currentStep + 1) / totalSteps),
            const SizedBox(height: 10),
            Text(
              'Adım ${currentStep + 1} / $totalSteps',
              style: AppTypography.body12Regular.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 22),
            Reveal(
              duration: _revealDuration,
              child: Text(
                question,
                style: AppTypography.heading1.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Reveal(
                  delay: const Duration(milliseconds: 100),
                  duration: _revealDuration,
                  child: content,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
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
          ],
        ),
      ),
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
