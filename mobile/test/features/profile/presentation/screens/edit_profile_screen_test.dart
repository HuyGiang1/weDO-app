import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/data/models/auth_models.dart';
import 'package:mobile/features/profile/data/profile_models.dart';
import 'package:mobile/features/profile/presentation/screens/edit_profile_screen.dart';

void main() {
  final initialUser = _user();

  Future<void> pumpScreen(
    WidgetTester tester, {
    Future<CurrentUser> Function(UpdateProfileRequest)? updateProfile,
  }) => tester.pumpWidget(
    MaterialApp(
      home: EditProfileScreen(
        initialUser: initialUser,
        updateProfile: updateProfile ?? (_) async => _user(),
      ),
    ),
  );

  TextFormField field(WidgetTester tester, int index) =>
      tester.widgetList<TextFormField>(find.byType(TextFormField)).elementAt(index);

  testWidgets('populates editable fields from CurrentUser', (tester) async {
    await pumpScreen(tester);

    expect(field(tester, 0).controller!.text, 'Huy Giang');
    expect(field(tester, 1).controller!.text, 'Building weDO.');
    expect(field(tester, 2).controller!.text, '+84987654321');
  });

  testWidgets('validates blank and overlong display names', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextFormField).at(0), '   ');
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    expect(find.text('Display name is required'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'a' * 101);
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    expect(find.text('Display name must not exceed 100 characters'), findsOneWidget);
  });

  testWidgets('validates overlong bio and phone values', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextFormField).at(1), 'a' * 501);
    await tester.enterText(find.byType(TextFormField).at(2), '1' * 21);
    await tester.tap(find.text('Save changes'));
    await tester.pump();

    expect(find.text('Bio must not exceed 500 characters'), findsOneWidget);
    expect(find.text('Phone must not exceed 20 characters'), findsOneWidget);
  });

  testWidgets('disables duplicate submission while a request is pending', (tester) async {
    final completer = Completer<CurrentUser>();
    var calls = 0;
    await pumpScreen(tester, updateProfile: (_) {
      calls++;
      return completer.future;
    });

    await tester.tap(find.text('Save changes'));
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(calls, 1);
    expect(
      tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      ).onPressed,
      isNull,
    );

    completer.complete(_user());
    await tester.pump();
  });

  testWidgets('submits once and pops the updated CurrentUser', (tester) async {
    UpdateProfileRequest? sent;
    CurrentUser? result;
    final updated = _user(displayName: 'Updated name');
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.of(context).push<CurrentUser>(
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(
                    initialUser: initialUser,
                    updateProfile: (request) async {
                      sent = request;
                      return updated;
                    },
                  ),
                ),
              );
            },
            child: const Text('Open editor'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Updated name');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(sent!.displayName, 'Updated name');
    expect(sent!.bio, 'Building weDO.');
    expect(sent!.phone, '+84987654321');
    expect(result, same(updated));
    expect(find.text('Open editor'), findsOneWidget);
  });

  testWidgets('sends blank bio and phone as clear operations', (tester) async {
    UpdateProfileRequest? sent;
    await pumpScreen(tester, updateProfile: (request) async {
      sent = request;
      return _user(bio: null, phone: null);
    });

    await tester.enterText(find.byType(TextFormField).at(1), '');
    await tester.enterText(find.byType(TextFormField).at(2), '');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(sent!.bio, '');
    expect(sent!.phone, '');
  });

  testWidgets('renders safe request-level feedback when the API fails', (tester) async {
    await pumpScreen(tester, updateProfile: (_) async => throw StateError('offline'));

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to update your profile. Please try again.'), findsOneWidget);
  });

  testWidgets('canceling does not submit', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => EditProfileScreen(
                  initialUser: initialUser,
                  updateProfile: (_) async {
                    calls++;
                    return _user();
                  },
                ),
              ),
            ),
            child: const Text('Open editor'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(calls, 0);
  });
}

CurrentUser _user({String? displayName, String? bio = 'Building weDO.', String? phone = '+84987654321'}) =>
    CurrentUser(
      id: 'user-id',
      email: 'huy@wedo.social',
      status: 'ACTIVE',
      emailVerified: true,
      username: 'huy_giang',
      displayName: displayName ?? 'Huy Giang',
      bio: bio,
      phone: phone,
    );
