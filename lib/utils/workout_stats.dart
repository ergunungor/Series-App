import '../models/workout_history.dart';

/// 100 → "100", 116.67 → "116.7" (gösterim için).
String formatKg(double value) =>
    value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);

/// Bir egzersizin tek bir seanstaki en iyi performansı.
class StrengthPoint {
  final DateTime date;

  /// Tahmini 1TM (kg), puanın kendisi.
  final double score;
  final double weight;
  final int reps;

  const StrengthPoint({
    required this.date,
    required this.score,
    required this.weight,
    required this.reps,
  });
}

class ExerciseOption {
  final String name;
  final int sessionCount;

  const ExerciseOption({required this.name, required this.sessionCount});
}

/// Antrenman geçmişinden grafik ve özet verisi üretir. Yalnızca zaten çekilmiş
/// `WorkoutHistorySession` listesi üzerinde çalışır; ağ ya da veritabanı yok.
class WorkoutStats {
  WorkoutStats._();

  /// Epley formülü yüksek tekrarda şişer; bu sınırın üstündeki setler puana
  /// katılmaz.
  static const int maxRepsForEstimate = 12;

  /// Tahmini 1TM (Epley): `kg × (1 + tekrar / 30)`. Ağırlıksız (vücut ağırlığı)
  /// ya da çok yüksek tekrarlı setler için null.
  static double? estimated1RM(double weight, int reps) {
    if (weight <= 0 || reps < 1 || reps > maxRepsForEstimate) return null;
    return weight * (1 + reps / 30);
  }

  /// Puan alabilen egzersizler, en çok seansta yapılan ilk sırada.
  static List<ExerciseOption> exerciseOptions(
    List<WorkoutHistorySession> sessions,
  ) {
    final counts = <String, int>{};
    for (final session in sessions) {
      final seen = <String>{};
      for (final set in session.sets) {
        if (estimated1RM(set.weightUsed, set.repsPerformed) != null) {
          seen.add(set.exerciseName);
        }
      }
      for (final name in seen) {
        counts[name] = (counts[name] ?? 0) + 1;
      }
    }
    final options =
        counts.entries
            .map((e) => ExerciseOption(name: e.key, sessionCount: e.value))
            .toList();
    options.sort((a, b) {
      final byCount = b.sessionCount.compareTo(a.sessionCount);
      return byCount != 0 ? byCount : a.name.compareTo(b.name);
    });
    return options;
  }

  /// Her seans için egzersizin en yüksek puanlı seti, eskiden yeniye sıralı.
  static List<StrengthPoint> _allPoints(
    List<WorkoutHistorySession> sessions,
    String exerciseName,
  ) {
    final points = <StrengthPoint>[];
    for (final session in sessions) {
      StrengthPoint? best;
      for (final set in session.sets) {
        if (set.exerciseName != exerciseName) continue;
        final score = estimated1RM(set.weightUsed, set.repsPerformed);
        if (score == null) continue;
        if (best == null || score > best.score) {
          best = StrengthPoint(
            date: session.completedAt,
            score: score,
            weight: set.weightUsed,
            reps: set.repsPerformed,
          );
        }
      }
      if (best != null) points.add(best);
    }
    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  /// Grafik için son [limit] seansın puanları, eskiden yeniye.
  static List<StrengthPoint> strengthSeries(
    List<WorkoutHistorySession> sessions,
    String exerciseName, {
    int limit = 12,
  }) {
    final points = _allPoints(sessions, exerciseName);
    return points.length <= limit
        ? points
        : points.sublist(points.length - limit);
  }

  /// Egzersizin tüm geçmişindeki en yüksek puanlı noktası.
  static StrengthPoint? personalRecord(
    List<WorkoutHistorySession> sessions,
    String exerciseName,
  ) {
    StrengthPoint? record;
    for (final point in _allPoints(sessions, exerciseName)) {
      if (record == null || point.score > record.score) record = point;
    }
    return record;
  }

  /// Toplam kaldırılan ağırlık (kg × tekrar), tüm setler.
  static double totalVolumeKg(List<WorkoutHistorySession> sessions) {
    var total = 0.0;
    for (final session in sessions) {
      for (final set in session.sets) {
        total += set.weightUsed * set.repsPerformed;
      }
    }
    return total;
  }

  /// Son [weeks] haftanın seans sayıları, eskiden yeniye; sonuncusu içinde
  /// bulunulan hafta (pazartesi başlangıçlı).
  static List<int> weeklyCounts(
    List<WorkoutHistorySession> sessions,
    DateTime now, {
    int weeks = 8,
  }) {
    DateTime weekStart(DateTime d) =>
        DateTime(d.year, d.month, d.day - (d.weekday - 1));
    final firstWeek = weekStart(
      DateTime(now.year, now.month, now.day - 7 * (weeks - 1)),
    );
    final counts = List<int>.filled(weeks, 0);
    for (final session in sessions) {
      final start = weekStart(session.completedAt);
      // Yaz/kış saati farkı için saat cinsinden yuvarlıyoruz.
      final index = (start.difference(firstWeek).inHours / 168).round();
      if (index >= 0 && index < weeks) counts[index]++;
    }
    return counts;
  }
}
