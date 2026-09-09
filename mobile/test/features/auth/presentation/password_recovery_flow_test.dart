import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/core/network/access_token_holder.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/storage/secure_key_value_store.dart';
import 'package:mobile/core/storage/secure_storage_service.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/data/models/auth_models.dart';
import 'package:mobile/features/auth/presentation/auth_flow_coordinator.dart';

void main() {
  testWidgets(
    'forgot and reset preserve an existing session while returning to the existing Login route',
    (tester) async {
      final api = RecoveryApi();
      final store = MemoryStore()
        ..values[SecureStorageService.accessTokenKey] = 'access-a'
        ..values[SecureStorageService.refreshTokenKey] = 'refresh-a';
      final holder = AccessTokenHolder()..setAccessToken('access-a');
      final coordinator = AuthFlowCoordinator(
        AuthRepository(
          api: api,
          storage: SecureStorageService(store: store),
          accessTokenHolder: holder,
        ),
      );

      await tester.pumpWidget(WeDoApp(authFlowCoordinator: coordinator));
      await tester.ensureVisible(find.text('Login'));
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Forgot Password?'));
      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), ' User@Example.COM ');
      final send = find.widgetWithText(ElevatedButton, 'Send Reset Code');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();

      expect(api.forgotCalls, 1);
      expect(api.forgotEmail, 'user@example.com');
      expect(
        find.widgetWithText(ElevatedButton, 'Update Password'),
        findsOneWidget,
      );
      expect(store.values[SecureStorageService.accessTokenKey], 'access-a');
      expect(store.values[SecureStorageService.refreshTokenKey], 'refresh-a');
      expect(holder.currentAccessToken, 'access-a');

      await tester.enterText(find.byType(TextFormField).at(0), '001234');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        '  Secret Pass  ',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        '  Secret Pass  ',
      );
      final update = find.widgetWithText(ElevatedButton, 'Update Password');
      await tester.ensureVisible(update);
      await tester.tap(update);
      await tester.pumpAndSettle();

      expect(api.resetCalls, 1);
      expect(api.resetEmail, 'user@example.com');
      expect(api.resetCode, '001234');
      expect(api.resetNewPassword, '  Secret Pass  ');
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(
        find.text('Password updated. You can now log in.'),
        findsOneWidget,
      );
      expect(api.loginCalls, 0);
      expect(api.currentUserCalls, 0);
      expect(store.values[SecureStorageService.accessTokenKey], 'access-a');
      expect(store.values[SecureStorageService.refreshTokenKey], 'refresh-a');
      expect(holder.currentAccessToken, 'access-a');
    },
  );

  testWidgets(
    'forgot ignores neutral response wording and keeps no account-existence state',
    (tester) async {
      final api = RecoveryApi()
        ..forgotMessage = 'A deliberately different neutral response.';
      final coordinator = AuthFlowCoordinator(
        AuthRepository(
          api: api,
          storage: SecureStorageService(store: MemoryStore()),
          accessTokenHolder: AccessTokenHolder(),
        ),
      );
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) {
                context = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(await coordinator.forgotPassword(context, ' A@B.C '), isTrue);
      expect(api.forgotEmail, 'a@b.c');
      expect(find.byType(SnackBar), findsNothing);
      api.forgotMessage = 'Another neutral response with different wording.';
      expect(await coordinator.forgotPassword(context, ' A@B.C '), isTrue);
      expect(api.forgotCalls, 2);
    },
  );

  for (final failure in <String, ApiException>{
    'network': const ApiException(
      transportFailure: ApiTransportFailure.network,
    ),
    'timeout': const ApiException(
      transportFailure: ApiTransportFailure.timeout,
    ),
  }.entries) {
    testWidgets(
      'forgot ${failure.key} is safe, does not navigate, and retries',
      (tester) async {
        final api = RecoveryApi()..forgotFailure = failure.value;
        final coordinator = AuthFlowCoordinator(
          AuthRepository(
            api: api,
            storage: SecureStorageService(store: MemoryStore()),
            accessTokenHolder: AccessTokenHolder(),
          ),
        );
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (c) {
                  context = c;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(await coordinator.forgotPassword(context, 'a@b.c'), isFalse);
        await tester.pump();
        expect(find.byType(SnackBar), findsOneWidget);
        if (failure.key == 'PASSWORD_RESET_CODE_INVALID') {
          expect(
            find.text('The reset code is invalid or no longer valid.'),
            findsOneWidget,
          );
        }
        api.forgotFailure = null;
        expect(await coordinator.forgotPassword(context, 'a@b.c'), isTrue);
        expect(api.forgotCalls, 2);
      },
    );
  }

  for (final failure in <String, ApiException>{
    'PASSWORD_RESET_CODE_INVALID': const ApiException(
      code: 'PASSWORD_RESET_CODE_INVALID',
    ),
    'network': const ApiException(
      transportFailure: ApiTransportFailure.network,
    ),
    'timeout': const ApiException(
      transportFailure: ApiTransportFailure.timeout,
    ),
    'unexpected': const ApiException(),
  }.entries) {
    testWidgets(
      'reset ${failure.key} is safe, preserves session, and retries',
      (tester) async {
        final api = RecoveryApi()..resetFailure = failure.value;
        final store = MemoryStore()
          ..values[SecureStorageService.accessTokenKey] = 'access-a'
          ..values[SecureStorageService.refreshTokenKey] = 'refresh-a';
        final holder = AccessTokenHolder()..setAccessToken('access-a');
        final coordinator = AuthFlowCoordinator(
          AuthRepository(
            api: api,
            storage: SecureStorageService(store: store),
            accessTokenHolder: holder,
          ),
        );
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (c) {
                  context = c;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(
          await coordinator.resetPassword(
            context,
            email: ' User@Example.COM ',
            code: '001234',
            newPassword: '  Secret Pass  ',
          ),
          isFalse,
        );
        await tester.pump();
        expect(find.byType(SnackBar), findsOneWidget);
        expect(store.values[SecureStorageService.accessTokenKey], 'access-a');
        expect(store.values[SecureStorageService.refreshTokenKey], 'refresh-a');
        expect(holder.currentAccessToken, 'access-a');

        api.resetFailure = null;
        expect(
          await coordinator.resetPassword(
            context,
            email: ' User@Example.COM ',
            code: '001234',
            newPassword: '  Secret Pass  ',
          ),
          isTrue,
        );
        expect(api.resetEmail, 'user@example.com');
        expect(api.resetCode, '001234');
        expect(api.resetNewPassword, '  Secret Pass  ');
      },
    );
  }
}

class RecoveryApi extends AuthApi {
  RecoveryApi() : super(Dio());

  int forgotCalls = 0;
  int resetCalls = 0;
  int loginCalls = 0;
  int currentUserCalls = 0;
  String? forgotEmail;
  String? resetEmail;
  String? resetCode;
  String? resetNewPassword;
  String forgotMessage = 'neutral';
  ApiException? forgotFailure;
  ApiException? resetFailure;

  @override
  Future<ForgotPasswordResult> forgotPassword(String email) async {
    forgotCalls++;
    forgotEmail = email;
    if (forgotFailure != null) throw forgotFailure!;
    return ForgotPasswordResult(forgotMessage);
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    resetCalls++;
    resetEmail = email;
    resetCode = code;
    resetNewPassword = newPassword;
    if (resetFailure != null) throw resetFailure!;
  }

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
    String? deviceName,
  }) async {
    loginCalls++;
    throw UnimplementedError();
  }

  @override
  Future<CurrentUser> getCurrentUser() async {
    currentUserCalls++;
    throw UnimplementedError();
  }
}

class MemoryStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}
