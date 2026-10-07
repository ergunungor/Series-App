import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // YENİ: rootBundle (lokal dosya okuma) için gerekli
import '../models/exercise.dart';

// Büyük egzersiz JSON'unu ayrı bir isolate'te çözer: ana (UI) thread'i bloklayıp
// ekranın takılmasına yol açmasın.
List<Exercise> _parseExercises(String jsonString) {
  final List<dynamic> data = json.decode(jsonString);
  return data.map((json) => Exercise.fromJson(json)).toList();
}

class ExerciseService {
  // Statik: her antrenman oturumunda yeni bir servis örneği oluşsa bile
  // egzersiz listesi uygulama boyunca bir kez çözülür.
  static List<Exercise>? _cachedAllExercises;

  // Artık isme, çeviriye veya yapay zekanın uydurmalarına ihtiyacımız yok.
  // Supabase'den gelen programdaki "id" değerini buraya veriyoruz.
  Future<Exercise?> fetchExerciseById(String id) async {
    try {
      if (_cachedAllExercises == null) {
        debugPrint('⚡ Lokal JSON okunuyor...');
        final String jsonString = await rootBundle.loadString(
          'assets/exercises.json',
        );
        _cachedAllExercises = await compute(_parseExercises, jsonString);
      }

      // ID'ler benzersiz olduğu için milisaniyede tam isabet bulur (%0 hata payı)
      final matchedExercise = _cachedAllExercises!.firstWhere(
        (exercise) => exercise.id == id,
      );

      return matchedExercise;
    } catch (e) {
      return null;
    }
  }
}
