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
          // YENİ: Sabit width yerine Expanded kullandık. Ekranı eşit böler.
          child: Padding(
            // Kutular arası boşluğu 16'dan 8'e düşürdük
            padding: EdgeInsets.only(right: index == widget.length - 1 ? 0 : 8),
            child: SizedBox(
              height:
                  52, // Dokunma alanı rahat olsun diye yüksekliği biraz artırdık
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: AppTypography.heading3.copyWith(
                  color: Colors.black,
                  fontSize: 20, // Ekrana sığması için fontu çok az küçülttük
                ),
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding:
                      EdgeInsets
                          .zero, // Yazının tam ortalanması için sıfırladık
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.brandSecondary,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                onChanged: (v) => _onChanged(index, v),
              ),
            ),
          ),
        );
      }),
    );
  }
}
