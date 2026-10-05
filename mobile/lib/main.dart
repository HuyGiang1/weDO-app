import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
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

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final NotificationRepository notificationRepository = NotificationRepository(
    NotificationApi(dio.dio),
  );
  NotificationPushService? pushService;

  Future<void> openPushNotification(FcmPushEvent event) async {
    final NavigatorState? navigator = navigatorKey.currentState;
    if (navigator == null) {
      if (kDebugMode) debugPrint('FCM tap: navigator unavailable');
      return;
    }
    final int sessionGeneration = sessionController.sessionGeneration;
    if (!sessionController.isAuthenticated) return;
    final String? notificationId = event.notificationId;
    try {
      if (notificationId != null && notificationId.isNotEmpty) {
        final NotificationItemModel item = await notificationRepository
            .markReadForTap(notificationId);
        if (!sessionController.isAuthenticated ||
            sessionController.sessionGeneration != sessionGeneration) {
          return;
        }
        if (kDebugMode) debugPrint('FCM tap: recipient target resolved');
        if (navigator.mounted) {
          await NotificationTargetRouter.open(
            context: navigator.context,
            item: item,
            groupRepository: groupRepository,
          );
          return;
        }
      }
    } catch (_) {
      // The notification center remains available if live target resolution fails.
    }
    if (!sessionController.isAuthenticated ||
        sessionController.sessionGeneration != sessionGeneration) {
      return;
    }
    if (!navigator.mounted) return;
    if (kDebugMode) debugPrint('FCM tap: falling back to notification center');
    navigator.pushNamed(
      AppRoutes.notifications,
      arguments: GroupsRouteArgs(
        repository: groupRepository,
        searchArgs: SearchRouteArgs(
          searchRepository: searchRepository,
          profileRepository: profileRepository,
          groupRepository: groupRepository,
          chatRepository: chatRepository,
        ),
      ),
    );
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

  if (defaultTargetPlatform == TargetPlatform.android) {
    pushService = NotificationPushService(
      messaging: FirebasePushMessagingClient(FirebaseMessaging.instance),
      storage: storage,
      registerDevice: ({required deviceId, required pushToken}) async {
        await notificationRepository.registerDevice(
          deviceId: deviceId,
          platform: 'ANDROID',
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
      AppRoutes.groups,
      (route) => false,
      arguments: GroupsRouteArgs(
        repository: groupRepository,
        searchArgs: SearchRouteArgs(
          searchRepository: searchRepository,
          profileRepository: profileRepository,
          groupRepository: groupRepository,
          chatRepository: chatRepository,
        ),
      ),
    );
  }

  runApp(
    WeDoApp(
      authFlowCoordinator: AuthFlowCoordinator(
        repository,
        sessionController: sessionController,
        onAuthenticated: handleAuthenticated,
      ),
      authSessionController: sessionController,
      groupRepository: groupRepository,
      chatRepository: chatRepository,
      searchRouteArgs: SearchRouteArgs(
        searchRepository: searchRepository,
        profileRepository: profileRepository,
        groupRepository: groupRepository,
        chatRepository: chatRepository,
      ),
      loadCurrentUser: repository.getCurrentUser,
      updateProfile: profileRepository.updateProfile,
      uploadAvatar: profileRepository.uploadAvatar,
      updateUsername: profileRepository.updateUsername,
      changePassword: repository.changePassword,
      endSessionAfterPasswordChange: endSessionAfterPasswordChange,
      logout: pushService == null ? null : logout,
      loadPrivacySettings: privacyRepository.getPrivacySettings,
      updatePrivacySettings: privacyRepository.updatePrivacySettings,
      loadPersonalQr: personalQrRepository.getPersonalQr,
      loadPublicProfile: profileRepository.getPublicProfile,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(pushService?.markAppReady());
  });
}
