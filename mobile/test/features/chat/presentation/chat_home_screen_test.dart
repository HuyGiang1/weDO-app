import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/data/chat_api.dart';
import 'package:mobile/features/chat/data/chat_models.dart';
import 'package:mobile/features/chat/data/chat_realtime_client.dart';
import 'package:mobile/features/chat/data/chat_realtime_event.dart';
import 'package:mobile/features/chat/data/chat_repository.dart';
import 'package:mobile/features/chat/presentation/chat_home_screen.dart';
import 'package:mobile/features/groups/presentation/widgets/group_widgets.dart';

void main() {
  testWidgets('Chat Home lists empty group and opens its exact conversation', (
    tester,
  ) async {
    final adapter = _ConversationAdapter();
    final repository = ChatRepository(
      ChatApi(
        Dio(BaseOptions(baseUrl: 'https://test'))..httpClientAdapter = adapter,
      ),
    );
    ChatConversation? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: ChatHomeScreen(
          repository: repository,
          onGroups: () {},
          onOpenConversation: (conversation) => selected = conversation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Badminton'), findsOneWidget);
    expect(find.text('Chưa có tin nhắn'), findsOneWidget);
    await tester.tap(find.text('Badminton'));
    final avatar = tester.widget<GroupAvatar>(find.byType(GroupAvatar));
    expect(avatar.avatarStorageKey, 'avatars/canonical-group.png');
    expect(
      avatar.resolvedUrl,
      'http://localhost:8080/api/v1/media/avatars/canonical-group.png',
    );
    expect(find.text('avatars/canonical-group.png'), findsNothing);
    expect(selected?.id, 'conversation-exact');
    expect(selected?.groupId, 'group-exact');
    expect(selected?.avatarStorageKey, 'avatars/canonical-group.png');
  });

  testWidgets('group avatar falls back to the group-name initial', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupAvatar(name: 'Paddle Club', avatarStorageKey: null),
        ),
      ),
    );
    expect(find.text('P'), findsOneWidget);
  });

  testWidgets('realtime chat refresh replaces conversations synchronously', (
    tester,
  ) async {
    final realtime = _FakeRealtimeClient();
    final repository = ChatRepository(
      ChatApi(
        Dio(BaseOptions(baseUrl: 'https://test'))
          ..httpClientAdapter = _ConversationAdapter(),
      ),
      realtimeClient: realtime,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChatHomeScreen(
          repository: repository,
          onGroups: () {},
          onOpenConversation: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    realtime.emit(
      const ChatRealtimeEvent(
        type: ChatRealtimeEventType.messageCreated,
        rawType: 'MESSAGE_CREATED',
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Badminton'), findsOneWidget);
  });
}

class _FakeRealtimeClient implements ChatRealtimeClient {
  final StreamController<ChatRealtimeEvent> _events =
      StreamController<ChatRealtimeEvent>.broadcast();

  void emit(ChatRealtimeEvent event) => _events.add(event);

  @override
  Stream<ChatRealtimeEvent> get events => _events.stream;

  @override
  Stream<ChatRealtimeConnectionState> get connectionStates =>
      const Stream.empty();

  @override
  ChatRealtimeConnectionState get currentState =>
      ChatRealtimeConnectionState.connected;

  @override
  Set<String> get subscribedConversationIds => const {};

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  void subscribeConversation(String conversationId) {}

  @override
  void unsubscribeConversation(String conversationId) {}

  @override
  void sendTypingStart(String conversationId) {}

  @override
  void sendTypingStop(String conversationId) {}

  @override
  void sendMarkRead(String conversationId, int lastReadSequence) {}

  @override
  void dispose() => _events.close();
}

class _ConversationAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode([
      {
        'id': 'conversation-exact',
        'type': 'GROUP',
        'groupId': 'group-exact',
        'title': 'Badminton',
        'avatarStorageKey': 'avatars/canonical-group.png',
        'peer': null,
        'accessStatus': 'OPEN',
        'lastSequence': 0,
        'lastMessagePreview': null,
        'lastMessageAt': null,
        'unreadCount': 0,
        'permissions': _permissions,
      },
    ]),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

const _permissions = {
  'canSend': true,
  'canEdit': false,
  'canUnsend': false,
  'canDeleteForMe': false,
  'canReact': false,
  'canPin': false,
  'readOnly': false,
};
