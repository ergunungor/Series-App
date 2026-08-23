import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/program.dart';

class ProgramRepository {
  static Future<ActiveProgram?> fetchActiveProgram(String userId) async {
    final client = Supabase.instance.client;

    final programRows = await client
        .from('programs')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1);

    if (programRows.isEmpty) return null;

    final programRow = programRows.first;
    final programId = programRow['id'];

    final workoutRows = await client
        .from('workouts')
        .select()
        .eq('program_id', programId)
        .order('day_number', ascending: true);

    final workouts =
        (workoutRows as List)
            .map((row) => WorkoutDay.fromJson(row as Map<String, dynamic>))
            .toList();

    return ActiveProgram(
      id: programId.toString(),
      name: programRow['name'] as String? ?? '',
      description: programRow['description'] as String? ?? '',
      workouts: workouts,
    );
  }
}
