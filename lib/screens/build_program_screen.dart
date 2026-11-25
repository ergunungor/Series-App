import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/exercise_service.dart';
import '../services/program_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/exercise_name.dart';

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

  @override
  void dispose() {
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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

  @override
  Widget build(BuildContext context) {
    final items = _day.items;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.pop(false),
                  ),
                  Expanded(
                    child: Text(
                      'Program Oluştur',
                      style: AppTypography.heading2.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.espresso,
                      foregroundColor: Colors.white,
                    ),
                    child:
                        _saving
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Text('Kaydet'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: _fieldDecoration(
                  'Program adı (örn. Push Pull Legs)',
                ),
              ),
            ),
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                children: [
                  for (var i = 0; i < _days.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onLongPress: i == _selected ? _dayMenu : null,
                        child: ChoiceChip(
                          label: Text(_days[i].name),
                          selected: i == _selected,
                          onSelected: (_) => setState(() => _selected = i),
                          selectedColor: AppColors.espresso,
                          labelStyle: TextStyle(
                            color:
                                i == _selected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Gün'),
                    onPressed: _addDay,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      items.isEmpty
                          ? 'Henüz hareket yok'
                          : 'Sürükleyerek sırala · karta dokunarak düzenle',
                      style: AppTypography.body12Regular.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _dayMenu,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Günü düzenle'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: items.length,
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
                footer: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton.icon(
                    onPressed: _pickExercises,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Hareket ekle'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: AppColors.espresso,
                      side: BorderSide(
                        color: AppColors.espresso.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                itemBuilder: (context, i) {
                  final e = items[i];
                  final grouped =
                      e.linkNext || (i > 0 && items[i - 1].linkNext);
                  final startsGroup =
                      e.linkNext && !(i > 0 && items[i - 1].linkNext);
                  return Padding(
                    key: e.key,
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _edit(e),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color:
                                    grouped
                                        ? AppColors.accentGold
                                        : Colors.transparent,
                                width: 5,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (startsGroup)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: Text(
                                          'SÜPERSET',
                                          style: AppTypography.body12Medium
                                              .copyWith(
                                                color: AppColors.goldDeep,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 1.2,
                                              ),
                                        ),
                                      ),
                                    Text(
                                      formatExerciseName(e.ex.name),
                                      style: AppTypography.body16Medium
                                          .copyWith(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      e.summary,
                                      style: AppTypography.body12Regular
                                          .copyWith(
                                            color: AppColors.textTertiary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              ReorderableDragStartListener(
                                index: i,
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(String hint) => InputDecoration(
  hintText: hint,
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide.none,
  ),
);

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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatExerciseName(e.ex.name),
              style: AppTypography.heading3.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _StepperRow(
              label: 'Set',
              value: e.sets,
              min: 1,
              max: 10,
              step: 1,
              onChanged: (v) => _change(() => e.sets = v),
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Tekrar')),
                ButtonSegment(value: true, label: Text('Süre')),
              ],
              selected: {e.timed},
              onSelectionChanged: (s) => _change(() => e.timed = s.first),
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
              TextField(
                controller: _reps,
                decoration: _fieldDecoration('Tekrar (örn. 10 ya da 8-12)'),
                onChanged: (v) {
                  e.reps = v.trim().isEmpty ? '10' : v.trim();
                  widget.onChanged();
                },
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
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Her setten sonra ara vermeden ${e.drops} kez ağırlığı azaltıp devam edersin.',
                  style: AppTypography.body12Regular.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: e.linkNext && widget.canLinkNext,
              onChanged:
                  widget.canLinkNext
                      ? (v) {
                        HapticFeedback.selectionClick();
                        _change(() => e.linkNext = v);
                      }
                      : null,
              title: const Text('Sonraki hareketle süperset'),
              subtitle: Text(
                widget.canLinkNext
                    ? 'İkisi ara vermeden art arda yapılır, mola turun sonunda. Set sayısı ilk hareketinkine eşitlenir.'
                    : 'Önce altına bir hareket daha ekle.',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    widget.onDelete();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Hareketi sil'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.espresso,
                  ),
                  child: const Text('Tamam'),
                ),
              ],
            ),
          ],
        ),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
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
          IconButton(
            onPressed:
                value > min
                    ? () => onChanged((value - step).clamp(min, max))
                    : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: AppTypography.body18Medium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed:
                value < max
                    ? () => onChanged((value + step).clamp(min, max))
                    : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: _fieldDecoration(
                      'Hareket ara (İngilizce ad)',
                    ).copyWith(prefixIcon: const Icon(Icons.search_rounded)),
                    onChanged:
                        (v) => setState(() => _query = v.toLowerCase().trim()),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    _added.isEmpty
                        ? 'Kapat'
                        : 'Bitti (${_added.values.fold(0, (a, b) => a + b)})',
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Tümü'),
                    selected: _part == null,
                    onSelected: (_) => setState(() => _part = null),
                  ),
                ),
                for (final entry in _bodyPartLabels.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: _part == entry.key,
                      onSelected: (_) => setState(() => _part = entry.key),
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
                  return const Center(child: CircularProgressIndicator());
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
                  return const Center(child: Text('Sonuç yok'));
                }
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final e = list[i];
                    final n = _added[e.id] ?? 0;
                    return ListTile(
                      title: Text(formatExerciseName(e.name)),
                      subtitle: Text(
                        '${_bodyPartLabels[e.bodyPart] ?? e.bodyPart} · ${e.equipment}',
                      ),
                      trailing:
                          n > 0
                              ? Chip(label: Text('×$n'))
                              : const Icon(Icons.add_circle_outline_rounded),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onAdd(e);
                        setState(() => _added[e.id] = n + 1);
                      },
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
