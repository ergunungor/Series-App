import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class OtpInput extends StatefulWidget {
  final int length;
  final ValueChanged<String>? onCompleted;

  const OtpInput({super.key, this.length = 4, this.onCompleted});

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    final code = _controllers.map((c) => c.text).join();
    if (code.length == widget.length) {
      widget.onCompleted?.call(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (index) {
        return Expanded(
          // Sabit width yerine Expanded: ekranı eşit böler.
          child: Padding(
            // Kutular arası boşluk 8
            padding: EdgeInsets.only(right: index == widget.length - 1 ? 0 : 8),
            child: _OtpBox(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              onChanged: (v) => _onChanged(index, v),
            ),
          ),
        );
      }),
    );
  }
}

/// Tek haneli kutu: odakta kiremit çerçeve ve gölge, dolunca çerçeve kiremit
/// kalır ve kutu hafifçe büyüyüp oturur.
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  static const double _height = 56;
  static const double _radius = 14;
  static const double _filledScale = 1.04;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([focusNode, controller]),
      builder: (context, _) {
        final focused = focusNode.hasFocus;
        final filled = controller.text.isNotEmpty;
        final active = focused || filled;
        return AnimatedScale(
          scale: filled ? _filledScale : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            height: _height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(
                color: active ? AppColors.homeHero : AppColors.borderSubtle,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      focused
                          ? AppColors.homeHero.withValues(alpha: 0.14)
                          : Colors.black.withValues(alpha: 0.03),
                  blurRadius: focused ? 16 : 8,
                  offset: Offset(0, focused ? 6 : 2),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              cursorColor: AppColors.homeHero,
              style: AppTypography.heading3.copyWith(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: onChanged,
            ),
          ),
        );
      },
    );
  }
}
