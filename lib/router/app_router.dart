import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/verification_screen.dart';
import '../screens/home_screen.dart';
import '../screens/programs_screen.dart';
import '../screens/workouts_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/workout_player_screen.dart';
import '../screens/workout_break_screen.dart';
import '../widgets/main_shell.dart';
import '../screens/onboarding_survey_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      // ── DEĞİŞMEDİ ──
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/login',
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const LoginScreen(),
              transitionDuration: const Duration(milliseconds: 500),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                final curvedAnimation = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut,
                );
                return FadeTransition(opacity: curvedAnimation, child: child);
              },
            ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const RegisterScreen(),
              transitionDuration: const Duration(milliseconds: 500),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                final curvedAnimation = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut,
                );
                return FadeTransition(opacity: curvedAnimation, child: child);
              },
            ),
      ),
      GoRoute(
        path: '/verification',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final fullName = extra['fullName'] as String? ?? '';
          final email = extra['email'] as String? ?? '';
          return VerificationScreen(fullName: fullName, email: email);
        },
      ),
      GoRoute(
        path: '/workout-player',
        builder: (context, state) => const WorkoutPlayerScreen(),
      ),
      GoRoute(
        path: '/workout-break',
        builder: (context, state) => const WorkoutBreakScreen(),
      ),
      // '/workout-break' route'undan hemen sonra ekle:
      GoRoute(
        path: '/onboarding-survey',
        builder: (context, state) => const OnboardingSurveyScreen(),
      ),

      // ── YENİ: bottom nav shell ──
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(
            currentIndex: navigationShell.currentIndex,
            onTap:
                (index) => navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                ),
            child: navigationShell,
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/programs',
                builder: (context, state) => const ProgramsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/workouts',
                builder: (context, state) => const WorkoutsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
