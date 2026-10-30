import 'dart:convert' show utf8;

import 'package:flutter/material.dart';

import '../../../../core/ui/widgets/wedo_brand_mark.dart';

import 'package:flutter/services.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final Future<bool> Function({
    required String email,
    required String code,
    required String newPassword,
  })?
  onSubmit;
  final VoidCallback onBackToLogin;
  final VoidCallback? onResetSuccess;

  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.onBackToLogin,
    this.onSubmit,
    this.onResetSuccess,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;
  late final FocusNode _codeFocusNode;
  late final FocusNode _newPasswordFocusNode;
  late final FocusNode _confirmPasswordFocusNode;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isSubmitting = false;
  bool _resetSucceeded = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _codeFocusNode = FocusNode();
    _newPasswordFocusNode = FocusNode();
    _confirmPasswordFocusNode = FocusNode();
    _newPasswordController.addListener(_handlePasswordChanged);
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_handlePasswordChanged);
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _codeFocusNode.dispose();
    _newPasswordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _handlePasswordChanged() {
    if (mounted) setState(() {});
  }

  String? _validateCode(String? value) {
    if (value == null || value.isEmpty) return 'Reset code is required';
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'Enter a valid 6-digit reset code';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.trim().isEmpty) return 'Password is required';
    if (value.length < 8 || value.length > 72) {
      return 'Password must be between 8 and 72 characters';
    }
    if (utf8.encode(value).length > 72) {
      return 'Password must not exceed 72 bytes';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _newPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (widget.onSubmit == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    try {
      final succeeded = await widget.onSubmit!(
        email: widget.email,
        code: _codeController.text,
        newPassword: _newPasswordController.text,
      );
      if (!succeeded || !mounted) return;
      setState(() => _resetSucceeded = true);
      widget.onResetSuccess?.call();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final password = _newPasswordController.text;
    final hasValidCharacterLength =
        password.isNotEmpty && password.length >= 8 && password.length <= 72;
    final hasValidByteLength =
        password.isNotEmpty && utf8.encode(password).length <= 72;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480.0),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Container(
                      width: double.infinity,
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(child: const WeDoBrandMark(size: 72)),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              'New Password',
                              style: AppTextStyles.of(context).headline,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Choose a password with 8–72 characters.',
                              style: AppTextStyles.of(context).bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _ResetField(
                              label: 'Reset Code',
                              hintText: 'Enter 6-digit code',
                              controller: _codeController,
                              focusNode: _codeFocusNode,
                              validator: _validateCode,
                              enabled: !_isSubmitting,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _ResetField(
                              label: 'New Password',
                              hintText: 'Enter new password',
                              controller: _newPasswordController,
                              focusNode: _newPasswordFocusNode,
                              validator: _validateNewPassword,
                              enabled: !_isSubmitting,
                              obscureText: !_isNewPasswordVisible,
                              textInputAction: TextInputAction.next,
                              suffixIcon: IconButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => setState(
                                        () => _isNewPasswordVisible =
                                            !_isNewPasswordVisible,
                                      ),
                                tooltip: _isNewPasswordVisible
                                    ? 'Hide new password'
                                    : 'Show new password',
                                icon: Icon(
                                  _isNewPasswordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _ResetField(
                              label: 'Confirm Password',
                              hintText: 'Confirm new password',
                              controller: _confirmPasswordController,
                              focusNode: _confirmPasswordFocusNode,
                              validator: _validateConfirmPassword,
                              enabled: !_isSubmitting,
                              obscureText: !_isConfirmPasswordVisible,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _handleSubmit(),
                              suffixIcon: IconButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => setState(
                                        () => _isConfirmPasswordVisible =
                                            !_isConfirmPasswordVisible,
                                      ),
                                tooltip: _isConfirmPasswordVisible
                                    ? 'Hide confirm password'
                                    : 'Show confirm password',
                                icon: Icon(
                                  _isConfirmPasswordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _RequirementsCard(
                              hasValidCharacterLength: hasValidCharacterLength,
                              hasValidByteLength: hasValidByteLength,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _UpdatePasswordButton(
                              onPressed: _handleSubmit,
                              isLoading: _isSubmitting,
                            ),
                            if (_resetSucceeded) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Password updated. You can now log in.',
                                style: AppTextStyles.of(context).bodySmall,
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: AppSpacing.sm),
                            TextButton.icon(
                              onPressed: _isSubmitting
                                  ? null
                                  : widget.onBackToLogin,
                              icon: const Icon(Icons.arrow_back, size: 18.0),
                              label: Text(
                                'Back to Login',
                                style: AppTextStyles.of(context).bodySmall,
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                minimumSize: const Size(48.0, 40.0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResetField extends StatefulWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final FocusNode focusNode;
  final FormFieldValidator<String> validator;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  const _ResetField({
    required this.label,
    required this.hintText,
    required this.controller,
    required this.focusNode,
    required this.validator,
    required this.enabled,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.onSubmitted,
    this.suffixIcon,
  });

  @override
  State<_ResetField> createState() => _ResetFieldState();
}

class _ResetFieldState extends State<_ResetField> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChanged);
    super.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppTextStyles.of(context).label),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          validator: widget.validator,
          enabled: widget.enabled,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          inputFormatters: widget.inputFormatters,
          onFieldSubmitted: widget.onSubmitted,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
            filled: true,
            fillColor: _isFocused
                ? Theme.of(context).colorScheme.surface
                : Theme.of(context).colorScheme.surfaceContainerLow,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            suffixIcon: widget.suffixIcon,
          ),
        ),
      ],
    );
  }
}

class _RequirementsCard extends StatelessWidget {
  final bool hasValidCharacterLength;
  final bool hasValidByteLength;

  const _RequirementsCard({
    required this.hasValidCharacterLength,
    required this.hasValidByteLength,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password requirements:',
            style: AppTextStyles.of(context).label,
          ),
          const SizedBox(height: AppSpacing.xs),
          _RequirementRow(
            label: '8–72 characters',
            isSatisfied: hasValidCharacterLength,
          ),
          const SizedBox(height: 4.0),
          _RequirementRow(
            label: 'At most 72 UTF-8 bytes',
            isSatisfied: hasValidByteLength,
          ),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final String label;
  final bool isSatisfied;

  const _RequirementRow({required this.label, required this.isSatisfied});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isSatisfied ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16.0,
          color: isSatisfied
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(label, style: AppTextStyles.of(context).bodySmall),
        ),
      ],
    );
  }
}

class _UpdatePasswordButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const _UpdatePasswordButton({
    required this.onPressed,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        height: AppSpacing.buttonHeightLarge,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            disabledBackgroundColor: Theme.of(context).colorScheme.primary
                .withValues(alpha: 0.7),
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            elevation: 0,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: 24.0,
                  height: 24.0,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                )
              : Text(
                  'Update Password',
                  style: AppTextStyles.of(context).buttonPrimary,
                ),
        ),
      ),
    );
  }
}
