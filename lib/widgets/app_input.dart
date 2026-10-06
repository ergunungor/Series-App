import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Metin giriş alanı: 52px, radius 16, beyaz zemin. Odaklanınca çerçeve kiremit
/// olur, hafif kiremit gölge çıkar ve ikon rengi buna geçer (200ms).
class AppInput extends StatefulWidget {
  final String hintText;
  final IconData? prefixIcon;
  final bool isPassword;
  // yeni:
  final TextEditingController? controller;
  final TextInputType? keyboardType;

  /// Odak çerçevesi, ikon ve imleç rengi; varsayılan kiremit.
  final Color focusColor;

  const AppInput({
    super.key,
    required this.hintText,
    this.prefixIcon,
    this.isPassword = false,
    this.controller,
    this.keyboardType,
    this.focusColor = AppColors.homeHero,
  });

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  static const double _height = 52;
  static const double _radius = 16;
  static const Duration _focusDuration = Duration(milliseconds: 200);

  final FocusNode _focusNode = FocusNode();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;
    final iconColor = focused ? widget.focusColor : AppColors.textTertiary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focusNode.requestFocus,
      child: AnimatedContainer(
        duration: _focusDuration,
        curve: Curves.easeOut,
        height: _height,
        padding: const EdgeInsets.only(left: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(
            color: focused ? widget.focusColor : AppColors.borderSubtle,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  focused
                      ? widget.focusColor.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.03),
              blurRadius: focused ? 18 : 8,
              offset: Offset(0, focused ? 6 : 2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (widget.prefixIcon != null) ...[
              TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: iconColor),
                duration: _focusDuration,
                builder:
                    (context, color, _) =>
                        Icon(widget.prefixIcon, size: 20, color: color),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                keyboardType: widget.keyboardType,
                obscureText: widget.isPassword ? _obscure : false,
                cursorColor: widget.focusColor,
                textAlignVertical: TextAlignVertical.center,
                style: AppTypography.body16Regular.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: AppTypography.body16Regular.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),
            if (widget.isPassword)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _obscure = !_obscure),
                child: SizedBox(
                  width: 48,
                  height: _height,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      key: ValueKey(_obscure),
                      size: 20,
                      color: iconColor,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }
}
