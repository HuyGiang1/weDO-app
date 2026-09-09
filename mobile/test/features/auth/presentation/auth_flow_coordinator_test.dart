import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/core/network/access_token_holder.dart';
import 'package:mobile/core/storage/secure_key_value_store.dart';
import 'package:mobile/core/storage/secure_storage_service.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/data/models/auth_models.dart';
import 'package:mobile/features/auth/presentation/auth_flow_coordinator.dart';
import 'package:mobile/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:mobile/features/auth/presentation/screens/create_username_screen.dart';
import 'package:mobile/features/auth/presentation/screens/complete_profile_screen.dart';

void main() {
  testWidgets(
    'register routes with canonical email and zero cooldown without exposing userId',
    (tester) async {
      final api = FlowApi();
      final coordinator = AuthFlowCoordinator(
        AuthRepository(
          api: api,
          storage: SecureStorageService(store: Memory()),
          accessTokenHolder: AccessTokenHolder(),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  coordinator.register(context, ' Test@Example.COM ', 'raw'),
              child: const Text('go'),
            ),
          ),
          onGenerateRoute: (s) {
            final a = s.arguments as VerifyEmailFlowArgs;
            return MaterialPageRoute(
              builder: (_) => VerifyEmailScreen(
                email: a.email,
                initialCooldownSeconds: 0,
                onBack: () {},
                onChangeEmail: () {},
                onVerify: a.onVerify,
                onResend: a.onResend,
              ),
            );
          },
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(api.registerCalls, 1);
      expect(find.textContaining('test@example.com'), findsOneWidget);
      expect(find.text('Resend Code'), findsOneWidget);
    },
  );
  testWidgets(
    'complete profile network failure retains onboarding state and retry reaches Login',
    (tester) async {
      final api = FlowApi();
      final store = Memory();
      final holder = AccessTokenHolder();
      final coordinator = AuthFlowCoordinator(
        AuthRepository(
          api: api,
          storage: SecureStorageService(store: store),
          accessTokenHolder: holder,
        ),
      );
      late BuildContext context;
      var loginRoutes = 0;
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
          onGenerateRoute: (settings) {
            if (settings.name == '/login') loginRoutes++;
            return MaterialPageRoute<void>(builder: (_) => const SizedBox());
          },
        ),
      );
      await coordinator.register(context, 'a@b.c', 'p');
      await tester.pump();
      await coordinator.verify(context, '001234');
      await tester.pump();
      await coordinator.selectUsername(context, 'user_name');
      await tester.pump();
      api.completeFailure = const ApiException(
        transportFailure: ApiTransportFailure.network,
      );
      await coordinator.completeProfile(
        context,
        const CompleteProfileData(
          username: 'user_name',
          displayName: 'Name',
          bio: null,
        ),
      );
      await tester.pump();
      expect(loginRoutes, 0);
      expect(coordinator.hasProfileCompletionToken, isTrue);
      expect(store.values, isEmpty);
      expect(holder.currentAccessToken, isNull);
      expect(find.byType(SnackBar), findsOneWidget);
      api.completeFailure = null;
      await coordinator.completeProfile(
        context,
        const CompleteProfileData(
          username: 'user_name',
          displayName: 'Name',
          bio: null,
        ),
      );
      await tester.pump();
      expect(loginRoutes, 1);
      expect(coordinator.hasProfileCompletionToken, isFalse);
    },
  );
  testWidgets(
    'username race keeps onboarding state and allows another username selection',
    (tester) async {
      final api = FlowApi();
      final store = Memory();
      final holder = AccessTokenHolder();
      final coordinator = AuthFlowCoordinator(
        AuthRepository(
          api: api,
          storage: SecureStorageService(store: store),
          accessTokenHolder: holder,
        ),
      );
      late BuildContext context;
      var loginRoutes = 0;
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
          onGenerateRoute: (settings) {
            if (settings.name == '/login') loginRoutes++;
            return MaterialPageRoute<void>(builder: (_) => const SizedBox());
          },
        ),
      );
      await coordinator.register(context, 'a@b.c', 'p');
      await tester.pump();
      await coordinator.verify(context, '001234');
      await tester.pump();
      expect(
        await coordinator.checkUsername(context, 'taken'),
        UsernameAvailability.available,
      );
      await coordinator.selectUsername(context, 'taken');
      await tester.pump();
      api.completeFailure = const ApiException(code: 'USERNAME_ALREADY_EXISTS');
      await coordinator.completeProfile(
        context,
        const CompleteProfileData(
          username: 'taken',
          displayName: 'Name',
          bio: null,
        ),
      );
      await tester.pump();
      expect(loginRoutes, 0);
      expect(coordinator.hasProfileCompletionToken, isTrue);
      expect(store.values, isEmpty);
      expect(holder.currentAccessToken, isNull);
      expect(find.byType(SnackBar), findsOneWidget);
      api.completeFailure = null;
      await coordinator.selectUsername(context, 'other');
      await tester.pump();
      await coordinator.completeProfile(
        context,
        const CompleteProfileData(
          username: 'other',
          displayName: 'Name',
          bio: null,
        ),
      );
      await tester.pump();
      expect(loginRoutes, 1);
    },
  );
  testWidgets(
    'verify to username availability then complete profile uses memory-only onboarding state',
    (tester) async {
      final api = FlowApi();
      final store = Memory();
      final holder = AccessTokenHolder();
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
          onGenerateRoute: (_) =>
              MaterialPageRoute<void>(builder: (_) => const SizedBox()),
        ),
      );
      await coordinator.register(context, 'a@b.c', 'p');
      await tester.pump();
      await coordinator.verify(context, '001234');
      await tester.pump();
      expect(
        await coordinator.checkUsername(context, 'User_Name'),
        UsernameAvailability.available,
      );
      api.available = false;
      expect(
        await coordinator.checkUsername(context, 'other'),
        UsernameAvailability.unavailable,
      );
      api.available = true;
      await coordinator.selectUsername(context, 'user_name');
      await tester.pump();
      await coordinator.completeProfile(
        context,
        const CompleteProfileData(
          username: 'user_name',
          displayName: 'Name',
          bio: 'bio',
        ),
      );
      expect(api.completeToken, 'secret');
      expect(api.completeUsername, 'user_name');
      expect(api.completeAvatar, isNull);
      expect(coordinator.hasProfileCompletionToken, isFalse);
      expect(store.values, isEmpty);
      expect(holder.currentAccessToken, isNull);
    },
  );
  testWidgets(
    'register, verify, and resend failures stay on the current flow and show safe feedback',
    (tester) async {
      final api = FlowApi()
        ..failure = const ApiException(code: 'EMAIL_ALREADY_EXISTS');
      final coordinator = AuthFlowCoordinator(
        AuthRepository(
          api: api,
          storage: SecureStorageService(store: Memory()),
          accessTokenHolder: AccessTokenHolder(),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => coordinator.register(context, 'a@b.c', 'p'),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      expect(find.textContaining('already exists'), findsOneWidget);
    },
  );
  for (final code in const [
    'VERIFICATION_CODE_INVALID',
    'VERIFICATION_CODE_EXPIRED',
    'VERIFICATION_ATTEMPTS_EXCEEDED',
  ]) {
    testWidgets(
      'verify $code keeps onboarding state and surfaces safe feedback',
      (tester) async {
        final api = FlowApi();
        final store = Memory();
        final coordinator = AuthFlowCoordinator(
          AuthRepository(
            api: api,
            storage: SecureStorageService(store: store),
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
            onGenerateRoute: (_) =>
                MaterialPageRoute<void>(builder: (_) => const SizedBox()),
          ),
        );
        await coordinator.register(context, 'a@b.c', 'p');
        await tester.pump();
        api.failure = ApiException(code: code);
        await coordinator.verify(context, '001234');
        await tester.pump();
        expect(coordinator.hasProfileCompletionToken, isFalse);
        expect(store.values, isEmpty);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(api.code, isNull);
      },
    );
  }
  testWidgets(
    'resend RESEND_COOLDOWN_ACTIVE returns no fabricated cooldown and stays usable',
    (tester) async {
      final api = FlowApi();
      final coordinator = AuthFlowCoordinator(
        AuthRepository(
          api: api,
          storage: SecureStorageService(store: Memory()),
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
          onGenerateRoute: (_) =>
              MaterialPageRoute<void>(builder: (_) => const SizedBox()),
        ),
      );
      await coordinator.register(context, 'a@b.c', 'p');
      await tester.pump();
      api.failure = const ApiException(code: 'RESEND_COOLDOWN_ACTIVE');
      expect(await coordinator.resend(context), isNull);
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(api.resendUserId, isNull);
      api.failure = null;
      expect(await coordinator.resend(context), 37);
      expect(api.resendUserId, 'user');
    },
  );
  testWidgets(
    'verify preserves leading-zero code, retains token only in memory, and resend returns backend cooldown',
    (tester) async {
      final api = FlowApi();
      final store = Memory();
      final coordinator = AuthFlowCoordinator(
        AuthRepository(
          api: api,
          storage: SecureStorageService(store: store),
          accessTokenHolder: AccessTokenHolder(),
        ),
      );
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
          onGenerateRoute: (_) =>
              MaterialPageRoute<void>(builder: (_) => const SizedBox()),
        ),
      );
      await coordinator.register(context, 'a@b.c', 'p');
      await tester.pump();
      await coordinator.verify(context, '001234');
      expect(api.code, '001234');
      expect(coordinator.hasProfileCompletionToken, isTrue);
      expect(store.values, isEmpty);
      expect(await coordinator.resend(context), 37);
      expect(api.resendUserId, 'user');
    },
  );
  testWidgets(
    'LoginScreen forwards canonical credentials once and authenticated login persists only through repository',
    (tester) async {
      final api = FlowApi();
      final store = Memory();
      final holder = AccessTokenHolder();
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
      await tester.enterText(find.byType(TextFormField).at(0), ' A@B.C ');
      await tester.enterText(find.byType(TextFormField).at(1), ' raw ');
      final login = find.widgetWithText(ElevatedButton, 'Login');
      await tester.ensureVisible(login);
      await tester.tap(login);
      await tester.pumpAndSettle();

      expect(api.loginCalls, 1);
      expect(api.loginEmail, 'a@b.c');
      expect(api.loginPassword, ' raw ');
      expect(api.loginDeviceName, isNull);
      expect(store.values[SecureStorageService.accessTokenKey], 'access');
      expect(store.values[SecureStorageService.refreshTokenKey], 'refresh');
      expect(holder.currentAccessToken, 'access');
      expect(coordinator.hasProfileCompletionToken, isFalse);
      expect(find.text('Signed in successfully.'), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(api.currentUserCalls, 0);
    },
  );
  testWidgets(
    'authenticated login clears stale onboarding state without navigation',
    (tester) async {
      final api = FlowApi();
      final store = Memory();
      final holder = AccessTokenHolder();
      final coordinator = AuthFlowCoordinator(
        AuthRepository(
          api: api,
          storage: SecureStorageService(store: store),
          accessTokenHolder: holder,
        ),
      );
      late BuildContext context;
      var routes = 0;
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
          onGenerateRoute: (_) {
            routes++;
            return MaterialPageRoute<void>(builder: (_) => const SizedBox());
          },
        ),
      );
      await coordinator.register(context, 'a@b.c', 'raw');
      await coordinator.verify(context, '001234');
      expect(coordinator.hasProfileCompletionToken, isTrue);

      await coordinator.login(context, 'a@b.c', 'raw');
      await tester.pump();

      expect(coordinator.hasProfileCompletionToken, isFalse);
      expect(routes, 2);
      expect(store.values[SecureStorageService.accessTokenKey], 'access');
      expect(store.values[SecureStorageService.refreshTokenKey], 'refresh');
      expect(holder.currentAccessToken, 'access');
      expect(api.currentUserCalls, 0);
    },
  );
  testWidgets(
    'incomplete-profile login without a prior session keeps onboarding credentials memory-only',
    (tester) async {
      final api = FlowApi()
        ..loginResult = const ProfileCompletionRequired(
          userId: 'account-b',
          status: 'PENDING_PROFILE',
          profileCompletionToken: 'account-b-profile-token',
        );
      final store = Memory();
      final holder = AccessTokenHolder();
      final coordinator = AuthFlowCoordinator(
        AuthRepository(
          api: api,
          storage: SecureStorageService(store: store),
          accessTokenHolder: holder,
        ),
      );
      late BuildContext context;
      Object? routeArguments;
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
          onGenerateRoute: (settings) {
            routeArguments = settings.arguments;
            return MaterialPageRoute<void>(builder: (_) => const SizedBox());
          },
        ),
      );

      await coordinator.login(context, 'b@b.c', 'raw');
      await tester.pump();

      expect(store.values, isEmpty);
      expect(holder.currentAccessToken, isNull);
      expect(coordinator.hasProfileCompletionToken, isTrue);
      expect(routeArguments, isA<CreateUsernameFlowArgs>());
    },
  );
  testWidgets(
    'incomplete-profile login clears an old local session before memory-only onboarding',
    (tester) async {
      final api = FlowApi()
        ..loginResult = const ProfileCompletionRequired(
          userId: 'account-b',
          status: 'PENDING_PROFILE',
          profileCompletionToken: 'account-b-profile-token',
        );
      final store = Memory()
        ..values[SecureStorageService.accessTokenKey] = 'account-a-access'
        ..values[SecureStorageService.refreshTokenKey] = 'account-a-refresh';
      final holder = AccessTokenHolder()..setAccessToken('account-a-access');
      final coordinator = AuthFlowCoordinator(
        AuthRepository(
          api: api,
          storage: SecureStorageService(store: store),
          accessTokenHolder: holder,
        ),
      );
      late BuildContext context;
      Object? routeArguments;
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
          onGenerateRoute: (settings) {
            if (settings.name == '/create-username') {
              routeArguments = settings.arguments;
            }
            return MaterialPageRoute<void>(builder: (_) => const SizedBox());
          },
        ),
      );

      await coordinator.login(context, 'b@b.c', 'raw');
      await tester.pump();

      expect(store.values, isEmpty);
      expect(holder.currentAccessToken, isNull);
      expect(api.logoutCalls, 0);
      expect(coordinator.hasProfileCompletionToken, isTrue);
      expect(routeArguments, isA<CreateUsernameFlowArgs>());
    },
  );
  testWidgets(
    'incomplete-profile login does not establish onboarding when local clearing fails',
    (tester) async {
      final api = FlowApi()
        ..loginResult = const ProfileCompletionRequired(
          userId: 'account-b',
          status: 'PENDING_PROFILE',
          profileCompletionToken: 'account-b-profile-token',
        );
      final store = Memory()
        ..values[SecureStorageService.accessTokenKey] = 'account-a-access'
        ..values[SecureStorageService.refreshTokenKey] = 'account-a-refresh'
        ..failDeletes = true;
      final holder = AccessTokenHolder()..setAccessToken('account-a-access');
      final coordinator = AuthFlowCoordinator(
        AuthRepository(
          api: api,
          storage: SecureStorageService(store: store),
          accessTokenHolder: holder,
        ),
      );
      late BuildContext context;
      var createUsernameRoutes = 0;
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
          onGenerateRoute: (settings) {
            if (settings.name == '/create-username') createUsernameRoutes++;
            return MaterialPageRoute<void>(builder: (_) => const SizedBox());
          },
        ),
      );

      await coordinator.login(context, 'b@b.c', 'raw');
      await tester.pump();

      expect(createUsernameRoutes, 0);
      expect(coordinator.hasProfileCompletionToken, isFalse);
      expect(holder.currentAccessToken, isNull);
      expect(
        store.values[SecureStorageService.accessTokenKey],
        'account-a-access',
      );
      expect(find.byType(SnackBar), findsOneWidget);
    },
  );
  for (final loginFailure in <String, ApiException>{
    'AUTH_INVALID_CREDENTIALS': const ApiException(
      code: 'AUTH_INVALID_CREDENTIALS',
    ),
    'EMAIL_NOT_VERIFIED': const ApiException(code: 'EMAIL_NOT_VERIFIED'),
    'ACCOUNT_LOCKED': const ApiException(code: 'ACCOUNT_LOCKED'),
    'ACCOUNT_SUSPENDED': const ApiException(code: 'ACCOUNT_SUSPENDED'),
    'ACCOUNT_DEACTIVATED': const ApiException(code: 'ACCOUNT_DEACTIVATED'),
    'network': const ApiException(
      transportFailure: ApiTransportFailure.network,
    ),
    'timeout': const ApiException(
      transportFailure: ApiTransportFailure.timeout,
    ),
    'unexpected': const ApiException(),
  }.entries) {
    testWidgets(
      'login ${loginFailure.key} preserves an existing session and does not navigate',
      (tester) async {
        final api = FlowApi()..loginFailure = loginFailure.value;
        final store = Memory()
          ..values[SecureStorageService.accessTokenKey] = 'account-a-access'
          ..values[SecureStorageService.refreshTokenKey] = 'account-a-refresh';
        final holder = AccessTokenHolder()..setAccessToken('account-a-access');
        final coordinator = AuthFlowCoordinator(
          AuthRepository(
            api: api,
            storage: SecureStorageService(store: store),
            accessTokenHolder: holder,
          ),
        );
        late BuildContext context;
        var navigationCount = 0;
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
            onGenerateRoute: (_) {
              navigationCount++;
              return MaterialPageRoute<void>(builder: (_) => const SizedBox());
            },
          ),
        );

        await coordinator.login(context, 'b@b.c', 'raw');
        await tester.pump();

        expect(
          store.values[SecureStorageService.accessTokenKey],
          'account-a-access',
        );
        expect(
          store.values[SecureStorageService.refreshTokenKey],
          'account-a-refresh',
        );
        expect(holder.currentAccessToken, 'account-a-access');
        expect(coordinator.hasProfileCompletionToken, isFalse);
        expect(navigationCount, 0);
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );
  }
}

