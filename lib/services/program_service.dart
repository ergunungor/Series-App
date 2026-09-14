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
        'model_type':
            'pro', // GÜNCELLENDİ: Zeki revizeler için Pro modeli gönderiliyor
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 429) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['detail']);
    }
    throw Exception('Program güncellenemedi: ${response.body}');
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
