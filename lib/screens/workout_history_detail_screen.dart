import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../models/workout_history.dart';
import '../utils/exercise_name.dart';
import '../utils/workout_stats.dart';
import '../widgets/app_logo.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/reveal.dart';

class WorkoutHistoryDetailScreen extends StatefulWidget {
  final WorkoutHistorySession session;

  const WorkoutHistoryDetailScreen({super.key, required this.session});

  @override
  State<WorkoutHistoryDetailScreen> createState() =>
      _WorkoutHistoryDetailScreenState();
}

class _WorkoutHistoryDetailScreenState
    extends State<WorkoutHistoryDetailScreen> {
  static const double _pagePadding = 16;
  static const double _heroRadius = 32;
  static const double _cardRadius = 22;
  static const double _cardGap = 12;
  static const Duration _revealDuration = Duration(milliseconds: 500);
  static const Duration _revealStagger = Duration(milliseconds: 100);
  static const int _revealedCards = 4;

  final GlobalKey _heroKey = GlobalKey();
  bool _isStatusBarLight = true;

  late final Map<String, List<LoggedSet>> _byExercise = _groupByExercise();

  Map<String, List<LoggedSet>> _groupByExercise() {
    final Map<String, List<LoggedSet>> byExercise = {};
    for (final set in widget.session.sets) {
      byExercise.putIfAbsent(set.exerciseName, () => []).add(set);
    }
    for (final list in byExercise.values) {
      list.sort((a, b) => a.setNumber.compareTo(b.setNumber));
    }
    return byExercise;
  }

  // Hero ekranın üstünden çıkınca saat/pil rengini koyuya çevirir.
  bool _handleScroll(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification || notification.depth != 0) {
      return false;
    }
    final heroHeight = _heroKey.currentContext?.size?.height;
    if (heroHeight == null) return false;

    final isLight =
        notification.metrics.pixels <
        heroHeight - MediaQuery.paddingOf(context).top;
    if (isLight != _isStatusBarLight) {
      setState(() => _isStatusBarLight = isLight);
    }
    return false;
  }

  Widget _heroStat(String value, String label, {bool isFirst = false}) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(left: isFirst ? 0 : 14, right: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTypography.heading2.copyWith(
                color: AppColors.onHeroDark,
                fontWeight: FontWeight.w700,
                height: 1,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.body12Regular.copyWith(
                color: AppColors.onHeroDark.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroDivider() {
    return Container(
      width: 0.5,
      color: AppColors.onHeroDark.withValues(alpha: 0.18),
    );
  }

  Widget _buildHero() {
    final session = widget.session;
    final dateLabel = DateFormat(
      'd MMMM yyyy, HH:mm',
      'tr_TR',
    ).format(session.completedAt);
    final volume = WorkoutStats.totalVolumeKg([session]).round();
    final durationSeconds = session.durationSeconds;

    final hero = Container(
      key: _heroKey,
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.fromLTRB(
        _pagePadding,
        MediaQuery.paddingOf(context).top + 12,
        _pagePadding,
        28,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.workoutsHero, AppColors.workoutsHeroDeep],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(_heroRadius),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -32,
            bottom: -44,
            child: Opacity(
              opacity: 0.06,
              child: const AppLogo(explicitSize: 190, type: AppLogoType.light),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PressableScale(
                pressedScale: 0.92,
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.onHeroDark.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.back,
                    size: 20,
                    color: AppColors.onHeroDark,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                session.workoutName,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.heading1.copyWith(
                  color: AppColors.onHeroDark,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                dateLabel,
                style: AppTypography.body14Regular.copyWith(
                  color: AppColors.onHeroDark.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              IntrinsicHeight(
                child: Row(
                  children: [
                    _heroStat(
                      '${session.exerciseCount}',
                      'hareket',
                      isFirst: true,
                    ),
                    _heroDivider(),
                    _heroStat('${session.setCount}', 'set'),
                    _heroDivider(),
                    _heroStat('$volume', 'kg'),
                    if (durationSeconds != null) ...[
                      _heroDivider(),
                      _heroStat(
                        '${math.max(1, (durationSeconds / 60).round())}',
                        'dk',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // Aşağı çekildiğinde (bounce) hero'nun üstü açık kalmasın diye aynı
    // renkte, ekran yüksekliğinde bir blok ekliyoruz.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -MediaQuery.sizeOf(context).height,
          left: 0,
          right: 0,
          height: MediaQuery.sizeOf(context).height,
          child: const ColoredBox(color: AppColors.workoutsHero),
        ),
        hero,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _byExercise.entries.toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        // Hero durum çubuğunun arkasındayken açık, liste altına geçince koyu
        value:
            _isStatusBarLight
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
        child: NotificationListener<ScrollNotification>(
          onNotification: _handleScroll,
          child: ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 24,
            ),
            children: [
              _buildHero(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  _pagePadding,
                  24,
                  _pagePadding,
                  12,
                ),
                child: Text(
                  'Hareketler',
                  style: AppTypography.body18Medium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (var i = 0; i < entries.length; i++)
                _revealed(
                  i,
                  _ExerciseCard(
                    name: entries[i].key,
                    sets: entries[i].value,
                    radius: _cardRadius,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _revealed(int index, Widget card) {
    final padded = Padding(
      padding: const EdgeInsets.fromLTRB(
        _pagePadding,
        0,
        _pagePadding,
        _cardGap,
      ),
      child: card,
    );
    if (index >= _revealedCards) return padded;
    return Reveal(
      delay: _revealStagger * (1 + index),
      duration: _revealDuration,
      child: padded,
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final String name;
  final List<LoggedSet> sets;
  final double radius;

  const _ExerciseCard({
    required this.name,
    required this.sets,
    required this.radius,
  });

  /// Egzersizin bu seanstaki en yüksek tahmini 1TM puanı; puanlanamıyorsa null.
  double? get _bestScore {
    double? best;
    for (final set in sets) {
      final score = WorkoutStats.estimated1RM(
        set.weightUsed,
        set.repsPerformed,
      );
      if (score != null) best = best == null ? score : math.max(best, score);
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final score = _bestScore;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatExerciseName(name),
                  style: AppTypography.body16Medium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (score != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.workoutsTint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Puan ${formatKg(score)}',
                    style: AppTypography.body12Medium.copyWith(
                      color: AppColors.workoutsAccent,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < sets.length; i++) ...[
            if (i > 0) Container(height: 0.5, color: AppColors.borderSubtle),
            _SetRow(set: sets[i]),
          ],
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  final LoggedSet set;

  const _SetRow({required this.set});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Set ${set.setNumber}',
              style: AppTypography.body14Regular.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Text(
            '${set.repsPerformed} tekrar · ${formatKg(set.weightUsed)} kg',
            style: AppTypography.body14Medium.copyWith(
              color: AppColors.workoutsAccent,
            ),
          ),
        ],
      ),
    );
  }
}
