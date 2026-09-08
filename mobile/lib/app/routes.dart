import 'package:flutter/material.dart';

import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/reset_password_screen.dart';
import '../features/auth/presentation/screens/verify_email_screen.dart';
import '../features/auth/presentation/screens/welcome_screen.dart';
import '../features/auth/presentation/screens/create_username_screen.dart';
import '../features/auth/presentation/screens/complete_profile_screen.dart';
import '../features/auth/presentation/auth_flow_coordinator.dart';

/// Data required to render the verification screen from a real auth flow.
///
/// API integration remains outside presentation; future callbacks can capture
/// any integration-only state there without exposing it to the screen.
class VerifyEmailRouteArgs {
  final String email;
  final int initialCooldownSeconds;

  const VerifyEmailRouteArgs({
    required this.email,
    required this.initialCooldownSeconds,
  });
}

class ResetPasswordRouteArgs {
  final String email;

  const ResetPasswordRouteArgs({required this.email});
}

/// Application route definitions and Navigator 1.0 generator.
abstract final class AppRoutes {
  static const String welcome = '/';
  static const String register = '/register';
  static const String verifyEmail = '/verify-email';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String createUsername = '/create-username';
  static const String completeProfile = '/complete-profile';

  static Route<dynamic>? onGenerateRoute(
    RouteSettings settings, {
    AuthFlowCoordinator? coordinator,
  }) {
    switch (settings.name) {
      case welcome:
        return MaterialPageRoute<void>(
          builder: (context) => WelcomeScreen(
            onCreateAccountPressed: () {
              Navigator.of(context).pushNamed(register);
            },
            onLoginPressed: () {
              Navigator.of(context).pushNamed(login);
            },
          ),
          settings: settings,
        );
      case register:
        return MaterialPageRoute<void>(
          builder: (context) => RegisterScreen(
            onSubmit: coordinator == null
                ? null
                : (email, password) =>
                      coordinator.register(context, email, password),
            onLoginPressed: () {
              Navigator.of(context).pushNamed(login);
            },
          ),
          settings: settings,
        );
      case login:
        return MaterialPageRoute<void>(
          builder: (context) => LoginScreen(
            onCreateAccount: () => Navigator.of(context).pushNamed(register),
            onForgotPassword: () =>
                Navigator.of(context).pushNamed(forgotPassword),
          ),
          settings: settings,
        );
      case createUsername:
        final args = settings.arguments;
        if (args is! CreateUsernameFlowArgs) return null;
        return MaterialPageRoute<void>(
          builder: (_) => CreateUsernameScreen(
            onCheckAvailability: args.onCheckAvailability,
            onContinue: args.onContinue,
          ),
          settings: settings,
        );
      case completeProfile:
        final args = settings.arguments;
        if (args is! CompleteProfileFlowArgs) return null;
        return MaterialPageRoute<void>(
          builder: (_) => CompleteProfileScreen(
            username: args.username,
            onContinue: args.onContinue,
          ),
          settings: settings,
        );
      case forgotPassword:
        return MaterialPageRoute<void>(
          builder: (context) => ForgotPasswordScreen(
            onBack: () => Navigator.of(context).maybePop(),
            onReturnToLogin: () => Navigator.of(context).maybePop(),
          ),
          settings: settings,
        );
      case resetPassword:
        final arguments = settings.arguments;
        if (arguments is! ResetPasswordRouteArgs ||
            arguments.email.trim().isEmpty) {
          return null;
        }
        return MaterialPageRoute<void>(
          builder: (context) => ResetPasswordScreen(
            email: arguments.email,
            onBackToLogin: () => Navigator.of(context).popUntil(
              (route) => route.settings.name == login || route.isFirst,
            ),
          ),
          settings: settings,
        );
      case verifyEmail:
        final arguments = settings.arguments;
        if (arguments is VerifyEmailFlowArgs) {
          return MaterialPageRoute<void>(
            builder: (context) => VerifyEmailScreen(
              email: arguments.email,
              initialCooldownSeconds: 0,
              onBack: () => Navigator.of(context).maybePop(),
              onChangeEmail: () => Navigator.of(context).maybePop(),
              onVerify: arguments.onVerify,
              onResend: arguments.onResend,
            ),
            settings: settings,
          );
        }
        if (arguments is! VerifyEmailRouteArgs ||
            arguments.email.isEmpty ||
            arguments.initialCooldownSeconds < 0) {
          return null;
        }
        return MaterialPageRoute<void>(
          builder: (context) => VerifyEmailScreen(
            email: arguments.email,
            initialCooldownSeconds: arguments.initialCooldownSeconds,
            onBack: () => Navigator.of(context).maybePop(),
            onChangeEmail: () => Navigator.of(context).maybePop(),
          ),
          settings: settings,
        );
      default:
        return null;
    }
  }
}
