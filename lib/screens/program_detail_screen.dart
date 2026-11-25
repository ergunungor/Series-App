import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../models/program.dart';
import '../services/program_service.dart';
import '../services/program_repository.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import '../widgets/pressable_scale.dart';
import '../widgets/ai_revise_sheet.dart';
import '../widgets/detail_hero.dart';
import 'dart:async';

class ProgramDetailScreen extends StatefulWidget {
  final ActiveProgram program;

  const ProgramDetailScreen({super.key, required this.program});

  @override
  State<ProgramDetailScreen> createState() => _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends State<ProgramDetailScreen> {
  bool _isLoading = false;
  static const double _pagePadding = 16;

  // --- PROGRAM JSON ÇEVİRİCİ ---
  Map<String, dynamic> _programToJson(ActiveProgram p) {
    return {
      "program_name": p.name,
      "description": p.description,
      "workouts":
          p.workouts
              .map(
                (w) => {
                  "id": w.id,
                  "day_number": w.dayNumber,
                  "name": w.name,
                  "estimated_duration_min": w.estimatedDurationMin,
                  "exercises":
                      w.exercises
                          .map(
                            (e) => {
                              "id": e.id,
                              "name": e.name,
                              "sets": e.sets,
                              "reps": e.reps,
                              "duration_seconds": e.durationSeconds,
                              "rest_seconds": e.restSeconds,
                              "instructions": e.instructions,
                              "notes": e.notes,
                              if (e.supersetGroup != null)
                                "superset_group": e.supersetGroup,
                              if (e.dropSets > 0) "drop_sets": e.dropSets,
                              if (e.section != null) "section": e.section,
                            },
                          )
                          .toList(),
                },
              )
              .toList(),
    };
  }

  // --- YAPAY ZEKA TETİKLEYİCİSİ ---
  Future<void> _handleRevise(String prompt) async {
    if (prompt.trim().isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final hasCredit = await AiCredits.canUse(user.id);
      if (!hasCredit) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Bugünlük yapay zeka limitine (5/5) ulaştın. Lütfen yarın tekrar dene.',
              ),
            ),
          );
        }
        return;
      }

      // 1. AI'dan yeni programı iste
      final reviseResponse = await ProgramService.reviseProgram(
        user.id,
        _programToJson(widget.program),
        prompt,
      );
      final newData = Map<String, dynamic>.from(reviseResponse['data'] as Map);

      // 2. Programı yerinde güncelle: program ve gün kimlikleri (aktif
      // program, geçmiş kayıtları) korunur. Yapılamazsa eski yönteme dön.
      final updatedInPlace = await ProgramRepository.applyRevision(
        widget.program,
        newData,
      );
      if (!updatedInPlace) {
        final newProgramId = await ProgramService.saveProgram(user.id, newData);
        await ProgramRepository.deleteProgram(widget.program.id);
        await ProgramRepository.setActiveProgram(user.id, newProgramId);
      }

      // 4. Limiti düşür
      await AiCredits.consume(user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Programın başarıyla güncellendi!')),
        );

        // YENİ: Listeyi yenilemesi için geriye "true" göndererek çıkıyoruz
        if (context.canPop()) {
          context.pop(true);
        }
      }
    } catch (e) {
      debugPrint('Revize Hatası: $e');
      if (mounted) {
        // "Exception: " ön ekini temizleyerek sadece asıl mesajı alıyoruz
        final errorMessage = e.toString().replaceAll('Exception: ', '').trim();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: $errorMessage'),
            backgroundColor: AppColors.error, // hata rengi
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildHero(GlobalKey heroKey) {
    final program = widget.program;
    final exerciseCount = program.workouts.fold<int>(
      0,
      (sum, w) => sum + w.exercises.length,
    );
    final totalMinutes = program.workouts.fold<int>(
      0,
      (sum, w) => sum + w.estimatedDurationMin,
    );

    return DetailHero(
      heroKey: heroKey,
      gradientColors: const [AppColors.heroDarkStart, AppColors.heroDarkEnd],
      onBack: () => context.pop(),
      trailing: PressableScale(
        onTap: () async {
          final prompt = await showAiReviseSheet(
            context,
            suggestions: const [
              'Süreyi kısalt',
              'Bacak hareketlerini çıkar',
              'Daha yoğun yap',
              'Ekipmansız olsun',
            ],
          );
          if (prompt != null) _handleRevise(prompt);
        },
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.accentGold.withValues(alpha: 0.16),
            border: Border.all(
              color: AppColors.accentGold.withValues(alpha: 0.45),
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 16,
                color: AppColors.accentGold,
              ),
              const SizedBox(width: 6),
              Text(
                'Düzenle',
                style: AppTypography.body14Medium.copyWith(
                  color: AppColors.accentGold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      title: program.name,
      stats: [
        DetailHeroStat('${program.workouts.length}', 'gün'),
        DetailHeroStat('$exerciseCount', 'hareket'),
        DetailHeroStat('$totalMinutes', 'dk toplam'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          body: HeroStatusBarScope(
            builder:
                (context, heroKey) => ListView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.paddingOf(context).bottom + 24,
                  ),
                  children: [
                    _buildHero(heroKey),
                    if (widget.program.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          _pagePadding,
                          20,
                          _pagePadding,
                          0,
                        ),
                        child: Text(
                          widget.program.description,
                          style: AppTypography.body14Regular.copyWith(
                            color: AppColors.textTertiary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        _pagePadding,
                        24,
                        _pagePadding,
                        8,
                      ),
                      child: Text(
                        'Antrenman günleri',
                        style: AppTypography.body18Medium.copyWith(
                          color: AppColors.espresso,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    for (var i = 0; i < widget.program.workouts.length; i++)
                      _DayTimelineItem(
                        workout: widget.program.workouts[i],
                        isFirst: i == 0,
                        isLast: i == widget.program.workouts.length - 1,
                        onTap:
                            () => context.push(
                              '/workout-day-detail',
                              extra: widget.program.workouts[i],
                            ),
                      ),
                  ],
                ),
          ),
        ),
        if (_isLoading) const Positioned.fill(child: AiLoadingOverlay()),
      ],
    );
  }
}

class _DayTimelineItem extends StatelessWidget {
  final WorkoutDay workout;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _DayTimelineItem({
    required this.workout,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  static const double _nodeSize = 34;
  static const double _lineWidth = 2;
  static const double _gap = 12;

  Widget _railLine({required bool visible}) {
    return Center(
      child: Container(
        width: _lineWidth,
        decoration: BoxDecoration(
          color:
              visible
                  ? AppColors.goldDeep.withValues(alpha: 0.3)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(_lineWidth),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTypography.body12Regular.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _nodeSize,
              child: Column(
                children: [
                  Expanded(child: _railLine(visible: !isFirst)),
                  Container(
                    width: _nodeSize,
                    height: _nodeSize,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.espresso,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${workout.dayNumber}',
                      style: AppTypography.body14Medium.copyWith(
                        color: AppColors.onHeroDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(child: _railLine(visible: !isLast)),
                ],
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(
              child: Padding(
                // Boşluk satırın içinde simetrik: daire kartın tam ortasında kalır
                // ve çizgi satırlar arasında kopmaz.
                padding: const EdgeInsets.symmetric(vertical: _gap / 2),
                child: PressableScale(
                  pressedScale: 0.98,
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                workout.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body16Medium.copyWith(
                                  color: AppColors.espresso,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 14,
                                runSpacing: 4,
                                children: [
                                  _meta(
                                    Icons.fitness_center_rounded,
                                    '${workout.exercises.length} hareket',
                                  ),
                                  _meta(
                                    Icons.schedule_rounded,
                                    '~${workout.estimatedDurationMin} dk',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          CupertinoIcons.chevron_right,
                          size: 18,
                          color: AppColors.goldDeep,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
