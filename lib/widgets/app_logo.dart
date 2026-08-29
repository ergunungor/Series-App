import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum AppLogoSize { small, medium, large }

enum AppLogoType { light, dark }

class AppLogo extends StatelessWidget {
  final AppLogoSize size;
  final AppLogoType type;

  const AppLogo({
    super.key,
    this.size = AppLogoSize.large,
    this.type = AppLogoType.dark,
  });

  @override
  Widget build(BuildContext context) {
    final double dimension = switch (size) {
      AppLogoSize.large => 180,
      AppLogoSize.medium => 112,
      AppLogoSize.small => 56,
    };
    return SvgPicture.asset(
      'assets/images/series_logo.svg',
      width: dimension,
      height: dimension,
      colorFilter:
          type == AppLogoType.light
              ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
              : null,
    );
  }
}
