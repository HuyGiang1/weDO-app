import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/social/data/models/social_models.dart';
import 'package:mobile/features/social/presentation/widgets/social_action_button.dart';

void main() {
  group('SocialActionButton Widget Tests', () {
    testWidgets('19. Renders loading indicator when isLoading is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SocialActionButton(
              state: RelationshipState.none,
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Thêm bạn bè'), findsNothing);
    });

    testWidgets('none state renders Thêm bạn bè button and fires callback', (tester) async {
      bool called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocialActionButton(
              state: RelationshipState.none,
              onAddFriend: () => called = true,
            ),
          ),
        ),
      );

      expect(find.text('Thêm bạn bè'), findsOneWidget);
      await tester.tap(find.text('Thêm bạn bè'));
      expect(called, isTrue);
    });

    testWidgets('pendingSent state renders Hủy lời mời and fires callback', (tester) async {
      bool called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocialActionButton(
              state: RelationshipState.pendingSent,
              onCancelRequest: () => called = true,
            ),
          ),
        ),
      );

      expect(find.text('Hủy lời mời'), findsOneWidget);
      await tester.tap(find.text('Hủy lời mời'));
      expect(called, isTrue);
    });

    testWidgets('pendingReceived state renders Chấp nhận and Từ chối buttons and fires callbacks',
        (tester) async {
      bool acceptCalled = false;
      bool declineCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocialActionButton(
              state: RelationshipState.pendingReceived,
              onAccept: () => acceptCalled = true,
              onDecline: () => declineCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Chấp nhận'), findsOneWidget);
      expect(find.text('Từ chối'), findsOneWidget);

      await tester.tap(find.text('Chấp nhận'));
      expect(acceptCalled, isTrue);

      await tester.tap(find.text('Từ chối'));
      expect(declineCalled, isTrue);
    });

    testWidgets('friends state renders Bạn bè button and fires callback', (tester) async {
      bool called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocialActionButton(
              state: RelationshipState.friends,
              onUnfriend: () => called = true,
            ),
          ),
        ),
      );

      expect(find.text('Bạn bè'), findsOneWidget);
      await tester.tap(find.text('Bạn bè'));
      expect(called, isTrue);
    });

    testWidgets('blocked state renders Bỏ chặn button and fires callback', (tester) async {
      bool called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocialActionButton(
              state: RelationshipState.blocked,
              onUnblock: () => called = true,
            ),
          ),
        ),
      );

      expect(find.text('Bỏ chặn'), findsOneWidget);
      await tester.tap(find.text('Bỏ chặn'));
      expect(called, isTrue);
    });

    testWidgets('blockedBy state renders nothing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SocialActionButton(
              state: RelationshipState.blockedBy,
            ),
          ),
        ),
      );

      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('self state renders nothing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SocialActionButton(
              state: RelationshipState.self,
            ),
          ),
        ),
      );

      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });
  });
}
