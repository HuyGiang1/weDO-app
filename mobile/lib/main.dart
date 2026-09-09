import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/network/access_token_holder.dart';
import 'core/network/api_config.dart';
import 'core/network/dio_client.dart';
import 'core/storage/secure_storage_service.dart';
import 'features/auth/application/auth_session_controller.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_flow_coordinator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiConfig = ApiConfig();
  final holder = AccessTokenHolder();
  final storage = SecureStorageService();
  final dio = DioClient(apiConfig: apiConfig, accessTokenHolder: holder);
  final refreshDio = DioClient.raw(apiConfig: apiConfig);
  final repository = AuthRepository(
    api: AuthApi(dio.dio, refreshDio: refreshDio.dio),
    storage: storage,
    accessTokenHolder: holder,
  );
  final sessionController = AuthSessionController(
    storage: storage,
    accessTokenHolder: holder,
    repository: repository,
  );

  await sessionController.restoreSession();

  runApp(
    WeDoApp(
      authFlowCoordinator: AuthFlowCoordinator(
        repository,
        sessionController: sessionController,
      ),
      authSessionController: sessionController,
    ),
  );
}
