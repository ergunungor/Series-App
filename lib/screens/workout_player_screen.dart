import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_logo.dart';

class WorkoutPlayerScreen extends StatefulWidget {
  const WorkoutPlayerScreen({super.key});

  @override
  State<WorkoutPlayerScreen> createState() => _WorkoutPlayerScreenState();
}

class _WorkoutPlayerScreenState extends State<WorkoutPlayerScreen> {
  final _repsController = TextEditingController(text: 'Tekrar Sayısı');
  final _weightController = TextEditingController(text: 'Ağırlık');

  @override
  void dispose() {
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.25),
                      blurRadius: 14.667,
                      spreadRadius: 3.667,
                      offset: const Offset(2.2, 2.2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(26),
                child: const AppLogo(
                  size: AppLogoSize.medium,
                  type: AppLogoType.dark,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.brandSecondary),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.brandPrimary, Color(0xFF300000)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.25),
                      blurRadius: 9,
                      spreadRadius: 3,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hareket Adı:',
                      style: AppTypography.body14Medium.copyWith(
                        color: AppColors.brandSecondary,
                      ),
                    ),
                    Text(
                      'Leg Raise',
                      style: AppTypography.heading1.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Bilgi:',
                      style: AppTypography.body14Medium.copyWith(
                        color: AppColors.brandSecondary,
                      ),
                    ),
                    Text(
                      '3 Set 12 Tekrar',
                      style: AppTypography.heading1.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Set:',
                              style: AppTypography.body14Medium.copyWith(
                                color: AppColors.brandSecondary,
                              ),
                            ),
                            Text(
                              '1/3',
                              style: AppTypography.heading1.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Expanded(
                          child: TextField(
                            controller: _repsController,
                            textAlign: TextAlign.center,
                            style: AppTypography.body16Regular.copyWith(
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.all(16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: TextField(
                            controller: _weightController,
                            textAlign: TextAlign.center,
                            style: AppTypography.body16Regular.copyWith(
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.all(16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(45),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.25),
                      blurRadius: 9,
                      spreadRadius: 5,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        'Sıradaki',
                        style: AppTypography.body18Medium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        'Cable Crunch - 3x10',
                        style: AppTypography.body16Medium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  Container(
                    width: 124,
                    height: 124,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.check,
                        color: Colors.green,
                        size: 48,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
