import 'package:mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:mobile/features/auth/presentation/screens/register_screen.dart';
import 'package:mobile/features/community/presentation/recruitment_screen.dart';
import 'package:mobile/features/community/data/recruitment_api.dart';
import 'package:mobile/features/groups/application/groups_controller.dart';
import 'package:mobile/features/groups/presentation/screens/my_groups_screen.dart';
import 'package:mobile/features/search/application/search_controller.dart' as search;
import 'package:mobile/features/search/data/search_api.dart';
import 'package:mobile/features/search/presentation/search_screen.dart';
import 'package:mobile/features/profile/data/profile_api.dart';
import 'package:mobile/features/profile/data/profile_repository.dart';
import 'package:mobile/features/home/presentation/home_screen.dart';
import 'package:mobile/features/home/application/home_controller.dart';
import 'package:mobile/features/home/data/home_repository.dart';
import 'package:mobile/features/home/data/home_models.dart';
import 'package:mobile/features/expense/data/expense_models.dart';
import 'package:mobile/features/chat/data/chat_api.dart';
import 'package:mobile/features/chat/data/chat_repository.dart';
import 'package:mobile/features/chat/presentation/chat_home_screen.dart';
import 'package:mobile/features/calendar/data/calendar_api.dart';
import 'package:mobile/features/calendar/data/calendar_repository.dart';
import 'package:mobile/features/calendar/presentation/calendar_screen.dart';
import 'package:mobile/features/auth/data/models/auth_models.dart';
import 'package:mobile/features/profile/presentation/screens/profile_screen.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/core/ui/widgets/app_text_field.dart';
import 'package:mobile/core/models/paged_response.dart';
import 'package:mobile/features/groups/application/create_group_controller.dart';
import 'package:mobile/features/groups/application/group_detail_controller.dart';
import 'package:mobile/features/groups/application/group_management_controllers.dart';
import 'package:mobile/features/groups/application/group_admission_controllers.dart';
import 'package:mobile/features/groups/data/group_api.dart';
import 'package:mobile/features/groups/data/group_repository.dart';
import 'package:mobile/features/groups/data/models/group_models.dart';
import 'package:mobile/features/groups/presentation/screens/create_group_screen.dart';
import 'package:mobile/features/groups/presentation/screens/group_info_screen.dart';
import 'package:mobile/features/groups/presentation/screens/group_management_screens.dart';
import 'package:mobile/features/groups/presentation/screens/group_admission_screens.dart';
import 'package:mobile/features/activity/application/activity_controllers.dart';
import 'package:mobile/features/activity/data/activity_api.dart';
import 'package:mobile/features/activity/data/activity_repository.dart';
import 'package:mobile/features/activity/presentation/screens/activity_runtime_screens.dart';
import 'package:mobile/features/task/data/task_api.dart';
import 'package:mobile/features/task/data/task_repository.dart';
import 'package:mobile/features/task/presentation/screens/task_screens.dart';
import 'package:mobile/features/poll/data/poll_api.dart';
import 'package:mobile/features/poll/data/poll_repository.dart';
import 'package:mobile/features/poll/presentation/screens/poll_screens.dart';
import 'package:mobile/features/expense/data/expense_api.dart';
import 'package:mobile/features/expense/data/expense_repository.dart';
import 'package:mobile/features/expense/presentation/expense_screens.dart';
import 'package:mobile/features/community/data/community_api.dart';
import 'package:mobile/features/community/presentation/community_screen.dart';
import 'package:mobile/features/journey/presentation/journey_screens.dart';

import '../features/journey/journey_test.dart' as journey_fixture;

final _date = DateTime.utc(2026, 10, 28);
PagedResponse<T> _page<T>(List<T> items) => PagedResponse(
  items: items,
  page: 0,
  size: 20,
  totalElements: items.length,
  totalPages: 1,
  hasNext: false,
);

