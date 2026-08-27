import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../models/workout_history.dart';

class WorkoutHistoryDetailScreen extends StatelessWidget {
  final WorkoutHistorySession session;

  const WorkoutHistoryDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final Map<String, List<LoggedSet>> byExercise = {};
    for (final set in session.sets) {
      byExercise.putIfAbsent(set.exerciseName, () => []).add(set);
    }
    for (final list in byExercise.values) {
      list.sort((a, b) => a.setNumber.compareTo(b.setNumber));
    }

    final dateLabel = DateFormat(
      'd MMMM yyyy, HH:mm',
      'tr_TR',
    ).format(session.completedAt);

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
                      session.workoutName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.heading2.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 4),
                child: Text(
                  dateLabel,
                  style: AppTypography.body14Regular.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children:
                      byExercise.entries.map((entry) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.brandSecondary),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.key,
                                style: AppTypography.body16Medium.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...entry.value.map(
                                (set) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Set ${set.setNumber}',
                                        style: AppTypography.body12Regular
                                            .copyWith(
                                              color: AppColors.textTertiary,
                                            ),
                                      ),
                                      Text(
                                        '${set.repsPerformed} tekrar · ${set.weightUsed.toStringAsFixed(set.weightUsed % 1 == 0 ? 0 : 1)} kg',
                                        style: AppTypography.body12Medium
                                            .copyWith(
                                              color: AppColors.brandPrimary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
