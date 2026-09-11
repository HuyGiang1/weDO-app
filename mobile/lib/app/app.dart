import 'package:flutter/material.dart';

import 'routes.dart';
import 'theme/app_colors.dart';
import '../features/auth/application/auth_session_controller.dart';
import '../features/auth/presentation/auth_flow_coordinator.dart';
import '../features/auth/data/models/auth_models.dart';

/// Root application widget configuring MaterialApp, theme, and routes.
class WeDoApp extends StatelessWidget {
  final AuthFlowCoordinator? authFlowCoordinator;
  final AuthSessionController authSessionController;
  final Future<CurrentUser> Function()? loadCurrentUser;

  const WeDoApp({
    super.key,
    this.authFlowCoordinator,
    required this.authSessionController,
    this.loadCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WeDo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.backgroundGradientStart,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
      ),
      initialRoute: AppRoutes.welcome,
      onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(
        settings.name == AppRoutes.profile && loadCurrentUser != null
            ? RouteSettings(name: settings.name, arguments: loadCurrentUser)
            : settings,
        authStatus: authSessionController.status,
        coordinator: authFlowCoordinator,
      ),
    );
  }
}
