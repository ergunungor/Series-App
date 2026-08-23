import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AppInput extends StatefulWidget {
  final String hintText;
  final IconData? prefixIcon;
  final bool isPassword;
  // yeni:
  final TextEditingController? controller;
  final TextInputType? keyboardType;

  const AppInput({
    super.key,
    required this.hintText,
    this.prefixIcon,
    this.isPassword = false,
    this.controller,
    this.keyboardType,
  });

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  bool _obscure = true;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: TextField(
        controller: widget.controller,
        obscureText: widget.isPassword ? _obscure : false,
        style: AppTypography.body16Regular.copyWith(
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: AppTypography.body16Regular.copyWith(
            color: AppColors.textTertiary,
          ),
          prefixIcon:
              widget.prefixIcon != null
                  ? Icon(
                    widget.prefixIcon,
                    size: 16,
                    color: AppColors.textTertiary,
                  )
                  : null,
          suffixIcon:
              widget.isPassword
                  ? IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                  : null,
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.textTertiary),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
