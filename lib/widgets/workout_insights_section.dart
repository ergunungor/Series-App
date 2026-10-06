import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../models/workout_history.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/exercise_name.dart';
import '../utils/workout_stats.dart';
import 'pressable_scale.dart';
import 'reveal.dart';
import 'strength_line_chart.dart';
import 'weekly_bars_chart.dart';

/// Antrenmanlar ekranının hero'su ile geçmiş listesi arasındaki bölüm: güç
/// puanı grafiği, fun fact ve haftalık antrenman çubukları. Hesap
/// `WorkoutStats` üzerinden yalnızca verilen listede yapılır.
class WorkoutInsightsSection extends StatefulWidget {
  final List<WorkoutHistorySession> sessions;

  /// İlk açılışta kartlar sırayla belirsin mi. Yalnızca ilk build'de okunur,
  /// sonradan değişirse ağaç yapısı değişip grafik state'i sıfırlanmasın.
  final bool animateIntro;
  final Duration revealStagger;
  final Duration revealDuration;

  const WorkoutInsightsSection({
    super.key,
    required this.sessions,
    required this.animateIntro,
    required this.revealStagger,
    required this.revealDuration,
  });

  /// Bölümdeki kart sayısı; ekran, altındaki liste animasyonunu bu kadar
  /// geciktirir.
  static const int cardCount = 3;

  @override
  State<WorkoutInsightsSection> createState() => _WorkoutInsightsSectionState();
}

class _WorkoutInsightsSectionState extends State<WorkoutInsightsSection> {
  static const double _cardGap = 12;
  static const int _maxChips = 6;
  static const double _carWeightKg = 1500;
  static const int _growthWindowDays = 28;

  late final bool _animate = widget.animateIntro;

