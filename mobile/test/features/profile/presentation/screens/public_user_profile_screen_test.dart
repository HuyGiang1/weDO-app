import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/data/profile_models.dart';
import 'package:mobile/features/profile/presentation/screens/public_user_profile_screen.dart';

void main() {
  testWidgets('message action uses valid Vietnamese and retains its callback', (
    tester,
  ) async {
    var messages = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PublicUserProfileScreen(
          userId: 'id',
          loadPublicProfile: (_) async => const PublicUserProfile(
            id: 'id',
            username: 'maya',
            displayName: 'Maya',
          ),
          onMessage: () => messages++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhắn tin'));
    expect(messages, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('renders loading then only safe public fields with fallbacks', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PublicUserProfileScreen(
          userId: 'id',
          loadPublicProfile: (_) async => const PublicUserProfile(
            id: 'id',
            username: 'maya',
            displayName: null,
            avatarStorageKey: null,
            bio: null,
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('maya'), findsOneWidget);
    expect(find.text('@maya'), findsOneWidget);
    expect(find.textContaining('email', findRichText: true), findsNothing);
    expect(find.text('Add Friend'), findsNothing);
    expect(find.text('Message'), findsNothing);
    expect(find.text('Block User'), findsNothing);
  });

  testWidgets('renders bio and supports safe retry on error', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PublicUserProfileScreen(
          userId: 'id',
          loadPublicProfile: (_) async {
            calls++;
            if (calls == 1) {
              throw Exception();
            }
            return const PublicUserProfile(
              id: 'id',
              username: 'maya',
              displayName: 'Maya Lin',
              bio: 'Designer',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không thể tải hồ sơ này.'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Maya Lin'), findsOneWidget);
    expect(find.text('Designer'), findsOneWidget);
  });
}
