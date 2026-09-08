import 'package:flutter/material.dart';

import '../data/auth_failure.dart';
import '../data/auth_repository.dart';

/// Owns only the transient Register -> Verify Email onboarding seam.
class AuthFlowCoordinator {
  final AuthRepository _repository;
  String? _registeredUserId;
  String? _profileCompletionToken;
  bool get hasProfileCompletionToken => _profileCompletionToken != null;

  AuthFlowCoordinator(this._repository);

  Future<void> register(
    BuildContext context,
    String email,
    String password,
  ) async {
    try {
      final result = await _repository.register(
        email: email,
        password: password,
      );
      if (result.nextStep != 'VERIFY_EMAIL') {
        throw StateError('Unexpected register step');
      }
      _registeredUserId = result.userId;
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pushNamed(
        '/verify-email',
        arguments: VerifyEmailFlowArgs(
          email: result.email,
          onVerify: (code) => verify(context, code),
          onResend: () => resend(context),
        ),
      );
    } on AuthException catch (error) {
      if (context.mounted) {
        _show(context, _message(error.failure));
      }
    }
  }

  Future<void> verify(BuildContext context, String code) async {
    final userId = _registeredUserId;
    if (userId == null) {
      return;
    }
    try {
      final result = await _repository.verifyEmail(userId: userId, code: code);
      if (result.nextStep != 'COMPLETE_PROFILE') {
        throw StateError('Unexpected verify step');
      }
      _profileCompletionToken = result.profileCompletionToken;
    } on AuthException catch (error) {
      if (context.mounted) {
        _show(context, _message(error.failure));
      }
    }
  }

  Future<int?> resend(BuildContext context) async {
    final userId = _registeredUserId;
    if (userId == null) {
      return null;
    }
    try {
      return (await _repository.resendVerification(userId)).cooldownSeconds;
    } on AuthException catch (error) {
      if (context.mounted) {
        _show(context, _message(error.failure));
      }
      return null;
    }
  }

  String _message(AuthFailure failure) => switch (failure.type) {
    AuthFailureType.emailAlreadyExists =>
      'An account with this email already exists.',
    AuthFailureType.verificationCodeInvalid => 'Invalid verification code.',
    AuthFailureType.verificationCodeExpired => 'Verification code has expired.',
    AuthFailureType.verificationAttemptsExceeded =>
      'Maximum verification attempts exceeded.',
    AuthFailureType.resendCooldownActive =>
      'Please wait before requesting another code.',
    AuthFailureType.network => 'Network unavailable. Please try again.',
    AuthFailureType.timeout => 'Request timed out. Please try again.',
    _ => 'Something went wrong. Please try again.',
  };
  void _show(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class VerifyEmailFlowArgs {
  final String email;
  final Future<void> Function(String) onVerify;
  final Future<int?> Function() onResend;
  const VerifyEmailFlowArgs({
    required this.email,
    required this.onVerify,
    required this.onResend,
  });
}
