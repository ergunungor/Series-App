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
import '../screens/workout_session_screen.dart';
import '../widgets/main_shell.dart';
import '../screens/onboarding_survey_screen.dart';
import '../screens/program_detail_screen.dart';
import '../models/program.dart';
import '../screens/workout_day_detail_screen.dart';
import '../screens/workout_history_detail_screen.dart';
import '../models/workout_history.dart';

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
      // yeni:
      GoRoute(
        path: '/workout-player',
        builder:
            (context, state) =>
                WorkoutSessionScreen(workout: state.extra as WorkoutDay),
      ),
      GoRoute(
        path: '/onboarding-survey',
        builder: (context, state) => const OnboardingSurveyScreen(),
      ),
      // workout-session rotası için:
      GoRoute(
        path: '/workout-session',
        builder: (context, state) {
          final workout = state.extra as WorkoutDay?;
          if (workout == null) {
            // Eğer tarayıcı yenilendiyse veya extra kaybolduysa ana sayfaya düş
            return const HomeScreen();
          }
          return WorkoutSessionScreen(workout: workout);
        },
      ),

      // program-detail rotası için:
      GoRoute(
        path: '/program-detail',
        builder: (context, state) {
          final program = state.extra as ActiveProgram?;
          if (program == null) {
            return const ProgramsScreen();
          }
          return ProgramDetailScreen(program: program);
        },
      ),
      GoRoute(
        path: '/workout-day-detail',
        builder:
            (context, state) =>
                WorkoutDayDetailScreen(workout: state.extra as WorkoutDay),
      ),
      GoRoute(
        path: '/workout-history-detail',
        builder:
            (context, state) => WorkoutHistoryDetailScreen(
              session: state.extra as WorkoutHistorySession,
            ),
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
