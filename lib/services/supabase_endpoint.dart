import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Supabase'e hangi adresten bağlanılacağını seçer.
///
/// Önce doğrudan adres denenir; herhangi bir HTTP yanıtı gelirse (401 dahil)
/// erişilebilir sayılır. Zaman aşımı ya da bağlantı hatası olursa (ör.
/// `supabase.co` engelli ağ) ve vekil adresi tanımlıysa vekil kullanılır.
class SupabaseEndpoint {
  static const Duration _probeTimeout = Duration(seconds: 3);

  static Future<String> resolve() async {
    final proxy = ApiConfig.supabaseProxyUrl;
    if (proxy.isEmpty || kIsWeb) return ApiConfig.supabaseUrl;

    try {
      await http
          .get(Uri.parse('${ApiConfig.supabaseUrl}/auth/v1/health'))
          .timeout(_probeTimeout);
      return ApiConfig.supabaseUrl;
    } catch (e) {
      debugPrint('Supabase doğrudan erişilemedi, vekil kullanılıyor: $e');
      return proxy;
    }
  }
}
