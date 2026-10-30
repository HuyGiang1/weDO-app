import 'package:flutter/material.dart';

import '../../../../core/ui/widgets/wedo_brand_mark.dart';

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
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
                                        child: const WeDoBrandMark(size: 72),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    Text(
                                      'Forgot Password?',
                                      style: AppTextStyles.of(context).headline,
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
                                          style: AppTextStyles.of(context)
                                              .bodyMedium,
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
                                      Text(
                                        'If an account with this email exists, a 6-digit reset code will be sent.',
                                        style: AppTextStyles.of(context)
                                            .bodySmall,
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
                                      label: Text(
                                        'Return to Login',
                                        style: AppTextStyles.of(context)
                                            .bodySmall,
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
        Text('Email Address', style: AppTextStyles.of(context).label),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          validator: widget.validator,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: widget.onSubmitted,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'you@example.com',
            hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
            filled: true,
            fillColor: _isFocused
                ? Theme.of(context).colorScheme.surface
                : Theme.of(context).colorScheme.surfaceContainerLow,
            prefixIcon: Icon(
              Icons.mail_outline,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 14.0,
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
                  'Send Reset Code',
                  style: AppTextStyles.of(context).buttonPrimary,
                ),
        ),
      ),
    );
  }
}
