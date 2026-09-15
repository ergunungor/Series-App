import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart'; // YENİ EKLENDİ
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../models/program.dart';
import '../services/program_repository.dart';
import '../widgets/add_program_sheet.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_logo.dart';
import '../widgets/active_badge.dart';
import 'package:lottie/lottie.dart';

class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> {
  List<ActiveProgram> _programs = [];
  bool _isLoading = true;
  String? _activeProgramId;

  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  // YENİ: Arka planda program oluşturulurken listeye shimmer eklemek için
  bool _isCreatingNewProgram = false;

  @override
  void initState() {
    super.initState();
    _fetch();
    programRefreshNotifier.addListener(_fetch);
  }

  @override
  void dispose() {
    programRefreshNotifier.removeListener(_fetch);
    super.dispose();
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
          _isCreatingNewProgram = false; // Veri gelince shimmer'ı kapat
        });
      }
    } catch (error) {
      debugPrint('Program çekme hatası: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCreatingNewProgram = false;
        });
      }
    }
  }

  // YENİ: Dışarıdan veya anketten dönerken arka plan işlemini başlatmak için
  void setCreatingState(bool isCreating) {
    setState(() {
      _isCreatingNewProgram = isCreating;
    });
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

  void _enterSelectionMode(String id) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(id);
    });
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
    if (_isSelectionMode) {
      return Row(
        children: [
          IconButton(
            onPressed: _exitSelectionMode,
            icon: const Icon(Icons.close, color: AppColors.brandTertiary),
          ),
          Expanded(
            child: Text(
              '${_selectedIds.length} seçili',
              style: AppTypography.heading2.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          PopupMenuButton<String>(
            color: Colors.white,
            icon: const Icon(Icons.more_vert, color: AppColors.brandTertiary),
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
                      style: TextStyle(color: AppColors.brandPrimary),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    enabled: false,
                    child: Text('Paylaş (yakında)'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Sil', style: TextStyle(color: Colors.red)),
                  ),
                ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            'Programlarım',
            style: AppTypography.heading1.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
        PopupMenuButton<String>(
          color: Colors.white,
          icon: const Icon(Icons.more_vert, color: AppColors.brandTertiary),
          onSelected: (value) {
            if (value == 'select' && _programs.isNotEmpty) {
              setState(() => _isSelectionMode = true);
            }
          },
          itemBuilder:
              (context) => [
                PopupMenuItem(
                  value: 'select',
                  enabled: _programs.isNotEmpty,
                  child: const Text(
                    'Seç',
                    style: TextStyle(color: AppColors.brandPrimary),
                  ),
                ),
              ],
        ),
      ],
    );
  }

  // YENİ: İçi pırıl pırıl parlayan gerçek iskelet (Skeleton) kart tasarımı
  Widget _buildProgramShimmerCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brandSecondary),
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.white,
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 100,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom + 120;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : (_programs.isEmpty && !_isCreatingNewProgram)
                        ? _EmptyState(
                          onCreate: () async {
                            final created = await context.push<bool>(
                              '/onboarding-survey',
                            );
                            if (created == true) _fetch();
                          },
                        )
                        : ListView.separated(
                          padding: EdgeInsets.fromLTRB(0, 0, 0, bottomInset),
                          physics: const BouncingScrollPhysics(),
                          itemCount:
                              _programs.length +
                              (_isCreatingNewProgram ? 1 : 0),
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            // Shimmer'ı en üste bas
                            if (_isCreatingNewProgram && index == 0) {
                              return _buildProgramShimmerCard();
                            }

                            // Gerçek listeyi Shimmer varsa 1 kaydırarak çiz
                            final actualIndex =
                                _isCreatingNewProgram ? index - 1 : index;
                            final program = _programs[actualIndex];
                            final isSelected = _selectedIds.contains(
                              program.id,
                            );

                            if (_isSelectionMode) {
                              return _ProgramCard(
                                program: program,
                                isSelectionMode: true,
                                isActive: program.id == _activeProgramId,
                                isSelected: isSelected,
                                onTap: () => _toggleSelection(program.id),
                              );
                            }

                            return Dismissible(
                              key: ValueKey(program.id),
                              direction: DismissDirection.endToStart,
                              confirmDismiss:
                                  (_) => _confirmDeleteProgram(program),
                              onDismissed: (_) {
                                final removedIndex = actualIndex;
                                setState(
                                  () => _programs.removeAt(removedIndex),
                                );
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '"${program.name}" silindi',
                                        ),
                                        backgroundColor:
                                            AppColors.brandTertiary,
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 3),
                                        action: SnackBarAction(
                                          label: 'Geri Al',
                                          textColor: Colors.white,
                                          onPressed: () {
                                            setState(
                                              () => _programs.insert(
                                                removedIndex,
                                                program,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    )
                                    .closed
                                    .then((reason) async {
                                      if (reason == SnackBarClosedReason.action)
                                        return;
                                      try {
                                        await ProgramRepository.deleteProgram(
                                          program.id,
                                        );
                                      } catch (error) {
                                        debugPrint(
                                          'Program silme hatası: $error',
                                        );
                                      }
                                    });
                              },
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                ),
                              ),
                              child: _ProgramCard(
                                program: program,
                                isSelectionMode: false,
                                isSelected: false,
                                isActive: program.id == _activeProgramId,
                                onTap: () async {
                                  final result = await context.push<bool>(
                                    '/program-detail',
                                    extra: program,
                                  );
                                  if (result == true) _fetch();
                                },
                                onLongPress:
                                    () => _enterSelectionMode(program.id),
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton:
          _isSelectionMode
              ? null
              : Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 95,
                ),
                child: FloatingActionButton(
                  onPressed:
                      () => showAddProgramSheet(
                        context: context,
                        onCreateWithAi: () async {
                          final created = await context.push<bool>(
                            '/onboarding-survey',
                          );
                          if (created == true) {
                            setCreatingState(true);
                          }
                        },
                        onImportProgram: () async {
                          final created = await context.push<bool>(
                            '/import-program',
                          );
                          if (created == true) _fetch();
                        },
                      ),
                  backgroundColor: AppColors.brandTertiary,
                  elevation: 4,
                  child: const Icon(Icons.add, color: Colors.white, size: 26),
                ),
              ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final ActiveProgram program;
  final bool isSelectionMode;
  final bool isSelected;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ProgramCard({
    required this.program,
    required this.isSelectionMode,
    required this.isSelected,
    required this.isActive,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  isSelected
                      ? AppColors.brandPrimary
                      : AppColors.brandSecondary,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              if (isSelectionMode) ...[
                Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color:
                      isSelected
                          ? AppColors.brandPrimary
                          : AppColors.textTertiary,
                ),
                const SizedBox(width: 12),
              ] else ...[
                const AppLogo(explicitSize: 56, type: AppLogoType.dark),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            program.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body16Medium.copyWith(
                              color: AppColors.brandPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (!isSelectionMode) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Programa git',
                            style: AppTypography.body14Regular.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 8),
                            const ActiveBadge(),
                          ],
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!isSelectionMode)
                const Icon(Icons.chevron_right, color: AppColors.textTertiary),
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
          Lottie.asset(
            'assets/gifs/ghosty.json',
            width: 160,
            height: 160,
            repeat: true,
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
            'Sağ alttaki + butonuyla sana özel\nbir antrenman programı oluştur.',
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
