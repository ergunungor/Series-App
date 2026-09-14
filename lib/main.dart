import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'router/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Supabase için gerekli
import 'package:intl/date_symbol_data_local.dart';
import 'package:app_links/app_links.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);

  await Supabase.initialize(
    url: 'https://scycflgsxpkgoouunptr.supabase.co', // Kopyaladığın URL
    publishableKey:
        'sb_publishable_6DIZ_1cdyXAFe1EXCKy3AA_ClBEe2ah', // Kopyaladığın Anon Key
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
    );
  }
}