class _Groups extends GroupRepository {
  GroupRole role;
  bool allowMemberEdit = false;
  int joinReads = 0;
  int pendingTotal = 1;
  _Groups({this.role = GroupRole.owner}) : super(api: GroupApi(Dio()));
  @override
  Future<GroupDetail> getGroup(String id) async => GroupDetail(
    id: id,
    name: 'Nhóm cùng nhau khám phá Ba Vì',
    description:
        'Cùng lên kế hoạch, chia sẻ khoảnh khắc và hoàn thành công việc.',
    status: GroupStatus.active,
    ownerUserId: 'owner',
    callerRole: role,
    createdAt: _date,
    updatedAt: _date,
  );
  @override
  Future<PagedResponse<GroupSummary>> listGroups({int page = 0, int size = 30, GroupStatus? status}) async => _page([]);
  @override
  Future<List<GroupMember>> getMembers(String id) async => [
    GroupMember(
      userId: 'owner',
      username: 'owner',
      displayName: 'Nguyễn Hoàng Anh',
      role: GroupRole.owner,
      joinedAt: _date,
    ),
    GroupMember(
      userId: 'member',
      username: 'member',
      displayName: 'Trần Nguyễn Khánh Linh có tên dài',
      role: GroupRole.member,
      joinedAt: _date,
    ),
  ];
  @override
  Future<GroupMember> getMember(String group, String user) async =>
      (await getMembers(group)).firstWhere((m) => m.userId == user);
  @override
  Future<GroupSettings> getSettings(String id) async => GroupSettings(
    groupId: id,
    joinPolicy: GroupJoinPolicy.approvalRequired,
    memberModifyInfoAllowed: allowMemberEdit,
    memberCreateActivityAllowed: true,
    memberPinMessageAllowed: false,
    chatHistoryPolicy: ChatHistoryPolicy.fullHistory,
    updatedAt: _date,
  );
  InviteLinkResponse get link => InviteLinkResponse(
    id: 'link',
    groupId: 'g',
    inviteCode: 'QA_safe_Code',
    creatorUserId: 'owner',
    maxUses: 10,
    usesCount: 2,
    isRevoked: false,
    createdAt: _date,
  );
  @override
  Future<List<InviteLinkResponse>> listInviteLinks(String id) async => [link];
  @override
  Future<InviteLinkResponse> getDefaultInviteLink(String id) async => link;
  @override
  Future<PagedResponse<JoinRequestResponse>> listJoinRequests(
    String id, {
    int page = 0,
    int size = 20,
  }) async {
    joinReads++;
    final data = _page([
      JoinRequestResponse(
        id: 'req',
        groupId: id,
        requesterUserId: 'requester',
        userDisplayName: 'Nguyễn Thị Minh Anh có tên rất dài',
        status: GroupJoinRequestStatus.pending,
        createdAt: _date,
      ),
    ]);
    return PagedResponse(
      items: data.items,
      page: page,
      size: size,
      totalElements: pendingTotal,
      totalPages: pendingTotal,
      hasNext: pendingTotal > size,
    );
  }

  @override
  Future<PagedResponse<GroupBanResponse>> listBans(
    String id, {
    int page = 0,
    int size = 30,
  }) async => _page([
    GroupBanResponse(
      id: 'ban',
      groupId: id,
      bannedUserId: 'banned',
      bannedByUserId: 'owner',
      displayName: 'Thành viên thử nghiệm có tên dài',
      reason: 'Vi phạm quy tắc của nhóm trong dữ liệu QA',
      createdAt: _date,
    ),
  ]);
}

class _Community extends CommunityApi {
  _Community() : super(Dio());
  @override
  Future<List<(String, String)>> writableGroups() async => [
    ('g', 'Nhóm Ba Vì'),
  ];
}

