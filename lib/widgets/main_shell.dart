import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    // 1. iOS sistem alt çubuğunun (Home Indicator) arkayı beyaza boyamasını engeller
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        // 2. DİKKAT: bottomNavigationBar parametresi TAMAMEN silindi!
        body: Stack(
          children: [
            // Arka Katman: Sayfanın kendisi (Aşağıya kadar tam ekran uzanır)
            Positioned.fill(child: child),

            // Ön Katman: Havada süzülen Navigator
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: AppBottomNav(currentIndex: currentIndex, onTap: onTap),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
