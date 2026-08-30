import 'package:flutter/material.dart';
import '../theme/app_typography.dart';

class ActiveBadge extends StatelessWidget {
  const ActiveBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      decoration: BoxDecoration(
        // SVG'deki renk ve opaklık birebir: #78EB7B, %70 opaklık
        color: const Color(0xFF78EB7B).withOpacity(0.7),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        'AKTİF',
        style: AppTypography.body12Medium.copyWith(color: Colors.white),
      ),
    );
  }
}
