import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import '../services/app_settings.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'pressable_scale.dart';

/// Ayar satırında görünen kısa ad.
String soundModeLabel(SoundMode mode) => switch (mode) {
  SoundMode.mix => 'Müzikle birlikte',
  SoundMode.duck => 'Müziği kıs',
  SoundMode.pause => 'Müziği duraklat',
};

String _soundModeHint(SoundMode mode) => switch (mode) {
  SoundMode.mix => 'Müzik durmaz, ses üstüne biner.',
  SoundMode.duck => 'Ses çalarken müziğin sesi kısılır, sonra geri gelir.',
  SoundMode.pause =>
    'Ses çalarken müzik durur. Müzik uygulamasına göre kendiliğinden '
        'devam etmeyebilir.',
};

/// "Müzik çalarken" seçim sayfası.
Future<void> showSoundModeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final bottomSafe = MediaQuery.paddingOf(context).bottom;
      return Container(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomSafe + 24),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        // Kısa ekranlarda / büyük yazı boyutunda taşmasın diye kaydırılabilir.
        child: SingleChildScrollView(
          child: ListenableBuilder(
            listenable: AppSettings.instance,
            builder: (context, _) {
              final current = AppSettings.instance.soundMode;
              return Column(
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
                        'Müzik çalarken',
                        style: AppTypography.heading2.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Set arası sesler çalarken telefonundaki müziğe ne olsun?',
                        style: AppTypography.body14Regular.copyWith(
                          color: AppColors.textTertiary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final mode in SoundMode.values) ...[
                    _ModeOption(
                      label: soundModeLabel(mode),
                      hint: _soundModeHint(mode),
                      selected: mode == current,
                      onTap: () {
                        AppSettings.instance.setSoundMode(mode);
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

class _ModeOption extends StatelessWidget {
  final String label;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  const _ModeOption({
    required this.label,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.98,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.homeHero : Colors.transparent,
            width: 1.5,
          ),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.body16Medium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: AppTypography.body14Regular.copyWith(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              size: 22,
              color: selected ? AppColors.homeHero : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
