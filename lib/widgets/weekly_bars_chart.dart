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

  static const double height = 104;

  @override
  State<WeeklyBarsChart> createState() => _WeeklyBarsChartState();
}

class _WeeklyBarsChartState extends State<WeeklyBarsChart>
    with SingleTickerProviderStateMixin {
  static const Duration _growDuration = Duration(milliseconds: 700);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _growDuration,
  )..forward();
  late int _selected = widget.counts.length - 1;

  @override
  void dispose() {
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
                onTapDown:
                    (d) => _select(
                      (d.localPosition.dx / width * counts.length)
                          .floor()
                          .clamp(0, counts.length - 1),
                    ),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder:
                      (context, _) => CustomPaint(
                        size: Size(width, WeeklyBarsChart.height),
                        painter: _BarsPainter(
                          counts: counts,
                          selected: _selected,
                          progress: _controller.value,
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
  final TextStyle labelStyle;

  _BarsPainter({
    required this.counts,
    required this.selected,
    required this.progress,
    required this.labelStyle,
  });

  static const double _gap = 10;
  static const double _radius = 7;
  static const double _topLabelSpace = 18;
  static const double _bottomLabelSpace = 16;
  static const double _emptyBarHeight = 6;
  // Çubuklar soldan sağa sırayla büyür; her biri toplam sürenin bir diliminde.
  static const double _staggerSpan = 0.5;

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
      final h = full * t;
      final left = i * (barWidth + _gap);
      final isCurrent = i == n - 1;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, baseline - h, barWidth, h),
        const Radius.circular(_radius),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = isCurrent ? AppColors.workoutsHero : AppColors.fillSubtle,
      );

      if (i == selected && t >= 1) {
        _paintText(
          canvas,
          '${counts[i]}',
          labelStyle.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          Offset(left + barWidth / 2, baseline - full - 16),
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
      old.selected != selected ||
      old.counts != counts;
}
