import 'dart:async' show Timer;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AppBottomNavItem {
  final IconData icon;
  final String label;

  /// Bu sekme seçiliyken ikon ve yazıların tamamının rengi (sayfanın baskın
  /// rengi).
  final Color color;

  const AppBottomNavItem({
    required this.icon,
    required this.label,
    required this.color,
  });
}

/// iOS 26 "Liquid Glass" esinli alt bar: bulanık cam kapsül + yay fiziğiyle
/// hareket eden, hızla hafifçe esneyen cam seçim göstergesi (lens).
///
/// Ortada, içeriğe göre daralan bir kapsül. [_idleDelay] boyunca dokunulmazsa
/// yazılar kaybolup yalnızca ikonlar kalacak şekilde küçülür; dokununca yay
/// fiziğiyle büyüyüp yazıları gösterir. İkon ve yazılar her sekmede o sayfanın
/// rengine geçer.
///
/// Gerçek ışık kırılması yok (shader gerektirir); cam hissi blur, yarı saydam
/// dolgu ve ince ışık kenarıyla verilir. Dışarıya sadece [currentIndex] ve
/// [onTap] açıktır.
class AppBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Büyük hâldeki kapsül yüksekliği ve alt marj. Ekranlar alt boşluklarını
  /// buna bağlar ([clearance]); bar küçülüp büyüyünce içerik kaymaz.
  static const double expandedHeight = 72;
  static const double bottomMargin = 16;
  static const double clearance = expandedHeight + bottomMargin;

  static const List<AppBottomNavItem> _items = [
    AppBottomNavItem(
      icon: Icons.home_rounded,
      label: 'Ana Sayfa',
      color: AppColors.heroGradientStart,
    ),
    AppBottomNavItem(
      icon: Icons.calendar_month_rounded,
      label: 'Programlar',
      color: AppColors.espresso,
    ),
    AppBottomNavItem(
      icon: Icons.fitness_center_rounded,
      label: 'Antrenmanlar',
      color: AppColors.workoutsHero,
    ),
    AppBottomNavItem(
      icon: Icons.person_rounded,
      label: 'Profil',
      color: AppColors.profileHero,
    ),
  ];

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav>
    with TickerProviderStateMixin {
  // Kapsül
  static const double _barRadius = 45;
  static const double _blurSigma = 24;
  static const double _glassAlpha = 0.58;
  static const double _borderAlpha = 0.75;

  // Büyük (yazılı) ve küçük (yalnızca ikon) hâl ölçüleri; animasyon bunlar
  // arasında tek bir değerle (0..1) ilerler.
  static const double _expandedSlot = 80;
  static const double _collapsedSlot = 56;
  static const double _expandedPad = 7;
  static const double _collapsedPad = 5;
  static const double _expandedItem = 58;
  static const double _collapsedItem = 46;
  static const double _expandedIcon = 27;
  static const double _collapsedIcon = 25;
  static const double _labelFontSize = 11.5;

  // Dokunurken bar hover gibi hafifçe (%7) büyür.
  static const double _pressedScale = 1.07;
  // Basarken hızlı (kısa dokunuşta da görünsün), bırakırken yavaş ve yumuşak.
  static const Duration _pressInDuration = Duration(milliseconds: 140);
  static const Duration _pressOutDuration = Duration(milliseconds: 380);

  // Boşta kalma ve animasyon süreleri
  static const Duration _idleDelay = Duration(milliseconds: 3500);
  static const Duration _collapseDuration = Duration(milliseconds: 400);
  static const Duration _colorDuration = Duration(milliseconds: 350);
  // Yazılar, büyüme değerinin bu eşiğinden sonra belirir (önce kapsül açılır).
  static const double _labelStart = 0.4;
  static const double _labelSlide = 4;

  // Seçim lensi
  static const double _lensVerticalInset = 2;
  static const double _lensInset = 3;
  static const double _lensAlpha = 0.7;
  static const double _stretchPerVelocity = 0.035;
  static const double _maxStretch = 1.22;
  static const double _squashFactor = 0.5;

  // Hafif sönümlü yay: hedefi hafifçe aşıp oturur (jöle hissi).
  static const SpringDescription _spring = SpringDescription(
    mass: 1,
    stiffness: 220,
    damping: 21,
  );
  // Büyüme yayı: lensten biraz daha hızlı, hafif taşıp oturur.
  static const SpringDescription _expandSpring = SpringDescription(
    mass: 1,
    stiffness: 240,
    damping: 20,
  );

  // Değer = (kesirli) sekme indeksi; sınırsız, çünkü yay hedefi aşabilir.
  late final AnimationController _position;
  // 0 = küçük, 1 = büyük. Yay hedefi hafifçe aşabilir (>1).
  late final AnimationController _expand;
  Timer? _idleTimer;
  bool _isExpanded = true;
  bool _isPressed = false;
  // VoiceOver ya da "hareketi azalt" açıkken bar hep büyük kalır.
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    _position = AnimationController.unbounded(
      vsync: this,
      value: widget.currentIndex.toDouble(),
    );
    _expand = AnimationController.unbounded(vsync: this, value: 1);
    _restartIdleTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mq = MediaQuery.of(context);
    final locked = mq.accessibleNavigation || mq.disableAnimations;
    if (locked != _isLocked) {
      _isLocked = locked;
      if (locked) {
        _idleTimer?.cancel();
        _setExpanded(true);
      } else {
        _restartIdleTimer();
      }
    }
  }

  @override
  void didUpdateWidget(AppBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _position.animateWith(
        SpringSimulation(
          _spring,
          _position.value,
          widget.currentIndex.toDouble(),
          _position.velocity,
        ),
      );
      _setExpanded(true);
      _restartIdleTimer();
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _position.dispose();
    _expand.dispose();
    super.dispose();
  }

  void _setExpanded(bool expanded) {
    if (_isExpanded == expanded) return;
    _isExpanded = expanded;
    if (expanded) {
      _expand.animateWith(
        SpringSimulation(_expandSpring, _expand.value, 1, _expand.velocity),
      );
    } else {
      // Küçülme taşmasın: yaysız, yumuşak eğri.
      _expand.animateTo(
        0,
        duration: _collapseDuration,
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    if (_isLocked) return;
    _idleTimer = Timer(_idleDelay, () {
      if (mounted) _setExpanded(false);
    });
  }

  // Parmak bara değdiği an büyümeye başlar; dokunuş bitince sayaç yeniden kurulur.
  void _handlePointerDown() {
    _idleTimer?.cancel();
    setState(() => _isPressed = true);
    _setExpanded(true);
  }

  void _handlePointerUp() {
    if (_isPressed) setState(() => _isPressed = false);
    _restartIdleTimer();
  }

  void _handleTap(int index) {
    if (index != widget.currentIndex) HapticFeedback.selectionClick();
    widget.onTap(index);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  Widget _buildLens(double slotWidth, double itemHeight) {
    final velocity = _position.velocity.abs();
    final stretch =
        (1 + velocity * _stretchPerVelocity).clamp(1.0, _maxStretch).toDouble();
    // Yatayda uzarken dikeyde biraz basıklaşır (hacim korunuyormuş gibi).
    final squash = 1 - (stretch - 1) * _squashFactor;

    return Positioned(
      left: slotWidth * _position.value + _lensInset,
      width: slotWidth - _lensInset * 2,
      top: 0,
      bottom: 0,
      child: Center(
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(stretch, squash, 1),
          child: Container(
            height: itemHeight - _lensVerticalInset * 2,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _lensAlpha),
              borderRadius: BorderRadius.circular(_barRadius),
              border: Border.all(color: Colors.white, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int index, Color color, double t) {
    final isSelected = index == widget.currentIndex;
    final item = AppBottomNav._items[index];
    final labelT = Curves.easeOut.transform(
      ((t - _labelStart) / (1 - _labelStart)).clamp(0.0, 1.0),
    );

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: item.label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _handleTap(index),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  scale: isSelected ? 1.08 : 1.0,
                  child: Icon(
                    item.icon,
                    color: color,
                    size: _lerp(_collapsedIcon, _expandedIcon, t.clamp(0, 1)),
                  ),
                ),
                // Yazı alanı büyürken yüksekliği de açılır; kapsül büyüyüp
                // küçülürken ikon yerinde sıçramaz.
                ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: labelT,
                    child: Opacity(
                      opacity: labelT,
                      child: Transform.translate(
                        offset: Offset(0, (1 - labelT) * _labelSlide),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              item.label,
                              maxLines: 1,
                              style: AppTypography.body12Medium.copyWith(
                                fontSize: _labelFontSize,
                                height: 1.2,
                                color: color,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBar(Color color, double t) {
    final radius = BorderRadius.circular(_barRadius);
    final slot = _lerp(_collapsedSlot, _expandedSlot, t);
    final pad = _lerp(_collapsedPad, _expandedPad, t);
    final itemHeight = _lerp(_collapsedItem, _expandedItem, t);
    final count = AppBottomNav._items.length;

    // Gölge kırpmanın dışında kalmalı; bu yüzden ClipRRect'in bir üstünde.
    final bar = Container(
      width: slot * count + pad * 2,
      height: itemHeight + pad * 2,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
          child: Container(
            padding: EdgeInsets.all(pad),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _glassAlpha),
              borderRadius: radius,
              border: Border.all(
                color: Colors.white.withValues(alpha: _borderAlpha),
                width: 1,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Lens arkada; Positioned.fill sayesinde iç Stack sınırlı ölçü
                // alır.
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _position,
                    builder:
                        (context, _) => Stack(
                          clipBehavior: Clip.none,
                          children: [_buildLens(slot, itemHeight)],
                        ),
                  ),
                ),
                Row(
                  children: List.generate(
                    count,
                    (i) => _buildItem(i, color, t),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppBottomNav.bottomMargin),
      child: AnimatedScale(
        scale: _isPressed ? _pressedScale : 1,
        duration: _isPressed ? _pressInDuration : _pressOutDuration,
        curve: _isPressed ? Curves.easeOut : Curves.easeInOutCubic,
        child: bar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final target = AppBottomNav._items[widget.currentIndex].color;

    return Center(
      child: Listener(
        onPointerDown: (_) => _handlePointerDown(),
        onPointerUp: (_) => _handlePointerUp(),
        onPointerCancel: (_) => _handlePointerUp(),
        // Sekme değişince ikon ve yazı rengi yumuşakça yeni sayfanın rengine
        // geçer; ilk build'de animasyon yok.
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: target),
          duration: _colorDuration,
          curve: Curves.easeOut,
          builder:
              (context, color, _) => AnimatedBuilder(
                animation: _expand,
                builder:
                    (context, _) => _buildBar(color ?? target, _expand.value),
              ),
        ),
      ),
    );
  }
}
