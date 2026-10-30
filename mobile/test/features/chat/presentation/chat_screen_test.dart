import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/app/routes.dart';
import 'package:mobile/core/realtime/realtime_binding.dart';
import 'package:mobile/core/realtime/realtime_sync.dart';
import 'package:mobile/features/auth/application/auth_session_controller.dart';
import 'package:mobile/features/chat/data/chat_api.dart';
import 'package:mobile/features/chat/data/chat_models.dart';
import 'package:mobile/features/chat/data/chat_realtime_client.dart';
import 'package:mobile/features/chat/data/chat_realtime_event.dart';
import 'package:mobile/features/chat/data/chat_repository.dart';
import 'package:mobile/features/chat/presentation/chat_screen.dart';
import 'package:mobile/features/media/data/media_upload_service.dart';
import 'package:mobile/features/media/presentation/media_storage_image.dart';
import 'package:mobile/features/chat/presentation/chat_image_viewer.dart';
import 'package:mobile/features/groups/data/group_api.dart';
import 'package:mobile/features/groups/data/group_repository.dart';
import 'package:mobile/features/groups/data/models/group_models.dart';
import 'package:mobile/features/groups/presentation/widgets/group_widgets.dart';
import 'package:mobile/features/social/presentation/widgets/user_avatar.dart';

