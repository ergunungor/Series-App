import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../models/program.dart';
import '../services/program_service.dart';
import '../services/program_repository.dart';
import '../widgets/app_button.dart';

class ProgramDetailScreen extends StatefulWidget {
  final ActiveProgram program;

  const ProgramDetailScreen({super.key, required this.program});

  @override
  State<ProgramDetailScreen> createState() => _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends State<ProgramDetailScreen> {
  bool _isLoading = false;

  // --- LİMİT KONTROL METOTLARI ---
  Future<bool> _canUseAI(String userId) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final response =
        await Supabase.instance.client
            .from('profiles')
            .select('daily_ai_count, last_ai_date')
            .eq('id', userId)
            .single();

    int count = response['daily_ai_count'] as int? ?? 0;
    String? lastDate = response['last_ai_date'] as String?;
    if (lastDate != today) count = 0;

    return count < 5;
  }

  Future<void> _consumeAICredit(String userId) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final response =
        await Supabase.instance.client
            .from('profiles')
            .select('daily_ai_count, last_ai_date')
            .eq('id', userId)
            .single();

    int count = response['daily_ai_count'] as int? ?? 0;
    String? lastDate = response['last_ai_date'] as String?;
    if (lastDate != today) count = 0;

    await Supabase.instance.client
        .from('profiles')
        .update({'daily_ai_count': count + 1, 'last_ai_date': today})
        .eq('id', userId);
  }

  // --- PROGRAM JSON ÇEVİRİCİ ---
  Map<String, dynamic> _programToJson(ActiveProgram p) {
    return {
      "program_name": p.name,
      "description": p.description,
      "workouts":
          p.workouts
              .map(
                (w) => {
                  "day_number": w.dayNumber,
                  "name": w.name,
                  "estimated_duration_min": w.estimatedDurationMin,
                  "exercises":
                      w.exercises
                          .map(
                            (e) => {
                              "id": e.id,
                              "name": e.name,
                              "sets": e.sets,
                              "reps": e.reps,
                              "duration_seconds": e.durationSeconds,
                              "rest_seconds": e.restSeconds,
                              "instructions": e.instructions,
                              "notes": e.notes,
                            },
                          )
                          .toList(),
                },
              )
              .toList(),
    };
  }

  // --- YAPAY ZEKA TETİKLEYİCİSİ ---
  Future<void> _handleRevise(String prompt) async {
    if (prompt.trim().isEmpty) return;
    context.pop(); // Alt pencereyi kapat

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final hasCredit = await _canUseAI(user.id);
      if (!hasCredit) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Bugünlük yapay zeka limitine (5/5) ulaştın. Lütfen yarın tekrar dene.',
              ),
            ),
          );
        }
        return;
      }

      // 1. AI'dan yeni programı iste
      final reviseResponse = await ProgramService.reviseProgram(
        user.id,
        _programToJson(widget.program),
        prompt,
      );
      final newData = reviseResponse['data'];

      // 2. Yeni programı DB'ye kaydet
      final newProgramId = await ProgramService.saveProgram(user.id, newData);

      // 3. Eski programı sil ve yenisini aktif yap
      await ProgramRepository.deleteProgram(widget.program.id);
      await ProgramRepository.setActiveProgram(user.id, newProgramId);

      // 4. Limiti düşür
      await _consumeAICredit(user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Programın başarıyla güncellendi!')),
        );

        // YENİ: Listeyi yenilemesi için geriye "true" göndererek çıkıyoruz
        if (context.canPop()) {
          context.pop(true);
        }
      }
    } catch (e) {
      debugPrint('Revize Hatası: $e');
      if (mounted) {
        // "Exception: " ön ekini temizleyerek sadece asıl mesajı alıyoruz
        final errorMessage = e.toString().replaceAll('Exception: ', '');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor:
                AppColors
                    .brandPrimary, // Hata için istersen kırmızı (Colors.red) da yapabilirsin
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- DÜZENLEME PENCERESİ ---
  void _showReviseSheet() {
    final promptController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 24,
            left: 16,
            right: 16,
            bottom:
                MediaQuery.of(ctx).viewInsets.bottom +
                24, // Klavye açıldığında yukarı kayması için
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'AI ile Şekillendir',
                style: AppTypography.heading2.copyWith(
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Antrenmanında neleri değiştirmek istersin? (Örn: Süreyi kısalt, bacak hareketlerini çıkar)',
                textAlign: TextAlign.center,
                style: AppTypography.body14Regular.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 20),

              // YENİ: Tek satırlık AppInput yerine çok satırlı (multi-line) TextField yapısı
              TextField(
                controller: promptController,
                maxLines:
                    4, // Kullanıcı yazdıkhça 4 satıra kadar dikey olarak büyür
                minLines: 2, // Başlangıçta 2 satır yükseklikte başlar
                keyboardType: TextInputType.multiline,
                style: AppTypography.body16Regular.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Talebini yaz...',
                  hintStyle: AppTypography.body14Regular.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(
                      bottom: 24,
                    ), // İkonu üste hizalamak için
                    child: Icon(
                      Icons.auto_awesome,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.brandSecondary),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.brandSecondary),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppColors.brandPrimary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),

              const SizedBox(height: 16),
              AppButton(
                text: 'GÜNCELLE',
                showIcon: false,
                onPressed: () => _handleRevise(promptController.text),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.brandTertiary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          widget.program.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.heading2.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      // GÜNCELLENEN KISIM: Arka planı tamamen beyaz, ince şık bir çerçeveli ve modern "Düzenle" butonu
                      TextButton.icon(
                        onPressed: _showReviseSheet,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.brandPrimary,
                          backgroundColor:
                              Colors.white, // Arka planı tamamen beyaz yaptık
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: AppColors.brandSecondary.withValues(
                                alpha: 0.5,
                              ),
                              width: 1,
                            ), // Hafif zarif bir çerçeve ekledik
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: Text(
                          'Düzenle',
                          style: AppTypography.body14Medium.copyWith(
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.program.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        widget.program.description,
                        style: AppTypography.body14Regular.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView.separated(
                      itemCount: widget.program.workouts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final workout = widget.program.workouts[index];
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap:
                                () => context.push(
                                  '/workout-day-detail',
                                  extra: workout,
                                ),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.brandSecondary,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: AppColors.background,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${workout.dayNumber}',
                                      style: AppTypography.body16Medium
                                          .copyWith(
                                            color: AppColors.brandPrimary,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          workout.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.body16Medium
                                              .copyWith(
                                                color: AppColors.textPrimary,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${workout.exercises.length} hareket · ~${workout.estimatedDurationMin} dk',
                                          style: AppTypography.body12Regular
                                              .copyWith(
                                                color: AppColors.textTertiary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: AppColors.textTertiary,
                                  ),
                                ],
                              ),
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
        ),
        // YENİ: Şık Yükleme Ekranı Overlay'i
        if (_isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            alignment: Alignment.center,
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.brandTertiary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const CircularProgressIndicator(
                        color: AppColors.brandPrimary,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'AI İş Başında',
                      style: AppTypography.heading2.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Programın yeniden şekillendiriliyor,\nlütfen bekle...',
                      textAlign: TextAlign.center,
                      style: AppTypography.body14Regular.copyWith(
                        color: AppColors.textTertiary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
