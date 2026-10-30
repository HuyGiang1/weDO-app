import 'dart:async';
import 'core/realtime/realtime_sync.dart';
import 'core/realtime/realtime_binding.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'app/app.dart';
import 'core/network/access_token_holder.dart';
import 'core/network/api_config.dart';
import 'core/network/auth_interceptor.dart';
import 'core/network/dio_client.dart';
import 'core/storage/secure_storage_service.dart';
import 'features/auth/application/auth_session_controller.dart';
import 'features/auth/application/auth_session_invalidator.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/auth_failure.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_flow_coordinator.dart';
import 'app/routes.dart';
import 'features/profile/data/profile_api.dart';
import 'features/profile/data/profile_repository.dart';
import 'features/media/data/media_upload_service.dart';
import 'features/media/presentation/media_storage_image.dart';
import 'features/groups/data/group_api.dart';
import 'features/groups/data/group_repository.dart';
import 'features/groups/presentation/widgets/group_widgets.dart';
import 'features/privacy/data/privacy_api.dart';
import 'features/privacy/data/privacy_repository.dart';
import 'features/qr/data/personal_qr_api.dart';
import 'features/qr/data/personal_qr_repository.dart';
import 'features/chat/data/chat_api.dart';
import 'features/chat/data/chat_realtime_client.dart';
import 'features/chat/data/chat_repository.dart';
import 'features/notification/application/notification_push_service.dart';
import 'features/notification/data/notification_api.dart';
import 'features/notification/data/notification_models.dart';
import 'features/notification/data/notification_repository.dart';
import 'features/notification/presentation/notification_target_router.dart';
import 'features/search/data/search_api.dart';
import 'features/social/data/social_api.dart';
import 'features/social/data/social_repository.dart';
import 'core/links/wedo_deep_link.dart';
import 'core/network/api_exception.dart';

