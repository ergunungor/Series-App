import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class WorkoutCard extends StatelessWidget {
  final String date;
  final int streakCount;
  final String greeting;
  final String workoutSummary;
  final String nextWorkoutName;
  final int? nextWorkoutDurationMin;
  final VoidCallback? onPlayTap;

  const WorkoutCard({
    super.key,
    required this.date,
    required this.streakCount,
    required this.greeting,
    required this.workoutSummary,
    required this.nextWorkoutName,
    this.nextWorkoutDurationMin,
    this.onPlayTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.brandPrimary, Color(0xFF300000)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                date,
                style: AppTypography.body12Regular.copyWith(
                  color: AppColors.brandSecondary.withOpacity(0.65),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(45),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      size: 16,
                      color: AppColors.streak,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$streakCount Günlük Seri',
                      style: AppTypography.body12Medium.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            greeting,
            style: AppTypography.heading2.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            workoutSummary,
            style: AppTypography.body14Regular.copyWith(
              color: AppColors.brandSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Sıradaki Antrenman',
            style: AppTypography.body18Medium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.brandSecondary, width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nextWorkoutName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.heading3.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (nextWorkoutDurationMin != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '~$nextWorkoutDurationMin dk',
                          style: AppTypography.body12Regular.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brandTertiary,
                  ),
                  child: IconButton(
                    onPressed: onPlayTap,
                    icon: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
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
