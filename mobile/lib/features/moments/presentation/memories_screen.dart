import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/realtime/realtime_binding.dart';
import '../../../core/realtime/reliable_read.dart';
import '../../activity/data/activity_api.dart';
import '../../activity/data/activity_models.dart';
import '../../social/presentation/widgets/user_avatar.dart';
import '../data/moment_models.dart';
import '../data/moments_api.dart';
import 'memory_media.dart';

String memoryTime(DateTime value) {
  final d = value.toLocal();
  return '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

void memoryNotice(BuildContext c, Object error) {
  final message = error is ApiException
      ? error.message ?? ReadFailure.fromError(error)?.message
      : null;
  if (error is! ApiException) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, library: 'Moments'),
    );
  }
  ScaffoldMessenger.of(c).showSnackBar(
    SnackBar(content: Text(message ?? 'Không thể hoàn tất. Vui lòng thử lại.')),
  );
}

Future<bool> memoryConfirm(BuildContext c, String title) async =>
    await showDialog<bool>(
      context: c,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: const Text(
          'Nội dung sẽ không còn hiển thị. Media dùng chung không bị xóa khỏi kho.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    ) ??
    false;

// Resource cards are shrink-wrapped inside feeds/details. The shared bounded
// screen builder uses Expanded, so reuse its read policy without that layout.
class _InlineRead<T> extends StatelessWidget {
  final ReliableRead<T> read;
  final VoidCallback onRetry;
  final Widget Function(BuildContext, AsyncSnapshot<T>) builder;
  const _InlineRead({
    required this.read,
    required this.onRetry,
    required this.builder,
  });
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<AsyncSnapshot<T>>(
        valueListenable: read,
        builder: (context, s, _) {
          final failure = read.failure;
          if (!s.hasData) {
            return failure == null
                ? const SizedBox(
                    height: 48,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : TextButton(
                    onPressed: onRetry,
                    child: Text('${failure.message} Thử lại'),
                  );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (failure != null)
                TextButton(
                  onPressed: onRetry,
                  child: Text('Dữ liệu chưa được cập nhật. ${failure.message}'),
                ),
              AbsorbPointer(
                absorbing: failure != null,
                child: builder(context, s),
              ),
            ],
          );
        },
      );
}

class MemoriesScreen extends StatefulWidget {
  final String groupId;
  final String? activityId;
  final MomentsApi api;
  const MemoriesScreen({
    super.key,
    required this.groupId,
    required this.api,
    this.activityId,
  });
  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen>
    with RealtimeBinding<MemoriesScreen> {
  final read = ReliableRead<List<MomentPost>>();
  final scroll = ScrollController();
  String? next;
  bool canCreate = false, newPosts = false, paging = false;
  int tab = 0;
  @override
  String get realtimeScope => 'group:${widget.groupId}';
  @override
  String get realtimePrefix => 'MOMENT_CREATED';
  @override
  Set<String> get realtimeAdditionalPrefixes => {'MOMENT_DELETED'};
  @override
  bool get realtimeReadNeedsRecovery => read.failure?.retainData == true;
  @override
  void onRealtimeAccessLost() {
    next = null;
    canCreate = false;
    read.denyAccess();
  }

  @override
  void initState() {
    super.initState();
    read.addListener(_rebuild);
    load();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> load({bool more = false}) async {
    if (more && (next == null || paging)) return;
    if (more) paging = true;
    final previous = read.value.data ?? <MomentPost>[];
    final before = more ? next : null;
    String? cursor;
    var allowed = false;
    await read.load(
      () async {
        final p = await widget.api.feed(
          widget.groupId,
          activity: widget.activityId,
          before: before,
        );
        final values = more ? [...previous, ...p.items] : p.items;
        cursor = p.next;
        allowed = p.canCreate;
        return (values.fold<Map<String, MomentPost>>(
          {},
          (m, p) => m..[p.id] = p,
        )).values.toList();
      },
      onData: (items) {
        next = cursor;
        canCreate = allowed;
      },
    );
    paging = false;
  }

  @override
  Future<void> reloadRealtime() async {
    if (scroll.hasClients && scroll.offset > 48 && read.value.hasData) {
      if (mounted) setState(() => newPosts = true);
      return;
    }
    await load();
  }

  @override
  void dispose() {
    read.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.activityId == null ? 'Khoảnh khắc' : 'Khoảnh khắc hoạt động',
      ),
      actions: [
        if (tab == 0 && canCreate && read.failure == null)
          IconButton(
            tooltip: 'Đăng khoảnh khắc',
            onPressed: () => Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) => MomentComposer(
                      api: widget.api,
                      groupId: widget.groupId,
                      activityId: widget.activityId,
                    ),
                  ),
                )
                .then((v) {
                  if (mounted && v != null) load();
                }),
            icon: const Icon(Icons.add_photo_alternate_outlined),
          ),
      ],
    ),
    body: Column(
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              label: Text('Khoảnh khắc'),
              icon: Icon(Icons.photo_library_outlined),
            ),
            ButtonSegment(
              value: 1,
              label: Text('Album'),
              icon: Icon(Icons.collections_bookmark_outlined),
            ),
          ],
          selected: {tab},
          onSelectionChanged: (s) => setState(() => tab = s.first),
        ),
        Expanded(
          child: tab == 1
              ? AlbumList(
                  api: widget.api,
                  groupId: widget.groupId,
                  activityId: widget.activityId,
                )
              : ReliableReadBuilder<List<MomentPost>>(
                  read: read,
                  onRetry: () => load(),
                  builder: (context, s) => s.hasData
                      ? Column(
                          children: [
                            if (newPosts)
                              TextButton.icon(
                                onPressed: () {
                                  setState(() => newPosts = false);
                                  load();
                                },
                                icon: const Icon(Icons.arrow_upward),
                                label: const Text('Có bài mới · Xem cập nhật'),
                              ),
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: () => load(),
                                child: ListView(
                                  controller: scroll,
                                  padding: const EdgeInsets.all(12),
                                  children: [
                                    if (s.requireData.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.all(48),
                                        child: Text(
                                          'Chưa có khoảnh khắc. Chia sẻ kỷ niệm đầu tiên nhé!',
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    for (final post in s.requireData)
                                      MomentView(
                                        key: ValueKey(post.id),
                                        initial: post,
                                        api: widget.api,
                                      ),
                                    if (next != null)
                                      TextButton(
                                        onPressed: () => load(more: true),
                                        child: Text(
                                          paging ? 'Đang tải…' : 'Xem thêm',
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
        ),
      ],
    ),
  );
}

class MomentComposer extends StatefulWidget {
  final MomentsApi api;
  final String groupId;
  final String? activityId, albumId;
  final MomentPost? editing;
  final Future<List<XFile>> Function()? pickPhotos;
  final Future<XFile?> Function()? pickVideo;
  const MomentComposer({
    super.key,
    required this.api,
    required this.groupId,
    this.activityId,
    this.albumId,
    this.editing,
    this.pickPhotos,
    this.pickVideo,
  });
  @override
  State<MomentComposer> createState() => _MomentComposerState();
}

class _MomentComposerState extends State<MomentComposer>
    with RealtimeBinding<MomentComposer> {
  bool blocked = false;
  int permissionGeneration = 0;
  @override
  String get realtimeScope => 'group:${widget.groupId}';
  @override
  String get realtimePrefix => 'GROUP_';
  @override
  void onRealtimeAccessLost() {
    permissionGeneration++;
    caption.clear();
    files.clear();
    uploaded.clear();
    activities.denyAccess();
    if (mounted) setState(() => blocked = true);
  }

  @override
  Future<void> reloadRealtime() async {
    final g = ++permissionGeneration;
    try {
      final p = await widget.api.feed(widget.groupId);
      if (mounted && g == permissionGeneration) {
        if (!p.canCreate) {
          onRealtimeAccessLost();
        } else {
          setState(() => blocked = false);
        }
      }
    } on ApiException catch (e) {
      if (mounted &&
          g == permissionGeneration &&
          [401, 403, 404].contains(e.statusCode)) {
        onRealtimeAccessLost();
      }
    }
  }

  late final caption = TextEditingController(
    text: widget.editing?.caption ?? '',
  );
  final command = MomentsApi.commandId();
  final files = <XFile>[];
  final uploaded = <String, String>{};
  final activities = ReliableRead<List<ActivitySummary>>();
  String? activity;
  bool busy = false;
  double progress = 0;
  MomentPost? created;
  @override
  void initState() {
    super.initState();
    activity = widget.editing?.activityId ?? widget.activityId;
    activities.load(() async {
      var page = 0;
      final result = <ActivitySummary>[];
      while (true) {
        final p = await ActivityApi(widget.api.dio)
            .list(widget.groupId, page: page++);
        result.addAll(p.items);
        if (!p.hasNext) break;
      }
      return result;
    });
  }

  @override
  void dispose() {
    caption.dispose();
    activities.dispose();
    super.dispose();
  }

  Future<void> pick({bool video = false, bool camera = false}) async {
    try {
      final picker = ImagePicker();
      final List<XFile> selected;
      if (video) {
        final f =
            await (widget.pickVideo?.call() ??
                picker.pickVideo(source: ImageSource.gallery));
        selected = f == null ? [] : [f];
      } else if (camera) {
        final f = await picker.pickImage(source: ImageSource.camera);
        selected = f == null ? [] : [f];
      } else {
        selected = await (widget.pickPhotos?.call() ?? picker.pickMultiImage());
      }
      if (!mounted) return;
      if (files.length + selected.length > 8) {
        memoryNotice(
          context,
          const ApiException(
            statusCode: 400,
            message: 'Tối đa 8 ảnh/video mỗi bài.',
          ),
        );
        return;
      }
      setState(() => files.addAll(selected));
    } catch (e) {
      if (mounted) memoryNotice(context, e);
    }
  }

  Future<void> save() async {
    if (busy || blocked) return;
    if (caption.text.trim().isEmpty &&
        files.isEmpty &&
        (widget.editing?.media.isEmpty ?? true)) {
      memoryNotice(
        context,
        const ApiException(
          statusCode: 400,
          message: 'Nhập nội dung hoặc chọn ảnh/video.',
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      if (widget.editing != null) {
        created = await widget.api.edit(
          widget.editing!,
          caption.text.trim(),
          activity,
        );
      } else if (created == null) {
        for (final file in files) {
          if (!mounted || blocked) return;
          if (uploaded.containsKey(file.path)) continue;
          uploaded[file.path] = await widget.api.upload(
            widget.groupId,
            file,
            progress: (sent, total) {
              if (mounted) {
                setState(() => progress = total > 0 ? sent / total : 0);
              }
            },
          );
        }
        if (!mounted || blocked) return;
        created = await widget.api.create(
          widget.groupId,
          command,
          caption.text.trim(),
          files.map((f) => uploaded[f.path]!).toList(),
          activity: activity,
        );
      }
      if (!mounted || blocked) return;
      if (widget.albumId != null) {
        await widget.api.addItems(
          widget.albumId!,
          created!.media.map((m) => m.id).toList(),
        );
      }
      if (mounted) Navigator.pop(context, created);
    } catch (e) {
      if (mounted) memoryNotice(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => blocked
      ? const Scaffold(
          body: SafeArea(
            child: Center(
              child: Text('Bạn không còn quyền chia sẻ trong nhóm này.'),
            ),
          ),
        )
      : Scaffold(
          appBar: AppBar(
            title: Text(
              widget.editing == null
                  ? 'Chia sẻ khoảnh khắc'
                  : 'Sửa khoảnh khắc',
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: caption,
                enabled: !busy,
                maxLength: 5000,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Bạn muốn lưu lại kỷ niệm gì?',

                ),
              ),
              _ActivityChoice(
                read: activities,
                selected: activity,
                onChanged: busy ? null : (v) => setState(() => activity = v),
              ),
              if (widget.editing == null)
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => pick(),
                      icon: const Icon(Icons.photo_outlined),
                      label: const Text('Chọn ảnh'),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => pick(camera: true),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Máy ảnh'),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => pick(video: true),
                      icon: const Icon(Icons.videocam_outlined),
                      label: const Text('Video MP4'),
                    ),
                  ],
                ),
              const Text(
                'Ảnh JPG/PNG/WebP ≤ 10 MB · MP4 H.264/AAC ≤ 50 MB · Tối đa 8 media',
                style: TextStyle(fontSize: 11),
              ),
              for (final f in files)
                ListTile(
                  leading: f.name.toLowerCase().endsWith('.mp4')
                      ? const Icon(Icons.movie_outlined)
                      : Image.file(
                          File(f.path),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, s) => const Icon(Icons.image),
                        ),
                  title: Text(
                    f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    onPressed: busy
                        ? null
                        : () => setState(() => files.remove(f)),
                    icon: const Icon(Icons.close),
                  ),
                ),
              if (busy) ...[
                LinearProgressIndicator(value: progress > 0 ? progress : null),
                const Text('Đang tải và lưu…'),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(
                  busy
                      ? 'Đang lưu…'
                      : widget.editing == null
                      ? 'Đăng khoảnh khắc'
                      : 'Lưu thay đổi',
                ),
              ),
            ],
          ),
        );
}

class _ActivityChoice extends StatelessWidget {
  final ReliableRead<List<ActivitySummary>> read;
  final String? selected;
  final ValueChanged<String?>? onChanged;
  const _ActivityChoice({
    required this.read,
    required this.selected,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: read,
    builder: (context, s, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: selected,
          decoration: const InputDecoration(
            labelText: 'Hoạt động (không bắt buộc)',
          ),
          isExpanded: true,
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Chỉ trong nhóm'),
            ),
            for (final a in s.data ?? <ActivitySummary>[])
              DropdownMenuItem(
                value: a.id,
                child: Text(a.title, overflow: TextOverflow.ellipsis),
              ),
            if (selected != null &&
                !(s.data ?? []).any((a) => a.id == selected))
              DropdownMenuItem(
                value: selected,
                child: const Text('Hoạt động đang liên kết'),
              ),
          ],
          onChanged: onChanged,
        ),
        if (read.failure != null)
          const Text(
            'Chưa tải được hoạt động; vẫn có thể chia sẻ trong nhóm.',
            style: TextStyle(fontSize: 11),
          ),
      ],
    ),
  );
}

class MomentView extends StatefulWidget {
  final MomentPost initial;
  final MomentsApi api;
  final bool detail;
  const MomentView({
    super.key,
    required this.initial,
    required this.api,
    this.detail = false,
  });
  @override
  State<MomentView> createState() => _MomentViewState();
}

class _MomentViewState extends State<MomentView>
    with RealtimeBinding<MomentView> {
  final read = ReliableRead<MomentPost>();
  final comments = ReliableRead<List<MemoryComment>>();
  final input = TextEditingController();
  String? commentNext, commentCommand;
  bool busy = false;
  @override
  String get realtimeScope => 'group:${widget.initial.groupId}';
  @override
  String get realtimePrefix => 'MOMENT_';
  @override
  String get realtimeAggregateId => widget.initial.id;
  @override
  bool get realtimeReadNeedsRecovery =>
      read.failure?.retainData == true || comments.failure?.retainData == true;
  @override
  void onRealtimeAccessLost() {
    read.denyAccess();
    comments.denyAccess();
  }

  @override
  void initState() {
    super.initState();
    read.accept(widget.initial);
    reloadRealtime();
  }

  @override
  Future<void> reloadRealtime() async {
    await read.load(() => widget.api.get(widget.initial.id));
    if (read.failure?.accessDenied == true) {
      comments.denyAccess();
      return;
    }
    if (widget.detail) await loadComments();
  }

  Future<void> loadComments({bool more = false}) async {
    final old = comments.value.data ?? <MemoryComment>[];
    String? next;
    await comments.load(() async {
      final p = await widget.api.comments(
        widget.initial.id,
        before: more ? commentNext : null,
      );
      next = p.next;
      return more ? [...old, ...p.items] : p.items;
    }, onData: (_) => commentNext = next);
    if (comments.failure?.accessDenied == true) read.denyAccess();
  }

  Future<void> action(Future<void> Function() operation) async {
    if (!mounted || busy || read.failure != null) return;
    setState(() => busy = true);
    try {
      await operation();
    } catch (e) {
      if (mounted) {
        if (e is ApiException && [401, 403, 404].contains(e.statusCode)) {
          onRealtimeAccessLost();
        }
        memoryNotice(context, e);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    read.dispose();
    comments.dispose();
    input.dispose();
    super.dispose();
  }

  void openDetail(MomentPost p) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Khoảnh khắc')),
        body: SingleChildScrollView(
          child: MomentView(initial: p, api: widget.api, detail: true),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => _InlineRead<MomentPost>(
    read: read,
    onRetry: reloadRealtime,
    builder: (context, s) {
      if (!s.hasData) return const SizedBox();
      final p = s.requireData;
      final enabled = !busy && read.failure == null && p.permissions.interact;
      return Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UserAvatar(
                    displayName: p.author.name,
                    avatarStorageKey: p.author.avatar,
                    radius: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.author.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          memoryTime(p.createdAt),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (p.permissions.edit || p.permissions.delete)
                    PopupMenuButton<String>(
                      enabled: !busy && read.failure == null,
                      onSelected: (v) async {
                        if (v == 'edit') {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MomentComposer(
                                api: widget.api,
                                groupId: p.groupId,
                                editing: p,
                              ),
                            ),
                          );
                          if (mounted) reloadRealtime();
                        } else if (await memoryConfirm(
                          context,
                          'Xóa khoảnh khắc?',
                        )) {
                          await action(() async {
                            await widget.api.delete(p.id);
                            read.denyAccess();
                          });
                        }
                      },
                      itemBuilder: (_) => [
                        if (p.permissions.edit)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Sửa nội dung'),
                          ),
                        if (p.permissions.delete)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Xóa khoảnh khắc'),
                          ),
                      ],
                    ),
                ],
              ),
              if (p.activityTitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Hoạt động · ${p.activityTitle}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              if (p.caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    p.caption,
                    maxLines: widget.detail ? null : 5,
                    overflow: widget.detail ? null : TextOverflow.ellipsis,
                  ),
                ),
              if (p.media.isNotEmpty)
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: p.media.length == 1 ? 1 : 2,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  children: [
                    for (final m in p.media)
                      InkWell(
                        key: ValueKey(m.id),
                        onTap: () =>
                            openMemoryMedia(context, m, widget.api, p.groupId, items:p.media, aggregateId:p.id),
                        child: MemoryMediaView(
                          key: ValueKey('media-${m.id}'),
                          media: m,
                          api: widget.api,
                        ),
                      ),
                  ],
                ),
              Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: enabled
                        ? () => action(() async {
                            final generation = read.generation;
                            final next = await widget.api.react(
                              p.id,
                              p.myReaction == null ? '❤️' : null,
                            );
                            if (mounted && read.isCurrent(generation)) {
                              read.accept(next);
                            }
                          })
                        : null,
                    icon: Icon(
                      p.myReaction == null
                          ? Icons.favorite_border
                          : Icons.favorite,
                    ),
                    label: Text('${p.reactions} cảm xúc'),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Đổi cảm xúc',
                    enabled: enabled,
                    icon: const Icon(Icons.add_reaction_outlined, size: 20),
                    itemBuilder: (_) => [
                      for (final emoji in ['👍', '❤️', '😂', '😮', '😢', '😡'])
                        PopupMenuItem(value: emoji, child: Text(emoji)),
                    ],
                    onSelected: (emoji) => action(() async {
                      final generation = read.generation;
                      final next = await widget.api.react(p.id, emoji);
                      if (mounted && read.isCurrent(generation)) {
                        read.accept(next);
                      }
                    }),
                  ),
                  TextButton.icon(
                    onPressed: widget.detail ? null : () => openDetail(p),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: Text('${p.comments} bình luận'),
                  ),
                  TextButton(
                    onPressed: enabled
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AlbumList(
                                api: widget.api,
                                groupId: p.groupId,
                                selectMedia: p.media.map((m) => m.id).toList(),
                              ),
                            ),
                          )
                        : null,
                    child: const Text('Thêm vào album'),
                  ),
                ],
              ),
              if (!widget.detail)
                TextButton(
                  onPressed: () => openDetail(p),
                  child: const Text('Xem chi tiết'),
                ),
              if (widget.detail) ...[
                ValueListenableBuilder(
                  valueListenable: comments,
                  builder: (context, c, _) => Column(
                    children: [
                      for (final comment in c.data ?? <MemoryComment>[])
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: UserAvatar(
                            displayName: comment.author.name,
                            avatarStorageKey: comment.author.avatar,
                            radius: 14,
                          ),
                          title: Text(
                            comment.author.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${comment.text}\n${memoryTime(comment.createdAt)}',
                          ),
                          trailing: comment.canDelete
                              ? IconButton(
                                  tooltip: 'Xóa bình luận',
                                  onPressed: enabled
                                      ? () => action(() async {
                                          await widget.api.deleteComment(
                                            p.id,
                                            comment.id,
                                          );
                                          await reloadRealtime();
                                        })
                                      : null,
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                )
                              : null,
                        ),
                      if (commentNext != null)
                        TextButton(
                          onPressed: () => loadComments(more: true),
                          child: const Text('Bình luận trước'),
                        ),
                    ],
                  ),
                ),
                if (comments.failure != null)
                  TextButton(
                    onPressed: () => loadComments(),
                    child: Text(comments.failure!.message),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: input,
                        enabled: enabled,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          hintText: 'Viết bình luận…',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Gửi bình luận',
                      onPressed: enabled
                          ? () => action(() async {
                              if (input.text.trim().isEmpty) return;
                              commentCommand ??= MomentsApi.commandId();
                              await widget.api.comment(
                                p.id,
                                commentCommand!,
                                input.text.trim(),
                              );
                              commentCommand = null;
                              input.clear();
                              await reloadRealtime();
                            })
                          : null,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class AlbumList extends StatefulWidget {
  final MomentsApi api;
  final String groupId;
  final String? activityId;
  final List<String>? selectMedia;
  const AlbumList({
    super.key,
    required this.api,
    required this.groupId,
    this.activityId,
    this.selectMedia,
  });
  @override
  State<AlbumList> createState() => _AlbumListState();
}

class _AlbumListState extends State<AlbumList> with RealtimeBinding<AlbumList> {
  final read = ReliableRead<List<MemoryAlbum>>();
  String? next;
  bool busy = false, canCreate = false;
  @override
  String get realtimeScope => 'group:${widget.groupId}';
  @override
  String get realtimePrefix => 'ALBUM_';
  @override
  bool get realtimeReadNeedsRecovery => read.failure?.retainData == true;
  @override
  void onRealtimeAccessLost() => read.denyAccess();
  @override
  void initState() {
    super.initState();
    reloadRealtime();
  }

  @override
  Future<void> reloadRealtime() => load();
  Future<void> load({bool more = false}) async {
    final old = read.value.data ?? <MemoryAlbum>[];
    String? cursor;
    var allowed = false;
    await read.load(
      () async {
        final p = await widget.api.albums(
          widget.groupId,
          activity: widget.activityId,
          before: more ? next : null,
        );
        cursor = p.next;
        allowed = p.canCreate;
        return more ? [...old, ...p.items] : p.items;
      },
      onData: (_) {
        next = cursor;
        canCreate = allowed;
      },
    );
  }

  @override
  void dispose() {
    read.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = ReliableReadBuilder<List<MemoryAlbum>>(
      read: read,
      onRetry: reloadRealtime,
      builder: (context, s) => !s.hasData
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (canCreate && read.failure == null)
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) => AlbumEditor(
                              api: widget.api,
                              groupId: widget.groupId,
                              activityId: widget.activityId,
                            ),
                          ),
                        )
                        .then((v) {
                          if (mounted && v != null) load();
                        }),
                    icon: const Icon(Icons.add),
                    label: const Text('Tạo album'),
                  ),
                if (s.requireData.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Chưa có album.'),
                  ),
                for (final a in s.requireData)
                  ListTile(
                    key: ValueKey(a.id),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    leading: a.cover == null
                        ? const Icon(Icons.photo_album_outlined, size: 44)
                        : SizedBox.square(
                            dimension: 56,
                            child: MemoryMediaView(
                              key: ValueKey(a.cover!.id),
                              media: a.cover!,
                              api: widget.api,
                            ),
                          ),
                    title: Text(a.name),
                    subtitle: Text(
                      '${a.count} media${a.activityTitle == null ? '' : ' · ${a.activityTitle}'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: busy
                        ? null
                        : () async {
                            if (widget.selectMedia != null) {
                              if (!a.permissions.manage) {
                                memoryNotice(
                                  context,
                                  const ApiException(
                                    statusCode: 403,
                                    message: 'Chỉ người tạo hoặc quản trị viên được quản lý album.',
                                  ),
                                );
                                return;
                              }
                              setState(() => busy = true);
                              try {
                                await widget.api.addItems(
                                  a.id,
                                  widget.selectMedia!,
                                );
                                if (context.mounted) {
                                  Navigator.pop(context, true);
                                }
                              } catch (e) {
                                if (context.mounted) memoryNotice(context, e);
                              } finally {
                                if (mounted) setState(() => busy = false);
                              }
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AlbumDetail(api: widget.api, initial: a),
                                ),
                              );
                            }
                          },
                  ),
                if (next != null)
                  TextButton(
                    onPressed: () => load(more: true),
                    child: const Text('Xem thêm album'),
                  ),
              ],
            ),
    );
    return widget.selectMedia == null
        ? body
        : Scaffold(
            appBar: AppBar(title: const Text('Chọn album')),
            body: body,
          );
  }
}

