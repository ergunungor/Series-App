import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'router/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Supabase için gerekli

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://scycflgsxpkgoouunptr.supabase.co', // Kopyaladığın URL
    publishableKey:
        'sb_publishable_6DIZ_1cdyXAFe1EXCKy3AA_ClBEe2ah', // Kopyaladığın Anon Key
  );

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
