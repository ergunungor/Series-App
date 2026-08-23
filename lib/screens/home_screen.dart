import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/workout_card.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/program.dart';
import '../services/program_repository.dart';
import '../widgets/app_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// yeni:
class _HomeScreenState extends State<HomeScreen> {
  String _firstName = 'İsim'; // Varsayılan değer
  bool _isLoading = true; // Veri çekilirken loading göstermek için
  ActiveProgram? _activeProgram;
  bool _isLoadingProgram = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData(); // Sayfa açılırken veriyi çekmeye başla
    _fetchActiveProgram();
  }

  Future<void> _fetchActiveProgram() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingProgram = false);
      return;
    }
    try {
      final program = await ProgramRepository.fetchActiveProgram(user.id);
      if (mounted) {
        setState(() {
          _activeProgram = program;
          _isLoadingProgram = false;
        });
      }
    } catch (error) {
      debugPrint('Program çekme hatası: $error');
      if (mounted) setState(() => _isLoadingProgram = false);
    }
  }

  Future<void> _fetchUserData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // profiles tablosundan bu user'ın verisini çekiyoruz
        final response =
            await Supabase.instance.client
                .from('profiles')
                .select('full_name')
                .eq('id', user.id)
                .single(); // Sadece tek bir satır döneceğini biliyoruz

        if (response['full_name'] != null) {
          final fullName = response['full_name'] as String;
          // Sadece ilk ismini almak için boşluktan bölüyoruz
          final firstName = fullName.split(' ')[0];

          if (mounted) {
            setState(() {
              _firstName = firstName;
              _isLoading = false;
            });
          }
        }
      }
    } catch (error) {
      debugPrint('Veri çekme hatası: $error');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // yeni:
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppTopBar(),
              const SizedBox(height: 28),
              // yeni:
              if (_isLoadingProgram)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_activeProgram == null ||
                  _activeProgram!.workouts.isEmpty)
                _NoProgramCard(greeting: 'Hoş Geldin, $_firstName')
              else
                WorkoutCard(
                  date: '22/08/2026',
                  streakCount: 5,
                  greeting: 'Hoş Geldin, $_firstName',
                  workoutSummary:
                      '${_activeProgram!.workouts.first.exercises.length} Hareket - '
                      '${_activeProgram!.workouts.first.exercises.fold<int>(0, (sum, e) => sum + e.sets)} set '
                      '(~${_activeProgram!.workouts.first.estimatedDurationMin}dk)',
                  nextWorkoutName: _activeProgram!.workouts.first.name,
                ),
              // yeni:
              const SizedBox(height: 32),
              if (_activeProgram != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.brandSecondary),
                    borderRadius: BorderRadius.circular(45),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AKTİF PROGRAM',
                        style: AppTypography.heading3.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Divider(color: AppColors.brandSecondary, height: 1),
                      const SizedBox(height: 16),
                      Text(
                        '"${_activeProgram!.name}"',
                        style: AppTypography.body18Medium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (_activeProgram!.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _activeProgram!.description,
                          style: AppTypography.body14Regular.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '${_activeProgram!.workouts.length} Antrenman Günü',
                        style: AppTypography.body16Medium.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoProgramCard extends StatelessWidget {
  final String greeting;

  const _NoProgramCard({required this.greeting});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.brandSecondary),
        borderRadius: BorderRadius.circular(45),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: AppTypography.heading2.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Henüz aktif bir programın yok.',
            style: AppTypography.body14Regular.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            text: 'Program Oluştur',
            showIcon: false,
            onPressed: () => context.push('/onboarding-survey'),
          ),
        ],
      ),
    );
  }
}
