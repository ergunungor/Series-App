import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dokunulan child'ı basılı tutulduğu sürece hafifçe küçültür (iOS tarzı feedback).
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final bool haptics;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.haptics = true,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  static const Duration _duration = Duration(milliseconds: 120);

  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed != value) setState(() => _isPressed = value);
  }

  void _handleTap() {
    if (widget.haptics) HapticFeedback.selectionClick();
    widget.onTap?.call();
  }

  void _handleLongPress() {
    if (widget.haptics) HapticFeedback.mediumImpact();
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap == null ? null : _handleTap,
        onLongPress: widget.onLongPress == null ? null : _handleLongPress,
        child: AnimatedScale(
          scale: _isPressed ? widget.pressedScale : 1.0,
          duration: _duration,
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}
