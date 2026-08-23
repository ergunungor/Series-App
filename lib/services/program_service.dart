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
}
