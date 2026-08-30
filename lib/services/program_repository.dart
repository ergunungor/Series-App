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

  static Future<String?> fetchActiveProgramId(String userId) async {
    final row =
        await Supabase.instance.client
            .from('profiles')
            .select('active_program_id')
            .eq('id', userId)
            .single();
    return row['active_program_id'] as String?;
  }

  static Future<void> setActiveProgram(String userId, String programId) async {
    await Supabase.instance.client
        .from('profiles')
        .update({'active_program_id': programId})
        .eq('id', userId);
  }

  static Future<ActiveProgram?> fetchActiveProgram(String userId) async {
    final programs = await fetchPrograms(userId);
    if (programs.isEmpty) return null;

    final activeId = await fetchActiveProgramId(userId);
    if (activeId != null) {
      final match = programs.where((p) => p.id == activeId);
      if (match.isNotEmpty) return match.first;
    }
    // Henüz seçim yapılmamışsa (veya seçili program silinmişse) en son
    // oluşturulana geri dönüyoruz — eski davranış, güvenli varsayılan.
    return programs.first;
  }

  static Future<void> deleteProgram(String programId) async {
    final client = Supabase.instance.client;
    await client.from('workouts').delete().eq('program_id', programId);
    await client.from('programs').delete().eq('id', programId);
  }
}
