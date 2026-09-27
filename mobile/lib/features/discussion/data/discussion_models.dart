class CommentPermissions {
  final bool canComment, canReply, canEdit, canDelete, canModerate, readOnly;
  const CommentPermissions({
    required this.canComment,
    required this.canReply,
    required this.canEdit,
    required this.canDelete,
    required this.canModerate,
    required this.readOnly,
  });
  factory CommentPermissions.fromJson(Map<String, dynamic>? j) =>
      CommentPermissions(
        canComment: j?['canComment'] as bool? ?? false,
        canReply: j?['canReply'] as bool? ?? false,
        canEdit: j?['canEdit'] as bool? ?? false,
        canDelete: j?['canDelete'] as bool? ?? false,
        canModerate: j?['canModerate'] as bool? ?? false,
        readOnly: j?['readOnly'] as bool? ?? true,
      );
}

class DiscussionPermissions {
  final bool canComment, canReply, readOnly;
  const DiscussionPermissions({
    required this.canComment,
    required this.canReply,
    required this.readOnly,
  });
  factory DiscussionPermissions.fromJson(Map<String, dynamic> j) =>
      DiscussionPermissions(
        canComment: j['canComment'] as bool? ?? false,
        canReply: j['canReply'] as bool? ?? false,
        readOnly: j['readOnly'] as bool? ?? true,
      );
}

class ActivityDiscussion {
  final DiscussionPermissions permissions;
  final List<ActivityComment> comments;
  const ActivityDiscussion({required this.permissions, required this.comments});
  factory ActivityDiscussion.fromJson(Map<String, dynamic> j) =>
      ActivityDiscussion(
        permissions: DiscussionPermissions.fromJson(
          Map<String, dynamic>.from(j['permissions'] as Map),
        ),
        comments: (j['comments'] as List? ?? const [])
            .map(
              (e) =>
                  ActivityComment.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
      );
}

class ActivityComment {
  final String id;
  final String activityId;
  final String authorId;
  final DiscussionAuthor? author;
  final String? parentCommentId;
  final String content;
  final bool edited;
  final DateTime? editedAt;
  final bool deleted;
  final DateTime? deletedAt;
  final String? deletedBy;
  final DateTime createdAt;
  final CommentPermissions permissions;

  const ActivityComment({
    required this.id,
    required this.activityId,
    required this.authorId,
    required this.author,
    required this.parentCommentId,
    required this.content,
    required this.edited,
    required this.editedAt,
    required this.deleted,
    required this.deletedAt,
    required this.deletedBy,
    required this.createdAt,
    required this.permissions,
  });
  factory ActivityComment.fromJson(Map<String, dynamic> json) =>
      ActivityComment(
        id: json['id'] as String,
        activityId: json['activityId'] as String,
        authorId: json['authorId'] as String,
        author: json['author'] is Map
            ? DiscussionAuthor.fromJson(
                Map<String, dynamic>.from(json['author'] as Map),
              )
            : null,
        parentCommentId: json['parentCommentId'] as String?,
        content: json['content'] as String,
        edited: json['edited'] as bool? ?? false,
        editedAt: json['editedAt'] == null
            ? null
            : DateTime.parse(json['editedAt'] as String),
        deleted: json['deleted'] as bool? ?? false,
        deletedAt: json['deletedAt'] == null
            ? null
            : DateTime.parse(json['deletedAt'] as String),
        deletedBy: json['deletedBy'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        permissions: CommentPermissions.fromJson(
          json['permissions'] is Map
              ? Map<String, dynamic>.from(json['permissions'] as Map)
              : null,
        ),
      );
}

class DiscussionAuthor {
  final String id;
  final String? username;
  final String? displayName;
  final String? avatarStorageKey;

  const DiscussionAuthor({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarStorageKey,
  });

  factory DiscussionAuthor.fromJson(Map<String, dynamic> json) =>
      DiscussionAuthor(
        id: json['id'] as String,
        username: json['username'] as String?,
        displayName: json['displayName'] as String?,
        avatarStorageKey: json['avatarStorageKey'] as String?,
      );

  String get name {
    final preferred = displayName?.trim();
    if (preferred != null && preferred.isNotEmpty) return preferred;
    final handle = username?.trim();
    if (handle != null && handle.isNotEmpty) return handle;
    return 'Member';
  }
}
