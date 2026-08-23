import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_bottom_nav.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const MainShell({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // yeni:
    return Scaffold(
      backgroundColor: AppColors.background,
      body: child,
      bottomNavigationBar: SafeArea(
        child: AppBottomNav(currentIndex: currentIndex, onTap: onTap),
      ),
    );
  }
}
