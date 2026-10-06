import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Kartın ya da listenin üstünde duran küçük, silik bölüm başlığı; sağda
/// opsiyonel ikincil metin.
class SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;

  const SectionTitle({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.body12Medium.copyWith(
      color: AppColors.textTertiary,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (trailing != null) Text(trailing!, style: style),
        ],
      ),
    );
  }
}
