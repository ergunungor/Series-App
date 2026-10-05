import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../models/program.dart';
import '../services/program_service.dart';
import '../services/program_repository.dart';
import '../widgets/app_button.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import '../widgets/pressable_scale.dart';
import 'package:flutter/services.dart';
import '../widgets/app_logo.dart';
import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoActivityIndicator;

class ProgramDetailScreen extends StatefulWidget {
  final ActiveProgram program;

  const ProgramDetailScreen({super.key, required this.program});

  @override
  State<ProgramDetailScreen> createState() => _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends State<ProgramDetailScreen> {
  bool _isLoading = false;
  static const double _pagePadding = 16;

  final GlobalKey _heroKey = GlobalKey();
  bool _isStatusBarLight = true;

  // Hero ekranın üstünden çıkınca saat/pil rengini koyuya çevirir.
  bool _handleScroll(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification || notification.depth != 0) {
      return false;
    }
    final heroHeight = _heroKey.currentContext?.size?.height;
    if (heroHeight == null) return false;

    final isLight =
        notification.metrics.pixels <
        heroHeight - MediaQuery.paddingOf(context).top;
    if (isLight != _isStatusBarLight) {
      setState(() => _isStatusBarLight = isLight);
    }
    return false;
  }

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
            color: AppColors.background,
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
                    color: AppColors.brandSecondary,
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
                      color: AppColors.goldTint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 22,
                      color: AppColors.goldDeep,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'AI ile Şekillendir',
                      style: AppTypography.heading2.copyWith(
                        color: AppColors.espresso,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Antrenmanında neleri değiştirmek istersin? (Örn: Süreyi kısalt, bacak hareketlerini çıkar)',
                style: AppTypography.body14Regular.copyWith(
                  color: AppColors.textTertiary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: promptController,
                // Yazdıkça 4 satıra kadar dikey büyür, 2 satırla başlar
                maxLines: 4,
                minLines: 2,
                keyboardType: TextInputType.multiline,
                style: AppTypography.body16Regular.copyWith(
                  color: AppColors.espresso,
                ),
                decoration: InputDecoration(
                  hintText: 'Talebini yaz...',
                  hintStyle: AppTypography.body14Regular.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: inputBorder.copyWith(
                    borderSide: const BorderSide(
                      color: AppColors.goldDeep,
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
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.goldDeep.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(
                    'Güncelle',
                    style: AppTypography.body16Medium.copyWith(
                      color: AppColors.espresso,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _heroStat(String value, String label, {bool isFirst = false}) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(left: isFirst ? 0 : 14, right: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTypography.heading2.copyWith(
                color: AppColors.onHeroDark,
                fontWeight: FontWeight.w700,
                height: 1,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.body12Regular.copyWith(
                color: AppColors.onHeroDark.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroDivider() {
    return Container(
      width: 0.5,
      color: AppColors.onHeroDark.withValues(alpha: 0.18),
    );
  }

  Widget _buildHero() {
    final program = widget.program;
    final exerciseCount = program.workouts.fold<int>(
      0,
      (sum, w) => sum + w.exercises.length,
    );
    final totalMinutes = program.workouts.fold<int>(
      0,
      (sum, w) => sum + w.estimatedDurationMin,
    );

    final hero = Container(
      key: _heroKey,
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.fromLTRB(
        _pagePadding,
        MediaQuery.paddingOf(context).top + 12,
        _pagePadding,
        28,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.heroDarkStart, AppColors.heroDarkEnd],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -32,
            bottom: -44,
            child: Opacity(
              opacity: 0.06,
              child: const AppLogo(explicitSize: 190, type: AppLogoType.light),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PressableScale(
                    pressedScale: 0.92,
                    onTap: () => context.pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.onHeroDark.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.back,
                        size: 20,
                        color: AppColors.onHeroDark,
                      ),
                    ),
                  ),
                  const Spacer(),
                  PressableScale(
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
                ],
              ),
              const SizedBox(height: 28),
              Text(
                program.name,
                style: AppTypography.heading1.copyWith(
                  color: AppColors.onHeroDark,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 24),
              IntrinsicHeight(
                child: Row(
                  children: [
                    _heroStat(
                      '${program.workouts.length}',
                      'gün',
                      isFirst: true,
                    ),
                    _heroDivider(),
                    _heroStat('$exerciseCount', 'hareket'),
                    _heroDivider(),
                    _heroStat('$totalMinutes', 'dk toplam'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // Üst kenar boşluğa çekilince (bounce) hero'nun üstü açık kalmasın diye,
    // hero'nun üstüne aynı renkte uzun bir blok ekliyoruz. Normalde ekran dışında,
    // sadece aşağı çekilirken görünür.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -MediaQuery.sizeOf(context).height,
          left: 0,
          right: 0,
          height: MediaQuery.sizeOf(context).height,
          child: const ColoredBox(color: AppColors.heroDarkStart),
        ),
        hero,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          body: AnnotatedRegion<SystemUiOverlayStyle>(
            // Hero durum çubuğunun arkasındayken açık, liste altına geçince koyu
            value:
                _isStatusBarLight
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark,
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScroll,
              child: ListView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom + 24,
                ),
                children: [
                  _buildHero(),
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
        ),
        // Yükleme overlay'i: sayfa bulanıklaşır, ortada beyaz bir kart belirir
        if (_isLoading)
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              builder: (context, t, child) {
                return BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8 * t, sigmaY: 8 * t),
                  child: Container(
                    color: AppColors.heroDarkEnd.withValues(alpha: 0.55 * t),
                    alignment: Alignment.center,
                    child: Opacity(opacity: t, child: child),
                  ),
                );
              },
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 32,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.goldTint,
                          shape: BoxShape.circle,
                        ),
                        child: const CupertinoActivityIndicator(
                          radius: 16,
                          color: AppColors.goldDeep,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'AI İş Başında',
                        style: AppTypography.heading3.copyWith(
                          color: AppColors.espresso,
                          fontWeight: FontWeight.w700,
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
          ),
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
