import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_button.dart';

class WorkoutBreakScreen extends StatelessWidget {
  final int remainingSeconds;
  final int totalSeconds;
  final String nextExercise;

  const WorkoutBreakScreen({
    super.key,
    this.remainingSeconds = 10,
    this.totalSeconds = 40,
    this.nextExercise = 'Cable Crunch - 3x10',
  });

  @override
  Widget build(BuildContext context) {
    final double progress = remainingSeconds / totalSeconds;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 27),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandPrimary.withOpacity(0.15),
                      blurRadius: 14.667,
                      spreadRadius: 3.667,
                      offset: const Offset(2.2, 2.2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(26),
                child: const AppLogo(
                  size: AppLogoSize.medium,
                  type: AppLogoType.dark,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'MOLA',
                style: AppTypography.heading1.copyWith(
                  color: AppColors.brandPrimary,
                  fontSize: 36,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 230,
                height: 230,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 230,
                      height: 230,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 18,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.brandPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '$remainingSeconds',
                      style: AppTypography.heading1.copyWith(
                        color: AppColors.brandPrimary,
                        fontSize: 60,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Kalan Süre',
                style: AppTypography.heading2.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              const Spacer(),

              AppButton(
                text: 'Molayı Atla',
                variant: AppButtonVariant.outlined,
                icon: Icons.chevron_right,
                onPressed: () {},
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: Icon(
                      Icons.chevron_left,
                      color: AppColors.brandSecondary,
                      size: 48,
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(
                      Icons.chevron_right,
                      color: AppColors.brandSecondary,
                      size: 48,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
