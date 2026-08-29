import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_logo.dart';

class WorkoutCard extends StatelessWidget {
  final String nextWorkoutName;
  final VoidCallback? onStartTap;

  const WorkoutCard({
    super.key,
    required this.nextWorkoutName,
    this.onStartTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.brandPrimary),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const AppLogo(explicitSize: 64, type: AppLogoType.dark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nextWorkoutName,
                  textAlign: TextAlign.center,
                  style: AppTypography.body18Medium.copyWith(
                    color: AppColors.brandTertiary,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onStartTap,
                  icon: Icon(
                    Icons.play_arrow_rounded,
                    size: 18,
                    color: AppColors.brandTertiary,
                  ),
                  label: Text(
                    'Antrenmanı Başlat',
                    style: AppTypography.body12Medium.copyWith(
                      color: AppColors.brandTertiary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.brandTertiary),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
