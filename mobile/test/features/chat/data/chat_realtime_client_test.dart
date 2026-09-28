import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/data/chat_realtime_client.dart';
import 'package:mobile/features/chat/data/chat_realtime_event.dart';

void main() {
  group('ChatRealtimeEvent.fromJson', () {
    test('parses MESSAGE_CREATED, READ_STATE_UPDATED, TYPING_UPDATED, PRESENCE_UPDATED', () {
      final created = ChatRealtimeEvent.fromJson({
        'type': 'MESSAGE_CREATED',
        'eventId': 'evt-1',
        'conversationId': 'conv-1',
        'sequence': 5,
        'occurredAt': '2026-09-28T04:00:00Z',
        'payload': {
          'clientMessageId': 'client-1',
          'message': {
            'id': 'msg-1',
            'sequence': 5,
            'status': 'ACTIVE',
            'content': 'Xin chào realtime',
            'isMine': false,
            'author': {
              'id': 'user-2',
              'displayName': 'Lan Anh',
              'avatarStorageKey': null,
            },
            'createdAt': '2026-09-28T04:00:00Z',
            'reactions': const [],
            'permissions': {
              'canSend': true,
              'canEdit': false,
              'canUnsend': false,
              'canDeleteForMe': true,
              'canReact': true,
              'canPin': false,
              'readOnly': false,
            },
          },
        },
      });
      expect(created.type, ChatRealtimeEventType.messageCreated);
      expect(created.eventId, 'evt-1');
      expect(created.conversationId, 'conv-1');
      expect(created.sequence, 5);
      expect(created.clientMessageId, 'client-1');
      expect(created.message?.id, 'msg-1');
      expect(created.message?.content, 'Xin chào realtime');
      expect(created.message?.author?.displayName, 'Lan Anh');

      final readEvt = ChatRealtimeEvent.fromJson({
        'type': 'READ_STATE_UPDATED',
        'eventId': 'evt-2',
        'conversationId': 'conv-1',
        'sequence': 5,
        'payload': {
          'user': {'id': 'user-3', 'displayName': 'Bình'},
          'lastReadSequence': 5,
        },
      });
      expect(readEvt.type, ChatRealtimeEventType.readStateUpdated);
      expect(readEvt.reader?.userId, 'user-3');
      expect(readEvt.lastReadSequence, 5);

      final typingEvt = ChatRealtimeEvent.fromJson({
        'type': 'TYPING_UPDATED',
        'eventId': 'evt-3',
        'conversationId': 'conv-1',
        'payload': {
          'user': {'id': 'user-2', 'displayName': 'Lan Anh'},
          'typing': true,
        },
      });
      expect(typingEvt.type, ChatRealtimeEventType.typingUpdated);
      expect(typingEvt.typingUser?.displayName, 'Lan Anh');
      expect(typingEvt.typing, isTrue);

      final presenceEvt = ChatRealtimeEvent.fromJson({
        'type': 'PRESENCE_UPDATED',
        'eventId': 'evt-4',
        'payload': {
          'user': {'id': 'user-2', 'displayName': 'Lan Anh'},
          'online': true,
        },
      });
      expect(presenceEvt.type, ChatRealtimeEventType.presenceUpdated);
      expect(presenceEvt.presenceUser?.id, 'user-2');
      expect(presenceEvt.online, isTrue);
    });
  });

  group('WebSocketChatRealtimeClient', () {
    test('builds ws URI with token, subscribes, emits frames, and sends typing', () async {
      final fakeSocket = _FakeRealtimeSocket();
      String? connectedUrl;
      final client = WebSocketChatRealtimeClient(
        baseUrl: 'http://127.0.0.1:8080',
        accessTokenProvider: () => 'jwt-token-123',
        connector: (url, headers) async {
          connectedUrl = url;
          return fakeSocket;
        },
      );

      final received = <ChatRealtimeEvent>[];
      final sub = client.events.listen(received.add);

      await client.connect();
      client.subscribeConversation('conv-99');
      expect(connectedUrl, startsWith('ws://127.0.0.1:8080/ws?access_token=jwt-token-123'));
      expect(
        fakeSocket.sentFrames.map(jsonDecode).toList(),
        contains(
          predicate<Map<String, dynamic>>(
            (frame) =>
                frame['type'] == 'SUBSCRIBE' &&
                frame['conversationId'] == 'conv-99',
          ),
        ),
      );

      fakeSocket.serverSide.add(
        jsonEncode({
          'type': 'CONNECTED',
          'eventId': 'evt-conn',
          'payload': {'sessionId': 's-1'},
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        received.any((e) => e.type == ChatRealtimeEventType.connected),
        isTrue,
      );

      client.sendTypingStart('conv-99');
      expect(
        fakeSocket.sentFrames.map(jsonDecode).toList(),
        contains(
          predicate<Map<String, dynamic>>(
            (frame) =>
                frame['type'] == 'TYPING_START' &&
                frame['conversationId'] == 'conv-99',
          ),
        ),
      );

      await sub.cancel();
      client.dispose();
    });
  });
}

class _FakeRealtimeSocket implements ChatRealtimeSocket {
  final StreamController<dynamic> serverSide =
      StreamController<dynamic>.broadcast();
  final List<String> sentFrames = <String>[];

  @override
  Stream<dynamic> get stream => serverSide.stream;

  @override
  void add(String data) {
    sentFrames.add(data);
  }

  @override
  Future<void> close() async {
    await serverSide.close();
  }
}
