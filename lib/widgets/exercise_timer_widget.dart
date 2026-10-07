import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'pressable_scale.dart';

class ExerciseTimerWidget extends StatefulWidget {
  final int durationSeconds;
  final VoidCallback? onComplete; // YENİ: Süre bitince çalışacak fonksiyon

  const ExerciseTimerWidget({
    super.key,
    required this.durationSeconds,
    this.onComplete,
  });

  @override
  State<ExerciseTimerWidget> createState() => _ExerciseTimerWidgetState();
}

class _ExerciseTimerWidgetState extends State<ExerciseTimerWidget> {
  late int _remainingSeconds;
  Timer? _timer;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.durationSeconds;
  }

  @override
  void didUpdateWidget(covariant ExerciseTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.durationSeconds != widget.durationSeconds) {
      _resetTimer();
    }
  }

  void _startTimer() {
    if (_remainingSeconds > 0 && !_isRunning) {
      setState(() => _isRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 0) {
          setState(() => _remainingSeconds--);
          // YENİ: Süre tam bittiği an ana ekrana ses çalması için sinyal gönderiyoruz
          if (_remainingSeconds == 0) {
            widget.onComplete?.call();
          }
        } else {
          _stopTimer();
        }
      });
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _stopTimer();
    setState(() => _remainingSeconds = widget.durationSeconds);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.durationSeconds == 0 ? 1 : widget.durationSeconds;
    final progress = 1 - _remainingSeconds / total;
    final isDone = _remainingSeconds == 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formattedTime,
          style: AppTypography.heading1.copyWith(
            fontSize: 56,
            fontWeight: FontWeight.w700,
            letterSpacing: -2,
            height: 1,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: isDone ? AppColors.success : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        // İlerleme: süre ilerledikçe kiremit dolgu akıcı uzar.
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: progress.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.linear,
            builder:
                (context, value, _) => Container(
                  height: 6,
                  color: AppColors.borderSubtle,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: value,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.homeHeroGlow,
                            isDone ? AppColors.success : AppColors.homeHero,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PressableScale(
              pressedScale: 0.92,
              onTap: _resetTimer,
              child: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppColors.fillSubtle,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.replay_rounded,
                  size: 24,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            const SizedBox(width: 18),
            PressableScale(
              pressedScale: 0.94,
              onTap: _isRunning ? _stopTimer : _startTimer,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRunning ? AppColors.accentGold : AppColors.homeHero,
                  boxShadow: [
                    BoxShadow(
                      color: (_isRunning
                              ? AppColors.accentGold
                              : AppColors.homeHero)
                          .withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 38,
                  color: _isRunning ? AppColors.espresso : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
