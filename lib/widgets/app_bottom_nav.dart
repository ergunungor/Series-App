import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AppBottomNavItem {
  final IconData icon;
  final String label;

  const AppBottomNavItem({required this.icon, required this.label});
}

/// iOS 26 "Liquid Glass" esinli alt bar: bulanık cam kapsül + yay fiziğiyle
/// hareket eden, hızla hafifçe esneyen cam seçim göstergesi (lens).
///
/// Gerçek ışık kırılması yok (shader gerektirir); cam hissi blur, yarı saydam
/// dolgu ve ince ışık kenarıyla verilir. Dışarıya sadece [currentIndex] ve
/// [onTap] açıktır.
class AppBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<AppBottomNavItem> _items = [
    AppBottomNavItem(icon: Icons.home_rounded, label: 'Ana Sayfa'),
    AppBottomNavItem(icon: Icons.calendar_month_rounded, label: 'Programlar'),
    AppBottomNavItem(icon: Icons.fitness_center_rounded, label: 'Antrenmanlar'),
    AppBottomNavItem(icon: Icons.person_rounded, label: 'Profil'),
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
    with SingleTickerProviderStateMixin {
  // Kapsül
  static const double _barRadius = 45;
  static const double _blurSigma = 24;
  static const double _glassAlpha = 0.58;
  static const double _borderAlpha = 0.75;
  static const EdgeInsets _barMargin = EdgeInsets.fromLTRB(16, 0, 16, 16);
  static const EdgeInsets _barPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 8,
  );

  // Seçim lensi
  static const double _lensHeight = 56;
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

  // Değer = (kesirli) sekme indeksi; sınırsız, çünkü yay hedefi aşabilir.
  late final AnimationController _position;

  @override
  void initState() {
    super.initState();
    _position = AnimationController.unbounded(
      vsync: this,
      value: widget.currentIndex.toDouble(),
    );
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
    }
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  void _handleTap(int index) {
    if (index != widget.currentIndex) HapticFeedback.selectionClick();
    widget.onTap(index);
  }

  Widget _buildLens(double slotWidth) {
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
            height: _lensHeight,
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

  Widget _buildItem(int index) {
    final isSelected = index == widget.currentIndex;
    final item = AppBottomNav._items[index];

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: item.label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _handleTap(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  scale: isSelected ? 1.08 : 1.0,
                  child: Icon(
                    item.icon,
                    color: AppColors.brandTertiary,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: AppTypography.body12Medium.copyWith(
                    color: AppColors.brandTertiary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  child: Text(item.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(_barRadius);

    // Gölge kırpmanın dışında kalmalı; bu yüzden ClipRRect'in bir üstünde.
    return Container(
      margin: _barMargin,
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
            padding: _barPadding,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _glassAlpha),
              borderRadius: radius,
              border: Border.all(
                color: Colors.white.withValues(alpha: _borderAlpha),
                width: 1,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slotWidth =
                    constraints.maxWidth / AppBottomNav._items.length;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Lens arkada; Positioned.fill sayesinde iç Stack sınırlı
                    // ölçü alır (Row yüksekliği belirler).
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _position,
                        builder:
                            (context, _) => Stack(
                              clipBehavior: Clip.none,
                              children: [_buildLens(slotWidth)],
                            ),
                      ),
                    ),
                    Row(
                      children: List.generate(
                        AppBottomNav._items.length,
                        _buildItem,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
