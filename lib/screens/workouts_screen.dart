import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../models/workout_history.dart';
import '../services/workout_history_repository.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_confirm_dialog.dart';

final ValueNotifier<bool> workoutRefreshNotifier = ValueNotifier(false);

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  List<WorkoutHistorySession> _sessions = [];
  bool _isLoading = true;

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
      }
    } catch (error) {
      debugPrint('Geçmiş çekme hatası: $error');
      if (mounted) setState(() => _isLoading = false);
    }
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
              '${_selectedKeys.length} seçili',
              style: AppTypography.heading2.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          PopupMenuButton<String>(
            color: Colors.white,
            icon: Icon(Icons.more_vert, color: AppColors.brandTertiary),
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
                    child: Text(
                      'Paylaş (yakında)',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
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
            'Antrenmanlarım',
            style: AppTypography.heading1.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
        PopupMenuButton<String>(
          color: Colors.white,
          icon: Icon(Icons.more_vert, color: AppColors.brandTertiary),
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
                    style: TextStyle(color: AppColors.brandPrimary),
                  ),
                ),
              ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom + 104;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 28),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : RefreshIndicator(
                          color: AppColors.brandPrimary,
                          backgroundColor: Colors.white,
                          onRefresh: _fetch,
                          child:
                              _sessions.isEmpty
                                  ? SingleChildScrollView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(
                                          parent: BouncingScrollPhysics(),
                                        ),
                                    padding: EdgeInsets.fromLTRB(
                                      0,
                                      40,
                                      0,
                                      bottomInset,
                                    ),
                                    child: const _EmptyHistory(),
                                  )
                                  : ListView.separated(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(
                                          parent: BouncingScrollPhysics(),
                                        ),
                                    padding: EdgeInsets.fromLTRB(
                                      0,
                                      0,
                                      0,
                                      bottomInset,
                                    ),
                                    itemCount: _sessions.length,
                                    separatorBuilder:
                                        (_, __) => const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final session = _sessions[index];
                                      final key = _keyOf(session);
                                      final isSelected = _selectedKeys.contains(
                                        key,
                                      );

                                      if (_isSelectionMode) {
                                        return _HistoryCard(
                                          session: session,
                                          isSelectionMode: true,
                                          isSelected: isSelected,
                                          onTap: () => _toggleSelection(key),
                                        );
                                      }

                                      return Dismissible(
                                        key: ValueKey(key),
                                        direction: DismissDirection.endToStart,
                                        confirmDismiss:
                                            (_) =>
                                                _confirmDeleteSession(session),
                                        onDismissed: (_) {
                                          final removedIndex = index;
                                          setState(
                                            () => _sessions.removeAt(
                                              removedIndex,
                                            ),
                                          );
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    '"${session.workoutName}" kaydı silindi',
                                                  ),
                                                  backgroundColor:
                                                      AppColors.brandTertiary,
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  duration: const Duration(
                                                    seconds: 3,
                                                  ),
                                                  action: SnackBarAction(
                                                    label: 'Geri Al',
                                                    textColor: Colors.white,
                                                    onPressed: () {
                                                      setState(
                                                        () => _sessions.insert(
                                                          removedIndex,
                                                          session,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              )
                                              .closed
                                              .then((reason) async {
                                                if (reason ==
                                                    SnackBarClosedReason.action)
                                                  return;
                                                try {
                                                  await WorkoutHistoryRepository.deleteSession(
                                                    session,
                                                  );
                                                } catch (error) {
                                                  debugPrint(
                                                    'Antrenman kaydı silme hatası: $error',
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
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.white,
                                          ),
                                        ),
                                        child: _HistoryCard(
                                          session: session,
                                          isSelectionMode: false,
                                          isSelected: false,
                                          onTap:
                                              () => context.push(
                                                '/workout-history-detail',
                                                extra: session,
                                              ),
                                          onLongPress:
                                              () => _enterSelectionMode(key),
                                        ),
                                      );
                                    },
                                  ),
                        ),
              ),
            ],
          ),
        ),
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
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: AppColors.brandSecondary),
            ),
            child: Icon(Icons.history, size: 40, color: AppColors.brandPrimary),
          ),
          const SizedBox(height: 20),
          Text(
            'Henüz tamamlanmış antrenman yok',
            style: AppTypography.heading2.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bir antrenman tamamladığında burada görünecek.',
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

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat(
      'd MMMM yyyy, HH:mm',
      'tr_TR',
    ).format(session.completedAt);

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
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: AppColors.brandPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
              ],
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
                        color: AppColors.brandPrimary,
                      ),
                    ),
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
