import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../models/program.dart';
import 'app_bottom_nav.dart';

/// Aktif program seçme sheet'i: krem zeminde tek beyaz kart içinde ince çizgili
/// satırlar (iOS ayarlar listesi gibi). Seçili satır kiremit radyo ve kiremit
/// yazı; bir satıra dokunmak sheet'i kapatıp o programı döndürür.
Future<ActiveProgram?> showSelectActiveProgramSheet({
  required BuildContext context,
  required List<ActiveProgram> programs,
  required String? currentActiveId,
}) {
  return showModalBottomSheet<ActiveProgram>(
    context: context,
    isScrollControlled:
        true, // KRİTİK: İçerik yüksekliğine göre esnek ve kaydırılabilir olmasını sağlar
    backgroundColor: Colors.transparent,
    builder: (context) {
      // Sekme kabuğundaki süzülen alt barın altında kalmasın.
      final bottomPadding =
          MediaQuery.of(context).padding.bottom + AppBottomNav.clearance;

      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              children: [
                // Sürükleme çubuğu
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(45),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Aktif Program Seç',
                      style: AppTypography.heading2.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ),
                // Liste başlığın altında sert kesilmesin diye üstte yumuşak geçiş.
                Expanded(
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback:
                        (rect) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black],
                          stops: [0, 0.04],
                        ).createShader(rect),
                    child: ListView(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        6,
                        16,
                        bottomPadding + 24,
                      ),
                      children: [
                        Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              for (var i = 0; i < programs.length; i++) ...[
                                if (i > 0)
                                  const Divider(
                                    height: 1,
                                    thickness: 0.5,
                                    indent: 52,
                                    color: AppColors.borderSubtle,
                                  ),
                                _ProgramRow(
                                  program: programs[i],
                                  isActive: programs[i].id == currentActiveId,
                                  onTap:
                                      () => Navigator.of(
                                        context,
                                      ).pop(programs[i]),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _ProgramRow extends StatefulWidget {
  final ActiveProgram program;
  final bool isActive;
  final VoidCallback onTap;

  const _ProgramRow({
    required this.program,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_ProgramRow> createState() => _ProgramRowState();
}

class _ProgramRowState extends State<_ProgramRow> {
  static const double _radio = 22;

  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed != value) setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final program = widget.program;
    final days = program.workouts.length;
    final exercises = program.workouts.fold<int>(
      0,
      (sum, w) => sum + w.exercises.length,
    );
    final active = widget.isActive;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _isPressed ? AppColors.fillSubtle : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: _radio,
              height: _radio,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? AppColors.homeHero : Colors.transparent,
                border: Border.all(
                  color:
                      active
                          ? AppColors.homeHero
                          : AppColors.textTertiary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                scale: active ? 1 : 0,
                child: const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                program.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body16Medium.copyWith(
                  color: active ? AppColors.homeHero : AppColors.textPrimary,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$days gün',
                  style: AppTypography.body12Medium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                Text(
                  '$exercises hareket',
                  style: AppTypography.body12Regular.copyWith(
                    color: AppColors.textTertiary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
