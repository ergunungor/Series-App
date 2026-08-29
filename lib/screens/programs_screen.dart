import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../models/program.dart';
import '../services/program_repository.dart';
import '../widgets/add_program_sheet.dart';
import '../widgets/app_confirm_dialog.dart';

class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> {
  List<ActiveProgram> _programs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  // yeni:
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

  // Kaydırma onaylandığında çağrılır: önce kullanıcıya emin misin diye sorar,
  // "evet" derse true döner (Dismissible bu true'ya göre kartı ekrandan
  // kaldırır), "hayır" derse false döner (kart geri yerine kayar, hiçbir
  // şey silinmez).
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // yeni (standart FAB):
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Programlarım',
                style: AppTypography.heading1.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _programs.isEmpty
                        ? _EmptyState(
                          // ESKİ: onCreate: () => context.push('/onboarding-survey'),
                          // DÜZELTME:
                          onCreate: () async {
                            final created = await context.push<bool>(
                              '/onboarding-survey',
                            );
                            if (created == true) _fetch();
                          },
                        )
                        // yeni:
                        : ListView.separated(
                          itemCount: _programs.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final program = _programs[index];
                            return Dismissible(
                              // key: her item'ı benzersiz tanımlıyor, Flutter
                              // silme animasyonunu doğru öğeye uygulayabilsin
                              // diye. program.id kullanmak, listede sıralama
                              // değişse bile doğru kartı takip etmesini sağlar.
                              key: ValueKey(program.id),
                              direction: DismissDirection.endToStart,
                              confirmDismiss:
                                  (_) => _confirmDeleteProgram(program),
                              // yeni:
                              onDismissed: (_) {
                                final removedIndex = index;
                                setState(
                                  () => _programs.removeAt(removedIndex),
                                );

                                // showSnackBar bir controller döner; onun .closed
                                // future'ı SnackBar kapandığında, "hangi sebeple
                                // kapandığını" (action/timeout/swipe) veriyor.
                                // Kullanıcı "Geri Al"a bastıysa reason == action
                                // oluyor — o zaman gerçek silme hiç yapılmıyor.
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
                                      // Süre doldu, geri alınmadı — şimdi gerçekten sil.
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
                                onTap:
                                    () => context.push(
                                      '/program-detail',
                                      extra: program,
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
      // yeni:
      floatingActionButton: FloatingActionButton(
        onPressed:
            () => showAddProgramSheet(
              context: context,
              onCreateWithAi: () async {
                final created = await context.push<bool>('/onboarding-survey');
                if (created == true)
                  _fetch(); // Anket bittiğinde çalışan _fetch() fonksiyonunu tetikler
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

class _ProgramCard extends StatelessWidget {
  final ActiveProgram program;
  final VoidCallback onTap;

  const _ProgramCard({required this.program, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.brandSecondary),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      program.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.heading3.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (program.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        program.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body14Regular.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      '${program.workouts.length} Antrenman Günü',
                      style: AppTypography.body12Medium.copyWith(
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddProgramFab extends StatelessWidget {
  final VoidCallback onTap;

  const _AddProgramFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandTertiary,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.3),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Icon(Icons.add, color: Colors.white, size: 26),
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
