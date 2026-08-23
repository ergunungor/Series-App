import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AppBottomNavItem {
  final IconData icon;
  final String label;

  const AppBottomNavItem({required this.icon, required this.label});
}

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<AppBottomNavItem> _items = [
    AppBottomNavItem(icon: Icons.home_rounded, label: 'Ana Sayfa'),
    AppBottomNavItem(icon: Icons.calendar_month_rounded, label: 'Programlar'),
    AppBottomNavItem(icon: Icons.fitness_center_rounded, label: 'Antrenmanlar'),
    AppBottomNavItem(icon: Icons.person_rounded, label: 'Profil'),
  ];

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // yeni:
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(45),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double slotWidth = constraints.maxWidth / _items.length;

            return Stack(
              children: [
                // Kayan "damla" arka plan
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 700),
                  curve: const ElasticOutCurve(0.85),
                  left: slotWidth * currentIndex + 3,
                  width: slotWidth - 6,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(currentIndex),
                      duration: const Duration(milliseconds: 700),
                      curve: const ElasticOutCurve(0.85),
                      tween: Tween(begin: 0.94, end: 1.0),
                      builder:
                          (context, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.navSelectedBg,
                          borderRadius: BorderRadius.circular(45),
                        ),
                      ),
                    ),
                  ),
                ),
                // Item'lar (icon + label, tıklanabilir)
                Row(
                  children: List.generate(_items.length, (index) {
                    final isSelected = index == currentIndex;
                    final item = _items[index];
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTap(index),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // yeni:
                              AnimatedScale(
                                duration: const Duration(milliseconds: 450),
                                curve: Curves.easeOutCubic,
                                scale: isSelected ? 1.08 : 1.0,
                                child: Icon(
                                  item.icon,
                                  color: AppColors.brandTertiary,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(height: 4),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 250),
                                style: AppTypography.body12Medium.copyWith(
                                  color: AppColors.brandTertiary,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                ),
                                child: Text(item.label),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
            // yeni:
          },
        ),
      ),
    );
  }
}
