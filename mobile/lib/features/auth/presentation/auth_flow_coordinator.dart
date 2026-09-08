import 'package:flutter/material.dart';

import '../data/auth_failure.dart';
import '../data/auth_repository.dart';
import '../data/models/auth_models.dart';
import 'screens/complete_profile_screen.dart';
import 'screens/create_username_screen.dart';

/// Owns only the transient Register -> Verify Email onboarding seam.
class AuthFlowCoordinator {
  final AuthRepository _repository;
  String? _registeredUserId;
  String? _profileCompletionToken;
  String? _selectedUsername;
  bool get hasProfileCompletionToken => _profileCompletionToken != null;

  AuthFlowCoordinator(this._repository);

  Future<void> login(
    BuildContext context,
    String email,
    String password,
  ) async {
    try {
      final result = await _repository.login(
        email: email,
        password: password,
        deviceName: null,
      );
      if (result is AuthenticatedSession) {
        _clearOnboardingState();
        if (context.mounted) _show(context, 'Signed in successfully.');
        return;
      }
      if (result is ProfileCompletionRequired) {
        // An incomplete-profile result belongs to a new account boundary, so
        // it must never coexist with a previous account's bearer session.
        _clearOnboardingState();
        await _repository.clearLocalSession();
        _registeredUserId = result.userId;
        _profileCompletionToken = result.profileCompletionToken;
        if (context.mounted) {
          Navigator.of(context).pushNamed(
            '/create-username',
            arguments: CreateUsernameFlowArgs(
              onCheckAvailability: (username) => checkUsername(context, username),
              onContinue: (username) => selectUsername(context, username),
            ),
          );
        }
      }
    } on AuthException catch (error) {
      if (context.mounted) _show(context, _message(error.failure));
    }
  }

  void _clearOnboardingState() {
    _registeredUserId = null;
    _profileCompletionToken = null;
    _selectedUsername = null;
  }

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
      if (context.mounted) {
        Navigator.of(context).pushNamed(
          '/create-username',
          arguments: CreateUsernameFlowArgs(
            onCheckAvailability: (username) => checkUsername(context, username),
            onContinue: (username) => selectUsername(context, username),
          ),
        );
      }
    } on AuthException catch (error) {
      if (context.mounted) {
        _show(context, _message(error.failure));
      }
    }
  }

  Future<UsernameAvailability> checkUsername(
    BuildContext context,
    String username,
  ) async {
    try {
      final result = await _repository.checkUsernameAvailability(username);
      return result.available
          ? UsernameAvailability.available
          : UsernameAvailability.unavailable;
    } on AuthException {
      rethrow;
    }
  }

  Future<void> selectUsername(BuildContext context, String username) async {
    _selectedUsername = username;
    if (context.mounted) {
      Navigator.of(context).pushNamed(
        '/complete-profile',
        arguments: CompleteProfileFlowArgs(
          username: username,
          onContinue: (data) => completeProfile(context, data),
        ),
      );
    }
  }

  Future<void> completeProfile(
    BuildContext context,
    CompleteProfileData data,
  ) async {
    final token = _profileCompletionToken;
    final username = _selectedUsername;
    if (token == null || username == null) {
      return;
    }
    try {
      final result = await _repository.completeProfile(
        profileCompletionToken: token,
        username: username,
        displayName: data.displayName,
        bio: data.bio,
        avatarStorageKey: null,
      );
      if (result.nextStep != 'LOGIN') {
        throw StateError('Unexpected complete-profile step');
      }
      _clearOnboardingState();
      if (context.mounted) {
        Navigator.of(context).pushNamed('/login');
      }
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
    AuthFailureType.invalidCredentials => 'Invalid email or password.',
    AuthFailureType.emailNotVerified => 'Please verify your email first.',
    AuthFailureType.accountLocked => 'This account is locked.',
    AuthFailureType.accountSuspended => 'This account is suspended.',
    AuthFailureType.accountDeactivated => 'This account is deactivated.',
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

class CreateUsernameFlowArgs {
  final Future<UsernameAvailability> Function(String) onCheckAvailability;
  final Future<void> Function(String) onContinue;
  const CreateUsernameFlowArgs({
    required this.onCheckAvailability,
    required this.onContinue,
  });
}

class CompleteProfileFlowArgs {
  final String username;
  final Future<void> Function(CompleteProfileData) onContinue;
  const CompleteProfileFlowArgs({
    required this.username,
    required this.onContinue,
  });
}
