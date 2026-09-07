import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/screens/welcome_screen.dart';

void main() {
  Widget buildSubject({
    VoidCallback? onCreateAccountPressed,
    VoidCallback? onLoginPressed,
  }) {
    return MaterialApp(
      home: WelcomeScreen(
        onCreateAccountPressed: onCreateAccountPressed ?? () {},
        onLoginPressed: onLoginPressed ?? () {},
      ),
    );
  }

  group('WelcomeScreen Widget Tests', () {
    testWidgets('renders brand, headline, subtitle, and action buttons', (tester) async {
      await tester.pumpWidget(buildSubject());

      // Brand
      expect(find.text('WeDo'), findsOneWidget);

      // Headline & Subtitle
      expect(find.text('Squad up.'), findsOneWidget);
      expect(
        find.text('Coordinate, share, and settle up with your squad effortlessly.'),
        findsOneWidget,
      );

      // Buttons
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);

      // Image asset
      expect(find.byType(Image), findsOneWidget);
      final imageWidget = tester.widget<Image>(find.byType(Image));
      expect(imageWidget.image, isA<AssetImage>());
      final assetImage = imageWidget.image as AssetImage;
      expect(assetImage.assetName, equals('assets/images/wedo_logo.png'));
    });

    testWidgets('fires onCreateAccountPressed callback when Create Account is tapped', (tester) async {
      var createAccountTapped = false;

      await tester.pumpWidget(
        buildSubject(
          onCreateAccountPressed: () {
            createAccountTapped = true;
          },
        ),
      );

      final buttonFinder = find.text('Create Account');
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pump();

      expect(createAccountTapped, isTrue);
    });

    testWidgets('fires onLoginPressed callback when Login is tapped', (tester) async {
      var loginTapped = false;

      await tester.pumpWidget(
        buildSubject(
          onLoginPressed: () {
            loginTapped = true;
          },
        ),
      );

      final buttonFinder = find.text('Login');
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pump();

      expect(loginTapped, isTrue);
    });

    testWidgets('renders without overflow at normal phone sizes', (tester) async {
      // Test at standard modern smartphone viewport (390 x 844)
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSubject());
      expect(tester.takeException(), isNull);

      // Test at compact smartphone viewport (360 x 640)
      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpWidget(buildSubject());
      expect(tester.takeException(), isNull);
    });
  });
}
