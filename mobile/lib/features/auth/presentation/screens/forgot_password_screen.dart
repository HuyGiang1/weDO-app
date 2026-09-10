import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final Future<bool> Function({required String email})? onSubmit;
  final VoidCallback onBack;
  final VoidCallback onReturnToLogin;
  final ValueChanged<String>? onRequestSuccess;

  const ForgotPasswordScreen({
    super.key,
    required this.onBack,
    required this.onReturnToLogin,
    this.onSubmit,
    this.onRequestSuccess,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final FocusNode _emailFocusNode;
  bool _isSubmitting = false;
  bool _requestSucceeded = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _emailFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
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
        email: _emailController.text.trim().toLowerCase(),
      );
      if (!succeeded || !mounted) return;
      setState(() => _requestSucceeded = true);
      widget.onRequestSuccess?.call(_emailController.text.trim().toLowerCase());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGradientStart,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 64.0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: IconButton(
                    onPressed: _isSubmitting ? null : widget.onBack,
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AppSpacing.maxContentWidth,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.xl,
                            AppSpacing.md,
                            AppSpacing.xl,
                          ),
                          child: LayoutBuilder(
                            builder: (context, cardConstraints) => Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(24.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryShadow.withValues(
                                      alpha: 0.04,
                                    ),
                                    blurRadius: 20.0,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(
                                cardConstraints.maxWidth >= 400.0
                                    ? 40.0
                                    : AppSpacing.xl,
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Center(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          16.0,
                                        ),
                                        child: Image.asset(
                                          'assets/images/wedo_logo.png',
                                          width: 64.0,
                                          height: 64.0,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    const Text(
                                      'Forgot Password?',
                                      style: AppTextStyles.headline,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Center(
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: 300.0,
                                        ),
                                        child: Text(
                                          "Enter your email and we'll send a 6-digit reset code if an account exists.",
                                          style: AppTextStyles.bodyMedium,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xl),
                                    _ForgotPasswordEmailField(
                                      controller: _emailController,
                                      focusNode: _emailFocusNode,
                                      enabled: !_isSubmitting,
                                      validator: _validateEmail,
                                      onSubmitted: (_) => _handleSubmit(),
                                    ),
                                    const SizedBox(height: AppSpacing.xl),
                                    _ForgotPasswordButton(
                                      onPressed: _handleSubmit,
                                      isLoading: _isSubmitting,
                                    ),
                                    if (_requestSucceeded) ...[
                                      const SizedBox(height: AppSpacing.sm),
                                      const Text(
                                        'If an account with this email exists, a 6-digit reset code will be sent.',
                                        style: AppTextStyles.bodySmall,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                    const SizedBox(height: AppSpacing.lg),
                                    TextButton.icon(
                                      onPressed: _isSubmitting
                                          ? null
                                          : widget.onReturnToLogin,
                                      icon: const Icon(
                                        Icons.arrow_back,
                                        size: 18.0,
                                      ),
                                      label: const Text(
                                        'Return to Login',
                                        style: AppTextStyles.bodySmall,
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            AppColors.onSurfaceVariant,
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
            ),
          ],
        ),
      ),
    );
  }
}

class _ForgotPasswordEmailField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final FormFieldValidator<String> validator;
  final ValueChanged<String>? onSubmitted;

  const _ForgotPasswordEmailField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.validator,
    this.onSubmitted,
  });

  @override
  State<_ForgotPasswordEmailField> createState() =>
      _ForgotPasswordEmailFieldState();
}

class _ForgotPasswordEmailFieldState extends State<_ForgotPasswordEmailField> {
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
        const Text('Email Address', style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          validator: widget.validator,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: widget.onSubmitted,
          style: AppTextStyles.input,
          decoration: InputDecoration(
            hintText: 'you@example.com',
            hintStyle: AppTextStyles.inputHint,
            filled: true,
            fillColor: _isFocused
                ? AppColors.surface
                : AppColors.inputBackground,
            prefixIcon: const Icon(
              Icons.mail_outline,
              color: AppColors.onSurfaceVariant,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 14.0,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

class _ForgotPasswordButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const _ForgotPasswordButton({
    required this.onPressed,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryShadow.withValues(alpha: 0.12),
            blurRadius: 16.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        height: AppSpacing.buttonHeightLarge,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.7),
            foregroundColor: AppColors.onPrimary,
            elevation: 0,
            shape: const StadiumBorder(),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 24.0,
                  height: 24.0,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.onPrimary,
                    ),
                  ),
                )
              : const Text(
                  'Send Reset Code',
                  style: AppTextStyles.buttonPrimary,
                ),
        ),
      ),
    );
  }
}
