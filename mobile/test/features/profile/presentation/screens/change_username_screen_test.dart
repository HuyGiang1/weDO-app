import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/auth/data/models/auth_models.dart';
import 'package:mobile/features/profile/data/profile_models.dart';
import 'package:mobile/features/profile/presentation/screens/change_username_screen.dart';

void main() {
  final initialUser = _user();

  Future<void> pumpScreen(
    WidgetTester tester, {
    Future<CurrentUser> Function(UpdateUsernameRequest)? updateUsername,
  }) => tester.pumpWidget(
    MaterialApp(
      home: ChangeUsernameScreen(
        initialUser: initialUser,
        updateUsername: updateUsername ?? (_) async => _user(),
      ),
    ),
  );

  TextFormField usernameField(WidgetTester tester) =>
      tester.widget(find.byType(TextFormField));

  testWidgets(
    'populates the current username and has no live availability UI',
    (tester) async {
      await pumpScreen(tester);

      expect(usernameField(tester).controller!.text, 'huy_giang');
      expect(find.text('Checking username...'), findsNothing);
    },
  );

  testWidgets('validates canonical username input locally', (tester) async {
    await pumpScreen(tester);
    final field = find.byType(TextFormField);

    for (final invalid in ['', 'ab', 'a' * 31, 'hello world', 'giảng']) {
      await tester.enterText(field, invalid);
      await tester.tap(find.text('Update Username'));
      await tester.pump();
    }

    expect(
      find.text('Username must contain only letters, numbers, and underscores'),
      findsOneWidget,
    );
  });

  testWidgets('trims and lowercases the payload before submitting', (
    tester,
  ) async {
    UpdateUsernameRequest? sent;
    await pumpScreen(
      tester,
      updateUsername: (request) async {
        sent = request;
        return _user(username: 'new_name');
      },
    );

    await tester.enterText(find.byType(TextFormField), '  New_Name  ');
    await tester.tap(find.text('Update Username'));
    await tester.pump();

    expect(sent!.username, 'new_name');
  });

  testWidgets('prevents duplicate submission while a request is pending', (
    tester,
  ) async {
    final completer = Completer<CurrentUser>();
    var calls = 0;
    await pumpScreen(
      tester,
      updateUsername: (_) {
        calls++;
        return completer.future;
      },
    );

    await tester.tap(find.text('Update Username'));
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(calls, 1);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    completer.complete(_user());
    await tester.pump();
  });

  testWidgets('submits same username and pops the returned CurrentUser', (
    tester,
  ) async {
    UpdateUsernameRequest? sent;
    CurrentUser? result;
    final updated = _user(username: 'new_name');
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.of(context).push<CurrentUser>(
                MaterialPageRoute(
                  builder: (_) => ChangeUsernameScreen(
                    initialUser: initialUser,
                    updateUsername: (request) async {
                      sent = request;
                      return updated;
                    },
                  ),
                ),
              );
            },
            child: const Text('Open username editor'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open username editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update Username'));
    await tester.pumpAndSettle();

    expect(sent!.username, 'huy_giang');
    expect(result, same(updated));
  });

  testWidgets('renders conflict and safe network feedback', (tester) async {
    await pumpScreen(
      tester,
      updateUsername: (_) async =>
          throw const ApiException(code: 'USERNAME_ALREADY_EXISTS'),
    );
    await tester.tap(find.text('Update Username'));
    await tester.pumpAndSettle();
    expect(find.text('Username is already taken.'), findsOneWidget);

    await pumpScreen(
      tester,
      updateUsername: (_) async => throw StateError('offline'),
    );
    await tester.tap(find.text('Update Username'));
    await tester.pumpAndSettle();
    expect(
      find.text('Unable to update your username. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('canceling does not submit', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => ChangeUsernameScreen(
                  initialUser: initialUser,
                  updateUsername: (_) async {
                    calls++;
                    return _user();
                  },
                ),
              ),
            ),
            child: const Text('Open username editor'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open username editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(calls, 0);
  });
}

CurrentUser _user({String username = 'huy_giang'}) => CurrentUser(
  id: 'user-id',
  email: 'huy@wedo.social',
  status: 'ACTIVE',
  emailVerified: true,
  username: username,
  displayName: 'Huy Giang',
);
