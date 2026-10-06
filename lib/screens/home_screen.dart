import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
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

  /// Bu hafta (Pazartesi başlangıçlı) en az bir kez yapılmış antrenman günleri.
  Set<String> _doneWorkoutIds(ActiveProgram program) {
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
          s.workoutId,
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
                                  _ActiveProgramCard(
                                    program: _activeProgram!,
                                    nextIndex: _nextWorkoutIndex,
                                    doneWorkoutIds: _doneWorkoutIds(
                                      _activeProgram!,
                                    ),
                                    onTap:
                                        () => context.push(
                                          '/program-detail',
                                          extra: _activeProgram,
                                        ),
                                    onSwap: _changeActiveProgram,
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

/// Aktif program kartı: üstte logo karosu, ad, özet ve "Değiştir" hapı; altta
/// programın günleri yatay çipler hâlinde (sıradaki gün kiremit, bu hafta
/// yapılanlar soluk). Karta dokununca program detayı, hapa dokununca program
/// değiştirme açılır.
class _ActiveProgramCard extends StatefulWidget {
  final ActiveProgram program;
  final int nextIndex;
  final Set<String> doneWorkoutIds;
  final VoidCallback onTap;
  final VoidCallback onSwap;

  const _ActiveProgramCard({
    required this.program,
    required this.nextIndex,
    required this.doneWorkoutIds,
    required this.onTap,
    required this.onSwap,
  });

  @override
  State<_ActiveProgramCard> createState() => _ActiveProgramCardState();
}

class _ActiveProgramCardState extends State<_ActiveProgramCard> {
  static const double _radius = 24;
  static const double _pillHeight = 36;
  static const double _touchHeight = 44;
  static const double _chipMaxWidth = 150;

  final GlobalKey _nextChipKey = GlobalKey();
  final ScrollController _chipScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToNextChip();
  }

  @override
  void didUpdateWidget(_ActiveProgramCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Geçmiş sonradan yüklenince sıradaki gün değişebilir.
    if (oldWidget.nextIndex != widget.nextIndex) _scrollToNextChip();
  }

  // Sıradaki gün çipi görünür alanın dışındaysa yatay listeyi kaydırıp getirir.
  // Scrollable.ensureVisible sayfanın dikey kaydırmasını da oynatırdı; bu
  // yüzden yalnızca bu listenin kontrolcüsünü kullanıyoruz.
  void _scrollToNextChip() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _nextChipKey.currentContext?.findRenderObject();
      if (box == null || !mounted || !_chipScroll.hasClients) return;
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport == null) return;
      final target =
          viewport.getOffsetToReveal(box, 0.1, axis: Axis.horizontal).offset;
      _chipScroll.animateTo(
        target.clamp(0.0, _chipScroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _chipScroll.dispose();
    super.dispose();
  }

  String get _summary {
    final days = widget.program.workouts.length;
    final exercises = widget.program.workouts.fold<int>(
      0,
      (sum, w) => sum + w.exercises.length,
    );
    return '$days gün · $exercises hareket';
  }

  @override
  Widget build(BuildContext context) {
    final workouts = widget.program.workouts;
    return PressableScale(
      pressedScale: 0.98,
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _LogoTile(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.program.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body16Medium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _summary,
                        style: AppTypography.body12Regular.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: 'Programı değiştir',
                  button: true,
                  child: PressableScale(
                    pressedScale: 0.94,
                    onTap: widget.onSwap,
                    // Görsel hap 36px, dokunma alanı 44px.
                    child: SizedBox(
                      height: _touchHeight,
                      child: Center(
                        child: Container(
                          height: _pillHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.fillSubtle,
                            borderRadius: BorderRadius.circular(
                              _pillHeight / 2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.swap_horiz_rounded,
                                size: 16,
                                color: AppColors.homeHero,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Değiştir',
                                style: AppTypography.body12Medium.copyWith(
                                  color: AppColors.homeHero,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (workouts.isNotEmpty) ...[
              const SizedBox(height: 14),
              SingleChildScrollView(
                controller: _chipScroll,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    for (var i = 0; i < workouts.length; i++)
                      Padding(
                        padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                        child: _DayChip(
                          key: i == widget.nextIndex ? _nextChipKey : null,
                          name: workouts[i].name,
                          state:
                              i == widget.nextIndex
                                  ? _DayState.next
                                  : widget.doneWorkoutIds.contains(
                                    workouts[i].id,
                                  )
                                  ? _DayState.done
                                  : _DayState.upcoming,
                          maxWidth: _chipMaxWidth,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _DayState { next, done, upcoming }

class _DayChip extends StatelessWidget {
  final String name;
  final _DayState state;
  final double maxWidth;

  const _DayChip({
    super.key,
    required this.name,
    required this.state,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final isNext = state == _DayState.next;
    final isDone = state == _DayState.done;
    final label = isNext ? 'Sıradaki' : (isDone ? 'Yapıldı' : 'Bekliyor');
    return Opacity(
      opacity: isDone ? 0.55 : 1,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isNext ? AppColors.homeHero : AppColors.background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.body12Regular.copyWith(
                fontSize: 10,
                height: 1.2,
                color:
                    isNext
                        ? AppColors.onHeroDark.withValues(alpha: 0.7)
                        : AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body12Medium.copyWith(
                height: 1.25,
                color: isNext ? AppColors.onHeroDark : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
