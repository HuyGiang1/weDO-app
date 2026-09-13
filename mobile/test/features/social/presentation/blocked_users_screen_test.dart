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
import 'package:mobile/features/social/presentation/screens/blocked_users_screen.dart';
import 'package:mobile/features/social/presentation/widgets/social_empty_state.dart';
import 'package:mobile/features/social/presentation/widgets/social_error_view.dart';

class MockSocialRepository extends SocialRepository {
  MockSocialRepository() : super(api: SocialApi(Dio()));

  PagedResponse<BlockedUser>? blockedResult;
  SocialFailure? errorToThrow;
  SocialFailure? actionErrorToThrow;

  bool unblockCalled = false;
  String? unblockUserId;

  @override
  Future<PagedResponse<BlockedUser>> getBlockedUsers({
    int page = 0,
    int size = 30,
  }) async {
    if (errorToThrow != null) throw SocialException(errorToThrow!);
    return blockedResult ??
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
  Future<void> unblockUser(String userId) async {
    unblockCalled = true;
    unblockUserId = userId;
    if (actionErrorToThrow != null) throw SocialException(actionErrorToThrow!);
  }
}

void main() {
  late MockSocialRepository repository;
  late BlockedUsersController controller;

  final sampleBlocked = BlockedUser(
    blockId: 'b-1',
    blockedUser: const SocialUserSummary(
      id: 'user-3',
      username: 'charlie',
      displayName: 'Charlie Brown',
    ),
    createdAt: DateTime.parse('2026-09-13T10:00:00Z'),
  );

  setUp(() {
    repository = MockSocialRepository();
    controller = BlockedUsersController(repository: repository);
  });

  Widget buildSubject() => MaterialApp(
        home: BlockedUsersScreen(
          controller: controller,
        ),
      );

  group('BlockedUsersScreen Widget Tests', () {
    testWidgets('13. Blocked users list renders correctly', (tester) async {
      repository.blockedResult = PagedResponse(
        items: [sampleBlocked],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Người dùng đã chặn'), findsOneWidget);
      expect(find.text('Charlie Brown'), findsOneWidget);
      expect(find.text('@charlie'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Bỏ chặn'), findsOneWidget);
    });

    testWidgets('14. Blocked users empty state renders when list is empty', (tester) async {
      repository.blockedResult = const PagedResponse(
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
      expect(find.text('Không có người dùng bị chặn'), findsOneWidget);
    });

    testWidgets('Renders error state and retries on press', (tester) async {
      repository.errorToThrow = const SocialFailure(
        SocialFailureType.network,
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(SocialErrorView), findsOneWidget);

      repository.errorToThrow = null;
      repository.blockedResult = PagedResponse(
        items: [sampleBlocked],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Thử lại'));
      await tester.pumpAndSettle();

      expect(find.text('Charlie Brown'), findsOneWidget);
    });

    testWidgets('15. Unblock confirmation dialog is displayed', (tester) async {
      repository.blockedResult = PagedResponse(
        items: [sampleBlocked],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Bỏ chặn'));
      await tester.pumpAndSettle();

      expect(find.text('Bỏ chặn người dùng'), findsOneWidget);
      expect(find.text('Bạn có chắc muốn bỏ chặn Charlie Brown?'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Hủy'), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
      await tester.pumpAndSettle();

      expect(repository.unblockCalled, isFalse);
      expect(find.text('Charlie Brown'), findsOneWidget);
    });

    testWidgets('16. Unblock confirmation triggers unblock and removes item on success',
        (tester) async {
      repository.blockedResult = PagedResponse(
        items: [sampleBlocked],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Bỏ chặn'));
      await tester.pumpAndSettle();

      // Tap confirm button in dialog (TextButton with 'Bỏ chặn')
      await tester.tap(find.widgetWithText(TextButton, 'Bỏ chặn'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repository.unblockCalled, isTrue);
      expect(repository.unblockUserId, equals('user-3'));
      expect(find.text('Đã bỏ chặn Charlie Brown.'), findsOneWidget);
      expect(find.text('Charlie Brown'), findsNothing);
    });

    testWidgets('Unblock error shows localized error SnackBar', (tester) async {
      repository.blockedResult = PagedResponse(
        items: [sampleBlocked],
        page: 0,
        size: 30,
        totalElements: 1,
        totalPages: 1,
        hasNext: false,
      );
      repository.actionErrorToThrow = const SocialFailure(
        SocialFailureType.resourceNotFound,
        backendCode: 'RESOURCE_NOT_FOUND',
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Bỏ chặn'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Bỏ chặn'));
      await tester.pumpAndSettle();

      expect(
        find.text('Người dùng không tồn tại hoặc tài khoản đã bị vô hiệu hóa.'),
        findsOneWidget,
      );
      expect(find.text('Charlie Brown'), findsOneWidget);
    });

    testWidgets('Pagination loading indicator renders when hasNext is true', (tester) async {
      repository.blockedResult = PagedResponse(
        items: [sampleBlocked],
        page: 0,
        size: 1,
        totalElements: 2,
        totalPages: 2,
        hasNext: true,
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Charlie Brown'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Pagination error state renders retry button on errorMore', (tester) async {
      repository.blockedResult = PagedResponse(
        items: [sampleBlocked],
        page: 0,
        size: 1,
        totalElements: 2,
        totalPages: 2,
        hasNext: true,
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      controller.blockedUsers.value = controller.blockedUsers.value.copyWith(
        status: SocialListStatus.errorMore,
        failure: const SocialFailure(SocialFailureType.network),
      );
      await tester.pump();

      expect(find.text('Tải thêm thất bại. Thử lại'), findsOneWidget);
    });
  });
}
