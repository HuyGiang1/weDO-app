import 'package:flutter/material.dart';

import 'routes.dart';
import 'theme/app_colors.dart';
import '../features/auth/application/auth_session_controller.dart';
import '../features/auth/presentation/auth_flow_coordinator.dart';
import '../features/auth/data/models/auth_models.dart';
import '../features/profile/data/profile_models.dart';
import '../features/privacy/data/privacy_models.dart';

/// Root application widget configuring MaterialApp, theme, and routes.
class WeDoApp extends StatelessWidget {
  final AuthFlowCoordinator? authFlowCoordinator;
  final AuthSessionController authSessionController;
  final Future<CurrentUser> Function()? loadCurrentUser;
  final Future<CurrentUser> Function(UpdateProfileRequest request)?
  updateProfile;
  final Future<CurrentUser> Function(UpdateUsernameRequest request)?
  updateUsername;
  final Future<void> Function({required String currentPassword, required String newPassword})? changePassword;
  final Future<bool> Function()? endSessionAfterPasswordChange;
  final Future<PrivacySettings> Function()? loadPrivacySettings;
  final Future<PrivacySettings> Function(UpdatePrivacySettingsRequest request)?
  updatePrivacySettings;

  const WeDoApp({
    super.key,
    this.authFlowCoordinator,
    required this.authSessionController,
    this.loadCurrentUser,
    this.updateProfile,
    this.updateUsername,
    this.changePassword,
    this.endSessionAfterPasswordChange,
    this.loadPrivacySettings,
    this.updatePrivacySettings,
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
        settings.name == AppRoutes.profile &&
                loadCurrentUser != null &&
                updateProfile != null &&
                updateUsername != null && changePassword != null && endSessionAfterPasswordChange != null
            ? RouteSettings(
                name: settings.name,
                arguments: ProfileRouteArgs(
                  loadCurrentUser: loadCurrentUser!,
                  updateProfile: updateProfile!,
                  updateUsername: updateUsername!,
                  changePassword: changePassword!,
                  endSessionAfterPasswordChange: endSessionAfterPasswordChange!,
                ),
              )
            : settings.name == AppRoutes.privacy &&
                  loadPrivacySettings != null &&
                  updatePrivacySettings != null
            ? RouteSettings(
                name: settings.name,
                arguments: PrivacyRouteArgs(
                  loadPrivacySettings: loadPrivacySettings!,
                  updatePrivacySettings: updatePrivacySettings!,
                ),
              )
            : settings,
        authStatus: authSessionController.status,
        coordinator: authFlowCoordinator,
      ),
    );
  }
}
