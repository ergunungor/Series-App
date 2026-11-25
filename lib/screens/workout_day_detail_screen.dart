import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../models/program.dart';
import '../utils/session_flow.dart';
import '../services/program_repository.dart';
import '../services/program_service.dart';
import '../widgets/ai_revise_sheet.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/detail_hero.dart';
import '../widgets/pressable_scale.dart';
import '../utils/exercise_name.dart';

class WorkoutDayDetailScreen extends StatefulWidget {
  final WorkoutDay workout;

  const WorkoutDayDetailScreen({super.key, required this.workout});

  @override
  State<WorkoutDayDetailScreen> createState() => _WorkoutDayDetailScreenState();
}

class _WorkoutDayDetailScreenState extends State<WorkoutDayDetailScreen> {
  static const double _pagePadding = 16;

  static const double _ctaHeight = 56;
  static const double _ctaGap = 16;
  static const double _ctaFade = 32;

  // Ekranda düzenlenebilen güncel gün (Düzenle ve sürükleyerek sıralama).
  late String _name = widget.workout.name;
  late int _minutes = widget.workout.estimatedDurationMin;
  late List<WorkoutExercise> _exercises = [...widget.workout.exercises];
  bool _aiLoading = false;

  WorkoutDay get _day => WorkoutDay(
    id: widget.workout.id,
    dayNumber: widget.workout.dayNumber,
    name: _name,
    estimatedDurationMin: _minutes,
    exercises: _exercises,
  );

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppColors.error : null,
        ),
      );
  }

  /// Günü veritabanında günceller; izin yoksa ya da satır bulunamazsa hata.
  Future<void> _persist({String? name, int? minutes}) async {
    final rows = await Supabase.instance.client
        .from('workouts')
        .update({
          'exercises': _exercises.map((e) => e.toJson()).toList(),
          if (name != null) 'name': name,
          if (minutes != null) 'estimated_duration_min': minutes,
        })
        .eq('id', widget.workout.id)
        .select('id');
    if ((rows as List).isEmpty) {
      throw Exception('Değişiklik kaydedilemedi.');
    }
    programRefreshNotifier.value++;
  }

  Future<void> _onReorder(int from, int to) async {
    final previous = _exercises;
    final next = [...previous];
    final moved = next.removeAt(from);
    next.insert(to, moved);
    setState(() => _exercises = normalizeSupersets(next));
    try {
      await _persist();
    } catch (_) {
      if (!mounted) return;
      setState(() => _exercises = previous);
      _toast('Sıralama kaydedilemedi. Bağlantını kontrol et.', error: true);
    }
  }

  Future<void> _openAiEdit() async {
    final prompt = await showAiReviseSheet(
      context,
      subtitle: 'Bu antrenmanda neleri değiştirmek istersin?',
      suggestions: const [
        'Süreyi kısalt',
        'Bir hareketi değiştir',
        'Isınma ekle',
        'Son iki hareketi süperset yap',
      ],
    );
    if (prompt == null || !mounted) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _aiLoading = true);
    try {
      if (!await AiCredits.canUse(user.id)) {
        _toast(
          'Bugünlük yapay zeka limitine (5/5) ulaştın. Yarın tekrar dene.',
        );
        return;
      }
      final response = await ProgramService.reviseProgram(user.id, {
        'program_name': '',
        'workouts': [
          {
            'id': widget.workout.id,
            'day_number': 1,
            'name': _name,
            'estimated_duration_min': _minutes,
            'exercises': _exercises.map((e) => e.toJson()).toList(),
          },
        ],
      }, prompt);
      final workouts = (response['data']?['workouts'] as List?) ?? const [];
      if (workouts.isEmpty) throw Exception('Antrenman boş döndü.');
      final w = Map<String, dynamic>.from(workouts.first as Map);
      final exercises =
          ((w['exercises'] as List?) ?? const [])
              .map(
                (e) => WorkoutExercise.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
      if (exercises.isEmpty) throw Exception('Antrenmanda hareket kalmadı.');

      final previous = (_name, _minutes, _exercises);
      setState(() {
        _exercises = exercises;
        _name =
            (w['name'] as String?)?.trim().isNotEmpty == true
                ? w['name']
                : _name;
        _minutes = (w['estimated_duration_min'] as num?)?.toInt() ?? _minutes;
      });
      try {
        await _persist(name: _name, minutes: _minutes);
      } catch (e) {
        setState(() {
          _name = previous.$1;
          _minutes = previous.$2;
          _exercises = previous.$3;
        });
        rethrow;
      }
      await AiCredits.consume(user.id);
      _toast('Antrenman güncellendi.');
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', '').trim(), error: true);
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  // Eski butonun onpayı ve yönlendirmesi birebir aynı; sadece metoda alındı.
  Future<void> _confirmAndStart() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Antrenmanı Başlat',
      message: '"$_name" antrenmanına başlamak istiyor musunuz?',
      confirmLabel: 'Başla',
    );
    if (confirmed && mounted) {
      context.push('/workout-player', extra: _day);
    }
  }

  Widget _buildStartBar() {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Stack(
      children: [
        // Listenin buton arkasında keskin kesilmemesi için yumuşak geçiş.
        // IgnorePointer: bu şerit altındaki satırlara dokunmayı engellemesin.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background.withValues(alpha: 0),
                    AppColors.background,
                  ],
                  stops: const [0, 0.4],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            _pagePadding,
            _ctaFade,
            _pagePadding,
            bottomInset + _ctaGap,
          ),
          child: PressableScale(
            onTap: _confirmAndStart,
            child: Container(
              height: _ctaHeight,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accentGold,
                borderRadius: BorderRadius.circular(_ctaHeight / 2),
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
                  const Icon(
                    Icons.play_arrow_rounded,
                    size: 24,
                    color: AppColors.espresso,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Antrenmanı Başlat',
                    style: AppTypography.body16Medium.copyWith(
                      color: AppColors.espresso,
                      fontWeight: FontWeight.w700,
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

  Widget _buildHero(GlobalKey heroKey) {
    final workout = _day;

    return DetailHero(
      heroKey: heroKey,
      gradientColors: const [AppColors.heroDarkStart, AppColors.heroDarkEnd],
      onBack: () => Navigator.of(context).pop(),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dayChip(workout.dayNumber),
          const SizedBox(width: 8),
          PressableScale(
            onTap: _aiLoading ? null : _openAiEdit,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.accentGold,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 15,
                    color: AppColors.espresso,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Düzenle',
                    style: AppTypography.body14Medium.copyWith(
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
      title: workout.name,
      stats: [
        DetailHeroStat('${workout.exercises.length}', 'hareket'),
        DetailHeroStat('${workout.estimatedDurationMin}', 'dk'),
      ],
    );
  }

  Widget _dayChip(int dayNumber) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accentGold.withValues(alpha: 0.16),
        border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '$dayNumber. gün',
        style: AppTypography.body14Medium.copyWith(
          color: AppColors.accentGold,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Bir hareketin satırı: gerekiyorsa bölüm başlığı ya da ayırıcı ile.
  Widget _buildItem(int i) {
    final exercises = _exercises;
    final exercise = exercises[i];
    final hasSections = exercises.any((e) => e.isPrep);
    final children = <Widget>[];

    // Isınma / antrenman / soğuma başlıkları (programda ısınma varsa).
    if (hasSections &&
        (i == 0 || exercise.section != exercises[i - 1].section)) {
      children.add(
        _SectionHeader(
          label:
              exercise.isWarmup
                  ? 'ISINMA'
                  : exercise.isCooldown
                  ? 'SOĞUMA'
                  : 'ANTRENMAN',
          first: i == 0,
        ),
      );
    } else if (i > 0) {
      final linked =
          exercise.supersetGroup != null &&
          exercises[i - 1].supersetGroup == exercise.supersetGroup;
      if (!linked) children.add(const _RowDivider());
    }

    // Süre varsa süreyi, yoksa tekrarı gösteriyoruz
    final String repsOrDuration =
        (exercise.durationSeconds != null && exercise.durationSeconds! > 0)
            ? '${exercise.durationSeconds}sn'
            : '${exercise.reps ?? ""}';

    final gs = groupStart(exercises, i);
    final ge = groupEnd(exercises, i);
    final inSuperset = gs != ge;

    children.add(
      _ExerciseRow(
        number: i + 1,
        name: formatExerciseName(exercise.name),
        setsLabel: '${exercise.sets} × $repsOrDuration',
        // Süpersette mola yalnızca bloğun sonunda verilir.
        restLabel:
            inSuperset && i < ge
                ? 'ara vermeden'
                : '${exercise.restSeconds ?? 60}sn dinlenme',
        notes: exercise.notes,
        supersetLabel: inSuperset && i == gs ? 'SÜPERSET' : null,
        supersetTop: inSuperset && i > gs,
        supersetBottom: inSuperset && i < ge,
        inSuperset: inSuperset,
        dropSets: exercise.dropSets,
      ),
    );

    // Basılı tutunca sürüklenir (iOS'taki gibi).
    return ReorderableDelayedDragStartListener(
      key: ObjectKey(exercise),
      index: i,
      child: ColoredBox(
        color: Colors.white,
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          HeroStatusBarScope(
            builder:
                (context, heroKey) => ListView(
                  // Son satır, butonun ve geçiş şeridinin altında kalmasın
                  padding: EdgeInsets.only(
                    bottom:
                        MediaQuery.paddingOf(context).bottom +
                        _ctaHeight +
                        _ctaGap +
                        _ctaFade,
                  ),
                  children: [
                    _buildHero(heroKey),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        _pagePadding,
                        24,
                        _pagePadding,
                        12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              'Hareketler',
                              style: AppTypography.body18Medium.copyWith(
                                color: AppColors.espresso,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            'Sıralamak için basılı tut',
                            style: AppTypography.body12Regular.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_exercises.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: _pagePadding,
                        ),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          buildDefaultDragHandles: false,
                          itemCount: _exercises.length,
                          onReorderStart: (_) => HapticFeedback.mediumImpact(),
                          onReorderItem: _onReorder,
                          proxyDecorator:
                              (child, _, _) => Material(
                                color: Colors.white,
                                elevation: 8,
                                shadowColor: Colors.black26,
                                borderRadius: BorderRadius.circular(16),
                                clipBehavior: Clip.antiAlias,
                                child: child,
                              ),
                          itemBuilder: (context, i) => _buildItem(i),
                        ),
                      ),
                  ],
                ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _buildStartBar()),
          if (_aiLoading) const Positioned.fill(child: AiLoadingOverlay()),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final bool first;

  const _SectionHeader({required this.label, required this.first});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.fillSubtle.withValues(alpha: 0.6),
        border:
            first
                ? null
                : Border(
                  top: BorderSide(
                    color: AppColors.espresso.withValues(alpha: 0.08),
                  ),
                ),
      ),
      child: Text(
        label,
        style: AppTypography.body12Medium.copyWith(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    // Numara karosu + boşluk kadar içeriden başlar (14 + 34 + 12)
    return Container(
      height: 0.5,
      margin: const EdgeInsets.only(left: 60),
      color: AppColors.espresso.withValues(alpha: 0.1),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final int number;
  final String name;
  final String setsLabel;
  final String restLabel;
  final String? notes;

  /// Süperset bloğunun ilk satırında gösterilen etiket.
  final String? supersetLabel;
  final bool inSuperset;

  /// Sol bağ çizgisi üst/alt komşu satıra uzansın mı.
  final bool supersetTop;
  final bool supersetBottom;
  final int dropSets;

  const _ExerciseRow({
    required this.number,
    required this.name,
    required this.setsLabel,
    required this.restLabel,
    this.notes,
    this.supersetLabel,
    this.inSuperset = false,
    this.supersetTop = false,
    this.supersetBottom = false,
    this.dropSets = 0,
  });

  static const double _tileSize = 34;
  static const double _chipHeight = 28;

  Widget _chip({
    required String label,
    required Color background,
    required Color foreground,
    IconData? icon,
    FontWeight weight = FontWeight.w400,
  }) {
    return Container(
      height: _chipHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(_chipHeight / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body12Regular.copyWith(
                color: foreground,
                fontWeight: weight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final row = _buildRow();
    if (!inSuperset) return row;
    // Süperset: numara karolarını dikey bir altın çizgiyle birbirine bağlar.
    return Stack(
      children: [
        // İlk satırda karodan aşağı, sonuncuda yukarıdan karoya, ortadakilerde
        // boydan boya.
        Positioned(
          left: 14 + _tileSize / 2 - 1.5,
          top: supersetTop ? 0 : 14 + _tileSize / 2,
          bottom: supersetBottom ? 0 : null,
          height: supersetBottom ? null : 14 + _tileSize / 2,
          width: 3,
          child: const ColoredBox(color: AppColors.accentGold),
        ),
        row,
      ],
    );
  }

  Widget _buildRow() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: _tileSize,
            height: _tileSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: inSuperset ? AppColors.accentGold : AppColors.goldTint,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              '$number',
              style: AppTypography.body14Medium.copyWith(
                color: AppColors.espresso,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (supersetLabel != null || dropSets > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      [
                        if (supersetLabel != null)
                          '$supersetLabel · ara vermeden art arda',
                        if (dropSets > 0) 'DROPSET ×$dropSets',
                      ].join('   '),
                      style: AppTypography.body12Medium.copyWith(
                        color: AppColors.goldDeep,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                // Ad, karonun dikey ortasına hizalı; uzun ad iki satıra inerse
                // blok büyür ve karo ilk satırla hizalı kalır.
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _tileSize),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      name,
                      style: AppTypography.body16Medium.copyWith(
                        color: AppColors.espresso,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _chip(
                        label: setsLabel,
                        background: AppColors.goldTint,
                        foreground: AppColors.espresso,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _chip(
                        label: restLabel,
                        background: AppColors.fillSubtle,
                        foreground: AppColors.textTertiary,
                        icon: Icons.timer_outlined,
                      ),
                    ),
                  ],
                ),
                if (notes != null && notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    notes!,
                    style: AppTypography.body12Regular.copyWith(
                      color: AppColors.textTertiary,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
