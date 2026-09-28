import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/routes.dart';
import 'package:mobile/features/auth/application/auth_session_controller.dart';
import 'package:mobile/features/chat/data/chat_api.dart';
import 'package:mobile/features/chat/data/chat_models.dart';
import 'package:mobile/features/chat/data/chat_repository.dart';
import 'package:mobile/features/chat/presentation/chat_home_screen.dart';
import 'package:mobile/features/chat/presentation/chat_screen.dart';
import 'package:mobile/features/groups/data/group_api.dart';
import 'package:mobile/features/groups/data/group_repository.dart';
import 'package:mobile/features/groups/data/models/group_models.dart';
import 'package:mobile/features/groups/presentation/screens/group_info_screen.dart';

void main() {
  testWidgets(
    'Group Info global Chat opens only Chat Home with no context IDs',
    (tester) async {
      final chat = _ChatRepository();
      final observer = _RouteObserver();
      await tester.pumpWidget(_app(chat, observer));
      await tester.tap(find.text('Open Tam Đảo'));
      await tester.pumpAndSettle();
      expect(find.byType(GroupInfoScreen), findsOneWidget);
      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatHomeScreen), findsOneWidget);
      expect(find.byType(ChatScreen), findsNothing);
      expect(find.text('Tam Đảo'), findsOneWidget);
      expect(find.text('Cầu lông'), findsOneWidget);
      expect(chat.openedGroups, isEmpty);
      expect(chat.histories, isEmpty);
      expect(chat.listCalls, 1);
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        2,
      );
      expect(observer.last.name, AppRoutes.chatHome);
      expect(observer.last.arguments, isA<ChatHomeRouteArgs>());
      expect(observer.last.arguments, isNot(isA<ChatRouteArgs>()));
      expect(observer.last.arguments, isNot(isA<GroupInfoRouteArgs>()));

      await tester.tap(find.text('Tam Đảo'));
      await tester.pumpAndSettle();
      expect(chat.histories, ['tam-dao-conversation']);
      expect(chat.openedGroups, isEmpty);
      final args = observer.last.arguments as ChatRouteArgs;
      expect(args.conversation?.id, 'tam-dao-conversation');
      expect(args.conversation?.groupId, 'tam-dao');
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatHomeScreen), findsOneWidget);
      expect(find.byType(GroupInfoScreen), findsNothing);
      expect(find.byType(ChatScreen), findsNothing);

      // Reselecting Chat must not reopen the conversation just visited.
      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();
      expect(chat.histories, ['tam-dao-conversation']);
      expect(find.byType(ChatHomeScreen), findsOneWidget);
    },
  );

  testWidgets(
    'explicit group chat retains exact group and returns to Group Info',
    (tester) async {
      final chat = _ChatRepository();
      final observer = _RouteObserver();
      await tester.pumpWidget(_app(chat, observer));
      await tester.tap(find.text('Open Tam Đảo'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Trò chuyện'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trò chuyện'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(chat.openedGroups, ['tam-dao']);
      expect(chat.histories, ['tam-dao-conversation']);
      expect((observer.last.arguments as ChatRouteArgs).groupId, 'tam-dao');
      expect(chat.listCalls, 0);
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.byType(GroupInfoScreen), findsOneWidget);
      expect(find.byType(ChatHomeScreen), findsNothing);
    },
  );

  testWidgets(
    'global Chat from conversation header Group Info ignores active conversation',
    (tester) async {
      final chat = _ChatRepository();
      final observer = _RouteObserver();
      await tester.pumpWidget(_app(chat, observer));
      await tester.tap(find.text('Open Tam Đảo'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Trò chuyện'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trò chuyện'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-group-header')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<GroupInfoScreen>(find.byType(GroupInfoScreen)).groupId,
        'tam-dao',
      );
      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();
      expect(observer.last.name, AppRoutes.chatHome);
      expect(observer.last.arguments, isA<ChatHomeRouteArgs>());
      expect(find.byType(ChatHomeScreen), findsOneWidget);
      expect(find.byType(ChatScreen), findsNothing);
      expect(chat.openedGroups, ['tam-dao']);
      expect(chat.histories, ['tam-dao-conversation']);

      await tester.tap(find.text('Cầu lông'));
      await tester.pumpAndSettle();
      expect(chat.histories.last, 'badminton-conversation');
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatHomeScreen), findsOneWidget);
    },
  );
}

Widget _app(_ChatRepository chat, _RouteObserver observer) => MaterialApp(
  navigatorObservers: [observer],
  onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(
    settings,
    authStatus: AuthSessionStatus.authenticated,
  ),
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => Navigator.of(context).pushNamed(
          AppRoutes.groupInfo,
          arguments: GroupInfoRouteArgs(
            repository: _GroupsRepository(),
            groupId: 'tam-dao',
            chatRepository: chat,
          ),
        ),
        child: const Text('Open Tam Đảo'),
      ),
    ),
  ),
);

class _RouteObserver extends NavigatorObserver {
  late RouteSettings last;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    last = route.settings;
  }
}

class _ChatRepository extends ChatRepository {
  _ChatRepository() : super(ChatApi(Dio()));
  final openedGroups = <String>[];
  final histories = <String>[];
  int listCalls = 0;
  final entries = [
    _conversation('tam-dao', 'Tam Đảo'),
    _conversation('badminton', 'Cầu lông'),
  ];

  @override
  Future<List<ChatConversation>> conversations() async {
    listCalls++;
    return entries;
  }

  @override
  Future<ChatConversation> openGroup(String id) async {
    openedGroups.add(id);
    return entries.singleWhere((entry) => entry.groupId == id);
  }

  @override
  Future<ChatMessagePage> history(
    String id, {
    int? beforeSequence,
    int limit = 30,
  }) async {
    histories.add(id);
    return ChatMessagePage(
      conversationId: id,
      messages: const [],
      readers: const [],
      nextBeforeSequence: null,
      hasMore: false,
    );
  }
}

ChatConversation _conversation(String id, String title) => ChatConversation(
  id: '$id-conversation',
  groupId: id,
  title: title,
  type: 'GROUP',
  avatarStorageKey: 'avatars/$id.png',
  accessStatus: 'OPEN',
  lastSequence: 0,
  unreadCount: 0,
  permissions: const ChatPermissions(
    canSend: true,
    canEdit: false,
    canUnsend: false,
    canDeleteForMe: false,
    canReact: true,
    canPin: false,
    readOnly: false,
  ),
);

class _GroupsRepository extends GroupRepository {
  _GroupsRepository() : super(api: GroupApi(Dio()));
  @override
  Future<GroupDetail> getGroup(String id) async => GroupDetail(
    id: id,
    name: 'Tam Đảo',
    avatarStorageKey: 'avatars/$id.png',
    status: GroupStatus.active,
    ownerUserId: 'owner',
    callerRole: GroupRole.member,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  @override
  Future<List<GroupMember>> getMembers(String id) async => const [];
}
