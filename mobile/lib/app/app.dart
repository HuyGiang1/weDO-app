import 'package:flutter/material.dart';

import 'routes.dart';
import 'theme/app_colors.dart';
import '../features/auth/presentation/auth_flow_coordinator.dart';

/// Root application widget configuring MaterialApp, theme, and routes.
class WeDoApp extends StatelessWidget {
  final AuthFlowCoordinator? authFlowCoordinator;
  const WeDoApp({super.key, this.authFlowCoordinator});

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
      onGenerateRoute: (settings) =>
          AppRoutes.onGenerateRoute(settings, coordinator: authFlowCoordinator),
    );
  }
}
