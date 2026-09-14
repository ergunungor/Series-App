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
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data.toJson(userId)),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      'Program oluşturulamadı (${response.statusCode}): ${response.body}',
    );
  }

  // YENİ: Yapay zekadan programı revize etmesini ister (Geriye MAP döner)
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
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 429) {
      // 429 Gemini yoğunluk hatasını burada yakalıyoruz
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['detail']);
    }
    throw Exception('Program güncellenemedi: ${response.body}');
  }

  // YENİ: Revize edilen programı veritabanına kaydeder (Geriye STRING ID döner)
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
      // Hatanın çözüldüğü yer: Tüm MAP'i değil, sadece ID'yi String olarak döndürüyoruz
      return data['program_id'].toString();
    }
    throw Exception('Program kaydedilemedi: ${response.body}');
  }
}
