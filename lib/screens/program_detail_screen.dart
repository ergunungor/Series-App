import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../models/program.dart';
import '../services/program_service.dart';
import '../services/program_repository.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import '../widgets/pressable_scale.dart';
import '../widgets/detail_hero.dart';
import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'dart:async';
import 'dart:math';

class ProgramDetailScreen extends StatefulWidget {
  final ActiveProgram program;

  const ProgramDetailScreen({super.key, required this.program});

  @override
  State<ProgramDetailScreen> createState() => _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends State<ProgramDetailScreen> {
  bool _isLoading = false;
  static const double _pagePadding = 16;
  // Öneri çipleri: dokununca yazı alanına eklenir (gönderim akışına dokunmaz).
  static const List<String> _reviseSuggestions = [
    'Süreyi kısalt',
    'Bacak hareketlerini çıkar',
    'Daha yoğun yap',
    'Ekipmansız olsun',
  ];

  // --- LİMİT KONTROL METOTLARI ---
  Future<bool> _canUseAI(String userId) async {
    final user = Supabase.instance.client.auth.currentUser;

    // YENİ: Patron çıldırdı (Kendi e-postan için VIP Geçiş)
    if (user?.email == 'ergun6e@gmail.com') {
      return true; // Sınır yok, hep true döner
    }

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
    final user = Supabase.instance.client.auth.currentUser;

    // YENİ: Kendi hesabında kota düşürme işlemini tamamen pas geç
    if (user?.email == 'ergun6e@gmail.com') {
      return;
    }

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
        final errorMessage = e.toString().replaceAll('Exception: ', '').trim();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: $errorMessage'),
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

  void _showReviseSheet() {
    final promptController = TextEditingController();

    // Boşsa çipin metnini yazar, doluysa mevcut metnin sonuna cümle olarak ekler.
    void addSuggestion(String suggestion) {
      final current = promptController.text.trim();
      final next =
          current.isEmpty
              ? suggestion
              : current.endsWith('.')
              ? '$current $suggestion'
              : '$current. $suggestion';
      promptController.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final inputBorder = OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        );

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.espresso,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            top: 12,
            left: 20,
            right: 20,
            // Klavye açıldığında yukarı kayması için
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.onHeroDark.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.accentGold,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 22,
                      color: AppColors.espresso,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'AI ile Şekillendir',
                      style: AppTypography.heading2.copyWith(
                        color: AppColors.onHeroDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Antrenmanında neleri değiştirmek istersin?',
                style: AppTypography.body14Regular.copyWith(
                  color: AppColors.onHeroDark.withValues(alpha: 0.62),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final suggestion in _reviseSuggestions)
                    PressableScale(
                      pressedScale: 0.95,
                      onTap: () => addSuggestion(suggestion),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold.withValues(alpha: 0.1),
                          border: Border.all(
                            color: AppColors.accentGold.withValues(alpha: 0.4),
                            width: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          suggestion,
                          style: AppTypography.body12Medium.copyWith(
                            color: AppColors.accentGold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: promptController,
                // Yazdıkça 4 satıra kadar dikey büyür, 2 satırla başlar
                maxLines: 4,
                minLines: 2,
                keyboardType: TextInputType.multiline,
                keyboardAppearance: Brightness.dark,
                cursorColor: AppColors.accentGold,
                style: AppTypography.body16Regular.copyWith(
                  color: AppColors.onHeroDark,
                ),
                decoration: InputDecoration(
                  hintText: 'Talebini yaz...',
                  hintStyle: AppTypography.body14Regular.copyWith(
                    color: AppColors.onHeroDark.withValues(alpha: 0.45),
                  ),
                  filled: true,
                  fillColor: AppColors.onHeroDark.withValues(alpha: 0.08),
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: inputBorder.copyWith(
                    borderSide: BorderSide(
                      color: AppColors.accentGold.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(18),
                ),
              ),
              const SizedBox(height: 16),
              PressableScale(
                onTap: () => _handleRevise(promptController.text),
                child: Container(
                  height: 52,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accentGold,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 18,
                        color: AppColors.espresso,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Güncelle',
                        style: AppTypography.body16Medium.copyWith(
                          color: AppColors.espresso,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHero(GlobalKey heroKey) {
    final program = widget.program;
    final exerciseCount = program.workouts.fold<int>(
      0,
      (sum, w) => sum + w.exercises.length,
    );
    final totalMinutes = program.workouts.fold<int>(
      0,
      (sum, w) => sum + w.estimatedDurationMin,
    );

    return DetailHero(
      heroKey: heroKey,
      gradientColors: const [AppColors.heroDarkStart, AppColors.heroDarkEnd],
      onBack: () => context.pop(),
      trailing: PressableScale(
        onTap: _showReviseSheet,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.accentGold.withValues(alpha: 0.16),
            border: Border.all(
              color: AppColors.accentGold.withValues(alpha: 0.45),
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 16,
                color: AppColors.accentGold,
              ),
              const SizedBox(width: 6),
              Text(
                'Düzenle',
                style: AppTypography.body14Medium.copyWith(
                  color: AppColors.accentGold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      title: program.name,
      stats: [
        DetailHeroStat('${program.workouts.length}', 'gün'),
        DetailHeroStat('$exerciseCount', 'hareket'),
        DetailHeroStat('$totalMinutes', 'dk toplam'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          body: HeroStatusBarScope(
            builder:
                (context, heroKey) => ListView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.paddingOf(context).bottom + 24,
                  ),
                  children: [
                    _buildHero(heroKey),
                    if (widget.program.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          _pagePadding,
                          20,
                          _pagePadding,
                          0,
                        ),
                        child: Text(
                          widget.program.description,
                          style: AppTypography.body14Regular.copyWith(
                            color: AppColors.textTertiary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        _pagePadding,
                        24,
                        _pagePadding,
                        8,
                      ),
                      child: Text(
                        'Antrenman günleri',
                        style: AppTypography.body18Medium.copyWith(
                          color: AppColors.espresso,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    for (var i = 0; i < widget.program.workouts.length; i++)
                      _DayTimelineItem(
                        workout: widget.program.workouts[i],
                        isFirst: i == 0,
                        isLast: i == widget.program.workouts.length - 1,
                        onTap:
                            () => context.push(
                              '/workout-day-detail',
                              extra: widget.program.workouts[i],
                            ),
                      ),
                  ],
                ),
          ),
        ),
        if (_isLoading) const Positioned.fill(child: _AiLoadingOverlay()),
      ],
    );
  }
}

class _DayTimelineItem extends StatelessWidget {
  final WorkoutDay workout;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _DayTimelineItem({
    required this.workout,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  static const double _nodeSize = 34;
  static const double _lineWidth = 2;
  static const double _gap = 12;

  Widget _railLine({required bool visible}) {
    return Center(
      child: Container(
        width: _lineWidth,
        decoration: BoxDecoration(
          color:
              visible
                  ? AppColors.goldDeep.withValues(alpha: 0.3)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(_lineWidth),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTypography.body12Regular.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _nodeSize,
              child: Column(
                children: [
                  Expanded(child: _railLine(visible: !isFirst)),
                  Container(
                    width: _nodeSize,
                    height: _nodeSize,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.espresso,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${workout.dayNumber}',
                      style: AppTypography.body14Medium.copyWith(
                        color: AppColors.onHeroDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(child: _railLine(visible: !isLast)),
                ],
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(
              child: Padding(
                // Boşluk satırın içinde simetrik: daire kartın tam ortasında kalır
                // ve çizgi satırlar arasında kopmaz.
                padding: const EdgeInsets.symmetric(vertical: _gap / 2),
                child: PressableScale(
                  pressedScale: 0.98,
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                workout.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body16Medium.copyWith(
                                  color: AppColors.espresso,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 14,
                                runSpacing: 4,
                                children: [
                                  _meta(
                                    Icons.fitness_center_rounded,
                                    '${workout.exercises.length} hareket',
                                  ),
                                  _meta(
                                    Icons.schedule_rounded,
                                    '~${workout.estimatedDurationMin} dk',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          CupertinoIcons.chevron_right,
                          size: 18,
                          color: AppColors.goldDeep,
                        ),
                      ],
                    ),
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

class _AiLoadingOverlay extends StatefulWidget {
  const _AiLoadingOverlay();

  @override
  State<_AiLoadingOverlay> createState() => _AiLoadingOverlayState();
}

class _AiLoadingOverlayState extends State<_AiLoadingOverlay>
    with SingleTickerProviderStateMixin {
  static const List<String> _messages = [
    'Programın yeniden şekilleniyor',
    'Hareketler senin için düzenleniyor',
    'Son rötuşlar yapılıyor',
  ];
  static const Duration _pulseDuration = Duration(milliseconds: 2400);
  static const Duration _messageInterval = Duration(milliseconds: 2800);
  static const double _orbSize = 76;

  late final AnimationController _pulse;
  Timer? _messageTimer;
  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: _pulseDuration)
      ..repeat();
    _messageTimer = Timer.periodic(_messageInterval, (_) {
      if (!mounted) return;
      setState(() => _messageIndex = (_messageIndex + 1) % _messages.length);
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  // phase: iki halkanın yarım turluk farkla dalgalanması için
  Widget _ring(double phase) {
    final t = (_pulse.value + phase) % 1.0;
    return Opacity(
      opacity: (1 - t) * 0.35,
      child: Transform.scale(
        scale: 1 + t * 0.9,
        child: Container(
          width: _orbSize,
          height: _orbSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accentGold, width: 1.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, t, child) {
        // BackdropFilter en dışta: Opacity içine konursa arkadaki sayfayı
        // bulanıklaştıramaz. Geçişi sigma, perde ve içerik opaklığına dağıtıyoruz.
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10 * t, sigmaY: 10 * t),
          child: Container(
            color: AppColors.heroDarkEnd.withValues(alpha: 0.78 * t),
            alignment: Alignment.center,
            child: Opacity(opacity: t, child: child),
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              child: SizedBox(
                width: _orbSize * 2,
                height: _orbSize * 2,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) {
                    final breathe = 1 + 0.05 * sin(_pulse.value * 2 * pi);
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        _ring(0),
                        _ring(0.5),
                        Transform.scale(
                          scale: breathe,
                          child: Container(
                            width: _orbSize,
                            height: _orbSize,
                            decoration: BoxDecoration(
                              color: AppColors.accentGold,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentGold.withValues(
                                    alpha: 0.45,
                                  ),
                                  blurRadius: 36,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              size: 34,
                              color: AppColors.espresso,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'AI İş Başında',
              style: AppTypography.heading2.copyWith(
                color: AppColors.onHeroDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 22,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  _messages[_messageIndex],
                  key: ValueKey(_messageIndex),
                  textAlign: TextAlign.center,
                  style: AppTypography.body14Regular.copyWith(
                    color: AppColors.onHeroDark.withValues(alpha: 0.7),
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
