import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/discussion/data/discussion_models.dart';

void main() {
  test('ActivityComment preserves reply and soft-delete state', () {
    final comment = ActivityComment.fromJson({
      'id': 'comment-2',
      'activityId': 'activity-1',
      'authorId': 'user-1',
      'author': {
        'id': 'user-1',
        'username': 'lan',
        'displayName': 'Lan Nguyen',
        'avatarStorageKey': 'avatars/lan.png',
      },
      'parentCommentId': 'comment-1',
      'content': 'I can bring it.',
      'edited': true,
      'editedAt': '2026-09-30T10:00:00Z',
      'deleted': false,
      'deletedAt': null,
      'deletedBy': null,
      'createdAt': '2026-09-29T10:00:00Z',
      'permissions': {
        'canComment': true,
        'canReply': false,
        'canEdit': true,
        'canDelete': true,
        'canModerate': false,
        'readOnly': false,
      },
    });
    expect(comment.parentCommentId, 'comment-1');
    expect(comment.edited, isTrue);
    expect(comment.deleted, isFalse);
    expect(comment.permissions.canEdit, isTrue);
    expect(comment.permissions.canReply, isFalse);
    expect(comment.author?.name, 'Lan Nguyen');
    expect(comment.author?.avatarStorageKey, 'avatars/lan.png');
  });

  test('ActivityComment retains each reply author independently', () {
    final firstReply = ActivityComment.fromJson(_commentJson(
      id: 'reply-1',
      authorId: 'user-2',
      displayName: 'Minh Tran',
    ));
    final secondReply = ActivityComment.fromJson(_commentJson(
      id: 'reply-2',
      authorId: 'user-3',
      displayName: 'Hoa Le',
    ));

    expect(firstReply.author?.name, 'Minh Tran');
    expect(secondReply.author?.name, 'Hoa Le');
    expect(firstReply.author?.id, isNot(secondReply.author?.id));
  });

  test('ActivityDiscussion keeps writable state when it has zero comments', () {
    final discussion = ActivityDiscussion.fromJson({
      'permissions': {'canComment': true, 'canReply': true, 'readOnly': false},
      'comments': [],
    });
    expect(discussion.comments, isEmpty);
    expect(discussion.permissions.canComment, isTrue);
    expect(discussion.permissions.readOnly, isFalse);
  });

  test(
    'ActivityDiscussion parses read-only state independently of comments',
    () {
      final discussion = ActivityDiscussion.fromJson({
        'permissions': {
          'canComment': false,
          'canReply': false,
          'readOnly': true,
        },
        'comments': [],
      });
      expect(discussion.comments, isEmpty);
      expect(discussion.permissions.canComment, isFalse);
      expect(discussion.permissions.readOnly, isTrue);
    },
  );
}

Map<String, dynamic> _commentJson({
  required String id,
  required String authorId,
  required String displayName,
}) => {
  'id': id,
  'activityId': 'activity-1',
  'authorId': authorId,
  'author': {
    'id': authorId,
    'username': displayName.toLowerCase().replaceAll(' ', '.'),
    'displayName': displayName,
    'avatarStorageKey': null,
  },
  'parentCommentId': 'comment-1',
  'content': 'Reply',
  'edited': false,
  'deleted': false,
  'createdAt': '2026-09-29T10:00:00Z',
  'permissions': const {
    'canComment': false,
    'canReply': false,
    'canEdit': false,
    'canDelete': false,
    'canModerate': false,
    'readOnly': true,
  },
};
