import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'package:http_parser/http_parser.dart' as http_parser;

class ProgramImportService {
  /// Metin olarak program gönderir, yapay zekaya okutur ve veritabanına kaydeder
  static Future<void> importFromText(String text, String userId) async {
    // 1. ADIM: Metni yapay zekaya gönder (Backend Form data beklediği için 'body' map olarak verilir)
    final parseUri = Uri.parse('${ApiConfig.baseUrl}/api/parse-program');
    final parseResponse = await http.post(parseUri, body: {'text': text});

    if (parseResponse.statusCode != 200) {
      throw Exception(
        'Program analiz edilirken bir hata oluştu: ${parseResponse.body}',
      );
    }

    final parsedData = jsonDecode(parseResponse.body)['data'];

    // 2. ADIM: Yapay zekanın oluşturduğu JSON formatındaki programı Supabase'e kaydet
    await _saveProgramToDatabase(userId, parsedData);
  }

  static Future<void> importFromFile(File file, String userId) async {
    final parseUri = Uri.parse('${ApiConfig.baseUrl}/api/parse-program');

    // Dosya uzantısına göre MIME type belirliyoruz (Gemini hata vermesin diye)
    String mimeType = 'image/jpeg';
    if (file.path.endsWith('.png')) {
      mimeType = 'image/png';
    } else if (file.path.endsWith('.pdf')) {
      mimeType = 'application/pdf';
    }

    final request = http.MultipartRequest('POST', parseUri)
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: http_parser.MediaType.parse(
            mimeType,
          ), // MIME type eklendi
        ),
      );

    final streamedResponse = await request.send();
    final parseResponse = await http.Response.fromStream(streamedResponse);

    if (parseResponse.statusCode != 200) {
      throw Exception(
        'Dosya analiz edilirken bir hata oluştu: ${parseResponse.body}',
      );
    }

    final parsedData = jsonDecode(parseResponse.body)['data'];
    await _saveProgramToDatabase(userId, parsedData);
  }

  /// Arka planda çalışan ortak kayıt fonksiyonu
  static Future<void> _saveProgramToDatabase(
    String userId,
    Map<String, dynamic> programData,
  ) async {
    final saveUri = Uri.parse('${ApiConfig.baseUrl}/api/save-program');

    final saveResponse = await http.post(
      saveUri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'program': programData}),
    );

    if (saveResponse.statusCode != 200) {
      throw Exception(
        'Program veritabanına kaydedilirken bir hata oluştu: ${saveResponse.body}',
      );
    }
  }
}
