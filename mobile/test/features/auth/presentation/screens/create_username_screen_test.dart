import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/ui/widgets/primary_button.dart';
import 'package:mobile/features/auth/presentation/screens/create_username_screen.dart';

void main() {
  Widget buildSubject({
    Future<UsernameAvailability> Function(String username)? onCheckAvailability,
    Future<void> Function(String username)? onContinue,
  }) {
    return MaterialApp(
      home: CreateUsernameScreen(
        onCheckAvailability: onCheckAvailability,
        onContinue: onContinue,
      ),
    );
  }

  Finder usernameField() => find.byType(TextField);
  Finder continueButton() => find.widgetWithText(PrimaryButton, 'Continue');

  ElevatedButton continueElevatedButton(WidgetTester tester) {
    return tester.widget<ElevatedButton>(
      find.descendant(
        of: continueButton(),
        matching: find.byType(ElevatedButton),
      ),
    );
  }

  Future<void> enterUsername(WidgetTester tester, String username) async {
    await tester.enterText(usernameField(), username);
    await tester.pump();
  }

  group('CreateUsernameScreen Widget Tests', () {
    testWidgets('renders Stitch copy, prefix, Continue, and empty input', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('WeDo'), findsOneWidget);
      expect(find.text('Choose your vibe'), findsOneWidget);
      expect(
        find.text('Pick a unique username for your profile.'),
        findsOneWidget,
      );
      expect(find.text('@'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('alex_vibes'), findsNothing);
      expect(
        tester.widget<TextField>(usernameField()).controller!.text,
        isEmpty,
      );
      expect(find.text('Username is available'), findsNothing);
    });

    testWidgets(
      'enforces exact local username syntax without availability calls',
      (tester) async {
        var availabilityCalls = 0;
        await tester.pumpWidget(
          buildSubject(
            onCheckAvailability: (_) async {
              availabilityCalls++;
              return UsernameAvailability.available;
            },
          ),
        );

        final invalidCases = <String, String>{
          'ab': 'Username must be between 3 and 30 characters',
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa':
              'Username must be between 3 and 30 characters',
          'name.with.dot':
              'Username must contain only letters, numbers, and underscores',
          'name-hyphen':
              'Username must contain only letters, numbers, and underscores',
          'name space':
              'Username must contain only letters, numbers, and underscores',
        };

        for (final entry in invalidCases.entries) {
          await enterUsername(tester, entry.key);
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.text(entry.value), findsOneWidget);
        }

        expect(availabilityCalls, equals(0));
        expect(continueElevatedButton(tester).onPressed, isNull);
      },
    );

    testWidgets('accepts letters, numbers, and underscores', (tester) async {
      final checkedUsernames = <String>[];
      await tester.pumpWidget(
        buildSubject(
          onCheckAvailability: (username) async {
            checkedUsernames.add(username);
            return UsernameAvailability.available;
          },
        ),
      );

      for (final username in ['lettersOnly', 'name123', '__name__']) {
        await enterUsername(tester, username);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
      }

      expect(checkedUsernames, equals(['lettersonly', 'name123', '__name__']));
      expect(find.text('Username is available'), findsOneWidget);
    });

    testWidgets('waits 400ms before availability and shows checking state', (
      tester,
    ) async {
      final completer = Completer<UsernameAvailability>();
      var availabilityCalls = 0;
      await tester.pumpWidget(
        buildSubject(
          onCheckAvailability: (_) {
            availabilityCalls++;
            return completer.future;
          },
        ),
      );

      await enterUsername(tester, 'alex');
      await tester.pump(const Duration(milliseconds: 399));
      expect(availabilityCalls, equals(0));
      expect(find.text('Checking username...'), findsNothing);

      await tester.pump(const Duration(milliseconds: 1));
      expect(availabilityCalls, equals(1));
      expect(find.text('Checking username...'), findsOneWidget);
      expect(continueElevatedButton(tester).onPressed, isNull);

      completer.complete(UsernameAvailability.available);
      await tester.pump();
    });

    testWidgets(
      'renders available, unavailable, and availability error states',
      (tester) async {
        final results = <Future<UsernameAvailability> Function()>[
          () async => UsernameAvailability.available,
          () async => UsernameAvailability.unavailable,
          () => Future<UsernameAvailability>.error(StateError('network')),
        ];
        final expectedMessages = [
          'Username is available',
          'Username is already taken',
          "Couldn't check username availability",
        ];

        for (var i = 0; i < results.length; i++) {
          await tester.pumpWidget(
            buildSubject(onCheckAvailability: (_) => results[i]()),
          );
          await enterUsername(tester, 'state$i');
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump();
          expect(find.text(expectedMessages[i]), findsOneWidget);
        }
      },
    );

    testWidgets(
      'ignores stale availability responses after a username change',
      (tester) async {
        final responses = <String, Completer<UsernameAvailability>>{};
        await tester.pumpWidget(
          buildSubject(
            onCheckAvailability: (username) {
              final completer = Completer<UsernameAvailability>();
              responses[username] = completer;
              return completer.future;
            },
          ),
        );

        await enterUsername(tester, 'alex');
        await tester.pump(const Duration(milliseconds: 400));
        await enterUsername(tester, 'alex2');
        await tester.pump(const Duration(milliseconds: 400));

        responses['alex2']!.complete(UsernameAvailability.available);
        await tester.pump();
        expect(find.text('Username is available'), findsOneWidget);

        responses['alex']!.complete(UsernameAvailability.unavailable);
        await tester.pump();
        expect(find.text('Username is available'), findsOneWidget);
        expect(find.text('Username is already taken'), findsNothing);
      },
    );

    testWidgets(
      'uses canonical lowercase username for availability and Continue',
      (tester) async {
        String? checkedUsername;
        String? continuedUsername;
        await tester.pumpWidget(
          buildSubject(
            onCheckAvailability: (username) async {
              checkedUsername = username;
              return UsernameAvailability.available;
            },
            onContinue: (username) async {
              continuedUsername = username;
            },
          ),
        );

        await enterUsername(tester, 'Alex_Vibes');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(checkedUsername, equals('alex_vibes'));

        await tester.ensureVisible(continueButton());
        await tester.tap(continueButton());
        await tester.pumpAndSettle();
        expect(continuedUsername, equals('alex_vibes'));
      },
    );

    testWidgets(
      'blocks Continue before confirmed availability and without callback',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await enterUsername(tester, 'valid_name');
        expect(continueElevatedButton(tester).onPressed, isNull);

        await tester.pumpWidget(
          buildSubject(
            onCheckAvailability: (_) async => UsernameAvailability.available,
          ),
        );
        await enterUsername(tester, 'valid_name');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(continueElevatedButton(tester).onPressed, isNull);
      },
    );

    testWidgets('prevents double Continue while callback is pending', (
      tester,
    ) async {
      final completer = Completer<void>();
      var continueCalls = 0;
      await tester.pumpWidget(
        buildSubject(
          onCheckAvailability: (_) async => UsernameAvailability.available,
          onContinue: (_) {
            continueCalls++;
            return completer.future;
          },
        ),
      );

      await enterUsername(tester, 'available_name');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.ensureVisible(continueButton());
      await tester.tap(continueButton());
      await tester.pump();

      expect(continueCalls, equals(1));
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('cancels pending debounce when disposed', (tester) async {
      var availabilityCalls = 0;
      await tester.pumpWidget(
        buildSubject(
          onCheckAvailability: (_) async {
            availabilityCalls++;
            return UsernameAvailability.available;
          },
        ),
      );
      await enterUsername(tester, 'dispose_name');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 400));

      expect(availabilityCalls, equals(0));
    });

    testWidgets('renders without overflow at normal and compact phone sizes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSubject());
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpWidget(buildSubject());
      expect(tester.takeException(), isNull);
    });
  });
}
