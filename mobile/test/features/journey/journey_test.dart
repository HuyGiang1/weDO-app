import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/realtime/realtime_binding.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/app/theme/app_colors.dart';
import 'package:mobile/core/realtime/realtime_sync.dart';
import 'package:mobile/features/chat/data/chat_realtime_client.dart';
import 'package:mobile/features/journey/data/journey_api.dart';
import 'package:mobile/features/journey/presentation/journey_screens.dart';
import 'package:mobile/features/journey/presentation/poll_action_screen.dart';
import 'package:mobile/features/task/presentation/screens/task_screens.dart';
import 'package:mobile/features/moments/data/moment_models.dart';
import 'package:mobile/features/moments/presentation/memory_media.dart';

Json stopFixture([String id = 's', String title = 'Leo núi Ba Vì']) => {
  'id': id,
  'activityId': 'a',
  'title': title,
  'notes': 'Mang nước và giày phù hợp.',
  'startsAt': '2026-10-29T02:00:00Z',
  'endsAt': null,
  'locationLabel': 'Cổng vườn quốc gia Ba Vì',
  'organizerId': null,
  'organizerName': null,
  'estimatedCost': null,
  'sortOrder': 0,
  'status': 'PLANNED',
  'updatedAt': '2026-10-28T00:00:00Z',
  'checkInCount': 0,
  'canManage': true,
  'canChangeStatus': true,
  'canCheckIn': true,
};

class Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions r,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    dynamic data = [];
    if (r.path == '/api/v1/groups/g/members') {
      data = [
        {
          'userId': 'm',
          'username': 'member',
          'displayName': 'QA Member 1',
          'role': 'MEMBER',
          'joinedAt': '2026-10-27T00:00:00Z',
        },
      ];
    }
    if (r.path == '/api/v1/polls/p') {
      data = {
        'id': 'p',
        'activityId': 'a',
        'groupId': 'g',
        'createdBy': 'o',
        'question': 'Cuối tuần đi đâu?',
        'pollType': 'MULTIPLE_CHOICE',
        'allowMemberAddOption': false,
        'voteVisibility': 'ANONYMOUS',
        'resultVisibility': 'IMMEDIATE',
        'status': 'OPEN',
        'resultsVisible': true,
        'participantCount': 1,
        'options': [
          {
            'id': 'option',
            'text': 'Leo núi Ba Vì',
            'sortOrder': 0,
            'disabled': false,
            'voteCount': 1,
          },
        ],
        'callerOptionIds': [],
        'permissions': {
          'canVote': true,
          'canAddOption': false,
          'canClose': true,
          'canViewVoters': false,
        },
      };
    }
    if (r.path == '/api/v1/activities/a') {
      data = {
        'id': 'a',
        'groupId': 'g',
        'title': 'Đi Ba Vì cuối tuần',
        'status': 'CONFIRMED',
        'startAt': null,
        'endAt': null,
        'createdAt': '2026-10-27T00:00:00Z',
        'updatedAt': '2026-10-27T00:00:00Z',
        'creator': {'userId': 'o', 'displayName': 'QA Owner'},
        'callerRsvpStatus': 'GOING',
        'goingCount': 2,
        'maybeCount': 0,
        'notGoingCount': 0,
        'waitlistCount': 0,
        'permissions': {},
      };
    }
    if (r.path == '/api/v1/activities/a/participants') {
      data = [
        {'userId': 'm', 'displayName': 'QA Member 1', 'rsvpStatus': 'GOING'},
      ];
    }
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class Api extends JourneyApi {
  Api()
    : super(
        Dio(BaseOptions(baseUrl: 'https://fixture'))
          ..httpClientAdapter = Adapter(),
      );
  List<Json> stops = [
    stopFixture(),
    stopFixture('s2', 'Đi suối'),
    stopFixture('s3', 'Ăn trưa cùng nhóm'),
  ];
  bool denied = false;
  int reads = 0;
  Completer<void>? gate;
  final writes = <Json>[];
  final links = <Json>[];
  bool failCommit = false;
  int? convertFailure;
  int uploadsCount = 0;
  Json data() => {
    'activityId': 'a',
    'groupId': 'g',
    'title': 'Đi Ba Vì cuối tuần',
    'canManage': true,
    'stops': stops,
  };
  @override
  Future<Json> journey(String id) async {
    reads++;
    final result = data();
    await gate?.future;
    if (denied) throw const ApiException(statusCode: 403);
    return result;
  }

  @override
  Future<Json> stop(String activity, String id) async =>
      stops.firstWhere((s) => s['id'] == id);
  @override
  Future<Json> checkIns(String activity, String id, {String? before}) async => {
    'items': [],
    'hasMore': false,
    'nextBefore': null,
  };
  @override
  Future<List<Json>> list(String path) async => [];
  @override
  Future<Json> saveStop(String activity, Json body, {String? id}) async {
    writes.add(body);
    return stop(activity, id ?? 's');
  }

  @override
  Future<Json> order(
    String activity,
    List<String> old,
    List<String> ids,
  ) async {
    writes.add({'expectedOrder': old, 'orderedIds': ids});
    stops = ids.map((id) => stops.firstWhere((s) => s['id'] == id)).toList();
    return data();
  }

  @override
  Future<Json> state(String activity, Json original, String status) async {
    writes.add({'status': status});
    final index = stops.indexWhere((s) => s['id'] == original['id']);
    stops[index] = {...stops[index], 'status': status};
    return stops[index];
  }

  @override
  Future<Json> execution(String task, {String? before}) async => {
    'task': {
      'id': task,
      'activityId': 'a',
      'title': 'Mua rau',
      'status': 'TODO',
    },
    'mode': 'REQUIRE_REVIEW',
    'stopId': null,
    'canConfigure': true,
    'canSubmit': true,
    'evidence': [],
    'nextBefore': null,
  };
  @override
  Future<Json> configure(String task, String mode, String? id) async {
    writes.add({'mode': mode, 'stopId': id});
    return execution(task);
  }

  @override
  Future<Json> pollActions(String id) async => {
    'groupId': 'g',
    'activityId': 'a',
    'canCreateStop': true,
    'links': links,
  };
  @override
  Future<Json> convert(String poll, Json body) async {
    writes.add({...body});
    if (convertFailure != null) throw ApiException(statusCode: convertFailure);
    final result = {
      'id': 'link',
      'pollId': poll,
      'optionId': body['optionId'],
      'sourceQuestion': 'Cuối tuần đi đâu?',
      'sourceOption': 'Leo núi Ba Vì',
      'activityId': 'a',
      'target': body['target'],
      'taskId': body['target'] == 'TASK' ? 'task' : null,
      'stopId': body['target'] == 'STOP' ? 's' : null,
    };
    links.add(result);
    return result;
  }

  @override
  Future<String> upload(
    String group,
    XFile file, {
    void Function(int, int)? progress,
  }) async {
    uploadsCount++;
    progress?.call(1, 1);
    return 'private-test-key';
  }

  @override
  Future<Json> checkIn(String activity, String stop, Json data) async {
    writes.add({...data});
    if (failCommit) throw const ApiException(statusCode: 503);
    return {'ok': true};
  }

  @override
  Future<String> mediaUrl(String id) async {
    if (denied) throw const ApiException(statusCode: 403);
    return 'https://fixture/photo.png';
  }
}

