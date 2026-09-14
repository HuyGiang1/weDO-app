import 'package:flutter/material.dart';

import 'auth_route_guard.dart';
import '../features/auth/application/auth_session_controller.dart';
import '../features/auth/presentation/auth_flow_coordinator.dart';
import '../features/auth/presentation/screens/complete_profile_screen.dart';
import '../features/auth/presentation/screens/create_username_screen.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/reset_password_screen.dart';
import '../features/auth/presentation/screens/verify_email_screen.dart';
import '../features/auth/presentation/screens/welcome_screen.dart';
import '../features/auth/data/models/auth_models.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/profile/presentation/screens/change_password_screen.dart';
import '../features/profile/data/profile_models.dart';
import '../features/privacy/data/privacy_models.dart';
import '../features/privacy/presentation/screens/privacy_settings_screen.dart';
import '../features/qr/data/personal_qr.dart';
import '../features/qr/presentation/screens/personal_qr_screen.dart';

export 'auth_route_guard.dart';

/// Data required to render the verification screen from a real auth flow.
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

class ProfileRouteArgs {
  final Future<CurrentUser> Function() loadCurrentUser;
  final Future<CurrentUser> Function(UpdateProfileRequest request)
  updateProfile;
  final Future<CurrentUser> Function(UpdateUsernameRequest request)
  updateUsername;
  final Future<void> Function({required String currentPassword, required String newPassword}) changePassword;
  final Future<bool> Function() endSessionAfterPasswordChange;

  const ProfileRouteArgs({
    required this.loadCurrentUser,
    required this.updateProfile,
    required this.updateUsername,
    required this.changePassword,
    required this.endSessionAfterPasswordChange,
  });
}
class ChangePasswordRouteArgs {
  final Future<void> Function({required String currentPassword, required String newPassword}) changePassword;
  final Future<bool> Function() endSessionAfterPasswordChange;
  const ChangePasswordRouteArgs({required this.changePassword, required this.endSessionAfterPasswordChange});
}

class PrivacyRouteArgs {
  final Future<PrivacySettings> Function() loadPrivacySettings;
  final Future<PrivacySettings> Function(UpdatePrivacySettingsRequest request)
  updatePrivacySettings;

  const PrivacyRouteArgs({
    required this.loadPrivacySettings,
    required this.updatePrivacySettings,
  });
}
class PersonalQrRouteArgs {
  final Future<PersonalQr> Function() loadPersonalQr;
  const PersonalQrRouteArgs({required this.loadPersonalQr});
}

/// A unified route definition binding access policy to route construction.
final class AppRouteDefinition {
  final AppRouteAccess access;
  final Route<dynamic>? Function(
    RouteSettings settings,
    AuthFlowCoordinator? coordinator,
  )
  builder;

  const AppRouteDefinition({required this.access, required this.builder});
}

/// Application route definitions, registry, and Navigator 1.0 generator.
abstract final class AppRoutes {
  static const String welcome = '/';
  static const String register = '/register';
  static const String verifyEmail = '/verify-email';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String createUsername = '/create-username';
  static const String completeProfile = '/complete-profile';
  static const String profile = '/profile';
  static const String changePassword = '/profile/change-password';
  static const String privacy = '/profile/privacy';
  static const String personalQr = '/profile/qr';

