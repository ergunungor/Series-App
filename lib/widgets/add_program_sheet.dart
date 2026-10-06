// ignore_for_file: unused_element_parameter

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_bottom_nav.dart';
import 'pressable_scale.dart';
import 'reveal.dart';

Future<void> showAddProgramSheet({
  required BuildContext context,
  required VoidCallback onCreateWithAi,
  required VoidCallback onImportProgram,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      // Sheet, sekme kabuğundaki süzülen alt barın ALTINDA kalmasın diye barın
      // kapladığı alan kadar boşluk bırakılır.
      final bottomInset =
          MediaQuery.of(context).padding.bottom + AppBottomNav.clearance;

      return Container(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(45),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Yeni Program',
                  style: AppTypography.heading2.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Reveal(
              duration: const Duration(milliseconds: 400),
              offsetY: 10,
              child: _SheetOption(
                icon: Icons.auto_awesome,
                isPrimary: true,
                title: 'AI ile Program Oluştur',
                subtitle: 'Birkaç soruyla sana özel bir program üretelim',
                onTap: () {
                  Navigator.of(context).pop();
                  onCreateWithAi();
                },
              ),
            ),
            const SizedBox(height: 12),
            Reveal(
              delay: const Duration(milliseconds: 70),
              duration: const Duration(milliseconds: 400),
              offsetY: 10,
              child: _SheetOption(
                icon: Icons.file_upload_outlined,
                title: 'Program Yükle',
                subtitle: 'Kendi programını yükle ve takibini kolaylaştır',
                onTap: () {
                  Navigator.of(context).pop();
                  onImportProgram();
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Ana seçenek: kiremit gradyan ikon karosu; diğeri nötr karo.
  final bool isPrimary;

  const _SheetOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isPrimary = false,
  });

  static const double _radius = 22;
  static const double _tile = 48;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.98,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: _tile,
              height: _tile,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient:
                    isPrimary
                        ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.homeHero, AppColors.homeHeroDeep],
                        )
                        : null,
                color: isPrimary ? null : AppColors.fillSubtle,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isPrimary ? AppColors.accentGold : AppColors.homeHero,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body16Medium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.body12Regular.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 24,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
