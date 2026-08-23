import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../models/program.dart';
import 'package:go_router/go_router.dart';

class ProgramDetailScreen extends StatelessWidget {
  final ActiveProgram program;

  const ProgramDetailScreen({super.key, required this.program});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.arrow_back,
                      color: AppColors.brandTertiary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      program.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.heading2.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              if (program.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    program.description,
                    style: AppTypography.body14Regular.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: program.workouts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final workout = program.workouts[index];
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        // yeni:
                        onTap:
                            () => context.push(
                              '/workout-day-detail',
                              extra: workout,
                            ),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.brandSecondary),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${workout.dayNumber}',
                                  style: AppTypography.body16Medium.copyWith(
                                    color: AppColors.brandPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      workout.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.body16Medium
                                          .copyWith(
                                            color: AppColors.textPrimary,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${workout.exercises.length} hareket · ~${workout.estimatedDurationMin} dk',
                                      style: AppTypography.body12Regular
                                          .copyWith(
                                            color: AppColors.textTertiary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: AppColors.textTertiary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