  static final Map<String, AppRouteDefinition> _routes = {
    welcome: AppRouteDefinition(
      access: AppRouteAccess.public,
      builder: (settings, coordinator) => MaterialPageRoute<void>(
        builder: (context) => WelcomeScreen(
          onCreateAccountPressed: () {
            Navigator.of(context).pushNamed(register);
          },
          onLoginPressed: () {
            Navigator.of(context).pushNamed(login);
          },
        ),
        settings: settings,
      ),
    ),
    register: AppRouteDefinition(
      access: AppRouteAccess.public,
      builder: (settings, coordinator) => MaterialPageRoute<void>(
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
      ),
    ),
    login: AppRouteDefinition(
      access: AppRouteAccess.public,
      builder: (settings, coordinator) => MaterialPageRoute<void>(
        builder: (context) => LoginScreen(
          onLogin: coordinator == null
              ? null
              : ({required email, required password}) =>
                    coordinator.login(context, email, password),
          onCreateAccount: () => Navigator.of(context).pushNamed(register),
          onForgotPassword: () =>
              Navigator.of(context).pushNamed(forgotPassword),
        ),
        settings: settings,
      ),
    ),
    createUsername: AppRouteDefinition(
      access: AppRouteAccess.public,
      builder: (settings, coordinator) {
        final args = settings.arguments;
        if (args is! CreateUsernameFlowArgs) return null;
        return MaterialPageRoute<void>(
          builder: (_) => CreateUsernameScreen(
            onCheckAvailability: args.onCheckAvailability,
            onContinue: args.onContinue,
          ),
          settings: settings,
        );
      },
    ),
    completeProfile: AppRouteDefinition(
      access: AppRouteAccess.public,
      builder: (settings, coordinator) {
        final args = settings.arguments;
        if (args is! CompleteProfileFlowArgs) return null;
        return MaterialPageRoute<void>(
          builder: (_) => CompleteProfileScreen(
            username: args.username,
            onContinue: args.onContinue,
          ),
          settings: settings,
        );
      },
    ),
    forgotPassword: AppRouteDefinition(
      access: AppRouteAccess.public,
      builder: (settings, coordinator) => MaterialPageRoute<void>(
        builder: (context) => ForgotPasswordScreen(
          onSubmit: coordinator == null
              ? null
              : ({required email}) =>
                    coordinator.forgotPassword(context, email),
          onBack: () => Navigator.of(context).maybePop(),
          onReturnToLogin: () => Navigator.of(context).maybePop(),
          onRequestSuccess: (email) => Navigator.of(context).pushNamed(
            resetPassword,
            arguments: ResetPasswordRouteArgs(email: email),
          ),
        ),
        settings: settings,
      ),
    ),
    resetPassword: AppRouteDefinition(
      access: AppRouteAccess.public,
      builder: (settings, coordinator) {
        final arguments = settings.arguments;
        if (arguments is! ResetPasswordRouteArgs ||
            arguments.email.trim().isEmpty) {
          return null;
        }
        return MaterialPageRoute<void>(
          builder: (context) => ResetPasswordScreen(
            email: arguments.email,
            onSubmit: coordinator == null
                ? null
                : ({required email, required code, required newPassword}) =>
                      coordinator.resetPassword(
                        context,
                        email: email,
                        code: code,
                        newPassword: newPassword,
                      ),
            onBackToLogin: () => Navigator.of(context).popUntil(
              (route) => route.settings.name == login || route.isFirst,
            ),
            onResetSuccess: () {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(context).popUntil(
                (route) => route.settings.name == login || route.isFirst,
              );
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Password updated. You can now log in.'),
                ),
              );
            },
          ),
          settings: settings,
        );
      },
    ),
    verifyEmail: AppRouteDefinition(
      access: AppRouteAccess.public,
      builder: (settings, coordinator) {
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
      },
    ),
    profile: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final loader = settings.arguments;
        if (loader is! ProfileRouteArgs) return null;
        return MaterialPageRoute<void>(
          builder: (_) => ProfileScreen(
            loadCurrentUser: loader.loadCurrentUser,
            updateProfile: loader.updateProfile,
            updateUsername: loader.updateUsername,
            changePassword: loader.changePassword,
            endSessionAfterPasswordChange: loader.endSessionAfterPasswordChange,
          ),
          settings: settings,
        );
      },
    ),
    changePassword: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final args = settings.arguments;
        if (args is! ChangePasswordRouteArgs) return null;
        return MaterialPageRoute<void>(
          builder: (context) => ChangePasswordScreen(
            changePassword: args.changePassword,
            endSessionAfterPasswordChange: args.endSessionAfterPasswordChange,
            onSuccess: () {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(context).pushNamedAndRemoveUntil(login, (route) => false);
              messenger.showSnackBar(const SnackBar(content: Text('Password changed. Please sign in again.')));
            },
          ), settings: settings);
      },
    ),
    privacy: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final args = settings.arguments;
        if (args is! PrivacyRouteArgs) return null;
        return MaterialPageRoute<void>(
          builder: (_) => PrivacySettingsScreen(
            loadPrivacySettings: args.loadPrivacySettings,
            updatePrivacySettings: args.updatePrivacySettings,
          ),
          settings: settings,
        );
      },
    ),
    personalQr: AppRouteDefinition(
      access: AppRouteAccess.authenticated,
      builder: (settings, coordinator) {
        final args = settings.arguments;
        if (args is! PersonalQrRouteArgs) return null;
        return MaterialPageRoute<void>(builder: (_) => PersonalQrScreen(loadPersonalQr: args.loadPersonalQr), settings: settings);
      },
    ),
  };

  /// Read-only view of all registered production route definitions.
  static Map<String, AppRouteDefinition> get routes =>
      Map.unmodifiable(_routes);

  /// Evaluates guard policy and invokes the builder if and only if access is allowed.
  @visibleForTesting
  static Route<dynamic>? evaluateAndBuildRoute(
    AppRouteDefinition definition,
    RouteSettings settings, {
    required AuthSessionStatus authStatus,
    AuthFlowCoordinator? coordinator,
  }) {
    final decision = AuthRouteGuard.evaluate(
      access: definition.access,
      authStatus: authStatus,
    );
    if (decision != RouteGuardDecision.allow) {
      return null;
    }
    return definition.builder(settings, coordinator);
  }

  /// Evaluates route existence and authorization before building any target screen.
  static Route<dynamic>? onGenerateRoute(
    RouteSettings settings, {
    required AuthSessionStatus authStatus,
    AuthFlowCoordinator? coordinator,
  }) {
    final name = settings.name;
    if (name == null) {
      return null;
    }

    final definition = _routes[name];
    if (definition == null) {
      return null;
    }

    return evaluateAndBuildRoute(
      definition,
      settings,
      authStatus: authStatus,
      coordinator: coordinator,
    );
  }
}
