import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../media/data/gallery_image_saver.dart';
import '../../media/data/media_upload_service.dart';
import '../../media/presentation/media_storage_image.dart';

/// The image's intrinsic geometry determines its size inside responsive bounds.
class ChatImageFrame extends StatelessWidget {
  final ImageProvider image;
  final VoidCallback onOpen;
  final VoidCallback onRetry;
  const ChatImageFrame({
    super.key,
    required this.image,
    required this.onOpen,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.min(320.0, constraints.maxWidth);
      final height = math.min(400.0, MediaQuery.sizeOf(context).height * .55);
      final ratio = MediaQuery.devicePixelRatioOf(context);
      return Semantics(
        button: true,
        label: 'Mở ảnh toàn màn hình',
        child: GestureDetector(
          onTap: onOpen,
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width, maxHeight: height),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image(
                  image: ResizeImage(
                    image,
                    width: (width * ratio).ceil(),
                    height: (height * ratio).ceil(),
                    policy: ResizeImagePolicy.fit,
                  ),
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  frameBuilder: (context, child, frame, synchronous) =>
                      synchronous || frame != null
                      ? child
                      : const _ImagePlaceholder(),
                  errorBuilder: (_, error, stack) =>
                      _ImagePlaceholder(onRetry: onRetry),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class ChatImageThumbnail extends StatefulWidget {
  final String storageKey;
  const ChatImageThumbnail({super.key, required this.storageKey});

  @override
  State<ChatImageThumbnail> createState() => _ChatImageThumbnailState();
}

class _ChatImageThumbnailState extends State<ChatImageThumbnail> {
  late Future<String> _url;

  Future<String> _resolve() =>
      MediaStorageImage.service?.authorizedReadUrl(widget.storageKey) ??
      Future.error(const MediaUploadException('media_unavailable'));

  @override
  void initState() {
    super.initState();
    _url = _resolve();
  }

  @override
  void didUpdateWidget(covariant ChatImageThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storageKey != widget.storageKey) _url = _resolve();
  }

  void _retry() => setState(() {
    _url = _resolve();
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _url,
    builder: (context, snapshot) {
      if (snapshot.hasError) return _ImagePlaceholder(onRetry: _retry);
      final url = snapshot.data;
      if (url == null) return const _ImagePlaceholder();
      return ChatImageFrame(
        image: NetworkImage(url),
        onRetry: _retry,
        onOpen: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => ChatImageViewer(storageKey: widget.storageKey),
          ),
        ),
      );
    },
  );
}

class ChatImageViewer extends StatefulWidget {
  final String storageKey;
  final MediaUploadService? service;
  final GalleryImageSaver saver;
  const ChatImageViewer({
    super.key,
    required this.storageKey,
    this.service,
    this.saver = const GalleryImageSaver(),
  });

  @override
  State<ChatImageViewer> createState() => _ChatImageViewerState();
}

class _ChatImageViewerState extends State<ChatImageViewer> {
  final _transform = TransformationController();
  late Future<DownloadedMediaImage> _image;
  Offset _doubleTap = Offset.zero;
  bool _saving = false;

  Future<DownloadedMediaImage> _load() =>
      (widget.service ?? MediaStorageImage.service)?.downloadImage(
        widget.storageKey,
      ) ??
      Future.error(const MediaUploadException('media_unavailable'));

  @override
  void initState() {
    super.initState();
    _image = _load();
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_transform.value.getMaxScaleOnAxis() > 1.05) {
      _transform.value = Matrix4.identity();
    } else {
      _transform.value = Matrix4.diagonal3Values(2.5, 2.5, 1)
        ..setTranslationRaw(-_doubleTap.dx * 1.5, -_doubleTap.dy * 1.5, 0);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    String message;
    try {
      // Fresh authorization at save time, not an expired/cached URL or screenshot.
      final original = await _load();
      await widget.saver.save(original);
      message = 'Đã lưu ảnh vào thư viện ảnh.';
    } on PlatformException catch (error) {
      message = switch (error.code) {
        'permission_denied' =>
          'Chưa được phép lưu ảnh. Bạn có thể cho phép thêm ảnh trong Cài đặt.',
        'permission_restricted' => 'Thiết bị đang hạn chế quyền thêm ảnh. Vui lòng kiểm tra giới hạn quyền riêng tư của thiết bị.',
        'permission_unavailable' => 'iOS chưa cấp được quyền thêm ảnh. Vui lòng thử lại khi ứng dụng đang mở.',
        _ => 'Không thể lưu ảnh. Vui lòng thử lại.',
      };
    } catch (_) {
      message = 'Không thể lưu ảnh. Vui lòng kiểm tra kết nối và thử lại.';
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Đóng ảnh',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Ảnh'),
        actions: [
          FutureBuilder<DownloadedMediaImage>(
            future: _image,
            builder: (context, snapshot) => IconButton(
              tooltip: 'Lưu ảnh',
              onPressed: snapshot.hasData && !_saving ? _save : null,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<DownloadedMediaImage>(
          future: _image,
          builder: (context, snapshot) {
            final image = snapshot.data;
            if (image == null) {
              return Center(
                child: snapshot.hasError
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Không tải được ảnh.',
                            style: TextStyle(color: Colors.white),
                          ),
                          TextButton.icon(
                            onPressed: () => setState(() {
                              _image = _load();
                            }),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Thử lại'),
                          ),
                        ],
                      )
                    : const CircularProgressIndicator(),
              );
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onDoubleTapDown: (details) =>
                      _doubleTap = details.localPosition,
                  onDoubleTap: _toggleZoom,
                  child: InteractiveViewer(
                    transformationController: _transform,
                    minScale: 1,
                    maxScale: 6,
                    child: SizedBox.expand(
                      child: Center(
                        child: Image(
                          image: ResizeImage(
                            MemoryImage(image.bytes),
                            width: 4096,
                            height: 4096,
                            policy: ResizeImagePolicy.fit,
                          ),
                          fit: BoxFit.contain,
                          semanticLabel: 'Ảnh trò chuyện',
                          errorBuilder: (_, error, stack) => const Text(
                            'Không đọc được ảnh.',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: ValueListenableBuilder<Matrix4>(
                      valueListenable: _transform,
                      builder: (context, matrix, _) {
                        final scale = matrix.getMaxScaleOnAxis();
                        return scale <= 1.05
                            ? const SizedBox.shrink()
                            : Center(
                                child: Text(
                                  '${scale.toStringAsFixed(1)}×',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    backgroundColor: Colors.black54,
                                  ),
                                ),
                              );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _ImagePlaceholder extends StatelessWidget {
  final VoidCallback? onRetry;
  const _ImagePlaceholder({this.onRetry});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 180,
    height: 120,
    child: Center(
      child: onRetry == null
          ? const CircularProgressIndicator()
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image_outlined),
                const Text('Không tải được ảnh'),
                IconButton(
                  tooltip: 'Tải lại ảnh',
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
    ),
  );
}
