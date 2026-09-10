import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import 'app_text_field.dart';

/// Password input field with integrated visibility toggle.
class AppPasswordField extends StatefulWidget {
  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final Widget? prefixIcon;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final FocusNode? focusNode;
  final bool enabled;

  const AppPasswordField({
    super.key,
    required this.label,
    this.controller,
    this.hintText,
    this.prefixIcon,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.focusNode,
    this.enabled = true,
  });

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscureText = true;

  void _toggleVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      controller: widget.controller,
      hintText: widget.hintText,
      prefixIcon: widget.prefixIcon ??
          const Icon(
            Icons.lock_outline_rounded,
            color: AppColors.onSurfaceVariant,
            size: 20.0,
          ),
      suffixIcon: IconButton(
        icon: Icon(
          _obscureText
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: AppColors.onSurfaceVariant,
          size: 20.0,
        ),
        onPressed: widget.enabled ? _toggleVisibility : null,
        tooltip: _obscureText ? 'Show password' : 'Hide password',
      ),
      obscureText: _obscureText,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
    );
  }
}
