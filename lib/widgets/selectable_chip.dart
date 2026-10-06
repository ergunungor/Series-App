import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'pressable_scale.dart';

/// Seçilebilir hap: seçilince kiremit dolar, yazı beyaza döner (180ms). Basınca
/// hafifçe küçülür.
class SelectableChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const SelectableChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.96,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.homeHero : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.homeHero : AppColors.borderSubtle,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(45),
          boxShadow: [
            BoxShadow(
              color:
                  isSelected
                      ? AppColors.homeHero.withValues(alpha: 0.28)
                      : Colors.black.withValues(alpha: 0.03),
              blurRadius: isSelected ? 14 : 8,
              offset: Offset(0, isSelected ? 6 : 2),
            ),
          ],
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: AppTypography.body16Medium.copyWith(
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
