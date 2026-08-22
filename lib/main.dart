import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/workout_break_screen.dart';

void main() {
  runApp(const SeriesApp());
}

class SeriesApp extends StatelessWidget {
  const SeriesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Series',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const WorkoutBreakScreen(),
    );
  }
}
