import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/app_button.dart';
import '../models/program.dart';
import '../services/program_repository.dart';

class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> {
  ActiveProgram? _activeProgram;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final program = await ProgramRepository.fetchActiveProgram(user.id);
      if (mounted) {
        setState(() {
          _activeProgram = program;
          _isLoading = false;
        });
      }
    } catch (error) {
      debugPrint('Program çekme hatası: $error');
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _activeProgram == null
                        ? _EmptyState(
                          onCreate: () => context.push('/onboarding-survey'),
                        )
                        : _ProgramDetail(program: _activeProgram!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: AppColors.brandSecondary),
            ),
            child: Icon(
              Icons.auto_awesome,
              size: 40,
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Henüz bir programın yok',
            style: AppTypography.heading2.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Birkaç soruyla sana özel bir antrenman\nprogramı oluşturalım.',
            textAlign: TextAlign.center,
            style: AppTypography.body14Regular.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            child: AppButton(
              text: 'Program Oluştur',
              showIcon: false,
              onPressed: onCreate,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramDetail extends StatelessWidget {
  final ActiveProgram program;

  const _ProgramDetail({required this.program});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${program.name}"',
            style: AppTypography.heading2.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          if (program.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              program.description,
              style: AppTypography.body14Regular.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
          const SizedBox(height: 24),
          ...program.workouts.map(
            (workout) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.brandSecondary),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gün ${workout.dayNumber}: ${workout.name}',
                            style: AppTypography.body16Medium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${workout.exercises.length} hareket · ~${workout.estimatedDurationMin} dk',
                            style: AppTypography.body14Regular.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.textTertiary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
