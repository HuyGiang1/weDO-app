import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/paged_response.dart';
import 'package:mobile/features/groups/application/groups_controller.dart';
import 'package:mobile/features/groups/application/group_admission_controllers.dart';
import 'package:mobile/features/groups/data/group_api.dart';
import 'package:mobile/features/groups/data/group_repository.dart';
import 'package:mobile/features/groups/data/models/group_models.dart';
import 'package:mobile/features/groups/presentation/screens/my_groups_screen.dart';
import 'package:mobile/features/groups/presentation/screens/group_admission_screens.dart';
import 'package:mobile/features/groups/presentation/widgets/group_widgets.dart';

void main() {
  for (final withIdentity in [true, false]) {
    testWidgets('join request identity projection/fallback: $withIdentity', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GroupJoinRequestsScreen(
            groupId: 'g',
            controller: JoinRequestsController(_IdentityRepo(withIdentity)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          withIdentity ? 'Human requester' : 'Tên người yêu cầu chưa khả dụng',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('internal-requester'), findsNothing);
      expect(
        tester.widget<GroupAvatar>(find.byType(GroupAvatar)).avatarStorageKey,
        withIdentity ? 'avatars/requester.png' : null,
      );
    });
    testWidgets('ban identity projection/fallback: $withIdentity', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GroupBansScreen(
            groupId: 'g',
            controller: GroupBansController(_IdentityRepo(withIdentity)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          withIdentity ? 'Human banned user' : 'Tên người dùng chưa khả dụng',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('internal-banned'), findsNothing);
      expect(
        tester.widget<GroupAvatar>(find.byType(GroupAvatar)).avatarStorageKey,
        withIdentity ? 'avatars/banned.png' : null,
      );
    });
  }
  for (final scale in [1.1, 1.5]) {
    testWidgets('Groups header and actions fit at $scale text scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var searches = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: MyGroupsScreen(
            controller: GroupsController(_Repo()),
            onCreate: () {},
            onOpenGroup: (_) {},
            onSearch: () => searches++,
            onNotifications: () {},
            onChatRequests: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final title = tester.renderObject<RenderParagraph>(find.text('WeDo'));
      expect(
        title.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 4),
        ),
        hasLength(1),
      );
      await tester.tap(find.byTooltip('Tìm kiếm'));
      expect(searches, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'invitation renders existing projection names, never internal IDs',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MyGroupInvitationsScreen(
            controller: GroupInvitationsController(_Repo()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Invitation group'), findsOneWidget);
      expect(
        find.textContaining('Human inviter', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('internal-group'), findsNothing);
      expect(
        find.textContaining('internal-inviter', findRichText: true),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _Repo extends GroupRepository {
  _Repo() : super(api: GroupApi(Dio()));
  @override
  Future<PagedResponse<GroupSummary>> listGroups({
    int page = 0,
    int size = 30,
    GroupStatus status = GroupStatus.active,
  }) async => PagedResponse(
    items: [
      GroupSummary(
        id: 'short',
        name: 'QA',
        status: GroupStatus.active,
        callerRole: GroupRole.owner,
        updatedAt: DateTime(2026),
      ),
      GroupSummary(
        id: 'long',
        name: 'A long group name to verify meaningful wrapping on the Samsung width',
        status: GroupStatus.active,
        callerRole: GroupRole.member,
        updatedAt: DateTime(2026),
      ),
    ],
    page: 0,
    size: 30,
    totalElements: 2,
    totalPages: 1,
    hasNext: false,
  );
  @override
  Future<PagedResponse<GroupInvitationResponse>> listMyInvitations({
    int page = 0,
    int size = 30,
    String status = 'PENDING',
  }) async => PagedResponse(
    items: [
      GroupInvitationResponse.fromJson({
        'id': 'invitation',
        'groupId': 'internal-group',
        'groupName': 'Invitation group',
        'groupAvatarStorageKey': null,
        'inviterId': 'internal-inviter',
        'inviterDisplayName': 'Human inviter',
        'inviteeId': 'recipient',
        'status': 'PENDING',
        'createdAt': '2026-10-13T00:00:00Z',
      }),
    ],
    page: 0,
    size: 30,
    totalElements: 1,
    totalPages: 1,
    hasNext: false,
  );
}

class _IdentityRepo extends GroupRepository {
  final bool withIdentity;
  _IdentityRepo(this.withIdentity) : super(api: GroupApi(Dio()));

  PagedResponse<T> _page<T>(T item) => PagedResponse(
    items: [item],
    page: 0,
    size: 30,
    totalElements: 1,
    totalPages: 1,
    hasNext: false,
  );

  @override
  Future<PagedResponse<JoinRequestResponse>> listJoinRequests(
    String groupId, {
    int page = 0,
    int size = 30,
    String status = 'PENDING',
  }) async => _page(
    JoinRequestResponse.fromJson({
      'id': 'request',
      'groupId': groupId,
      'userId': 'internal-requester',
      'status': 'PENDING',
      'createdAt': '2026-10-13T00:00:00Z',
      if (withIdentity) 'userDisplayName': 'Human requester',
      if (withIdentity) 'userAvatarStorageKey': 'avatars/requester.png',
    }),
  );

  @override
  Future<PagedResponse<GroupBanResponse>> listBans(
    String groupId, {
    int page = 0,
    int size = 30,
  }) async => _page(
    GroupBanResponse.fromJson({
      'id': 'ban',
      'groupId': groupId,
      'userId': 'internal-banned',
      'bannedBy': 'internal-admin',
      'createdAt': '2026-10-13T00:00:00Z',
      if (withIdentity) 'displayName': 'Human banned user',
      if (withIdentity) 'avatarStorageKey': 'avatars/banned.png',
    }),
  );
}
