import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/paged_response.dart';
import 'package:mobile/features/social/application/social_controllers.dart';
import 'package:mobile/features/social/data/models/social_models.dart';
import 'package:mobile/features/social/data/social_api.dart';
import 'package:mobile/features/social/data/social_failure.dart';
import 'package:mobile/features/social/data/social_repository.dart';
import 'package:mobile/features/social/presentation/screens/friend_requests_screen.dart';
import 'package:mobile/features/social/presentation/widgets/social_empty_state.dart';
import 'package:mobile/features/social/presentation/widgets/social_error_view.dart';

class MockSocialRepository extends SocialRepository {
  MockSocialRepository() : super(api: SocialApi(Dio()));

  PagedResponse<FriendRequest>? receivedResult;
  PagedResponse<FriendRequest>? sentResult;
  FriendRequest? acceptResult;
  SocialFailure? errorToThrow;
  SocialFailure? actionErrorToThrow;

  bool acceptCalled = false;
  bool declineCalled = false;
  bool cancelCalled = false;

  @override
  Future<PagedResponse<FriendRequest>> getReceivedFriendRequests({
    int page = 0,
    int size = 30,
  }) async {
    if (errorToThrow != null) throw SocialException(errorToThrow!);
    return receivedResult ??
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
  Future<PagedResponse<FriendRequest>> getSentFriendRequests({
    int page = 0,
    int size = 30,
  }) async {
    if (errorToThrow != null) throw SocialException(errorToThrow!);
    return sentResult ??
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
  Future<FriendRequest> acceptFriendRequest(String requestId) async {
    acceptCalled = true;
    if (actionErrorToThrow != null) throw SocialException(actionErrorToThrow!);
    return acceptResult!;
  }

  @override
  Future<void> declineFriendRequest(String requestId) async {
    declineCalled = true;
    if (actionErrorToThrow != null) throw SocialException(actionErrorToThrow!);
  }

  @override
  Future<void> cancelFriendRequest(String requestId) async {
    cancelCalled = true;
    if (actionErrorToThrow != null) throw SocialException(actionErrorToThrow!);
  }
}

void main() {
  late MockSocialRepository repository;
  late FriendRequestsController controller;

  final sampleUser = const SocialUserSummary(
    id: 'user-1',
    username: 'alice',
    displayName: 'Alice Wonderland',
  );

  final sampleTarget = const SocialUserSummary(
    id: 'user-2',
    username: 'bob',
    displayName: 'Bob The Builder',
  );

  final sampleRequest = FriendRequest(
    id: 'req-1',
    sender: sampleUser,
    receiver: sampleTarget,
    status: FriendRequestStatus.pending,
    createdAt: DateTime.parse('2026-09-13T10:00:00Z'),
  );

  setUp(() {
    repository = MockSocialRepository();
    controller = FriendRequestsController(repository: repository);
  });

  Widget buildSubject() => MaterialApp(
        home: FriendRequestsScreen(controller: controller),
      );

  group('FriendRequestsScreen Widget Tests', () {
    testWidgets('1. loads received requests and renders items', (tester) async {
      repository.receivedResult = PagedResponse(
        items: [sampleRequest],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Alice Wonderland'), findsOneWidget);
      expect(find.text('@alice'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Chấp nhận'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Từ chối'), findsOneWidget);
    });

    testWidgets('2. renders empty state when received requests is empty', (tester) async {
      repository.receivedResult = const PagedResponse(
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
      expect(find.text('Không có lời mời kết bạn nào'), findsOneWidget);
    });

    testWidgets('3. renders error state and retries on button press', (tester) async {
      repository.errorToThrow = const SocialFailure(
        SocialFailureType.network,
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(SocialErrorView), findsOneWidget);
      expect(
        find.text('Không có kết nối mạng. Vui lòng kiểm tra lại đường truyền internet.'),
        findsOneWidget,
      );

      // Now clear error and retry
      repository.errorToThrow = null;
      repository.receivedResult = PagedResponse(
        items: [sampleRequest],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Thử lại'));
      await tester.pumpAndSettle();

      expect(find.text('Alice Wonderland'), findsOneWidget);
    });

    testWidgets('4. Accept button triggers controller action and shows SnackBar', (tester) async {
      repository.receivedResult = PagedResponse(
        items: [sampleRequest],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );
      repository.acceptResult = FriendRequest(
        id: 'req-1',
        sender: sampleUser,
        receiver: sampleTarget,
        status: FriendRequestStatus.accepted,
        createdAt: DateTime.parse('2026-09-13T10:00:00Z'),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Chấp nhận'));
      await tester.pump(); // Start action

      await tester.pumpAndSettle();

      expect(repository.acceptCalled, isTrue);
      expect(find.text('Đã kết bạn với Alice Wonderland'), findsOneWidget);
      // Item is removed from list
      expect(find.text('Alice Wonderland'), findsNothing);
    });

    testWidgets('5. Decline button triggers controller action and removes item', (tester) async {
      repository.receivedResult = PagedResponse(
        items: [sampleRequest],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Từ chối'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repository.declineCalled, isTrue);
      expect(find.text('Đã từ chối lời mời kết bạn.'), findsOneWidget);
      expect(find.text('Alice Wonderland'), findsNothing);
    });

    testWidgets('6. Sent request renders on second tab', (tester) async {
      repository.sentResult = PagedResponse(
        items: [sampleRequest],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Switch to 'Đã gửi' tab
      await tester.tap(find.text('Đã gửi'));
      await tester.pumpAndSettle();

      expect(find.text('Bob The Builder'), findsOneWidget);
      expect(find.text('@bob'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Hủy'), findsOneWidget);
    });

    testWidgets('7. Cancel button triggers controller action on sent request', (tester) async {
      repository.sentResult = PagedResponse(
        items: [sampleRequest],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đã gửi'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Hủy'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repository.cancelCalled, isTrue);
      expect(find.text('Đã hủy lời mời kết bạn.'), findsOneWidget);
      expect(find.text('Bob The Builder'), findsNothing);
    });

    testWidgets('8. Shows backend error code message on action failure', (tester) async {
      repository.receivedResult = PagedResponse(
        items: [sampleRequest],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );
      repository.actionErrorToThrow = const SocialFailure(
        SocialFailureType.userBlocked,
        backendCode: 'USER_BLOCKED',
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Chấp nhận'));
      await tester.pumpAndSettle();

      expect(
        find.text('Không thể tương tác vì người dùng đã bị chặn.'),
        findsOneWidget,
      );
    });
  });
}
