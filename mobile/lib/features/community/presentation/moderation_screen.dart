import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/realtime/realtime_binding.dart';
import '../../../core/realtime/reliable_read.dart';
import '../../moments/data/moments_api.dart';
import '../../moments/data/moment_models.dart';
import '../../moments/presentation/memories_screen.dart' show memoryNotice;
import '../data/moderation_api.dart';
import '../../moments/presentation/memory_media.dart';

Future<String?> chooseReportReason(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Lý do báo cáo')),
            for (final r in reportReasons.entries)
              ListTile(
                title: Text(r.value),
                onTap: () => Navigator.pop(context, r.key),
              ),
          ],
        ),
      ),
    );

class SafetyRead extends StatelessWidget {
  final ReliableRead<Json> read;
  final Future<void> Function() retry;
  final Widget Function(Json, bool) content;
  const SafetyRead({
    super.key,
    required this.read,
    required this.retry,
    required this.content,
  });
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: read,
    builder: (context, s, _) => Column(
      children: [
        if (read.failure != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextButton(
              onPressed: retry,
              child: Text(read.failure!.message),
            ),
          ),
        if (s.hasData)
          Expanded(child: content(s.requireData, read.failure == null))
        else if (s.connectionState == ConnectionState.waiting)
          const Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
      ],
    ),
  );
}

class CommunitySafetyScreen extends StatefulWidget {
  final ModerationApi api;
  const CommunitySafetyScreen({super.key, required this.api});
  @override
  State<CommunitySafetyScreen> createState() => _CommunitySafetyState();
}

class _CommunitySafetyState extends State<CommunitySafetyScreen>
    with RealtimeBinding<CommunitySafetyScreen> {
  final read = ReliableRead<Json>();
  String? viewer;
  @override
  String? get realtimeScope => viewer == null ? null : 'user:$viewer';
  @override
  String get realtimePrefix => '';
  @override
  bool get realtimeReadNeedsRecovery => read.failure?.retainData == true;
  @override
  void onRealtimeAccessLost() => read.denyAccess();
  @override
  void onRealtimeInvalidated() {
    if (read.failure?.accessDenied != true) read.reset();
  }

  @override
  void initState() {
    super.initState();
    reloadRealtime();
  }

  @override
  Future<void> reloadRealtime() => read.load(() async {
    final id = await widget.api.viewer();
    final access = await widget.api.access();
    if (mounted) {
      viewer = id;
      bindRealtimeResource('user:$id');
    }
    return access;
  });
  @override
  void dispose() {
    read.dispose();
    super.dispose();
  }

  void open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quyền riêng tư & an toàn')),
    body: SafetyRead(
      read: read,
      retry: reloadRealtime,
      content: (j, enabled) => ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Người đã chặn'),
            onTap: () =>
                open(SafetyPersonalList(api: widget.api, blocked: true)),
          ),
          ListTile(
            leading: const Icon(Icons.visibility_off_outlined),
            title: const Text('Bài viết đã ẩn'),
            onTap: () =>
                open(SafetyPersonalList(api: widget.api, blocked: false)),
          ),
          if (j['canReview'] == true)
            ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Duyệt báo cáo'),
              subtitle: Text(
                j['globalModerator'] == true
                    ? 'Moderator Community'
                    : 'Chỉ nội dung trong nhóm bạn quản lý',
              ),
              onTap: !enabled || viewer == null
                  ? null
                  : () =>
                        open(ModerationQueue(api: widget.api, viewer: viewer!)),
            ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Chặn không xóa lịch sử nhóm. Bỏ chặn không tự khôi phục quan hệ bạn bè. Báo cáo không tự gỡ nội dung.',
            ),
          ),
        ],
      ),
    ),
  );
}

class SafetyPersonalList extends StatefulWidget {
  final ModerationApi api;
  final bool blocked;
  const SafetyPersonalList({
    super.key,
    required this.api,
    required this.blocked,
  });
  @override
  State<SafetyPersonalList> createState() => _SafetyPersonalState();
}

