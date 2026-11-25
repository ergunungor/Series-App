import '../models/program.dart';

/// Antrenman sırasındaki konum: hangi hareket, kaçıncı set, kaçıncı düşürme.
class SessionPos {
  final int exercise;
  final int set;

  /// 0 = normal çalışma seti, k>0 = k. dropset düşürmesi.
  final int drop;

  const SessionPos(this.exercise, this.set, [this.drop = 0]);

  @override
  bool operator ==(Object other) =>
      other is SessionPos &&
      other.exercise == exercise &&
      other.set == set &&
      other.drop == drop;

  @override
  int get hashCode => Object.hash(exercise, set, drop);

  @override
  String toString() => 'SessionPos($exercise, set $set, drop $drop)';
}

class SessionStep {
  final SessionPos pos;

  /// Bu adımdan sonra mola verilsin mi ([restSeconds] süresince).
  final bool rest;
  final int restSeconds;
  final bool finished;

  const SessionStep(
    this.pos, {
    this.rest = false,
    this.restSeconds = 0,
    this.finished = false,
  });
}

int groupStart(List<WorkoutExercise> list, int i) {
  final g = list[i].supersetGroup;
  if (g == null) return i;
  var s = i;
  while (s > 0 && list[s - 1].supersetGroup == g) {
    s--;
  }
  return s;
}

int groupEnd(List<WorkoutExercise> list, int i) {
  final g = list[i].supersetGroup;
  if (g == null) return i;
  var e = i;
  while (e + 1 < list.length && list[e + 1].supersetGroup == g) {
    e++;
  }
  return e;
}

/// Bir set tamamlanınca sıradaki konumu hesaplar:
/// 1. Dropset varsa ara vermeden sıradaki düşürme.
/// 2. Süpersette bloğun sıradaki hareketi, ara vermeden (aynı set numarası).
/// 3. Blok sonunda: turlar bitmediyse bloğun başına dönüp mola; bittiyse bir
///    sonraki harekete mola ile geçiş; hiçbiri kalmadıysa antrenman biter.
/// Süpersette tur sayısı bloğun ilk hareketinin set sayısıdır.
SessionStep advance(List<WorkoutExercise> list, SessionPos p) {
  final cur = list[p.exercise];

  if (cur.dropSets > 0 && p.drop < cur.dropSets) {
    return SessionStep(SessionPos(p.exercise, p.set, p.drop + 1));
  }

  final gs = groupStart(list, p.exercise);
  final ge = groupEnd(list, p.exercise);
  final rest = cur.restSeconds ?? 60;

  if (p.exercise < ge) {
    return SessionStep(SessionPos(p.exercise + 1, p.set));
  }

  final rounds = list[gs].sets;
  if (p.set + 1 < rounds) {
    return SessionStep(
      SessionPos(gs, p.set + 1),
      rest: true,
      restSeconds: rest,
    );
  }

  if (p.exercise + 1 < list.length) {
    return SessionStep(
      SessionPos(p.exercise + 1, 0),
      rest: true,
      restSeconds: rest,
    );
  }
  return SessionStep(p, finished: true);
}

/// Süperset bağları yalnızca art arda duran hareketlerde geçerli; sıralama
/// sonrası tek kalanların bağı kalkar, bloklarda mola son harekete taşınır.
List<WorkoutExercise> normalizeSupersets(List<WorkoutExercise> list) {
  final out = <WorkoutExercise>[];
  var i = 0;
  while (i < list.length) {
    final gs = groupStart(list, i);
    final ge = groupEnd(list, i);
    if (gs == ge) {
      final e = list[i];
      out.add(
        e.supersetGroup == null
            ? e
            : WorkoutExercise.fromJson({
              ...e.toJson(),
              'superset_group': null,
              'rest_seconds': (e.restSeconds ?? 0) > 0 ? e.restSeconds : 60,
            }),
      );
      i++;
      continue;
    }
    final rest = list
        .sublist(gs, ge + 1)
        .map((e) => e.restSeconds ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);
    for (var k = gs; k <= ge; k++) {
      out.add(
        WorkoutExercise.fromJson({
          ...list[k].toJson(),
          'rest_seconds': k == ge ? (rest > 0 ? rest : 60) : 0,
        }),
      );
    }
    i = ge + 1;
  }
  return out;
}
