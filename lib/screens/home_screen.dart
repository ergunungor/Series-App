import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/detail_hero.dart';
import '../widgets/home_hero.dart';
import '../widgets/home_week_strip.dart';
import '../widgets/app_logo.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/program.dart';
import '../models/workout_history.dart';
import '../services/program_repository.dart';
import '../services/workout_history_repository.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/select_active_program_sheet.dart';
import 'package:lottie/lottie.dart';
import '../widgets/reveal.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/section_title.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Duration _revealDuration = Duration(milliseconds: 500);
  static const Duration _revealStagger = Duration(milliseconds: 100);
  String _firstName = '';
  ActiveProgram? _activeProgram;
  bool _isLoadingProgram = true;
  int _weeklyCompleted = 0;
  int _weeklyTotal = 0;
  int _nextWorkoutIndex = 0;
  // Geçmiş kayıtları (yeni → eski); hafta şeridi bundan hesaplanır.
  List<WorkoutHistorySession> _history = [];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchActiveProgram();
    programRefreshNotifier.addListener(_fetchActiveProgram);
  }

  @override
  void dispose() {
    programRefreshNotifier.removeListener(_fetchActiveProgram);
    super.dispose();
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
          _history = history;
          _weeklyCompleted = doneThisWeek.length;
          _weeklyTotal = program.workouts.length;
          // Eğer 3 günlük programı tamamladıysa (completed=3), modulo % 3 = 0 olur (başa döner).
          // Eğer 1 antrenman yaptıysa, 1 % 3 = 1 olur (ikinci antrenman).
          _nextWorkoutIndex =
              _weeklyTotal == 0 ? 0 : (_weeklyCompleted % _weeklyTotal);
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
            });
          }
        }
      }
    } catch (error) {
      debugPrint('Veri çekme hatası: $error');
    }
  }

  /// Bu hafta (Pazartesi başlangıçlı) bu programa ait antrenman yapılan günler:
  /// 0 = Pazartesi ... 6 = Pazar.
  Set<int> _doneWeekdays(ActiveProgram program) {
    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - 1),
    );
    final ids = program.workouts.map((w) => w.id).toSet();
    return {
      for (final s in _history)
        if (ids.contains(s.workoutId) && !s.completedAt.isBefore(startOfWeek))
          s.completedAt.weekday - 1,
    };
  }

  // Program değiştirme akışı: önceki IconButton'daki kodun aynısı.
  Future<void> _changeActiveProgram() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final allPrograms = await ProgramRepository.fetchPrograms(user.id);
    if (!mounted) return;
    final selected = await showSelectActiveProgramSheet(
      context: context,
      programs: allPrograms,
      currentActiveId: _activeProgram?.id,
    );
    if (selected != null) {
      await ProgramRepository.setActiveProgram(user.id, selected.id);
      _fetchActiveProgram();

      // HER SEFERİNDE DEĞERİ DEĞİŞTİRİYORUZ (SAYAÇ ARTIYOR)
      programRefreshNotifier.value++;
    }
  }

  Widget _buildLastWorkoutRow(WorkoutHistorySession session) {
    final date = DateFormat('d MMMM', 'tr_TR').format(session.completedAt);
    return _RowCard(
      leading: const _CheckTile(),
      title: session.workoutName,
      subtitle:
          '$date · ${session.exerciseCount} egzersiz · ${session.setCount} set',
      trailing: const Icon(
        Icons.chevron_right_rounded,
        size: 24,
        color: AppColors.textTertiary,
      ),
      onTap: () => context.push('/workout-history-detail', extra: session),
    );
  }

  Future<void> _handleRefresh() async {
    await Future.wait([_fetchUserData(), _fetchActiveProgram()]);
  }

  @override
  Widget build(BuildContext context) {
    // Cihazın kendi alt çentik boşluğu (iOS Home Indicator vb.) + BottomNav payı (80px) + nefes payı (24px)
    final bottomInset =
        MediaQuery.of(context).padding.bottom + AppBottomNav.clearance + 34;

    final program = _activeProgram;
    final hasProgram = program != null && program.workouts.isNotEmpty;
    final nextWorkout = hasProgram ? program.workouts[_nextWorkoutIndex] : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: HeroStatusBarScope(
        builder:
            (context, heroKey) => RefreshIndicator(
              color: AppColors.homeHero,
              backgroundColor: Colors.white,
              // Hero durum çubuğunun arkasına uzandığı için gösterge altından başlar.
              edgeOffset: MediaQuery.paddingOf(context).top,
              onRefresh: _handleRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HomeHero(
                      heroKey: heroKey,
                      firstName: _firstName,
                      isLoading: _isLoadingProgram,
                      workoutName: nextWorkout?.name,
                      exerciseCount: nextWorkout?.exercises.length ?? 0,
                      durationMin: nextWorkout?.estimatedDurationMin ?? 0,
                      footer:
                          hasProgram
                              ? HomeWeekStrip(
                                doneDays: _doneWeekdays(program),
                                todayIndex: DateTime.now().weekday - 1,
                                completed: _weeklyCompleted,
                                total: _weeklyTotal,
                              )
                              : null,
                      onStart:
                          nextWorkout == null
                              ? null
                              : () async {
                                final confirmed = await showAppConfirmDialog(
                                  context: context,
                                  title: 'Antrenmanı Başlat',
                                  message:
                                      '"${nextWorkout.name}" antrenmanına başlamak istiyor musunuz?',
                                  confirmLabel: 'Başla',
                                );
                                if (confirmed && context.mounted) {
                                  context.push(
                                    '/workout-player',
                                    extra: nextWorkout,
                                  );
                                }
                              },
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_isLoadingProgram && !hasProgram)
                            _NoProgramCard(
                              onCreate:
                                  () => context.push('/onboarding-survey'),
                            ),
                          if (_activeProgram != null) ...[
                            Reveal(
                              delay: _revealStagger,
                              duration: _revealDuration,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SectionTitle(title: 'Aktif program'),
                                  _RowCard(
                                    leading: const _LogoTile(),
                                    title: _activeProgram!.name,
                                    subtitle: 'Programa git',
                                    trailing: _SwapButton(
                                      onTap: _changeActiveProgram,
                                    ),
                                    onTap:
                                        () => context.push(
                                          '/program-detail',
                                          extra: _activeProgram,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            if (_history.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Reveal(
                                delay: _revealStagger * 2,
                                duration: _revealDuration,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SectionTitle(title: 'Son antrenman'),
                                    _buildLastWorkoutRow(_history.first),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }
}

/// Ana Sayfa'daki beyaz satır kartı: solda karo, ortada iki satır metin,
/// sağda opsiyonel eylem. Basınca küçülür.
class _RowCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  const _RowCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  static const double _radius = 22;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.98,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body16Medium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body12Regular.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

const double _tileSize = 46;

class _LogoTile extends StatelessWidget {
  const _LogoTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _tileSize,
      height: _tileSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.fillSubtle,
        borderRadius: BorderRadius.circular(15),
      ),
      child: const AppLogo(explicitSize: 28, type: AppLogoType.dark),
    );
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _tileSize,
      height: _tileSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.workoutsTint,
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Icon(
        Icons.check_rounded,
        size: 22,
        color: AppColors.success,
      ),
    );
  }
}

/// Programı değiştir butonu: 44px yuvarlak, basınca küçülür.
class _SwapButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SwapButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Programı değiştir',
      button: true,
      child: PressableScale(
        pressedScale: 0.92,
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: AppColors.fillSubtle,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.swap_horiz_rounded,
            size: 20,
            color: AppColors.homeHero,
          ),
        ),
      ),
    );
  }
}

class _NoProgramCard extends StatelessWidget {
  final VoidCallback onCreate;
  static const double _buttonHeight = 52;

  const _NoProgramCard({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Sevimli Hayalet GIF'i
          Lottie.asset(
            'assets/gifs/empty.json',
            width: 120,
            height: 120,
            fit:
                BoxFit
                    .contain, // Animasyonun kesilmemesi için contain kullanıyoruz
          ),
          const SizedBox(height: 16),
          Text(
            'Buralar biraz ıssız...',
            style: AppTypography.heading3.copyWith(
              color: AppColors.brandTertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Henüz aktif bir programın yok.\nHadi hemen bir tane oluşturalım!',
            textAlign: TextAlign.center,
            style: AppTypography.body14Regular.copyWith(
              color: AppColors.textTertiary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          PressableScale(
            onTap: onCreate,
            child: Container(
              width: double.infinity,
              height: _buttonHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.homeHero, AppColors.homeHeroDeep],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Program Oluştur',
                style: AppTypography.body16Medium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
