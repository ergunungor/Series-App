import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum AppButtonVariant { filled, outlined }

/// Uygulamanın ana butonu. Dolu hâli kiremit gradyan + renkli gölge, çerçeveli
/// hâli beyaz zemin + kiremit çerçeve. Basınca hafifçe küçülür; [onPressed]
/// null ise soluk ve basılamaz; [isLoading] iken ikon yerine küçük bir
/// ilerleme göstergesi çıkar (dokunma yine [onPressed]'a bağlı).
class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool showIcon;
  final IconData icon;
  final bool isLoading;

  /// Dolu hâlde gradyanın üst/alt rengi, çerçeveli hâlde çerçeve ve yazı
  /// rengi. Varsayılan kiremit; anket gibi ekranlar kendi rengini verebilir.
  final Color color;
  final Color deepColor;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.showIcon = true,
    this.icon = Icons.play_arrow_rounded,
    this.isLoading = false,
    this.color = AppColors.homeHero,
    this.deepColor = AppColors.homeHeroDeep,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  static const double _height = 54;
  static const double _radius = 18;
  static const double _pressedScale = 0.97;
  static const Duration _pressDuration = Duration(milliseconds: 120);
  static const double _disabledOpacity = 0.55;

  bool _isPressed = false;

  bool get _isEnabled => widget.onPressed != null;

  void _setPressed(bool value) {
    if (_isPressed != value) setState(() => _isPressed = value);
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isFilled = widget.variant == AppButtonVariant.filled;
    final Color fg = isFilled ? Colors.white : widget.color;

    return Semantics(
      button: true,
      enabled: _isEnabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _isEnabled ? (_) => _setPressed(true) : null,
        onTapUp: _isEnabled ? (_) => _setPressed(false) : null,
        onTapCancel: _isEnabled ? () => _setPressed(false) : null,
        onTap: _isEnabled ? _handleTap : null,
        child: AnimatedScale(
          scale: _isPressed ? _pressedScale : 1,
          duration: _pressDuration,
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isEnabled ? 1 : _disabledOpacity,
            child: Container(
              width: double.infinity,
              height: _height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient:
                    isFilled
                        ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [widget.color, widget.deepColor],
                        )
                        : null,
                color: isFilled ? null : Colors.white,
                borderRadius: BorderRadius.circular(_radius),
                border:
                    isFilled
                        ? null
                        : Border.all(color: widget.color, width: 1.5),
                boxShadow:
                    isFilled && _isEnabled
                        ? [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.5),
                            blurRadius: 24,
                            spreadRadius: -8,
                            offset: const Offset(0, 12),
                          ),
                        ]
                        : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.text,
                    style: AppTypography.body16Medium.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  if (widget.isLoading) ...[
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(fg),
                      ),
                    ),
                  ] else if (widget.showIcon) ...[
                    const SizedBox(width: 8),
                    Icon(widget.icon, size: 24, color: fg),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
