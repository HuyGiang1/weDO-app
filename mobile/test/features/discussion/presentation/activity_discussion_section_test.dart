import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/discussion/data/discussion_models.dart';
import 'package:mobile/features/discussion/presentation/widgets/activity_discussion_section.dart';

void main() {
  for (final edit in [false, true]) {
    for (final delete in [false, true]) {
      testWidgets(
        'reply actions follow edit=$edit delete=$delete projections',
        (tester) async {
          var edited = false;
          var deleted = false;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: DiscussionCommentTile(
                  comment: _comment(
                    id: 'parent',
                    authorId: 'parent-author',
                    displayName: 'Parent',
                  ),
                  replies: [
                    _comment(
                      id: 'reply',
                      authorId: 'author',
                      displayName: 'Reply author',
                      permissions: CommentPermissions(
                        canComment: true,
                        canReply: false,
                        canEdit: edit,
                        canDelete: delete,
                        canModerate: delete && !edit,
                        readOnly: false,
                      ),
                    ),
                  ],
                  onReply: null,
                  onEdit: null,
                  onDelete: null,
                  onEditReply: (_) => edited = true,
                  onDeleteReply: (_) => deleted = true,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Phản hồi'), findsNothing);
          if (edit || delete) {
            await tester.tap(find.byType(PopupMenuButton<String>));
            await tester.pumpAndSettle();
            expect(
              find.text('Chỉnh sửa'),
              edit ? findsOneWidget : findsNothing,
            );
            expect(find.text('Xóa'), delete ? findsOneWidget : findsNothing);
            await tester.tap(find.text(edit ? 'Chỉnh sửa' : 'Xóa'));
            await tester.pumpAndSettle();
            expect(edited, edit);
            expect(deleted, !edit && delete);
          } else {
            expect(find.byType(PopupMenuButton<String>), findsNothing);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('renders author identities for a comment and distinct replies', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiscussionCommentTile(
            comment: _comment(
              id: 'parent',
              authorId: 'lan',
              displayName: 'Lan Nguyen',
            ),
            replies: [
              _comment(
                id: 'reply-1',
                authorId: 'minh',
                displayName: 'Minh Tran',
              ),
              _comment(id: 'reply-2', authorId: 'hoa', displayName: 'Hoa Le'),
            ],
            onReply: null,
            onEdit: null,
            onDelete: null,
          ),
        ),
      ),
    );

    expect(find.text('Lan Nguyen'), findsOneWidget);
    expect(find.text('Minh Tran'), findsOneWidget);
    expect(find.text('Hoa Le'), findsOneWidget);
    expect(find.text('Thành viên'), findsNothing);
  });

  testWidgets(
    'uses the neutral initial avatar fallback without an avatar key',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiscussionCommentTile(
              comment: _comment(
                id: 'parent',
                authorId: 'lan',
                displayName: 'Lan Nguyen',
              ),
              replies: const [],
              onReply: null,
              onEdit: null,
              onDelete: null,
            ),
          ),
        ),
      );

      expect(find.text('LN'), findsOneWidget);
    },
  );
}

ActivityComment _comment({
  required String id,
  required String authorId,
  required String displayName,
  CommentPermissions? permissions,
}) => ActivityComment(
  id: id,
  activityId: 'activity-1',
  authorId: authorId,
  author: DiscussionAuthor(
    id: authorId,
    username: displayName.toLowerCase().replaceAll(' ', '.'),
    displayName: displayName,
    avatarStorageKey: null,
  ),
  parentCommentId: id == 'parent' ? null : 'parent',
  content: 'Comment $id',
  edited: false,
  editedAt: null,
  deleted: false,
  deletedAt: null,
  deletedBy: null,
  createdAt: DateTime.utc(2026, 9, 26, 10),
  permissions:
      permissions ??
      const CommentPermissions(
        canComment: false,
        canReply: false,
        canEdit: false,
        canDelete: false,
        canModerate: false,
        readOnly: true,
      ),
);
