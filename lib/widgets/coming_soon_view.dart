import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class ComingSoonView extends StatelessWidget {
  final IconData icon;
  final String title;

  const ComingSoonView({super.key, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: AppColors.brandSecondary),
            ),
            child: Icon(icon, size: 40, color: AppColors.brandPrimary),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: AppTypography.heading2.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yakında burada olacak',
            style: AppTypography.body14Regular.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
