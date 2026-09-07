import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/ui/widgets/primary_button.dart';
import 'package:mobile/features/auth/presentation/screens/complete_profile_screen.dart';

void main() {
  Widget buildSubject({
    String username = 'alex_vibes',
    Future<void> Function(CompleteProfileData data)? onContinue,
    Future<void> Function()? onPickAvatar,
  }) {
    return MaterialApp(
      home: CompleteProfileScreen(
        username: username,
        onContinue: onContinue,
        onPickAvatar: onPickAvatar,
      ),
    );
  }

  Finder displayNameField() => find.byType(TextField).at(0);
  Finder bioField() => find.byType(TextField).at(1);
  Finder continueButton() => find.widgetWithText(PrimaryButton, 'Continue');

  ElevatedButton continueElevatedButton(WidgetTester tester) {
    return tester.widget<ElevatedButton>(
      find.descendant(
        of: continueButton(),
        matching: find.byType(ElevatedButton),
      ),
    );
  }

  Future<void> enterDisplayName(WidgetTester tester, String value) async {
    await tester.enterText(displayNameField(), value);
    await tester.pump();
  }

  group('CompleteProfileScreen Widget Tests', () {
    testWidgets(
      'renders Stitch content, local logo, avatar picker, and no Skip',
      (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(Image), findsOneWidget);
        expect(
          (tester.widget<Image>(find.byType(Image)).image as AssetImage)
              .assetName,
          equals('assets/images/wedo_logo.png'),
        );
        expect(find.text("Let's set up your profile"), findsOneWidget);
        expect(
          find.text('Add a photo and some details to help friends find you.'),
          findsOneWidget,
        );
        expect(find.text('Display Name'), findsOneWidget);
        expect(find.text('Bio'), findsOneWidget);
        expect(find.text('Optional'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);
        expect(find.text('Powered by WeDo'), findsOneWidget);
        expect(find.bySemanticsLabel('Add profile photo'), findsOneWidget);
        expect(find.text('Skip'), findsNothing);
      },
    );

    testWidgets('validates empty and whitespace-only display name', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(onContinue: (_) async {}));

      await enterDisplayName(tester, '   ');
      expect(find.text('Display name is required'), findsOneWidget);
      expect(continueElevatedButton(tester).onPressed, isNull);
    });

    testWidgets('accepts Unicode and exactly 100 display-name characters', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(onContinue: (_) async {}));
      await enterDisplayName(tester, 'Nguyễn Ánh');
      expect(find.text('Display name is required'), findsNothing);

      await enterDisplayName(tester, List.filled(100, 'a').join());
      expect(continueElevatedButton(tester).onPressed, isNotNull);
    });

    testWidgets('rejects display name longer than 100 characters', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(onContinue: (_) async {}));
      await enterDisplayName(tester, List.filled(101, 'a').join());

      expect(
        find.text('Display name must not exceed 100 characters'),
        findsOneWidget,
      );
      expect(continueElevatedButton(tester).onPressed, isNull);
    });

    testWidgets(
      'accepts empty and whitespace bio but rejects bio longer than 500',
      (tester) async {
        await tester.pumpWidget(buildSubject(onContinue: (_) async {}));
        await enterDisplayName(tester, 'Alex');

        await tester.enterText(bioField(), '   ');
        await tester.pump();
        expect(find.text('Bio must not exceed 500 characters'), findsNothing);
        expect(continueElevatedButton(tester).onPressed, isNotNull);

        await tester.enterText(bioField(), List.filled(501, 'b').join());
        await tester.pump();
        expect(find.text('Bio must not exceed 500 characters'), findsOneWidget);
        expect(continueElevatedButton(tester).onPressed, isNull);
      },
    );

    testWidgets('normalizes data and forwards supplied username on Continue', (
      tester,
    ) async {
      CompleteProfileData? received;
      await tester.pumpWidget(
        buildSubject(
          username: 'already_confirmed_name',
          onContinue: (data) async => received = data,
        ),
      );
      await enterDisplayName(tester, '  Alex Smith  ');
      await tester.enterText(bioField(), '  Hello friends  ');
      await tester.pump();

      await tester.ensureVisible(continueButton());
      await tester.tap(continueButton());
      await tester.pumpAndSettle();

      expect(received?.username, equals('already_confirmed_name'));
      expect(received?.displayName, equals('Alex Smith'));
      expect(received?.bio, equals('Hello friends'));
    });

    testWidgets('normalizes blank bio to null', (tester) async {
      CompleteProfileData? received;
      await tester.pumpWidget(
        buildSubject(onContinue: (data) async => received = data),
      );
      await enterDisplayName(tester, 'Alex');
      await tester.enterText(bioField(), '   ');
      await tester.pump();

      await tester.ensureVisible(continueButton());
      await tester.tap(continueButton());
      await tester.pumpAndSettle();
      expect(received?.bio, isNull);
    });

    testWidgets(
      'avatar picker invokes callback and null callback shows no selection',
      (tester) async {
        var pickerCalls = 0;
        await tester.pumpWidget(
          buildSubject(onPickAvatar: () async => pickerCalls++),
        );
        final picker = find.bySemanticsLabel('Add profile photo');
        await tester.ensureVisible(picker);
        await tester.tap(picker);
        await tester.pump();
        expect(pickerCalls, equals(1));

        await tester.pumpWidget(buildSubject());
        expect(find.byType(Image), findsOneWidget);
      },
    );

    testWidgets('does not fake completion when onContinue is null', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await enterDisplayName(tester, 'Alex');

      expect(continueElevatedButton(tester).onPressed, isNull);
    });

    testWidgets('prevents double submit while Continue callback is pending', (
      tester,
    ) async {
      final completer = Completer<void>();
      var continueCalls = 0;
      await tester.pumpWidget(
        buildSubject(
          onContinue: (_) {
            continueCalls++;
            return completer.future;
          },
        ),
      );
      await enterDisplayName(tester, 'Alex');
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
