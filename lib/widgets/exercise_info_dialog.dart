import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../services/exercise_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/exercise_name.dart';
import 'pressable_scale.dart';

/// Hareketin GIF'ini ve tarifini, açık ekranın üstünde ortada beliren bir
/// kart olarak gösterir; arka plan kararır. Boşluğa ya da sağ üstteki çarpıya
/// basınca kapanır.
Future<void> showExerciseInfoDialog(
  BuildContext context, {
  required String exerciseId,
  required String name,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Kapat',
    barrierColor: Colors.black.withValues(alpha: 0.62),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder:
        (ctx, _, _) => _ExerciseInfoCard(exerciseId: exerciseId, name: name),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _ExerciseInfoCard extends StatelessWidget {
  final String exerciseId;
  final String name;

  const _ExerciseInfoCard({required this.exerciseId, required this.name});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 440,
                maxHeight: size.height * 0.82,
              ),
              child: Stack(
                children: [
                  FutureBuilder<Exercise?>(
                    future: ExerciseService().fetchExerciseById(exerciseId),
                    builder: (context, snap) {
                      final info = snap.data;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 44),
                              child: Text(
                                formatExerciseName(name),
                                style: AppTypography.heading3.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.fillSubtle,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child:
                                    snap.connectionState != ConnectionState.done
                                        ? const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            color: AppColors.homeHero,
                                          ),
                                        )
                                        : (info == null || info.gifUrl.isEmpty)
                                        ? const Center(
                                          child: Icon(
                                            Icons.fitness_center_rounded,
                                            size: 40,
                                            color: AppColors.textTertiary,
                                          ),
                                        )
                                        : Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Image.network(
                                            info.gifUrl,
                                            fit: BoxFit.contain,
                                            gaplessPlayback: true,
                                            errorBuilder:
                                                (_, _, _) => const Icon(
                                                  Icons.broken_image_outlined,
                                                  color: AppColors.textTertiary,
                                                ),
                                          ),
                                        ),
                              ),
                            ),
                            if (info != null &&
                                info.instructions.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Text(
                                'NASIL YAPILIR',
                                style: AppTypography.body12Medium.copyWith(
                                  color: AppColors.textTertiary,
                                  letterSpacing: 1.4,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              for (var i = 0; i < info.instructions.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        alignment: Alignment.center,
                                        decoration: const BoxDecoration(
                                          color: AppColors.goldTint,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '${i + 1}',
                                          style: AppTypography.body12Medium
                                              .copyWith(
                                                color: AppColors.goldDeep,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 11,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          info.instructions[i],
                                          style: AppTypography.body14Regular
                                              .copyWith(
                                                color: AppColors.textPrimary,
                                                height: 1.45,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: PressableScale(
                      pressedScale: 0.9,
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppColors.fillSubtle,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
