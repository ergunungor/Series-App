import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'pressable_scale.dart';

/// Tek seçimli listelerde tam genişlik seçenek kartı: beyaz kart, sağda halka
/// göstergesi. Seçilince çerçeve ve gösterge kiremit olur, gösterge onay
/// işaretiyle dolar (200ms).
class SelectableOptionCard extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const SelectableOptionCard({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  static const double _radius = 20;
  static const double _indicator = 26;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.98,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(
            color: isSelected ? AppColors.homeHero : AppColors.borderSubtle,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  isSelected
                      ? AppColors.homeHero.withValues(alpha: 0.16)
                      : Colors.black.withValues(alpha: 0.03),
              blurRadius: isSelected ? 18 : 8,
              offset: Offset(0, isSelected ? 8 : 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: AppTypography.body16Medium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                child: Text(label),
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: _indicator,
              height: _indicator,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.homeHero : Colors.transparent,
                border: Border.all(
                  color:
                      isSelected
                          ? AppColors.homeHero
                          : AppColors.textTertiary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                scale: isSelected ? 1 : 0,
                child: const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
