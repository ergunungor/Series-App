class ApiConfig {
  //static const String baseUrl = 'http://127.0.0.1:8000';
  static const String baseUrl = 'https://series-app-l56d.onrender.com';

  /// Supabase proje adresi.
  static const String supabaseUrl = 'https://scycflgsxpkgoouunptr.supabase.co';

  /// `supabase.co` engellenen ağlar için Cloudflare Worker vekili
  /// (bkz. cloudflare/supabase-proxy/README.md). Boşsa vekil kullanılmaz.
  /// Sonunda `/` olmamalı.
  static const String supabaseProxyUrl = '';
}
