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
  static const double _groupGap = 20;
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
      // 8.0 → "8", 4.25 → "4,3"; 10 ton ve üstü tam sayı.
      final tonsLabel = (tons < 10
              ? tons.toStringAsFixed(1)
              : '${tons.round()}')
          .replaceAll(RegExp(r'\.0$'), '')
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
      padding: const EdgeInsets.only(bottom: _groupGap),
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
      children.add(
        _reveal(
          step++,
          _Group(title: 'Güç gelişimi', child: _buildStrengthCard(_selected!)),
        ),
      );
    }
    if (_funFact != null) {
      children.add(_reveal(step++, _FunFactCard(text: _funFact!)));
    }
    if (_weekly.any((c) => c > 0)) {
      children.add(
        _reveal(
          step++,
          _Group(
            title: 'Haftalık antrenman',
            trailing: 'Son ${_weekly.length} hafta',
            child: _buildWeeklyCard(),
          ),
        ),
      );
    }
    return Column(children: children);
  }

  Widget _buildStrengthCard(String exercise) {
    final series = WorkoutStats.strengthSeries(widget.sessions, exercise);
    final record = WorkoutStats.personalRecord(widget.sessions, exercise);
    final latest = series.last;
    final delta = series.length >= 2 ? latest.score - series.first.score : 0.0;

    return _InsightCard(
      dark: true,
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
                      dark: true,
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
                        color: AppColors.onHeroDark.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      '${formatKg(latest.score)} kg',
                      style: AppTypography.heading1.copyWith(
                        color: AppColors.onHeroDark,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (delta.abs() >= 0.05) _DeltaPill(delta: delta, dark: true),
            ],
          ),
          const SizedBox(height: 8),
          if (series.length >= 2)
            StrengthLineChart(
              points: series,
              record: record,
              style: StrengthChartStyle.dark,
            )
          else
            const _FirstRecordNote(dark: true),
        ],
      ),
    );
  }

  Widget _buildWeeklyCard() {
    return _InsightCard(child: WeeklyBarsChart(counts: _weekly));
  }
}

class _InsightCard extends StatelessWidget {
  final Widget child;

  /// Koyu ardıç yeşili gradyan zemin (hero ile aynı dil); false ise beyaz kart.
  final bool dark;

  const _InsightCard({required this.child, this.dark = false});

  static const double radius = 20;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? null : Colors.white,
        gradient:
            dark
                ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.workoutsHero, AppColors.workoutsHeroDeep],
                )
                : null,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color:
                dark
                    ? AppColors.workoutsHero.withValues(alpha: 0.28)
                    : Colors.black.withValues(alpha: 0.04),
            blurRadius: dark ? 24 : 16,
            offset: Offset(0, dark ? 12 : 4),
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
  final bool dark;

  const _ExerciseChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dark = false,
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
          color:
              dark
                  ? (selected
                      ? AppColors.accentGold
                      : AppColors.onHeroDark.withValues(alpha: 0.1))
                  : (selected ? AppColors.workoutsHero : AppColors.fillSubtle),
          borderRadius: BorderRadius.circular(_height / 2),
        ),
        child: Text(
          label,
          style: AppTypography.body12Medium.copyWith(
            color:
                dark
                    ? (selected ? AppColors.espresso : AppColors.onHeroDark)
                    : (selected ? AppColors.onHeroDark : AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  final double delta;
  final bool dark;

  const _DeltaPill({required this.delta, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final positive = delta > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:
            dark
                ? (positive
                    ? AppColors.accentGold.withValues(alpha: 0.18)
                    : AppColors.onHeroDark.withValues(alpha: 0.1))
                : (positive ? AppColors.workoutsTint : AppColors.fillSubtle),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${positive ? '+' : '−'}${formatKg(delta.abs())} kg',
        style: AppTypography.body12Medium.copyWith(
          color:
              dark
                  ? (positive
                      ? AppColors.accentGold
                      : AppColors.onHeroDark.withValues(alpha: 0.7))
                  : (positive
                      ? AppColors.workoutsAccent
                      : AppColors.textTertiary),
        ),
      ),
    );
  }
}

class _FirstRecordNote extends StatelessWidget {
  final bool dark;

  const _FirstRecordNote({this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: math.min(StrengthLineChart.height, 96),
      padding: const EdgeInsets.all(16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color:
            dark
                ? AppColors.onHeroDark.withValues(alpha: 0.08)
                : AppColors.fillSubtle,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'İlk kaydın alındı. Bir sonraki antrenmanda kıyaslayacağız.',
        style: AppTypography.body14Regular.copyWith(
          color: dark ? AppColors.onHeroDark : AppColors.textPrimary,
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

/// Kartın üstünde duran küçük, silik bölüm başlığı. Ekrandaki diğer bölümlerde
/// (ör. kayıt listesi) de kullanılır.
class InsightSectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;

  const InsightSectionTitle({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.body12Medium.copyWith(
      color: AppColors.textTertiary,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (trailing != null) Text(trailing!, style: style),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final String? trailing;
  final Widget child;

  const _Group({required this.title, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [InsightSectionTitle(title: title, trailing: trailing), child],
    );
  }
}
