import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/home_screen.dart';
import '../screens/workout_player_screen.dart';
import '../screens/workout_break_screen.dart';
import 'package:flutter/material.dart';
import '../screens/verification_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/login',
        // builder yerine pageBuilder kullanıyoruz:
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const LoginScreen(), // Splash'ten sonra gideceği ekran
              // 500ms süreyi burada belirliyoruz:
              transitionDuration: const Duration(milliseconds: 500),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                // Animasyon eğrisini (Ease In Out) burada tanımlıyoruz:
                final curvedAnimation = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut, // Senin istediğin eğri
                );

                // Yumuşak bir Fade (Erime/Görünürlük) efekti uyguluyoruz:
                return FadeTransition(opacity: curvedAnimation, child: child);
              },
            ),
      ),

      GoRoute(
        path: '/register',
        // builder yerine pageBuilder kullanıyoruz:
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const RegisterScreen(),
              // 500ms süreyi burada belirliyoruz:
              transitionDuration: const Duration(milliseconds: 500),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                // Animasyon eğrisini (Ease In Out) burada tanımlıyoruz:
                final curvedAnimation = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut, // Senin istediğin eğri
                );

                // Yumuşak bir Fade (Erime/Görünürlük) efekti uyguluyoruz:
                return FadeTransition(opacity: curvedAnimation, child: child);
              },
            ),
      ),
      GoRoute(
        path: '/verification',
        builder: (context, state) {
          // RegisterScreen'den gönderdiğimiz extra map'ini yakalıyoruz
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final fullName = extra['fullName'] as String? ?? '';
          final email = extra['email'] as String? ?? '';

          return VerificationScreen(fullName: fullName, email: email);
        },
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/workout-player',
        builder: (context, state) => const WorkoutPlayerScreen(),
      ),
      GoRoute(
        path: '/workout-break',
        builder: (context, state) => const WorkoutBreakScreen(),
      ),
    ],
  );
}
