import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/coming_soon_view.dart';

class WorkoutsScreen extends StatelessWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              const AppTopBar(),
              const SizedBox(height: 28),
              const Expanded(
                child: ComingSoonView(
                  icon: Icons.fitness_center_rounded,
                  title: 'Antrenmanlar',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
