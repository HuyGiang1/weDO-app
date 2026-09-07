import 'package:flutter/material.dart';

import 'routes.dart';
import 'theme/app_colors.dart';

/// Root application widget configuring MaterialApp, theme, and routes.
class WeDoApp extends StatelessWidget {
  const WeDoApp({super.key});

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
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
