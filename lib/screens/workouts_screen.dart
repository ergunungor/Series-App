import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../models/workout_history.dart';
import '../services/workout_history_repository.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/reveal.dart';
import '../widgets/detail_hero.dart' show HeroStatusBarScope;
import '../widgets/kiremit_hero_surface.dart';
import '../widgets/screen_title_block.dart';
import '../widgets/section_title.dart';
import '../widgets/workout_insights_section.dart';
import '../widgets/series_wordmark.dart';
import '../widgets/app_bottom_nav.dart';
import 'package:lottie/lottie.dart';

final ValueNotifier<bool> workoutRefreshNotifier = ValueNotifier(false);

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  List<WorkoutHistorySession> _sessions = [];
  bool _isLoading = true;

  // Home/Programlar ile aynı yatay sayfa boşluğu ve giriş ritmi.
  static const double _pagePadding = 16;
  static const double _cardGap = 12;
  static const Duration _revealDuration = Duration(milliseconds: 500);
  static const Duration _revealStagger = Duration(milliseconds: 100);
  static const Duration _heroSwitchDuration = Duration(milliseconds: 350);
  static const int _revealedItems = 5;
  static const int _skeletonCount = 3;

  // İlk içerik gösterildikten sonra kapanır; kaydırınca Reveal tekrar oynamasın.
  bool _isIntroActive = true;
  bool _isIntroTimerArmed = false;

  bool _isSelectionMode = false;
  final Set<String> _selectedKeys = {};

  // Programs ekranında id vardı, burada seans için tek bir "id" yok —
  // workoutId + completedAt'in birleşimini benzersiz anahtar olarak kullanıyoruz.
  String _keyOf(WorkoutHistorySession s) =>
      '${s.workoutId}_${s.completedAt.toIso8601String()}';

  @override
  void initState() {
    super.initState();
    _fetch();
    // 2. TETİKLEYİCİYİ DİNLE
    workoutRefreshNotifier.addListener(_fetch);
  }

  @override
  void dispose() {
    // 3. DİNLEYİCİYİ TEMİZLE
    workoutRefreshNotifier.removeListener(_fetch);
    super.dispose();
  }

  Future<void> _fetch() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final sessions = await WorkoutHistoryRepository.fetchHistory(user.id);
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _isLoading = false;
        });
        _armIntroTimer();
      }
    } catch (error) {
      debugPrint('Geçmiş çekme hatası: $error');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _armIntroTimer() {
    if (_isIntroTimerArmed) return;
    _isIntroTimerArmed = true;
    final steps = _revealedItems + 1 + WorkoutInsightsSection.cardCount;
    Future.delayed(_revealStagger * steps + _revealDuration, () {
      if (mounted) _isIntroActive = false;
    });
  }

  Future<bool> _confirmDeleteSession(WorkoutHistorySession session) async {
    return showAppConfirmDialog(
      context: context,
      title: 'Kaydı Sil',
      message:
          '"${session.workoutName}" antrenman kaydını silmek istediğine emin misin? Bu işlem geri alınamaz.',
      confirmLabel: 'Sil',
      isDestructive: true,
    );
  }

  void _enterSelectionMode(String key) {
    setState(() {
      _isSelectionMode = true;
      _selectedKeys.add(key);
    });
  }

  void _toggleSelection(String key) {
    setState(() {
      if (_selectedKeys.contains(key)) {
        _selectedKeys.remove(key);
      } else {
        _selectedKeys.add(key);
      }
      if (_selectedKeys.isEmpty) _isSelectionMode = false;
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedKeys.clear();
    });
  }

  void _selectAll() {
    setState(() => _selectedKeys.addAll(_sessions.map(_keyOf)));
  }

  Future<void> _deleteSelected() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Kayıtları Sil',
      message:
          '${_selectedKeys.length} antrenman kaydını silmek istediğine emin misin? Bu işlem geri alınamaz.',
      confirmLabel: 'Sil',
      isDestructive: true,
    );
    if (!confirmed) return;

    final sessionsToDelete =
        _sessions.where((s) => _selectedKeys.contains(_keyOf(s))).toList();
    setState(() {
      _sessions.removeWhere((s) => _selectedKeys.contains(_keyOf(s)));
      _isSelectionMode = false;
      _selectedKeys.clear();
    });

    for (final session in sessionsToDelete) {
      try {
        await WorkoutHistoryRepository.deleteSession(session);
      } catch (error) {
        debugPrint('Antrenman kaydı silme hatası: $error');
      }
    }
  }

  // Hero içindeki başlık satırı: normal başlık ya da seçim modu başlığı.
  Widget _buildHeaderRow() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _isSelectionMode ? _buildSelectionHeader() : _buildTitle(),
    );
  }

  Widget _buildSelectionHeader() {
    return SizedBox(
      key: const ValueKey('selection_header'),
      height: ScreenTitleBlock.height,
      child: Row(
        children: [
          _CircleIconButton(
            icon: CupertinoIcons.xmark,
            onTap: _exitSelectionMode,
            onHero: true,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '${_selectedKeys.length} seçili',
              style: AppTypography.heading2.copyWith(color: Colors.white),
            ),
          ),
          _MenuButton(
            onHero: true,
            onSelected: (value) {
              if (value == 'select_all') _selectAll();
              if (value == 'delete') _deleteSelected();
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'select_all',
                    child: Text(
                      'Tümünü Seç',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    enabled: false,
                    child: Text(
                      'Paylaş (yakında)',
                      style: TextStyle(color: AppColors.textTertiary),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Sil',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return ScreenTitleBlock(
      key: const ValueKey('normal_header'),
      eyebrow: 'Geçmiş',
      title: 'Antrenmanlarım',
      titleColor: Colors.white,
      eyebrowColor: Colors.white.withValues(alpha: 0.65),
      trailing: _MenuButton(
        onHero: true,
        onSelected: (value) {
          if (value == 'select' && _sessions.isNotEmpty) {
            setState(() => _isSelectionMode = true);
          }
        },
        itemBuilder:
            (context) => [
              PopupMenuItem(
                value: 'select',
                enabled: _sessions.isNotEmpty,
                child: const Text(
                  'Seç',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ],
      ),
    );
  }

  Widget _buildHero() {
    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - 1),
    );
    final totalSets = _sessions.fold<int>(0, (sum, s) => sum + s.setCount);
    final thisWeek =
        _sessions.where((s) => !s.completedAt.isBefore(weekStart)).length;
    return _HeroStats(
      workouts: _sessions.length,
      sets: totalSets,
      thisWeek: thisWeek,
    );
  }

  Widget _buildSessionItem(int index) {
    final session = _sessions[index];
    final key = _keyOf(session);
    final isSelected = _selectedKeys.contains(key);

    final Widget card;
    if (_isSelectionMode) {
      card = _HistoryCard(
        session: session,
        isSelectionMode: true,
        isSelected: isSelected,
        onTap: () => _toggleSelection(key),
      );
    } else {
      card = Dismissible(
        key: ValueKey(key),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => _confirmDeleteSession(session),
        onDismissed: (_) {
          final removedIndex = index;
          setState(() => _sessions.removeAt(removedIndex));
          ScaffoldMessenger.of(context)
              .showSnackBar(
                SnackBar(
                  content: Text('"${session.workoutName}" kaydı silindi'),
                  backgroundColor: AppColors.workoutsHero,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                  action: SnackBarAction(
                    label: 'Geri Al',
                    textColor: AppColors.accentGold,
                    onPressed: () {
                      setState(() => _sessions.insert(removedIndex, session));
                    },
                  ),
                ),
              )
              .closed
              .then((reason) async {
                if (reason == SnackBarClosedReason.action) return;
                try {
                  await WorkoutHistoryRepository.deleteSession(session);
                } catch (error) {
                  debugPrint('Antrenman kaydı silme hatası: $error');
                }
              });
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(_HistoryCard.radius),
          ),
          child: const Icon(CupertinoIcons.trash, color: Colors.white),
        ),
        child: _HistoryCard(
          session: session,
          isSelectionMode: false,
          isSelected: false,
          onTap: () => context.push('/workout-history-detail', extra: session),
          onLongPress: () => _enterSelectionMode(key),
        ),
      );
    }

    final item = Padding(
      key: ValueKey('item_$key'),
      padding: const EdgeInsets.only(bottom: _cardGap),
      child: card,
    );
    if (!_isIntroActive || index >= _revealedItems) return item;
    return Reveal(
      key: ValueKey('reveal_$key'),
      delay: _revealStagger * (1 + WorkoutInsightsSection.cardCount + index),
      duration: _revealDuration,
      child: item,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        MediaQuery.of(context).padding.bottom + AppBottomNav.clearance;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: HeroStatusBarScope(
        builder:
            (context, heroKey) => RefreshIndicator(
              color: AppColors.workoutsHero,
              backgroundColor: Colors.white,
              // Hero durum çubuğunun arkasına uzandığı için gösterge altından başlar.
              edgeOffset: MediaQuery.paddingOf(context).top,
              onRefresh: _fetch,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: _buildScreenHero(heroKey)),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  if (_isLoading)
                    const SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: _pagePadding),
                      sliver: SliverToBoxAdapter(child: _ListSkeleton()),
                    )
                  else if (_sessions.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyHistory(),
                    )
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _pagePadding,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: WorkoutInsightsSection(
                          sessions: _sessions,
                          animateIntro: _isIntroActive,
                          revealStagger: _revealStagger,
                          revealDuration: _revealDuration,
                        ),
                      ),
                    ),
                    const SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: _pagePadding),
                      sliver: SliverToBoxAdapter(
                        child: SectionTitle(title: 'Geçmiş kayıtlar'),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _pagePadding,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildSessionItem(index),
                          childCount: _sessions.length,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
                  ],
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildScreenHero(GlobalKey heroKey) {
    return KiremitHeroSurface(
      heroKey: heroKey,
      topColor: AppColors.workoutsHero,
      bottomColor: AppColors.workoutsHeroDeep,
      glowColor: AppColors.workoutsGlow,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _pagePadding,
          MediaQuery.paddingOf(context).top + 12,
          _pagePadding,
          28,
        ),
        child: Column(
          children: [
            SeriesWordmark(color: Colors.white.withValues(alpha: 0.9)),
            // Diğer sekmelerle aynı başlık konumu (wordmark + 16 boşluk).
            const SizedBox(height: 16),
            _buildHeaderRow(),
            if (_isLoading || _sessions.isNotEmpty) ...[
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: _heroSwitchDuration,
                child: _isLoading ? const _HeroStatsSkeleton() : _buildHero(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration(double radius) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ],
);

/// 44px dairesel ikon butonu (Programlar'daki `_GlassIconButton` ile aynı ölçü).
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  /// Koyu hero üzerinde yarı saydam beyaz daire ve beyaz ikon.
  final bool onHero;

  const _CircleIconButton({
    required this.icon,
    this.onTap,
    this.onHero = false,
  });

  static const double size = 44;
  static const double _pressedScale = 0.92;

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color:
            onHero
                ? Colors.white.withValues(alpha: 0.14)
                : AppColors.fillSubtle,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 20,
        color: onHero ? Colors.white : AppColors.workoutsHero,
      ),
    );
    if (onTap == null) return circle;
    return PressableScale(
      pressedScale: _pressedScale,
      onTap: onTap,
      child: circle,
    );
  }
}

/// Üç nokta menüsü: aynı daire buton görünümü, ripple yok.
class _MenuButton extends StatelessWidget {
  final PopupMenuItemSelected<String> onSelected;
  final PopupMenuItemBuilder<String> itemBuilder;
  final bool onHero;

  const _MenuButton({
    required this.onSelected,
    required this.itemBuilder,
    this.onHero = false,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onSelected: onSelected,
        itemBuilder: itemBuilder,
        child: _CircleIconButton(icon: CupertinoIcons.ellipsis, onHero: onHero),
      ),
    );
  }
}

