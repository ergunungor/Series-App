import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'gradient_progress_bar.dart';
import 'app_button.dart';

class SurveyStepScaffold extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final String question;
  final Widget content;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final String nextLabel;

  const SurveyStepScaffold({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.question,
    required this.content,
    required this.onNext,
    this.onBack,
    this.nextLabel = 'İleri',
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (onBack != null)
                  IconButton(
                    onPressed: onBack,
                    icon: Icon(
                      Icons.arrow_back,
                      color: AppColors.brandTertiary,
                    ),
                  ),
                Expanded(
                  child: GradientProgressBar(
                    value: (currentStep + 1) / totalSteps,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              question,
              style: AppTypography.heading2.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(child: SingleChildScrollView(child: content)),
            AppButton(text: nextLabel, showIcon: false, onPressed: onNext),
          ],
        ),
      ),
    );
  }
}
