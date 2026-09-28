import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/data/chat_api.dart';
import 'package:mobile/features/chat/data/chat_models.dart';

void main() {
  test('parses nullable direct/group fields and deleted messages safely', () {
    final group = ChatConversation.fromJson(_conversationJson());
    expect(group.groupId, 'group-1');
    expect(group.lastMessageAt, isNull);
    expect(group.avatarStorageKey, 'group-media/group-avatar.jpg');
    final deleted = ChatMessage.fromJson({
      'id': 'message-1',
      'sequence': 1,
      'isMine': true,
      'author': null,
      'content': null,
      'status': 'UNSENT',
      'replyToMessageId': null,
      'createdAt': '2026-09-27T00:00:00Z',
      'editedAt': null,
      'unsentAt': '2026-09-27T00:01:00Z',
      'myReaction': null,
      'reactions': [],
      'permissions': _permissions(),
    });
    expect(deleted.content, isNull);
    expect(deleted.author, isNull);
    expect(deleted.isMine, isTrue);
  });

  test('open group and send preserve IDs and typed payloads', () async {
    final adapter = _ChatAdapter();
    final api = ChatApi(
      Dio(BaseOptions(baseUrl: 'https://test'))..httpClientAdapter = adapter,
    );
    final conversation = await api.openGroup('group/one');
    expect(adapter.request.path, '/api/v1/groups/group%2Fone/conversation');
    expect(conversation.id, 'conversation-1');
    final sent = await api.send(conversation.id, 'Xin chào');
    expect(adapter.request.method, 'POST');
    expect(
      adapter.request.path,
      '/api/v1/conversations/conversation-1/messages',
    );
    expect(adapter.request.data, {
      'content': 'Xin chào',
      'replyToMessageId': null,
    });
    expect(sent.isMine, isTrue);
    final withdrawn = await api.unsend('message/one');
    expect(adapter.request.method, 'POST');
    expect(adapter.request.path, '/api/v1/messages/message%2Fone/unsend');
    expect(withdrawn.status, 'UNSENT');
  });
}

Map<String, dynamic> _permissions() => {
  'canSend': true,
  'canEdit': false,
  'canUnsend': false,
  'canDeleteForMe': true,
  'canReact': true,
  'canPin': false,
  'readOnly': false,
};
Map<String, dynamic> _conversationJson() => {
  'id': 'conversation-1',
  'type': 'GROUP',
  'groupId': 'group-1',
  'title': 'Nhóm A',
  'avatarStorageKey': 'group-media/group-avatar.jpg',
  'peer': null,
  'accessStatus': 'OPEN',
  'lastSequence': 0,
  'lastMessagePreview': null,
  'lastMessageAt': null,
  'unreadCount': 0,
  'permissions': _permissions(),
};

class _ChatAdapter implements HttpClientAdapter {
  late RequestOptions request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    final data = options.path.endsWith('/conversation')
        ? _conversationJson()
        : options.path.endsWith('/unsend')
        ? {
            'id': 'message-2',
            'conversationId': 'conversation-1',
            'sequence': 1,
            'isMine': true,
            'author': null,
            'content': null,
            'status': 'UNSENT',
            'replyToMessageId': null,
            'createdAt': '2026-09-27T00:00:00Z',
            'editedAt': null,
            'unsentAt': '2026-09-27T00:01:00Z',
            'myReaction': null,
            'reactions': [],
            'permissions': _permissions(),
          }
        : {
            'id': 'message-2',
            'conversationId': 'conversation-1',
            'sequence': 1,
            'isMine': true,
            'author': {
              'id': 'user-1',
              'displayName': 'An',
              'avatarStorageKey': null,
            },
            'content': 'Xin chào',
            'status': 'ACTIVE',
            'replyToMessageId': null,
            'createdAt': '2026-09-27T00:00:00Z',
            'editedAt': null,
            'unsentAt': null,
            'myReaction': null,
            'reactions': [],
            'permissions': _permissions(),
          };
    return ResponseBody.fromString(
      jsonEncode(data),
      options.path.endsWith('/messages') ? 201 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
