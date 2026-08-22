import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GradientProgressBar extends StatelessWidget {
  final double value; // 0.0 - 1.0

  const GradientProgressBar({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container(
              height: 8,
              width: constraints.maxWidth,
              decoration: BoxDecoration(
                color: AppColors.progressTrack,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            Container(
              height: 8,
              width: constraints.maxWidth * value.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.brandPrimary, Color(0xFF300000)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandPrimary.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
