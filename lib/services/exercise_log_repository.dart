import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/set_log.dart';

class ExerciseLogRepository {
  static Future<void> saveSessionLogs({
    required String userId,
    required String workoutId,
    required List<SetLog> logs,
  }) async {
    if (logs.isEmpty) return;

    final rows =
        logs
            .map(
              (log) => {
                'user_id': userId,
                'workout_id': workoutId,
                'exercise_name': log.exerciseName,
                'set_number': log.setNumber,
                'reps_performed': log.repsPerformed,
                'weight_used': log.weightUsed,
                'completed_at': DateTime.now().toIso8601String(),
              },
            )
            .toList();

    await Supabase.instance.client.from('exercise_logs').insert(rows);
  }
}
