import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/social/data/social_failure.dart';
import 'package:mobile/features/social/presentation/utils/social_error_localizer.dart';
import 'package:mobile/features/social/presentation/widgets/social_confirmation_dialog.dart';
import 'package:mobile/features/social/presentation/widgets/social_empty_state.dart';
import 'package:mobile/features/social/presentation/widgets/social_error_view.dart';
import 'package:mobile/features/social/presentation/widgets/user_avatar.dart';

void main() {
  group('SocialErrorLocalizer Tests', () {
    test('20. maps backend error codes to Vietnamese user-friendly messages', () {
      expect(
        SocialErrorLocalizer.localize(
          const SocialFailure(SocialFailureType.cannotFriendSelf),
        ),
        'Không thể gửi lời mời kết bạn cho chính mình.',
      );

      expect(
        SocialErrorLocalizer.localize(
          const SocialFailure(SocialFailureType.alreadyFriends),
        ),
        'Hai bạn đã là bạn bè.',
      );

      expect(
        SocialErrorLocalizer.localize(
          const SocialFailure(SocialFailureType.friendRequestAlreadyPending),
        ),
        'Lời mời kết bạn đã được gửi và đang chờ phản hồi.',
      );

      expect(
        SocialErrorLocalizer.localize(
          const SocialFailure(SocialFailureType.friendRequestCooldownActive),
        ),
        'Vui lòng đợi trước khi gửi lại lời mời kết bạn (thời gian chờ 24 giờ).',
      );

      expect(
        SocialErrorLocalizer.localize(
          const SocialFailure(SocialFailureType.userBlocked),
        ),
        'Không thể tương tác vì người dùng đã bị chặn.',
      );

      expect(
        SocialErrorLocalizer.localize(
          const SocialFailure(SocialFailureType.cannotBlockSelf),
        ),
        'Không thể chặn chính mình.',
      );

      expect(
        SocialErrorLocalizer.localize(
          const SocialFailure(SocialFailureType.accessDenied),
        ),
        'Bạn không có quyền thực hiện hành động này.',
      );

      expect(
        SocialErrorLocalizer.localize(
          const SocialFailure(SocialFailureType.network),
        ),
        'Không có kết nối mạng. Vui lòng kiểm tra lại đường truyền internet.',
      );

      expect(
        SocialErrorLocalizer.localize(
          const SocialFailure(SocialFailureType.timeout),
        ),
        'Hết thời gian kết nối đến máy chủ. Vui lòng thử lại sau.',
      );
    });
  });

  group('Social Widgets Tests', () {
    testWidgets('UserAvatar displays initials when no image is loaded', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(displayName: 'John Doe'),
          ),
        ),
      );

      expect(find.text('JD'), findsOneWidget);
    });

    testWidgets('SocialEmptyState displays title and subtitle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SocialEmptyState(
              icon: Icons.inbox,
              title: 'Trống rỗng',
              subtitle: 'Không có dữ liệu',
            ),
          ),
        ),
      );

      expect(find.text('Trống rỗng'), findsOneWidget);
      expect(find.text('Không có dữ liệu'), findsOneWidget);
      expect(find.byIcon(Icons.inbox), findsOneWidget);
    });

    testWidgets('SocialErrorView displays message and triggers retry', (tester) async {
      bool retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocialErrorView(
              message: 'Lỗi máy chủ',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Lỗi máy chủ'), findsOneWidget);
      await tester.tap(find.text('Thử lại'));
      expect(retried, isTrue);
    });

    testWidgets('SocialConfirmationDialog returns true on confirm, false on cancel',
        (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await SocialConfirmationDialog.show(
                    context,
                    title: 'Xác nhận xóa',
                    message: 'Bạn có chắc chắn?',
                    confirmLabel: 'Xóa ngay',
                    isDestructive: true,
                  );
                },
                child: const Text('Mở hộp thoại'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở hộp thoại'));
      await tester.pumpAndSettle();

      expect(find.text('Xác nhận xóa'), findsOneWidget);
      expect(find.text('Bạn có chắc chắn?'), findsOneWidget);

      // Cancel
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      // Re-open and Confirm
      await tester.tap(find.text('Mở hộp thoại'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa ngay'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });
}
