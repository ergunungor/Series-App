import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../widgets/series_wordmark.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../models/program.dart';
import '../services/program_repository.dart';
import '../widgets/add_program_sheet.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_logo.dart';
import '../widgets/pressable_scale.dart';

class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> {
  // Home ile aynı yatay sayfa boşluğu; sekmeler arası geçişte içerik kaymasın.
  static const double _pagePadding = 16;
  // AppBottomNav'ın kapladığı alan: 86 yükseklik + 16 alt marj. Nav dosyasına
  // dokunmadığımız için burada tutuluyor; nav ölçüleri değişirse güncellenmeli.
  static const double _navBarClearance = 102;
  static const double _fabGap = 16;

  List<ActiveProgram> _programs = [];
  bool _isLoading = true;
  String? _activeProgramId;

  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _fetch();
    programRefreshNotifier.addListener(_fetch);
    generationStateNotifier.addListener(_onGenerationStateChanged);
  }

  @override
  void dispose() {
    programRefreshNotifier.removeListener(_fetch);
    generationStateNotifier.removeListener(_onGenerationStateChanged);
    super.dispose();
  }

  void _onGenerationStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _fetch() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final programs = await ProgramRepository.fetchPrograms(user.id);
      final activeId = await ProgramRepository.fetchActiveProgramId(user.id);
      if (mounted) {
        setState(() {
          _programs = programs;
          _activeProgramId = activeId;
          _isLoading = false;
        });
      }
    } catch (error) {
      debugPrint('Program çekme hatası: $error');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _confirmDeleteProgram(ActiveProgram program) async {
    return showAppConfirmDialog(
      context: context,
      title: 'Programı Sil',
      message:
          '"${program.name}" programını silmek istediğine emin misin? Bu işlem geri alınamaz.',
      confirmLabel: 'Sil',
      isDestructive: true,
    );
  }

  void _enterSelectionMode() {
    setState(() => _isSelectionMode = true);
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      if (_selectedIds.isEmpty) _isSelectionMode = false;
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll() {
    setState(() => _selectedIds.addAll(_programs.map((p) => p.id)));
  }

  Future<void> _deleteSelected() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Programları Sil',
      message:
          '${_selectedIds.length} programı silmek istediğine emin misin? Bu işlem geri alınamaz.',
      confirmLabel: 'Sil',
      isDestructive: true,
    );
    if (!confirmed) return;

    final idsToDelete = Set<String>.from(_selectedIds);
    setState(() {
      _programs.removeWhere((p) => idsToDelete.contains(p.id));
      _isSelectionMode = false;
      _selectedIds.clear();
    });

    for (final id in idsToDelete) {
      try {
        await ProgramRepository.deleteProgram(id);
      } catch (error) {
        debugPrint('Program silme hatası ($id): $error');
      }
    }
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_pagePadding, 16, _pagePadding, 16),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child:
              _isSelectionMode
                  ? Row(
                    key: const ValueKey('selection_header'),
                    children: [
                      _GlassIconButton(
                        icon: CupertinoIcons.xmark,
                        onTap: _exitSelectionMode,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          '${_selectedIds.length} Seçili',
                          style: AppTypography.heading2.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      _GlassIconButton(
                        icon: CupertinoIcons.check_mark_circled,
                        onTap: _selectAll,
                      ),
                      const SizedBox(width: 12),
                      _GlassIconButton(
                        icon: CupertinoIcons.trash,
                        color: CupertinoColors.destructiveRed,
                        onTap: _selectedIds.isEmpty ? () {} : _deleteSelected,
                      ),
                    ],
                  )
                  : Row(
                    key: const ValueKey('normal_header'),
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kütüphane',
                              style: AppTypography.body18Medium.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Programlar',
                              style: AppTypography.heading1.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_programs.isNotEmpty)
                        _GlassIconButton(
                          icon: CupertinoIcons.check_mark_circled,
                          onTap: _enterSelectionMode,
                        ),
                    ],
                  ),
        ),
      ),
    );
  }

  Widget _buildGenerationStatus() {
    final status = generationStateNotifier.value;
    if (status == GenerationStatus.idle) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _pagePadding,
          vertical: 8,
        ),
        child:
            status == GenerationStatus.generating
                ? _buildPremiumShimmer()
                : _buildPremiumError(),
      ),
    );
  }

  Widget _buildPremiumShimmer() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Shimmer.fromColors(
        baseColor: AppColors.goldTint,
        highlightColor: Colors.white,
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 120,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumError() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.fillSubtle,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              color: CupertinoColors.destructiveRed,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Oluşturulamadı',
                  style: AppTypography.body16Medium.copyWith(
                    color: AppColors.espresso,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Bağlantı koptu veya zaman aşımı.',
                  style: AppTypography.body14Regular.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              if (retryGenerationCallback != null) retryGenerationCallback!();
            },
            icon: const Icon(
              CupertinoIcons.refresh_thick,
              color: AppColors.espresso,
              size: 20,
            ),
          ),
          IconButton(
            onPressed:
                () => generationStateNotifier.value = GenerationStatus.idle,
            icon: const Icon(
              CupertinoIcons.xmark,
              color: AppColors.textTertiary,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeProgram =
        _programs.where((p) => p.id == _activeProgramId).firstOrNull;
    final otherPrograms =
        _programs.where((p) => p.id != _activeProgramId).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              const SliverSafeArea(
                sliver: SliverToBoxAdapter(child: SizedBox(height: 12)),
                bottom: false,
              ),
              const SliverToBoxAdapter(child: SeriesWordmark()),
              _buildHeader(),
              _buildGenerationStatus(),

              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CupertinoActivityIndicator(radius: 16)),
                )
              else if (_programs.isEmpty &&
                  generationStateNotifier.value == GenerationStatus.idle)
                SliverFillRemaining(
                  child: _PremiumEmptyState(
                    onCreate: () => context.push<bool>('/onboarding-survey'),
                  ),
                )
              else ...[
                // Hero Active Program
                if (activeProgram != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _pagePadding,
                        vertical: 16,
                      ),
                      child: _DismissibleWrapper(
                        program: activeProgram,
                        isSelectionMode: _isSelectionMode,
                        onDeleteConfirmed: () async {
                          final originalIndex = _programs.indexOf(
                            activeProgram,
                          );
                          setState(() => _programs.removeAt(originalIndex));
                          try {
                            await ProgramRepository.deleteProgram(
                              activeProgram.id,
                            );
                          } catch (e) {
                            debugPrint(e.toString());
                          }
                        },
                        child: _FeaturedActiveCard(
                          program: activeProgram,
                          isSelected: _selectedIds.contains(activeProgram.id),
                          isSelectionMode: _isSelectionMode,
                          onTap: () {
                            if (_isSelectionMode) {
                              _toggleSelection(activeProgram.id);
                            } else {
                              context
                                  .push<bool>(
                                    '/program-detail',
                                    extra: activeProgram,
                                  )
                                  .then((v) {
                                    if (v == true) _fetch();
                                  });
                            }
                          },
                          onLongPress: _enterSelectionMode,
                        ),
                      ),
                    ),
                  ),

                // Grid Other Programs
                if (otherPrograms.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _pagePadding,
                    ),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.85,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final program = otherPrograms[index];
                        return _DismissibleWrapper(
                          program: program,
                          isSelectionMode: _isSelectionMode,
                          onDeleteConfirmed: () async {
                            final originalIndex = _programs.indexOf(program);
                            setState(() => _programs.removeAt(originalIndex));
                            try {
                              await ProgramRepository.deleteProgram(program.id);
                            } catch (e) {
                              debugPrint(e.toString());
                            }
                          },
                          child: _GridProgramCard(
                            program: program,
                            isSelected: _selectedIds.contains(program.id),
                            isSelectionMode: _isSelectionMode,
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleSelection(program.id);
                              } else {
                                context
                                    .push<bool>(
                                      '/program-detail',
                                      extra: program,
                                    )
                                    .then((v) {
                                      if (v == true) _fetch();
                                    });
                              }
                            },
                            onLongPress: _enterSelectionMode,
                          ),
                        );
                      }, childCount: otherPrograms.length),
                    ),
                  ),

                // Bottom padding to avoid FAB overlap
                SliverToBoxAdapter(
                  child: SizedBox(
                    height:
                        MediaQuery.paddingOf(context).bottom +
                        _navBarClearance +
                        _LiquidGlassFab.height +
                        _fabGap * 2,
                  ),
                ),
              ],
            ],
          ),

          if (!_isSelectionMode)
            Positioned(
              bottom:
                  MediaQuery.paddingOf(context).bottom +
                  _navBarClearance +
                  _fabGap,
              left: 0,
              right: 0,
              child: Center(
                child: _LiquidGlassFab(
                  onTap:
                      () => showAddProgramSheet(
                        context: context,
                        onCreateWithAi: () async {
                          await context.push<bool>('/onboarding-survey');
                        },
                        onImportProgram: () async {
                          final created = await context.push<bool>(
                            '/import-program',
                          );
                          if (created == true) _fetch();
                        },
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeaturedActiveCard extends StatelessWidget {
  final ActiveProgram program;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FeaturedActiveCard({
    required this.program,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  static const double _radius = 24;
  static const double _padding = 24;
  static const double _height = 220;

  int get _exerciseCount =>
      program.workouts.fold(0, (sum, w) => sum + w.exercises.length);

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: _height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.heroDarkStart, AppColors.heroDarkEnd],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.heroDarkStart.withValues(alpha: 0.30),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -32,
              bottom: -32,
              child: Opacity(
                opacity: 0.06,
                child: const AppLogo(
                  explicitSize: 200,
                  type: AppLogoType.light,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(_padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold.withValues(alpha: 0.16),
                      border: Border.all(
                        color: AppColors.accentGold.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.flame_fill,
                          color: AppColors.accentGold,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AKTİF PROGRAM',
                          style: AppTypography.body12Medium.copyWith(
                            color: AppColors.accentGold,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    program.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.heading2.copyWith(
                      color: AppColors.onHeroDark,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${program.workouts.length} gün · $_exerciseCount hareket',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body14Regular.copyWith(
                            color: AppColors.onHeroDark.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.accentGold,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.arrow_up_right,
                          color: AppColors.heroDarkStart,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isSelectionMode)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(
                      alpha: isSelected ? 0.4 : 0.1,
                    ),
                    borderRadius: BorderRadius.circular(_radius),
                  ),
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.all(_padding),
                  child: Icon(
                    isSelected
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.circle,
                    color: isSelected ? AppColors.accentGold : Colors.white,
                    size: 28,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GridProgramCard extends StatelessWidget {
  final ActiveProgram program;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _GridProgramCard({
    required this.program,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  static const double _radius = 24;
  static const double _padding = 20;
  static const double _arrowSize = 28;
  static const Duration _stateDuration = Duration(milliseconds: 200);

  int get _exerciseCount =>
      program.workouts.fold(0, (sum, w) => sum + w.exercises.length);

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: _stateDuration,
        curve: Curves.easeOut,
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
        // Seçim çerçevesi layout'u etkilemesin diye foreground'da çiziliyor.
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(
            color: isSelected ? AppColors.goldDeep : Colors.transparent,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(_padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${program.workouts.length}',
                        style: AppTypography.heading1.copyWith(
                          color: AppColors.espresso,
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                          height: 1,
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'gün',
                        style: AppTypography.body14Medium.copyWith(
                          color: AppColors.goldDeep,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    program.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body16Medium.copyWith(
                      color: AppColors.espresso,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$_exerciseCount hareket',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body14Regular.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                      Container(
                        width: _arrowSize,
                        height: _arrowSize,
                        decoration: const BoxDecoration(
                          color: AppColors.goldTint,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.arrow_right,
                          color: AppColors.goldDeep,
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: _stateDuration,
                  opacity: isSelectionMode ? 1 : 0,
                  child: Icon(
                    isSelected
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.circle,
                    color:
                        isSelected
                            ? AppColors.goldDeep
                            : AppColors.textTertiary,
                    size: 26,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumEmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _PremiumEmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.goldTint,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                CupertinoIcons.square_stack_3d_up_slash,
                size: 40,
                color: AppColors.goldDeep,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Program Yok',
              style: AppTypography.heading2.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Antrenman kütüphanen şu an boş. Alttaki butonu kullanarak kendine özel bir program oluştur veya hazır bir program içe aktar.',
              textAlign: TextAlign.center,
              style: AppTypography.body16Regular.copyWith(
                color: AppColors.textTertiary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiquidGlassFab extends StatelessWidget {
  final VoidCallback onTap;
  const _LiquidGlassFab({required this.onTap});

  static const double height = 52;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: AppColors.accentGold,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.goldDeep.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.add, color: AppColors.espresso, size: 20),
            const SizedBox(width: 8),
            Text(
              'Program Ekle',
              style: AppTypography.body16Medium.copyWith(
                color: AppColors.espresso,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DismissibleWrapper extends StatelessWidget {
  final ActiveProgram program;
  final bool isSelectionMode;
  final Widget child;
  final VoidCallback onDeleteConfirmed;

  const _DismissibleWrapper({
    required this.program,
    required this.isSelectionMode,
    required this.child,
    required this.onDeleteConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(program.id),
      direction: DismissDirection.endToStart,
      confirmDismiss:
          isSelectionMode
              ? (_) async => false
              : (_) async {
                return await showAppConfirmDialog(
                  context: context,
                  title: 'Programı Sil',
                  message:
                      '"${program.name}" programını silmek istediğine emin misin? Bu işlem geri alınamaz.',
                  confirmLabel: 'Sil',
                  isDestructive: true,
                );
              },
      onDismissed: (_) => onDeleteConfirmed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        decoration: BoxDecoration(
          color: CupertinoColors.destructiveRed,
          borderRadius: BorderRadius.circular(24), // Hero ve Grid'e uyan radius
        ),
        child: const Icon(CupertinoIcons.trash, color: Colors.white, size: 28),
      ),
      child: child,
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _GlassIconButton({required this.icon, required this.onTap, this.color});

  static const double _size = 44;
  static const double _pressedScale = 0.92;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: _pressedScale,
      onTap: onTap,
      child: Container(
        width: _size,
        height: _size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.fillSubtle,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: color ?? AppColors.brandTertiary),
      ),
    );
  }
}
