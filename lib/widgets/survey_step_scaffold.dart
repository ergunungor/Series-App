import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'gradient_progress_bar.dart';
import 'app_top_bar.dart'; // AppTopBar import edildi

class SurveyStepScaffold extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final String question;
  final Widget content;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final VoidCallback? onExit; // Çarpı butonu için yeni callback
  final String nextLabel;

  const SurveyStepScaffold({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.question,
    required this.content,
    required this.onNext,
    this.onBack,
    this.onExit,
    this.nextLabel = 'İleri',
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        // Üst boşluğu diğer ekranlarla (HomeScreen) aynı olması için 12'ye çektik:
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar ve Çıkış İkonu Alanı
            Stack(
              alignment: Alignment.center, // İkisini dikeyde birbirine eşitler
              children: [
                const AppTopBar(), // Kendi doğal boyutunda renderlanır
                if (onExit != null)
                  Positioned(
                    right: 0,
                    child: Transform.translate(
                      offset: const Offset(
                        0,
                        4,
                      ), // Eğer X hala çok az yukarıdaysa bunu 2 yapabilirsin
                      child: IconButton(
                        onPressed: onExit,
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.brandPrimary,
                          size: 28,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            GradientProgressBar(value: (currentStep + 1) / totalSteps),
            const SizedBox(height: 32),
            Text(
              question,
              style: AppTypography.heading2.copyWith(
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(child: SingleChildScrollView(child: content)),

            Row(
              children: [
                if (onBack != null) ...[
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: onBack,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: AppColors.brandPrimary,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.chevron_left,
                              color: AppColors.brandPrimary,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Geri',
                              style: AppTypography.body16Medium.copyWith(
                                color: AppColors.brandPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            nextLabel,
                            style: AppTypography.body16Medium.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (nextLabel == 'İleri')
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
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
