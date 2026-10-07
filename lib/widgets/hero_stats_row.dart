import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Hero içindeki tek bir rakam ve etiketi.
class HeroStat {
  final int value;
  final String label;

  /// Vurgulu rakam için (ör. altın); varsayılan krem.
  final Color valueColor;

  const HeroStat(
    this.value,
    this.label, {
    this.valueColor = AppColors.onHeroDark,
  });
}

/// Koyu hero içinde yan yana, aralarında ince çizgi olan ortalı rakamlar.
class HeroStatsRow extends StatelessWidget {
  final List<HeroStat> stats;

  const HeroStatsRow({super.key, required this.stats});

  static const double height = 72;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('hero_stats'),
      height: height,
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) const _Divider(),
            Expanded(child: _Stat(stat: stats[i])),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final HeroStat stat;

  const _Stat({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${stat.value}',
          style: AppTypography.heading1.copyWith(
            color: stat.valueColor,
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          stat.label,
          style: AppTypography.body12Medium.copyWith(
            color: AppColors.onHeroDark.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: AppColors.onHeroDark.withValues(alpha: 0.14),
    );
  }
}

/// Rakamlar yüklenirken: koyu zeminde silik shimmer çubukları.
class HeroStatsSkeleton extends StatelessWidget {
  final int count;

  const HeroStatsSkeleton({super.key, this.count = 3});

  Widget _column() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 44,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      const SizedBox(height: 8),
      Container(
        width: 62,
        height: 10,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      key: const ValueKey('hero_stats_skeleton'),
      baseColor: Colors.white.withValues(alpha: 0.1),
      highlightColor: Colors.white.withValues(alpha: 0.24),
      child: SizedBox(
        height: HeroStatsRow.height,
        child: Row(
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: 1),
              Expanded(child: _column()),
            ],
          ],
        ),
      ),
    );
  }
}
