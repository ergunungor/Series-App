import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_bottom_nav.dart';
import 'reveal.dart';

/// "Yeni Program" sheet'i: espresso zeminde ince işçilikli cam kartlar. Üst
/// kenarda altın ışık çizgisi, sağ üstte silik halter filigranı; AI seçeneği
/// altın çerçeveli ve "ÖNERİLEN" rozetli.
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

      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.9, -1.1),
              radius: 1.5,
              colors: [
                AppColors.espressoLift,
                AppColors.espresso,
                AppColors.heroDarkEnd,
              ],
              stops: [0, 0.42, 1],
            ),
          ),
          child: Stack(
            children: [
              // Üst kenarda ortadan kenarlara solan altın ışık çizgisi.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.accentGold.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Silik büyük halter filigranı.
              Positioned(
                right: -30,
                top: -34,
                child: IgnorePointer(
                  child: Icon(
                    Icons.fitness_center_rounded,
                    size: 150,
                    color: AppColors.onHeroDark.withValues(alpha: 0.045),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, bottomInset + 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(top: 12, bottom: 18),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: AppColors.accentGold,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'KÜTÜPHANE',
                            style: AppTypography.body12Medium.copyWith(
                              color: AppColors.onHeroDark.withValues(
                                alpha: 0.6,
                              ),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 6, 4, 18),
                      child: Text(
                        'Yeni Program',
                        style: AppTypography.heading1.copyWith(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ),
                    Reveal(
                      duration: const Duration(milliseconds: 400),
                      offsetY: 10,
                      child: _GlassOption(
                        icon: Icons.auto_awesome,
                        isPrimary: true,
                        title: 'AI ile Program Oluştur',
                        subtitle:
                            'Birkaç soruyla sana özel bir program üretelim',
                        onTap: () {
                          Navigator.of(context).pop();
                          onCreateWithAi();
                        },
                      ),
                    ),
                    const SizedBox(height: 11),
                    Reveal(
                      delay: const Duration(milliseconds: 70),
                      duration: const Duration(milliseconds: 400),
                      offsetY: 10,
                      child: _GlassOption(
                        icon: Icons.file_upload_outlined,
                        title: 'Program Yükle',
                        subtitle:
                            'Kendi programını yükle ve takibini kolaylaştır',
                        onTap: () {
                          Navigator.of(context).pop();
                          onImportProgram();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Cam seçenek kartı: dikey gradyan, ince açık kenar ve iç parlama çizgisi.
/// Basınca küçülür ve çerçevesi altına döner.
class _GlassOption extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Ana seçenek: altın çerçeve, parlak altın ikon karosu, rozet, dolu ok.
  final bool isPrimary;

  const _GlassOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  State<_GlassOption> createState() => _GlassOptionState();
}

class _GlassOptionState extends State<_GlassOption> {
  static const double _radius = 22;
  static const double _tile = 52;
  static const double _arrow = 30;

  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed != value) setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.isPrimary;
    final borderColor =
        _isPressed
            ? AppColors.accentGold.withValues(alpha: 0.6)
            : (primary
                ? AppColors.accentGold.withValues(alpha: 0.45)
                : AppColors.onHeroDark.withValues(alpha: 0.12));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.onHeroDark.withValues(alpha: 0.11),
                AppColors.onHeroDark.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color:
                    primary
                        ? AppColors.accentGold.withValues(alpha: 0.28)
                        : Colors.black.withValues(alpha: 0.4),
                blurRadius: 28,
                spreadRadius: -14,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // İç parlama: kartın üst kenarında ince açık çizgi.
              Positioned(
                left: 8,
                right: 8,
                top: -14,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.onHeroDark.withValues(alpha: 0.28),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: _tile,
                    height: _tile,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient:
                          primary
                              ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.goldHighlight,
                                  AppColors.accentGold,
                                  AppColors.goldShade,
                                ],
                                stops: [0, 0.55, 1],
                              )
                              : null,
                      color:
                          primary
                              ? null
                              : AppColors.onHeroDark.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(17),
                      border:
                          primary
                              ? null
                              : Border.all(
                                color: AppColors.onHeroDark.withValues(
                                  alpha: 0.14,
                                ),
                              ),
                      boxShadow:
                          primary
                              ? [
                                BoxShadow(
                                  color: AppColors.accentGold.withValues(
                                    alpha: 0.5,
                                  ),
                                  blurRadius: 20,
                                  spreadRadius: -6,
                                  offset: const Offset(0, 10),
                                ),
                              ]
                              : null,
                    ),
                    child: Icon(
                      widget.icon,
                      size: 24,
                      color:
                          primary ? AppColors.espresso : AppColors.accentGold,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (primary)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentGold,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'ÖNERİLEN',
                              style: AppTypography.body12Medium.copyWith(
                                color: AppColors.espresso,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                height: 1,
                              ),
                            ),
                          ),
                        Text(
                          widget.title,
                          style: AppTypography.body16Medium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.subtitle,
                          style: AppTypography.body12Regular.copyWith(
                            color: AppColors.onHeroDark.withValues(alpha: 0.62),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: _arrow,
                    height: _arrow,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          primary
                              ? AppColors.accentGold
                              : AppColors.onHeroDark.withValues(alpha: 0.1),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color:
                          primary ? AppColors.espresso : AppColors.accentGold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
