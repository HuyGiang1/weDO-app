import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/presentation/chat_image_viewer.dart';
import 'package:mobile/features/media/data/gallery_image_saver.dart';
import 'package:mobile/features/media/data/media_upload_service.dart';

Future<Uint8List> fixture(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(Colors.teal, BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
      .asUint8List();
  image.dispose();
  picture.dispose();
  return bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final entry in {
    'permission_restricted': 'Thiết bị đang hạn chế quyền thêm ảnh.',
    'permission_unavailable': 'iOS chưa cấp được quyền thêm ảnh.',
  }.entries) {
    testWidgets(
      'save distinguishes ${entry.key} without requesting broader access',
      (tester) async {
        final bytes = await tester.runAsync(() => fixture(10, 10));
        final service = _Service(DownloadedMediaImage.fromBytes(bytes!));
        const channel = MethodChannel('test/gallery-status');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (_) async {
            throw PlatformException(code: entry.key);
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: ChatImageViewer(
              storageKey: 'private/key',
              service: service,
              saver: const GalleryImageSaver(channel: channel),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Lưu ảnh'));
        await tester.pumpAndSettle();
        expect(find.textContaining(entry.value), findsOneWidget);
        expect(service.loads, 2);
      },
    );
  }
  for (final size in [
    (100, 200),
    (240, 120),
    (200, 200),
    (1000, 50),
    (50, 1000),
  ]) {
    testWidgets(
      'thumbnail preserves ${size.$1}:${size.$2} without a fixed bubble',
      (tester) async {
        final bytes = await tester.runAsync(() => fixture(size.$1, size.$2));
        var opened = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 280,
                  child: ChatImageFrame(
                    image: MemoryImage(bytes!),
                    onOpen: () => opened++,
                    onRetry: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pumpAndSettle();
        final rendered = tester.getSize(find.byType(RawImage));
        expect(
          rendered.width / rendered.height,
          closeTo(size.$1 / size.$2, .03),
        );
        expect(rendered.width, lessThanOrEqualTo(280));
        expect(rendered.height, lessThanOrEqualTo(400));
        await tester.tap(find.byType(RawImage));
        expect(opened, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'viewer zoom, pan, reauthorizing original save, busy guard, close',
    (tester) async {
      final bytes = await tester.runAsync(() => fixture(120, 240));
      final service = _Service(DownloadedMediaImage.fromBytes(bytes!));
      const channel = MethodChannel('test/gallery');
      final gate = Completer<void>();
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        await gate.future;
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChatImageViewer(
                      storageKey: 'private/key',
                      service: service,
                      saver: const GalleryImageSaver(channel: channel),
                    ),
                  ),
                ),
                child: const Text('conversation'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('conversation'));
      await tester.pumpAndSettle();
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final center = tester.getCenter(find.byType(InteractiveViewer));
      final first = await tester.createGesture(pointer: 1);
      final second = await tester.createGesture(pointer: 2);
      await first.down(center - const Offset(40, 0));
      await second.down(center + const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 50));
      await first.moveTo(center - const Offset(80, 0));
      await second.moveTo(center + const Offset(80, 0));
      await tester.pump(const Duration(milliseconds: 50));
      await first.moveTo(center - const Offset(120, 0));
      await second.moveTo(center + const Offset(120, 0));
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        greaterThan(1.5),
      );
      viewer.transformationController!.value = Matrix4.identity();
      await tester.pump();
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(center);
      await tester.pumpAndSettle();
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        closeTo(2.5, .01),
      );
      final before = viewer.transformationController!.value.clone();
      await tester.drag(find.byType(InteractiveViewer), const Offset(50, 40));
      await tester.pumpAndSettle();
      expect(viewer.transformationController!.value, isNot(before));
      await tester.tap(find.byTooltip('Lưu ảnh'));
      await tester.pump();
      await tester.tap(find.byTooltip('Lưu ảnh'), warnIfMissed: false);
      await tester.pump();
      expect(calls, hasLength(1));
      expect(service.loads, 2);
      expect((calls.single.arguments as Map)['bytes'], orderedEquals(bytes));
      expect((calls.single.arguments as Map)['contentType'], 'image/png');
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Đã lưu ảnh vào thư viện ảnh.'), findsOneWidget);
      await tester.tap(find.byTooltip('Đóng ảnh'));
      await tester.pumpAndSettle();
      expect(find.text('conversation'), findsOneWidget);
    },
  );

  testWidgets(
    'viewer handles failed load and retry, permission denial and save failure',
    (tester) async {
      final bytes = await tester.runAsync(() => fixture(10, 10));
      final service = _Service(DownloadedMediaImage.fromBytes(bytes!))
        ..fail = true;
      const channel = MethodChannel('test/gallery-denied');
      var denied = true;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        _,
      ) async {
        throw PlatformException(
          code: denied ? 'permission_denied' : 'save_failed',
        );
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ChatImageViewer(
            storageKey: 'private/key',
            service: service,
            saver: const GalleryImageSaver(channel: channel),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Không tải được ảnh.'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == 'Lưu ảnh',
              ),
            )
            .onPressed,
        isNull,
      );
      service.fail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Lưu ảnh'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Chưa được phép'), findsOneWidget);
      denied = false;
      await tester.tap(find.byTooltip('Lưu ảnh'));
      await tester.pumpAndSettle();
      expect(find.text('Không thể lưu ảnh. Vui lòng thử lại.'), findsOneWidget);
    },
  );
}

class _Service extends MediaUploadService {
  final DownloadedMediaImage image;
  int loads = 0;
  bool fail = false;
  _Service(this.image) : super(apiDio: Dio());
  @override
  Future<DownloadedMediaImage> downloadImage(String storageKey) async {
    loads++;
    if (fail) throw const MediaUploadException('media_unavailable');
    return image;
  }
}