class _SafetyPersonalState extends State<SafetyPersonalList>
    with RealtimeBinding<SafetyPersonalList> {
  final read = ReliableRead<Json>();
  String? viewer;
  bool busy = false;
  int pages = 1;
  @override
  String? get realtimeScope => viewer == null ? null : 'community:$viewer';
  @override
  String get realtimePrefix => 'COMMUNITY_';
  @override
  bool get realtimeReadNeedsRecovery => read.failure?.retainData == true;
  @override
  void onRealtimeAccessLost() => read.denyAccess();
  @override
  void onRealtimeInvalidated() {
    if (read.failure?.accessDenied != true) read.reset();
  }

  @override
  void initState() {
    super.initState();
    reloadRealtime();
  }

  @override
  Future<void> reloadRealtime() => read.load(() async {
    final id = await widget.api.viewer();
    final items = <dynamic>[];
    String? next;
    bool more = false;
    for (int page = 0; page < pages; page++) {
      final j = widget.blocked
          ? await widget.api.blocked(page: page)
          : await widget.api.hidden(before: next);
      items.addAll(j['items'] as List);
      next = j['nextBefore'] as String?;
      more = widget.blocked
          ? (j['hasNext'] == true ||
                j['hasMore'] == true ||
                ((j['totalPages'] as num?)?.toInt() ?? 0) > page + 1)
          : j['hasMore'] == true;
      if (!more) break;
    }
    if (mounted) {
      viewer = id;
      bindRealtimeResource('community:$id');
    }
    return {'items': items, 'hasMore': more};
  });
  Future<void> undo(String id) async {
    if (busy || read.failure != null) return;
    setState(() => busy = true);
    try {
      if (widget.blocked) {
        await widget.api.unblock(id);
      } else {
        await widget.api.unhide(id);
      }
      if (mounted) await reloadRealtime();
    } on ApiException catch (e) {
      if (mounted) {
        if ([401, 403, 404].contains(e.statusCode)) read.denyAccess();
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
    appBar: AppBar(
      title: Text(widget.blocked ? 'Người đã chặn' : 'Bài viết đã ẩn'),
    ),
    body: SafetyRead(
      read: read,
      retry: reloadRealtime,
      content: (j, current) => ListView(
        children: [
          if ((j['items'] as List).isEmpty)
            const ListTile(title: Text('Chưa có nội dung.')),
          for (final raw in j['items'] as List)
            Builder(
              builder: (context) {
                final row = Map<String, dynamic>.from(raw as Map);
                final user = widget.blocked
                    ? Map<String, dynamic>.from(row['blockedUser'] as Map)
                    : row;
                return ListTile(
                  title: Text(
                    widget.blocked
                        ? (user['displayName'] ??
                                  user['username'] ??
                                  'Người dùng')
                              as String
                        : row['caption'] as String,
                  ),
                  trailing: TextButton(
                    onPressed: current && !busy
                        ? () => undo(
                            (widget.blocked ? user['id'] : row['id']) as String,
                          )
                        : null,
                    child: Text(widget.blocked ? 'Bỏ chặn' : 'Hiện lại'),
                  ),
                );
              },
            ),
          if (j['hasMore'] == true)
            TextButton(
              onPressed: busy
                  ? null
                  : () {
                      pages++;
                      reloadRealtime();
                    },
              child: const Text('Xem thêm'),
            ),
        ],
      ),
    ),
  );
}

class ModerationQueue extends StatefulWidget {
  final ModerationApi api;
  final String viewer;
  const ModerationQueue({super.key, required this.api, required this.viewer});
  @override
  State<ModerationQueue> createState() => _ModerationQueueState();
}

class _ModerationQueueState extends State<ModerationQueue>
    with RealtimeBinding<ModerationQueue> {
  final read = ReliableRead<Json>();
  String? status = 'OPEN', reason, type;
  int pages = 1;
  @override
  String get realtimeScope => 'moderation:${widget.viewer}';
  @override
  String get realtimePrefix => 'MODERATION_';
  @override
  bool get realtimeReadNeedsRecovery => read.failure?.retainData == true;
  @override
  void onRealtimeAccessLost() => read.denyAccess();
  @override
  void onRealtimeInvalidated() {
    if (read.failure?.accessDenied != true) read.reset();
  }

  @override
  void initState() {
    super.initState();
    reloadRealtime();
  }

  @override
  Future<void> reloadRealtime() => read.load(() async {
    final items = <dynamic>[];
    String? next;
    bool more = false;
    for (int page = 0; page < pages; page++) {
      final j = await widget.api.queue(
        status: status,
        reason: reason,
        type: type,
        before: next,
      );
      items.addAll(j['items'] as List);
      next = j['nextBefore'] as String?;
      more = j['hasMore'] == true;
      if (!more) break;
    }
    return {'items': items, 'hasMore': more};
  });
  Widget filter(
    String title,
    String? value,
    Map<String, String> values,
    void Function(String?) set,
  ) => DropdownButton<String>(
    hint: Text(title),
    value: value,
    items: [
      DropdownMenuItem<String>(child: Text('Tất cả $title')),
      for (final e in values.entries)
        DropdownMenuItem(value: e.key, child: Text(e.value)),
    ],
    onChanged: (v) {
      setState(() => set(v));
      pages = 1;
      read.reset();
      reloadRealtime();
    },
  );
  @override
  void dispose() {
    read.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Duyệt báo cáo')),
    body: Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              filter('trạng thái', status, reviewStatuses, (v) => status = v),
              const SizedBox(width: 12),
              filter('lý do', reason, reportReasons, (v) => reason = v),
              const SizedBox(width: 12),
              filter('loại', type, reviewTypes, (v) => type = v),
            ],
          ),
        ),
        Expanded(
          child: SafetyRead(
            read: read,
            retry: reloadRealtime,
            content: (j, current) => ListView(
              children: [
                if ((j['items'] as List).isEmpty)
                  const ListTile(title: Text('Không có báo cáo phù hợp.')),
                for (final raw in j['items'] as List)
                  Builder(
                    builder: (context) {
                      final item = Map<String, dynamic>.from(raw as Map);
                      return ListTile(
                        leading: const Icon(Icons.flag_outlined),
                        title: Text(
                          '${reviewTypes[item['targetType']]} · ${reportReasons[item['reason']] ?? 'Nội dung không phù hợp'}',
                        ),
                        subtitle: Text(
                          item['evidence'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: !current
                            ? null
                            : () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ModerationReview(
                                      api: widget.api,
                                      viewer: widget.viewer,
                                      id: item['id'] as String,
                                    ),
                                  ),
                                );
                                if (mounted) await reloadRealtime();
                              },
                      );
                    },
                  ),
                if (j['hasMore'] == true)
                  TextButton(
                    onPressed: () {
                      pages++;
                      reloadRealtime();
                    },
                    child: const Text('Xem thêm'),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class ModerationReview extends StatefulWidget {
  final ModerationApi api;
  final String viewer, id;
  const ModerationReview({
    super.key,
    required this.api,
    required this.viewer,
    required this.id,
  });
  @override
  State<ModerationReview> createState() => _ModerationReviewState();
}

class _ModerationReviewState extends State<ModerationReview>
    with RealtimeBinding<ModerationReview> {
  final read = ReliableRead<Json>();
  final note = TextEditingController();
  bool busy = false;
  String? pendingId, pendingAction, pendingReason;
  @override
  String get realtimeScope => 'moderation:${widget.viewer}';
  @override
  String get realtimePrefix => 'MODERATION_';
  @override
  String? get realtimeAggregateId => widget.id;
  @override
  bool get realtimeReadNeedsRecovery => read.failure?.retainData == true;
  @override
  void onRealtimeAccessLost() {
    read.denyAccess();
    note.clear();
  }

  @override
  void onRealtimeInvalidated() {
    if (read.failure?.accessDenied != true) read.reset();
  }

  @override
  void initState() {
    super.initState();
    reloadRealtime();
  }

  @override
  Future<void> reloadRealtime() =>
      read.load(() => widget.api.review(widget.id));
  Future<void> decide(String action) async {
    if (busy || read.failure != null || note.text.trim().isEmpty) return;
    if (pendingAction != action || pendingReason != note.text.trim()) {
      pendingId = MomentsApi.commandId();
      pendingAction = action;
      pendingReason = note.text.trim();
    }
    setState(() => busy = true);
    final generation = read.generation;
    try {
      final result = await widget.api.decide(
        widget.id,
        pendingId!,
        action,
        pendingReason!,
      );
      if (mounted && read.isCurrent(generation)) {
        read.accept(result);
        pendingId = null;
        pendingAction = null;
        pendingReason = null;
        note.clear();
      }
    } on ApiException catch (e) {
      if (mounted) {
        if ([401, 403, 404].contains(e.statusCode)) onRealtimeAccessLost();
        memoryNotice(context, e);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    read.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Xem xét báo cáo')),
    body: SafetyRead(
      read: read,
      retry: reloadRealtime,
      content: (j, current) {
        final report = Map<String, dynamic>.from(j['report'] as Map);
        return ListView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Text(
              '${reviewTypes[report['targetType']]} · ${reportReasons[report['reason']] ?? 'Nội dung không phù hợp'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(report['evidence'] as String),
            if ((j['media'] as List? ?? []).isNotEmpty)
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                children: [
                  for (final raw in j['media'] as List)
                    MemoryMediaView(
                      media: MemoryMedia.fromJson(
                        Map<String, dynamic>.from(raw as Map),
                      ),
                      api: ModerationEvidenceApi(widget.api.dio, widget.id),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            Text(reviewStatuses[report['status']] ?? 'Đã xử lý'),
            Text(
              report['contentStatus'] == 'REMOVED'
                  ? 'Nội dung đã gỡ'
                  : report['contentStatus'] == 'DELETED'
                  ? 'Tác giả đã xóa'
                  : 'Nội dung chưa bị gỡ',
            ),
            TextField(
              controller: note,
              enabled: current && !busy,
              maxLength: 1000,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              decoration: const InputDecoration(
                labelText: 'Lý do quyết định (bắt buộc)',
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final action in report['allowedActions'] as List)
                  OutlinedButton(
                    onPressed: current && !busy
                        ? () => decide(action as String)
                        : null,
                    child: Text(reviewActions[action] ?? 'Xem xét'),
                  ),
              ],
            ),
            const Divider(),
            const Text('Lịch sử xử lý'),
            for (final raw in j['history'] as List)
              Builder(
                builder: (context) {
                  final h = Map<String, dynamic>.from(raw as Map);
                  return ListTile(
                    title: Text(reviewActions[h['action']] ?? 'Xem xét'),
                    subtitle: Text(
                      '${h['reason']}\n${DateTime.parse(h['createdAt'] as String).toLocal()}',
                    ),
                  );
                },
              ),
          ],
        );
      },
    ),
  );
}
