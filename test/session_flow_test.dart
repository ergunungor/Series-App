import 'package:flutter_test/flutter_test.dart';
import 'package:series_app/models/program.dart';
import 'package:series_app/utils/session_flow.dart';

WorkoutExercise ex(
  String name, {
  int sets = 3,
  int rest = 60,
  int? group,
  int drops = 0,
}) => WorkoutExercise(
  id: name,
  name: name,
  sets: sets,
  reps: '10',
  restSeconds: rest,
  supersetGroup: group,
  dropSets: drops,
);

/// Antrenmanı baştan sona oynatır; her tamamlanan set için
/// "hareket:set[:drop]" ve ardından mola varsa "(mola N)" yazar.
List<String> play(List<WorkoutExercise> list) {
  final out = <String>[];
  var pos = const SessionPos(0, 0);
  for (var guard = 0; guard < 500; guard++) {
    final label =
        '${list[pos.exercise].name}:${pos.set + 1}${pos.drop > 0 ? ':d${pos.drop}' : ''}';
    final step = advance(list, pos);
    out.add(step.finished ? '$label (bitti)' : label);
    if (step.finished) return out;
    if (step.rest) out.add('(mola ${step.restSeconds})');
    pos = step.pos;
  }
  fail('antrenman bitmedi');
}

void main() {
  test('süpersetsiz: set set ilerler, hareket sonunda da mola', () {
    expect(play([ex('A', sets: 2), ex('B', sets: 1)]), [
      'A:1',
      '(mola 60)',
      'A:2',
      '(mola 60)',
      'B:1 (bitti)',
    ]);
  });

  test('süperset: ara vermeden art arda, mola turun sonunda', () {
    final list = [
      ex('A', sets: 2, rest: 0, group: 1),
      ex('B', sets: 2, rest: 90, group: 1),
      ex('C', sets: 1),
    ];
    expect(play(list), [
      'A:1',
      'B:1',
      '(mola 90)',
      'A:2',
      'B:2',
      '(mola 90)',
      'C:1 (bitti)',
    ]);
  });

  test('üçlü süperset (giant set) tüm halkaları gezer', () {
    final list = [
      ex('A', sets: 2, rest: 0, group: 1),
      ex('B', sets: 2, rest: 0, group: 1),
      ex('C', sets: 2, rest: 45, group: 1),
    ];
    expect(play(list), [
      'A:1',
      'B:1',
      'C:1',
      '(mola 45)',
      'A:2',
      'B:2',
      'C:2 (bitti)',
    ]);
  });

  test('iki ayrı süperset ve aradaki normal hareket', () {
    final list = [
      ex('A', sets: 1, rest: 0, group: 1),
      ex('B', sets: 1, rest: 30, group: 1),
      ex('C', sets: 1, rest: 40),
      ex('D', sets: 1, rest: 0, group: 2),
      ex('E', sets: 1, rest: 20, group: 2),
    ];
    expect(play(list), [
      'A:1',
      'B:1',
      '(mola 30)',
      'C:1',
      '(mola 40)',
      'D:1',
      'E:1 (bitti)',
    ]);
  });

  test('dropset: her setten sonra ara vermeden düşürmeler, sonra mola', () {
    expect(play([ex('A', sets: 2, drops: 2)]), [
      'A:1',
      'A:1:d1',
      'A:1:d2',
      '(mola 60)',
      'A:2',
      'A:2:d1',
      'A:2:d2 (bitti)',
    ]);
  });

  test('süperset içinde dropset: düşürmeler hareketin hemen ardından', () {
    final list = [
      ex('A', sets: 1, rest: 0, group: 1, drops: 1),
      ex('B', sets: 1, rest: 60, group: 1),
    ];
    expect(play(list), ['A:1', 'A:1:d1', 'B:1 (bitti)']);
  });

  test('set sayısı bloğun ilk hareketine göre eşitlenir', () {
    final list = [
      ex('A', sets: 2, rest: 0, group: 1),
      ex('B', sets: 5, rest: 30, group: 1),
    ];
    expect(play(list).where((l) => l.startsWith('B')).length, 2);
  });

  test('süperset alanları JSON gidiş-dönüşte korunur', () {
    final e = WorkoutExercise.fromJson({
      'id': '1',
      'name': 'x',
      'sets': 3,
      'reps': '10',
      'superset_group': 2,
      'drop_sets': 2,
    });
    expect(e.supersetGroup, 2);
    expect(e.dropSets, 2);
    final j = e.toJson();
    expect(j['superset_group'], 2);
    expect(j['drop_sets'], 2);
    final plain = WorkoutExercise.fromJson({'id': '2', 'name': 'y'});
    expect(plain.supersetGroup, isNull);
    expect(plain.toJson().containsKey('drop_sets'), isFalse);
  });
}
