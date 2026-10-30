import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/realtime/realtime_binding.dart';
import '../../../core/network/api_exception.dart';

import '../data/moment_models.dart';
import '../data/moments_api.dart';

/// Stable media identity; signed URLs stay in memory and never enter captions.
class MemoryMediaView extends StatefulWidget {
  final VideoPlayerController Function(Uri)? controllerFactory;
  final MemoryMedia media;
  final MomentsApi api;
  final BoxFit fit;
  final int? decodeWidth;
  const MemoryMediaView({
    super.key,
    required this.media,
    required this.api,
    this.controllerFactory,
    this.fit = BoxFit.cover,
    this.decodeWidth = 960,
  });
  @override
  State<MemoryMediaView> createState() => _MemoryMediaViewState();
}

class _MemoryMediaViewState extends State<MemoryMediaView> {
  late Future<String> url;
  int renewals = 0;
  @override
  void initState() {
    super.initState();
    if (!widget.media.isVideo) url = widget.api.mediaUrl(widget.media.id);
  }

  void retry() {
    if (mounted) {
      final next = widget.api.mediaUrl(widget.media.id);
      setState(() {
        url = next;
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.media.isVideo
      ? _PrivateVideo(
          key: ValueKey(widget.media.id),
          media: widget.media,
          api: widget.api,
          controllerFactory: widget.controllerFactory,
        )
      : FutureBuilder<String>(
          future: url,
          builder: (context, s) {
            if (s.hasError) return _MediaError(onRetry: retry);
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return Image.network(
              s.data!,
              fit: widget.fit,
              cacheWidth: widget.decodeWidth,
              gaplessPlayback: true,
              errorBuilder: (context, error, stack) {
                if (renewals++ == 0) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => retry());
                }
                return _MediaError(onRetry: retry);
              },
            );
          },
        );
}

class _PrivateVideo extends StatefulWidget {
  final VideoPlayerController Function(Uri)? controllerFactory;
  final MemoryMedia media;
  final MomentsApi api;
  const _PrivateVideo({
    super.key,
    required this.media,
    required this.api,
    this.controllerFactory,
  });
  @override
  State<_PrivateVideo> createState() => _PrivateVideoState();
}

class _PrivateVideoState extends State<_PrivateVideo>
    with WidgetsBindingObserver {
  VideoPlayerController? controller;
  Object? failure;
  int generation = 0, renewals = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  Future<void> load() async {
    final g = ++generation;
    final previous = controller;
    controller = null;
    await previous?.dispose();
    VideoPlayerController? next;
    try {
      final url = await widget.api.mediaUrl(widget.media.id);
      if (!mounted || g != generation) return;
      next =
          widget.controllerFactory?.call(Uri.parse(url)) ??
          VideoPlayerController.networkUrl(Uri.parse(url));
      await next.initialize();
      if (!mounted || g != generation) {
        await next.dispose();
        return;
      }
      final ready = next;
      setState(() {
        controller = ready;
        failure = null;
      });
      ready.addListener(() {
        if (mounted &&
            ready == controller &&
            ready.value.hasError &&
            failure == null) {
          setState(() => failure = StateError('Không thể phát video.'));
          if (renewals++ == 0) load();
        }
      });
    } catch (e) {
      await next?.dispose();
      if (mounted && g == generation) setState(() => failure = e);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) controller?.pause();
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (failure != null) return _MediaError(onRetry: load);
    final c = controller;
    if (c == null) return const Center(child: CircularProgressIndicator());
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: c,
      builder: (context, value, _) => Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
              child: VideoPlayer(c),
            ),
          ),
          IconButton.filledTonal(
            tooltip: value.isPlaying ? 'Tạm dừng' : 'Phát video MP4',
            onPressed: () => value.isPlaying ? c.pause() : c.play(),
            icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 4,
            child: VideoProgressIndicator(c, allowScrubbing: true),
          ),
        ],
      ),
    );
  }
}

class _MediaError extends StatelessWidget {
  final VoidCallback onRetry;
  const _MediaError({required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: TextButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('Không thể tải media. Thử lại'),
    ),
  );
}

