import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/program.dart';

class ProgramRepository {
  static Future<List<ActiveProgram>> fetchPrograms(String userId) async {
    final client = Supabase.instance.client;

    final rows = await client
        .from('programs')
        .select('*, workouts(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (rows as List).map((row) {
      final workoutsJson = (row['workouts'] as List?) ?? [];
      final workouts =
          workoutsJson
              .map((w) => WorkoutDay.fromJson(w as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));

      return ActiveProgram(
        id: row['id'].toString(),
        name: row['name'] as String? ?? '',
        description: row['description'] as String? ?? '',
        workouts: workouts,
      );
    }).toList();
  }

  static Future<ActiveProgram?> fetchActiveProgram(String userId) async {
    final programs = await fetchPrograms(userId);
    return programs.isEmpty ? null : programs.first;
  }
}