/// Hero içindeki üç rakam: antrenman, set ve bu hafta (altın).
class _HeroStats extends StatelessWidget {
  final int workouts;
  final int sets;
  final int thisWeek;

  const _HeroStats({
    required this.workouts,
    required this.sets,
    required this.thisWeek,
  });

  static const double height = 64;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('hero_stats'),
      height: height,
      child: Row(
        children: [
          Expanded(child: _Stat(value: workouts, label: 'Antrenman')),
          const _StatDivider(),
          Expanded(child: _Stat(value: sets, label: 'Set')),
          const _StatDivider(),
          Expanded(
            child: _Stat(
              value: thisWeek,
              label: 'Bu hafta',
              valueColor: AppColors.accentGold,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final int value;
  final String label;
  final Color valueColor;

  const _Stat({
    required this.value,
    required this.label,
    this.valueColor = AppColors.onHeroDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$value',
          style: AppTypography.heading1.copyWith(
            color: valueColor,
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.body12Medium.copyWith(
            color: AppColors.onHeroDark.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: AppColors.onHeroDark.withValues(alpha: 0.14),
    );
  }
}

/// Hero içindeki rakamlar yüklenirken: koyu zeminde silik shimmer çubukları.
class _HeroStatsSkeleton extends StatelessWidget {
  const _HeroStatsSkeleton();

  Widget _column() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 44,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      const SizedBox(height: 8),
      Container(
        width: 62,
        height: 10,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      key: const ValueKey('hero_stats_skeleton'),
      baseColor: Colors.white.withValues(alpha: 0.1),
      highlightColor: Colors.white.withValues(alpha: 0.24),
      child: SizedBox(
        height: _HeroStats.height,
        child: Row(
          children: [
            Expanded(child: _column()),
            const SizedBox(width: 1),
            Expanded(child: _column()),
            const SizedBox(width: 1),
            Expanded(child: _column()),
          ],
        ),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.borderSubtle,
      highlightColor: Colors.white,
      child: Column(
        children: [
          for (var i = 0; i < _WorkoutsScreenState._skeletonCount; i++)
            Container(
              height: _HistoryCard.height,
              margin: const EdgeInsets.only(
                bottom: _WorkoutsScreenState._cardGap,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_HistoryCard.radius),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Lottie.asset(
            'assets/gifs/no_result_calender.json',
            width: 160,
            height: 160,
            repeat: true,
          ),
          const SizedBox(height: 20),
          Text(
            'Henüz tamamlanmış antrenman yok',
            textAlign: TextAlign.center,
            style: AppTypography.heading2.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bir antrenman tamamladığında\nburada görünecek.',
            textAlign: TextAlign.center,
            style: AppTypography.body14Regular.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final WorkoutHistorySession session;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _HistoryCard({
    required this.session,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
  });

  static const double radius = 20;
  static const double height = 94;
  static const double _selectedBorderWidth = 2;

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat(
      'd MMMM yyyy, HH:mm',
      'tr_TR',
    ).format(session.completedAt);

    return PressableScale(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: _cardDecoration(radius),
        // Seçim çerçevesi layout'u kaydırmasın diye hep var, seçili değilken şeffaf.
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: isSelected ? AppColors.workoutsHero : Colors.transparent,
            width: _selectedBorderWidth,
          ),
        ),
        child: Row(
          children: [
            if (isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  isSelected
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.circle,
                  color:
                      isSelected
                          ? AppColors.workoutsHero
                          : AppColors.textTertiary,
                ),
              )
            else
              Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(right: 12),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.fillSubtle,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.checkmark_alt_circle_fill,
                  color: AppColors.success,
                  size: 22,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.workoutName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body16Medium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateLabel,
                    style: AppTypography.body12Regular.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${session.exerciseCount} egzersiz · ${session.setCount} set',
                    style: AppTypography.body12Medium.copyWith(
                      color: AppColors.workoutsAccent,
                    ),
                  ),
                ],
              ),
            ),
            if (!isSelectionMode)
              const Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}