void main() {
  testWidgets(
    'R3 activity does not jump the visible history anchor while scrolled upward',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 800));
      final realtime = _FakeRealtimeClient();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        realtime.dispose();
        await tester.binding.setSurfaceSize(null);
      });
      final adapter = _ChatScreenAdapter(
        messages: [
          for (var i = 1; i <= 30; i++)
            _message(
              id: 'history-$i',
              sequence: i,
              authorId: 'peer',
              name: 'Peer',
              content: 'Earlier message $i',
              mine: false,
            ),
        ],
      );
      await tester.pumpWidget(_app(adapter, realtimeClient: realtime));
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(450);
      await tester.pumpAndSettle();
      final viewport = tester.getRect(find.byType(ListView).first);
      final visible = find
          .byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith(
                  'chat-item-history-',
                ),
          )
          .evaluate()
          .map((e) => e.widget.key!)
          .where((key) {
            final rect = tester.getRect(find.byKey(key));
            return rect.top >= viewport.top && rect.bottom <= viewport.bottom;
          })
          .toList();
      expect(visible, isNotEmpty);
      final anchor = find.byKey(visible.first);
      final before = tester.getTopLeft(anchor).dy;
      final historyReads = adapter.historyCursors.length;
      final frame = ChatRealtimeEvent.fromJson({
        'type': 'MESSAGE_CREATED',
        'eventId': 'public-vote-new',
        'conversationId': 'conversation-1',
        'message': {
          ..._message(
            id: 'new-poll-activity',
            sequence: 31,
            authorId: 'peer',
            name: 'Peer',
            content: 'Peer đã thay đổi bình chọn: QA',
            mine: false,
          ),
          'type': 'POLL_VOTE_CHANGED',
          'pollId': 'p',
        },
      });
      realtime.emit(frame);
      realtime.emit(frame);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(anchor).dy, closeTo(before, 1));
      expect(position.pixels, greaterThan(0));
      expect(adapter.historyCursors.length, historyReads);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'R3 Poll updates preserve old image states, byte reads, history and scroll',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2600));
      final bytes = (await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.teal, BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(40, 25);
        final result = (await image.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
        image.dispose();
        picture.dispose();
        return result;
      }))!;
      final client = _ImageHttpClient(bytes);
      final media = _CountingReadService();
      debugNetworkImageHttpClientProvider = () => client;
      MediaStorageImage.service = media;
      PaintingBinding.instance.imageCache.clear();
      final realtime = _FakeRealtimeClient();
      final sync = RealtimeSync(realtime);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(sync.dispose);
        realtime.dispose();
        debugNetworkImageHttpClientProvider = null;
        MediaStorageImage.service = null;
        PaintingBinding.instance.imageCache.clear();
        await tester.binding.setSurfaceSize(null);
      });
      final adapter = _ChatScreenAdapter(
        messages: [
          for (var i = 1; i <= 2; i++)
            {
              ..._message(
                id: 'old-$i',
                sequence: i,
                authorId: 'peer',
                name: 'Peer',
                content: '',
                mine: false,
              ),
              'type': 'IMAGE',
              'attachments': [
                {
                  'id': 'a$i',
                  'storageKey': 'chat/conversation-1/old-$i',
                  'contentType': 'image/png',
                  'fileSizeBytes': bytes.length,
                  'sortOrder': 0,
                },
              ],
            },
          {
            ..._message(
              id: 'poll-message',
              sequence: 3,
              authorId: 'peer',
              name: 'Peer',
              content: 'Poll',
              mine: false,
            ),
            'type': 'POLL',
            'pollId': 'p',
          },
        ],
      );
      await tester.pumpWidget(
        RealtimeHost(
          sync: sync,
          child: _app(adapter, realtimeClient: realtime),
        ),
      );
      await _settleChatImages(tester);
      expect(find.text('Chat Poll 1'), findsOneWidget);
      final states = tester.stateList(find.byType(ChatImageThumbnail)).toList();
      expect(states, hasLength(2));
      final reads = media.reads.length,
          gets = client.urls.length,
          history = adapter.historyCursors.length;
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final offset = position.pixels;
      adapter.pollQuestion = 'Chat Poll 2';
      final frame = {
        'type': 'DOMAIN_CHANGED',
        'eventId': 'vote-one',
        'eventType': 'POLL_VOTE_CHANGED',
        'scope': 'activity:a',
        'aggregateId': 'p',
      };
      sync.accept(frame);
      sync.accept(frame);
      await _settleChatImages(tester);
      expect(find.text('Chat Poll 2'), findsOneWidget);
      expect(adapter.pollReads, 2);
      expect(adapter.historyCursors.length, history);
      expect(
        tester.stateList(find.byType(ChatImageThumbnail)).toList(),
        states,
      );
      expect(media.reads.length, reads);
      expect(client.urls.length, gets);
      expect(position.pixels, closeTo(offset, 0.1));
      final activity = {
        ..._message(
          id: 'poll-vote-update',
          sequence: 4,
          authorId: 'peer',
          name: 'Peer',
          content: 'Peer đã tham gia bình chọn: Chat Poll 2',
          mine: false,
        ),
        'type': 'POLL_VOTED',
        'pollId': 'p',
      };
      adapter.messages.add(activity);
      final update = ChatRealtimeEvent.fromJson({
        'type': 'MESSAGE_CREATED',
        'eventId': 'durable-vote',
        'conversationId': 'conversation-1',
        'message': activity,
      });
      realtime.emit(update);
      realtime.emit(update);
      await _settleChatImages(tester);
      expect(
        find.byKey(const ValueKey('chat-item-poll-vote-update')),
        findsOneWidget,
      );
      expect(
        adapter.historyCursors.length,
        history,
      ); // No per-vote history reload.
      expect(
        tester.stateList(find.byType(ChatImageThumbnail)).toList(),
        states,
      );
      expect(media.reads.length, reads);
      expect(client.urls.length, gets);
      expect(position.pixels, closeTo(offset, 0.1));
      realtime.emit(ChatRealtimeEvent.fromJson({'type': 'CONNECTED'}));
      await _settleChatImages(tester);
      realtime.emit(ChatRealtimeEvent.fromJson({'type': 'CONNECTED'}));
      await _settleChatImages(tester);
      expect(
        find.byKey(const ValueKey('chat-item-poll-vote-update')),
        findsOneWidget,
      );
      expect(
        tester.stateList(find.byType(ChatImageThumbnail)).toList(),
        states,
      );
      expect(media.reads.length, reads);
      expect(client.urls.length, gets);
      debugNetworkImageHttpClientProvider = null;
      MediaStorageImage.service = null;
    },
  );
  testWidgets(
    'P0 new text preserves mounted old images, URLs, byte GETs and history',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1600));
      final bytes = (await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.teal, BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(40, 25);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
        image.dispose();
        picture.dispose();
        return bytes;
      }))!;
      final client = _ImageHttpClient(bytes);
      debugNetworkImageHttpClientProvider = () => client;
      final media = _CountingReadService();
      MediaStorageImage.service = media;
      PaintingBinding.instance.imageCache.clear();
      final realtime = _FakeRealtimeClient();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        debugNetworkImageHttpClientProvider = null;
        MediaStorageImage.service = null;
        PaintingBinding.instance.imageCache.clear();
        realtime.dispose();
        await tester.binding.setSurfaceSize(null);
      });
      final messages = [
        for (var i = 1; i <= 2; i++)
          {
            ..._message(
              id: 'image-$i',
              sequence: i,
              authorId: 'peer',
              name: 'Peer',
              content: '',
              mine: false,
            ),
            'type': 'IMAGE',
            'attachments': [
              {
                'id': 'attachment-$i',
                'storageKey': 'chat/conversation-1/old-$i',
                'contentType': 'image/png',
                'fileSizeBytes': bytes.length,
                'sortOrder': 0,
              },
            ],
          },
      ];
      final adapter = _ChatScreenAdapter(messages: messages);
      await tester.pumpWidget(_app(adapter, realtimeClient: realtime));
      await _settleChatImages(tester);
      final states = tester.stateList(find.byType(ChatImageThumbnail)).toList();
      expect(states, hasLength(2));
      final beforeReads = media.reads.length;
      final beforeGets = client.urls.length;
      final providers = tester
          .widgetList<ChatImageFrame>(find.byType(ChatImageFrame))
          .map((frame) => frame.image)
          .toList();
      expect(
        tester
            .widgetList<RawImage>(find.byType(RawImage))
            .where((image) => image.image != null),
        hasLength(2),
      );
      for (var i = 3; i <= 7; i++) {
        realtime.emit(
          ChatRealtimeEvent.fromJson({
            'type': 'MESSAGE_CREATED',
            'eventId': 'text-$i',
            'conversationId': 'conversation-1',
            'message': _message(
              id: 'text-$i',
              sequence: i,
              authorId: 'peer',
              name: 'Peer',
              content: 'New $i',
              mine: false,
            ),
          }),
        );
        await _settleChatImages(tester);
      }
      debugPrint(
        'P0_IMAGE_EVIDENCE auth=$beforeReads->${media.reads.length} bytes=$beforeGets->${client.urls.length} history=${adapter.historyCursors.length}',
      );
      expect(adapter.historyCursors, hasLength(1));
      expect(media.reads, hasLength(beforeReads));
      expect(client.urls, hasLength(beforeGets));
      final after = tester.stateList(find.byType(ChatImageThumbnail)).toList();
      for (final state in states) {
        expect(state.mounted, isTrue);
        expect(after, contains(state));
      }
      expect(find.text('New 7'), findsOneWidget);
      adapter.nextSendSequence = 8;
      for (var i = 0; i < 5; i++) {
        await tester.enterText(find.byType(TextField), 'Own text $i');
        await tester.pump();
        await tester.tap(find.byTooltip('Gửi tin nhắn'));
        await _settleChatImages(tester);
      }
      // Duplicate frame with the same event ID cannot insert a second copy.
      for (var i = 0; i < 2; i++) {
        realtime.emit(
          ChatRealtimeEvent.fromJson({
            'type': 'MESSAGE_CREATED',
            'eventId': 'echo-own',
            'conversationId': 'conversation-1',
            'message': _message(
              id: 'sent-message-5',
              sequence: 12,
              authorId: 'me',
              name: 'Minh',
              content: 'Own text 4',
              mine: true,
            ),
          }),
        );
        await _settleChatImages(tester);
      }
      expect(find.text('Own text 4'), findsOneWidget);
      expect(media.reads, hasLength(beforeReads));
      expect(client.urls, hasLength(beforeGets));
      expect(adapter.historyCursors, hasLength(1));
      expect(
        tester
            .widgetList<ChatImageFrame>(find.byType(ChatImageFrame))
            .map((frame) => frame.image),
        unorderedEquals(providers),
      );
      for (final state in states) {
        expect(state.mounted, isTrue);
      }
      debugNetworkImageHttpClientProvider = null;
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('known conversation shows loading until history resolves', (
    tester,
  ) async {
    final gate = Completer<void>();
    final adapter = _ChatScreenAdapter(historyGate: gate.future);
    final conversation = ChatConversation.fromJson({
      'id': 'conversation-1',
      'type': 'GROUP',
      'title': 'Known group',
      'lastSequence': 0,
      'unreadCount': 0,
      'permissions': _permissions(),
    });
    await tester.pumpWidget(_app(adapter, initialConversation: conversation));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Chưa có tin nhắn'), findsNothing);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Chưa có tin nhắn'), findsOneWidget);
  });

  testWidgets(
    'known conversation history failure offers retry, not empty chat',
    (tester) async {
      final adapter = _ChatScreenAdapter(historyFail: true);
      final conversation = ChatConversation.fromJson({
        'id': 'conversation-1',
        'type': 'GROUP',
        'title': 'Known group',
        'lastSequence': 0,
        'unreadCount': 0,
        'permissions': _permissions(),
      });
      await tester.pumpWidget(_app(adapter, initialConversation: conversation));
      await tester.pumpAndSettle();
      expect(find.text('Không thể tải cuộc trò chuyện.'), findsOneWidget);
      expect(find.text('Chưa có tin nhắn'), findsNothing);
      adapter.historyFail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Không thể tải cuộc trò chuyện.'), findsNothing);
      expect(find.text('Chưa có tin nhắn'), findsOneWidget);
    },
  );

  testWidgets(
    'background chat releases push suppression and resumes catch-up',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final realtime = _FakeRealtimeClient();
      addTearDown(realtime.dispose);
      final messages = [
        _message(
          id: 'm1',
          sequence: 1,
          authorId: 'peer',
          name: 'Peer',
          content: 'Anchor',
          mine: false,
        ),
      ];
      final adapter = _ChatScreenAdapter(messages: messages);
      await tester.pumpWidget(_app(adapter, realtimeClient: realtime));
      await tester.pumpAndSettle();
      expect(realtime.subscribedConversations, {'conversation-1'});
      final readsBeforeBackground = [...adapter.readSequences];

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(realtime.subscribedConversations, isEmpty);
      realtime.emit(
        ChatRealtimeEvent.fromJson({
          'type': 'CONNECTED',
          'eventId': 'background-connect',
        }),
      );
      final missed = _message(
        id: 'm2',
        sequence: 2,
        authorId: 'peer',
        name: 'Peer',
        content: 'While away',
        mine: false,
      );
      messages.add(missed);
      realtime.emit(
        ChatRealtimeEvent.fromJson({
          'type': 'MESSAGE_CREATED',
          'eventId': 'late-frame',
          'conversationId': 'conversation-1',
          'message': missed,
        }),
      );
      await tester.pumpAndSettle();
      expect(realtime.subscribedConversations, isEmpty);
      expect(adapter.readSequences, readsBeforeBackground);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(realtime.subscribedConversations, {'conversation-1'});
      expect(adapter.historyCursors.length, 2);
      expect(find.text('While away'), findsOneWidget);
      expect(adapter.readSequences.last, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );

  testWidgets(
    'initial open and reopen show latest page, older history remains available',
    (tester) async {
      final adapter = _ChatScreenAdapter(
        messages: [
          for (var i = 1; i <= 120; i++)
            _message(
              id: 'm$i',
              sequence: i,
              authorId: 'peer',
              name: 'Peer',
              content: i == 120
                  ? 'Message 120'
                  : 'Message $i\n${List.filled(i % 5 == 0 ? 35 : 1, 'Variable height history').join('\n')}',
              mine: false,
            ),
        ],
      );
      for (var open = 0; open < 2; open++) {
        await tester.pumpWidget(_app(adapter));
        await tester.pumpAndSettle();
        expect(find.text('Message 120'), findsOneWidget);
        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        expect(scrollable.position.pixels, 0);
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tin nhắn trước đó'));
        await tester.pumpAndSettle();
        expect(adapter.historyCursors.last, 91);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );
  testWidgets(
    'reconnect walks past one page and merges REST realtime overlap',
    (tester) async {
      final realtime = _FakeRealtimeClient();
      addTearDown(realtime.dispose);
      final messages = [
        _message(
          id: 'm1',
          sequence: 1,
          authorId: 'peer',
          name: 'Peer',
          content: 'Anchor',
          mine: false,
        ),
      ];
      final adapter = _ChatScreenAdapter(messages: messages);
      await tester.pumpWidget(_app(adapter, realtimeClient: realtime));
      await tester.pumpAndSettle();
      // The shared client was already connected before this screen mounted.
      // Its broadcast CONNECTED frame is not replayed to a new subscriber.
      for (var sequence = 2; sequence <= 105; sequence++) {
        messages.add(
          _message(
            id: 'm$sequence',
            sequence: sequence,
            authorId: 'peer',
            name: 'Peer',
            content: 'Recovered $sequence',
            mine: false,
          ),
        );
      }
      final overlap = ChatRealtimeEvent.fromJson({
        'type': 'MESSAGE_CREATED',
        'eventId': 'overlap',
        'conversationId': 'conversation-1',
        'message': messages.last,
      });
      realtime.emit(
        ChatRealtimeEvent.fromJson({
          'type': 'CONNECTED',
          'eventId': 'connect-2',
        }),
      );
      realtime.emit(overlap);
      realtime.emit(overlap);
      await tester.pumpAndSettle();
      expect(adapter.historyCursors, [null, null, 6]);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('chat-item-m1')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Anchor'), findsOneWidget);
      expect(find.text('Recovered 2'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('chat-item-m105')),
        -500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Recovered 105'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('group chat loads and sends authoritative REST response', (
    tester,
  ) async {
    final adapter = _ChatScreenAdapter();
    await tester.pumpWidget(_app(adapter));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có tin nhắn'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Chào cả nhóm');
    await tester.pump();
    await tester.tap(find.byTooltip('Gửi tin nhắn'));
    await tester.pumpAndSettle();
    expect(find.text('Chào cả nhóm'), findsOneWidget);
    expect(adapter.sent, isTrue);
  });

  testWidgets('empty composer without images cannot send', (tester) async {
    final adapter = _ChatScreenAdapter();
    await tester.pumpWidget(_app(adapter));
    await tester.pumpAndSettle();

    expect(_sendButton(tester).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('chat-send-button')));
    await tester.pump();
    expect(adapter.sent, isFalse);
  });

  testWidgets('text-only composer enables send', (tester) async {
    final adapter = _ChatScreenAdapter();
    await tester.pumpWidget(_app(adapter));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Text message');
    await tester.pump();
    expect(_sendButton(tester).onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('chat-send-button')));
    await tester.pumpAndSettle();

    expect(adapter.sentBody?['content'], 'Text message');
    expect(adapter.sentBody?.containsKey('attachmentStorageKeys'), isFalse);
  });

  testWidgets(
    'image-only send uses the shared route uploader and storage key',
    (tester) async {
      final media = _TestMediaUpload();
      ChatRepository.defaultMediaUploadService = media.service;
      addTearDown(() => ChatRepository.defaultMediaUploadService = null);
      final adapter = _ChatScreenAdapter();
      final images = await _makeImages(1);

      await tester.pumpWidget(
        _app(adapter, pickImages: () async => images.files),
      );
      await tester.pumpAndSettle();
      await _pickImages(tester);
      expect(_sendButton(tester).onPressed, isNotNull);
      expect(find.byTooltip('Remove image'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('chat-send-button')));
      await tester.pumpAndSettle();

      expect(media.presign.requests, hasLength(1));
      expect(media.presign.requests.single.data['category'], 'CHAT_IMAGE');
      expect(media.presign.requests.single.data['contextId'], 'conversation-1');
      expect(media.upload.requests, hasLength(1));
      expect(adapter.sentBody?['content'], '');
      expect(adapter.sentBody?['attachmentStorageKeys'], [
        'chat/conversation-1/user-1/object-1',
      ]);
      expect(find.byTooltip('Remove image'), findsNothing);
    },
  );

  testWidgets('camera preview keeps draft and uploads only on Send', (
    tester,
  ) async {
    final media = _TestMediaUpload();
    final adapter = _ChatScreenAdapter();
    final images = await _makeImages(1);
    await tester.pumpWidget(
      _app(
        adapter,
        mediaUploadService: media.service,
        takePhoto: () async => images.files.single,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ảnh vừa chụp');
    await tester.tap(find.byTooltip('Ảnh và camera'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chụp ảnh'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove image'), findsOneWidget);
    expect(find.text('Ảnh vừa chụp'), findsOneWidget);
    expect(media.presign.requests, isEmpty);
    await tester.tap(find.byKey(const ValueKey('chat-send-button')));
    await tester.pumpAndSettle();
    expect(media.presign.requests.single.data['category'], 'CHAT_IMAGE');
    expect(media.presign.requests.single.data['contextId'], 'conversation-1');
    expect(adapter.sentBody?['content'], 'Ảnh vừa chụp');
    expect(adapter.sentBody?['attachmentStorageKeys'], hasLength(1));
  });
  for (final fails in [false, true]) {
    testWidgets('camera cancel/error keeps draft: $fails', (tester) async {
      final media = _TestMediaUpload();
      await tester.pumpWidget(
        _app(
          _ChatScreenAdapter(),
          mediaUploadService: media.service,
          takePhoto: () async {
            if (fails) throw Exception('camera unavailable');
            return null;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Giữ bản nháp');
      await tester.tap(find.byTooltip('Ảnh và camera'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chụp ảnh'));
      await tester.pumpAndSettle();
      expect(find.text('Giữ bản nháp'), findsOneWidget);
      expect(find.byTooltip('Remove image'), findsNothing);
      expect(media.presign.requests, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('caption and image uploads before sending caption', (
    tester,
  ) async {
    final media = _TestMediaUpload();
    final adapter = _ChatScreenAdapter();
    final images = await _makeImages(1);

    await tester.pumpWidget(
      _app(
        adapter,
        mediaUploadService: media.service,
        pickImages: () async => images.files,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Caption');
    await _pickImages(tester);
    await tester.tap(find.byKey(const ValueKey('chat-send-button')));
    await tester.pumpAndSettle();

    expect(media.presign.requests, hasLength(1));
    expect(media.upload.requests, hasLength(1));
    expect(adapter.sentBody?['content'], 'Caption');
    expect(adapter.sentBody?['attachmentStorageKeys'], isNotEmpty);
  });

  testWidgets(
    'pending message request allows text but hides image attachment',
    (tester) async {
      final adapter = _ChatScreenAdapter();
      final pending = ChatConversation.fromJson({
        'id': 'conversation-1',
        'type': 'DIRECT',
        'accessStatus': 'REQUEST_PENDING',
        'lastSequence': 0,
        'unreadCount': 0,
        'permissions': _permissions(),
      });
      await tester.pumpWidget(_app(adapter, initialConversation: pending));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Ảnh và camera'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Text request');
      await tester.pump();
      expect(_sendButton(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('chat-send-button')));
      await tester.pumpAndSettle();
      expect(adapter.sentBody?['content'], 'Text request');
      expect(adapter.sentBody?.containsKey('attachmentStorageKeys'), isFalse);
    },
  );

  testWidgets('accepted direct chat offers image attachment', (tester) async {
    final adapter = _ChatScreenAdapter();
    final accepted = ChatConversation.fromJson({
      'id': 'conversation-1',
      'type': 'DIRECT',
      'accessStatus': 'OPEN',
      'lastSequence': 0,
      'unreadCount': 0,
      'permissions': _permissions(),
    });
    await tester.pumpWidget(_app(adapter, initialConversation: accepted));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Ảnh và camera'), findsOneWidget);
  });

  testWidgets('upload failure retains draft and prevents message creation', (
    tester,
  ) async {
    final media = _TestMediaUpload(failPresign: true);
    final adapter = _ChatScreenAdapter();
    final images = await _makeImages(1);

    await tester.pumpWidget(
      _app(
        adapter,
        mediaUploadService: media.service,
        pickImages: () async => images.files,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Keep this caption');
    await _pickImages(tester);
    await tester.tap(find.byKey(const ValueKey('chat-send-button')));
    await tester.pumpAndSettle();

    expect(media.presign.requests, hasLength(1));
    expect(media.upload.requests, isEmpty);
    expect(adapter.sent, isFalse);
    expect(find.text('Keep this caption'), findsOneWidget);
    expect(find.byTooltip('Remove image'), findsOneWidget);
    expect(_sendButton(tester).onPressed, isNotNull);
  });

  testWidgets('rapid repeated image-send taps submit only once', (
    tester,
  ) async {
    final media = _TestMediaUpload();
    final adapter = _ChatScreenAdapter();
    final images = await _makeImages(1);

    await tester.pumpWidget(
      _app(
        adapter,
        mediaUploadService: media.service,
        pickImages: () async => images.files,
      ),
    );
    await tester.pumpAndSettle();
    await _pickImages(tester);
    await tester.tap(find.byKey(const ValueKey('chat-send-button')));
    await tester.tap(find.byKey(const ValueKey('chat-send-button')));
    await tester.pumpAndSettle();

    expect(media.presign.requests, hasLength(1));
    expect(media.upload.requests, hasLength(1));
    expect(adapter.sent, isTrue);
  });

  testWidgets('four images are accepted and sent in picker order', (
    tester,
  ) async {
    final media = _TestMediaUpload();
    final adapter = _ChatScreenAdapter();
    final images = await _makeImages(4);

    await tester.pumpWidget(
      _app(
        adapter,
        mediaUploadService: media.service,
        pickImages: () async => images.files,
      ),
    );
    await tester.pumpAndSettle();
    await _pickImages(tester);
    expect(find.byTooltip('Remove image'), findsNWidgets(4));
    await tester.tap(find.byKey(const ValueKey('chat-send-button')));
    await tester.pumpAndSettle();

    expect(media.presign.requests, hasLength(4));
    expect(media.upload.requests, hasLength(4));
    expect(adapter.sentBody?['attachmentStorageKeys'], [
      'chat/conversation-1/user-1/object-1',
      'chat/conversation-1/user-1/object-2',
      'chat/conversation-1/user-1/object-3',
      'chat/conversation-1/user-1/object-4',
    ]);
  });

  testWidgets('picker result over four images is rejected', (tester) async {
    final adapter = _ChatScreenAdapter();
    final images = await _makeImages(5);

    await tester.pumpWidget(
      _app(adapter, pickImages: () async => images.files),
    );
    await tester.pumpAndSettle();
    await _pickImages(tester);

    expect(find.byTooltip('Remove image'), findsNothing);
    expect(_sendButton(tester).onPressed, isNull);
    expect(adapter.sent, isFalse);
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
      tester
          .widget<GroupAvatar>(find.byType(GroupAvatar).first)
          .avatarStorageKey,
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
    'message long press opens compact quick reactions and permitted actions while tap toggles exact timestamp',
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
      expect(
        find.byKey(const ValueKey('chat-tap-timestamp-own-message')),
        findsNothing,
      );

      await tester.tap(find.text('React to this'));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('chat-tap-timestamp-own-message')),
        findsOneWidget,
      );
      expect(find.text('Sao chép'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.byKey(const ValueKey('chat-tap-timestamp-own-message')),
        findsNothing,
      );

      await tester.longPress(find.text('React to this'));
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

      await tester.longPress(find.text('React to this'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thu hồi tin nhắn'));
      await tester.pumpAndSettle();
      expect(find.text('Tin nhắn đã được thu hồi'), findsOneWidget);
      expect(find.text('❤️ 2'), findsNothing);
      expect(find.text('👍 1'), findsNothing);
    },
  );

  testWidgets(
    '30-minute separator renders only on >=30m gaps and breaks author runs',
    (tester) async {
      final adapter = _ChatScreenAdapter(
        messages: [
          _message(
            id: 'm1',
            sequence: 1,
            authorId: 'peer',
            name: 'Lan Anh',
            content: 'Tin 1',
            mine: false,
            createdAt: '2026-09-27T01:00:00Z',
          ),
          _message(
            id: 'm2',
            sequence: 2,
            authorId: 'peer',
            name: 'Lan Anh',
            content: 'Tin 2 trong 5 phút',
            mine: false,
            createdAt: '2026-09-27T01:05:00Z',
          ),
          _message(
            id: 'm3',
            sequence: 3,
            authorId: 'peer',
            name: 'Lan Anh',
            content: 'Tin 3 sau 31 phút',
            mine: false,
            createdAt: '2026-09-27T01:36:00Z',
          ),
        ],
      );
      await tester.pumpWidget(_app(adapter));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('chat-time-separator-m1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('chat-time-separator-m2')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('chat-time-separator-m3')),
        findsOneWidget,
      );
      // Separator breaks author run so Lan Anh header/avatar appears on m1 and m3
      expect(find.text('Lan Anh'), findsNWidgets(2));
    },
  );

  testWidgets(
    'M10 realtime updates message create/dedupe, edit, reaction, unsend, read state, typing, and presence',
    (tester) async {
      final realtime = _FakeRealtimeClient();
      final adapter = _ChatScreenAdapter(
        messages: [
          _message(
            id: 'm1',
            sequence: 1,
            authorId: 'me',
            name: 'Minh',
            content: 'Tin đầu tiên',
            mine: true,
          ),
        ],
      );
      await tester.pumpWidget(_app(adapter, realtimeClient: realtime));
      await tester.pumpAndSettle();
      expect(realtime.subscribedConversations, contains('conversation-1'));

      // 1. Live presence online
      realtime.emit(
        ChatRealtimeEvent.fromJson({
          'type': 'PRESENCE_UPDATED',
          'eventId': 'evt-presence-1',
          'payload': {
            'user': {'id': 'peer-2', 'displayName': 'Lan Anh'},
            'online': true,
          },
        }),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('chat-presence-online')),
        findsOneWidget,
      );
      expect(find.text('Đang hoạt động'), findsOneWidget);

      // 2. Live typing indicator
      realtime.emit(
        ChatRealtimeEvent.fromJson({
          'type': 'TYPING_UPDATED',
          'eventId': 'evt-typing-1',
          'conversationId': 'conversation-1',
          'payload': {
            'user': {'id': 'peer-2', 'displayName': 'Lan Anh'},
            'typing': true,
          },
        }),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('chat-typing-indicator')),
        findsOneWidget,
      );
      expect(find.text('Lan Anh đang nhập...'), findsOneWidget);

      // 3. Live MESSAGE_CREATED clears typing and deduplicates repeated delivery
      final createdEvent = ChatRealtimeEvent.fromJson({
        'type': 'MESSAGE_CREATED',
        'eventId': 'evt-msg-2',
        'conversationId': 'conversation-1',
        'sequence': 2,
        'payload': {
          'message': _message(
            id: 'm2',
            sequence: 2,
            authorId: 'peer-2',
            name: 'Lan Anh',
            content: 'Chào từ WebSocket',
            mine: false,
          ),
        },
      });
      realtime.emit(createdEvent);
      realtime.emit(createdEvent); // duplicate eventId
      await tester.pumpAndSettle();
      expect(find.text('Chào từ WebSocket'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-typing-indicator')), findsNothing);

      // 4. Live MESSAGE_EDITED + MESSAGE_REACTION_UPDATED
      realtime.emit(
        ChatRealtimeEvent.fromJson({
          'type': 'MESSAGE_EDITED',
          'eventId': 'evt-edit-2',
          'conversationId': 'conversation-1',
          'sequence': 2,
          'payload': {
            'message': _message(
              id: 'm2',
              sequence: 2,
              authorId: 'peer-2',
              name: 'Lan Anh',
              content: 'Chào từ WebSocket (đã sửa)',
              mine: false,
              reactions: [
                {'emoji': '❤️', 'count': 2, 'reactedByMe': false},
              ],
            ),
          },
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chào từ WebSocket (đã sửa)'), findsOneWidget);
      expect(find.text('❤️ 2'), findsOneWidget);

      // 5. Live READ_STATE_UPDATED moves reader avatar to m2
      realtime.emit(
        ChatRealtimeEvent.fromJson({
          'type': 'READ_STATE_UPDATED',
          'eventId': 'evt-read-2',
          'conversationId': 'conversation-1',
          'sequence': 2,
          'payload': {
            'user': {'id': 'reader-9', 'displayName': 'Bình'},
            'lastReadSequence': 2,
          },
        }),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reader-reader-9')), findsOneWidget);

      // 6. Live MESSAGE_UNSENT transitions bubble to withdrawn state
      realtime.emit(
        ChatRealtimeEvent.fromJson({
          'type': 'MESSAGE_UNSENT',
          'eventId': 'evt-unsend-2',
          'conversationId': 'conversation-1',
          'sequence': 2,
          'payload': {
            'message': _message(
              id: 'm2',
              sequence: 2,
              authorId: 'peer-2',
              name: 'Lan Anh',
              content: null,
              mine: false,
              status: 'UNSENT',
            ),
          },
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tin nhắn đã được thu hồi'), findsOneWidget);
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

Future<void> _settleChatImages(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  final images = tester.widgetList<Image>(find.byType(Image)).toList();
  final context = tester.element(find.byType(ChatScreen));
  await tester.runAsync(
    () =>
        Future.wait(images.map((image) => precacheImage(image.image, context))),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

Widget _app(
  _ChatScreenAdapter adapter, {
  VoidCallback? onOpenGroupInfo,
  ChatRealtimeClient? realtimeClient,
  MediaUploadService? mediaUploadService,
  Future<List<XFile>> Function()? pickImages,
  Future<XFile?> Function()? takePhoto,
  ChatConversation? initialConversation,
}) => MaterialApp(
  home: ChatScreen(
    groupId: initialConversation == null ? 'group-1' : null,
    initialConversation: initialConversation,
    onOpenGroupInfo: onOpenGroupInfo,
    pickImages: pickImages,
    takePhoto: takePhoto,
    repository: ChatRepository(
      ChatApi(
        Dio(BaseOptions(baseUrl: 'https://test'))..httpClientAdapter = adapter,
      ),
      realtimeClient: realtimeClient ?? const NoopChatRealtimeClient(),
      mediaUploadService: mediaUploadService,
    ),
  ),
);

IconButton _sendButton(WidgetTester tester) =>
    tester.widget<IconButton>(find.byKey(const ValueKey('chat-send-button')));

Future<void> _pickImages(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Ảnh và camera'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Chọn từ thư viện'));
  await tester.pumpAndSettle();
}

Future<_ImageFixture> _makeImages(int count) async {
  final bytes = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/S7sAAAAASUVORK5CYII=',
    ),
  );
  final files = <XFile>[];
  for (var index = 0; index < count; index++) {
    files.add(
      XFile.fromData(bytes, name: 'image-$index.png', mimeType: 'image/png'),
    );
  }
  return _ImageFixture(files);
}

class _ImageFixture {
  final List<XFile> files;
  const _ImageFixture(this.files);
}

class _TestMediaUpload {
  final _PresignAdapter presign;
  final _UploadAdapter upload;
  late final MediaUploadService service;

  _TestMediaUpload({bool failPresign = false})
    : presign = _PresignAdapter(fail: failPresign),
      upload = _UploadAdapter() {
    final apiDio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = presign;
    final directUploadDio = Dio()..httpClientAdapter = upload;
    service = MediaUploadService(
      apiDio: apiDio,
      directUploadDio: directUploadDio,
    );
  }
}

class _PresignAdapter implements HttpClientAdapter {
  final bool fail;
  final requests = <RequestOptions>[];
  _PresignAdapter({this.fail = false});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    if (fail) {
      return ResponseBody.fromString(
        jsonEncode({'code': 'UPLOAD_FAILED'}),
        503,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    final request = Map<String, dynamic>.from(options.data as Map);
    return ResponseBody.fromString(
      jsonEncode({
        'storageKey': 'chat/conversation-1/user-1/object-${requests.length}',
        'uploadUrl': 'https://storage.test/object-${requests.length}',
        'expiresAt': '2030-01-01T00:10:00Z',
        'requiredHeaders': {
          'Content-Type': request['contentType'],
          'x-amz-meta-declared-size': request['fileSize'].toString(),
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _UploadAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    return ResponseBody.fromString('', 200);
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _message({
  required String id,
  required int sequence,
  required String authorId,
  required String name,
  required String? content,
  required bool mine,
  String status = 'ACTIVE',
  String? avatarStorageKey,
  String createdAt = '2026-09-27T00:00:00Z',
  List<Map<String, Object>> reactions = const [],
}) => {
  'id': id,
  'conversationId': 'conversation-1',
  'sequence': sequence,
  'type': 'TEXT',
  'isMine': mine,
  'author': {
    'id': authorId,
    'displayName': name,
    'avatarStorageKey': avatarStorageKey,
  },
  'content': content,
  'status': status,
  'replyToMessageId': null,
  'createdAt': createdAt,
  'editedAt': null,
  'unsentAt': status == 'UNSENT' ? '2026-09-27T00:01:00Z' : null,
  'myReaction': null,
  'reactions': reactions,
  'permissions': _permissions(canEdit: mine && status == 'ACTIVE'),
};

class _CountingReadService extends MediaUploadService {
  _CountingReadService() : super(apiDio: Dio());
  final reads = <String>[];
  @override
  Future<String> authorizedReadUrl(String key) async {
    reads.add(key);
    return 'https://storage.test/$key?signature=${reads.length}';
  }
}

class _ImageHttpClient implements HttpClient {
  _ImageHttpClient(this.bytes);
  final Uint8List bytes;
  final urls = <Uri>[];
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    urls.add(url);
    return _ImageRequest(bytes);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImageRequest implements HttpClientRequest {
  _ImageRequest(this.bytes);
  final Uint8List bytes;
  @override
  Future<HttpClientResponse> close() async => _ImageResponse(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImageResponse extends StreamView<List<int>>
    implements HttpClientResponse {
  _ImageResponse(Uint8List bytes)
    : contentLength = bytes.length,
      super(Stream.value(bytes));
  @override
  final int contentLength;
  @override
  int get statusCode => 200;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRealtimeClient implements ChatRealtimeClient {
  final StreamController<ChatRealtimeEvent> _events =
      StreamController<ChatRealtimeEvent>.broadcast();
  final StreamController<ChatRealtimeConnectionState> _states =
      StreamController<ChatRealtimeConnectionState>.broadcast();
  final Set<String> subscribedConversations = <String>{};

  void emit(ChatRealtimeEvent event) => _events.add(event);

  @override
  Stream<ChatRealtimeEvent> get events => _events.stream;

  @override
  Stream<ChatRealtimeConnectionState> get connectionStates => _states.stream;

  @override
  ChatRealtimeConnectionState get currentState =>
      ChatRealtimeConnectionState.connected;

  @override
  Set<String> get subscribedConversationIds => subscribedConversations;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  void subscribeConversation(String conversationId) {
    subscribedConversations.add(conversationId);
  }

  @override
  void unsubscribeConversation(String conversationId) {
    subscribedConversations.remove(conversationId);
  }

  @override
  void sendTypingStart(String conversationId) {}

  @override
  void sendTypingStop(String conversationId) {}

  @override
  void sendMarkRead(String conversationId, int lastReadSequence) {}

  @override
  void dispose() {
    _events.close();
    _states.close();
  }
}

class _ChatScreenAdapter implements HttpClientAdapter {
  int pollReads = 0;
  String pollQuestion = 'Chat Poll 1';
  final List<int?> historyCursors = [];
  final List<int> readSequences = [];
  final List<Map<String, dynamic>> messages;
  final List<Map<String, Object?>> readers;
  final String? groupAvatarStorageKey;
  final List<Map<String, dynamic>> reactionDetails;
  bool detailsFail;
  bool historyFail;
  final Future<void>? historyGate;
  String? detailsMessagePath;
  bool sent = false;
  int sentCount = 0;
  int? nextSendSequence;
  Map<String, dynamic>? sentBody;
  String? lastReaction;

  _ChatScreenAdapter({
    this.messages = const [],
    this.readers = const [],
    this.groupAvatarStorageKey,
    this.reactionDetails = const [],
    this.detailsFail = false,
    this.historyFail = false,
    this.historyGate,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    Object body = {};
    var status = 200;
    if (options.path == '/api/v1/polls/p') {
      pollReads++;
      body = {
        'id': 'p',
        'activityId': 'a',
        'createdBy': 'peer',
        'question': pollQuestion,
        'pollType': 'SINGLE_CHOICE',
        'voteVisibility': 'PUBLIC',
        'resultVisibility': 'IMMEDIATE',
        'resultsVisible': true,
        'status': 'OPEN',
        'options': [
          {
            'id': 'o',
            'text': 'Option',
            'sortOrder': 0,
            'createdBy': 'peer',
            'voteCount': 1,
            'disabled': false,
          },
        ],
        'callerOptionIds': [],
        'permissions': {'canVote': true},
      };
    } else if (options.path.endsWith('/conversation')) {
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
      await historyGate;
      if (historyFail) {
        return ResponseBody.fromString(
          jsonEncode({'code': 'UNAVAILABLE'}),
          503,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      final cursor = options.queryParameters['beforeSequence'] as int?;
      historyCursors.add(cursor);
      final limit = options.queryParameters['limit'] as int? ?? 30;
      final candidates = messages
          .where((m) => cursor == null || (m['sequence'] as int) < cursor)
          .toList();
      final page = candidates.length > limit
          ? candidates.sublist(candidates.length - limit)
          : candidates;
      body = {
        'conversationId': 'conversation-1',
        'messages': page,
        'readers': readers,
        'nextBeforeSequence': candidates.length > limit
            ? page.first['sequence']
            : null,
        'hasMore': candidates.length > limit,
      };
    } else if (options.path.endsWith('/read-state')) {
      readSequences.add((options.data as Map)['lastReadSequence'] as int);
      status = 204;
    } else if (options.path.endsWith('/messages') && options.method == 'POST') {
      sent = true;
      sentCount++;
      sentBody = Map<String, dynamic>.from(options.data as Map);
      status = 201;
      body = _message(
        id: sentCount == 1 ? 'sent-message' : 'sent-message-$sentCount',
        sequence: nextSendSequence ?? messages.length + 1,
        authorId: 'me',
        name: 'Minh',
        content: sentBody!['content'] as String,
        mine: true,
      );
      if (nextSendSequence != null) nextSendSequence = nextSendSequence! + 1;
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