void openMemoryMedia(
  BuildContext context,
  MemoryMedia media,
  MomentsApi api,
  String groupId, {
  List<MemoryMedia>? items,
  String? scope,
  String prefix = 'MOMENT_DELETED',
  String? aggregateId,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => MemoryGallery(
        media: media,
        items: items ?? [media],
        api: api,
        scope: scope ?? 'group:$groupId',
        prefix: prefix,
        aggregateId: aggregateId,
      ),
    ),
  );
}

/// One authorized viewer for Moments/Albums/check-ins/evidence/Community.
class MemoryGallery extends StatefulWidget {
  final MemoryMedia media;
  final List<MemoryMedia> items;
  final MomentsApi api;
  final String scope, prefix;
  final String? aggregateId;
  const MemoryGallery({
    super.key,
    required this.media,
    required this.items,
    required this.api,
    required this.scope,
    this.prefix = 'MOMENT_DELETED',
    this.aggregateId,
  });
  @override
  State<MemoryGallery> createState() => _MemoryGalleryState();
}

class _MemoryGalleryState extends State<MemoryGallery>
    with RealtimeBinding<MemoryGallery> {
  late final PageController pages;
  late int index;
  bool denied = false, zoomed = false;
  int generation = 0;
  @override
  String get realtimeScope => widget.scope;
  @override
  String get realtimePrefix => widget.prefix;
  @override
  String? get realtimeAggregateId => widget.aggregateId;
  @override
  void initState() {
    super.initState();
    index = widget.items.indexWhere((m) => m.id == widget.media.id);
    if (index < 0) index = 0;
    pages = PageController(initialPage: index);
  }

  @override
  void onRealtimeAccessLost() {
    generation++;
    if (mounted) setState(() => denied = true);
  }

  @override
  Future<void> reloadRealtime() async {
    final g = ++generation;
    try {
      await widget.api.mediaUrl(widget.items[index].id);
      if (mounted && g == generation) setState(() => denied = false);
    } on ApiException catch (e) {
      if (mounted &&
          g == generation &&
          [401, 403, 404].contains(e.statusCode)) {
        onRealtimeAccessLost();
      }
    }
  }

  @override
  void dispose() {
    generation++;
    pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text('${index + 1} / ${widget.items.length}'),
    ),
    body: denied
        ? const Center(
            child: Text(
              'Bạn không còn quyền xem media này.',
              style: TextStyle(color: Colors.white),
            ),
          )
        : SafeArea(
            child: PageView.builder(
              controller: pages,
              itemCount: widget.items.length,
              physics: zoomed
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              onPageChanged: (i) => setState(() {
                index = i;
                zoomed = false;
              }),
              itemBuilder: (context, i) => widget.items[i].isVideo
                  ? MemoryMediaView(
                      key: ValueKey(widget.items[i].id),
                      media: widget.items[i],
                      api: widget.api,
                    )
                  : _ZoomPhoto(
                      key: ValueKey(widget.items[i].id),
                      media: widget.items[i],
                      api: widget.api,
                      onZoom: (v) {
                        if (mounted && i == index && v != zoomed) {
                          setState(() => zoomed = v);
                        }
                      },
                    ),
            ),
          ),
  );
}

class _ZoomPhoto extends StatefulWidget {
  final MemoryMedia media;
  final MomentsApi api;
  final ValueChanged<bool> onZoom;
  const _ZoomPhoto({
    super.key,
    required this.media,
    required this.api,
    required this.onZoom,
  });
  @override
  State<_ZoomPhoto> createState() => _ZoomPhotoState();
}

class _ZoomPhotoState extends State<_ZoomPhoto> {
  final transform = TransformationController();
  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  void doubleTap() {
    final reset = transform.value.getMaxScaleOnAxis() > 1.01;
    final next = transform.value.clone()..setIdentity();
    if (!reset) {
      next.setEntry(0, 0, 2);
      next.setEntry(1, 1, 2);
    }
    transform.value = next;
    widget.onZoom(!reset);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onDoubleTap: doubleTap,
    child: InteractiveViewer(
      transformationController: transform,
      minScale: 1,
      maxScale: 5,
      onInteractionUpdate: (_) =>
          widget.onZoom(transform.value.getMaxScaleOnAxis() > 1.01),
      child: Center(
        child: MemoryMediaView(
          media: widget.media,
          api: widget.api,
          fit: BoxFit.contain,
          decodeWidth: 4096,
        ),
      ),
    ),
  );
}
