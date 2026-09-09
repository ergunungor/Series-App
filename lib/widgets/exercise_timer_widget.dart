import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandSecondary.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formattedTime,
            style: AppTypography.heading1.copyWith(
              fontSize: 48,
              color:
                  _remainingSeconds == 0
                      ? Colors.green
                      : AppColors.brandPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _resetTimer,
                icon: Icon(Icons.replay, color: AppColors.textTertiary),
                iconSize: 28,
              ),
              const SizedBox(width: 16),
              InkWell(
                onTap: _isRunning ? _stopTimer : _startTimer,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        _isRunning
                            ? Colors.orange.withOpacity(0.2)
                            : AppColors.brandPrimary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isRunning ? Icons.pause : Icons.play_arrow,
                    color: _isRunning ? Colors.orange : AppColors.brandPrimary,
                    size: 36,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