class AlbumEditor extends StatefulWidget {
  final MomentsApi api;
  final String groupId;
  final String? activityId;
  final MemoryAlbum? editing;
  const AlbumEditor({
    super.key,
    required this.api,
    required this.groupId,
    this.activityId,
    this.editing,
  });
  @override
  State<AlbumEditor> createState() => _AlbumEditorState();
}

class _AlbumEditorState extends State<AlbumEditor>
    with RealtimeBinding<AlbumEditor> {
  bool blocked = false;
  int permissionGeneration = 0;
  @override
  String get realtimeScope => 'group:${widget.groupId}';
  @override
  String get realtimePrefix => 'GROUP_';
  @override
  void onRealtimeAccessLost() {
    permissionGeneration++;
    name.clear();
    description.clear();
    activities.denyAccess();
    if (mounted) setState(() => blocked = true);
  }

  @override
  Future<void> reloadRealtime() async {
    final g = ++permissionGeneration;
    try {
      final p = await widget.api.albums(widget.groupId);
      if (mounted && g == permissionGeneration) {
        if (!p.canCreate) {
          onRealtimeAccessLost();
        } else {
          setState(() => blocked = false);
        }
      }
    } on ApiException catch (e) {
      if (mounted &&
          g == permissionGeneration &&
          [401, 403, 404].contains(e.statusCode)) {
        onRealtimeAccessLost();
      }
    }
  }

  late final name = TextEditingController(text: widget.editing?.name ?? ''),
      description = TextEditingController(
        text: widget.editing?.description ?? '',
      );
  late final id = widget.editing?.id ?? MomentsApi.commandId();
  final activities = ReliableRead<List<ActivitySummary>>();
  String? activity;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    activity = widget.editing?.activityId ?? widget.activityId;
    activities.load(() async {
      var page = 0;
      final rows = <ActivitySummary>[];
      while (true) {
        final r = await ActivityApi(widget.api.dio)
            .list(widget.groupId, page: page++);
        rows.addAll(r.items);
        if (!r.hasNext) return rows;
      }
    });
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    activities.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || blocked) return;
    if (name.text.trim().isEmpty) {
      memoryNotice(
        context,
        const ApiException(statusCode: 400, message: 'Nhập tên album.'),
      );
      return;
    }
    setState(() => busy = true);
    try {
      final a = await widget.api.saveAlbum(
        widget.groupId,
        id,
        name.text.trim(),
        description.text.trim(),
        activity: activity,
        update: widget.editing != null,
      );
      if (mounted) Navigator.pop(context, a);
    } catch (e) {
      if (mounted) memoryNotice(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => blocked
      ? const Scaffold(
          body: SafeArea(
            child: Center(
              child: Text('Bạn không còn quyền quản lý album này.'),
            ),
          ),
        )
      : Scaffold(
          appBar: AppBar(
            title: Text(widget.editing == null ? 'Tạo album' : 'Sửa album'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: name,
                maxLength: 160,
                enabled: !busy,
                decoration: const InputDecoration(labelText: 'Tên album'),
              ),
              TextField(
                controller: description,
                maxLength: 2000,
                maxLines: 3,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Mô tả (không bắt buộc)',
                ),
              ),
              _ActivityChoice(
                read: activities,
                selected: activity,
                onChanged: busy ? null : (v) => setState(() => activity = v),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? 'Đang lưu…' : 'Lưu album'),
              ),
            ],
          ),
        );
}

