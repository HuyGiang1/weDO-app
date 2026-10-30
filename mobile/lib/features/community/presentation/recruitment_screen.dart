import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/realtime/realtime_binding.dart';
import '../../../core/realtime/realtime_sync.dart';
import '../../../core/realtime/reliable_read.dart';
import '../../moments/data/moment_models.dart';
import '../../moments/data/moments_api.dart';
import '../../moments/presentation/memories_screen.dart' show memoryNotice;
import '../data/community_api.dart';
import '../data/recruitment_api.dart';
import '../data/recruitment_models.dart';
import 'community_screen.dart' show CommunityRead, CommunityCard;

String recruitDate(DateTime value) {
  final d = value.toLocal();
  return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

Future<DateTime?> recruitPickDate(
  BuildContext context,
  DateTime? initial,
) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final now = DateTime.now();
  final start = initial ?? now.add(const Duration(hours: 1));
  final day = await showDatePicker(
    context: context,
    initialDate: start,
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: now.add(const Duration(days: 1095)),
  );
  if (day == null || !context.mounted) return initial;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(start),
  );
  if (time == null) return initial;
  return DateTime(day.year, day.month, day.day, time.hour, time.minute);
}

class RecruitmentComposer extends StatefulWidget {
  final RecruitmentApi api;
  const RecruitmentComposer({super.key, required this.api});
  @override
  State<RecruitmentComposer> createState() => _RecruitmentComposerState();
}

