import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class WorkoutCard extends StatelessWidget {
  final String date;
  final int streakCount;
  final String greeting;
  final String workoutSummary;
  final String nextWorkoutName;
  final VoidCallback? onPlayTap;

  const WorkoutCard({
    super.key,
    required this.date,
    required this.streakCount,
    required this.greeting,
    required this.workoutSummary,
    required this.nextWorkoutName,
    this.onPlayTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(45),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.brandPrimary, Color(0xFF300000)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 4,
            offset: const Offset(-3, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date,
                style: AppTypography.body12Regular.copyWith(
                  color: AppColors.brandSecondary,
                ),
              ),
              Row(
                children: [
                  Text(
                    'Haftalık Seri',
                    style: AppTypography.body12Regular.copyWith(
                      color: AppColors.streak,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.textSecondary),
                      borderRadius: BorderRadius.circular(45),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '$streakCount',
                          style: AppTypography.body12Regular.copyWith(
                            color: AppColors.streak,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.local_fire_department,
                          size: 16,
                          color: AppColors.streak,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            greeting,
            style: AppTypography.heading2.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            workoutSummary,
            style: AppTypography.body14Regular.copyWith(
              color: AppColors.brandSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sıradaki Antrenman:',
            style: AppTypography.body18Medium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.brandSecondary, width: 2),
              borderRadius: BorderRadius.circular(45),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  nextWorkoutName,
                  style: AppTypography.heading3.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: onPlayTap,
                  icon: Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.textPrimary,
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
