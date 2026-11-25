import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/onboarding_data.dart';

class ProgramService {
  static Future<Map<String, dynamic>> generateProgram(
    OnboardingData data,
    String userId,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/generate-program');

    // GÜNCELLENDİ: Modele 'flash' parametresi ve 'gender' verisi ekleniyor
    final requestBody = data.toJson(userId);
    requestBody['model_type'] = 'flash'; // Hızlı üretim için

    // Not: Eğer onboarding_data.dart içindeki toJson() metoduna 'gender' eklemediysen
    // oraya da eklemen gerekiyor.

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      'Program oluşturulamadı (${response.statusCode}): ${response.body}',
    );
  }

  static Future<Map<String, dynamic>> reviseProgram(
    String userId,
    Map<String, dynamic> currentProgram,
    String prompt,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/revise-program');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'current_program': currentProgram,
        'prompt': prompt,
        'model_type': 'pro',
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    // Sunucunun Türkçe açıklamasını göster; ham yanıtı değil.
    String message = 'Program güncellenemedi. Lütfen tekrar dene.';
    try {
      final detail = jsonDecode(response.body)['detail'];
      if (detail is String && detail.isNotEmpty) message = detail;
    } catch (_) {}
    throw Exception(message);
  }

  static Future<String> saveProgram(
    String userId,
    Map<String, dynamic> programData,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/save-program');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'program': programData}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['program_id'].toString();
    }
    throw Exception('Program kaydedilemedi: ${response.body}');
  }
}
