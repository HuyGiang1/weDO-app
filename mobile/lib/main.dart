import 'package:flutter/material.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiConfig = ApiConfig();
  GroupAvatar.defaultBaseUrl = apiConfig.baseUrl;
  final holder = AccessTokenHolder();
  final storage = SecureStorageService();
  final dio = DioClient(apiConfig: apiConfig);
  final refreshDio = DioClient.raw(apiConfig: apiConfig);
  final repository = AuthRepository(
    api: AuthApi(dio.dio, refreshDio: refreshDio.dio),
    storage: storage,
    accessTokenHolder: holder,
  );
  final profileRepository = ProfileRepository(api: ProfileApi(dio.dio));
  final groupRepository = GroupRepository(api: GroupApi(dio.dio));
  final chatRepository = ChatRepository(
    ChatApi(dio.dio),
    realtimeClient: WebSocketChatRealtimeClient(
      baseUrl: apiConfig.baseUrl,
      accessTokenProvider: () => holder.currentAccessToken,
    ),
  );
  ChatRepository.defaultRealtimeClient = chatRepository.realtimeClient;
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

  void handleAuthenticated(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.groups,
      (route) => false,
      arguments: GroupsRouteArgs(repository: groupRepository),
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
      loadCurrentUser: repository.getCurrentUser,
      updateProfile: profileRepository.updateProfile,
      updateUsername: profileRepository.updateUsername,
      changePassword: repository.changePassword,
      endSessionAfterPasswordChange:
          sessionController.endSessionAfterPasswordChange,
      loadPrivacySettings: privacyRepository.getPrivacySettings,
      updatePrivacySettings: privacyRepository.updatePrivacySettings,
      loadPersonalQr: personalQrRepository.getPersonalQr,
    ),
  );
}