void main() {
  bool fontsReady = false;
  setUpAll(() async {
    final font = File('/System/Library/Fonts/Supplemental/Arial.ttf');
    if (await font.exists()) {
      final loader = FontLoader('R10QA')
        ..addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
      await loader.load();
      fontsReady = true;
      final icons = File(
        '/opt/homebrew/Caskroom/flutter/3.0.3/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (await icons.exists()) {
        final loader = FontLoader('MaterialIcons')
          ..addFont(
            Future.value(ByteData.sublistView(await icons.readAsBytes())),
          );
        await loader.load();
      }
    }
  });

  late Api api;
  late RealtimeSync sync;
  const repaint = ValueKey('r10-render');
  Future<void> mount(
    WidgetTester t,
    Widget Function() page, {
    Size size = const Size(500, 1000),
    Brightness brightness = Brightness.light,
  }) async {
    api = Api();
    sync = RealtimeSync(const NoopChatRealtimeClient());
    await t.binding.setSurfaceSize(size);
    await t.pumpWidget(
      RepaintBoundary(
        key: repaint,
        child: RealtimeHost(
          sync: sync,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: brightness,
              fontFamily: fontsReady ? 'R10QA' : null,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                brightness: brightness,
              ),
            ),
            home: page(),
          ),
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

  testWidgets('timeline renders canonical ordered stops and opens detail', (
    t,
  ) async {
    await mount(t, () => JourneyScreen(api: api, activity: 'a'));
    expect(find.text('0 / 3 điểm đã hoàn thành'), findsOneWidget);
    await t.tap(find.text('Leo núi Ba Vì'));
    await t.pumpAndSettle();
    expect(find.text('Chụp check-in'), findsOneWidget);
    expect(find.textContaining('không xác minh vị trí'), findsOneWidget);
  });
  testWidgets('timeline distinguishes active, finished and planned stops after realtime', (t) async {
    await mount(t, () {
      api.stops[0] = {...api.stops[0], 'status': 'IN_PROGRESS'};
      api.stops[1] = {...api.stops[1], 'status': 'COMPLETED'};
      return JourneyScreen(api: api, activity: 'a');
    });
    expect(find.text('Đang diễn ra: Leo núi Ba Vì'), findsOneWidget);
    expect(find.text('Đang diễn ra'), findsOneWidget);
    expect(find.text('Đã hoàn thành'), findsOneWidget);
    expect(find.text('1 / 3 điểm đã hoàn thành'), findsOneWidget);
    api.stops[0] = {...api.stops[0], 'status': 'COMPLETED'};
    sync.resync();
    await t.pump(const Duration(milliseconds: 100));
    await t.pumpAndSettle();
    expect(find.text('Đang diễn ra: Leo núi Ba Vì'), findsNothing);
    expect(find.text('2 / 3 điểm đã hoàn thành'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('future planned time does not disable start or camera entry', (t) async {
    await mount(t, () {
      api.stops[0] = {...api.stops[0], 'startsAt': '2099-10-29T02:00:00Z'};
      return StopDetailScreen(api: api, activity: 'a', stop: 's', group: 'g');
    });
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Chụp check-in')).onPressed, isNotNull);
    await t.ensureVisible(find.text('Bắt đầu điểm này'));
    await t.tap(find.text('Bắt đầu điểm này'));
    await t.pumpAndSettle();
    expect(api.writes.last['status'], 'IN_PROGRESS');
    expect(find.text('Đang diễn ra'), findsOneWidget);
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Chụp check-in')).onPressed, isNotNull);
    expect(find.text('Đánh dấu hoàn thành'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('composer submits full date/time and stable UUID', (t) async {
    await mount(t, () => StopComposer(api: api, activity: 'a'));
    await t.enterText(
      find.widgetWithText(TextField, 'Tên điểm dừng'),
      'Đi suối',
    );
    await t.ensureVisible(find.text('Lưu điểm dừng'));
    await t.tap(find.text('Lưu điểm dừng'));
    await t.pumpAndSettle();
    expect(api.writes.single['clientRequestId'], isNotEmpty);
    expect(
      DateTime.parse(api.writes.single['startsAt'] as String).isUtc,
      isTrue,
    );
    expect(api.writes.single['title'], 'Đi suối');
  });
  testWidgets('timeline resync obtains authoritative changes without a write', (
    t,
  ) async {
    await mount(t, () => JourneyScreen(api: api, activity: 'a'));
    api.stops = [stopFixture('s', 'Cập nhật từ Owner')];
    sync.accept({'type': 'SCOPE_RESYNC', 'scope': 'activity:a'});
    await t.pump(const Duration(milliseconds: 100));
    await t.pumpAndSettle();
    expect(find.text('Cập nhật từ Owner'), findsOneWidget);
    expect(api.writes, isEmpty);
  });
  testWidgets('membership revoked clears old timeline; late response ignored', (
    t,
  ) async {
    await mount(t, () => JourneyScreen(api: api, activity: 'a'));
    api.gate = Completer<void>();
    sync.accept({'type': 'SCOPE_RESYNC', 'scope': 'activity:a'});
    await t.pump(const Duration(milliseconds: 100));
    sync.accept({'type': 'SCOPE_REVOKED', 'scope': 'activity:a'});
    await t.pump();
    expect(find.text('Leo núi Ba Vì'), findsNothing);
    api.denied = true;
    api.gate!.complete();
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets('disposed timeline ignores pending response', (t) async {
    await mount(t, () => JourneyScreen(api: api, activity: 'a'));
    api.gate = Completer<void>();
    sync.resync();
    await t.pump(const Duration(milliseconds: 100));
    await t.pumpWidget(const SizedBox());
    api.gate!.complete();
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets('camera cancellation does not upload or submit', (t) async {
    await mount(
      t,
      () => JourneyCapture(
        api: api,
        group: 'g',
        activity: 'a',
        stop: 's',
        capture: () async => null,
      ),
    );
    await t.tap(find.text('Mở camera'));
    await t.pumpAndSettle();
    expect(api.writes, isEmpty);
    expect(find.text('Gửi xác nhận'), findsOneWidget);
  });
  testWidgets('camera permission denial is handled without async exception', (
    t,
  ) async {
    await mount(
      t,
      () => JourneyCapture(
        api: api,
        group: 'g',
        activity: 'a',
        stop: 's',
        capture: () async =>
            throw PlatformException(code: 'camera_access_denied'),
      ),
    );
    await t.tap(find.text('Mở camera'));
    await t.pumpAndSettle();
    expect(find.textContaining('Hãy cho phép quyền'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'task evidence configuration and camera entry preserve task context',
    (t) async {
      await mount(t, () => TaskEvidenceScreen(api: api, task: 't'));
      expect(find.text('Mua rau'), findsOneWidget);
      await t.tap(find.text('Chụp minh chứng'));
      await t.pumpAndSettle();
      expect(find.text('Minh chứng công việc'), findsOneWidget);
      expect(find.text('Chọn ảnh thư viện (đính kèm)'), findsOneWidget);
    },
  );
  testWidgets('poll action fills canonical option and confirms once', (
    t,
  ) async {
    await mount(t, () => PollActionScreen(api: api, poll: 'p'));
    final titleField = find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == 'Tên công việc');
    expect(t.widget<TextField>(titleField).controller!.text, 'Cuối tuần đi đâu?');
    await t.enterText(titleField, 'Đi mua hoa quả');
    await t.tap(find.text('Phương án muốn chuyển'));
    await t.pumpAndSettle();
    await t.tap(find.text('Leo núi Ba Vì').last);
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Xác nhận tạo'));
    await t.tap(find.text('Xác nhận tạo'));
    await t.pumpAndSettle();
    expect(api.writes.single['taskTitle'], 'Đi mua hoa quả');
    expect(api.writes.single['optionId'], 'option');
    expect(api.writes.single['activityId'], 'a');
    expect(api.writes.single['clientRequestId'], isNotEmpty);
    expect(find.text('Đã tạo công việc từ bình chọn.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Xem'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, 'Đóng'));
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(api.writes, hasLength(1));
  });
  testWidgets('Stop conversion confirms success and opens its returned target', (t) async {
    await mount(t, () => PollActionScreen(api: api, poll: 'p'));
    await t.tap(find.text('Phương án muốn chuyển'));
    await t.pumpAndSettle();
    await t.tap(find.text('Leo núi Ba Vì').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Điểm dừng'));
    await t.pumpAndSettle();
    final stopTitleField = find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == 'Tên điểm dừng');
    expect(stopTitleField, findsOneWidget);
    expect(t.widget<TextField>(stopTitleField).controller!.text, 'Leo núi Ba Vì');
    await t.enterText(stopTitleField, 'Điểm dừng QA đã sửa tên');
    await t.ensureVisible(find.text('Xác nhận tạo'));
    await t.tap(find.text('Xác nhận tạo'));
    await t.pumpAndSettle();
    expect(api.writes.single['target'], 'STOP');
    expect(api.writes.single['stopTitle'], 'Điểm dừng QA đã sửa tên');
    expect(find.text('Đã tạo điểm dừng từ bình chọn.'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Xem'));
    await t.pumpAndSettle();
    expect(find.byType(StopDetailScreen), findsOneWidget);
    expect(find.text('Chụp check-in'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('Task success View opens the Activity task list', (t) async {
    await mount(t, () => PollActionScreen(api: api, poll: 'p'));
    await t.tap(find.text('Phương án muốn chuyển'));
    await t.pumpAndSettle();
    await t.tap(find.text('Leo núi Ba Vì').last);
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Xác nhận tạo'));
    await t.tap(find.text('Xác nhận tạo'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Xem'));
    await t.pumpAndSettle();
    expect(find.byType(TaskListScreen), findsOneWidget);
    expect(find.byType(TaskDetailScreen), findsNothing);
    expect(t.widget<TaskListScreen>(find.byType(TaskListScreen)).activityId, 'a');
    expect(t.takeException(), isNull);
  });
  testWidgets('uncertain conversion error shows no false success and retains retry command', (t) async {
    await mount(t, () => PollActionScreen(api: api, poll: 'p'));
    await t.tap(find.text('Phương án muốn chuyển'));
    await t.pumpAndSettle();
    await t.tap(find.text('Leo núi Ba Vì').last);
    await t.pumpAndSettle();
    api.convertFailure = 503;
    await t.ensureVisible(find.text('Xác nhận tạo'));
    await t.tap(find.text('Xác nhận tạo'));
    await t.pumpAndSettle();
    expect(find.text('Đã tạo công việc từ bình chọn.'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Xem'), findsNothing);
    expect(find.text('Thử xác nhận lại an toàn'), findsOneWidget);
    expect(api.links, isEmpty);
    expect(t.takeException(), isNull);
  });
  testWidgets('fullscreen viewer supports paging and double-tap zoom', (
    t,
  ) async {
    await mount(
      t,
      () => MemoryGallery(
        media: const MemoryMedia('m', 'image/png', 'qa.png', 42, 0),
        items: const [
          MemoryMedia('m', 'image/png', 'qa.png', 42, 0),
          MemoryMedia('m2', 'image/png', 'qa2.png', 42, 1),
        ],
        api: api,
        scope: 'group:g',
      ),
    );
    expect(find.text('1 / 2'), findsOneWidget);
    await t.drag(find.byType(PageView), const Offset(-400, 0));
    await t.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    final center = t.getCenter(find.byType(InteractiveViewer).last);
    await t.tapAt(center);
    await t.pump(const Duration(milliseconds: 80));
    await t.tapAt(center);
    await t.pumpAndSettle();
    expect(
      t.widget<PageView>(find.byType(PageView)).physics,
      isA<NeverScrollableScrollPhysics>(),
    );
    expect(t.takeException(), isNull);
  });
  for (final brightness in Brightness.values) {
    testWidgets('narrow timeline ${brightness.name} render and screenshot', (
      t,
    ) async {
      await mount(
        t,
        () => JourneyScreen(api: api, activity: 'a'),
        size: const Size(320, 900),
        brightness: brightness,
      );
      expect(t.takeException(), isNull);
      final boundary = t.renderObject<RenderRepaintBoundary>(
        find.byKey(repaint),
      );
      await t.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/wedo-r10-timeline-${brightness.name}.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
  testWidgets(
    'camera preview upload and retry retain UUID and uploaded object',
    (t) async {
      final path = '/tmp/wedo-r10-camera-test.png';
      await t.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, 32, 32),
          ui.Paint()..color = const Color(0xff146bcb),
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(32, 32);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(path).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      });
      await mount(
        t,
        () => JourneyCapture(
          api: api,
          group: 'g',
          activity: 'a',
          stop: 's',
          capture: () async => XFile(path),
        ),
      );
      await t.tap(find.text('Mở camera'));
      await t.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      api.failCommit = true;
      await t.ensureVisible(find.text('Gửi xác nhận'));
      await t.tap(find.text('Gửi xác nhận'));
      await t.pumpAndSettle();
      expect(api.uploadsCount, 1);
      expect(find.text('Thử gửi lại an toàn'), findsOneWidget);
      api.failCommit = false;
      await t.tap(find.text('Thử gửi lại an toàn'));
      await t.pumpAndSettle();
      expect(api.uploadsCount, 1);
      expect(api.writes.length, 2);
      expect(
        api.writes[0]['clientRequestId'],
        api.writes[1]['clientRequestId'],
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'known conversion validation error permits correction without phantom target',
    (t) async {
      await mount(t, () => PollActionScreen(api: api, poll: 'p'));
      await t.tap(find.text('Phương án muốn chuyển'));
      await t.pumpAndSettle();
      await t.tap(find.text('Leo núi Ba Vì').last);
      await t.pumpAndSettle();
      api.convertFailure = 400;
      await t.ensureVisible(find.text('Xác nhận tạo'));
      await t.tap(find.text('Xác nhận tạo'));
      await t.pumpAndSettle();
      expect(api.links, isEmpty);
      expect(find.text('Đã tạo công việc từ bình chọn.'), findsNothing);
      expect(find.text('Thử xác nhận lại an toàn'), findsNothing);
      expect(t.widget<TextField>(find.byType(TextField).last).enabled, isTrue);
      api.convertFailure = null;
      await t.tap(find.text('Xác nhận tạo'));
      await t.pumpAndSettle();
      expect(api.writes.length, 2);
      expect(
        api.writes.first['clientRequestId'],
        api.writes.last['clientRequestId'],
      );
      expect(api.links.length, 1);
    },
  );
  testWidgets(
    'overview shows real progress next stop and scoped realtime updates',
    (t) async {
      await mount(
        t,
        () => Scaffold(
          body: SingleChildScrollView(
            child: JourneyOverview(api: api, activity: 'a', onOpen: () {}),
          ),
        ),
      );
      expect(find.text('0/3'), findsOneWidget);
      expect(find.textContaining('Tiếp theo: Leo núi Ba Vì'), findsOneWidget);
      api.stops = [
        {...api.stops.first, 'status': 'COMPLETED'},
        ...api.stops.skip(1),
      ];
      sync.accept({
        'type': 'DOMAIN_CHANGED',
        'scope': 'activity:a',
        'eventId': 'overview-1',
        'eventType': 'ACTIVITY_STOP_STATUS_CHANGED',
        'aggregateId': 's',
      });
      await t.pump(const Duration(milliseconds: 100));
      await t.pumpAndSettle();
      expect(find.text('1/3'), findsOneWidget);
      expect(find.textContaining('Tiếp theo: Đi suối'), findsOneWidget);
      expect(api.writes, isEmpty);
    },
  );
}
