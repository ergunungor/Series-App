import 'package:flutter/material.dart';

/// Alt bar sekmeleri arasında geçişi 250ms crossfade ile (ease in-out) yapar.
///
/// `StatefulShellRoute.indexedStack` gibi tüm dalları canlı tutar (scroll ve
/// state korunur) ama geçişi anında keser. Burada yeni sekme eskisinin üstünde
/// belirir, eski sekme fade bitene kadar altta kalır; arka plan sızıp
/// parlaklık düşmez.
class FadeBranchContainer extends StatefulWidget {
  final int currentIndex;
  final List<Widget> children;

  const FadeBranchContainer({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  @override
  State<FadeBranchContainer> createState() => _FadeBranchContainerState();
}

class _FadeBranchContainerState extends State<FadeBranchContainer>
    with SingleTickerProviderStateMixin {
  static const Duration _duration = Duration(milliseconds: 250);

  late final AnimationController _controller;
  late final Animation<double> _opacity;
  int? _previousIndex;

  @override
  void initState() {
    super.initState();
    // value: 1 → ilk açılışta fade oynamaz.
    _controller = AnimationController(
      vsync: this,
      duration: _duration,
      value: 1,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(FadeBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final current = widget.currentIndex;
        final isFading = _controller.value < 1;

        // Aktif sekme en son (en üstte) çizilir; anahtarlar sayesinde
        // sıra değişse de dalların state'i korunur.
        final order = [
          for (var i = 0; i < widget.children.length; i++)
            if (i != current) i,
          current,
        ];

        return Stack(
          fit: StackFit.expand,
          children: [
            for (final i in order)
              KeyedSubtree(
                key: ValueKey(i),
                child: Offstage(
                  offstage: i != current && !(isFading && i == _previousIndex),
                  child: IgnorePointer(
                    ignoring: i != current,
                    child: TickerMode(
                      enabled: i == current,
                      child: FadeTransition(
                        opacity:
                            i == current ? _opacity : kAlwaysCompleteAnimation,
                        child: widget.children[i],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