import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool pushAvailable = false;
  const pushEnabled = bool.fromEnvironment('WEDO_PUSH_ENABLED', defaultValue: true);
  final pushPlatform = !pushEnabled || kIsWeb
      ? null
      : notificationDevicePlatform(defaultTargetPlatform);
  if (pushPlatform != null) {
    pushAvailable = await initializePushFirebase(() async {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // The existing onMessage SnackBar is our single foreground presenter.
        // Background/terminated notification alerts remain native APNs/FCM.
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
              alert: false,
              badge: false,
              sound: false,
            );
      }
    });
  }

  final apiConfig = ApiConfig();
  GroupAvatar.defaultBaseUrl = apiConfig.baseUrl;
  final holder = AccessTokenHolder();
  final storage = SecureStorageService();
  final dio = DioClient(apiConfig: apiConfig);
  final mediaUploadService = MediaUploadService(apiDio: dio.dio);
  MediaStorageImage.service = mediaUploadService;
  final refreshDio = DioClient.raw(apiConfig: apiConfig);
  final repository = AuthRepository(
    api: AuthApi(dio.dio, refreshDio: refreshDio.dio),
    storage: storage,
    accessTokenHolder: holder,
  );
  final profileRepository = ProfileRepository(
    api: ProfileApi(dio.dio),
    mediaUploadService: mediaUploadService,
  );
  final groupRepository = GroupRepository(
    api: GroupApi(dio.dio),
    mediaUploadService: mediaUploadService,
  );
  final chatRepository = ChatRepository(
    ChatApi(dio.dio),
    mediaUploadService: mediaUploadService,
    realtimeClient: WebSocketChatRealtimeClient(
      baseUrl: apiConfig.baseUrl,
      accessTokenProvider: () => holder.currentAccessToken,
    ),
  );
  ChatRepository.defaultRealtimeClient = chatRepository.realtimeClient;
  ChatRepository.defaultMediaUploadService = mediaUploadService;
  final searchRepository = SearchRepository(SearchApi(dio.dio));
  final privacyRepository = PrivacyRepository(api: PrivacyApi(dio.dio));
  final personalQrRepository = PersonalQrRepository(
    api: PersonalQrApi(dio.dio),
  );
  final socialRepository = SocialRepository(api: SocialApi(dio.dio));
  final searchRouteArgs = SearchRouteArgs(
    searchRepository: searchRepository,
    profileRepository: profileRepository,
    groupRepository: groupRepository,
    chatRepository: chatRepository,
  );
  final sessionController = AuthSessionController(
    storage: storage,
    accessTokenHolder: holder,
    repository: repository,
  );
  final invalidator = AuthSessionInvalidator(
    repository: repository,
    sessionController: sessionController,
  );

  dio.attachAuthInterceptor(
    AuthInterceptor(
      accessTokenHolder: holder,
      refreshSession: ({required int expectedRevision}) async {
        try {
          return await repository.refreshSession(
            expectedRevision: expectedRevision,
          );
        } on AuthException catch (error) {
          await invalidator.handleRefreshFailure(
            failure: error.failure,
            expectedRevision: expectedRevision,
          );
          rethrow;
        }
      },
      onAccessTokenInvalid: invalidator.handleAccessTokenInvalid,
      dio: dio.dio,
    ),
  );

  await sessionController.restoreSession();
  if (sessionController.isAuthenticated) {
    try {
      // Validate/rotate through the existing generation-aware interceptor before
      // creating the authenticated root or dispatching a cold-start push tap.
      await repository.getCurrentUser();
    } on AuthException {
      // Definitive failures already invalidate via AuthSessionInvalidator.
      // Offline/timeout errors do not prove the persisted session is invalid.
    }
  }

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final NotificationRepository notificationRepository = NotificationRepository(
    NotificationApi(dio.dio),
  );
  NotificationPushService? pushService;
  final WeDoScanDeduplicator scanDeduplicator = WeDoScanDeduplicator();
  String? pendingDeepLink;

  void safeNavigate(VoidCallback action) {
    final phase = WidgetsBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      action();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => action());
    }
  }

  Future<void> handleDeepLink(
    String rawLink, {
    bool fromScanner = false,
  }) async {
    final parsed = WeDoDeepLink.parse(rawLink);
    if (parsed == null) {
      if (fromScanner) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Mã QR không hợp lệ hoặc không thuộc ứng dụng weDO.'),
          ),
        );
      }
      return;
    }

    if (!scanDeduplicator.shouldProcess(rawLink)) {
      return;
    }

    if (!sessionController.isAuthenticated) {
      pendingDeepLink = rawLink;
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để mở liên kết weDO.'),
        ),
      );
      navigatorKey.currentState?.pushNamed(AppRoutes.login);
      return;
    }

    final navigator = navigatorKey.currentState;
    if (navigator == null || !navigator.mounted) {
      pendingDeepLink = rawLink;
      return;
    }

    if (parsed is WeDoGroupInviteLink) {
      safeNavigate(() {
        final nav = navigatorKey.currentState;
        if (nav == null || !nav.mounted) {
          pendingDeepLink = rawLink;
          return;
        }
        nav.pushNamed(
          AppRoutes.joinGroupByCode,
          arguments: GroupsRouteArgs(
            repository: groupRepository,
            searchArgs: searchRouteArgs,
            initialCode: parsed.inviteCode,
          ),
        );
      });
      return;
    }

    if (parsed is WeDoFriendProfileLink) {
      try {
        final resolved = await personalQrRepository.resolveQr(
          parsed.canonicalDeepLink,
        );
        safeNavigate(() {
          final nav = navigatorKey.currentState;
          if (nav == null || !nav.mounted) return;
          nav.pushNamed(
            AppRoutes.publicUserProfile,
            arguments: PublicUserProfileRouteArgs(
              userId: resolved.id,
              loadPublicProfile: (userId) async => userId == resolved.id
                  ? resolved
                  : await profileRepository.getPublicProfile(userId),
              chatRepository: chatRepository,
              socialRepository: socialRepository,
            ),
          );
        });
      } on ApiException {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text(
              'Không tìm thấy người dùng hoặc người dùng đã tắt tìm kiếm qua mã QR.',
            ),
          ),
        );
      } catch (_) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Không thể mở hồ sơ từ liên kết này.')),
        );
      }
    }
  }

  Future<void> scanAndOpenQr() async {
    try {
      final scanned = await WeDoPlatformLinks.scanQr();
      if (scanned == null || scanned.isEmpty) return;
      await handleDeepLink(scanned, fromScanner: true);
    } on PlatformException catch (e) {
      if (e.code == 'camera_permission_denied') {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Vui lòng cấp quyền máy ảnh để quét mã QR.'),
          ),
        );
      } else if (e.code == 'camera_unavailable') {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Không thể mở máy ảnh trên thiết bị này.'),
          ),
        );
      }
    }
  }

  Future<void> openPushNotification(FcmPushEvent event) async {
    final int sessionGeneration = sessionController.sessionGeneration;
    if (!sessionController.isAuthenticated) return;
    final String? notificationId = event.notificationId;

    bool targetHandled = false;
    try {
      if (notificationId != null && notificationId.isNotEmpty) {
        final NotificationItemModel item = await notificationRepository
            .markReadForTap(notificationId);
        if (!sessionController.isAuthenticated ||
            sessionController.sessionGeneration != sessionGeneration) {
          return;
        }
        if (kDebugMode) debugPrint('FCM tap: recipient target resolved');

        final NavigatorState? navigator = navigatorKey.currentState;
        if (navigator == null || !navigator.mounted) {
          if (kDebugMode) debugPrint('FCM tap: navigator unavailable');
          return;
        }

        targetHandled = true;
        safeNavigate(() {
          final NavigatorState? nav = navigatorKey.currentState;
          if (nav == null || !nav.mounted) return;
          if (!sessionController.isAuthenticated ||
              sessionController.sessionGeneration != sessionGeneration) {
            return;
          }
          unawaited(
            NotificationTargetRouter.open(
              context: nav.context,
              navigator: nav,
              item: item,
              groupRepository: groupRepository,
            ),
          );
        });
        return;
      }
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('FCM tap: target resolution failed: $error\n$stack');
      }
    }

    if (targetHandled) return;
    if (!sessionController.isAuthenticated ||
        sessionController.sessionGeneration != sessionGeneration) {
      return;
    }

    safeNavigate(() {
      final NavigatorState? nav = navigatorKey.currentState;
      if (nav == null || !nav.mounted) return;
      if (!sessionController.isAuthenticated ||
          sessionController.sessionGeneration != sessionGeneration) {
        return;
      }
      if (kDebugMode) debugPrint('FCM tap: falling back to notification center');
      nav.pushNamed(
        AppRoutes.notifications,
        arguments: GroupsRouteArgs(
          repository: groupRepository,
          searchArgs: searchRouteArgs,
        ),
      );
    });
  }

  void showForegroundNotification(FcmPushEvent event) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          [event.title, event.body]
              .whereType<String>()
              .where((String text) => text.trim().isNotEmpty)
              .join('\n'),
        ),
        action: SnackBarAction(
          label: 'Mở',
          onPressed: () => unawaited(openPushNotification(event)),
        ),
      ),
    );
  }

  if (pushAvailable) {
    pushService = NotificationPushService(
      messaging: FirebasePushMessagingClient(FirebaseMessaging.instance),
      storage: storage,
      registerDevice: ({required deviceId, required pushToken}) async {
        await notificationRepository.registerDevice(
          deviceId: deviceId,
          platform: pushPlatform!,
          pushToken: pushToken,
        );
      },
      deactivateDevice: notificationRepository.deactivateDevice,
      onForegroundMessage: (event) async => showForegroundNotification(event),
      onNotificationTap: openPushNotification,
    );
    await pushService.start(authenticated: sessionController.isAuthenticated);
    sessionController.addListener(() {
      unawaited(
        pushService?.setAuthenticated(sessionController.isAuthenticated),
      );
    });
  }

  Future<void> logout() async {
    await sessionController.logout(
      beforeLogout: pushService?.deactivateForLogout,
    );
  }

  Future<bool> endSessionAfterPasswordChange() async {
    await pushService?.deactivateForLogout();
    return sessionController.endSessionAfterPasswordChange();
  }

  void handleAuthenticated(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (route) => false,
      arguments: HomeRouteArgs(
        repository: groupRepository,
        searchArgs: searchRouteArgs,
      ),
    );
    final resumeLink = pendingDeepLink;
    if (resumeLink != null) {
      pendingDeepLink = null;
      scanDeduplicator.reset();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(handleDeepLink(resumeLink));
      });
    }
  }

  runApp(
    RealtimeSession(
      sync: RealtimeSync(chatRepository.realtimeClient),
      session: sessionController,
      child: WeDoApp(
      authFlowCoordinator: AuthFlowCoordinator(
        repository,
        sessionController: sessionController,
        onAuthenticated: handleAuthenticated,
      ),
      authSessionController: sessionController,
      groupRepository: groupRepository,
      chatRepository: chatRepository,
      socialRepository: socialRepository,
      searchRouteArgs: searchRouteArgs,
      loadCurrentUser: repository.getCurrentUser,
      updateProfile: profileRepository.updateProfile,
      uploadAvatar: profileRepository.uploadAvatar,
      updateUsername: profileRepository.updateUsername,
      changePassword: repository.changePassword,
      endSessionAfterPasswordChange: endSessionAfterPasswordChange,
      logout: logout,
      loadPrivacySettings: privacyRepository.getPrivacySettings,
      updatePrivacySettings: privacyRepository.updatePrivacySettings,
      loadPersonalQr: personalQrRepository.getPersonalQr,
      loadPublicProfile: profileRepository.getPublicProfile,
      onScanQr: () => unawaited(scanAndOpenQr()),
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      ),
    ),
  );
  WeDoPlatformLinks.incomingLinks.listen((link) {
    unawaited(handleDeepLink(link));
  });
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(pushService?.markAppReady());
    unawaited(() async {
      final initial = await WeDoPlatformLinks.getInitialLink();
      if (initial != null) {
        await handleDeepLink(initial);
      } else if (pendingDeepLink != null && sessionController.isAuthenticated) {
        final link = pendingDeepLink!;
        pendingDeepLink = null;
        scanDeduplicator.reset();
        await handleDeepLink(link);
      }
    }());
  });
}
