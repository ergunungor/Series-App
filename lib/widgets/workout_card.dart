import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_logo.dart';

class WorkoutCard extends StatefulWidget {
  final String nextWorkoutName;
  final VoidCallback? onStartTap;

  const WorkoutCard({
    super.key,
    required this.nextWorkoutName,
    this.onStartTap,
  });

  @override
  State<WorkoutCard> createState() => _WorkoutCardState();
}

class _WorkoutCardState extends State<WorkoutCard> {
  static const double _cardRadius = 24;
  static const double _cardPadding = 24;
  static const double _buttonHeight = 48;
  static const double _pressedScale = 0.96;
  static const Duration _pressDuration = Duration(milliseconds: 120);

  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed != value) setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDeep],
        ),
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Dekoratif filigran logo: kartın sağ altından taşar, Container kırpar.
          Positioned(
            right: -28,
            bottom: -28,
            child: Opacity(
              opacity: 0.10,
              child: const AppLogo(explicitSize: 160, type: AppLogoType.light),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(_cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SIRADAKİ ANTRENMAN',
                  style: AppTypography.body12Medium.copyWith(
                    color: AppColors.onPrimary.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.nextWorkoutName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.heading2.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => _setPressed(true),
                  onTapUp: (_) => _setPressed(false),
                  onTapCancel: () => _setPressed(false),
                  onTap: widget.onStartTap,
                  child: AnimatedScale(
                    scale: _isPressed ? _pressedScale : 1.0,
                    duration: _pressDuration,
                    curve: Curves.easeOut,
                    child: Container(
                      height: _buttonHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            size: 22,
                            color: AppColors.onAccent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Antrenmanı Başlat',
                            style: AppTypography.body16Medium.copyWith(
                              color: AppColors.onAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
