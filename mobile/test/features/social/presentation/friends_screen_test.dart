import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/paged_response.dart';
import 'package:mobile/features/social/application/social_controllers.dart';
import 'package:mobile/features/social/application/social_state.dart';
import 'package:mobile/features/social/data/models/social_models.dart';
import 'package:mobile/features/social/data/social_api.dart';
import 'package:mobile/features/social/data/social_failure.dart';
import 'package:mobile/features/social/data/social_repository.dart';
import 'package:mobile/features/social/presentation/screens/friends_screen.dart';
import 'package:mobile/features/social/presentation/widgets/social_empty_state.dart';
import 'package:mobile/features/social/presentation/widgets/social_error_view.dart';

class MockSocialRepository extends SocialRepository {
  MockSocialRepository() : super(api: SocialApi(Dio()));

  PagedResponse<Friend>? friendsResult;
  SocialFailure? errorToThrow;
  SocialFailure? actionErrorToThrow;

  bool unfriendCalled = false;
  String? unfriendUserId;

  @override
  Future<PagedResponse<Friend>> getFriends({
    int page = 0,
    int size = 30,
  }) async {
    if (errorToThrow != null) throw SocialException(errorToThrow!);
    return friendsResult ??
        const PagedResponse(
          items: [],
          page: 0,
          size: 30,
          totalElements: 0,
          totalPages: 0,
          hasNext: false,
        );
  }

  @override
  Future<void> unfriend(String friendUserId) async {
    unfriendCalled = true;
    unfriendUserId = friendUserId;
    if (actionErrorToThrow != null) throw SocialException(actionErrorToThrow!);
  }
}

void main() {
  late MockSocialRepository repository;
  late FriendsController controller;

  final sampleFriend = Friend(
    friendshipId: 'f-1',
    friend: const SocialUserSummary(
      id: 'user-2',
      username: 'bob',
      displayName: 'Bob The Builder',
    ),
    createdAt: DateTime.parse('2026-09-13T10:00:00Z'),
  );

  setUp(() {
    repository = MockSocialRepository();
    controller = FriendsController(repository: repository);
  });

  Widget buildSubject({VoidCallback? onOpenRequests, VoidCallback? onOpenBlocked}) =>
      MaterialApp(
        home: FriendsScreen(
          controller: controller,
          onOpenFriendRequests: onOpenRequests,
          onOpenBlockedUsers: onOpenBlocked,
        ),
      );

  group('FriendsScreen Widget Tests', () {
    testWidgets('8. Friends list renders correctly', (tester) async {
      repository.friendsResult = PagedResponse(
        items: [sampleFriend],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Bạn bè'), findsOneWidget);
      expect(find.text('Bob The Builder'), findsOneWidget);
      expect(find.text('@bob'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Hủy kết bạn'), findsOneWidget);
    });

    testWidgets('9. Friends empty state renders when list is empty', (tester) async {
      repository.friendsResult = const PagedResponse(
        items: [],
        page: 0,
        size: 30,
        totalElements: 0,
        totalPages: 0,
        hasNext: false,
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(SocialEmptyState), findsOneWidget);
      expect(find.text('Chưa có bạn bè nào'), findsOneWidget);
    });

    testWidgets('Renders error state and retries on press', (tester) async {
      repository.errorToThrow = const SocialFailure(
        SocialFailureType.network,
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(SocialErrorView), findsOneWidget);

      repository.errorToThrow = null;
      repository.friendsResult = PagedResponse(
        items: [sampleFriend],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Thử lại'));
      await tester.pumpAndSettle();

      expect(find.text('Bob The Builder'), findsOneWidget);
    });

    testWidgets('10. Unfriend confirmation dialog is displayed', (tester) async {
      repository.friendsResult = PagedResponse(
        items: [sampleFriend],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Hủy kết bạn'));
      await tester.pumpAndSettle();

      expect(find.text('Hủy kết bạn'), findsWidgets);
      expect(find.text('Bạn có chắc muốn hủy kết bạn với Bob The Builder?'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Hủy'), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
      await tester.pumpAndSettle();

      expect(repository.unfriendCalled, isFalse);
      expect(find.text('Bob The Builder'), findsOneWidget);
    });

    testWidgets('11. Unfriend confirmation triggers unfriend and removes item on success',
        (tester) async {
      repository.friendsResult = PagedResponse(
        items: [sampleFriend],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Hủy kết bạn'));
      await tester.pumpAndSettle();

      // Tap confirm button in dialog (TextButton with 'Hủy kết bạn')
      await tester.tap(find.widgetWithText(TextButton, 'Hủy kết bạn'));
      await tester.pump(); // trigger mutation
      await tester.pumpAndSettle();

      expect(repository.unfriendCalled, isTrue);
      expect(repository.unfriendUserId, equals('user-2'));
      expect(find.text('Đã hủy kết bạn với Bob The Builder.'), findsOneWidget);
      expect(find.text('Bob The Builder'), findsNothing);
    });

    testWidgets('12. Unfriend error shows localized error SnackBar', (tester) async {
      repository.friendsResult = PagedResponse(
        items: [sampleFriend],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );
      repository.actionErrorToThrow = const SocialFailure(
        SocialFailureType.friendshipNotFound,
        backendCode: 'FRIENDSHIP_NOT_FOUND',
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Hủy kết bạn'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Hủy kết bạn'));
      await tester.pumpAndSettle();

      expect(find.text('Không tìm thấy quan hệ bạn bè.'), findsOneWidget);
      // Item still present because unfriend failed
      expect(find.text('Bob The Builder'), findsOneWidget);
    });

    testWidgets('17. Pagination loading indicator renders when hasNext is true', (tester) async {
      repository.friendsResult = PagedResponse(
        items: [sampleFriend],
        page: 0,
        size: 1,
        totalElements: 2,
        totalPages: 2,
        hasNext: true,
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify item rendered and has a progress indicator at the end
      expect(find.text('Bob The Builder'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('18. Pagination error state renders retry button on errorMore', (tester) async {
      repository.friendsResult = PagedResponse(
        items: [sampleFriend],
        page: 0,
        size: 1,
        totalElements: 2,
        totalPages: 2,
        hasNext: true,
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Trigger errorMore state manually on controller
      controller.friends.value = controller.friends.value.copyWith(
        status: SocialListStatus.errorMore,
        failure: const SocialFailure(SocialFailureType.network),
      );
      await tester.pump();

      expect(find.text('Tải thêm thất bại. Thử lại'), findsOneWidget);
    });
  });
}
