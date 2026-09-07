import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/ui/widgets/primary_button.dart';
import '../widgets/otp_code_field.dart';

/// Presentation screen for email verification.
///
/// Faithfully ported from Stitch visual design with backend-driven 6-digit OTP adaptation.
class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final VoidCallback onBack;
  final VoidCallback onChangeEmail;
  final int initialCooldownSeconds;
  final Future<void> Function(String code)? onVerify;
  final Future<int?> Function()? onResend;
  final VoidCallback? onVerificationSuccess;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.onBack,
    required this.onChangeEmail,
    required this.initialCooldownSeconds,
    this.onVerify,
    this.onResend,
    this.onVerificationSuccess,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final GlobalKey<OtpCodeFieldState> _otpKey = GlobalKey<OtpCodeFieldState>();

  String _currentCode = '';
  String? _validationError;

  late int _cooldownSeconds;
  Timer? _cooldownTimer;

  bool _isSubmitting = false;
  bool _isResending = false;

  bool get _isBusy => _isSubmitting || _isResending;

  @override
  void initState() {
    super.initState();
    _cooldownSeconds = widget.initialCooldownSeconds;
    if (_cooldownSeconds > 0) {
      _startCooldownTimer();
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_cooldownSeconds > 1) {
        setState(() {
          _cooldownSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _cooldownSeconds = 0;
        });
      }
    });
  }

  String _formatCooldown(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _handleResend() async {
    if (_cooldownSeconds > 0 || _isBusy) return;
    if (widget.onResend == null) return;

    setState(() {
      _isResending = true;
      _validationError = null;
    });

    try {
      final newCooldown = await widget.onResend!();
      if (!mounted) return;
      if (newCooldown != null && newCooldown > 0) {
        setState(() {
          _cooldownSeconds = newCooldown;
        });
        _startCooldownTimer();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (_isBusy) return;

    if (_currentCode.length < OtpCodeFieldState.codeLength) {
      setState(() {
        _validationError = 'Please enter the complete 6-digit code';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _validationError = null;
    });

    try {
      if (widget.onVerify != null) {
        await widget.onVerify!(_currentCode);
        if (!mounted) return;
        widget.onVerificationSuccess?.call();
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
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Back button positioned ABOVE the main card
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: 40.0,
                              height: 40.0,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back_rounded),
                                color: AppColors.onSurfaceVariant,
                                padding: EdgeInsets.zero,
                                onPressed: _isBusy ? null : widget.onBack,
                                tooltip: 'Back',
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),

                          // 2. Main Card with 24px border radius
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(24.0),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryShadow.withValues(
                                    alpha: 0.08,
                                  ),
                                  blurRadius: 24.0,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: constraints.maxWidth < 380
                                  ? AppSpacing.lg
                                  : AppSpacing.xl,
                              vertical: AppSpacing.xl,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Logo (64x64, centered, NOT rotated)
                                Center(
                                  child: Container(
                                    width: 64.0,
                                    height: 64.0,
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(16.0),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: AppColors.primaryShadow,
                                          blurRadius: 16.0,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(16.0),
                                      child: Image.asset(
                                        'assets/images/wedo_logo.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),

                                // Title
                                const Text(
                                  'Check your email',
                                  style: AppTextStyles.headline,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppSpacing.xs),

                                // Description with highlighted email
                                Text.rich(
                                  TextSpan(
                                    text: 'We sent a verification code to ',
                                    style: AppTextStyles.bodyMedium,
                                    children: [
                                      TextSpan(
                                        text: widget.email,
                                        style: AppTextStyles.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.onSurface,
                                        ),
                                      ),
                                      const TextSpan(
                                        text:
                                            '. Please enter it below to verify your account.',
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppSpacing.xl),

                                // 6-digit OTP input field
                                OtpCodeField(
                                  key: _otpKey,
                                  enabled: !_isBusy,
                                  errorText: _validationError,
                                  onChanged: (code) {
                                    _currentCode = code;
                                    if (_validationError != null) {
                                      setState(() {
                                        _validationError = null;
                                      });
                                    }
                                  },
                                  onCompleted: (code) {
                                    _currentCode = code;
                                  },
                                ),
                                const SizedBox(height: AppSpacing.lg),

                                // Resend section
                                Center(
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 4.0,
                                    children: [
                                      const Text(
                                        "Didn't receive the code?",
                                        style: AppTextStyles.bodySmall,
                                      ),
                                      if (_cooldownSeconds > 0)
                                        Text(
                                          'Resend in ${_formatCooldown(_cooldownSeconds)}',
                                          style: AppTextStyles.bodySmall.copyWith(
                                            color: AppColors.onSurfaceVariant
                                                .withValues(alpha: 0.6),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        )
                                      else if (_isResending)
                                        const SizedBox(
                                          width: 14.0,
                                          height: 14.0,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.0,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              AppColors.primary,
                                            ),
                                          ),
                                        )
                                      else
                                        TextButton(
                                          onPressed: _isBusy
                                              ? null
                                              : _handleResend,
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            tapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: const Text(
                                            'Resend Code',
                                            style: AppTextStyles.link,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xl),

                                // Continue Primary Button (NO trailing icon, exact label "Continue")
                                PrimaryButton(
                                  label: 'Continue',
                                  isLoading: _isSubmitting,
                                  onPressed: _isBusy ? null : _handleSubmit,
                                ),
                                const SizedBox(height: AppSpacing.lg),

                                // Bottom action: Change email address (NO "Wrong email?" prefix)
                                Center(
                                  child: TextButton(
                                    onPressed:
                                        _isBusy ? null : widget.onChangeEmail,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Change email address',
                                      style: AppTextStyles.link,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
