import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/workout_stats.dart';

/// Güç puanı (tahmini 1TM) çizgi grafiği: ardıç yeşili çizgi, rekor noktası
/// altın. Dokununca ya da sürükleyince en yakın nokta seçilir ve tooltip çıkar.
class StrengthLineChart extends StatefulWidget {
  final List<StrengthPoint> points;

  /// Tüm zamanların rekoru; penceredeki noktalardan biriyle eşleşirse altınla
  /// işaretlenir.
  final StrengthPoint? record;
  final TextStyle? labelStyle;

  const StrengthLineChart({
    super.key,
    required this.points,
    this.record,
    this.labelStyle,
  });

  static const double height = 168;

  @override
  State<StrengthLineChart> createState() => _StrengthLineChartState();
}

class _StrengthLineChartState extends State<StrengthLineChart>
    with SingleTickerProviderStateMixin {
  static const Duration _drawDuration = Duration(milliseconds: 700);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _drawDuration,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  int? _selected;

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void didUpdateWidget(StrengthLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_samePoints(oldWidget.points, widget.points)) {
      _selected = null;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static bool _samePoints(List<StrengthPoint> a, List<StrengthPoint> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].date != b[i].date || a[i].score != b[i].score) return false;
    }
    return true;
  }

  int _nearestIndex(double dx, double width) {
    final geometry = _ChartGeometry(
      Size(width, StrengthLineChart.height),
      widget.points,
    );
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < widget.points.length; i++) {
      final distance = (geometry.x(i) - dx).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    return best;
  }

  void _select(int? index) {
    if (index == _selected) return;
    HapticFeedback.selectionClick();
    setState(() => _selected = index);
  }

  String get _semanticsLabel {
    final first = widget.points.first;
    final last = widget.points.last;
    return 'Güç puanı grafiği, ${widget.points.length} antrenman. '
        'İlk puan ${_formatKg(first.score)} kilo, '
        'son puan ${_formatKg(last.score)} kilo.';
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle =
        widget.labelStyle ??
        AppTypography.body12Regular.copyWith(color: AppColors.textTertiary);
    return Semantics(
      label: _semanticsLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          height: StrengthLineChart.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) {
                  final index = _nearestIndex(d.localPosition.dx, width);
                  _select(index == _selected ? null : index);
                },
                onHorizontalDragUpdate:
                    (d) => _select(_nearestIndex(d.localPosition.dx, width)),
                child: AnimatedBuilder(
                  animation: _progress,
                  builder:
                      (context, _) => CustomPaint(
                        size: Size(width, StrengthLineChart.height),
                        painter: _StrengthPainter(
                          points: widget.points,
                          record: widget.record,
                          progress: _progress.value,
                          selected: _selected,
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

String _formatKg(double value) =>
    value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);

/// Çizim alanı ölçüleri; painter ve dokunma hesabı aynı yerden okusun.
class _ChartGeometry {
  static const double sidePadding = 10;
  static const double topPadding = 44; // tooltip için yer
  static const double bottomPadding = 22; // tarih etiketleri
  static const double _valuePadding = 0.15;

  final Size size;
  final List<StrengthPoint> points;
  late final double _min;
  late final double _max;

  _ChartGeometry(this.size, this.points) {
    var lo = points.map((p) => p.score).reduce(math.min);
    var hi = points.map((p) => p.score).reduce(math.max);
    if (hi - lo < 1) {
      lo -= 1;
      hi += 1;
    }
    final pad = (hi - lo) * _valuePadding;
    _min = lo - pad;
    _max = hi + pad;
  }

  double get plotBottom => size.height - bottomPadding;
  double get plotTop => topPadding;

  double x(int i) {
    if (points.length == 1) return size.width / 2;
    final width = size.width - sidePadding * 2;
    return sidePadding + width * i / (points.length - 1);
  }

  double y(int i) {
    final t = (points[i].score - _min) / (_max - _min);
    return plotBottom - t * (plotBottom - plotTop);
  }
}

class _StrengthPainter extends CustomPainter {
  final List<StrengthPoint> points;
  final StrengthPoint? record;
  final double progress;
  final int? selected;
  final TextStyle labelStyle;

  _StrengthPainter({
    required this.points,
    required this.record,
    required this.progress,
    required this.selected,
    required this.labelStyle,
  });

  static const double _lineWidth = 2.5;
  static const double _dotRadius = 3.5;
  static const double _selectedRadius = 6;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final g = _ChartGeometry(size, points);

    // Yatay kılavuz çizgileri
    final gridPaint =
        Paint()
          ..color = AppColors.fillSubtle
          ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = g.plotTop + (g.plotBottom - g.plotTop) * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Eğri: yatay teğetli kübik Bézier, değerleri aşmaz.
    final line = Path()..moveTo(g.x(0), g.y(0));
    for (var i = 1; i < points.length; i++) {
      final midX = (g.x(i - 1) + g.x(i)) / 2;
      line.cubicTo(midX, g.y(i - 1), midX, g.y(i), g.x(i), g.y(i));
    }
    final fill =
        Path.from(line)
          ..lineTo(g.x(points.length - 1), g.plotBottom)
          ..lineTo(g.x(0), g.plotBottom)
          ..close();

    final clipRight = g.x(0) + (size.width - g.x(0)) * progress;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, clipRight, size.height));
    canvas.drawPath(
      fill,
      Paint()..color = AppColors.workoutsHero.withValues(alpha: 0.07),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.workoutsHero
        ..style = PaintingStyle.stroke
        ..strokeWidth = _lineWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();

    // Noktalar
    int? recordIndex;
    if (record != null) {
      for (var i = 0; i < points.length; i++) {
        if (points[i].date == record!.date &&
            points[i].score == record!.score) {
          recordIndex = i;
        }
      }
    }
    for (var i = 0; i < points.length; i++) {
      if (g.x(i) > clipRight) continue;
      final center = Offset(g.x(i), g.y(i));
      if (i == recordIndex) {
        canvas.drawCircle(
          center,
          9,
          Paint()..color = AppColors.accentGold.withValues(alpha: 0.35),
        );
        canvas.drawCircle(center, 5, Paint()..color = AppColors.accentGold);
        canvas.drawCircle(
          center,
          5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } else {
        final radius = i == selected ? _selectedRadius : _dotRadius;
        canvas.drawCircle(center, radius, Paint()..color = Colors.white);
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = AppColors.workoutsHero
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    // "Rekor" etiketi (seçili değilse)
    if (recordIndex != null && selected != recordIndex && progress >= 1) {
      _paintText(
        canvas,
        'Rekor',
        labelStyle.copyWith(
          color: AppColors.accentDeep,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
        Offset(g.x(recordIndex), g.y(recordIndex) - 24),
        size.width,
      );
    }

    // Tarih etiketleri
    final dateFormat = DateFormat('d MMM', 'tr_TR');
    final small = labelStyle.copyWith(fontSize: 10);
    _paintText(
      canvas,
      dateFormat.format(points.first.date),
      small,
      Offset(g.x(0), size.height - bottomLabelOffset),
      size.width,
      align: _LabelAlign.start,
    );
    if (points.length > 1) {
      _paintText(
        canvas,
        _isToday(points.last.date)
            ? 'Bugün'
            : dateFormat.format(points.last.date),
        small,
        Offset(g.x(points.length - 1), size.height - bottomLabelOffset),
        size.width,
        align: _LabelAlign.end,
      );
    }

    // Tooltip
    final s = selected;
    if (s != null && s < points.length && progress >= 1) {
      _paintTooltip(canvas, size, g, s, dateFormat);
    }
  }

  static const double bottomLabelOffset = 14;

  static bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  void _paintTooltip(
    Canvas canvas,
    Size size,
    _ChartGeometry g,
    int index,
    DateFormat dateFormat,
  ) {
    final p = points[index];
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        children: [
          TextSpan(
            text: '${_formatKg(p.score)} kg\n',
            style: labelStyle.copyWith(
              color: AppColors.onHeroDark,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              height: 1.25,
            ),
          ),
          TextSpan(
            text:
                '${_formatKg(p.weight)} kg × ${p.reps} · ${dateFormat.format(p.date)}',
            style: labelStyle.copyWith(
              color: AppColors.onHeroDark.withValues(alpha: 0.75),
              fontSize: 10,
              height: 1.25,
            ),
          ),
        ],
      ),
    )..layout();

    const padX = 10.0;
    const padY = 6.0;
    final w = painter.width + padX * 2;
    final h = painter.height + padY * 2;
    final cx = g.x(index);
    final left = (cx - w / 2).clamp(0.0, size.width - w);
    final top = math.max(0.0, g.y(index) - 14 - h);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, w, h),
      const Radius.circular(10),
    );
    canvas.drawRRect(rect, Paint()..color = AppColors.workoutsHero);
    painter.paint(canvas, Offset(left + padX, top + padY));
  }

  void _paintText(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset anchor,
    double maxWidth, {
    _LabelAlign align = _LabelAlign.center,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      _LabelAlign.start => anchor.dx - _ChartGeometry.sidePadding,
      _LabelAlign.end => anchor.dx - painter.width + _ChartGeometry.sidePadding,
      _LabelAlign.center => anchor.dx - painter.width / 2,
    };
    painter.paint(
      canvas,
      Offset(dx.clamp(0.0, maxWidth - painter.width), anchor.dy),
    );
  }

  @override
  bool shouldRepaint(_StrengthPainter old) =>
      old.progress != progress ||
      old.selected != selected ||
      old.points != points ||
      old.record != record;
}

enum _LabelAlign { start, center, end }
