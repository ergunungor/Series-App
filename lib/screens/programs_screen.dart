import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../models/program.dart';
import '../services/program_repository.dart';
import '../widgets/add_program_sheet.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_logo.dart';

class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> {
  List<ActiveProgram> _programs = [];
  bool _isLoading = true;

  // Seçim modu state'i: hangi kartların işaretli olduğunu tutuyoruz.
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

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
      final programs = await ProgramRepository.fetchPrograms(user.id);
      if (mounted) {
        setState(() {
          _programs = programs;
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
      // Son seçili öğe de kaldırılırsa seçim modundan otomatik çık.
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
            icon: Icon(Icons.close, color: AppColors.brandTertiary),
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
            icon: Icon(Icons.more_vert, color: AppColors.brandTertiary),
            onSelected: (value) {
              if (value == 'select_all') _selectAll();
              if (value == 'delete') _deleteSelected();
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'select_all',
                    child: Text('Tümünü Seç'),
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
          icon: Icon(Icons.more_vert, color: AppColors.brandTertiary),
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
                  child: const Text('Seç'),
                ),
              ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _programs.isEmpty
                        ? _EmptyState(
                          onCreate: () async {
                            final created = await context.push<bool>(
                              '/onboarding-survey',
                            );
                            if (created == true) _fetch();
                          },
                        )
                        : ListView.separated(
                          itemCount: _programs.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final program = _programs[index];
                            final isSelected = _selectedIds.contains(
                              program.id,
                            );

                            // Seçim modundayken kaydırarak silmeyi kapatıyoruz
                            // (checkbox ile seçip toplu silmek daha tutarlı;
                            // ikisi bir aradayken kafa karıştırırdı).
                            if (_isSelectionMode) {
                              return _ProgramCard(
                                program: program,
                                isSelectionMode: true,
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
                                final removedIndex = index;
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
                                onTap:
                                    () => context.push(
                                      '/program-detail',
                                      extra: program,
                                    ),
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
              : FloatingActionButton(
                onPressed:
                    () => showAddProgramSheet(
                      context: context,
                      onCreateWithAi: () async {
                        final created = await context.push<bool>(
                          '/onboarding-survey',
                        );
                        if (created == true) _fetch();
                      },
                      onImportProgram: () {},
                    ),
                backgroundColor: AppColors.brandTertiary,
                elevation: 4,
                child: const Icon(Icons.add, color: Colors.white, size: 26),
              ),
    );
  }
}

// yeni:
class _ProgramCard extends StatelessWidget {
  final ActiveProgram program;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ProgramCard({
    required this.program,
    required this.isSelectionMode,
    required this.isSelected,
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
                // Marka logosunu küçük bir daire içinde göstererek kartın
                // "bir program" olduğunu görsel olarak da anlatıyoruz —
                const AppLogo(explicitSize: 56, type: AppLogoType.dark),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      program.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body16Medium.copyWith(
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    if (!isSelectionMode) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Programa git',
                        style: AppTypography.body14Regular.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isSelectionMode)
                Icon(Icons.chevron_right, color: AppColors.textTertiary),
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
