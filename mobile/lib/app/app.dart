import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'routes.dart';
import '../features/community/data/community_api.dart';
import 'theme/app_theme.dart';
import '../features/auth/application/auth_session_controller.dart';
import '../features/auth/presentation/auth_flow_coordinator.dart';
import '../features/auth/data/models/auth_models.dart';
import '../features/profile/data/profile_models.dart';
import '../features/groups/data/group_repository.dart';
import '../features/privacy/data/privacy_models.dart';
import '../features/qr/data/personal_qr.dart';
import '../features/chat/data/chat_repository.dart';
import '../features/chat/data/chat_api.dart';
import '../features/social/data/social_repository.dart';

/// Root application widget configuring MaterialApp, theme, and routes.
class WeDoApp extends StatelessWidget {
  final AuthFlowCoordinator? authFlowCoordinator;
  final AuthSessionController authSessionController;
  final GroupRepository? groupRepository;
  final ChatRepository? chatRepository;
  final SocialRepository? socialRepository;
  final SearchRouteArgs? searchRouteArgs;
  final Future<CurrentUser> Function()? loadCurrentUser;
  final Future<CurrentUser> Function(UpdateProfileRequest request)?
  updateProfile;
  final Future<String> Function({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  })?
  uploadAvatar;
  final Future<CurrentUser> Function(UpdateUsernameRequest request)?
  updateUsername;
  final Future<void> Function({
    required String currentPassword,
    required String newPassword,
  })?
  changePassword;
  final Future<bool> Function()? endSessionAfterPasswordChange;
  final Future<PrivacySettings> Function()? loadPrivacySettings;
  final Future<PrivacySettings> Function(UpdatePrivacySettingsRequest request)?
  updatePrivacySettings;
  final Future<PersonalQr> Function()? loadPersonalQr;
  final Future<PublicUserProfile> Function(String userId)? loadPublicProfile;
  final Future<void> Function()? logout;
  final VoidCallback? onScanQr;
  final GlobalKey<NavigatorState>? navigatorKey;
  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  const WeDoApp({
    super.key,
    this.authFlowCoordinator,
    required this.authSessionController,
    this.groupRepository,
    this.chatRepository,
    this.socialRepository,
    this.searchRouteArgs,
    this.loadCurrentUser,
    this.updateProfile,
    this.uploadAvatar,
    this.updateUsername,
    this.changePassword,
    this.endSessionAfterPasswordChange,
    this.loadPrivacySettings,
    this.updatePrivacySettings,
    this.loadPersonalQr,
    this.loadPublicProfile,
    this.logout,
    this.onScanQr,
    this.navigatorKey,
    this.scaffoldMessengerKey,
  });

