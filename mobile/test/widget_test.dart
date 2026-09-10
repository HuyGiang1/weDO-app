import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/core/network/access_token_holder.dart';
import 'package:mobile/core/storage/secure_key_value_store.dart';
import 'package:mobile/core/storage/secure_storage_service.dart';
import 'package:mobile/features/auth/application/auth_session_controller.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';

class _TestSecureStore implements SecureKeyValueStore {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write({required String key, required String value}) async {}
}

class _TestAuthApi extends Fake implements AuthApi {}

AuthSessionController _createTestSessionController({
  AuthSessionStatus status = AuthSessionStatus.unauthenticated,
}) {
  final store = _TestSecureStore();
  final storage = SecureStorageService(store: store);
  final holder = AccessTokenHolder();
  final repo = AuthRepository(
    api: _TestAuthApi(),
    storage: storage,
    accessTokenHolder: holder,
  );
  return AuthSessionController(
    storage: storage,
    accessTokenHolder: holder,
    repository: repo,
    initialStatus: status,
  );
}

void main() {
  testWidgets('WeDoApp mounts and displays initial WelcomeScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      WeDoApp(authSessionController: _createTestSessionController()),
    );

    expect(find.text('WeDo'), findsOneWidget);
    expect(find.text('Squad up.'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('Welcome Login reaches LoginScreen', (WidgetTester tester) async {
    await tester.pumpWidget(
      WeDoApp(authSessionController: _createTestSessionController()),
    );

    final loginButton = find.text('Login');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Welcome Create Account reaches RegisterScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      WeDoApp(authSessionController: _createTestSessionController()),
    );

    final createAccountButton = find.text('Create Account');
    await tester.ensureVisible(createAccountButton);
    await tester.tap(createAccountButton);
    await tester.pumpAndSettle();

    expect(find.text('Join WeDo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Register Login reaches LoginScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      WeDoApp(authSessionController: _createTestSessionController()),
    );

    final createAccountButton = find.text('Create Account');
    await tester.ensureVisible(createAccountButton);
    await tester.tap(createAccountButton);
    await tester.pumpAndSettle();
    expect(find.text('Join WeDo'), findsOneWidget);

    final loginButton = find.text('Login');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login Forgot Password reaches ForgotPasswordScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      WeDoApp(authSessionController: _createTestSessionController()),
    );

    final loginButton = find.text('Login');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    final forgotPassword = find.text('Forgot Password?');
    await tester.ensureVisible(forgotPassword);
    await tester.tap(forgotPassword);
    await tester.pumpAndSettle();

    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login Create Account reaches RegisterScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      WeDoApp(authSessionController: _createTestSessionController()),
    );

    final loginButton = find.text('Login');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    final createAccountButton = find.text('Create Account');
    await tester.ensureVisible(createAccountButton);
    await tester.tap(createAccountButton);
    await tester.pumpAndSettle();

    expect(find.text('Join WeDo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
