import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/realtime/realtime_binding.dart';
import 'package:mobile/core/realtime/realtime_sync.dart';
import 'package:mobile/features/chat/data/chat_realtime_client.dart';
import 'package:mobile/features/community/data/community_api.dart';
import 'package:mobile/features/community/presentation/community_screen.dart';
import 'package:mobile/features/moments/data/moment_models.dart';
import 'package:mobile/features/moments/presentation/memory_media.dart';

Json post([String id = 'p', int reactions = 0]) => {
  'id': id,
  'caption': 'Community $id',
  'visibility': 'PUBLIC',
  'groupId': null,
  'author': {'id': 'author', 'displayName': 'QA Author'},
  'createdAt': '2026-10-27T00:00:00Z',
  'media': [],
  'reactionCount': reactions,
  'commentCount': 0,
  'myReaction': reactions > 0 ? '❤️' : null,
  'permissions': {'canEdit': true, 'canDelete': true, 'canInteract': true},
};
Json page(List<Object> items, {String? next}) => {
  'items': items,
  'nextBefore': next,
  'hasMore': next != null,
};

void main() {
  late FakeAdapter adapter;
  late CommunityApi api;
  late RealtimeSync sync;
  Future<void> mount(
    WidgetTester t,
    Widget Function() child, {
    Brightness brightness = Brightness.light,
    Size size = const Size(500, 950),
  }) async {
    await t.binding.setSurfaceSize(size);
    adapter = FakeAdapter();
    api = CommunityApi(
      Dio(BaseOptions(baseUrl: 'https://fixture'))..httpClientAdapter = adapter,
    );
    sync = RealtimeSync(const NoopChatRealtimeClient());
    await t.pumpWidget(
      RealtimeHost(
        sync: sync,
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: child(),
        ),
      ),
    );
    await t.pumpAndSettle();
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      await t.runAsync(sync.dispose);
      await t.binding.setSurfaceSize(null);
    });
  }

  Future<void> event(
    WidgetTester t,
    String scope,
    String type, {
    String id = 'p',
    String? eventId,
  }) async {
    sync.accept({
      'type': 'DOMAIN_CHANGED',
      'scope': scope,
      'eventId': eventId ?? '$type-$id',
      'eventType': type,
      'aggregateId': id,
    });
    await t.pump(const Duration(milliseconds: 100));
    await t.pumpAndSettle();
  }

  testWidgets(
    'For You and Friends are real separate reads; recruitment shows real empty discovery',
    (t) async {
      await mount(t, () => CommunityScreen(api: api));
      expect(find.text('Community p'), findsOneWidget);
      expect(adapter.modes.last, 'FOR_YOU');
      await t.tap(find.text('Bạn bè'));
      await t.pumpAndSettle();
      expect(adapter.modes.last, 'FRIENDS');
      await t.tap(find.text('Tìm người đồng hành'));
      await t.pumpAndSettle();
      expect(find.text('Chưa có tin tuyển phù hợp đang mở.'), findsOneWidget);
    },
  );
  testWidgets('new-post indicator preserves scroll and does not refetch feed', (
    t,
  ) async {
    await mount(t, () {
      adapter.many = true;
      return CommunityScreen(api: api);
    });
    await t.drag(find.byType(ListView).first, const Offset(0, -500));
    await t.pumpAndSettle();
    final scroll = t.state<ScrollableState>(find.byType(Scrollable).first);
    final position = scroll.position.pixels;
    expect(position, greaterThan(0));
    final before = adapter.feeds;
    await event(t, 'community:viewer', 'COMMUNITY_POST_CREATED', id: 'new');
    expect(scroll.position.pixels, position);
    expect(adapter.feeds, before);
    expect(find.text('Có bài viết mới · Xem cập nhật'), findsOneWidget);
    await t.tap(find.text('Có bài viết mới · Xem cập nhật'));
    await t.pumpAndSettle();
    expect(adapter.feeds, before + 1);
  });
  testWidgets(
    'reaction hint refreshes only visible resource and deduplicates',
    (t) async {
      await mount(t, () => CommunityScreen(api: api));
      final feeds = adapter.feeds, reads = adapter.reads;
      adapter.reactions = 3;
      await event(t, 'post:p', 'COMMUNITY_REACTION_CHANGED');
      await event(t, 'post:p', 'COMMUNITY_REACTION_CHANGED');
      expect(adapter.feeds, feeds);
      expect(adapter.reads, reads + 1);
      expect(find.text('3 cảm xúc'), findsOneWidget);
    },
  );
  testWidgets(
    'offline retains last valid content; resubscribe restores authoritative state',
    (t) async {
      await mount(t, () => CommunityScreen(api: api));
      adapter.offline = true;
      await event(t, 'post:p', 'COMMUNITY_POST_UPDATED');
      expect(find.text('Community p'), findsOneWidget);
      expect(t.takeException(), isNull);
      adapter.offline = false;
      adapter.reactions = 4;
      sync.accept({'type': 'SCOPE_SUBSCRIBED', 'scope': 'post:p'});
      await t.pump(const Duration(milliseconds: 100));
      await t.pumpAndSettle();
      expect(find.text('4 cảm xúc'), findsOneWidget);
    },
  );
  testWidgets('policy clears cache immediately even if REST is offline', (
    t,
  ) async {
    await mount(t, () => CommunityScreen(api: api));
    adapter.offline = true;
    sync.accept({
      'type': 'DOMAIN_CHANGED',
      'scope': 'community:viewer',
      'eventId': 'policy',
      'eventType': 'COMMUNITY_POLICY_CHANGED',
      'aggregateId': 'viewer',
    });
    await t.pump();
    expect(find.text('Community p'), findsNothing);
    await t.pump(const Duration(milliseconds: 100));
    await t.pumpAndSettle();
    expect(find.text('Community p'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'revocation and late successful response cannot restore protected content',
    (t) async {
      await mount(
        t,
        () => Scaffold(
          body: SingleChildScrollView(
            child: CommunityCard(
              api: api,
              initial: CommunityPost(post()),
              viewer: 'viewer',
            ),
          ),
        ),
      );
      adapter.gate = Completer<void>();
      sync.accept({
        'type': 'DOMAIN_CHANGED',
        'scope': 'post:p',
        'eventId': 'wait',
        'eventType': 'COMMUNITY_POST_UPDATED',
        'aggregateId': 'p',
      });
      await t.pump(const Duration(milliseconds: 100));
      adapter.denied = true;
      sync.accept({'type': 'SCOPE_REVOKED', 'scope': 'post:p'});
      await t.pump();
      expect(find.text('Community p'), findsNothing);
      adapter.gate!.complete();
      adapter.gate = null;
      await t.pumpAndSettle();
      expect(find.text('Community p'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('disposed card ignores late mutation and does not update UI', (
    t,
  ) async {
    final show = ValueNotifier(true);
    addTearDown(show.dispose);
    await mount(
      t,
      () => Scaffold(
        body: ValueListenableBuilder(
          valueListenable: show,
          builder: (_, visible, _) => visible
              ? SingleChildScrollView(
                  child: CommunityCard(
                    api: api,
                    initial: CommunityPost(post()),
                    viewer: 'viewer',
                  ),
                )
              : const Text('Closed'),
        ),
      ),
    );
    adapter.mutationGate = Completer<void>();
    await t.tap(find.text('0 cảm xúc'));
    await t.pump();
    show.value = false;
    await t.pump();
    adapter.mutationGate!.complete();
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Closed'), findsOneWidget);
  });
  testWidgets(
    'cursor metadata follows request generation and pages deduplicate',
    (t) async {
      await mount(t, () { adapter.paginated = true; return CommunityScreen(api: api); });
      await t.scrollUntilVisible(find.text('Xem bài cũ hơn'), 300);
      await t.tap(find.text('Xem bài cũ hơn'));
      await t.pumpAndSettle();
      expect(adapter.cursors, contains('p'));
      expect(find.text('Community older'), findsOneWidget);
      sync.resync();
      await t.pump(const Duration(milliseconds: 100));
      await t.pumpAndSettle();
      expect(find.text('Community older'), findsOneWidget);
    },
  );
  testWidgets('ranked feed keeps accepted order on community reaction hint and reconnect', (t) async {
    await mount(t, () { adapter.rankedOrder = ['a','b']; return CommunityScreen(api: api); });
    final feeds = adapter.feeds;
    adapter.rankedOrder = ['b','a']; adapter.reactions = 7;
    await event(t, 'community:viewer', 'COMMUNITY_REACTION_CHANGED', id: 'a');
    expect(adapter.feeds, feeds);
    var cards = t.widgetList<CommunityCard>(find.byType(CommunityCard)).map((w) => w.initial.id).toList();
    expect(cards, ['a','b']);
    sync.resync(); await t.pump(const Duration(milliseconds:100)); await t.pumpAndSettle();
    expect(adapter.feeds, feeds + 1); // bounded discovery check, no list replacement
    cards = t.widgetList<CommunityCard>(find.byType(CommunityCard)).map((w) => w.initial.id).toList();
    expect(cards, ['a','b']);
  });
  testWidgets('For You tab cache preserves ranked cursor depth and scroll after Friends', (t) async {
    await mount(t, () { adapter.many = true; adapter.paginated = true; return CommunityScreen(api: api); });
    await t.drag(find.byType(ListView).first,const Offset(0,-450)); await t.pumpAndSettle();
    final before=t.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;
    expect(before,greaterThan(0));
    await t.tap(find.text('Bạn bè')); await t.pumpAndSettle();
    final feeds=adapter.feeds;
    await t.tap(find.text('Dành cho bạn')); await t.pumpAndSettle(); await t.pump();
    expect(adapter.feeds,feeds);
    expect(t.state<ScrollableState>(find.byType(Scrollable).first).position.pixels,closeTo(before,1));
  });
  testWidgets('expired opaque cursor preserves visible posts and offers explicit refresh', (t) async {
    await mount(t, () { adapter.paginated=true; return CommunityScreen(api: api); });
    adapter.expiredCursor=true;
    await t.scrollUntilVisible(find.text('Xem bài cũ hơn'),300);
    await t.tap(find.text('Xem bài cũ hơn')); await t.pumpAndSettle();
    expect(find.text('Community p'),findsOneWidget);
    expect(find.text('Phiên danh sách đã hết hạn · Tải lại'),findsOneWidget);
    expect(t.takeException(),isNull);
    adapter.expiredCursor=false;
    await t.tap(find.text('Phiên danh sách đã hết hạn · Tải lại'));await t.pumpAndSettle();
    expect(find.text('Phiên danh sách đã hết hạn · Tải lại'),findsNothing);
  });
  testWidgets('policy clears cached tabs and denied responses cannot resurrect protected cards', (t) async {
    await mount(t, () => CommunityScreen(api: api));
    await t.tap(find.text('Bạn bè')); await t.pumpAndSettle();
    adapter.denied=true;
    await event(t,'community:viewer','COMMUNITY_POLICY_CHANGED',id:'viewer');
    expect(find.text('Community p'),findsNothing);
    adapter.hidden=true;
    await t.tap(find.text('Dành cho bạn'));await t.pumpAndSettle();
    expect(find.text('Community p'),findsNothing); expect(t.takeException(),isNull);
  });
  testWidgets('targeted deletion removes only affected card without reranking other cards', (t) async {
    await mount(t, () { adapter.rankedOrder=['a','b'];return CommunityScreen(api:api); });
    final feeds=adapter.feeds; adapter.hiddenIds.add('a');
    await event(t,'community:viewer','COMMUNITY_POST_DELETED',id:'a');
    expect(find.text('Community a'),findsNothing);expect(find.text('Community b'),findsOneWidget);
    expect(adapter.feeds,feeds);expect(t.takeException(),isNull);
  });
  testWidgets('reconnect discovers missed posts via indicator without replacing accepted order', (t) async {
    await mount(t, () { adapter.rankedOrder=['a','b'];return CommunityScreen(api:api); });
    adapter.rankedOrder=['new','b','a'];
    sync.resync();await t.pump(const Duration(milliseconds:100));await t.pumpAndSettle();
    expect(find.text('Có bài viết mới · Xem cập nhật'),findsOneWidget);
    expect(find.text('Community new'),findsNothing);
    expect(t.widgetList<CommunityCard>(find.byType(CommunityCard)).map((w)=>w.initial.id).toList(),['a','b']);
  });
  testWidgets('unblock policy restores newly eligible cards without reordering retained cards', (t) async {
    await mount(t, () { adapter.rankedOrder=['a','b'];return CommunityScreen(api:api); });
    adapter.hiddenIds.add('b');
    await event(t,'community:viewer','COMMUNITY_POLICY_CHANGED',id:'viewer',eventId:'blocked');
    expect(find.text('Community b'),findsNothing);
    adapter.hiddenIds.clear();adapter.rankedOrder=['b','a'];
    await event(t,'community:viewer','COMMUNITY_POLICY_CHANGED',id:'viewer',eventId:'unblocked');
    final cards=t.widgetList<CommunityCard>(find.byType(CommunityCard)).map((w)=>w.initial.id).toList();
    expect(cards,['a','b']);expect(t.takeException(),isNull);
  });
  testWidgets('late ranked refresh cannot restore cards after policy loss', (t) async {
    await mount(t, () => CommunityScreen(api: api));
    adapter.gate=Completer<void>();
    sync.resync(); await t.pump(const Duration(milliseconds:100));
    adapter.hidden=true;
    sync.accept({'type':'DOMAIN_CHANGED','scope':'community:viewer','eventId':'revoked','eventType':'COMMUNITY_POLICY_CHANGED','aggregateId':'viewer'});
    await t.pump(); expect(find.text('Community p'),findsNothing);
    adapter.gate!.complete(); await t.pump(const Duration(milliseconds:100)); await t.pumpAndSettle();
    expect(find.text('Community p'),findsNothing); expect(t.takeException(),isNull);
  });
  testWidgets(
    'composer exposes four visibility choices and stable failed-write retry',
    (t) async {
      await mount(t, () => CommunityComposer(api: api, viewer: 'viewer'));
      await t.enterText(find.byType(TextField).first, 'R5 QA');
      await t.tap(find.text('Công khai'));
      await t.pumpAndSettle();
      expect(find.text('Bạn của bạn bè'), findsOneWidget);
      await t.tap(find.text('Bạn bè').last);
      await t.pumpAndSettle();
      adapter.failWrite = true;
      await t.tap(find.text('Đăng bài'));
      await t.pumpAndSettle();
      adapter.failWrite = false;
      await t.tap(find.text('Đăng bài'));
      await t.pumpAndSettle();
      expect(adapter.commands.toSet().length, 1);
      expect(adapter.lastVisibility, 'FRIENDS');
    },
  );
  testWidgets('photo picker uploads only once when the post write is retried', (
    t,
  ) async {
    late UploadApi upload;
    await mount(t, () {
      upload = UploadApi(api.dio);
      return CommunityComposer(
        api: upload,
        viewer: 'viewer',
        pickImages: () async => [
          XFile.fromData(
            Uint8List.fromList([1, 2]),
            name: 'qa.png',
            path: '/tmp/qa.png',
          ),
        ],
      );
    });
    await t.tap(find.text('Chọn ảnh'));
    await t.pumpAndSettle();
    expect(find.text('qa.png'), findsOneWidget);
    adapter.failWrite = true;
    await t.tap(find.text('Đăng bài'));
    await t.pumpAndSettle();
    adapter.failWrite = false;
    await t.tap(find.text('Đăng bài'));
    await t.pumpAndSettle();
    expect(upload.uploadsCount, 1);
    expect(adapter.commands.toSet().length, 1);
  });
  testWidgets(
    'hide and structured report call real endpoints without deleting post',
    (t) async {
      await mount(
        t,
        () => Scaffold(
          body: SingleChildScrollView(
            child: CommunityCard(
              api: api,
              initial: CommunityPost(post()),
              viewer: 'viewer',
            ),
          ),
        ),
      );
      await t.tap(find.byTooltip('Tùy chọn bài viết'));
      await t.pumpAndSettle();
      await t.tap(find.text('Báo cáo: nội dung rác'));
      await t.pumpAndSettle();
      expect(adapter.reportReason, 'SPAM');
      expect(find.text('Community p'), findsOneWidget);
      await t.tap(find.byTooltip('Tùy chọn bài viết'));
      await t.pumpAndSettle();
      await t.tap(find.text('Ẩn khỏi bảng tin'));
      await t.pumpAndSettle();
      expect(adapter.hidden, true);
      expect(find.text('Community p'), findsNothing);
      expect(adapter.deletes, 0);
    },
  );
  testWidgets('detail comments are idempotent on failed response retry', (
    t,
  ) async {
    await mount(
      t,
      () => Scaffold(
        body: SingleChildScrollView(
          child: CommunityCard(
            api: api,
            initial: CommunityPost(post()),
            viewer: 'viewer',
            detail: true,
          ),
        ),
      ),
    );
    await t.enterText(find.byType(TextField), 'QA comment');
    adapter.failComment = true;
    await t.tap(find.byTooltip('Gửi bình luận'));
    await t.pumpAndSettle();
    adapter.failComment = false;
    await t.tap(find.byTooltip('Gửi bình luận'));
    await t.pumpAndSettle();
    expect(adapter.commentCommands.toSet().length, 1);
    expect(find.textContaining('QA comment'), findsOneWidget);
  });
  testWidgets(
    'iOS composer dismisses keyboard on outside touch and explicit control without publishing',
    (t) async {
      await mount(t, () => CommunityComposer(api: api, viewer: 'viewer'));
      await t.enterText(find.byType(TextField), 'R5 caption');
      await t.pumpAndSettle();
      expect(t.testTextInput.isVisible, isTrue);
      await t.tap(find.text('Tối đa 8 ảnh JPG/PNG/WebP · 10 MB mỗi ảnh'));
      await t.pumpAndSettle();
      expect(t.testTextInput.isVisible, isFalse);
      await t.showKeyboard(find.byType(TextField));
      await t.pumpAndSettle();
      expect(t.testTextInput.isVisible, isTrue);
      await t.tap(find.byTooltip('Ẩn bàn phím'));
      await t.pumpAndSettle();
      expect(t.testTextInput.isVisible, isFalse);
      expect(adapter.commands, isEmpty);
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        'R5 caption',
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  testWidgets(
    'iOS comment outside touch dismisses keyboard and retains unsent text',
    (t) async {
      await mount(
        t,
        () => Scaffold(
          appBar: AppBar(title: const Text('QA detail')),
          body: SingleChildScrollView(
            child: CommunityCard(
              api: api,
              initial: CommunityPost(post()),
              viewer: 'viewer',
              detail: true,
            ),
          ),
        ),
      );
      await t.enterText(find.byType(TextField), 'Unsent comment');
      await t.pumpAndSettle();
      expect(t.testTextInput.isVisible, isTrue);
      await t.tap(find.text('Community p'));
      await t.pumpAndSettle();
      expect(t.testTextInput.isVisible, isFalse);
      expect(adapter.commentCommands, isEmpty);
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        'Unsent comment',
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  testWidgets(
    'observer refetches edited caption and removes deleted post without writes',
    (t) async {
      await mount(t, () => CommunityScreen(api: api));
      adapter.captionOverride = 'Author edited caption';
      await event(t, 'post:p', 'COMMUNITY_POST_UPDATED');
      expect(find.text('Author edited caption'), findsOneWidget);
      adapter.hidden = true;
      adapter.denied = true;
      sync.accept({'type': 'SCOPE_REVOKED', 'scope': 'post:p'});
      await t.pump();
      expect(find.text('Author edited caption'), findsNothing);
      await event(
        t,
        'community:viewer',
        'COMMUNITY_POLICY_CHANGED',
        id: 'viewer',
      );
      expect(find.text('Author edited caption'), findsNothing);
      expect(adapter.deletes, 0);
      expect(adapter.commands, isEmpty);
    },
  );
  testWidgets('late reaction reply cannot overwrite newer successful resync', (
    t,
  ) async {
    await mount(
      t,
      () => Scaffold(
        body: SingleChildScrollView(
          child: CommunityCard(
            api: api,
            initial: CommunityPost(post()),
            viewer: 'viewer',
          ),
        ),
      ),
    );
    adapter.mutationGate = Completer<void>();
    await t.tap(find.text('0 cảm xúc'));
    await t.pump();
    adapter.reactions = 3;
    await event(t, 'post:p', 'COMMUNITY_REACTION_CHANGED');
    expect(find.text('3 cảm xúc'), findsOneWidget);
    adapter.mutationGate!.complete();
    await t.pumpAndSettle();
    expect(find.text('3 cảm xúc'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('reaction preserves media widget state and signed URL identity', (
    t,
  ) async {
    await mount(t, () {
      adapter.images = true;
      return Scaffold(
        body: SingleChildScrollView(
          child: CommunityCard(
            api: api,
            initial: CommunityPost(adapter.makePost('p')),
            viewer: 'viewer',
          ),
        ),
      );
    });
    final state = t.state(find.byType(MemoryMediaView));
    final calls = adapter.mediaReads;
    await t.ensureVisible(find.text('0 cảm xúc'));
    await t.tap(find.text('0 cảm xúc'));
    await t.pumpAndSettle();
    expect(identical(state, t.state(find.byType(MemoryMediaView))), isTrue);
    expect(adapter.mediaReads, calls);
  });
  for (final brightness in Brightness.values) {
    testWidgets('narrow ${brightness.name} feed has no overflow', (t) async {
      await mount(
        t,
        () => CommunityScreen(api: api),
        brightness: brightness,
        size: const Size(320, 740),
      );
      expect(t.takeException(), isNull);
      expect(find.text('Community p'), findsOneWidget);
    });
  }
}

class UploadApi extends CommunityApi {
  int uploadsCount = 0;
  UploadApi(super.dio);
  @override
  Future<String> uploadPhoto(
    String viewer,
    XFile file, {
    void Function(int, int)? progress,
  }) async {
    uploadsCount++;
    progress?.call(1, 2);
    progress?.call(2, 2);
    return 'key-qa';
  }
}

class FakeAdapter implements HttpClientAdapter {
  bool many = false;
  String? captionOverride;
  List<String>? rankedOrder;
  bool expiredCursor = false;
  final hiddenIds = <String>{};
  bool images = false;
  int mediaReads = 0;
  Json makePost(String id) => {
    ...post(id, reactions),
    'caption': captionOverride ?? 'Community $id',
    'media': images
        ? [
            {
              'id': 'm',
              'contentType': 'image/png',
              'fileName': 'qa.png',
              'fileSize': 42,
              'sortOrder': 0,
            },
          ]
        : [],
  };
  bool offline = false,
      denied = false,
      paginated = false,
      failWrite = false,
      hidden = false,
      failComment = false;
  int feeds = 0, reads = 0, reactions = 0, deletes = 0;
  String? lastVisibility, reportReason;
  Completer<void>? gate, mutationGate;
  final modes = <String>[],
      cursors = <String>[],
      commands = <String>[],
      commentCommands = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions r,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    if (offline) {
      throw DioException(
        requestOptions: r,
        type: DioExceptionType.connectionError,
      );
    }
    final path = r.path;
    Object data = {};
    int status = 200;
    if (path == '/api/v1/community/recruitments') {
      data = page([]);
    } else if (path == '/api/v1/community/media/m/access') {
      mediaReads++;
      data = {'url': 'https://media.test/image.png'};
    } else if (path == '/api/v1/me') {
      data = {'id': 'viewer'};
    } else if (path == '/api/v1/groups') {
      data = {
        'items': [
          {'id': 'group', 'name': 'QA group'},
        ],
      };
    } else if (path.endsWith('/reaction')) {
      await mutationGate?.future;
      reactions = r.data['emoji'] == null ? 0 : 1;
      data = makePost('p');
    } else if (path.endsWith('/hidden')) {
      hidden = true;
    } else if (path.endsWith('/reports')) {
      reportReason = r.data['reason'] as String;
    } else if (path.endsWith('/comments')) {
      if (r.method == 'POST') {
        commentCommands.add(r.data['clientRequestId'] as String);
        if (failComment) status = 503;
      } else {
        data = page(
          commentCommands.isEmpty
              ? []
              : [
                  {
                    'id': 'c',
                    'content': 'QA comment',
                    'author': {'id': 'viewer', 'displayName': 'QA'},
                    'createdAt': '2026-10-27T00:00:00Z',
                    'canDelete': true,
                  },
                ],
        );
      }
    } else if (path == '/api/v1/community/posts/refresh') {
      reads++;
      if (denied) status = 403;
      data = page((r.data['ids'] as List).cast<String>().where((id) => !hidden && !hiddenIds.contains(id)).map(makePost).toList());
      await gate?.future;
    } else if (path == '/api/v1/community/posts') {
      if (r.method == 'POST') {
        commands.add(r.data['clientRequestId'] as String);
        lastVisibility = r.data['visibility'] as String;
        data = post();
        if (failWrite) status = 503;
      } else {
        feeds++;
        modes.add(r.queryParameters['feed'] as String);
        final cursor = r.queryParameters['before'] as String?;
        if (cursor != null) cursors.add(cursor);
        data = page(
          hidden
              ? []
              : rankedOrder != null
              ? rankedOrder!.where((id)=>!hiddenIds.contains(id)).map(makePost).toList()
              : cursor == null
              ? many
                    ? List.generate(20, (i) => post('p$i', reactions))
                    : [post('p', reactions)]
              : [post('p', reactions), post('older')],
          next: paginated && cursor == null ? 'p' : null,
        );
        if (cursor != null && expiredCursor) { status=400; data={'code':'COMMUNITY_FEED_CURSOR_INVALID'}; }
      }
    } else if (path.contains('/api/v1/community/posts/')) {
      reads++;
      await gate?.future;
      if (denied) status = 403;
      if (hidden || hiddenIds.contains(path.split('/').last)) status = 404;
      data = makePost(path.split('/').last);
      if (r.method == 'DELETE') deletes++;
    }
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
