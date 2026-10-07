import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Ekranların üstündeki ortalı "SERIES" yazısı. Tüm sekmelerde aynı yükseklik
/// ve konumda durması için tek yerde tanımlı.
class SeriesWordmark extends StatelessWidget {
  /// Koyu hero üzerinde krem kullanmak için değiştirilebilir.
  final Color color;

  const SeriesWordmark({super.key, this.color = AppColors.homeHeroDeep});

  static const double _letterSpacing = 4;

  @override
  Widget build(BuildContext context) {
    return Center(
      // letterSpacing son harften sonra da boşluk bıraktığı için yazı optik olarak
      // sola kayar; aynı miktarı soldan ekleyerek ortalıyoruz.
      child: Padding(
        padding: const EdgeInsets.only(left: _letterSpacing),
        child: Text(
          'SERIES',
          style: AppTypography.body14Medium.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: _letterSpacing,
          ),
        ),
      ),
    );
  }
}
