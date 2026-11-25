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

/// Egzersiz havuzundan program kurarken seçilebilen hafif kayıt.
class CatalogExercise {
  final String id;
  final String name;
  final String bodyPart;
  final String equipment;
  final String searchKey;

  const CatalogExercise({
    required this.id,
    required this.name,
    required this.bodyPart,
    required this.equipment,
    required this.searchKey,
  });
}

List<CatalogExercise> _parseCatalog(String jsonString) {
  final List<dynamic> data = json.decode(jsonString);
  return [
    for (final e in data)
      CatalogExercise(
        id: e['id'].toString(),
        name: (e['name'] ?? '').toString(),
        bodyPart: (e['body_part'] ?? '').toString(),
        equipment: (e['equipment'] ?? '').toString(),
        searchKey:
            '${e['name']} ${e['target'] ?? ''} ${e['equipment'] ?? ''}'
                .toLowerCase(),
      ),
  ];
}

class ExerciseService {
  static List<CatalogExercise>? _catalog;

  /// Tüm havuz (1300+ hareket), uygulama boyunca bir kez çözülür.
  static Future<List<CatalogExercise>> loadCatalog() async {
    if (_catalog != null) return _catalog!;
    final jsonString = await rootBundle.loadString('assets/exercises.json');
    final list = await compute(_parseCatalog, jsonString);
    list.sort((a, b) => a.name.compareTo(b.name));
    return _catalog = list;
  }

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
