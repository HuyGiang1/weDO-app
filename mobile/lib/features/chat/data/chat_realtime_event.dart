import 'chat_models.dart';

enum ChatRealtimeConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

enum ChatRealtimeEventType {
  connected,
  subscribed,
  unsubscribed,
  messageCreated,
  messageEdited,
  messageUnsent,
  messageReactionUpdated,
  readStateUpdated,
  messagePinned,
  messageUnpinned,
  typingUpdated,
  presenceUpdated,
  pong,
  error,
  unknown,
}

class ChatRealtimeEvent {
  final String? eventId;
  final ChatRealtimeEventType type;
  final String rawType;
  final String? eventAlias;
  final String? conversationId;
  final String? messageId;
  final int? sequence;
  final String? clientMessageId;
  final ChatUser? actor;
  final ChatMessage? message;
  final ChatReaderState? reader;
  final bool? typing;
  final bool? online;
  final List<String> onlineUserIds;
  final String? errorCode;
  final String? errorMessage;
  final DateTime? occurredAt;

  const ChatRealtimeEvent({
    required this.type,
    required this.rawType,
    this.eventId,
    this.eventAlias,
    this.conversationId,
    this.messageId,
    this.sequence,
    this.clientMessageId,
    this.actor,
    this.message,
    this.reader,
    this.typing,
    this.online,
    this.onlineUserIds = const [],
    this.errorCode,
    this.errorMessage,
    this.occurredAt,
  });

  ChatUser? get presenceUser => actor;
  ChatUser? get typingUser => actor;
  int? get lastReadSequence => reader?.lastReadSequence ?? sequence;

  factory ChatRealtimeEvent.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] is Map
        ? Map<String, dynamic>.from(json['payload'] as Map)
        : const <String, dynamic>{};
    final rawType = (json['type'] as String? ?? '').trim().toUpperCase();
    final alias = (json['eventAlias'] as String?)?.trim().toUpperCase();
    final effectiveType = _parseType(rawType, alias);

    bool? typingFlag =
        (json['typing'] as bool?) ?? (payload['typing'] as bool?);
    if (typingFlag == null) {
      if (rawType == 'USER_TYPING' || alias == 'USER_TYPING') {
        typingFlag = true;
      } else if (rawType == 'USER_STOPPED_TYPING' ||
          alias == 'USER_STOPPED_TYPING') {
        typingFlag = false;
      }
    }

    final actorRaw = json['actor'] ?? payload['actor'] ?? payload['user'];
    final messageRaw = json['message'] ?? payload['message'];
    final readerRaw = json['reader'] ?? payload['reader'];
    final parsedActor = actorRaw is Map
        ? ChatUser.fromJson(Map<String, dynamic>.from(actorRaw))
        : null;
    final parsedSeq =
        (json['sequence'] as num?)?.toInt() ??
        (payload['lastReadSequence'] as num?)?.toInt() ??
        (payload['sequence'] as num?)?.toInt();
    ChatReaderState? parsedReader;
    if (readerRaw is Map) {
      parsedReader = ChatReaderState.fromJson(
        Map<String, dynamic>.from(readerRaw),
      );
    } else if (effectiveType == ChatRealtimeEventType.readStateUpdated &&
        parsedActor != null &&
        parsedSeq != null) {
      parsedReader = ChatReaderState(
        userId: parsedActor.id,
        displayName: parsedActor.displayName,
        avatarStorageKey: parsedActor.avatarStorageKey,
        lastReadSequence: parsedSeq,
      );
    }

    return ChatRealtimeEvent(
      eventId: json['eventId'] as String?,
      type: effectiveType,
      rawType: rawType,
      eventAlias: alias,
      conversationId:
          (json['conversationId'] as String?) ??
          (payload['conversationId'] as String?),
      messageId:
          (json['messageId'] as String?) ?? (payload['messageId'] as String?),
      sequence: parsedSeq,
      clientMessageId:
          (json['clientMessageId'] as String?) ??
          (payload['clientMessageId'] as String?),
      actor: parsedActor,
      message: messageRaw is Map
          ? ChatMessage.fromJson(Map<String, dynamic>.from(messageRaw))
          : null,
      reader: parsedReader,
      typing: typingFlag,
      online: (json['online'] as bool?) ?? (payload['online'] as bool?),
      onlineUserIds:
          ((json['onlineUserIds'] as List?) ??
                  (payload['onlineUserIds'] as List?) ??
                  const [])
              .map((e) => e.toString())
              .toList(growable: false),
      errorCode:
          (json['errorCode'] as String?) ?? (payload['errorCode'] as String?),
      errorMessage:
          (json['errorMessage'] as String?) ??
          (payload['errorMessage'] as String?),
      occurredAt: DateTime.tryParse(json['occurredAt'] as String? ?? ''),
    );
  }

  static ChatRealtimeEventType _parseType(String rawType, String? alias) {
    return switch (rawType) {
      'CONNECTED' ||
      'CONNECTION_ESTABLISHED' => ChatRealtimeEventType.connected,
      'SUBSCRIBED' => ChatRealtimeEventType.subscribed,
      'UNSUBSCRIBED' => ChatRealtimeEventType.unsubscribed,
      'MESSAGE_CREATED' => ChatRealtimeEventType.messageCreated,
      'MESSAGE_EDITED' => ChatRealtimeEventType.messageEdited,
      'MESSAGE_UNSENT' => ChatRealtimeEventType.messageUnsent,
      'MESSAGE_REACTION_UPDATED' ||
      'REACTION_UPDATED' => ChatRealtimeEventType.messageReactionUpdated,
      'READ_STATE_UPDATED' ||
      'MESSAGE_READ' => ChatRealtimeEventType.readStateUpdated,
      'MESSAGE_PINNED' => ChatRealtimeEventType.messagePinned,
      'MESSAGE_UNPINNED' => ChatRealtimeEventType.messageUnpinned,
      'TYPING_UPDATED' ||
      'USER_TYPING' ||
      'USER_STOPPED_TYPING' => ChatRealtimeEventType.typingUpdated,
      'PRESENCE_UPDATED' ||
      'PRESENCE_CHANGED' => ChatRealtimeEventType.presenceUpdated,
      'PONG' => ChatRealtimeEventType.pong,
      'ERROR' => ChatRealtimeEventType.error,
      _ => switch (alias) {
        'REACTION_UPDATED' => ChatRealtimeEventType.messageReactionUpdated,
        'MESSAGE_READ' => ChatRealtimeEventType.readStateUpdated,
        'USER_TYPING' ||
        'USER_STOPPED_TYPING' => ChatRealtimeEventType.typingUpdated,
        'PRESENCE_CHANGED' => ChatRealtimeEventType.presenceUpdated,
        _ => ChatRealtimeEventType.unknown,
      },
    };
  }
}
