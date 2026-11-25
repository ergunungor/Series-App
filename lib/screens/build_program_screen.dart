import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/exercise_service.dart';
import '../services/program_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/exercise_name.dart';
import '../widgets/app_button.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/detail_hero.dart' show HeroStatusBarScope;
import '../widgets/exercise_info_dialog.dart';
import '../widgets/kiremit_hero_surface.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/selectable_chip.dart';
import '../widgets/series_wordmark.dart';

const _bodyPartLabels = <String, String>{
  'chest': 'Göğüs',
  'back': 'Sırt',
  'shoulders': 'Omuz',
  'upper arms': 'Kol',
  'lower arms': 'Ön kol',
  'upper legs': 'Bacak',
  'lower legs': 'Baldır',
  'waist': 'Karın',
  'cardio': 'Kardiyo',
  'neck': 'Boyun',
};

class _DraftExercise {
  final CatalogExercise ex;
  final Key key = UniqueKey();
  int sets = 3;
  String reps = '10';
  bool timed = false;
  int duration = 30;
  int rest = 60;
  int drops = 0;

  /// Sonraki hareketle süperset: ara vermeden birlikte yapılır.
  bool linkNext = false;

  _DraftExercise(this.ex);

  String get summary {
    final work = timed ? '${duration}sn' : reps;
    final parts = ['$sets × $work'];
    parts.add(linkNext ? 'mola turdan sonra' : '${rest}sn mola');
    if (drops > 0) parts.add('Drop ×$drops');
    return parts.join(' · ');
  }
}

extension _DraftExerciseX on _DraftExercise {
  Map<String, dynamic> toDraftJson() => {
    'id': ex.id,
    'name': ex.name,
    'body_part': ex.bodyPart,
    'equipment': ex.equipment,
    'sets': sets,
    'reps': reps,
    'timed': timed,
    'duration': duration,
    'rest': rest,
    'drops': drops,
    'link_next': linkNext,
  };

  // ignore: unused_element
  static _DraftExercise from(Map<String, dynamic> j) {
    final name = (j['name'] ?? '').toString();
    final equipment = (j['equipment'] ?? '').toString();
    return _DraftExercise(
        CatalogExercise(
          id: j['id'].toString(),
          name: name,
          bodyPart: (j['body_part'] ?? '').toString(),
          equipment: equipment,
          searchKey: '$name $equipment'.toLowerCase(),
        ),
      )
      ..sets = (j['sets'] as num?)?.toInt() ?? 3
      ..reps = (j['reps'] ?? '10').toString()
      ..timed = j['timed'] == true
      ..duration = (j['duration'] as num?)?.toInt() ?? 30
      ..rest = (j['rest'] as num?)?.toInt() ?? 60
      ..drops = (j['drops'] as num?)?.toInt() ?? 0
      ..linkNext = j['link_next'] == true;
  }
}

class _DraftDay {
  String name;
  final List<_DraftExercise> items = [];
  _DraftDay(this.name);
}

/// Kullanıcının kendi programını egzersiz havuzundan elle kurduğu ekran:
/// gün ekle, hareket seç, set / tekrar (ya da süre) / dinlenme ayarla,
/// süperset ve dropset işaretle. Yapay zekayla ilgisi yok.
class BuildProgramScreen extends StatefulWidget {
  const BuildProgramScreen({super.key});

  @override
  State<BuildProgramScreen> createState() => _BuildProgramScreenState();
}

class _BuildProgramScreenState extends State<BuildProgramScreen> {
  final _nameController = TextEditingController();
  final List<_DraftDay> _days = [_DraftDay('Gün 1')];
  int _selected = 0;
  bool _saving = false;

  _DraftDay get _day => _days[_selected];

  // Taslak: yanlışlıkla çıkılsa da son hâli cihazda saklanır ve geri yüklenir.
  bool _draftLoaded = false;
  bool _discardDraft = false;
  Timer? _persistTimer;

  String get _draftKey {
    String uid = '';
    try {
      uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    } catch (_) {}
    return 'program_draft_v1_$uid';
  }

