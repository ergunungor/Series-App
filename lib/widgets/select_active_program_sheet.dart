import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../models/program.dart';
import 'app_bottom_nav.dart';
import 'app_logo.dart';
import 'pressable_scale.dart';
import 'reveal.dart';

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
        initialChildSize: 0.55,
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
                // Sabit ConstrainedBox yerine DraggableScrollableSheet kullanan
                // esnek liste: uzun olsa da akıcı kayar.
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + 24),
                    itemCount: programs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final program = programs[index];
                      final card = _ProgramOptionCard(
                        program: program,
                        isActive: program.id == currentActiveId,
                        onTap: () => Navigator.of(context).pop(program),
                      );
                      if (index >= _revealedItems) return card;
                      return Reveal(
                        delay: _revealStagger * index,
                        duration: _revealDuration,
                        offsetY: 10,
                        child: card,
                      );
                    },
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

// Sheet açılışında ilk kartlar sırayla belirir; lazy listede gerisi animasyonsuz.
const int _revealedItems = 5;
const Duration _revealStagger = Duration(milliseconds: 60);
const Duration _revealDuration = Duration(milliseconds: 400);

class _ProgramOptionCard extends StatelessWidget {
  final ActiveProgram program;
  final bool isActive;
  final VoidCallback onTap;

  const _ProgramOptionCard({
    required this.program,
    required this.isActive,
    required this.onTap,
  });

  static const double _radius = 22;
  static const double _tileSize = 46;
  static const double _indicatorSize = 26;
  static const double _activeBorderWidth = 1.5;

  String get _summary {
    final days = program.workouts.length;
    final exercises = program.workouts.fold<int>(
      0,
      (sum, w) => sum + w.exercises.length,
    );
    return '$days gün · $exercises hareket';
  }

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.98,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
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
        // Seçim çerçevesi layout'u kaydırmasın diye hep var, aktif değilken şeffaf.
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(
            color: isActive ? AppColors.homeHero : Colors.transparent,
            width: _activeBorderWidth,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: _tileSize,
              height: _tileSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient:
                    isActive
                        ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.homeHero, AppColors.homeHeroDeep],
                        )
                        : null,
                color: isActive ? null : AppColors.fillSubtle,
                borderRadius: BorderRadius.circular(15),
              ),
              child: AppLogo(
                explicitSize: 28,
                type: isActive ? AppLogoType.light : AppLogoType.dark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    program.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body16Medium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _summary,
                    style: AppTypography.body12Regular.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _indicatorSize,
              height: _indicatorSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? AppColors.homeHero : Colors.transparent,
                border: Border.all(
                  color:
                      isActive
                          ? AppColors.homeHero
                          : AppColors.textTertiary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child:
                  isActive
                      ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                      : null,
            ),
          ],
        ),
      ),
    );
  }
}
