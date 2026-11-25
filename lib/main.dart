import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'router/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Supabase için gerekli
import 'package:intl/date_symbol_data_local.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/services.dart';
import 'config/api_config.dart';
import 'services/app_settings.dart';
import 'services/supabase_endpoint.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);
  // Ses ayarları (set arası sesler, müzikle karışma) ve ses oturumu.
  await AppSettings.instance.load();

  // Doğrudan erişilemiyorsa (supabase.co engelli ağ) vekil adres kullanılır.
  final supabaseUrl = await SupabaseEndpoint.resolve();

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey:
        'sb_publishable_6DIZ_1cdyXAFe1EXCKy3AA_ClBEe2ah', // Kopyaladığın Anon Key
    authOptions: FlutterAuthClientOptions(
      // Oturum anahtarı adresten türetilir; vekil/doğrudan geçişte kullanıcı
      // çıkış yapmış olmasın diye proje adresine göre sabitlenir.
      localStorage: SharedPreferencesLocalStorage(
        persistSessionKey:
            'sb-${Uri.parse(ApiConfig.supabaseUrl).host.split('.').first}-auth-token',
      ),
    ),
  );

  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen((uri) {
    if (uri.scheme == 'seriesfit' && uri.host == 'reset-password') {
      AppRouter.router.go('/reset-password');
    }
  });

  runApp(const SeriesApp());
}

class SeriesApp extends StatelessWidget {
  const SeriesApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp yerine MaterialApp.router kullanıyoruz
    return MaterialApp.router(
      title: 'Series',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: AppRouter.router, // Trafik polisimizi buraya atadık
      // Varsayılan durum çubuğu: açık zeminde koyu simgeler. Koyu hero'lu
      // ekranlar kendi AnnotatedRegion'ı ile bunu geçersiz kılar.
      builder:
          (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarBrightness: Brightness.light,
              statusBarIconBrightness: Brightness.dark,
            ),
            child: child ?? const SizedBox.shrink(),
          ),
    );
  }
}
