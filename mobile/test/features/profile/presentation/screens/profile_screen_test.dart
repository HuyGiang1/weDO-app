import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/routes.dart';
import 'package:mobile/features/auth/data/models/auth_models.dart';
import 'package:mobile/features/profile/presentation/screens/profile_screen.dart';

void main() {
  CurrentUser user({
    String? phone = '+84987654321',
    String? bio = 'Building weDO.',
  }) => CurrentUser(
    id: 'user-id',
    email: 'huy@wedo.social',
    status: 'ACTIVE',
    emailVerified: true,
    username: 'huy_giang',
    displayName: 'Huy Giang',
    phone: phone,
    bio: bio,
  );

  Widget subject(Future<CurrentUser> Function() loader) => MaterialApp(
    home: ProfileScreen(
      loadCurrentUser: loader,
      updateProfile: (_) async => user(),
      updateUsername: (_) async => user(),
      changePassword: ({
        required currentPassword,
        required newPassword,
      }) async {},
      endSessionAfterPasswordChange: () async => true,
    ),
  );

  testWidgets('shows loading before the current profile resolves', (
    tester,
  ) async {
    final completer = Completer<CurrentUser>();
    await tester.pumpWidget(subject(() => completer.future));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(user());
    await tester.pumpAndSettle();
  });

  testWidgets('renders the authenticated current user fields', (tester) async {
    await tester.pumpWidget(subject(() async => user()));
    await tester.pumpAndSettle();
    expect(find.text('Huy Giang'), findsOneWidget);
    expect(find.text('@huy_giang'), findsOneWidget);
    expect(find.text('huy@wedo.social'), findsOneWidget);
    expect(find.text('+84987654321'), findsOneWidget);
    expect(find.text('Building weDO.'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
  });

  testWidgets('omits nullable optional fields without fabricating values', (
    tester,
  ) async {
    await tester.pumpWidget(subject(() async => user(phone: null, bio: '   ')));
    await tester.pumpAndSettle();
    expect(find.text('Phone'), findsNothing);
    expect(find.text('Bio'), findsNothing);
  });

  testWidgets('shows an error and retries loading', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      subject(() async {
        attempts++;
        if (attempts == 1) throw StateError('offline');
        return user();
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load your profile.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Huy Giang'), findsOneWidget);
  });

  testWidgets('renders the edit result without loading /me a second time', (
    tester,
  ) async {
    var loads = 0;
    final updated = user(bio: 'Updated bio');
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          loadCurrentUser: () async {
            loads++;
            return user();
          },
          updateProfile: (_) async => updated,
          updateUsername: (_) async => updated,
          changePassword: ({
            required currentPassword,
            required newPassword,
          }) async {},
          endSessionAfterPasswordChange: () async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final edit = find.widgetWithText(ElevatedButton, 'Edit Profile');
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(loads, 1);
    expect(find.text('Updated bio'), findsOneWidget);
  });

  testWidgets('keeps the current profile when editing is canceled', (
    tester,
  ) async {
    var updates = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          loadCurrentUser: () async => user(),
          updateProfile: (_) async {
            updates++;
            return user(bio: 'Unexpected');
          },
          updateUsername: (_) async => user(),
          changePassword: ({
            required currentPassword,
            required newPassword,
          }) async {},
          endSessionAfterPasswordChange: () async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final edit = find.widgetWithText(ElevatedButton, 'Edit Profile');
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(updates, 0);
    expect(find.text('Building weDO.'), findsOneWidget);
  });

  testWidgets('renders a returned username without loading /me a second time', (
    tester,
  ) async {
    var loads = 0;
    final updated = CurrentUser(
      id: 'user-id',
      email: 'huy@wedo.social',
      status: 'ACTIVE',
      emailVerified: true,
      username: 'new_name',
      displayName: 'Huy Giang',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          loadCurrentUser: () async {
            loads++;
            return user();
          },
          updateProfile: (_) async => user(),
          updateUsername: (_) async => updated,
          changePassword: ({
            required currentPassword,
            required newPassword,
          }) async {},
          endSessionAfterPasswordChange: () async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final change = find.text('Change Username');
    await tester.ensureVisible(change);
    await tester.tap(change);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update Username'));
    await tester.pumpAndSettle();

    expect(loads, 1);
    expect(find.text('@new_name'), findsOneWidget);
  });

  testWidgets('opens the protected privacy route from the profile screen', (
    tester,
  ) async {
    String? pushedRoute;
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          pushedRoute = settings.name;
          return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Privacy destination')),
            settings: settings,
          );
        },
        home: ProfileScreen(
          loadCurrentUser: () async => user(),
          updateProfile: (_) async => user(),
          updateUsername: (_) async => user(),
          changePassword: ({
            required currentPassword,
            required newPassword,
          }) async {},
          endSessionAfterPasswordChange: () async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final privacy = find.text('Privacy Settings');
    await tester.ensureVisible(privacy);
    await tester.tap(privacy);
    await tester.pumpAndSettle();

    expect(pushedRoute, AppRoutes.privacy);
    expect(find.text('Privacy destination'), findsOneWidget);
  });

  testWidgets('opens My QR from the profile screen', (tester) async {
    String? pushedRoute;
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          pushedRoute = settings.name;
          return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('QR destination')),
            settings: settings,
          );
        },
        home: ProfileScreen(
          loadCurrentUser: () async => user(),
          updateProfile: (_) async => user(),
          updateUsername: (_) async => user(),
          changePassword: ({
            required currentPassword,
            required newPassword,
          }) async {},
          endSessionAfterPasswordChange: () async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final myQr = find.text('My QR');
    await tester.ensureVisible(myQr);
    await tester.tap(myQr);
    await tester.pumpAndSettle();
    expect(pushedRoute, AppRoutes.personalQr);
    expect(find.text('QR destination'), findsOneWidget);
  });
}
