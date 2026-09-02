import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/workout_card.dart';
import '../widgets/gradient_progress_bar.dart';
import '../widgets/app_logo.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/program.dart';
import '../models/workout_history.dart';
import '../services/program_repository.dart';
import '../services/workout_history_repository.dart';
import '../widgets/app_button.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/select_active_program_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _firstName = 'İsim';
  bool _isLoading = true;
  ActiveProgram? _activeProgram;
  bool _isLoadingProgram = true;
  int _weeklyCompleted = 0;
  int _weeklyTotal = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
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
      // Program yüklendikten sonra haftalık performansı hesaplıyoruz —
      // hangi workout id'lerinin bu programa ait olduğunu bilmemiz lazım,
      // o yüzden bu adım _activeProgram set edildikten sonra çalışıyor.
      if (program != null) _fetchWeeklyPerformance(program);
    } catch (error) {
      debugPrint('Program çekme hatası: $error');
      if (mounted) setState(() => _isLoadingProgram = false);
    }
  }

  Future<void> _fetchWeeklyPerformance(ActiveProgram program) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final history = await WorkoutHistoryRepository.fetchHistory(user.id);
      final now = DateTime.now();
      // Haftanın başlangıcı = bu haftanın Pazartesi'si, saat 00:00.
      final startOfWeek = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      final programWorkoutIds = program.workouts.map((w) => w.id).toSet();

      // Bu programa ait, bu hafta içinde tamamlanmış seansların hangi
      // antrenman günlerine (workout id) ait olduğunu benzersiz olarak
      // topluyoruz — aynı günü iki kez yapsa bile "1 gün tamamlandı" sayılır.
      final doneThisWeek =
          history
              .where(
                (s) =>
                    programWorkoutIds.contains(s.workoutId) &&
                    !s.completedAt.isBefore(startOfWeek),
              )
              .map((s) => s.workoutId)
              .toSet();

      if (mounted) {
        setState(() {
          _weeklyCompleted = doneThisWeek.length;
          _weeklyTotal = program.workouts.length;
        });
      }
    } catch (error) {
      debugPrint('Haftalık performans hesaplama hatası: $error');
    }
  }

  Future<void> _fetchUserData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final response =
            await Supabase.instance.client
                .from('profiles')
                .select('full_name')
                .eq('id', user.id)
                .single();

        if (response['full_name'] != null) {
          final fullName = response['full_name'] as String;
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRefresh() async {
    await Future.wait([_fetchUserData(), _fetchActiveProgram()]);
  }

  @override
  Widget build(BuildContext context) {
    // Cihazın kendi alt çentik boşluğu (iOS Home Indicator vb.) + BottomNav payı (80px) + nefes payı (24px)
    final bottomInset = MediaQuery.of(context).padding.bottom + 136;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom:
            false, // Alt padding'i biz dinamik yönettiğimiz için SafeArea'nın altını serbest bırakıyoruz
        child: RefreshIndicator(
          color: AppColors.brandPrimary,
          backgroundColor: Colors.white,
          onRefresh: _handleRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppTopBar(),
                const SizedBox(height: 28),
                Text(
                  'Hoş Geldin, $_firstName',
                  style: AppTypography.heading1.copyWith(
                    color: AppColors.brandPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sıradaki antrenman:',
                  style: AppTypography.body18Medium.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 16),
                if (_isLoadingProgram)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_activeProgram == null ||
                    _activeProgram!.workouts.isEmpty)
                  _NoProgramCard(
                    onCreate: () => context.push('/onboarding-survey'),
                  )
                else
                  WorkoutCard(
                    nextWorkoutName: _activeProgram!.workouts.first.name,
                    onStartTap: () async {
                      final workout = _activeProgram!.workouts.first;
                      final confirmed = await showAppConfirmDialog(
                        context: context,
                        title: 'Antrenmanı Başlat',
                        message:
                            '"${workout.name}" antrenmanına başlamak istiyor musunuz?',
                        confirmLabel: 'Başla',
                      );
                      if (confirmed && context.mounted) {
                        context.push('/workout-player', extra: workout);
                      }
                    },
                  ),
                if (_activeProgram != null) ...[
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Text(
                        'Haftalık Performans',
                        style: AppTypography.body16Medium.copyWith(
                          color: AppColors.brandTertiary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '($_weeklyCompleted/$_weeklyTotal)',
                        style: AppTypography.body16Regular.copyWith(
                          color: AppColors.brandSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GradientProgressBar(
                    value:
                        _weeklyTotal == 0 ? 0 : _weeklyCompleted / _weeklyTotal,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Aktif Program',
                        style: AppTypography.heading3.copyWith(
                          color: AppColors.brandPrimary,
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          final user =
                              Supabase.instance.client.auth.currentUser;
                          if (user == null) return;
                          final allPrograms =
                              await ProgramRepository.fetchPrograms(user.id);
                          if (!context.mounted) return;
                          final selected = await showSelectActiveProgramSheet(
                            context: context,
                            programs: allPrograms,
                            currentActiveId: _activeProgram?.id,
                          );
                          if (selected != null) {
                            await ProgramRepository.setActiveProgram(
                              user.id,
                              selected.id,
                            );
                            _fetchActiveProgram();
                          }
                        },
                        icon: Icon(
                          Icons.swap_horiz,
                          size: 20,
                          color: AppColors.brandTertiary,
                        ),
                        tooltip: 'Programı değiştir',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap:
                          () => context.push(
                            '/program-detail',
                            extra: _activeProgram,
                          ),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.brandSecondary),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const AppLogo(
                              explicitSize: 44,
                              type: AppLogoType.dark,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _activeProgram!.name,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.body18Medium.copyWith(
                                      color: AppColors.brandTertiary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Programa git',
                                        style: AppTypography.body16Regular
                                            .copyWith(
                                              color: AppColors.textTertiary,
                                            ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.chevron_right,
                                        size: 20,
                                        color: AppColors.textTertiary,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoProgramCard extends StatelessWidget {
  final VoidCallback onCreate;

  const _NoProgramCard({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.brandPrimary),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Henüz aktif bir programın yok.',
            style: AppTypography.body16Medium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            text: 'Program Oluştur',
            showIcon: false,
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}