  List<ExerciseOption> _options = const [];
  String? _selected;
  List<int> _weekly = const [];
  late String? _funFact;
  // Liste yerinde değiştiği için (silme/geri alma) kimlik yerine uzunluğa bakıyoruz.
  int _computedLength = -1;

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  @override
  void didUpdateWidget(WorkoutInsightsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sessions.length != _computedLength ||
        !identical(oldWidget.sessions, widget.sessions)) {
      _recompute();
    }
  }

  void _recompute() {
    final sessions = widget.sessions;
    _computedLength = sessions.length;
    _options = WorkoutStats.exerciseOptions(sessions);
    if (_selected == null || !_options.any((o) => o.name == _selected)) {
      _selected = _options.isEmpty ? null : _options.first.name;
    }
    _weekly = WorkoutStats.weeklyCounts(sessions, DateTime.now());
    _funFact = _pickFunFact();
  }

  String? _pickFunFact() {
    final sessions = widget.sessions;
    final facts = <String>[];

    final volume = WorkoutStats.totalVolumeKg(sessions);
    final cars = (volume / _carWeightKg).round();
    if (cars >= 1) {
      final tons = volume / 1000;
      final tonsLabel = (tons < 10
              ? tons.toStringAsFixed(1)
              : '${tons.round()}')
          .replaceAll('.', ',');
      facts.add(
        'Toplam $tonsLabel ton kaldırdın. Bu yaklaşık $cars arabaya denk.',
      );
    }

    if (_options.isNotEmpty) {
      final top = _options.first.name;
      final record = WorkoutStats.personalRecord(sessions, top);
      if (record != null) {
        final day = DateFormat('d MMMM', 'tr_TR').format(record.date);
        facts.add(
          'Rekorun: ${formatExerciseName(top)}, ${formatKg(record.score)} kg puan ($day).',
        );
      }

      final all = WorkoutStats.strengthSeries(sessions, top, limit: 1 << 20);
      final cutoff = DateTime.now().subtract(
        const Duration(days: _growthWindowDays),
      );
      final recent = all.where((p) => p.date.isAfter(cutoff)).toList();
      if (recent.length >= 2 && recent.first.score > 0) {
        final change = (recent.last.score / recent.first.score - 1) * 100;
        if (change >= 1) {
          facts.add(
            'Son 4 haftada ${formatExerciseName(top)} puanın %${change.round()} arttı.',
          );
        }
      }
    }

    if (facts.isEmpty) return null;
    // Gün bazlı seçim: her yeniden çizimde değişip kart zıplamasın.
    final dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    return facts[dayOfYear % facts.length];
  }

  Widget _reveal(int step, Widget child) {
    final padded = Padding(
      padding: const EdgeInsets.only(bottom: _cardGap),
      child: child,
    );
    if (!_animate) return padded;
    return Reveal(
      delay: widget.revealStagger * (1 + step),
      duration: widget.revealDuration,
      child: padded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    var step = 0;
    if (_selected != null) {
      children.add(_reveal(step++, _buildStrengthCard(_selected!)));
    }
    if (_funFact != null) {
      children.add(_reveal(step++, _FunFactCard(text: _funFact!)));
    }
    if (_weekly.any((c) => c > 0)) {
      children.add(_reveal(step++, _buildWeeklyCard()));
    }
    return Column(children: children);
  }

  Widget _buildStrengthCard(String exercise) {
    final series = WorkoutStats.strengthSeries(widget.sessions, exercise);
    final record = WorkoutStats.personalRecord(widget.sessions, exercise);
    final latest = series.last;
    final delta = series.length >= 2 ? latest.score - series.first.score : 0.0;

    return _InsightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final option in _options.take(_maxChips))
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _ExerciseChip(
                      label: formatExerciseName(option.name),
                      selected: option.name == exercise,
                      onTap: () => setState(() => _selected = option.name),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Güç puanı (tahmini 1TM)',
                      style: AppTypography.body12Regular.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    Text(
                      '${formatKg(latest.score)} kg',
                      style: AppTypography.heading1.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (delta.abs() >= 0.05) _DeltaPill(delta: delta),
            ],
          ),
          const SizedBox(height: 8),
          if (series.length >= 2)
            StrengthLineChart(points: series, record: record)
          else
            const _FirstRecordNote(),
        ],
      ),
    );
  }

  Widget _buildWeeklyCard() {
    return _InsightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Haftalık antrenman',
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body12Regular.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              Text(
                'Son ${_weekly.length} hafta',
                style: AppTypography.body12Regular.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          WeeklyBarsChart(counts: _weekly),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final Widget child;

  const _InsightCard({required this.child});

  static const double radius = 20;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ExerciseChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ExerciseChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const double _height = 34;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: _height,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.workoutsHero : AppColors.fillSubtle,
          borderRadius: BorderRadius.circular(_height / 2),
        ),
        child: Text(
          label,
          style: AppTypography.body12Medium.copyWith(
            color: selected ? AppColors.onHeroDark : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  final double delta;

  const _DeltaPill({required this.delta});

  @override
  Widget build(BuildContext context) {
    final positive = delta > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: positive ? AppColors.workoutsTint : AppColors.fillSubtle,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${positive ? '+' : '−'}${formatKg(delta.abs())} kg',
        style: AppTypography.body12Medium.copyWith(
          color: positive ? AppColors.workoutsAccent : AppColors.textTertiary,
        ),
      ),
    );
  }
}

class _FirstRecordNote extends StatelessWidget {
  const _FirstRecordNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: math.min(StrengthLineChart.height, 96),
      padding: const EdgeInsets.all(16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppColors.fillSubtle,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'İlk kaydın alındı. Bir sonraki antrenmanda kıyaslayacağız.',
        style: AppTypography.body14Regular.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _FunFactCard extends StatelessWidget {
  final String text;

  const _FunFactCard({required this.text});

  static const double _iconSize = 36;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.goldTint,
        borderRadius: BorderRadius.circular(_InsightCard.radius),
      ),
      child: Row(
        children: [
          Container(
            width: _iconSize,
            height: _iconSize,
            decoration: const BoxDecoration(
              color: AppColors.accentGold,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bolt_rounded,
              size: 20,
              color: AppColors.espresso,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Fun fact: ',
                    style: AppTypography.body14Medium.copyWith(
                      color: AppColors.espresso,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: text,
                    style: AppTypography.body14Regular.copyWith(
                      color: AppColors.espresso,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
