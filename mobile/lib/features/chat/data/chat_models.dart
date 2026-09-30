class ChatUser {
  final String id;
  final String displayName;
  final String? avatarStorageKey;
  const ChatUser({
    required this.id,
    required this.displayName,
    this.avatarStorageKey,
  });
  factory ChatUser.fromJson(Map<String, dynamic> json) => ChatUser(
    id: json['id'] as String,
    displayName: (json['displayName'] as String?)?.trim().isNotEmpty == true
        ? json['displayName'] as String
        : 'Người dùng',
    avatarStorageKey: json['avatarStorageKey'] as String?,
  );
}

class ChatPermissions {
  final bool canSend,
      canEdit,
      canUnsend,
      canDeleteForMe,
      canReact,
      canPin,
      readOnly;
  const ChatPermissions({
    required this.canSend,
    required this.canEdit,
    required this.canUnsend,
    required this.canDeleteForMe,
    required this.canReact,
    required this.canPin,
    required this.readOnly,
  });
  factory ChatPermissions.fromJson(Map<String, dynamic> json) =>
      ChatPermissions(
        canSend: json['canSend'] == true,
        canEdit: json['canEdit'] == true,
        canUnsend: json['canUnsend'] == true,
        canDeleteForMe: json['canDeleteForMe'] == true,
        canReact: json['canReact'] == true,
        canPin: json['canPin'] == true,
        readOnly: json['readOnly'] == true,
      );
}

class ChatConversation {
  final String id, type, accessStatus;
  final String? groupId, title, avatarStorageKey, lastMessagePreview;
  final ChatUser? peer;
  final DateTime? lastMessageAt;
  final int lastSequence, unreadCount;
  final ChatPermissions permissions;
  const ChatConversation({
    required this.id,
    required this.type,
    required this.accessStatus,
    required this.lastSequence,
    required this.unreadCount,
    required this.permissions,
    this.groupId,
    this.title,
    this.avatarStorageKey,
    this.lastMessagePreview,
    this.peer,
    this.lastMessageAt,
  });
  factory ChatConversation.fromJson(Map<String, dynamic> json) =>
      ChatConversation(
        id: json['id'] as String,
        type: json['type'] as String,
        accessStatus: json['accessStatus'] as String? ?? 'OPEN',
        groupId: json['groupId'] as String?,
        title: json['title'] as String?,
        avatarStorageKey: json['avatarStorageKey'] as String?,
        peer: json['peer'] is Map
            ? ChatUser.fromJson(Map<String, dynamic>.from(json['peer'] as Map))
            : null,
        lastMessagePreview: json['lastMessagePreview'] as String?,
        lastMessageAt: DateTime.tryParse(
          json['lastMessageAt'] as String? ?? '',
        ),
        lastSequence: (json['lastSequence'] as num?)?.toInt() ?? 0,
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
        permissions: ChatPermissions.fromJson(
          Map<String, dynamic>.from(json['permissions'] as Map? ?? const {}),
        ),
      );
}

class ChatDirectOpen {
  final ChatConversation conversation;
  final String accessStatus;
  const ChatDirectOpen(this.conversation, this.accessStatus);
}

class ChatMessageRequest {
  final String id, conversationId, status;
  final ChatUser sender, receiver;
  final DateTime createdAt;
  final int messageCount;
  const ChatMessageRequest({
    required this.id,
    required this.conversationId,
    required this.status,
    required this.sender,
    required this.receiver,
    required this.createdAt,
    required this.messageCount,
  });
  factory ChatMessageRequest.fromJson(Map<String, dynamic> json) =>
      ChatMessageRequest(
        id: json['id'] as String,
        conversationId: json['conversationId'] as String,
        status: json['status'] as String,
        sender: ChatUser.fromJson(
          Map<String, dynamic>.from(json['sender'] as Map),
        ),
        receiver: ChatUser.fromJson(
          Map<String, dynamic>.from(json['receiver'] as Map),
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        messageCount: (json['messageCount'] as num).toInt(),
      );
}

class ChatReaction {
  final String emoji;
  final int count;
  final bool reactedByMe;
  const ChatReaction({
    required this.emoji,
    required this.count,
    required this.reactedByMe,
  });
  factory ChatReaction.fromJson(Map<String, dynamic> json) => ChatReaction(
    emoji: json['emoji'] as String,
    count: (json['count'] as num).toInt(),
    reactedByMe: json['reactedByMe'] == true,
  );
}

class ChatReactionDetail {
  final String userId, displayName, emoji;
  final String? avatarUrl;
  const ChatReactionDetail({
    required this.userId,
    required this.displayName,
    required this.emoji,
    this.avatarUrl,
  });

