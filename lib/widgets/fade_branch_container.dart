import 'package:flutter/material.dart';

/// Alt bar sekmeleri arasında geçişi yatay kayma ile yapar (fade yok).
///
/// `StatefulShellRoute.indexedStack` gibi tüm dalları canlı tutar (scroll ve
/// state korunur) ama geçişi anında keser. Burada yeni sekme gittiği yönün
/// tersinden kayarak girer, eski sekme daha yavaş (paralaks) ters yöne çekilir
/// ve hafifçe kararır; yeni sekmenin kenarında ince bir gölge derinlik verir.
/// Eski sekme kayma bitene kadar altta kalır.
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
  static const Duration _duration = Duration(milliseconds: 420);
  // Eski sekmenin paralaks kayması (ekran genişliğinin oranı) ve kararması.
  static const double _parallax = 0.28;
  static const double _scrimAlpha = 0.1;

  late final AnimationController _controller;
  late final Animation<double> _progress;
  int? _previousIndex;
  // +1: yeni sekme sağdan girer (sağdaki sekmeye geçiş), -1: soldan.
  int _direction = 1;

  @override
  void initState() {
    super.initState();
    // value: 1 → ilk açılışta fade oynamaz.
    _controller = AnimationController(
      vsync: this,
      duration: _duration,
      value: 1,
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(FadeBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
      _direction = widget.currentIndex > oldWidget.currentIndex ? 1 : -1;
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final current = widget.currentIndex;
            final isAnimating = _controller.value < 1;
            final t = _progress.value;

            // Aktif sekme en son (en üstte) çizilir; anahtarlar sayesinde
            // sıra değişse de dalların state'i korunur.
            final order = [
              for (var i = 0; i < widget.children.length; i++)
                if (i != current) i,
              current,
            ];

            Widget decorate(int i) {
              final child = widget.children[i];
              if (!isAnimating) return child;
              if (i == current) {
                // Yeni sekme: gittiği yönün tersinden kayarak girer.
                return Transform.translate(
                  offset: Offset(_direction * (1 - t) * width, 0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14 * (1 - t)),
                          blurRadius: 32,
                          offset: Offset(-_direction * 6.0, 0),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                );
              }
              if (i == _previousIndex) {
                // Eski sekme: daha yavaş ters yöne kayar ve hafifçe kararır.
                return Transform.translate(
                  offset: Offset(-_direction * t * width * _parallax, 0),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      child,
                      IgnorePointer(
                        child: ColoredBox(
                          color: Colors.black.withValues(
                            alpha: _scrimAlpha * t,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return child;
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                for (final i in order)
                  KeyedSubtree(
                    key: ValueKey(i),
                    child: Offstage(
                      offstage:
                          i != current && !(isAnimating && i == _previousIndex),
                      child: IgnorePointer(
                        ignoring: i != current,
                        child: TickerMode(
                          enabled: i == current,
                          child: decorate(i),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
