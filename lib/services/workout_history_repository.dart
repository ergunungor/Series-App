import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout_history.dart';

class WorkoutHistoryRepository {
  static Future<List<WorkoutHistorySession>> fetchHistory(String userId) async {
    final rows = await Supabase.instance.client
        .from('exercise_logs')
        .select()
        .eq('user_id', userId)
        .order('completed_at', ascending: false);

    final Map<String, List<LoggedSet>> setsBySession = {};
    final Map<String, String> nameBySession = {};
    final Map<String, String> workoutIdBySession = {};
    final Map<String, DateTime> dateBySession = {};

    for (final row in (rows as List)) {
      final workoutId = row['workout_id'].toString();
      final completedAtStr = row['completed_at'] as String;
      final key = '$workoutId|$completedAtStr';

      setsBySession
          .putIfAbsent(key, () => [])
          .add(LoggedSet.fromJson(row as Map<String, dynamic>));
      nameBySession[key] = row['workout_name'] as String? ?? 'Antrenman';
      workoutIdBySession[key] = workoutId;
      dateBySession[key] = DateTime.parse(completedAtStr);
    }

    final result =
        setsBySession.entries
            .map(
              (entry) => WorkoutHistorySession(
                workoutId: workoutIdBySession[entry.key]!,
                workoutName: nameBySession[entry.key]!,
                completedAt: dateBySession[entry.key]!,
                sets: entry.value,
              ),
            )
            .toList();

    // yeni:
    result.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return result;
  }

  static Future<void> deleteSession(WorkoutHistorySession session) async {
    // Bir "seans" aslında exercise_logs'ta aynı workout_id + completed_at'e
    // sahip birden fazla satır (her set kendi satırı). İkisini birlikte
    // eşleştirerek sadece bu seansın satırlarını siliyoruz, başka bir
    // seansı (aynı antrenmanın farklı bir tekrarını) yanlışlıkla silmiyoruz.
    await Supabase.instance.client
        .from('exercise_logs')
        .delete()
        .eq('workout_id', session.workoutId)
        .eq('completed_at', session.completedAt.toIso8601String());
  }
}
