import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// İlerleme çubuğu: kiremit gradyan dolgu, değer değişince 450ms yumuşakça uzar.
class GradientProgressBar extends StatelessWidget {
  final double value; // 0.0 - 1.0

  const GradientProgressBar({super.key, required this.value});

  static const double _height = 8;
  static const Duration _duration = Duration(milliseconds: 450);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container(
              height: _height,
              width: constraints.maxWidth,
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(_height),
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: value.clamp(0.0, 1.0)),
              duration: _duration,
              curve: Curves.easeOutCubic,
              builder:
                  (context, animated, _) => Container(
                    height: _height,
                    width: constraints.maxWidth * animated,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_height),
                      gradient: const LinearGradient(
                        colors: [AppColors.homeHeroGlow, AppColors.homeHero],
                      ),
                    ),
                  ),
            ),
          ],
        );
      },
    );
  }
}
