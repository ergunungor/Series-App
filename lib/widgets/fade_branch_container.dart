import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Ekranlar arasında parmakla kaydırırken ya da kayma animasyonu bitene kadar,
/// alt barın seçim lensinin konumunu (kesirli sekme indeksi) taşır. Kaydırma
/// yokken `null`. Alt bar bunu dinleyip lensi içerikle birlikte akıtır.
final ValueNotifier<double?> tabSwipeProgress = ValueNotifier<double?>(null);

/// Alt bar sekmeleri arasında geçişi yatay kayma ile yapar (fade yok).
///
/// `StatefulShellRoute.indexedStack` gibi tüm dalları canlı tutar (scroll ve
/// state korunur) ama geçişi anında keser. Burada yeni sekme gittiği yönün
/// tersinden kayarak girer, eski sekme daha yavaş (paralaks) ters yöne çekilir
/// ve hafifçe kararır; yeni sekmenin kenarında ince bir gölge derinlik verir.
/// Eski sekme kayma bitene kadar altta kalır.
///
/// Ekranda yatay sürükleyerek de komşu sekmeye geçilir: geçiş animasyonu
/// parmakla birlikte ilerler, bırakınca hız ya da mesafeye göre tamamlanır ya
/// da geri döner. İçeride yatay kaydırılan bir öğe (ör. silinebilir kart)
/// hareketi önce kapar; sekme geçişi yalnızca boş alanda başlar.
class FadeBranchContainer extends StatefulWidget {
  final int currentIndex;
  final List<Widget> children;

  /// Kaydırma ile başka sekmeye geçilince çağrılır.
  final ValueChanged<int>? onIndexChanged;

  const FadeBranchContainer({
    super.key,
    required this.currentIndex,
    required this.children,
    this.onIndexChanged,
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
  static const double _edgeShadowWidth = 28;

  // Kaydırma ile geçiş: bu orandan fazla sürüklenirse ya da bu hızı aşan bir
  // fırlatma olursa tamamlanır.
  static const double _commitFraction = 0.33;
  static const double _flingVelocity = 700;

  late final AnimationController _controller;
  late final Animation<double> _progress;
  int? _previousIndex;
  // +1: yeni sekme sağdan girer (sağdaki sekmeye geçiş), -1: soldan.
  int _direction = 1;

  // Parmakla sürükleme: gösterilen (girmekte olan) komşu sekme. null = yok.
  int? _dragTarget;
  double _dragDx = 0;
  bool _isDragging = false;

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
    _controller.addListener(_publishProgress);
  }

  @override
  void didUpdateWidget(FadeBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex == widget.currentIndex) return;

    if (_dragTarget != null && _dragTarget == widget.currentIndex) {
      // Kaydırma ile tamamlanan geçiş: animasyon zaten sürüyor, yeniden başlatma.
      return;
    }
    // Alt bardan dokunma (ya da kaydırma sırasında başka yönlendirme).
    _dragTarget = null;
    _isDragging = false;
    tabSwipeProgress.value = null;
    _previousIndex = oldWidget.currentIndex;
    _direction = widget.currentIndex > oldWidget.currentIndex ? 1 : -1;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    tabSwipeProgress.value = null;
    _controller.removeListener(_publishProgress);
    _controller.dispose();
    super.dispose();
  }

  // Alt barın lensini içerikle birlikte akıtır (yalnızca sürükleme/yerleşme
  // sırasında).
  void _publishProgress() {
    if (_dragTarget == null || _previousIndex == null) return;
    tabSwipeProgress.value = _previousIndex! + _direction * _controller.value;
  }

  void _clearDrag() {
    _dragTarget = null;
    _isDragging = false;
    tabSwipeProgress.value = null;
    if (mounted) setState(() {});
  }

  int? _neighbor(int direction) {
    final target = widget.currentIndex + direction;
    if (target < 0 || target >= widget.children.length) return null;
    return target;
  }

  void _onDragStart(DragStartDetails details) {
    if (widget.onIndexChanged == null) return;
    // Bir geçiş sürerken yeni sürükleme başlatma.
    if (_controller.value < 1 || _dragTarget != null) return;
    _isDragging = true;
    _dragDx = 0;
  }