  factory ChatReactionDetail.fromJson(Map<String, dynamic> json) {
    final user = Map<String, dynamic>.from(json['user'] as Map);
    return ChatReactionDetail(
      userId: user['id'] as String,
      displayName: (user['displayName'] as String?)?.trim().isNotEmpty == true
          ? user['displayName'] as String
          : 'Người dùng',
      avatarUrl: user['avatarUrl'] as String?,
      emoji: json['emoji'] as String,
    );
  }
}

class ChatMessageAttachment {
  final String id;
  final String storageKey;
  final String? fileName;
  final String contentType;
  final int fileSizeBytes;
  final int sortOrder;

  const ChatMessageAttachment({
    required this.id,
    required this.storageKey,
    required this.contentType,
    required this.fileSizeBytes,
    required this.sortOrder,
    this.fileName,
  });

  factory ChatMessageAttachment.fromJson(Map<String, dynamic> json) =>
      ChatMessageAttachment(
        id: json['id'] as String,
        storageKey: json['storageKey'] as String,
        fileName: json['fileName'] as String?,
        contentType: json['contentType'] as String,
        fileSizeBytes: (json['fileSizeBytes'] as num).toInt(),
        sortOrder: (json['sortOrder'] as num).toInt(),
      );
}

class ChatMessage {
  final String id, status, type;
  final bool isMine;
  final int sequence;
  final ChatUser? author;
  final String? content, replyToMessageId, myReaction;
  final DateTime createdAt;
  final DateTime? editedAt, unsentAt;
  final List<ChatReaction> reactions;
  final List<ChatMessageAttachment> attachments;
  final ChatPermissions permissions;
  const ChatMessage({
    required this.id,
    required this.status,
    required this.isMine,
    required this.sequence,
    required this.createdAt,
    required this.reactions,
    this.type = 'TEXT',
    this.attachments = const [],
    required this.permissions,
    this.author,
    this.content,
    this.replyToMessageId,
    this.myReaction,
    this.editedAt,
    this.unsentAt,
  });
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    status: json['status'] as String,
    type:
        json['type'] as String? ??
        ((json['attachments'] as List?)?.isNotEmpty == true ? 'IMAGE' : 'TEXT'),
    sequence: (json['sequence'] as num).toInt(),
    isMine: json['isMine'] == true,
    author: json['author'] is Map
        ? ChatUser.fromJson(Map<String, dynamic>.from(json['author'] as Map))
        : null,
    content: json['content'] as String?,
    replyToMessageId: json['replyToMessageId'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    editedAt: DateTime.tryParse(json['editedAt'] as String? ?? ''),
    unsentAt: DateTime.tryParse(json['unsentAt'] as String? ?? ''),
    myReaction: json['myReaction'] as String?,
    reactions: ((json['reactions'] as List?) ?? const [])
        .map((e) => ChatReaction.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    attachments: ((json['attachments'] as List?) ?? const [])
        .map(
          (e) => ChatMessageAttachment.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList(),
    permissions: ChatPermissions.fromJson(
      Map<String, dynamic>.from(json['permissions'] as Map? ?? const {}),
    ),
  );
}

class ChatMessagePage {
  final String conversationId;
  final List<ChatMessage> messages;
  final List<ChatReaderState> readers;
  final int? nextBeforeSequence;
  final bool hasMore;
  const ChatMessagePage({
    required this.conversationId,
    required this.messages,
    required this.readers,
    required this.nextBeforeSequence,
    required this.hasMore,
  });
  factory ChatMessagePage.fromJson(Map<String, dynamic> json) =>
      ChatMessagePage(
        conversationId: json['conversationId'] as String,
        messages: ((json['messages'] as List?) ?? const [])
            .map(
              (e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
        readers: ((json['readers'] as List?) ?? const [])
            .map(
              (e) =>
                  ChatReaderState.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
        nextBeforeSequence: (json['nextBeforeSequence'] as num?)?.toInt(),
        hasMore: json['hasMore'] == true,
      );
}

class ChatReaderState {
  final String userId, displayName;
  final String? avatarStorageKey;
  final int lastReadSequence;
  const ChatReaderState({
    required this.userId,
    required this.displayName,
    required this.lastReadSequence,
    this.avatarStorageKey,
  });
  factory ChatReaderState.fromJson(Map<String, dynamic> json) =>
      ChatReaderState(
        userId: json['userId'] as String,
        displayName: (json['displayName'] as String?)?.trim().isNotEmpty == true
            ? json['displayName'] as String
            : 'Người dùng',
        avatarStorageKey: json['avatarStorageKey'] as String?,
        lastReadSequence: (json['lastReadSequence'] as num).toInt(),
      );
}
