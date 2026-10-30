typedef Json = Map<String, dynamic>;

class MemoryAuthor {
  final String id, name;
  final String? avatar;
  const MemoryAuthor(this.id, this.name, this.avatar);
  factory MemoryAuthor.fromJson(Json j) => MemoryAuthor(
    j['id'] as String,
    j['displayName'] as String? ?? 'Người dùng',
    j['avatarStorageKey'] as String?,
  );
}

class MemoryMedia {
  final String id, type, name;
  final int size, order;
  bool get isVideo => type.startsWith('video/');
  const MemoryMedia(this.id, this.type, this.name, this.size, this.order);
  factory MemoryMedia.fromJson(Json j) => MemoryMedia(
    j['id'] as String,
    j['contentType'] as String,
    j['fileName'] as String,
    (j['fileSize'] as num).toInt(),
    (j['sortOrder'] as num).toInt(),
  );
}

class MemoryPermissions {
  final bool edit, delete, interact, manage;
  const MemoryPermissions(this.edit, this.delete, this.interact, this.manage);
  factory MemoryPermissions.fromJson(Json j) => MemoryPermissions(
    j['canEdit'] == true,
    j['canDelete'] == true,
    j['canInteract'] == true,
    j['canManage'] == true,
  );
}

class MomentPost {
  final String id, groupId, caption;
  final String? activityId, activityTitle, myReaction;
  final MemoryAuthor author;
  final DateTime createdAt;
  final List<MemoryMedia> media;
  final int reactions, comments;
  final MemoryPermissions permissions;
  const MomentPost(
    this.id,
    this.groupId,
    this.activityId,
    this.activityTitle,
    this.caption,
    this.author,
    this.createdAt,
    this.media,
    this.reactions,
    this.myReaction,
    this.comments,
    this.permissions,
  );
  factory MomentPost.fromJson(Json j) => MomentPost(
    j['id'] as String,
    j['groupId'] as String,
    j['activityId'] as String?,
    j['activityTitle'] as String?,
    j['caption'] as String,
    MemoryAuthor.fromJson(Map<String, dynamic>.from(j['author'] as Map)),
    DateTime.parse(j['createdAt'] as String),
    (j['media'] as List)
        .map((v) => MemoryMedia.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList(),
    (j['reactionCount'] as num).toInt(),
    j['myReaction'] as String?,
    (j['commentCount'] as num).toInt(),
    MemoryPermissions.fromJson(
      Map<String, dynamic>.from(j['permissions'] as Map),
    ),
  );
}

class MemoryComment {
  final String id, text;
  final MemoryAuthor author;
  final DateTime createdAt;
  final bool canDelete;
  const MemoryComment(
    this.id,
    this.text,
    this.author,
    this.createdAt,
    this.canDelete,
  );
  factory MemoryComment.fromJson(Json j) => MemoryComment(
    j['id'] as String,
    j['content'] as String,
    MemoryAuthor.fromJson(Map<String, dynamic>.from(j['author'] as Map)),
    DateTime.parse(j['createdAt'] as String),
    j['canDelete'] == true,
  );
}

class MemoryAlbum {
  final String id, groupId, name, description;
  final String? activityId, activityTitle;
  final MemoryAuthor author;
  final int count;
  final MemoryMedia? cover;
  final MemoryPermissions permissions;
  const MemoryAlbum(
    this.id,
    this.groupId,
    this.name,
    this.description,
    this.activityId,
    this.activityTitle,
    this.author,
    this.count,
    this.cover,
    this.permissions,
  );
  factory MemoryAlbum.fromJson(Json j) => MemoryAlbum(
    j['id'] as String,
    j['groupId'] as String,
    j['name'] as String,
    j['description'] as String,
    j['activityId'] as String?,
    j['activityTitle'] as String?,
    MemoryAuthor.fromJson(Map<String, dynamic>.from(j['author'] as Map)),
    (j['itemCount'] as num).toInt(),
    j['cover'] == null
        ? null
        : MemoryMedia.fromJson(Map<String, dynamic>.from(j['cover'] as Map)),
    MemoryPermissions.fromJson(
      Map<String, dynamic>.from(j['permissions'] as Map),
    ),
  );
}

class MemoryPage<T> {
  final bool canCreate;
  final List<T> items;
  final String? next;
  final bool hasMore;
  const MemoryPage(
    this.items,
    this.next,
    this.hasMore, [
    this.canCreate = false,
  ]);
  factory MemoryPage.fromJson(Json j, T Function(Json) parse) => MemoryPage(
    (j['items'] as List)
        .map((v) => parse(Map<String, dynamic>.from(v as Map)))
        .toList(),
    j['nextBefore'] as String?,
    j['hasMore'] == true,
    j['canCreate'] == true,
  );
}
