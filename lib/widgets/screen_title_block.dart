import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Sekme ekranlarının ortak başlık bloğu: eyebrow + büyük başlık, sağda
/// opsiyonel eylem butonu. Programlar ve Antrenmanlar aynı yükseklikte ve
/// konumda dursun diye tek yerde tanımlı.
class ScreenTitleBlock extends StatelessWidget {
  final String eyebrow;
  final String title;
  final Color titleColor;
  final Color eyebrowColor;
  final Widget? trailing;

  const ScreenTitleBlock({
    super.key,
    required this.eyebrow,
    required this.title,
    this.titleColor = AppColors.textPrimary,
    this.eyebrowColor = AppColors.textTertiary,
    this.trailing,
  });

  static const double _eyebrowLineHeight = 20;
  static const double _gap = 2;
  static const double _titleFontSize = 34;
  // heading1 satır yüksekliği 38/28 oranında; fontSize 34'e büyütülünce orantılı.
  static const double _titleLineHeight = _titleFontSize * 38 / 28;

  /// Başlık bloğunun yüksekliği. Seçim modu gibi alternatif satırlar bu
  /// yükseklikte çizilirse mod değişiminde sayfa zıplamaz.
  static const double height = _eyebrowLineHeight + _gap + _titleLineHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: AppTypography.body18Medium.copyWith(
                    color: eyebrowColor,
                  ),
                ),
                const SizedBox(height: _gap),
                Text(
                  title,
                  style: AppTypography.heading1.copyWith(
                    color: titleColor,
                    fontSize: _titleFontSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
