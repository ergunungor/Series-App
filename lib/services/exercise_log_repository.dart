import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/set_log.dart';

class ExerciseLogRepository {
  static Future<void> saveSessionLogs({
    required String userId,
    required String workoutId,
    required String workoutName,
    required List<SetLog> logs,
  }) async {
    if (logs.isEmpty) return;

    final completedAt = DateTime.now().toIso8601String();

    final rows =
        logs
            .map(
              (log) => {
                'user_id': userId,
                'workout_id': workoutId,
                'workout_name': workoutName,
                'exercise_name': log.exerciseName,
                'set_number': log.setNumber,
                'reps_performed': log.repsPerformed,
                'weight_used': log.weightUsed,
                'completed_at': completedAt,
              },
            )
            .toList();

    await Supabase.instance.client.from('exercise_logs').insert(rows);
  }
}