class _RecruitmentComposerState extends State<RecruitmentComposer>
    with RealtimeBinding<RecruitmentComposer> {
  final options = ReliableRead<List<Json>>();
  final caption = TextEditingController(),
      count = TextEditingController(text: '3'),
      location = TextEditingController(),
      tags = TextEditingController();
  final command = MomentsApi.commandId();
  String? group, activity;
  String visibility = 'PUBLIC';
  List<(String, String)> activities = [];
  DateTime? planned, expires;
  bool busy = false, loadingActivities = false;
  int generation = 0, activityGeneration = 0;
  @override
  String get realtimeScope => 'user:self';
  @override
  String get realtimePrefix => 'GROUP_';
  @override
  void onRealtimeAccessLost() {
    generation++;
    activityGeneration++;
    loadingActivities = false;
    options.denyAccess();
    caption.clear();
    location.clear();
    tags.clear();
    group = null;
    activities = [];
  }

  @override
  Future<void> reloadRealtime() async {
    generation++;
    await options.load(
      widget.api.options,
      onData: (list) {
        if (group != null && !list.any((o) => o['groupId'] == group)) {
          activityGeneration++;
          loadingActivities = false;
          group = null;
          activity = null;
          activities = [];
        }
      },
    );
    if (options.failure?.accessDenied == true) onRealtimeAccessLost();
  }

  @override
  void initState() {
    super.initState();
    reloadRealtime();
  }

  Future<void> select(String? id) async {
    generation++;
    final g = ++activityGeneration;
    setState(() {
      group = id;
      activity = null;
      activities = [];
      loadingActivities = true;
    });
    try {
      final list = id == null
          ? <(String, String)>[]
          : await widget.api.activities(id);
      if (mounted &&
          g == activityGeneration &&
          group == id &&
          options.failure?.accessDenied != true) {
        setState(() => activities = list);
      }
    } on ApiException catch (e) {
      if (mounted && g == activityGeneration) {
        if ([401, 403, 404].contains(e.statusCode)) options.denyAccess();
        memoryNotice(context, e);
      }
    } finally {
      if (mounted && g == activityGeneration) {
        setState(() => loadingActivities = false);
      }
    }
  }

  Future<void> submit() async {
    if (busy || options.failure != null || group == null) return;
    final amount = int.tryParse(count.text);
    if (caption.text.trim().isEmpty ||
        amount == null ||
        amount < 1 ||
        amount > 100) {
      memoryNotice(
        context,
        const ApiException(
          statusCode: 400,
          message: 'Nhập nội dung và số người từ 1 đến 100.',
        ),
      );
      return;
    }
    if (planned != null && !planned!.isAfter(DateTime.now()) ||
        expires != null && !expires!.isAfter(DateTime.now())) {
      memoryNotice(
        context,
        const ApiException(
          statusCode: 400,
          message: 'Chọn cả ngày và giờ trong tương lai.',
        ),
      );
      return;
    }
    final g = generation;
    setState(() => busy = true);
    try {
      await widget.api.createRecruitment({
        'clientRequestId': command,
        'groupId': group,
        'activityId': activity,
        'caption': caption.text.trim(),
        'visibility': visibility,
        'requestedCount': amount,
        'broadLocation': location.text.trim(),
        'tags': tags.text
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        'plannedAt': planned?.toUtc().toIso8601String(),
        'expiresAt': expires?.toUtc().toIso8601String(),
        'mediaKeys': <String>[],
      });
      if (mounted && g == generation) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) memoryNotice(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    generation++;
    options.dispose();
    for (final t in [caption, count, location, tags]) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Tìm thành viên'),
      actions: [
        IconButton(
          tooltip: 'Ẩn bàn phím',
          onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
          icon: const Icon(Icons.keyboard_hide_outlined),
        ),
      ],
    ),
    body: CommunityRead(
      read: options,
      bounded: true,
      retry: reloadRealtime,
      content: (list, enabled) => ListView(
        padding: const EdgeInsets.all(16),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const Text(
            'Chủ nhóm hoặc quản trị viên có thể đăng tuyển cho nhóm đang hoạt động và yêu cầu duyệt. Người đăng ký vẫn cần được duyệt.',
          ),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Chưa có nhóm phù hợp. Tạo nhóm QA riêng hoặc bật yêu cầu duyệt trong Cài đặt nhóm bạn quản lý.',
              ),
            ),
          DropdownButtonFormField<String>(
            isExpanded: true,
            key: ValueKey(group),
            initialValue: group,
            decoration: const InputDecoration(
              labelText: 'Nhóm tuyển thành viên',
            ),
            items: [
              for (final o in list)
                DropdownMenuItem(
                  value: o['groupId'] as String,
                  child: Text(o['groupName'] as String, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: enabled && !busy ? select : null,
          ),
          if (group != null)
            DropdownButtonFormField<String>(
            isExpanded: true,
              key: ValueKey('activity-$group-$activity-${activities.length}'),
              initialValue: activity,
              decoration: InputDecoration(
                labelText: loadingActivities
                    ? 'Đang tải hoạt động…'
                    : 'Hoạt động (không bắt buộc)',
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Chỉ tuyển cho nhóm'),
                ),
                for (final a in activities)
                  DropdownMenuItem(value: a.$1, child: Text(a.$2, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: enabled && !busy && !loadingActivities
                  ? (v) => setState(() => activity = v)
                  : null,
            ),
          TextField(
            controller: caption,
            enabled: enabled && !busy,
            maxLength: 5000,
            minLines: 3,
            maxLines: 6,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            decoration: const InputDecoration(
              labelText: 'Bạn đang tìm ai?',
              hintText: 'Ví dụ: Tìm 3 người đi Ba Vì cuối tuần',
            ),
          ),
          TextField(
            controller: count,
            enabled: enabled && !busy,
            keyboardType: TextInputType.number,
            maxLength: 3,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            decoration: const InputDecoration(labelText: 'Số người cần tuyển'),
          ),
          TextField(
            controller: location,
            enabled: enabled && !busy,
            maxLength: 160,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            decoration: const InputDecoration(
              labelText: 'Khu vực chung',
              hintText: 'Ví dụ: Ba Vì, Hà Nội · Không chia sẻ vị trí trực tiếp',
            ),
          ),
          TextField(
            controller: tags,
            enabled: enabled && !busy,
            maxLength: 197,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            decoration: const InputDecoration(
              labelText: 'Sở thích (cách nhau bằng dấu phẩy)',
              hintText: 'đi bộ, du lịch · Tối đa 6 thẻ',
            ),
          ),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: visibility,
            decoration: const InputDecoration(labelText: 'Ai có thể xem?'),
            items: [
              for (final e in communityVisibility.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: enabled && !busy
                ? (v) => setState(() => visibility = v!)
                : null,
          ),
          TextButton.icon(
            onPressed: enabled && !busy
                ? () async {
                    final v = await recruitPickDate(context, planned);
                    if (mounted) setState(() => planned = v);
                  }
                : null,
            icon: const Icon(Icons.event_outlined),
            label: Text(
              planned == null
                  ? 'Ngày và giờ dự kiến (không bắt buộc)'
                  : recruitDate(planned!),
            ),
          ),
          TextButton.icon(
            onPressed: enabled && !busy
                ? () async {
                    final v = await recruitPickDate(context, expires);
                    if (mounted) setState(() => expires = v);
                  }
                : null,
            icon: const Icon(Icons.timer_outlined),
            label: Text(
              expires == null
                  ? 'Hạn nhận yêu cầu · Mặc định 30 ngày hoặc ngày dự kiến'
                  : recruitDate(expires!),
            ),
          ),
          const Text(
            'Đếm người được duyệt qua bài này; yêu cầu đang chờ không chiếm chỗ. Tham gia nhóm không tự đăng ký RSVP.',
          ),
          FilledButton(
            onPressed: enabled && !busy && group != null ? submit : null,
            child: Text(busy ? 'Đang đăng…' : 'Đăng tin tuyển'),
          ),
        ].expand((child) => [child, const SizedBox(height: 16)]).toList(),
      ),
    ),
  );
}

class RecruitmentSnippet extends StatelessWidget {
  final CommunityApi api;
  final CommunityPost post;
  const RecruitmentSnippet({super.key, required this.api, required this.post});
  @override
  Widget build(BuildContext context) {
    final r = post.recruitment;
    if (r == null) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${r.groupName} · ${recruitmentStates[r.status] ?? 'Đang cập nhật'}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            '${r.approved}/${r.requested} người đã được duyệt · Còn ${r.remaining} chỗ',
          ),
          if (r.activityTitle != null) Text('Hoạt động · ${r.activityTitle}'),
          if (r.broadLocation.isNotEmpty) Text(r.broadLocation),
          if (r.plannedAt != null) Text(recruitDate(r.plannedAt!)),
          if (r.tags.isNotEmpty) Text(r.tags.map((t) => '#$t').join('  ')),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RecruitmentPreview(
                      api: RecruitmentApi(api.dio),
                      post: post.id,
                    ),
                  ),
                ),
                child: const Text('Xem nhóm'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RecruitmentPreview(
                      api: RecruitmentApi(api.dio),
                      post: post.id,
                    ),
                  ),
                ),
                child: Text(
                  r.canRequest
                      ? 'Yêu cầu tham gia'
                      : recruitmentRequests[r.requestState] ?? 'Xem trạng thái',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RecruitmentPreview extends StatefulWidget {
  final RecruitmentApi api;
  final String post;
  const RecruitmentPreview({super.key, required this.api, required this.post});
  @override
  State<RecruitmentPreview> createState() => _RecruitmentPreviewState();
}

class _RecruitmentPreviewState extends State<RecruitmentPreview>
    with RealtimeBinding<RecruitmentPreview> {
  final read = ReliableRead<CommunityPost>();
  bool busy = false;
  @override
  String get realtimeScope => 'post:${widget.post}';
  @override
  String get realtimePrefix => 'COMMUNITY_';
  @override
  bool get realtimeReadNeedsRecovery => read.failure?.retainData == true;
  @override
  void onRealtimeAccessLost() => read.denyAccess();
  @override
  Future<void> reloadRealtime() =>
      read.load(() => widget.api.post(widget.post));
  @override
  void initState() {
    super.initState();
    reloadRealtime();
  }

  Future<void> act(Future<void> Function() action) async {
    if (busy || read.failure != null) return;
    setState(() => busy = true);
    try {
      await action();
      if (mounted && read.failure?.accessDenied != true) await reloadRealtime();
    } catch (e) {
      if (mounted) {
        if (e is ApiException && [401, 403, 404].contains(e.statusCode)) {
          read.denyAccess();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Xem nhóm tuyển thành viên')),
    body: CommunityRead(
      read: read,
      bounded: true,
      retry: reloadRealtime,
      content: (p, enabled) {
        final r = p.recruitment;
        if (r == null) return const Text('Tin tuyển không còn tồn tại.');
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(r.groupName, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(p.caption),
            const SizedBox(height: 12),
            Text(recruitmentStates[r.status] ?? 'Đang cập nhật'),
            Text(
              '${r.approved}/${r.requested} người đã được duyệt · Còn ${r.remaining} chỗ',
            ),
            if (r.activityTitle != null) Text('Hoạt động · ${r.activityTitle}'),
            if (r.broadLocation.isNotEmpty)
              Text('Khu vực · ${r.broadLocation}'),
            if (r.plannedAt != null)
              Text('Dự kiến · ${recruitDate(r.plannedAt!)}'),
            Text('Nhận yêu cầu đến · ${recruitDate(r.expiresAt)}'),
            if (r.tags.isNotEmpty)
              Wrap(
                spacing: 8,
                children: [for (final t in r.tags) Chip(label: Text(t))],
              ),
            const SizedBox(height: 16),
            Text(recruitmentRequests[r.requestState] ?? 'Đang cập nhật'),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Đây là thông tin giới thiệu được công bố trong bài tuyển. Chat, danh sách thành viên, khoảnh khắc và tài chính của nhóm chỉ mở sau khi được duyệt.',
              ),
            ),
            if (r.canRequest)
              FilledButton(
                onPressed: enabled && !busy
                    ? () => act(() => widget.api.join(p.id))
                    : null,
                child: Text(busy ? 'Đang gửi…' : 'Yêu cầu tham gia'),
              ),
            if (r.canCancel)
              OutlinedButton(
                onPressed: enabled && !busy
                    ? () => act(() => widget.api.cancelRequest(p.id))
                    : null,
                child: const Text('Hủy yêu cầu'),
              ),
            if (r.canManage) ...[
              TextButton(
                onPressed: enabled && !busy
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              RecruitmentRequests(api: widget.api, post: p.id),
                        ),
                      )
                    : null,
                child: const Text('Duyệt yêu cầu'),
              ),
              OutlinedButton(
                onPressed: enabled && !busy && r.status != 'CLOSED'
                    ? () => act(() => widget.api.closeRecruitment(p.id))
                    : null,
                child: const Text('Đóng tuyển thành viên'),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class RecruitmentRequests extends StatefulWidget {
  final RecruitmentApi api;
  final String post;
  const RecruitmentRequests({super.key, required this.api, required this.post});
  @override
  State<RecruitmentRequests> createState() => _RecruitmentRequestsState();
}

class _RecruitmentRequestsState extends State<RecruitmentRequests>
    with RealtimeBinding<RecruitmentRequests> {
  final read = ReliableRead<List<Json>>();
  bool busy = false;
  @override
  String get realtimeScope => 'review:${widget.post}';
  @override
  String get realtimePrefix => 'COMMUNITY_RECRUITMENT_';
  @override
  bool get realtimeReadNeedsRecovery => read.failure?.retainData == true;
  @override
  void onRealtimeAccessLost() => read.denyAccess();
  @override
  Future<void> reloadRealtime() =>
      read.load(() => widget.api.requests(widget.post));
  @override
  void initState() {
    super.initState();
    reloadRealtime();
  }

  Future<void> resolve(String request, bool approve) async {
    if (busy || read.failure != null) return;
    setState(() => busy = true);
    try {
      await widget.api.resolve(widget.post, request, approve);
      if (mounted) await reloadRealtime();
    } catch (e) {
      if (mounted) {
        if (e is ApiException && [401, 403, 404].contains(e.statusCode)) {
          read.denyAccess();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Duyệt yêu cầu')),
    body: CommunityRead(
      read: read,
      bounded: true,
      retry: reloadRealtime,
      content: (list, enabled) => list.isEmpty
          ? const Center(child: Text('Chưa có yêu cầu chờ duyệt qua bài này.'))
          : ListView(
              children: [
                for (final r in list)
                  ListTile(
                    title: Text(
                      r['userDisplayName'] as String? ?? 'Thành viên',
                    ),
                    subtitle: const Text('Đang chờ duyệt'),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Từ chối',
                          onPressed: enabled && !busy
                              ? () => resolve(r['id'] as String, false)
                              : null,
                          icon: const Icon(Icons.close),
                        ),
                        IconButton(
                          tooltip: 'Duyệt',
                          onPressed: enabled && !busy
                              ? () => resolve(r['id'] as String, true)
                              : null,
                          icon: const Icon(Icons.check),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    ),
  );
}

class RecruitmentDiscovery extends StatefulWidget {
  final RecruitmentApi api;
  final String viewer;
  const RecruitmentDiscovery({
    super.key,
    required this.api,
    required this.viewer,
  });
  @override
  State<RecruitmentDiscovery> createState() => _RecruitmentDiscoveryState();
}

class _RecruitmentDiscoveryState extends State<RecruitmentDiscovery>
    with RealtimeBinding<RecruitmentDiscovery> {
  final read = ReliableRead<List<CommunityPost>>(),
      keyword = TextEditingController(),
      tag = TextEditingController(),
      location = TextEditingController();
  final scroll = ScrollController();
  String? next;
  DateTime? from, to;
  bool available = false, more = false;
  int pages = 1;
  RealtimeSync? sync;
  void Function()? unwatch;
  @override
  String get realtimeScope => 'community:${widget.viewer}';
  @override
  String get realtimePrefix => 'COMMUNITY_RECRUITMENT_CREATED';
  @override
  Set<String> get realtimeAdditionalPrefixes => {'COMMUNITY_POLICY_CHANGED'};
  @override
  bool get realtimeReadNeedsRecovery => read.failure?.retainData == true;
  @override
  void onRealtimeAccessLost() => read.denyAccess();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = RealtimeHost.maybeOf(context);
    if (sync != current) {
      unwatch?.call();
      sync = current;
      unwatch = current?.watch(
        realtimeScope,
        'COMMUNITY_POLICY_CHANGED',
        () {},
        onChange: (e) {
          if (e != null) read.reset();
        },
      );
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Future<void> reloadRealtime() async {
    final types = takeRealtimeEventTypes();
    if (types.isNotEmpty &&
        types.every((t) => t == 'COMMUNITY_RECRUITMENT_CREATED') &&
        read.value.hasData) {
      if (mounted) setState(() => available = true);
      return;
    }
    await load();
  }

  Future<void> load({bool older = false}) async {
    final old = read.value.data ?? <CommunityPost>[];
    String? cursor = older ? next : null;
    int fetched = 0;
    await read.load(
      () async {
        final items = <CommunityPost>[];
        for (int page = 0; page < (older ? 1 : pages); page++) {
          final p = await widget.api.discover(
            keyword: keyword.text,
            tag: tag.text,
            location: location.text,
            from: from,
            to: to,
            before: cursor,
          );
          if (!mounted) return <CommunityPost>[];
          items.addAll(p.items);
          fetched++;
          cursor = p.next;
          if (cursor == null) break;
        }
        return {
          for (final p in [...(older ? old : <CommunityPost>[]), ...items])
            p.id: p,
        }.values.toList();
      },
      onData: (_) {
        if (mounted) {
          setState(() {
            next = cursor;
            pages = older ? pages + 1 : fetched;
            available = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    unwatch?.call();
    read.dispose();
    scroll.dispose();
    keyword.dispose();
    tag.dispose();
    location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Tìm người đồng hành'),
      actions: [
        IconButton(
          tooltip: 'Đăng tin tuyển',
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RecruitmentComposer(api: widget.api),
              ),
            );
            if (mounted) await load();
          },
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                controller: keyword,
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                decoration: const InputDecoration(
                  labelText: 'Từ khóa tuyển thành viên',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked =
                      constraints.maxWidth < 400 ||
                      MediaQuery.textScalerOf(context).scale(14) > 16.8;
                  final fields = [
                    TextField(
                      controller: tag,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      decoration: const InputDecoration(labelText: 'Sở thích'),
                    ),
                    TextField(
                      controller: location,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      decoration: const InputDecoration(labelText: 'Khu vực'),
                    ),
                  ];
                  return stacked
                      ? Column(
                          children: [
                            fields[0],
                            const SizedBox(height: 16),
                            fields[1],
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: fields[0]),
                            const SizedBox(width: 12),
                            Expanded(child: fields[1]),
                          ],
                        );
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () async {
                      final d = await recruitPickDate(context, from);
                      if (mounted) setState(() => from = d);
                    },
                    child: Text(
                      from == null ? 'Từ ngày/giờ' : recruitDate(from!),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final d = await recruitPickDate(context, to);
                      if (mounted) setState(() => to = d);
                    },
                    child: Text(to == null ? 'Đến ngày/giờ' : recruitDate(to!)),
                  ),
                  FilledButton.tonal(
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      pages = 1;
                      read.reset();
                      load();
                    },
                    child: const Text('Tìm kiếm'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (available)
          TextButton(
            onPressed: () => load(),
            child: const Text('Có bài tuyển mới · Xem cập nhật'),
          ),
        Expanded(
          child: CommunityRead(
            read: read,
            bounded: true,
            retry: () => load(),
            content: (list, enabled) => list.isEmpty
                ? const Center(
                    child: Text('Chưa có tin tuyển phù hợp đang mở.'),
                  )
                : ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length + (next == null ? 0 : 1),
                    itemBuilder: (c, i) {
                      if (i == list.length) {
                        return TextButton(
                          onPressed: enabled && !more
                              ? () async {
                                  setState(() => more = true);
                                  await load(older: true);
                                  if (mounted) setState(() => more = false);
                                }
                              : null,
                          child: const Text('Xem tin cũ hơn'),
                        );
                      }
                      return AbsorbPointer(
                        absorbing: !enabled,
                        child: CommunityCard(
                          key: ValueKey(list[i].id),
                          api: widget.api,
                          initial: list[i],
                          viewer: widget.viewer,
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    ),
  );
}
