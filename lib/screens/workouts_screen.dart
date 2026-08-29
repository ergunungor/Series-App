import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_top_bar.dart';
import '../models/workout_history.dart';
import '../services/workout_history_repository.dart';
import '../widgets/app_confirm_dialog.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  List<WorkoutHistorySession> _sessions = [];
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
                        : _sessions.isEmpty
                        ? const _EmptyHistory()
                        // yeni:
                        : ListView.separated(
                          itemCount: _sessions.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final session = _sessions[index];
                            return Dismissible(
                              // key: completedAt + workoutId, çünkü aynı
                              // antrenmanın birden fazla geçmiş kaydı olabilir
                              // (aynı isim, farklı tarih) — sadece workoutId
                              // yeterli olmazdı, çakışma yaratırdı.
                              key: ValueKey(
                                '${session.workoutId}_${session.completedAt.toIso8601String()}',
                              ),
                              direction: DismissDirection.endToStart,
                              confirmDismiss:
                                  (_) => _confirmDeleteSession(session),
                              onDismissed: (_) {
                                final removedIndex = index;
                                setState(
                                  () => _sessions.removeAt(removedIndex),
                                );

                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '"${session.workoutName}" kaydı silindi',
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
                                      if (reason == SnackBarClosedReason.action)
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
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                ),
                              ),
                              child: _HistoryCard(
                                session: session,
                                onTap:
                                    () => context.push(
                                      '/workout-history-detail',
                                      extra: session,
                                    ),
                              ),
                            );
                          },
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
  final VoidCallback onTap;

  const _HistoryCard({required this.session, required this.onTap});

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
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.brandSecondary),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
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
              Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