  void _onDragUpdate(DragUpdateDetails details, double width) {
    if (!_isDragging || width <= 0) return;
    _dragDx += details.delta.dx;

    // Sola sürükleme (negatif) → sağdaki sekme girer.
    final direction = _dragDx < 0 ? 1 : -1;
    final target = _neighbor(direction);
    if (target == null) {
      // Uçtaki sekme: komşu yok, hareket yok sayılır.
      if (_dragTarget != null) {
        _dragTarget = null;
        tabSwipeProgress.value = null;
        setState(() {});
      }
      return;
    }

    setState(() {
      if (_dragTarget != target) {
        _dragTarget = target;
        _previousIndex = widget.currentIndex;
        _direction = direction;
        // Yön değişirken başlangıç noktası sıfırdan hesaplanır.
      }
      _controller.value = (_dragDx.abs() / width).clamp(0.0, 1.0).toDouble();
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;
    final target = _dragTarget;
    if (target == null) return;

    // Gittiği yöne doğru hız (+: geçişi ilerleten, -: geri çeken).
    final velocity = -_direction * (details.primaryVelocity ?? 0);
    final progress = _controller.value;
    final cancelled = velocity < -_flingVelocity;
    final commit =
        !cancelled && (velocity > _flingVelocity || progress > _commitFraction);

    if (commit) {
      HapticFeedback.selectionClick();
      // Önce yönlendirmeyi yap: didUpdateWidget bu geçişi yeniden başlatmaz.
      widget.onIndexChanged?.call(target);
      final remaining = 1 - progress;
      _controller
          .animateTo(
            1,
            duration: Duration(milliseconds: (140 + 240 * remaining).round()),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(_clearDrag);
    } else {
      _controller
          .animateTo(
            0,
            duration: Duration(milliseconds: (120 + 220 * progress).round()),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            // Vazgeçildi: eski sekme yerinde kalır.
            _controller.value = 1;
            _clearDrag();
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          dragStartBehavior: DragStartBehavior.down,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: (d) => _onDragUpdate(d, width),
          onHorizontalDragEnd: _onDragEnd,
          onHorizontalDragCancel: () => _onDragEnd(DragEndDetails()),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final dragging = _dragTarget != null;
              // Gösterilen sekme: sürüklerken komşu, aksi halde aktif sekme.
              final current = _dragTarget ?? widget.currentIndex;
              final isAnimating = dragging || _controller.value < 1;
              // Sürüklerken parmağı birebir izlemek için doğrusal ilerleme.
              final t = dragging ? _controller.value : _progress.value;
              // Altta kalan (çıkan) sekme: geçişi başlatan sekme. Sürüklemede de,
              // tamamlanan kaydırmada da, dokunma geçişinde de aynı alan.
              final under = _previousIndex;

              // Aktif sekme en son (en üstte) çizilir; anahtarlar sayesinde
              // sıra değişse de dalların state'i korunur.
              final order = [
                for (var i = 0; i < widget.children.length; i++)
                  if (i != current) i,
                current,
              ];

              // Her sekmenin widget zinciri geçiş sırasında ve dışında AYNI kalır:
              // yapı değişirse sekme alt ağacı sökülüp yeniden kurulur ve
              // kaydırma başında takılma olur. Sekme içeriği ayrıca kendi
              // RepaintBoundary'sinde: kayarken içerik yeniden boyanmaz, yalnızca
              // katman taşınır (gölge/karartma içeriğin dışında, küçük katmanlar).
              Widget decorate(int i) {
                Offset offset = Offset.zero;
                Widget overlay = const SizedBox.shrink();
                if (isAnimating && i == current) {
                  // Yeni sekme: gittiği yönün tersinden kayarak girer; kenarında
                  // karşı sekmeye düşen ince bir derinlik gölgesi.
                  offset = Offset(_direction * (1 - t) * width, 0);
                  overlay = Positioned(
                    top: 0,
                    bottom: 0,
                    left: _direction > 0 ? -_edgeShadowWidth : null,
                    right: _direction < 0 ? -_edgeShadowWidth : null,
                    width: _edgeShadowWidth,
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.black.withValues(
                                  alpha: _direction > 0 ? 0 : 0.14 * (1 - t),
                                ),
                                Colors.black.withValues(
                                  alpha: _direction > 0 ? 0.14 * (1 - t) : 0,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                } else if (isAnimating && i == under) {
                  // Eski sekme: daha yavaş ters yöne kayar ve hafifçe kararır.
                  offset = Offset(-_direction * t * width * _parallax, 0);
                  overlay = Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: _scrimAlpha * t),
                      ),
                    ),
                  );
                }
                return Transform.translate(
                  offset: offset,
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      RepaintBoundary(child: widget.children[i]),
                      overlay,
                    ],
                  ),
                );
              }

              return Stack(
                fit: StackFit.expand,
                children: [
                  for (final i in order)
                    KeyedSubtree(
                      key: ValueKey(i),
                      child: Offstage(
                        offstage: i != current && !(isAnimating && i == under),
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
          ),
        );
      },
    );
  }
}