Dio _rootDio() {
  final dio = Dio(BaseOptions(baseUrl: 'https://fixture'));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (r, h) {
    final Object data = switch (r.path) {
      '/api/v1/me' => {'id': 'owner'},
      '/api/v1/community/posts' => {'items': [for (var i = 0; i < 4; i++) {'id': 'visual-$i', 'caption': 'Cùng lên kế hoạch cho cuối tuần. Một chuyến đi, nhiều kỷ niệm.', 'visibility': 'PUBLIC', 'author': {'id': 'owner', 'displayName': 'Nguyễn Hoàng Anh'}, 'createdAt': '2026-10-28T00:00:00Z', 'media': [], 'reactionCount': 2, 'commentCount': 1, 'permissions': {}}], 'hasMore': false},
      '/api/v1/conversations' => [{'id': 'chat', 'type': 'GROUP', 'title': 'Nhóm cùng nhau khám phá Ba Vì', 'accessStatus': 'ACTIVE', 'lastSequence': 3, 'unreadCount': 2, 'lastMessagePreview': 'Hẹn cả nhóm vào cuối tuần nhé.', 'permissions': {}}],
      '/api/v1/calendar/activities' => <Object>[],
      final path when path.startsWith('/api/v1/community/posts/') => {'id': path.split('/').last, 'caption': 'Cùng lên kế hoạch cho cuối tuần. Một chuyến đi, nhiều kỷ niệm.', 'visibility': 'PUBLIC', 'author': {'id': 'owner', 'displayName': 'Nguyễn Hoàng Anh'}, 'createdAt': '2026-10-28T00:00:00Z', 'media': [], 'reactionCount': 2, 'commentCount': 1, 'permissions': {}},
      _ => throw StateError('Unexpected visual fixture read: ${r.path}'),
    };
    h.resolve(Response(requestOptions: r, data: data));
  }));
  return dio;
}
class _Home implements HomeGateway {
  final bool emptyGroups;
  _Home({this.emptyGroups = false});
  @override
  Future<HomeResponse> load() async => HomeResponse(
    emptyGroups ? [] : [const HomeGroup('g', 'Nhóm cùng nhau khám phá Ba Vì', null)],
    [HomeActivity('a', 'g', 'Nhóm Ba Vì', 'Một ngày cùng nhau khám phá', DateTime(2026, 10, 30, 7, 30))],
    HomeFinance(ExpenseMoney.zero, ExpenseMoney.zero, []),
    [const HomeAction(HomeActionType.taskDue, 't', 'g', 'a', 'Chuẩn bị đồ dùng cho chuyến đi', null)], [],
  );
}