  bool get _hasContent =>
      _nameController.text.trim().isNotEmpty ||
      _days.length > 1 ||
      _days.any((d) => d.items.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_persistSoon);
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw != null && mounted) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final days = <_DraftDay>[
          for (final d in (data['days'] as List))
            _DraftDay((d['name'] ?? 'Gün').toString())
              ..items.addAll([
                for (final e in (d['items'] as List))
                  _DraftExerciseX.from(e as Map<String, dynamic>),
              ]),
        ];
        if (days.isNotEmpty) {
          setState(() {
            _days
              ..clear()
              ..addAll(days);
            _selected = ((data['selected'] as num?)?.toInt() ?? 0).clamp(
              0,
              days.length - 1,
            );
            _nameController.text = (data['name'] ?? '').toString();
          });
        }
      }
    } catch (_) {
      // Bozuk taslak yok sayılır.
    }
    _draftLoaded = true;
  }

  @override
  // ignore: must_call_super
  void setState(VoidCallback fn) {
    super.setState(fn);
    _persistSoon();
  }

  void _persistSoon() {
    if (!_draftLoaded || _discardDraft) return;
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 400), _persistNow);
  }

  Future<void> _persistNow() async {
    if (!_draftLoaded || _discardDraft) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_hasContent) {
        await prefs.remove(_draftKey);
        return;
      }
      await prefs.setString(
        _draftKey,
        jsonEncode({
          'name': _nameController.text,
          'selected': _selected,
          'days': [
            for (final d in _days)
              {
                'name': d.name,
                'items': [for (final e in d.items) e.toDraftJson()],
              },
          ],
        }),
      );
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    _persistTimer?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {}
  }

  Future<void> _confirmClearAll() async {
    final ok = await showAppConfirmDialog(
      context: context,
      title: 'Tümünü Temizle',
      message:
          'Program adı, günler ve eklediğin tüm hareketler silinecek. Emin misin?',
      confirmLabel: 'Temizle',
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    setState(() {
      _nameController.clear();
      _days
        ..clear()
        ..add(_DraftDay('Gün 1'));
      _selected = 0;
    });
    await _clearDraft();
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    if (!_discardDraft) _persistNow();
    _nameController.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _addDay() {
    setState(() {
      _days.add(_DraftDay('Gün ${_days.length + 1}'));
      _selected = _days.length - 1;
    });
  }

  Future<void> _dayMenu() async {
    final controller = TextEditingController(text: _day.name);
    final action = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Gün'),
            content: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Gün adı'),
            ),
            actions: [
              if (_days.length > 1)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'delete'),
                  child: const Text(
                    'Günü sil',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'save'),
                child: const Text('Tamam'),
              ),
            ],
          ),
    );
    if (!mounted || action == null) return;
    setState(() {
      if (action == 'delete') {
        _days.removeAt(_selected);
        _selected = (_selected - 1).clamp(0, _days.length - 1);
      } else if (controller.text.trim().isNotEmpty) {
        _day.name = controller.text.trim();
      }
    });
  }

  Future<void> _pickExercises() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder:
          (_) => _ExercisePicker(
            onAdd: (ex) => setState(() => _day.items.add(_DraftExercise(ex))),
          ),
    );
  }

  Future<void> _edit(_DraftExercise item) async {
    final index = _day.items.indexOf(item);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder:
          (_) => _EditSheet(
            item: item,
            canLinkNext: index < _day.items.length - 1,
            onChanged: () => setState(() {}),
            onDelete: () {
              setState(() {
                // Silinen hareketin süperset bağı bir öncekinden de kalkmasın
                // diye bağ, öncekine devredilir.
                if (index > 0 && item.linkNext == false) {
                  _day.items[index - 1].linkNext = false;
                }
                _day.items.remove(item);
              });
            },
          ),
    );
  }

  void _remove(_DraftExercise item) {
    final list = _day.items;
    final index = list.indexOf(item);
    if (index < 0) return;
    setState(() {
      // Silinen hareket süperset zincirinin ortasındaysa zincir bozulmasın:
      // önceki hareketin bağı, silinenin bağını devralır.
      if (index > 0) {
        list[index - 1].linkNext = item.linkNext && list[index - 1].linkNext;
      }
      list.removeAt(index);
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${formatExerciseName(item.ex.name)} silindi'),
          action: SnackBarAction(
            label: 'Geri al',
            onPressed: () {
              if (!mounted) return;
              setState(() => list.insert(index.clamp(0, list.length), item));
            },
          ),
        ),
      );
  }

  Future<void> _save() async {
    if (_saving) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final days = _days.where((d) => d.items.isNotEmpty).toList();
    if (days.isEmpty) {
      _toast('En az bir güne hareket ekle.');
      return;
    }

    setState(() => _saving = true);
    final client = Supabase.instance.client;
    String? programId;
    try {
      final name = _nameController.text.trim();
      final row =
          await client
              .from('programs')
              .insert({
                'user_id': user.id,
                'name': name.isEmpty ? 'Programım' : name,
                'description':
                    '${days.length} günlük, kendi hazırladığın program',
              })
              .select()
              .single();
      programId = row['id'].toString();

      var group = 0;
      final workouts = <Map<String, dynamic>>[];
      for (var d = 0; d < days.length; d++) {
        final items = days[d].items;
        final exercises = <Map<String, dynamic>>[];
        var seconds = 0;

        var i = 0;
        while (i < items.length) {
          // [i, end] aralığı bir süperset bloğu (ya da tek hareket).
          var end = i;
          while (end < items.length - 1 && items[end].linkNext) {
            end++;
          }
          final isSuperset = end > i;
          final gid = isSuperset ? ++group : null;
          final sets = items[i].sets;

          for (var k = i; k <= end; k++) {
            final e = items[k];
            final isLast = k == end;
            final rest = isSuperset && !isLast ? 0 : e.rest;
            exercises.add({
              'id': e.ex.id,
              'name': e.ex.name,
              'sets': isSuperset ? sets : e.sets,
              'reps': e.timed ? null : e.reps,
              'duration_seconds': e.timed ? e.duration : null,
              'rest_seconds': rest,
              if (gid != null) 'superset_group': gid,
              if (e.drops > 0) 'drop_sets': e.drops,
            });
            final perSet = e.timed ? e.duration : 40;
            final s = isSuperset ? sets : e.sets;
            seconds += s * (perSet * (1 + e.drops) + (isLast ? rest : 10));
          }
          i = end + 1;
        }

        workouts.add({
          'program_id': programId,
          'day_number': d + 1,
          'name': days[d].name,
          'estimated_duration_min': (seconds / 60).round().clamp(5, 300),
          'exercises': exercises,
        });
      }

      await client.from('workouts').insert(workouts);
      programRefreshNotifier.value++;
      _discardDraft = true;
      await _clearDraft();
      if (mounted) context.pop(true);
    } catch (e) {
      if (programId != null) {
        try {
          await client.from('programs').delete().eq('id', programId);
        } catch (_) {}
      }
      if (mounted) {
        setState(() => _saving = false);
        _toast('Program kaydedilemedi. Bağlantını kontrol edip tekrar dene.');
      }
    }
  }

  static const double _pad = 20;

  @override
  Widget build(BuildContext context) {
    final items = _day.items;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            HeroStatusBarScope(
              builder:
                  (context, heroKey) => ReorderableListView.builder(
                    physics: const BouncingScrollPhysics(),
                    buildDefaultDragHandles: false,
                    padding: EdgeInsets.only(bottom: bottomSafe + 120),
                    itemCount: items.length,
                    header: _buildHeader(heroKey),
                    footer: Padding(
                      padding: const EdgeInsets.fromLTRB(_pad, 6, _pad, 0),
                      child: AppButton(
                        text: 'Hareket Ekle',
                        icon: Icons.add_rounded,
                        variant: AppButtonVariant.outlined,
                        onPressed: _pickExercises,
                      ),
                    ),
                    onReorderItem: (from, to) {
                      setState(() {
                        final moved = items.removeAt(from);
                        items.insert(to, moved);
                        // Sıra değişince süperset bağları anlamsız kalabilir.
                        for (final e in items) {
                          e.linkNext = false;
                        }
                      });
                    },
                    proxyDecorator:
                        (child, _, _) => Material(
                          color: Colors.transparent,
                          elevation: 6,
                          shadowColor: Colors.black26,
                          borderRadius: BorderRadius.circular(22),
                          child: child,
                        ),
                    itemBuilder: (context, i) => _buildItem(items, i),
                  ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: false,
                child: Container(
                  padding: EdgeInsets.fromLTRB(_pad, 28, _pad, bottomSafe + 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.background.withValues(alpha: 0),
                        AppColors.background,
                      ],
                      stops: const [0, 0.38],
                    ),
                  ),
                  child: AppButton(
                    text: 'Programı Kaydet',
                    icon: Icons.check_rounded,
                    isLoading: _saving,
                    onPressed: _saving ? null : _save,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(GlobalKey heroKey) {
    return Column(
      key: const ValueKey('header'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KiremitHeroSurface(
          heroKey: heroKey,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              _pad,
              MediaQuery.paddingOf(context).top + 8,
              _pad,
              28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: PressableScale(
                          pressedScale: 0.92,
                          onTap: () => context.pop(false),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SeriesWordmark(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      if (_hasContent)
                        Align(
                          alignment: Alignment.centerRight,
                          child: PressableScale(
                            pressedScale: 0.92,
                            onTap: _confirmClearAll,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.delete_sweep_outlined,
                                size: 21,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Kendin Oluştur',
                  style: AppTypography.heading1.copyWith(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Hareketleri sen seç; set, dinlenme, süperset ve dropset senin elinde.',
                  style: AppTypography.body14Regular.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(_pad, 24, _pad, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            decoration: _cardDecoration(24),
            child: TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              cursorColor: AppColors.homeHero,
              style: AppTypography.body16Medium.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Program adı (örn. Push Pull Legs)',
                hintStyle: AppTypography.body16Medium.copyWith(
                  color: AppColors.textTertiary.withValues(alpha: 0.8),
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: _pad, vertical: 16),
            children: [
              for (var i = 0; i < _days.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onLongPress: i == _selected ? _dayMenu : null,
                    child: SelectableChip(
                      label: _days[i].name,
                      isSelected: i == _selected,
                      onTap: () => setState(() => _selected = i),
                    ),
                  ),
                ),
              SelectableChip(label: '+ Gün', isSelected: false, onTap: _addDay),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(_pad, 0, _pad - 6, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _day.items.isEmpty
                      ? 'Henüz hareket yok'
                      : 'Sola kaydır: sil · dokun: düzenle · sürükle: sırala',
                  style: AppTypography.body12Regular.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              TextButton(
                onPressed: _dayMenu,
                child: Text(
                  'Günü düzenle',
                  style: AppTypography.body12Medium.copyWith(
                    color: AppColors.homeHero,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItem(List<_DraftExercise> items, int i) {
    final e = items[i];
    final prevLinked = i > 0 && items[i - 1].linkNext;
    final grouped = e.linkNext || prevLinked;
    final startsGroup = e.linkNext && !prevLinked;

    return Dismissible(
      key: e.key,
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _remove(e),
      background: Container(
        margin: const EdgeInsets.fromLTRB(_pad, 0, _pad, 10),
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_pad, 0, _pad, 10),
        child: PressableScale(
          pressedScale: 0.985,
          onTap: () => _edit(e),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: _cardDecoration(22),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 5,
                    color: grouped ? AppColors.accentGold : Colors.transparent,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 0, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (startsGroup)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Text(
                                'SÜPERSET',
                                style: AppTypography.body12Medium.copyWith(
                                  color: AppColors.goldDeep,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ),
                          Text(
                            formatExerciseName(e.ex.name),
                            style: AppTypography.body16Medium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            e.summary,
                            style: AppTypography.body12Regular.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _RoundIconButton(
                    icon: Icons.info_outline_rounded,
                    onTap:
                        () => showExerciseInfoDialog(
                          context,
                          exerciseId: e.ex.id,
                          name: e.ex.name,
                        ),
                  ),
                  ReorderableDragStartListener(
                    index: i,
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(4, 12, 14, 12),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration(double radius) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ],
);

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.88,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: AppColors.fillSubtle,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 19, color: AppColors.homeHero),
        ),
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  final String title;
  final Widget child;

  const _SheetFrame({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              title,
              style: AppTypography.heading3.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tek bir hareketin set / tekrar / süre / mola / dropset / süperset ayarı.
class _EditSheet extends StatefulWidget {
  final _DraftExercise item;
  final bool canLinkNext;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _EditSheet({
    required this.item,
    required this.canLinkNext,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _reps = TextEditingController(
    text: widget.item.reps,
  );

  _DraftExercise get e => widget.item;

  void _change(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }

  @override
  void dispose() {
    _reps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: formatExerciseName(e.ex.name),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepperRow(
            label: 'Set',
            value: e.sets,
            min: 1,
            max: 10,
            step: 1,
            onChanged: (v) => _change(() => e.sets = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SelectableChip(
                  label: 'Tekrar',
                  isSelected: !e.timed,
                  onTap: () => _change(() => e.timed = false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SelectableChip(
                  label: 'Süre',
                  isSelected: e.timed,
                  onTap: () => _change(() => e.timed = true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (e.timed)
            _StepperRow(
              label: 'Süre (sn)',
              value: e.duration,
              min: 5,
              max: 600,
              step: 5,
              onChanged: (v) => _change(() => e.duration = v),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: _cardDecoration(16),
              child: TextField(
                controller: _reps,
                cursorColor: AppColors.homeHero,
                style: AppTypography.body16Medium.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Tekrar (örn. 10 ya da 8-12)',
                  border: InputBorder.none,
                  labelStyle: AppTypography.body14Regular.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                onChanged: (v) {
                  e.reps = v.trim().isEmpty ? '10' : v.trim();
                  widget.onChanged();
                },
              ),
            ),
          const SizedBox(height: 12),
          _StepperRow(
            label: 'Dinlenme (sn)',
            value: e.rest,
            min: 0,
            max: 300,
            step: 15,
            onChanged: (v) => _change(() => e.rest = v),
          ),
          const SizedBox(height: 12),
          _StepperRow(
            label: 'Dropset (ek düşürme)',
            value: e.drops,
            min: 0,
            max: 4,
            step: 1,
            onChanged: (v) => _change(() => e.drops = v),
          ),
          if (e.drops > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                'Her setten sonra ara vermeden ${e.drops} kez ağırlığı azaltıp devam edersin.',
                style: AppTypography.body12Regular.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            decoration: _cardDecoration(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sonraki hareketle süperset',
                        style: AppTypography.body16Medium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.canLinkNext
                            ? 'Ara vermeden art arda yapılır, mola turun sonunda. Set sayısı ilk hareketinkine eşitlenir.'
                            : 'Önce altına bir hareket daha ekle.',
                        style: AppTypography.body12Regular.copyWith(
                          color: AppColors.textTertiary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: e.linkNext && widget.canLinkNext,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.espresso,
                  onChanged:
                      widget.canLinkNext
                          ? (v) {
                            HapticFeedback.selectionClick();
                            _change(() => e.linkNext = v);
                          }
                          : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: 'Sil',
                  icon: Icons.delete_outline_rounded,
                  variant: AppButtonVariant.outlined,
                  color: AppColors.error,
                  onPressed: () {
                    widget.onDelete();
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AppButton(
                  text: 'Tamam',
                  icon: Icons.check_rounded,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  const _StepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  Widget _btn(IconData icon, VoidCallback? onTap) {
    return Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: PressableScale(
        pressedScale: 0.88,
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: AppColors.fillSubtle,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: AppColors.homeHero),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
      decoration: _cardDecoration(16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.body16Medium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _btn(
            Icons.remove_rounded,
            value > min
                ? () => onChanged((value - step).clamp(min, max))
                : null,
          ),
          SizedBox(
            width: 52,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: AppTypography.body18Medium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _btn(
            Icons.add_rounded,
            value < max
                ? () => onChanged((value + step).clamp(min, max))
                : null,
          ),
        ],
      ),
    );
  }
}

/// 1300+ hareketlik havuzda arama ve kas grubu filtresi; dokunulan hareket
/// hemen güne eklenir (birden çok seçilebilir).
class _ExercisePicker extends StatefulWidget {
  final void Function(CatalogExercise) onAdd;
  const _ExercisePicker({required this.onAdd});

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  late final Future<List<CatalogExercise>> _future =
      ExerciseService.loadCatalog();
  String _query = '';
  String? _part;
  final Map<String, int> _added = {};

  @override
  Widget build(BuildContext context) {
    final total = _added.values.fold(0, (a, b) => a + b);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: _cardDecoration(16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            cursorColor: AppColors.homeHero,
                            style: AppTypography.body16Medium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Hareket ara (İngilizce ad)',
                              hintStyle: AppTypography.body16Medium.copyWith(
                                color: AppColors.textTertiary.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onChanged:
                                (v) => setState(
                                  () => _query = v.toLowerCase().trim(),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    total == 0 ? 'Kapat' : 'Bitti ($total)',
                    style: AppTypography.body14Medium.copyWith(
                      color: AppColors.homeHero,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _SmallChip(
                    label: 'Tümü',
                    selected: _part == null,
                    onTap: () => setState(() => _part = null),
                  ),
                ),
                for (final entry in _bodyPartLabels.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _SmallChip(
                      label: entry.value,
                      selected: _part == entry.key,
                      onTap: () => setState(() => _part = entry.key),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<CatalogExercise>>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.homeHero,
                    ),
                  );
                }
                final list =
                    snap.data!
                        .where(
                          (e) =>
                              (_part == null || e.bodyPart == _part) &&
                              (_query.isEmpty || e.searchKey.contains(_query)),
                        )
                        .toList();
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      'Sonuç yok',
                      style: AppTypography.body14Regular.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final e = list[i];
                    final n = _added[e.id] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PressableScale(
                        pressedScale: 0.985,
                        onTap: () {
                          widget.onAdd(e);
                          setState(() => _added[e.id] = n + 1);
                        },
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                          decoration: _cardDecoration(18),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      formatExerciseName(e.name),
                                      style: AppTypography.body14Medium
                                          .copyWith(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_bodyPartLabels[e.bodyPart] ?? e.bodyPart} · ${e.equipment}',
                                      style: AppTypography.body12Regular
                                          .copyWith(
                                            color: AppColors.textTertiary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              _RoundIconButton(
                                icon: Icons.info_outline_rounded,
                                onTap:
                                    () => showExerciseInfoDialog(
                                      context,
                                      exerciseId: e.id,
                                      name: e.name,
                                    ),
                              ),
                              Container(
                                width: 34,
                                height: 34,
                                margin: const EdgeInsets.only(right: 4),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color:
                                      n > 0
                                          ? AppColors.espresso
                                          : AppColors.goldTint,
                                  shape: BoxShape.circle,
                                ),
                                child:
                                    n > 0
                                        ? Text(
                                          '$n',
                                          style: AppTypography.body12Medium
                                              .copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        )
                                        : const Icon(
                                          Icons.add_rounded,
                                          size: 20,
                                          color: AppColors.goldDeep,
                                        ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SmallChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.96,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.espresso : Colors.white,
          borderRadius: BorderRadius.circular(45),
          border: Border.all(
            color: selected ? AppColors.espresso : AppColors.borderSubtle,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.body14Medium.copyWith(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
