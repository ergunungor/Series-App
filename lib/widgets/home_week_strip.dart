import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Ana Sayfa hero'sunun içindeki cam hafta şeridi: Pazartesi'den Pazar'a 7 gün,
/// tamamlananlar altın dolu ve onaylı, bugün altın halka, gerisi silik.
class HomeWeekStrip extends StatelessWidget {
  /// Bu hafta antrenman yapılan günler (0 = Pazartesi ... 6 = Pazar).
  final Set<int> doneDays;
  final int todayIndex;
  final int completed;
  final int total;

  const HomeWeekStrip({
    super.key,
    required this.doneDays,
    required this.todayIndex,
    required this.completed,
    required this.total,
  });

  static const List<String> _dayInitials = ['P', 'S', 'Ç', 'P', 'C', 'C', 'P'];
  static const double _radius = 20;
  static const double _dotSize = 30;

  @override
  Widget build(BuildContext context) {
    final ready = total > 0;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: ready ? 1 : 0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.onHeroDark.withValues(alpha: 0.07),
          border: Border.all(
            color: AppColors.onHeroDark.withValues(alpha: 0.12),
          ),
          borderRadius: BorderRadius.circular(_radius),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bu hafta',
                    style: AppTypography.body12Regular.copyWith(
                      color: AppColors.onHeroDark.withValues(alpha: 0.65),
                    ),
                  ),
                  Text(
                    '$completed / $total gün',
                    style: AppTypography.body12Medium.copyWith(
                      color: AppColors.accentGold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _Day(
                      initial: _dayInitials[i],
                      index: i,
                      isDone: doneDays.contains(i),
                      isToday: i == todayIndex,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Day extends StatelessWidget {
  final String initial;
  final int index;
  final bool isDone;
  final bool isToday;

  const _Day({
    required this.initial,
    required this.index,
    required this.isDone,
    required this.isToday,
  });

  static const double _fillBaseMs = 350;
  // Soldan sağa her gün biraz daha geç oturur (kademeli doluş hissi).
  static const double _fillStaggerMs = 90;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          initial,
          style: AppTypography.body12Regular.copyWith(
            color: AppColors.onHeroDark.withValues(alpha: 0.5),
            fontSize: 10,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: isDone ? 1 : 0),
          duration: Duration(
            milliseconds: (_fillBaseMs + _fillStaggerMs * index).round(),
          ),
          curve: Curves.easeOutCubic,
          builder: (context, fill, _) {
            return Container(
              width: HomeWeekStrip._dotSize,
              height: HomeWeekStrip._dotSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(
                  AppColors.onHeroDark.withValues(alpha: 0.08),
                  AppColors.accentGold,
                  fill,
                ),
                border:
                    isToday && !isDone
                        ? Border.all(color: AppColors.accentGold, width: 1.5)
                        : null,
              ),
              child:
                  isDone
                      ? Opacity(
                        opacity: fill,
                        child: Transform.scale(
                          scale: 0.6 + 0.4 * fill,
                          child: const Icon(
                            Icons.check_rounded,
                            size: 17,
                            color: AppColors.espresso,
                          ),
                        ),
                      )
                      : isToday
                      ? Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: AppColors.accentGold,
                          shape: BoxShape.circle,
                        ),
                      )
                      : null,
            );
          },
        ),
      ],
    );
  }
}