class AlbumDetail extends StatefulWidget {
  final MomentsApi api;
  final MemoryAlbum initial;
  const AlbumDetail({super.key, required this.api, required this.initial});
  @override
  State<AlbumDetail> createState() => _AlbumDetailState();
}

class _AlbumContent {
  final MemoryAlbum album;
  final List<MemoryMedia> media;
  final String? next;
  const _AlbumContent(this.album, this.media, this.next);
}

class _AlbumDetailState extends State<AlbumDetail>
    with RealtimeBinding<AlbumDetail> {
  final read = ReliableRead<_AlbumContent>();
  bool busy = false;
  @override
  String get realtimeScope => 'group:${widget.initial.groupId}';
  @override
  String get realtimePrefix => 'ALBUM_';
  @override
  String get realtimeAggregateId => widget.initial.id;
  @override
  bool get realtimeReadNeedsRecovery => read.failure?.retainData == true;
  @override
  void onRealtimeAccessLost() => read.denyAccess();
  @override
  void initState() {
    super.initState();
    reloadRealtime();
  }

  @override
  Future<void> reloadRealtime() => load();
  Future<void> load({bool more = false}) => read.load(() async {
    final a = await widget.api.album(widget.initial.id);
    final old = read.value.data;
    final p = await widget.api.albumMedia(
      a.id,
      before: more ? old?.next : null,
    );
    return _AlbumContent(
      a,
      more ? [...?old?.media, ...p.items] : p.items,
      p.next,
    );
  });
  @override
  void dispose() {
    read.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Album')),
    body: ReliableReadBuilder<_AlbumContent>(
      read: read,
      onRetry: reloadRealtime,
      builder: (context, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final a = s.requireData.album;
        final enabled = a.permissions.manage && !busy && read.failure == null;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(a.name, style: Theme.of(context).textTheme.headlineSmall),
            if (a.description.isNotEmpty) Text(a.description),
            if (a.activityTitle != null) Text('Hoạt động · ${a.activityTitle}'),
            Text('${a.count} media'),
            if (a.permissions.manage)
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: enabled
                        ? () => Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (_) => MomentComposer(
                                    api: widget.api,
                                    groupId: a.groupId,
                                    activityId: a.activityId,
                                    albumId: a.id,
                                  ),
                                ),
                              )
                              .then((v) {
                                if (mounted && v != null) load();
                              })
                        : null,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Tải media mới'),
                  ),
                  TextButton(
                    onPressed: enabled
                        ? () => Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (_) => ExistingMediaPicker(
                                    api: widget.api,
                                    album: a,
                                  ),
                                ),
                              )
                              .then((v) {
                                if (mounted && v == true) load();
                              })
                        : null,
                    child: const Text('Chọn từ khoảnh khắc'),
                  ),
                  TextButton(
                    onPressed: enabled
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AlbumEditor(
                                api: widget.api,
                                groupId: a.groupId,
                                editing: a,
                              ),
                            ),
                          )
                        : null,
                    child: const Text('Sửa album'),
                  ),
                  TextButton(
                    onPressed: enabled
                        ? () async {
                            if (!await memoryConfirm(context, 'Xóa album?')) {
                              return;
                            }
                            try {
                              await widget.api.deleteAlbum(a.id);
                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              if (context.mounted) memoryNotice(context, e);
                            }
                          }
                        : null,
                    child: const Text('Xóa album'),
                  ),
                ],
              ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [
                for (final m in s.requireData.media)
                  Stack(
                    key: ValueKey(m.id),
                    fit: StackFit.expand,
                    children: [
                      InkWell(
                        onTap: () =>
                            openMemoryMedia(context, m, widget.api, a.groupId, items:s.requireData.media),
                        child: MemoryMediaView(media: m, api: widget.api),
                      ),
                      if (enabled)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton.filledTonal(
                            tooltip: 'Gỡ khỏi album',
                            onPressed: () async {
                              try {
                                await widget.api.removeItem(a.id, m.id);
                                if (mounted) load();
                              } catch (e) {
                                if (context.mounted) memoryNotice(context, e);
                              }
                            },
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            if (s.requireData.media.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text('Album chưa có ảnh hoặc video.'),
              ),
            if (s.requireData.next != null)
              TextButton(
                onPressed: () => load(more: true),
                child: const Text('Xem thêm media'),
              ),
          ],
        );
      },
    ),
  );
}

