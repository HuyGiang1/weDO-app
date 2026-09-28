import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/routes.dart';
import 'package:mobile/features/auth/application/auth_session_controller.dart';
import 'package:mobile/features/chat/data/chat_api.dart';
import 'package:mobile/features/chat/data/chat_models.dart';
import 'package:mobile/features/chat/data/chat_repository.dart';
import 'package:mobile/features/chat/presentation/chat_screen.dart';
import 'package:mobile/features/groups/data/group_api.dart';
import 'package:mobile/features/groups/data/group_repository.dart';
import 'package:mobile/features/groups/data/models/group_models.dart';
import 'package:mobile/features/groups/presentation/widgets/group_widgets.dart';
import 'package:mobile/features/social/presentation/widgets/user_avatar.dart';

void main() {
  testWidgets('group chat loads and sends authoritative REST response', (
    tester,
  ) async {
    final adapter = _ChatScreenAdapter();
    await tester.pumpWidget(_app(adapter));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có tin nhắn'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Chào cả nhóm');
    await tester.tap(find.byTooltip('Gửi tin nhắn'));
    await tester.pumpAndSettle();
    expect(find.text('Chào cả nhóm'), findsOneWidget);
    expect(adapter.sent, isTrue);
  });

  testWidgets('renders each author and places reader avatar only once', (
    tester,
  ) async {
    final adapter = _ChatScreenAdapter(
      messages: [
        _message(
          id: 'm1',
          sequence: 1,
          authorId: 'peer-1',
          name: 'Lan Anh',
          content: 'Tin nhắn đầu',
          mine: false,
        ),
        _message(
          id: 'm2',
          sequence: 2,
          authorId: 'me',
          name: 'Minh',
          content: 'Tin nhắn sau',
          mine: true,
        ),
      ],
      readers: [
        {
          'userId': 'reader-1',
          'displayName': 'Bình',
          'avatarStorageKey': null,
          'lastReadSequence': 2,
        },
      ],
    );
    await tester.pumpWidget(_app(adapter));
    await tester.pumpAndSettle();

    expect(find.text('Lan Anh'), findsOneWidget);
    expect(find.text('Minh'), findsNothing);
    expect(find.text('Tin nhắn đầu'), findsOneWidget);
    expect(find.text('Tin nhắn sau'), findsOneWidget);
    expect(find.byType(UserAvatar), findsNWidgets(2));
    expect(find.text('LA'), findsOneWidget);
    expect(find.text('M'), findsNothing);
    expect(find.byKey(const ValueKey('reader-reader-1')), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('groups consecutive authors and distinguishes own messages', (
    tester,
  ) async {
    final adapter = _ChatScreenAdapter(
      messages: [
        _message(
          id: 'peer-1',
          sequence: 1,
          authorId: 'peer',
          name: 'Lan Anh',
          content: 'First from Lan',
          mine: false,
        ),
        _message(
          id: 'peer-2',
          sequence: 2,
          authorId: 'peer',
          name: 'Lan Anh',
          content: 'Second from Lan',
          mine: false,
          reactions: [
            {'emoji': 'â¤ï¸', 'count': 1, 'reactedByMe': true},
          ],
        ),
        _message(
          id: 'peer-withdrawn',
          sequence: 3,
          authorId: 'peer',
          name: 'Lan Anh',
          content: null,
          mine: false,
          status: 'UNSENT',
        ),
        _message(
          id: 'peer-after-withdrawn',
          sequence: 4,
          authorId: 'peer',
          name: 'Lan Anh',
          content: 'Back again',
          mine: false,
        ),
        _message(
          id: 'other-author',
          sequence: 5,
          authorId: 'other',
          name: 'Binh Tran',
          content: 'Different author',
          mine: false,
        ),
        _message(
          id: 'own-message',
          sequence: 6,
          authorId: 'me',
          name: 'My Private Name',
          content: 'Own message',
          mine: true,
        ),
      ],
      readers: [
        {'userId': 'reader', 'displayName': 'Reader', 'lastReadSequence': 6},
      ],
    );
    await tester.pumpWidget(_app(adapter));
    await tester.pumpAndSettle();

    expect(find.text('Lan Anh'), findsNWidgets(2));
    expect(find.text('Binh Tran'), findsOneWidget);
    expect(find.text('My Private Name'), findsNothing);
    expect(
      find.byKey(const ValueKey('chat-message-bubble-peer-withdrawn')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('chat-message-bubble-peer-2')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('reader-reader')), findsOneWidget);

    final ownAlignment = tester.widget<Align>(
      find.byKey(const ValueKey('chat-message-align-own-message')),
    );
    final otherAlignment = tester.widget<Align>(
      find.byKey(const ValueKey('chat-message-align-other-author')),
    );
    expect(ownAlignment.alignment, Alignment.centerRight);
    expect(otherAlignment.alignment, Alignment.centerLeft);
    final ownBubble = tester.widget<Container>(
      find.byKey(const ValueKey('chat-message-bubble-own-message')),
    );
    final otherBubble = tester.widget<Container>(
      find.byKey(const ValueKey('chat-message-bubble-other-author')),
    );
    expect(
      (ownBubble.decoration! as BoxDecoration).color,
      isNot((otherBubble.decoration! as BoxDecoration).color),
    );
  });

  testWidgets('group author avatar is visible once and never shown for me', (
    tester,
  ) async {
    final adapter = _ChatScreenAdapter(
      messages: [
        _message(
          id: 'peer-first',
          sequence: 1,
          authorId: 'peer',
          name: 'Lan Anh',
          content: 'First',
          mine: false,
          avatarStorageKey: 'media/lan.png',
        ),
        _message(
          id: 'peer-next',
          sequence: 2,
          authorId: 'peer',
          name: 'Lan Anh',
          content: 'Next',
          mine: false,
          avatarStorageKey: 'media/lan.png',
        ),
        _message(
          id: 'own',
          sequence: 3,
          authorId: 'me',
          name: 'Minh',
          content: 'Mine',
          mine: true,
        ),
      ],
    );
    await tester.pumpWidget(_app(adapter));
    await tester.pumpAndSettle();

    final avatarFinder = find.byKey(
      const ValueKey('chat-message-avatar-peer-first'),
    );
    expect(avatarFinder, findsOneWidget);
    expect(tester.widget(avatarFinder), isA<UserAvatar>());
    expect(tester.getSize(avatarFinder), const Size(32, 32));
    expect(
      find.byKey(const ValueKey('chat-message-avatar-peer-next')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('chat-message-avatar-own')), findsNothing);
    expect(find.text('Lan Anh'), findsOneWidget);
    expect(find.text('media/lan.png'), findsNothing);
  });

  testWidgets('reaction badges attach to both bubbles and clear read avatars', (
    tester,
  ) async {
    final adapter = _ChatScreenAdapter(
      messages: [
        _message(
          id: 'peer-reaction',
          sequence: 1,
          authorId: 'peer',
          name: 'Lan Anh',
          content: 'Other message',
          mine: false,
          reactions: [
            {'emoji': '❤️', 'count': 2, 'reactedByMe': false},
            {'emoji': '😂', 'count': 1, 'reactedByMe': false},
            {'emoji': '👍', 'count': 1, 'reactedByMe': false},
          ],
        ),
        _message(
          id: 'own-reaction',
          sequence: 2,
          authorId: 'me',
          name: 'Minh',
          content: 'Own message',
          mine: true,
          reactions: [
            {'emoji': '❤️', 'count': 2, 'reactedByMe': false},
            {'emoji': '👍', 'count': 1, 'reactedByMe': true},
          ],
        ),
      ],
      readers: [
        {'userId': 'reader', 'displayName': 'Reader', 'lastReadSequence': 2},
      ],
    );
    await tester.pumpWidget(_app(adapter));
    await tester.pumpAndSettle();

    for (final id in ['peer-reaction', 'own-reaction']) {
      final bubble = tester.getRect(
        find.byKey(ValueKey('chat-message-bubble-$id')),
      );
      final badgeFinder = find.byKey(ValueKey('chat-reaction-badge-$id'));
      final badge = tester.getRect(badgeFinder);
      expect(badge.height, inInclusiveRange(18, 20));
      expect(badge.right, closeTo(bubble.right + 2, 0.1));
      expect(badge.bottom, closeTo(bubble.bottom + 12, 0.1));
      expect(badge.top, lessThan(bubble.bottom));
      expect(badge.bottom, greaterThan(bubble.bottom));
      expect(tester.getSize(badgeFinder).width, lessThan(108));
    }

    final ownBadge = tester.getRect(
      find.byKey(const ValueKey('chat-reaction-badge-own-reaction')),
    );
    final reader = tester.getRect(find.byKey(const ValueKey('reader-reader')));
    expect(reader.top, greaterThanOrEqualTo(ownBadge.bottom));
    expect(find.text('❤️ 😂 4'), findsOneWidget);
    expect(find.text('❤️ 👍 3'), findsOneWidget);
    expect(find.text('👍'), findsNothing);
  });

  for (final count in [1, 5]) {
    testWidgets('same reaction displays one heart and count $count', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          _ChatScreenAdapter(
            messages: [
              _message(
                id: 'heart',
                sequence: 1,
                authorId: 'me',
                name: 'Minh',
                content: 'Hi',
                mine: true,
                reactions: [
                  {'emoji': '❤️', 'count': count, 'reactedByMe': true},
                ],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('❤️ $count'), findsOneWidget);
    });
  }

  testWidgets('badge hanging edge opens authoritative filtered reactor sheet', (
    tester,
  ) async {
    final adapter = _ChatScreenAdapter(
      messages: [
        _message(
          id: 'mixed',
          sequence: 1,
          authorId: 'me',
          name: 'Minh',
          content: 'Hi',
          mine: true,
          reactions: [
            {'emoji': '❤️', 'count': 2, 'reactedByMe': true},
            {'emoji': '😂', 'count': 3, 'reactedByMe': false},
            {'emoji': '😮', 'count': 1, 'reactedByMe': false},
          ],
        ),
      ],
      reactionDetails: [
        for (var i = 0; i < 6; i++)
          {
            'user': {
              'id': 'private-id-$i',
              'displayName': i == 0 ? 'Minh' : 'Bạn $i',
              'avatarUrl': i == 1 ? '/api/v1/media/avatars/reactor.png' : null,
            },
            'emoji': i < 2
                ? '❤️'
                : i < 5
                ? '😂'
                : '😮',
          },
      ],
    );
    await tester.pumpWidget(_app(adapter));
    await tester.pumpAndSettle();
    expect(find.text('❤️ 😂 6'), findsOneWidget);
    final badge = tester.getRect(
      find.byKey(const ValueKey('chat-reaction-badge-mixed')),
    );
    await tester.tapAt(Offset(badge.right - 3, badge.bottom - 2));
    await tester.pumpAndSettle();
    expect(adapter.detailsMessagePath, '/api/v1/messages/mixed/reactions');
    expect(find.text('Biểu cảm'), findsOneWidget);
    expect(find.text('Sao chép'), findsNothing);
    expect(find.text('Tất cả 6'), findsOneWidget);
    expect(find.text('❤️ 2'), findsOneWidget);
    expect(find.text('😂 3'), findsOneWidget);
    expect(find.text('😮 1'), findsOneWidget);
    expect(find.text('👍 0'), findsNothing);
    expect(find.text('Minh'), findsOneWidget);
    expect(find.byType(UserAvatar), findsWidgets);
    final avatar = tester.widget<UserAvatar>(
      find.descendant(
        of: find.byKey(const ValueKey('reactor-private-id-1')),
        matching: find.byType(UserAvatar),
      ),
    );
    expect(avatar.avatarStorageKey, '/api/v1/media/avatars/reactor.png');
    expect(find.text('M'), findsOneWidget);
    expect(find.text('private-id-0'), findsNothing);
    expect(find.text('/api/v1/media/avatars/reactor.png'), findsNothing);
    expect(find.text('avatars/reactor.png'), findsNothing);
    await tester.tap(find.text('😂 3'));
    await tester.pumpAndSettle();
    expect(find.text('Minh'), findsNothing);
    expect(find.text('Bạn 1'), findsNothing);
    for (var i = 2; i < 5; i++) {
      expect(find.text('Bạn $i'), findsOneWidget);
    }
    expect(find.text('😂'), findsNWidgets(3));
    await tester.tap(find.text('Tất cả 6'));
    await tester.pumpAndSettle();
    expect(find.text('Minh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reaction sheet handles failed read then empty refreshed state', (
    tester,
  ) async {
    final adapter = _ChatScreenAdapter(
      detailsFail: true,
      messages: [
        _message(
          id: 'empty',
          sequence: 1,
          authorId: 'me',
          name: 'Minh',
          content: 'Hi',
          mine: true,
          reactions: [
            {'emoji': '❤️', 'count': 1, 'reactedByMe': true},
          ],
        ),
      ],
    );
    await tester.pumpWidget(_app(adapter));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-reaction-badge-empty')));
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
    adapter.detailsFail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Tất cả 0'), findsOneWidget);
    expect(find.text('Chưa có biểu cảm'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsOneWidget);
  });

  testWidgets(
    'group chat header shows canonical group avatar and is tappable',
    (tester) async {
      var opened = false;
      final adapter = _ChatScreenAdapter(
        groupAvatarStorageKey: 'avatars/canonical-group.png',
      );
      await tester.pumpWidget(
        _app(adapter, onOpenGroupInfo: () => opened = true),
      );
      await tester.pumpAndSettle();

      final avatar = tester.widget<GroupAvatar>(find.byType(GroupAvatar));
      expect(avatar.avatarStorageKey, 'avatars/canonical-group.png');
      expect(
        avatar.resolvedUrl,
        'http://localhost:8080/api/v1/media/avatars/canonical-group.png',
      );
      expect(find.text('avatars/canonical-group.png'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('chat-group-header')));
      expect(opened, isTrue);
    },
  );

  testWidgets('group chat and Group Info routes preserve canonical group id', (
    tester,
  ) async {
    final chat = _RouteChatRepository();
    final groups = _RouteGroupRepository();
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(
          settings,
          authStatus: AuthSessionStatus.authenticated,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).pushNamed(
                AppRoutes.groupChat,
                arguments: ChatRouteArgs(
                  repository: chat,
                  groupId: 'group-exact',
                  groupRepository: groups,
                ),
              ),
              child: const Text('Open group chat'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open group chat'));
    await tester.pumpAndSettle();
    expect(chat.openedGroupIds, ['group-exact']);
    await tester.tap(find.byKey(const ValueKey('chat-group-header')));
    await tester.pumpAndSettle();
    expect(groups.loadedGroupIds, ['group-exact']);
    expect(find.text('Badminton'), findsOneWidget);
    expect(
      tester.widget<GroupAvatar>(find.byType(GroupAvatar)).avatarStorageKey,
      'media/group.png',
    );

    await tester.ensureVisible(find.text('Trò chuyện'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trò chuyện'));
    await tester.pumpAndSettle();
    expect(chat.openedGroupIds, ['group-exact', 'group-exact']);
    expect(chat.openedConversationIds, [
      'conversation-canonical',
      'conversation-canonical',
    ]);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Thông tin nhóm'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-group-header')), findsOneWidget);
  });

  testWidgets(
    'message tap opens compact quick reactions and permitted actions',
    (tester) async {
      final adapter = _ChatScreenAdapter(
        messages: [
          _message(
            id: 'own-message',
            sequence: 1,
            authorId: 'me',
            name: 'Minh',
            content: 'React to this',
            mine: true,
            reactions: [
              {'emoji': '❤️', 'count': 2, 'reactedByMe': false},
              {'emoji': '👍', 'count': 1, 'reactedByMe': true},
            ],
          ),
        ],
      );
      await tester.pumpWidget(_app(adapter));
      await tester.pumpAndSettle();
      expect(find.text('❤️ 👍 3'), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsNothing);

      await tester.tap(find.text('React to this'));
      await tester.pumpAndSettle();
      for (final emoji in ['👍', '❤️', '😂', '😮', '😢', '😡']) {
        expect(find.text(emoji), findsOneWidget);
      }
      expect(find.text('Sao chép'), findsOneWidget);
      expect(find.text('Chỉnh sửa'), findsOneWidget);
      expect(find.text('Thu hồi tin nhắn'), findsOneWidget);
      expect(find.text('Xóa tin nhắn'), findsOneWidget);

      await tester.tap(find.text('😡'));
      await tester.pumpAndSettle();
      expect(adapter.lastReaction, '😡');

      await tester.tap(find.text('React to this'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thu hồi tin nhắn'));
      await tester.pumpAndSettle();
      expect(find.text('Tin nhắn đã được thu hồi'), findsOneWidget);
      expect(find.text('❤️ 2'), findsNothing);
      expect(find.text('👍 1'), findsNothing);
    },
  );

  testWidgets('withdrawn message renders only the withdrawn state', (
    tester,
  ) async {
    final adapter = _ChatScreenAdapter(
      messages: [
        _message(
          id: 'withdrawn',
          sequence: 1,
          authorId: 'peer',
          name: 'Hidden author',
          content: null,
          mine: false,
          status: 'UNSENT',
          reactions: [
            {'emoji': '❤️', 'count': 1, 'reactedByMe': true},
          ],
        ),
      ],
    );
    await tester.pumpWidget(_app(adapter));
    await tester.pumpAndSettle();
    expect(find.text('Tin nhắn đã được thu hồi'), findsOneWidget);
    expect(find.text('Hidden author'), findsNothing);
    expect(find.text('❤️ 1'), findsNothing);
    expect(find.byType(UserAvatar), findsNothing);
    await tester.tap(find.text('Tin nhắn đã được thu hồi'));
    await tester.pumpAndSettle();
    expect(find.text('Sao chép'), findsNothing);
    expect(find.text('👍'), findsNothing);
  });
}

Widget _app(_ChatScreenAdapter adapter, {VoidCallback? onOpenGroupInfo}) =>
    MaterialApp(
      home: ChatScreen(
        groupId: 'group-1',
        onOpenGroupInfo: onOpenGroupInfo,
        repository: ChatRepository(
          ChatApi(
            Dio(BaseOptions(baseUrl: 'https://test'))
              ..httpClientAdapter = adapter,
          ),
        ),
      ),
    );

Map<String, dynamic> _message({
  required String id,
  required int sequence,
  required String authorId,
  required String name,
  required String? content,
  required bool mine,
  String status = 'ACTIVE',
  String? avatarStorageKey,
  List<Map<String, Object>> reactions = const [],
}) => {
  'id': id,
  'sequence': sequence,
  'isMine': mine,
  'author': {
    'id': authorId,
    'displayName': name,
    'avatarStorageKey': avatarStorageKey,
  },
  'content': content,
  'status': status,
  'replyToMessageId': null,
  'createdAt': '2026-09-27T00:00:00Z',
  'editedAt': null,
  'unsentAt': status == 'UNSENT' ? '2026-09-27T00:01:00Z' : null,
  'myReaction': null,
  'reactions': reactions,
  'permissions': _permissions(canEdit: mine && status == 'ACTIVE'),
};

class _ChatScreenAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> messages;
  final List<Map<String, Object?>> readers;
  final String? groupAvatarStorageKey;
  final List<Map<String, dynamic>> reactionDetails;
  bool detailsFail;
  String? detailsMessagePath;
  bool sent = false;
  String? lastReaction;

  _ChatScreenAdapter({
    this.messages = const [],
    this.readers = const [],
    this.groupAvatarStorageKey,
    this.reactionDetails = const [],
    this.detailsFail = false,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    Object body = {};
    var status = 200;
    if (options.path.endsWith('/conversation')) {
      body = {
        'id': 'conversation-1',
        'type': 'GROUP',
        'groupId': 'group-1',
        'title': 'Nhóm thử nghiệm',
        'avatarStorageKey': groupAvatarStorageKey,
        'peer': null,
        'accessStatus': 'OPEN',
        'lastSequence': messages.length,
        'lastMessagePreview': null,
        'lastMessageAt': null,
        'unreadCount': 0,
        'permissions': _permissions(),
      };
    } else if (options.path.endsWith('/messages') && options.method == 'GET') {
      body = {
        'conversationId': 'conversation-1',
        'messages': messages,
        'readers': readers,
        'nextBeforeSequence': null,
        'hasMore': false,
      };
    } else if (options.path.endsWith('/read-state')) {
      status = 204;
    } else if (options.path.endsWith('/messages') && options.method == 'POST') {
      sent = true;
      status = 201;
      body = _message(
        id: 'sent-message',
        sequence: messages.length + 1,
        authorId: 'me',
        name: 'Minh',
        content: options.data['content'] as String,
        mine: true,
      );
    } else if (options.path.endsWith('/reactions')) {
      detailsMessagePath = options.path;
      status = detailsFail ? 403 : 200;
      body = detailsFail ? {'code': 'ACCESS_DENIED'} : reactionDetails;
    } else if (options.path.endsWith('/reaction')) {
      lastReaction = (options.data as Map)['emoji'] as String;
      final message = Map<String, dynamic>.from(messages.first);
      message['myReaction'] = lastReaction;
      message['reactions'] = [
        {'emoji': lastReaction, 'count': 1, 'reactedByMe': true},
      ];
      body = message;
    } else if (options.path.endsWith('/unsend')) {
      final message = Map<String, dynamic>.from(messages.first);
      message['status'] = 'UNSENT';
      message['content'] = null;
      message['myReaction'] = null;
      message['reactions'] = [];
      message['unsentAt'] = '2026-09-27T00:01:00Z';
      message['permissions'] = _permissions(canEdit: false, active: false);
      body = message;
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _RouteChatRepository extends ChatRepository {
  _RouteChatRepository() : super(ChatApi(Dio()));
  final openedGroupIds = <String>[];
  final openedConversationIds = <String>[];

  @override
  Future<ChatConversation> openGroup(String groupId) async {
    openedGroupIds.add(groupId);
    return const ChatConversation(
      id: 'conversation-canonical',
      type: 'GROUP',
      groupId: 'group-exact',
      title: 'Badminton',
      avatarStorageKey: 'media/group.png',
      accessStatus: 'OPEN',
      lastSequence: 0,
      unreadCount: 0,
      permissions: ChatPermissions(
        canSend: true,
        canEdit: false,
        canUnsend: false,
        canDeleteForMe: false,
        canReact: false,
        canPin: false,
        readOnly: false,
      ),
    );
  }

  @override
  Future<ChatMessagePage> history(
    String conversationId, {
    int? beforeSequence,
    int limit = 30,
  }) async {
    openedConversationIds.add(conversationId);
    return ChatMessagePage(
      conversationId: conversationId,
      messages: const [],
      readers: const [],
      nextBeforeSequence: null,
      hasMore: false,
    );
  }

  @override
  Future<void> markRead(String conversationId, int sequence) async {}
}

class _RouteGroupRepository extends GroupRepository {
  _RouteGroupRepository() : super(api: GroupApi(Dio()));
  final loadedGroupIds = <String>[];

  @override
  Future<GroupDetail> getGroup(String id) async {
    loadedGroupIds.add(id);
    return GroupDetail(
      id: id,
      name: 'Badminton',
      avatarStorageKey: 'media/group.png',
      status: GroupStatus.active,
      ownerUserId: 'owner',
      callerRole: GroupRole.member,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  @override
  Future<List<GroupMember>> getMembers(String id) async => const [];
}

Map<String, dynamic> _permissions({bool canEdit = false, bool active = true}) =>
    {
      'canSend': true,
      'canEdit': canEdit,
      'canUnsend': canEdit,
      'canDeleteForMe': active,
      'canReact': active,
      'canPin': false,
      'readOnly': false,
    };
