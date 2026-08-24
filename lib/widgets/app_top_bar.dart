import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AppTopBar extends StatelessWidget {
  const AppTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'SERIES',
          style: AppTypography.heading1.copyWith(
            color: AppColors.brandTertiary,
          ),
        ),
      ),
    );
  }
}
