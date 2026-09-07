import 'package:flutter/material.dart';

import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/welcome_screen.dart';

/// Application route definitions and Navigator 1.0 generator.
abstract final class AppRoutes {
  static const String welcome = '/';
  static const String register = '/register';
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
              // App-level wiring seam: will connect to LoginScreen when implemented
            },
          ),
          settings: settings,
        );
      default:
        return null;
    }
  }
}
