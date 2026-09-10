import 'dart:convert' show utf8;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/ui/widgets/app_password_field.dart';
import '../../../../core/ui/widgets/app_text_field.dart';
import '../../../../core/ui/widgets/primary_button.dart';

/// Presentation screen for user registration.
///
/// Ported cleanly from Stitch visual design.
class RegisterScreen extends StatefulWidget {
  final Future<void> Function(String email, String password)? onSubmit;
  final VoidCallback onLoginPressed;
  final VoidCallback? onRegistrationSuccess;

  const RegisterScreen({
    super.key,
    required this.onLoginPressed,
    this.onSubmit,
    this.onRegistrationSuccess,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    // Backend contract: password length in UTF-8 bytes must not exceed 72
    if (utf8.encode(value).length > 72) {
      return 'Password must not exceed 72 bytes';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;

      if (widget.onSubmit != null) {
        await widget.onSubmit!(email, password);
        if (!mounted) return;
        widget.onRegistrationSuccess?.call();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGradientStart,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSpacing.maxContentWidth,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.lg,
                      ),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(32.0),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryShadow.withValues(
                                alpha: 0.08,
                              ),
                              blurRadius: 30.0,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: constraints.maxWidth < 380
                              ? AppSpacing.lg
                              : AppSpacing.xl,
                          vertical: AppSpacing.xl,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _HeaderSection(),
                              const SizedBox(height: AppSpacing.xl),
                              AppTextField(
                                label: 'Email',
                                controller: _emailController,
                                hintText: 'you@wedo.social',
                                prefixIcon: const Icon(
                                  Icons.mail_outline_rounded,
                                  color: AppColors.onSurfaceVariant,
                                  size: 20.0,
                                ),
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: _validateEmail,
                                enabled: !_isSubmitting,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppPasswordField(
                                label: 'Password',
                                controller: _passwordController,
                                hintText: '••••••••',
                                textInputAction: TextInputAction.next,
                                validator: _validatePassword,
                                enabled: !_isSubmitting,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppPasswordField(
                                label: 'Confirm Password',
                                controller: _confirmPasswordController,
                                hintText: '••••••••',
                                prefixIcon: const Icon(
                                  Icons.lock_clock_outlined,
                                  color: AppColors.onSurfaceVariant,
                                  size: 20.0,
                                ),
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleSubmit(),
                                validator: _validateConfirmPassword,
                                enabled: !_isSubmitting,
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              PrimaryButton(
                                label: 'Create Account',
                                trailingIcon: Icons.arrow_forward_rounded,
                                isLoading: _isSubmitting,
                                onPressed: _handleSubmit,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _FooterSection(
                                onLoginPressed: _isSubmitting
                                    ? null
                                    : widget.onLoginPressed,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Transform.rotate(
          angle: 3.0 * (math.pi / 180.0),
          child: Container(
            width: 64.0,
            height: 64.0,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.primaryShadow,
                  blurRadius: 16.0,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.0),
              child: Image.asset(
                'assets/images/wedo_logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Join WeDo',
          style: AppTextStyles.headline,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Connect with your community.',
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _FooterSection extends StatelessWidget {
  final VoidCallback? onLoginPressed;

  const _FooterSection({this.onLoginPressed});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Already have an account? ', style: AppTextStyles.bodySmall),
        GestureDetector(
          onTap: onLoginPressed,
          child: const Text('Login', style: AppTextStyles.link),
        ),
      ],
    );
  }
}