class FlowApi extends AuthApi {
  FlowApi() : super(Dio(), refreshDio: Dio());
  int registerCalls = 0;
  int loginCalls = 0, logoutCalls = 0, currentUserCalls = 0;
  String? code, resendUserId, loginEmail, loginPassword, loginDeviceName;
  bool available = true;
  String? completeToken, completeUsername, completeAvatar;
  ApiException? completeFailure;
  ApiException? failure;
  ApiException? loginFailure;
  LoginResult? loginResult;
  @override
  Future<RegisterResult> register({
    required String email,
    required String password,
  }) async {
    if (failure != null) throw failure!;
    registerCalls++;
    return RegisterResult(
      userId: 'user',
      email: email,
      status: 'P',
      nextStep: 'VERIFY_EMAIL',
    );
  }

  @override
  Future<VerifyEmailResult> verifyEmail({
    required String userId,
    required String code,
  }) async {
    if (failure != null) throw failure!;
    this.code = code;
    return VerifyEmailResult(
      userId: userId,
      status: 'A',
      emailVerifiedAt: DateTime(2026),
      nextStep: 'COMPLETE_PROFILE',
      profileCompletionToken: 'secret',
    );
  }

  @override
  Future<ResendVerificationResult> resendVerification(String id) async {
    if (failure != null) throw failure!;
    resendUserId = id;
    return ResendVerificationResult(userId: id, cooldownSeconds: 37);
  }

