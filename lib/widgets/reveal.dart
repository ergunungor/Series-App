import 'package:flutter/material.dart';

/// İçeriği gecikmeli olarak fade + hafif yukarı kayma ile gösterir.
class Reveal extends StatelessWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 700),
    this.offsetY = 12,
  });

  @override
  Widget build(BuildContext context) {
    // TweenAnimationBuilder'da gecikme yok; toplam süreyi uzatıp
    // eğrinin ilk kısmını Interval ile boş bırakıyoruz.
    final total = delay + duration;
    final curve = Interval(
      delay.inMilliseconds / total.inMilliseconds,
      1.0,
      curve: Curves.easeOutCubic,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: total,
      curve: curve,
      child: child,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * offsetY),
            child: child,
          ),
        );
      },
    );
  }
}
