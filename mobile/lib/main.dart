import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/network/access_token_holder.dart';
import 'core/network/api_config.dart';
import 'core/network/dio_client.dart';
import 'core/storage/secure_storage_service.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_flow_coordinator.dart';

void main() {
  final holder = AccessTokenHolder();
  final dio = DioClient(apiConfig: ApiConfig(), accessTokenHolder: holder);
  final repository = AuthRepository(
    api: AuthApi(dio.dio),
    storage: SecureStorageService(),
    accessTokenHolder: holder,
  );
  runApp(WeDoApp(authFlowCoordinator: AuthFlowCoordinator(repository)));
}