  @override
  Future<UsernameAvailabilityResult> checkUsernameAvailability(
    String username,
  ) async =>
      UsernameAvailabilityResult(username: username, available: available);
  @override
  Future<CompleteProfileResult> completeProfile({
    required String profileCompletionToken,
    required String username,
    required String displayName,
    String? bio,
    String? avatarStorageKey,
  }) async {
    if (completeFailure != null) throw completeFailure!;
    completeToken = profileCompletionToken;
    completeUsername = username;
    completeAvatar = avatarStorageKey;
    return const CompleteProfileResult(
      userId: 'user',
      username: 'user_name',
      displayName: 'Name',
      status: 'ACTIVE',
      nextStep: 'LOGIN',
    );
  }

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
    String? deviceName,
  }) async {
    loginCalls++;
    loginEmail = email;
    loginPassword = password;
    loginDeviceName = deviceName;
    if (loginFailure != null) throw loginFailure!;
    return loginResult ??
        AuthenticatedSession(
          userId: 'user',
          status: 'ACTIVE',
          accessToken: 'access',
          refreshToken: 'refresh',
          tokenType: 'Bearer',
          accessTokenExpiresAt: DateTime(2026),
          user: const UserSummary(
            id: 'user',
            email: 'a@b.c',
            username: 'user',
            displayName: 'User',
          ),
        );
  }

  @override
  Future<void> logout(String refreshToken) async {
    logoutCalls++;
  }

  @override
  Future<CurrentUser> getCurrentUser() async {
    currentUserCalls++;
    throw UnimplementedError();
  }
}

class Memory implements SecureKeyValueStore {
  final values = <String, String>{};
  bool failDeletes = false;
  @override
  Future<void> delete(String k) async {
    if (failDeletes) throw StateError('x');
    values.remove(k);
  }

  @override
  Future<String?> read(String k) async => values[k];
  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}
