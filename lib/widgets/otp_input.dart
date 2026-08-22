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
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.length, (index) {
        return Padding(
          padding: EdgeInsets.only(right: index == widget.length - 1 ? 0 : 16),
          child: SizedBox(
            width: 48,
            height: 48,
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              style: AppTypography.heading3.copyWith(
                color: Colors.black,
                fontSize: 22,
              ),
              decoration: InputDecoration(
                counterText: '',
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.brandSecondary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.textSecondary),
                ),
              ),
              onChanged: (v) => _onChanged(index, v),
            ),
          ),
        );
      }),
    );
  }
}
