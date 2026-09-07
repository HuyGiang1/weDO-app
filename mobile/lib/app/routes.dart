import 'package:flutter/material.dart';

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
              // App-level wiring seam: will connect to RegisterScreen when implemented
            },
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