  @override
  Widget build(BuildContext context) {
    final rootRoute =
        authSessionController.isAuthenticated && groupRepository != null
        ? AppRoutes.home
        : AppRoutes.welcome;
    RouteSettings withRootSearch(RouteSettings settings) {
      final args = settings.arguments;
      if (settings.name == AppRoutes.search && args == null && searchRouteArgs != null) {
        return RouteSettings(name: settings.name, arguments: searchRouteArgs);
      }
      if (settings.name == AppRoutes.community && args == null && groupRepository != null) {
        return RouteSettings(name: settings.name, arguments: CommunityApi(groupRepository!.api.dio));
      }
      if (settings.name == AppRoutes.chatHome && args == null && groupRepository != null) {
        return RouteSettings(name: settings.name, arguments: ChatHomeRouteArgs(chatRepository ?? ChatRepository(ChatApi(groupRepository!.api.dio)), groupRepository!, searchArgs: searchRouteArgs));
      }
      if (settings.name == AppRoutes.calendar && args == null && groupRepository != null) {
        return RouteSettings(name: settings.name, arguments: CalendarRouteArgs(groupRepository!, searchArgs: searchRouteArgs));
      }
      if (settings.name == AppRoutes.home && args is HomeRouteArgs) {
        return RouteSettings(
          name: settings.name,
          arguments: HomeRouteArgs(
            repository: args.repository,
            searchArgs: args.searchArgs ?? searchRouteArgs,
          ),
        );
      }
      if (settings.name == AppRoutes.groups && args is GroupsRouteArgs) {
        return RouteSettings(
          name: settings.name,
          arguments: GroupsRouteArgs(
            repository: args.repository,
            searchArgs: args.searchArgs ?? searchRouteArgs,
            initialCode: args.initialCode,
          ),
        );
      }
      return settings;
    }

    return _SessionNavigationBoundary(
      controller: authSessionController,
      navigatorKey: navigatorKey,
      builder: (key) => MaterialApp(
        navigatorKey: key,
        scaffoldMessengerKey: scaffoldMessengerKey,
        title: 'WeDo',
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        initialRoute: rootRoute,
        // Flutter's default slash-route expansion inserts '/' below '/home'.
        // Restored sessions must have exactly one authenticated root before a
        // pending notification/deep link is pushed onto this navigator.
        // Android FCM data's "route" extra is also FlutterActivity's reserved
        // initial-route extra. WidgetsApp prioritizes that platform route over
        // initialRoute. Always bootstrap our session root here; the queued push
        // (or platform-link handler) resolves its target after this root exists.
        onGenerateInitialRoutes: (_) => [
          AppRoutes.onGenerateRoute(
            RouteSettings(
              name: rootRoute,
              arguments: rootRoute == AppRoutes.home && groupRepository != null
                  ? HomeRouteArgs(
                      repository: groupRepository!,
                      searchArgs: searchRouteArgs,
                    )
                  : null,
            ),
            authStatus: authSessionController.status,
            coordinator: authFlowCoordinator,
          )!,
        ],
        onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(
          settings.name == AppRoutes.home &&
                  groupRepository != null &&
                  settings.arguments == null
              ? RouteSettings(
                  name: settings.name,
                  arguments: HomeRouteArgs(
                    repository: groupRepository!,
                    searchArgs: searchRouteArgs,
                  ),
                )
              : settings.name == AppRoutes.groups &&
                    groupRepository != null &&
                    settings.arguments == null
              ? RouteSettings(
                  name: settings.name,
                  arguments: GroupsRouteArgs(
                    repository: groupRepository!,
                    searchArgs: searchRouteArgs,
                  ),
                )
              : settings.name == AppRoutes.profile &&
                    loadCurrentUser != null &&
                    updateProfile != null &&
                    updateUsername != null &&
                    changePassword != null &&
                    endSessionAfterPasswordChange != null
              ? RouteSettings(
                  name: settings.name,
                  arguments: ProfileRouteArgs(
                    groupRepository: groupRepository,
                    searchArgs: searchRouteArgs,
                    loadCurrentUser: loadCurrentUser!,
                    updateProfile: updateProfile!,
                    uploadAvatar: uploadAvatar,
                    updateUsername: updateUsername!,
                    changePassword: changePassword!,
                    endSessionAfterPasswordChange:
                        endSessionAfterPasswordChange!,
                    logout: logout,
                    onScanQr: onScanQr,
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
              : settings.name == AppRoutes.personalQr && loadPersonalQr != null
              ? RouteSettings(
                  name: settings.name,
                  arguments: PersonalQrRouteArgs(
                    loadPersonalQr: loadPersonalQr!,
                    onScanQr: onScanQr,
                  ),
                )
              : (settings.name == AppRoutes.friends ||
                        settings.name == AppRoutes.friendRequests ||
                        settings.name == AppRoutes.blockedUsers) &&
                    settings.arguments == null &&
                    (socialRepository != null || groupRepository != null)
              ? RouteSettings(
                  name: settings.name,
                  arguments: socialRepository != null
                      ? SocialRouteArgs(repository: socialRepository!)
                      : GroupsRouteArgs(
                          repository: groupRepository!,
                          searchArgs: searchRouteArgs,
                        ),
                )
              : settings.name == AppRoutes.publicUserProfile &&
                    loadPublicProfile != null &&
                    settings.arguments is! PublicUserProfileRouteArgs
              ? RouteSettings(
                  name: settings.name,
                  arguments: PublicUserProfileRouteArgs(
                    userId: (settings.arguments as String?) ?? '',
                    loadPublicProfile: loadPublicProfile!,
                    chatRepository: chatRepository,
                    socialRepository: socialRepository,
                  ),
                )
              : withRootSearch(settings),
          authStatus: authSessionController.status,
          coordinator: authFlowCoordinator,
        ),
      ),
    );
  }
}

/// A definitive session loss removes protected routes instead of leaving an
/// authenticated page (or a stale notification target) above the login flow.
class _SessionNavigationBoundary extends StatefulWidget {
  final AuthSessionController controller;
  final GlobalKey<NavigatorState>? navigatorKey;
  final Widget Function(GlobalKey<NavigatorState>) builder;
  const _SessionNavigationBoundary({
    required this.controller,
    required this.navigatorKey,
    required this.builder,
  });
  @override
  State<_SessionNavigationBoundary> createState() =>
      _SessionNavigationBoundaryState();
}

class _SessionNavigationBoundaryState
    extends State<_SessionNavigationBoundary> {
  final _localKey = GlobalKey<NavigatorState>();
  GlobalKey<NavigatorState> get _key => widget.navigatorKey ?? _localKey;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sessionChanged);
  }

  @override
  void didUpdateWidget(covariant _SessionNavigationBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sessionChanged);
      widget.controller.addListener(_sessionChanged);
    }
  }

  void _sessionChanged() {
    if (widget.controller.status != AuthSessionStatus.unauthenticated) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.controller.status != AuthSessionStatus.unauthenticated) {
        return;
      }
      _key.currentState?.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_key);
}
