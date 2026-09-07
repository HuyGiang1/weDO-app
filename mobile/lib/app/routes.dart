import 'package:flutter/material.dart';

import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/verify_email_screen.dart';
import '../features/auth/presentation/screens/welcome_screen.dart';

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

/// Application route definitions and Navigator 1.0 generator.
abstract final class AppRoutes {
  static const String welcome = '/';
  static const String register = '/register';
  static const String verifyEmail = '/verify-email';
  static const String login = '/login';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
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
          ),
          settings: settings,
        );
      case verifyEmail:
        final arguments = settings.arguments;
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