void main() {
  bool fontReady = false;
  const capture = bool.fromEnvironment('WEDO_CAPTURE_DESIGN');
  setUpAll(() async {
    final font = File('/System/Library/Fonts/Supplemental/Arial.ttf');
    if (await font.exists()) {
      final loader = FontLoader('WeDoVisual')
        ..addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
      await loader.load();
      fontReady = true;
    }
    final icons = File(
      '/opt/homebrew/Caskroom/flutter/3.0.3/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (await icons.exists()) {
      final loader = FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(await icons.readAsBytes())));
      await loader.load();
    }
  });
  Future<void> mount(
    WidgetTester t,
    Widget page,
    Brightness brightness, {
    double keyboard = 0,
    Size viewport = const Size(360, 900),
    double textScale = 1,
  }) async {
    await t.binding.setSurfaceSize(viewport);
    final base = AppTheme.build(brightness);
    await t.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('design'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: fontReady
              ? base.copyWith(
                  textTheme: base.textTheme.apply(fontFamily: 'WeDoVisual'),
                )
              : base,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(viewInsets: EdgeInsets.only(bottom: keyboard), textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: page,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> shot(WidgetTester t, String name, Brightness brightness) async {
    expect(t.takeException(), isNull, reason: name);
    if (capture) {
      expect(
        fontReady,
        isTrue,
        reason: 'Readable font required for visual evidence',
      );
      await t.runAsync(() async {
        final image = await (t.renderObject(
          find.byKey(const ValueKey('design')),
        ) as RenderRepaintBoundary).toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/wedo-design-$name-${brightness.name}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  }

  Widget info(_Groups repo) => GroupInfoScreen(
    groupId: 'g',
    controller: GroupDetailController(repo, readSettings: true),
    onEdit: () {},
    onMembers: () {},
    onSettings: () {},
    onActivityLog: () {},
    onLeave: () {},
    onActivities: () {},
    onMemories: () {},
    onChat: () {},
    onInviteLinks: () {},
    onJoinRequests: () {},
    onBans: () {},
    onTransferOwnership: () {},
    onDelete: () {},
  );
  for (final brightness in Brightness.values) {
    for (final name in [
      'create-group',
      'edit-group',
      'group-info',
      'invite-links',
      'join-requests',
      'blocked-members',
      'create-activity',
      'create-task',
      'create-poll',
      'create-expense',
      'community-composer',
      'stop-form',
      'group-members',
      'member-management',
      'permissions',
      'ownership-transfer',
      'invite-links-expanded',
      'group-info-management',
    ]) {
      testWidgets(
        '$name actual screen $brightness no overflow and screenshot',
        (t) async {
          final groups = _Groups();
          final fixture = journey_fixture.Api();
          final dio = fixture.dio;
          final page = switch (name) {
            'create-group' => CreateGroupScreen(
              controller: CreateGroupController(groups),
              onCreated: (_) {},
            ),
            'edit-group' => EditGroupScreen(
              groupId: 'g',
              controller: EditGroupController(groups),
            ),
            'group-info' || 'group-info-management' => info(groups),
            'group-members' => GroupMembersScreen(
              groupId: 'g',
              controller: GroupMembersController(groups),
              onMember: (_) {},
            ),
            'member-management' => MemberManagementScreen(
              groupId: 'g',
              userId: 'member',
              controller: MemberManagementController(groups),
              onKicked: () {},
            ),
            'permissions' => GroupPermissionsScreen(
              groupId: 'g',
              controller: GroupPermissionsController(groups),
              onAdmins: () {},
              onTransfer: () {},
            ),
            'ownership-transfer' => TransferOwnershipScreen(
              groupId: 'g',
              controller: TransferOwnershipController(groups),
              onTransferred: (_) {},
            ),
            'invite-links' || 'invite-links-expanded' => GroupInviteLinksScreen(
              groupId: 'g',
              controller: InviteLinksController(groups),
            ),
            'join-requests' => GroupJoinRequestsScreen(
              groupId: 'g',
              controller: JoinRequestsController(groups),
            ),
            'blocked-members' => GroupBansScreen(
              groupId: 'g',
              controller: GroupBansController(groups),
            ),
            'create-activity' => ActivityCreateRuntimeScreen(
              groupId: 'g',
              controller: ActivityListController(
                ActivityRepository(api: ActivityApi(dio)),
              ),
            ),
            'create-task' => CreateTaskScreen(
              activityId: 'a',
              repository: TaskRepository(TaskApi(dio)),
              loadMembers: () => groups.getMembers('g'),
            ),
            'create-poll' => CreatePollScreen(
              activityId: 'a',
              repository: PollRepository(PollApi(dio)),
            ),
            'create-expense' => ExpenseFormScreen(
              groupId: 'g',
              repository: ExpenseRepository(ExpenseApi(dio)),
              groupRepository: groups,
            ),
            'community-composer' => CommunityComposer(
              api: _Community(),
              viewer: 'owner',
            ),
            _ => StopComposer(api: fixture, activity: 'a'),
          };
          await mount(t, page, brightness);
          if (name == 'invite-links-expanded') {
            await t.tap(find.text('Quản lý liên kết nâng cao'));
            await t.pumpAndSettle();
          }
          if (name == 'group-info-management') {
            await t.scrollUntilVisible(find.text('Truy cập & quản lý'), 300);
            await t.pumpAndSettle();
          }
          await shot(t, name, brightness);
          await t.pumpWidget(const SizedBox());
          await t.binding.setSurfaceSize(null);
        },
      );
    }
    testWidgets(
      'outlined focus validation multiline dropdown and keyboard $brightness',
      (t) async {
        final form = GlobalKey<FormState>();
        final controller = TextEditingController();
        final focus = FocusNode();
        await mount(
          t,
          Scaffold(
            body: SingleChildScrollView(
              child: Form(
                key: form,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      AppTextField(
                        label: 'Tên hoạt động dành cho cả nhóm',
                        controller: controller,
                        focusNode: focus,
                        validator: (v) =>
                            v!.isEmpty ? 'Vui lòng nhập tên' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Ghi chú'),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Quyền truy cập',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'members',
                            child: Text('Chỉ thành viên trong nhóm'),
                          ),
                        ],
                        validator: (v) =>
                            v == null ? 'Chọn quyền truy cập' : null,
                        onChanged: (_) {},
                      ),
                      const TextField(
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Thông tin không thể chỉnh sửa',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          brightness,
          keyboard: 280,
        );
        form.currentState!.validate();
        await t.pumpAndSettle();
        expect(find.text('Vui lòng nhập tên'), findsOneWidget);
        expect(find.text('Chọn quyền truy cập'), findsOneWidget);
        focus.requestFocus();
        await t.pumpAndSettle();
        final field = t.widget<TextField>(find.byType(TextField).first);
        expect(
          field.decoration!
              .applyDefaults(AppTheme.build(brightness).inputDecorationTheme)
              .focusedBorder,
          isA<OutlineInputBorder>(),
        );
        await t.enterText(find.byType(TextFormField).first, 'Đi Ba Vì');
        expect(controller.text, 'Đi Ba Vì');
        await shot(t, 'field-states-keyboard', brightness);
        await t.pumpWidget(const SizedBox());
        focus.dispose();
        controller.dispose();
        await t.binding.setSurfaceSize(null);
      },
    );
  }
  testWidgets(
    'member hub hides owner/admin actions and honors granted edit capability',
    (t) async {
      final repo = _Groups(role: GroupRole.member);
      await mount(t, info(repo), Brightness.light);
      await t.drag(find.byType(ListView), const Offset(0, -1800));
      await t.pumpAndSettle();
      expect(find.text('Xóa nhóm'), findsNothing);
      expect(find.text('Chuyển quyền trưởng nhóm'), findsNothing);
      expect(find.text('Mã QR & liên kết mời'), findsNothing);
      expect(find.text('Yêu cầu tham gia'), findsNothing);
      expect(repo.joinReads, 0);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      repo.allowMemberEdit = true;
      await mount(t, info(repo), Brightness.light);
      expect(find.text('Sửa thông tin nhóm'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.binding.setSurfaceSize(null);
    },
  );

  for (final brightness in Brightness.values) {
    for (final device in ['android', 'iphone']) {
      for (final name in ['home', 'community', 'messages', 'calendar', 'profile', 'group', 'activity', 'form', 'home-large-text', 'home-empty', 'community-hidden', 'community-restored', 'community-search', 'group-list', 'community-search-people', 'login', 'register', 'recruitment']) {
        testWidgets('monochrome $name $device $brightness actual widget screenshot', (t) async {
          final dio = _rootDio(); final groups = _Groups(); final fixture = journey_fixture.Api();
          const user = CurrentUser(id: 'owner', email: 'qa@example.test', status: 'ACTIVE', emailVerified: true);
          Widget home() => HomeScreen(controller: HomeController(_Home(emptyGroups: name == 'home-empty')), onOpenGroup: (_) {}, onOpenActivity: (_) {}, onOpenBalance: (_) {}, onOpenAction: (_) {}, onOpenUpdate: (_) {}, onGroups: () {}, onChat: () {}, onCalendar: () {}, onProfile: () {}, onNotifications: () {});
          final Widget page = switch(name) {
            'home' || 'home-large-text' || 'home-empty' => home(),
            'community' || 'community-hidden' || 'community-restored' || 'community-search' => CommunityScreen(api: CommunityApi(dio), rootTab: true),
            'messages' => ChatHomeScreen(repository: ChatRepository(ChatApi(dio)), onGroups: () {}, onOpenConversation: (_) {}),
            'calendar' => CalendarScreen(repository: CalendarRepository(CalendarApi(dio)), groups: groups, onOpenActivity: (_) {}, onGroups: () {}, onChat: () {}, onProfile: () {}),
            'profile' => ProfileScreen(loadCurrentUser: () async => user, updateProfile: (_) async => user, updateUsername: (_) async => user, changePassword: ({required currentPassword, required newPassword}) async {}, endSessionAfterPasswordChange: () async => true, onHome: () {}, logout: () async {}),
            'login' => LoginScreen(onCreateAccount: () {}),
            'register' => RegisterScreen(onLoginPressed: () {}),
            'recruitment' => RecruitmentDiscovery(api: RecruitmentApi(dio), viewer: 'owner'),
            'group' => info(groups),
            'group-list' => MyGroupsScreen(controller: GroupsController(groups), onCreate: () {}, onOpenGroup: (_) {}, onJoinByCode: () {}, onInvitations: () {}),
            'community-search-people' => SearchScreen(controller: search.SearchController(SearchRepository(SearchApi(dio))), profileRepository: ProfileRepository(api: ProfileApi(dio)), groupRepository: groups, onOpenPerson: (_) {}, onOpenGroup: (_) {}, onOpenActivity: (_) {}, onOpenConversation: (_) {}),
            'activity' => ActivityDetailRuntimeScreen(activityId: 'a', controller: ActivityDetailController(ActivityRepository(api: ActivityApi(fixture.dio))), onOpenJourney: () {}, onOpenPolls: () {}, onOpenTasks: () {}, onOpenMemories: (_) {}),
            _ => CreateGroupScreen(controller: CreateGroupController(groups), onCreated: (_) {}),
          };
          await mount(t, page, brightness, viewport: device == 'android' ? const Size(360, 780) : const Size(430, 932), textScale: name == 'home-large-text' ? 1.5 : 1);
          if (name == 'community-hidden' || name == 'community-restored') {
            await t.drag(find.byType(ListView), const Offset(0, -180)); await t.pumpAndSettle();
            if (name == 'community-restored') { await t.drag(find.byType(ListView), const Offset(0, 90)); await t.pumpAndSettle(); }
          }
          if (name == 'community-search') { await t.tap(find.byTooltip('Tìm kiếm Cộng đồng')); await t.pumpAndSettle(); }
          await shot(t, 'mono-$name-$device', brightness);
          await t.pumpWidget(const SizedBox()); await t.binding.setSurfaceSize(null);
        });
      }
    }
  }
  test(
    'pending badge uses authoritative total for managers only and refreshes',
    () async {
      for (final role in [GroupRole.owner, GroupRole.admin, GroupRole.member]) {
        final repo = _Groups(role: role)..pendingTotal = 7;
        final controller = GroupDetailController(repo, readSettings: true);
        await controller.load('g');
        expect(
          controller.value.pendingJoinRequestCount,
          role == GroupRole.member ? isNull : 7,
        );
        expect(repo.joinReads, role == GroupRole.member ? 0 : 1);
        repo.pendingTotal = 2;
        await controller.resync('g');
        expect(
          controller.value.pendingJoinRequestCount,
          role == GroupRole.member ? isNull : 2,
        );
        controller.dispose();
      }
    },
  );
}