class ExistingMediaPicker extends StatefulWidget {
  final MomentsApi api;
  final MemoryAlbum album;
  const ExistingMediaPicker({
    super.key,
    required this.api,
    required this.album,
  });
  @override
  State<ExistingMediaPicker> createState() => _ExistingMediaPickerState();
}

class _ExistingMediaPickerState extends State<ExistingMediaPicker>
    with RealtimeBinding<ExistingMediaPicker> {
  @override
  String get realtimeScope => 'group:${widget.album.groupId}';
  @override
  String get realtimePrefix => 'MOMENT_';
  @override
  Future<void> reloadRealtime() => load();
  @override
  void onRealtimeAccessLost() {
    selected.clear();
    read.denyAccess();
  }

  @override
  bool get realtimeReadNeedsRecovery => read.failure?.retainData == true;
  final read = ReliableRead<List<MomentPost>>();
  final selected = <String>{};
  String? next;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool more = false}) async {
    final previous = read.value.data ?? <MomentPost>[];
    String? cursor;
    await read.load(() async {
      final p = await widget.api.feed(
        widget.album.groupId,
        before: more ? next : null,
      );
      cursor = p.next;
      return more ? [...previous, ...p.items] : p.items;
    }, onData: (_) => next = cursor);
  }

  @override
  void dispose() {
    read.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chọn media có sẵn')),
    body: ReliableReadBuilder<List<MomentPost>>(
      read: read,
      onRetry: () => load(),
      builder: (context, s) => !s.hasData
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                for (final p in s.requireData)
                  for (final m in p.media)
                    CheckboxListTile(
                      value: selected.contains(m.id),
                      title: Text(m.name),
                      subtitle: Text(
                        p.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onChanged: busy
                          ? null
                          : (v) => setState(
                              () => v == true
                                  ? selected.add(m.id)
                                  : selected.remove(m.id),
                            ),
                    ),
                if (next != null)
                  TextButton(
                    onPressed: () => load(more: true),
                    child: const Text('Xem thêm'),
                  ),
                FilledButton(
                  onPressed: busy || selected.isEmpty || read.failure != null
                      ? null
                      : () async {
                          setState(() => busy = true);
                          try {
                            await widget.api.addItems(
                              widget.album.id,
                              selected.toList(),
                            );
                            if (context.mounted) Navigator.pop(context, true);
                          } catch (e) {
                            if (context.mounted) memoryNotice(context, e);
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        },
                  child: const Text('Thêm vào album'),
                ),
              ],
            ),
    ),
  );
}
