import 'package:flutter_test/flutter_test.dart';
import 'package:series_app/models/program.dart';

void main() {
  test('superset ve dropset alanları JSON gidiş-dönüşte korunur', () {
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
    expect(plain.dropSets, 0);
    expect(plain.toJson().containsKey('drop_sets'), isFalse);
  });
}
