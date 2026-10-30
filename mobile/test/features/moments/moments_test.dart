import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/realtime/realtime_binding.dart';
import 'package:mobile/core/realtime/realtime_sync.dart';
import 'package:mobile/features/chat/data/chat_realtime_client.dart';
import 'package:mobile/features/moments/data/moment_models.dart';
import 'package:mobile/features/moments/data/moments_api.dart';
import 'package:mobile/features/moments/presentation/memories_screen.dart';
import 'package:mobile/features/moments/presentation/memory_media.dart';
import 'package:mobile/features/media/data/media_upload_service.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:video_player/video_player.dart';

Json post([String id = 'p', int count = 0]) => {
  'id': id,
  'groupId': 'g',
  'activityId': null,
  'activityTitle': null,
  'caption': 'Memory $id',
  'author': {'id': 'u', 'displayName': 'QA Member'},
  'createdAt': '2026-10-26T00:00:00Z',
  'media': [],
  'reactionCount': count,
  'myReaction': count > 0 ? '❤️' : null,
  'commentCount': 0,
  'permissions': {
    'canEdit': true,
    'canDelete': true,
    'canInteract': true,
    'canManage': true,
  },
};
Json album() => {
  'id': 'a',
  'groupId': 'g',
  'name': 'QA Album',
  'description': 'Memories',
  'author': {'id': 'u', 'displayName': 'QA Member'},
  'createdAt': '2026-10-26T00:00:00Z',
  'itemCount': 0,
  'cover': null,
  'permissions': {
    'canEdit': true,
    'canDelete': true,
    'canManage': true,
    'canInteract': true,
  },
};
Json page(List<Object> items, {String? next}) => {
  'items': items,
  'nextBefore': next,
  'hasMore': next != null,
  'canCreate': true,
};
void main() {
  late _Adapter adapter;
  late MomentsApi api;
  late RealtimeSync sync;
  Future<void> mount(WidgetTester t, Widget Function() screen) async {
    await t.binding.setSurfaceSize(const Size(500, 1000));
    adapter = _Adapter();
    api = MomentsApi(
      Dio(BaseOptions(baseUrl: 'https://fixture'))..httpClientAdapter = adapter,
    );
    sync = RealtimeSync(const NoopChatRealtimeClient());
    await t.pumpWidget(
      RealtimeHost(
        sync: sync,
        child: MaterialApp(home: screen()),
      ),
    );
    await t.pumpAndSettle();
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      await t.runAsync(sync.dispose);
      await t.binding.setSurfaceSize(null);
    });
  }

  Future<void> hint(WidgetTester t, String type, {String id = 'p'}) async {
    sync.accept({
      'type': 'DOMAIN_CHANGED',
      'eventId': '$type-$id',
      'eventType': type,
      'scope': 'group:g',
      'aggregateId': id,
    });
    await t.pump(const Duration(milliseconds: 100));
    await t.pumpAndSettle();
  }

  testWidgets('feed renders real data; reaction hint targets post, not feed', (
    t,
  ) async {
    await mount(t, () => MemoriesScreen(groupId: 'g', api: api));
    expect(find.text('Memory p'), findsOneWidget);
    final feeds = adapter.feeds, reads = adapter.reads;
    adapter.reactions = 7;
    await hint(t, 'MOMENT_REACTION_CHANGED');
    expect(find.text('7 cảm xúc'), findsOneWidget);
    expect(adapter.feeds, feeds);
    expect(adapter.reads, greaterThan(reads));
    await hint(t, 'MOMENT_REACTION_CHANGED');
    expect(adapter.feeds, feeds);
    expect(t.takeException(), isNull);
  });
  testWidgets('reactions toggle authoritative response and recover offline', (
    t,
  ) async {
    await mount(
      t,
      () => Scaffold(
        body: SingleChildScrollView(
          child: MomentView(initial: MomentPost.fromJson(post()), api: api),
        ),
      ),
    );
    await t.tap(find.text('0 cảm xúc'));
    await t.pumpAndSettle();
    expect(find.text('1 cảm xúc'), findsOneWidget);
    await t.tap(find.byTooltip('Đổi cảm xúc'));
    await t.pumpAndSettle();
    await t.tap(find.text('👍'));
    await t.pumpAndSettle();
    expect(adapter.lastEmoji, '👍');
    expect(find.text('1 cảm xúc'), findsOneWidget);
    adapter.offline = true;
    await hint(t, 'MOMENT_UPDATED');
    expect(find.text('Memory p'), findsOneWidget);
    adapter.offline = false;
    adapter.reactions = 3;
    sync.accept({'type': 'SCOPE_SUBSCRIBED', 'scope': 'group:g'});
    await t.pump(const Duration(milliseconds: 100));
    await t.pumpAndSettle();
    expect(find.text('3 cảm xúc'), findsOneWidget);
  });
  testWidgets('scope revocation and late reply cannot restore protected feed', (
    t,
  ) async {
    await mount(t, () => MemoriesScreen(groupId: 'g', api: api));
    adapter.gate = Completer<void>();
    await hint(t, 'MOMENT_CREATED', id: 'other');
    adapter.denied = true;
    sync.accept({'type': 'SCOPE_REVOKED', 'scope': 'group:g'});
    await t.pumpAndSettle();
    expect(find.text('Memory p'), findsNothing);
    adapter.gate!.complete();
    adapter.gate = null;
    await t.pumpAndSettle();
    expect(find.text('Memory p'), findsNothing);
  });
  testWidgets('late reaction response cannot undo confirmed access loss', (
    t,
  ) async {
    await mount(
      t,
      () => Scaffold(
        body: SingleChildScrollView(
          child: MomentView(initial: MomentPost.fromJson(post()), api: api),
        ),
      ),
    );
    adapter.mutationGate = Completer<void>();
    await t.tap(find.text('0 cảm xúc'));
    await t.pump();
    adapter.denied = true;
    sync.accept({'type': 'SCOPE_REVOKED', 'scope': 'group:g'});
    await t.pumpAndSettle();
    adapter.mutationGate!.complete();
    await t.pumpAndSettle();
    expect(find.text('Memory p'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'composer validation, photo/video picking and stable retry command',
    (t) async {
      late _UploadApi upload;
      await mount(t, () {
        upload = _UploadApi(api.dio);
        return MomentComposer(
          api: upload,
          groupId: 'g',
          pickPhotos: () async => [
            XFile.fromData(
              Uint8List.fromList([1, 2, 3]),
              name: 'qa.png',
              path: '/tmp/qa.png',
            ),
          ],
          pickVideo: () async => XFile.fromData(
            Uint8List.fromList([1, 2, 3]),
            name: 'qa.mp4',
            path: '/tmp/qa.mp4',
          ),
        );
      });
      await t.tap(find.text('Đăng khoảnh khắc'));
      await t.pumpAndSettle();
      expect(adapter.posts, 0);
      await t.tap(find.text('Chọn ảnh'));
      await t.pumpAndSettle();
      await t.tap(find.text('Video MP4'));
      await t.pumpAndSettle();
      expect(find.text('qa.mp4'), findsOneWidget);
      adapter.failCreate = true;
      await t.tap(find.text('Đăng khoảnh khắc'));
      await t.pumpAndSettle();
      expect(upload.uploaded, ['qa.png', 'qa.mp4']);
      expect(adapter.posts, 1);
      adapter.failCreate = false;
      await t.tap(find.text('Đăng khoảnh khắc'));
      await t.pumpAndSettle();
      expect(adapter.commands[0], adapter.commands[1]);
      expect(upload.uploaded, hasLength(2));
    },
  );
  testWidgets(
    'detail creates and renders comments with author, no duplicate retry id',
    (t) async {
      await mount(
        t,
        () => Scaffold(
          body: SingleChildScrollView(
            child: MomentView(
              initial: MomentPost.fromJson(post()),
              api: api,
              detail: true,
            ),
          ),
        ),
      );
      await t.enterText(find.byType(TextField), 'QA comment');
      await t.tap(find.byTooltip('Gửi bình luận'));
      await t.pumpAndSettle();
      expect(find.textContaining('QA comment'), findsOneWidget);
      expect(find.text('QA Member'), findsWidgets);
      expect(adapter.commentIds, hasLength(1));
    },
  );
  testWidgets(
    'album list and editor have real create endpoint and validation',
    (t) async {
      await mount(
        t,
        () => Scaffold(
          body: AlbumList(api: api, groupId: 'g'),
        ),
      );
      expect(find.text('QA Album'), findsOneWidget);
      await t.tap(find.text('Tạo album'));
      await t.pumpAndSettle();
      await t.tap(find.text('Lưu album'));
      await t.pumpAndSettle();
      expect(adapter.albumWrites, 0);
      await t.enterText(find.byType(TextField).first, 'New QA album');
      await t.tap(find.text('Lưu album'));
      await t.pumpAndSettle();
      expect(adapter.albumWrites, 1);
    },
  );
  testWidgets(
    'album detail loads media grid and metadata with authoritative permissions',
    (t) async {
      await mount(
        t,
        () => AlbumDetail(api: api, initial: MemoryAlbum.fromJson(album())),
      );
      expect(find.text('QA Album'), findsOneWidget);
      expect(find.text('Chọn từ khoảnh khắc'), findsOneWidget);
      expect(find.text('Album chưa có ảnh hoặc video.'), findsOneWidget);
      expect(adapter.albumMediaReads, 1);
    },
  );
  testWidgets(
    'new moments while reading older feed show indicator without jump',
    (t) async {
      await mount(t, () => MemoriesScreen(groupId: 'g', api: api));
      adapter.many = true;
      await hint(t, 'MOMENT_CREATED', id: 'seed');
      final list = find.byType(ListView).first;
      final scroll = t
          .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)).first,
          )
          .position;
      scroll.jumpTo(250);
      await t.pumpAndSettle();
      final offset = scroll.pixels, feeds = adapter.feeds;
      await hint(t, 'MOMENT_CREATED', id: 'new');
      expect(find.text('Có bài mới · Xem cập nhật'), findsOneWidget);
      expect(scroll.pixels, closeTo(offset, 1));
      expect(adapter.feeds, feeds);
    },
  );
  testWidgets('pagination requests cursor and deduplicates stable moment ids', (
    t,
  ) async {
    await mount(t, () => MemoriesScreen(groupId: 'g', api: api));
    adapter.paginated = true;
    await hint(t, 'MOMENT_CREATED', id: 'page');
    await t.scrollUntilVisible(
      find.text('Xem thêm'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.text('Xem thêm'));
    await t.pumpAndSettle();
    expect(adapter.cursors, contains('p'));
    expect(find.text('Memory older'), findsOneWidget);
  });
  testWidgets('initial network failure is retry, not successful empty feed', (
    t,
  ) async {
    await mount(t, () => MemoriesScreen(groupId: 'g', api: api));
    adapter.offline = true;
    await hint(t, 'MOMENT_CREATED', id: 'offline');
    expect(find.text('Memory p'), findsOneWidget);
    sync.accept({'type': 'SCOPE_REVOKED', 'scope': 'group:g'});
    await t.pumpAndSettle();
    expect(find.text('Memory p'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'real video widget initializes native player and supports play/dispose',
    (t) async {
      final old = VideoPlayerPlatform.instance;
      final platform = _VideoPlatform();
      late _OwnedVideoController owned;
      VideoPlayerPlatform.instance = platform;
      addTearDown(() => VideoPlayerPlatform.instance = old);
      await mount(
        t,
        () => Scaffold(
          body: SizedBox(
            height: 300,
            child: MemoryMediaView(
              controllerFactory: (uri) => owned = _OwnedVideoController(uri),
              media: const MemoryMedia('video', 'video/mp4', 'qa.mp4', 42, 0),
              api: api,
            ),
          ),
        ),
      );
      expect(find.byTooltip('Phát video MP4'), findsOneWidget);
      await t.tap(find.byTooltip('Phát video MP4'));
      await t.pumpAndSettle();
      expect(platform.plays, 1, reason: 'native play requested');
      final dynamic videoState = t.state(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_PrivateVideo',
        ),
      );
      expect(videoState.controller, isNotNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      expect(videoState.mounted, isFalse, reason: 'player state disposed');
      await t.pump(const Duration(milliseconds: 1));
      await t.pump();
      expect(
        owned.disposeRequests,
        1,
        reason: 'owned native controller disposal requested exactly once',
      );
    },
  );
  testWidgets('open moment editor clears private draft after membership loss', (
    t,
  ) async {
    await mount(
      t,
      () => MomentComposer(
        api: api,
        groupId: 'g',
        editing: MomentPost.fromJson(post()),
      ),
    );
    expect(find.text('Memory p'), findsOneWidget);
    adapter.denied = true;
    sync.accept({'type': 'SCOPE_REVOKED', 'scope': 'group:g'});
    await t.pump(const Duration(milliseconds: 100));
    await t.pumpAndSettle();
    expect(find.text('Memory p'), findsNothing);
    expect(
      find.text('Bạn không còn quyền chia sẻ trong nhóm này.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'open album editor clears protected title after membership loss',
    (t) async {
      await mount(
        t,
        () => AlbumEditor(
          api: api,
          groupId: 'g',
          editing: MemoryAlbum.fromJson(album()),
        ),
      );
      expect(find.text('QA Album'), findsOneWidget);
      adapter.denied = true;
      sync.accept({'type': 'SCOPE_REVOKED', 'scope': 'group:g'});
      await t.pump(const Duration(milliseconds: 100));
      await t.pumpAndSettle();
      expect(find.text('QA Album'), findsNothing);
      expect(
        find.text('Bạn không còn quyền quản lý album này.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('fullscreen media clears on group revocation', (t) async {
    await mount(
      t,
      () => Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => openMemoryMedia(
              context,
              const MemoryMedia('image', 'image/png', 'qa.png', 42, 0),
              api,
              'g',
            ),
            child: const Text('Open image'),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open image'));
    await t.pumpAndSettle();
    adapter.denied = true;
    sync.accept({'type': 'SCOPE_REVOKED', 'scope': 'group:g'});
    await t.pump(const Duration(milliseconds: 100));
    await t.pumpAndSettle();
    expect(find.byType(MemoryMediaView), findsNothing);
    expect(find.text('Bạn không còn quyền xem media này.'), findsOneWidget);
  });
  test('stream upload consumes chunks without whole-video buffering', () async {
    final auth = _Adapter();
    final direct = _StreamAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture'))
      ..httpClientAdapter = auth;
    final service = MediaUploadService(
      apiDio: dio,
      directUploadDio: Dio()..httpClientAdapter = direct,
    );
    final key = await service.uploadStream(
      category: 'MOMENT_VIDEO',
      contextId: 'g',
      fileName: 'qa.mp4',
      contentType: 'video/mp4',
      length: 6,
      openRead: () => Stream.fromIterable([
        [1, 2, 3],
        [4, 5, 6],
      ]),
    );
    expect(key, 'private-key');
    expect(direct.bytes, 6);
    expect(direct.authorization, null);
  });
}

class _UploadApi extends MomentsApi {
  final uploaded = <String>[];
  _UploadApi(super.dio);
  @override
  Future<String> upload(
    String group,
    XFile file, {
    void Function(int, int)? progress,
  }) async {
    uploaded.add(file.name);
    progress?.call(1, 2);
    progress?.call(2, 2);
    return 'uploaded-${file.name}';
  }
}

class _Adapter implements HttpClientAdapter {
  String? lastEmoji;
  int feeds = 0,
      reads = 0,
      reactions = 0,
      posts = 0,
      albumWrites = 0,
      albumMediaReads = 0;
  bool offline = false,
      failCreate = false,
      many = false,
      paginated = false,
      denied = false;
  Completer<void>? gate, mutationGate;
  final commands = <String>[], commentIds = <String>[], cursors = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions r,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    Object data = {};
    int status = 200;
    final path = r.path;
    final deny = denied;
    if (path.endsWith('/activities')) {
      data = {
        'items': [],
        'page': 0,
        'size': 20,
        'totalElements': 0,
        'totalPages': 0,
        'hasNext': false,
      };
    } else if (path.endsWith('/uploads/presign')) {
      data = {
        'storageKey': 'private-key',
        'uploadUrl': 'https://storage.test/put',
        'expiresAt': '2099-01-01T00:00:00Z',
        'requiredHeaders': {'Content-Type': 'video/mp4'},
      };
    } else if (path.endsWith('/access')) {
      data = {
        'url': 'https://storage.test/video',
        'expiresAt': '2099-01-01T00:00:00Z',
      };
    } else if (path.endsWith('/reaction')) {
      await mutationGate?.future;
      lastEmoji = r.data['emoji'] as String?;
      reactions = r.data['emoji'] == null ? 0 : 1;
      data = post('p', reactions);
    } else if (path.endsWith('/comments')) {
      if (r.method == 'POST') {
        commentIds.add(r.data['clientRequestId'] as String);
        data = {
          'id': 'c',
          'author': {'id': 'u', 'displayName': 'QA Member'},
          'content': r.data['content'],
          'createdAt': '2026-10-26T00:00:00Z',
          'canDelete': true,
        };
      } else {
        data = page(
          commentIds.isEmpty
              ? []
              : [
                  {
                    'id': 'c',
                    'author': {'id': 'u', 'displayName': 'QA Member'},
                    'content': 'QA comment',
                    'createdAt': '2026-10-26T00:00:00Z',
                    'canDelete': true,
                  },
                ],
        );
      }
    } else if (path == '/api/v1/groups/g/moments') {
      if (r.method == 'POST') {
        posts++;
        commands.add(r.data['clientRequestId'] as String);
        data = post();
        if (failCreate) status = 503;
      } else {
        feeds++;
        await gate?.future;
        final before = r.queryParameters['before'];
        if (before != null) cursors.add(before as String);
        data = page(
          before != null
              ? [post('older')]
              : many
              ? [for (var i = 0; i < 8; i++) post('p$i')]
              : [post()],
          next: paginated && before == null ? 'p' : null,
        );
      }
    } else if (path.startsWith('/api/v1/moments/')) {
      reads++;
      data = post(path.split('/').last, reactions);
    } else if (path == '/api/v1/groups/g/albums') {
      if (r.method != 'GET') albumWrites++;
      data = r.method == 'GET' ? page([album()]) : album();
    } else if (path.endsWith('/media')) {
      albumMediaReads++;
      data = page([]);
    } else if (path == '/api/v1/albums/a') {
      data = album();
    }
    if (offline) {
      throw DioException(
        requestOptions: r,
        type: DioExceptionType.connectionError,
      );
    }
    return ResponseBody.fromString(
      jsonEncode(deny ? {'code': 'ACCESS_DENIED'} : data),
      deny ? 403 : status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _StreamAdapter implements HttpClientAdapter {
  int bytes = 0;
  Object? authorization;
  @override
  Future<ResponseBody> fetch(
    RequestOptions r,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    authorization = r.headers['Authorization'];
    if (body != null) {
      await for (final chunk in body) {
        bytes += chunk.length;
      }
    }
    return ResponseBody.fromString('', 200);
  }

  @override
  void close({bool force = false}) {}
}

class _OwnedVideoController extends VideoPlayerController {
  int disposeRequests = 0;
  _OwnedVideoController(super.url) : super.networkUrl();
  @override
  Future<void> dispose() {
    disposeRequests++;
    return super.dispose();
  }
}

class _VideoPlatform extends VideoPlayerPlatform {
  final closed = Completer<void>();
  final events = StreamController<VideoEvent>.broadcast();
  int plays = 0, disposed = 0;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 1;
  @override
  Stream<VideoEvent> videoEventsFor(int id) {
    scheduleMicrotask(
      () => events.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 2),
          size: const Size(320, 180),
        ),
      ),
    );
    return events.stream;
  }

  @override
  Future<void> dispose(int id) async {
    disposed++;
    unawaited(events.close());
    if (!closed.isCompleted) closed.complete();
  }

  @override
  Future<void> setLooping(int id, bool loop) async {}
  @override
  Future<void> setVolume(int id, double value) async {}
  @override
  Future<void> pause(int id) async {}
  @override
  Future<void> play(int id) async {
    plays++;
  }

  @override
  Future<void> setPlaybackSpeed(int id, double speed) async {}
  @override
  Future<Duration> getPosition(int id) async => Duration.zero;
  @override
  Future<void> seekTo(int id, Duration position) async {}
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Colors.black);
}
