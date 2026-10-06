import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Haftalık antrenman sayısı çubukları. Son çubuk (bu hafta) koyu yeşil, geçmiş
/// haftalar nötr. Dokununca çubuğun üstünde sayı görünür.
class WeeklyBarsChart extends StatefulWidget {
  /// Eskiden yeniye; sonuncusu içinde bulunulan hafta.
  final List<int> counts;
  final TextStyle? labelStyle;

  const WeeklyBarsChart({super.key, required this.counts, this.labelStyle});

  static const double height = 124;

  @override
  State<WeeklyBarsChart> createState() => _WeeklyBarsChartState();
}

class _WeeklyBarsChartState extends State<WeeklyBarsChart>
    with TickerProviderStateMixin {
  static const Duration _growDuration = Duration(milliseconds: 700);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _growDuration,
  )..forward();
  late int _selected = widget.counts.length - 1;

  // Dokunma ("hover") geri bildirimi: parmak değdiği çubuk hafifçe yükselir,
  // koyulaşır ve altında yumuşak bir gölge belirir; parmak kalkınca geri döner.
  late final AnimationController _hover = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  int? _hoverIndex;

  int _indexAt(double dx, double width) => (dx / width * widget.counts.length)
      .floor()
      .clamp(0, widget.counts.length - 1);

  void _press(double dx, double width) {
    final index = _indexAt(dx, width);
    if (index != _hoverIndex) {
      _hoverIndex = index;
      _select(index);
    }
    _hover.forward();
  }

  void _release() => _hover.reverse();

  @override
  void dispose() {
    _hover.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == _selected) return;
    HapticFeedback.selectionClick();
    setState(() => _selected = index);
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle =
        widget.labelStyle ??
        AppTypography.body12Regular.copyWith(color: AppColors.textTertiary);
    final counts = widget.counts;
    return Semantics(
      label:
          'Son ${counts.length} haftanın antrenman sayıları. '
          'Bu hafta ${counts.last} antrenman.',
      child: ExcludeSemantics(
        child: SizedBox(
          height: WeeklyBarsChart.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _press(d.localPosition.dx, width),
                onTapUp: (_) => _release(),
                onTapCancel: _release,
                // Parmağı çubuklar üzerinde kaydırınca vurgu ve seçim onu izler.
                onHorizontalDragStart: (d) => _press(d.localPosition.dx, width),
                onHorizontalDragUpdate:
                    (d) => _press(d.localPosition.dx, width),
                onHorizontalDragEnd: (_) => _release(),
                onHorizontalDragCancel: _release,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_controller, _hover]),
                  builder:
                      (context, _) => CustomPaint(
                        size: Size(width, WeeklyBarsChart.height),
                        painter: _BarsPainter(
                          counts: counts,
                          selected: _selected,
                          progress: _controller.value,
                          hoverIndex: _hoverIndex,
                          hoverT: Curves.easeOut.transform(_hover.value),
                          labelStyle: labelStyle,
                        ),
                      ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<int> counts;
  final int selected;
  final double progress;
  final int? hoverIndex;
  final double hoverT;
  final TextStyle labelStyle;

  _BarsPainter({
    required this.counts,
    required this.selected,
    required this.progress,
    required this.hoverIndex,
    required this.hoverT,
    required this.labelStyle,
  });

  static const double _gap = 10;
  static const double _radius = 7;
  static const double _topLabelSpace = 36;
  static const double _bottomLabelSpace = 16;
  static const double _emptyBarHeight = 6;
  static const double _pillGap = 6;
  static const double _pillSize = 26;
  static const double _pillPadX = 7;
  // Çubuklar soldan sağa sırayla büyür; her biri toplam sürenin bir diliminde.
  static const double _staggerSpan = 0.5;
  // Dokunulan çubuğun yükselmesi, yana genişlemesi ve koyulaşması.
  static const double _hoverLift = 8;
  static const double _hoverGrow = 3;
  static const Color _hoverNeutral = Color(0xFFDDD6CC);

  @override
  void paint(Canvas canvas, Size size) {
    final n = counts.length;
    final barWidth = (size.width - _gap * (n - 1)) / n;
    final maxCount = math.max(1, counts.reduce(math.max));
    final plotHeight = size.height - _topLabelSpace - _bottomLabelSpace;
    final baseline = size.height - _bottomLabelSpace;

    for (var i = 0; i < n; i++) {
      final start = n == 1 ? 0.0 : _staggerSpan * i / (n - 1);
      final t = Curves.easeOutCubic.transform(
        ((progress - start) / (1 - _staggerSpan)).clamp(0.0, 1.0),
      );
      final full =
          counts[i] == 0
              ? _emptyBarHeight
              : math.max(_emptyBarHeight, plotHeight * counts[i] / maxCount);
      final isHovered = i == hoverIndex;
      final hv = isHovered ? hoverT : 0.0;
      final lift = _hoverLift * hv;
      final grow = _hoverGrow * hv;
      final h = full * t + (t >= 1 ? lift : 0);
      final left = i * (barWidth + _gap) - grow;
      final isCurrent = i == n - 1;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, baseline - h, barWidth + grow * 2, h),
        const Radius.circular(_radius),
      );
      final baseColor =
          isCurrent ? AppColors.workoutsHero : AppColors.fillSubtle;
      final hoverColor = isCurrent ? AppColors.workoutsHeroDeep : _hoverNeutral;
      if (hv > 0) {
        // Dokunulan çubuğun altında yumuşak gölge.
        canvas.drawRRect(
          rect.shift(const Offset(0, 4)),
          Paint()
            ..color = AppColors.workoutsHero.withValues(alpha: 0.16 * hv)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
      canvas.drawRRect(
        rect,
        Paint()..color = Color.lerp(baseColor, hoverColor, hv)!,
      );

      if (i == selected && t >= 1) {
        _paintValuePill(
          canvas,
          '${counts[i]}',
          Offset(
            left + (barWidth + grow * 2) / 2,
            baseline - full - lift - _pillGap,
          ),
        );
      }
    }

    _paintText(
      canvas,
      'Bu',
      labelStyle.copyWith(fontSize: 10),
      Offset(
        (n - 1) * (barWidth + _gap) + barWidth / 2,
        size.height - _bottomLabelSpace + 4,
      ),
    );
  }

  /// Seçili çubuğun sayısı: çubuktan [_pillGap] kadar ayrık, koyu yeşil daire
  /// içinde ortalı. Çok haneli sayıda daire yatayda hap şekline uzar.
  /// [bottomCenter] şeklin alt orta noktası.
  void _paintValuePill(Canvas canvas, String text, Offset bottomCenter) {
    // Satır yüksekliği 1 ve eşit boşluk dağılımı: metin kutusu rakamın kendisine
    // yakın olur, böylece daire içinde dikey olarak da ortalanır.
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: labelStyle.copyWith(
          color: AppColors.onHeroDark,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          height: 1,
          leadingDistribution: TextLeadingDistribution.even,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = math.max(_pillSize, painter.width + _pillPadX * 2);
    final rect = Rect.fromLTWH(
      bottomCenter.dx - w / 2,
      bottomCenter.dy - _pillSize,
      w,
      _pillSize,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(_pillSize / 2)),
      Paint()..color = AppColors.workoutsHero,
    );
    painter.paint(
      canvas,
      rect.center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _paintText(Canvas canvas, String text, TextStyle style, Offset center) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, 0));
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.progress != progress ||
      old.hoverIndex != hoverIndex ||
      old.hoverT != hoverT ||
      old.selected != selected ||
      old.counts != counts;
}
