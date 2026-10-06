import 'package:flutter_test/flutter_test.dart';
import 'package:series_app/models/workout_history.dart';
import 'package:series_app/utils/workout_stats.dart';

LoggedSet _set(String name, int reps, double kg, {int n = 1}) => LoggedSet(
  exerciseName: name,
  setNumber: n,
  repsPerformed: reps,
  weightUsed: kg,
);

WorkoutHistorySession _session(DateTime at, List<LoggedSet> sets) =>
    WorkoutHistorySession(
      workoutId: 'w',
      workoutName: 'Test',
      completedAt: at,
      sets: sets,
    );

void main() {
  const bench = 'barbell bench press';

  group('estimated1RM', () {
    test('ağır az tekrar, hafif çok tekrardan yüksek puan alır', () {
      expect(WorkoutStats.estimated1RM(80, 10), closeTo(106.67, 0.01));
      expect(WorkoutStats.estimated1RM(100, 5), closeTo(116.67, 0.01));
    });

    test('ağırlıksız ve 12 üstü tekrar puan almaz', () {
      expect(WorkoutStats.estimated1RM(0, 10), isNull);
      expect(WorkoutStats.estimated1RM(60, 13), isNull);
      expect(WorkoutStats.estimated1RM(60, 0), isNull);
      expect(WorkoutStats.estimated1RM(60, 12), isNotNull);
    });
  });

  group('exerciseOptions', () {
    test('seans sayısına göre sıralar, puanlanamayanı dışlar', () {
      final sessions = [
        _session(DateTime(2026, 3, 1), [
          _set(bench, 5, 100),
          _set('push-up', 15, 0),
        ]),
        _session(DateTime(2026, 3, 8), [
          _set(bench, 8, 90),
          _set('squat', 5, 120),
        ]),
      ];
      final options = WorkoutStats.exerciseOptions(sessions);
      expect(options.map((o) => o.name), [bench, 'squat']);
      expect(options.first.sessionCount, 2);
    });

    test('boş liste', () {
      expect(WorkoutStats.exerciseOptions([]), isEmpty);
    });
  });

  group('strengthSeries / personalRecord', () {
    final sessions = [
      // Yeni → eski sırada gelir (repository böyle döndürüyor).
      _session(DateTime(2026, 3, 8), [_set(bench, 5, 100)]),
      _session(DateTime(2026, 3, 1), [
        _set(bench, 10, 80),
        _set(bench, 5, 90, n: 2),
      ]),
    ];

    test('seans başına en iyi set, eskiden yeniye', () {
      final series = WorkoutStats.strengthSeries(sessions, bench);
      expect(series.length, 2);
      expect(series.first.date, DateTime(2026, 3, 1));
      // 10x80 = 106.67, 5x90 = 105 → 10x80 seçilir
      expect(series.first.reps, 10);
      expect(series.last.score, closeTo(116.67, 0.01));
    });

    test('limit son noktaları tutar', () {
      final series = WorkoutStats.strengthSeries(sessions, bench, limit: 1);
      expect(series.single.date, DateTime(2026, 3, 8));
    });

    test('rekor tüm geçmişten, bulunamazsa null', () {
      expect(WorkoutStats.personalRecord(sessions, bench)!.weight, 100);
      expect(WorkoutStats.personalRecord(sessions, 'yok'), isNull);
    });
  });

  test('totalVolumeKg tüm setleri toplar', () {
    final sessions = [
      _session(DateTime(2026, 3, 1), [_set(bench, 10, 80), _set('x', 5, 100)]),
    ];
    expect(WorkoutStats.totalVolumeKg(sessions), 1300);
    expect(WorkoutStats.totalVolumeKg([]), 0);
  });

  group('weeklyCounts', () {
    // 6 Ekim 2026 Salı; hafta pazartesi 5 Ekim'de başlar.
    final now = DateTime(2026, 10, 6, 12);

    test('bu hafta sonda, eski haftalar öncesinde', () {
      final sessions = [
        _session(DateTime(2026, 10, 5, 9), [_set(bench, 5, 100)]),
        _session(DateTime(2026, 10, 6, 9), [_set(bench, 5, 100)]),
        _session(DateTime(2026, 9, 29, 9), [_set(bench, 5, 100)]),
      ];
      final counts = WorkoutStats.weeklyCounts(sessions, now);
      expect(counts.length, 8);
      expect(counts.last, 2);
      expect(counts[6], 1);
    });

    test('aralık dışındaki seanslar sayılmaz', () {
      final sessions = [
        _session(DateTime(2026, 1, 1), [_set(bench, 5, 100)]),
      ];
      expect(
        WorkoutStats.weeklyCounts(sessions, now).every((c) => c == 0),
        true,
      );
    });
  });
}
