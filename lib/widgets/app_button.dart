import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum AppButtonVariant { filled, outlined }

// yeni:
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool showIcon;
  final IconData icon;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.showIcon = true,
    this.icon = Icons.play_arrow_rounded,
  });
  @override
  Widget build(BuildContext context) {
    final isFilled = variant == AppButtonVariant.filled;
    final Color fg = isFilled ? Colors.white : AppColors.brandTertiary;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: isFilled ? AppColors.brandTertiary : Colors.white,
          side: BorderSide(color: AppColors.brandTertiary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: AppTypography.body16Medium.copyWith(color: fg)),
            if (showIcon) ...[
              const SizedBox(width: 8),
              Icon(icon, size: 24, color: fg),
            ],
          ],
        ),
      ),
    );
  }
}
