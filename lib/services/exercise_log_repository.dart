import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/set_log.dart';
import '../models/workout_history.dart';

class ExerciseLogRepository {
  // Antrenman ekranı açılırken bu antrenmandaki tüm egzersizlerin en son ne
  // zaman/kaç tekrar/kaç kg ile yapıldığını TEK sorguda çekiyoruz. Set
  // değiştikçe tekrar tekrar sorgu atmak yerine sonucu Map olarak tutup
  // hafızadan okuyacağız — hem daha hızlı hem daha az network isteği.
  static Future<Map<String, LoggedSet>> fetchLastPerformance({
    required String userId,
    required List<String> exerciseNames,
  }) async {
    if (exerciseNames.isEmpty) return {};

    final rows = await Supabase.instance.client
        .from('exercise_logs')
        .select()
        .eq('user_id', userId)
        .inFilter('exercise_name', exerciseNames)
        .order('completed_at', ascending: false);

    // Sonuçlar en yeniden en eskiye sıralı geliyor. Aynı egzersiz+set
    // kombinasyonunu ilk gördüğümüz an, o zaten en güncel kayıt demektir —
    // bu yüzden putIfAbsent kullanıyoruz (ikinci/üçüncü eski kayıtları
    // görmezden geliyoruz).
    final Map<String, LoggedSet> result = {};
    for (final row in (rows as List)) {
      final log = LoggedSet.fromJson(row as Map<String, dynamic>);
      final key = '${log.exerciseName}|${log.setNumber}';
      result.putIfAbsent(key, () => log);
    }
    return result;
  }

  // Antrenman bittiğinde tüm set loglarını Supabase'e kaydeden metot
  static Future<void> saveSessionLogs({
    required String userId,
    required String workoutId,
    required String workoutName,
    required List<SetLog> logs,
  }) async {
    if (logs.isEmpty) return;

    final supabase = Supabase.instance.client;

    final data =
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
                'completed_at': DateTime.now().toIso8601String(),
              },
            )
            .toList();

    await supabase.from('exercise_logs').insert(data);
  }
}
