import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AppTopBar extends StatelessWidget {
  final VoidCallback? onMenuTap;

  const AppTopBar({super.key, this.onMenuTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onMenuTap,
          icon: Icon(Icons.menu, color: AppColors.brandTertiary),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 40),
              child: Text(
                'SERIES',
                style: AppTypography.heading1.copyWith(
                  color: AppColors.brandTertiary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
