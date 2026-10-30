import '../../../core/ui/widgets/app_management.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/realtime/realtime_binding.dart';
import '../../../core/realtime/reliable_read.dart';
import '../../moments/data/moment_models.dart';
import '../../moments/data/moments_api.dart';
import '../../moments/presentation/memory_media.dart';
import '../../moments/presentation/memories_screen.dart'
    show memoryNotice, memoryConfirm;
import '../../social/presentation/widgets/user_avatar.dart';
import '../data/journey_api.dart';
import '../../task/data/task_api.dart';
import '../../task/data/task_repository.dart';
import '../../task/presentation/screens/task_screens.dart';
import '../../groups/data/group_api.dart';

Json object(dynamic value) => Map<String, dynamic>.from(value as Map);
String localTime(dynamic value) {
  if (value == null) return 'Chưa đặt';
  final t = DateTime.parse(value as String).toLocal();
  return '${t.day}/${t.month} · ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

Future<DateTime?> journeyDateTime(
  BuildContext context,
  DateTime initial,
) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  return time == null
      ? null
      : DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

class JourneyRead extends StatelessWidget {
  final ReliableRead<Json> read;
  final Future<void> Function() retry;
  final Widget Function(Json, bool) builder;
  const JourneyRead({
    super.key,
    required this.read,
    required this.retry,
    required this.builder,
  });
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: read,
    builder: (context, s, _) => Column(
      children: [
        if (read.failure != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh),
              label: Text(read.failure!.message),
            ),
          ),
        if (s.hasData)
          Expanded(child: builder(s.requireData, read.failure == null))
        else if (s.connectionState == ConnectionState.waiting)
          const Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
      ],
    ),
  );
}

IconData _stopStatusIcon(String status) => switch (status) {
  'IN_PROGRESS' => Icons.play_circle_filled,
  'COMPLETED' => Icons.check_circle,
  'SKIPPED' => Icons.skip_next,
  'CANCELLED' => Icons.cancel_outlined,
  _ => Icons.schedule,
};

AppTone _stopTone(String status) => switch (status) {
  'IN_PROGRESS' => AppTone.accent,
  'COMPLETED' => AppTone.success,
  'SKIPPED' => AppTone.warning,
  'CANCELLED' => AppTone.danger,
  _ => AppTone.neutral,
};
class _StopStatusBadge extends StatelessWidget {
  final String status;
  const _StopStatusBadge(this.status);
  @override
  Widget build(BuildContext context) => AppStatusLabel(stopStates[status] ?? '', tone: _stopTone(status), icon: _stopStatusIcon(status));
}

class JourneyScreen extends StatefulWidget {
  final JourneyApi api;
  final String activity;
  const JourneyScreen({super.key, required this.api, required this.activity});
  @override
  State<JourneyScreen> createState() => _JourneyState();
}

class _JourneyState extends State<JourneyScreen>
    with RealtimeBinding<JourneyScreen> {
  final read = ReliableRead<Json>();
  bool busy = false;
  @override
  String get realtimeScope => 'activity:${widget.activity}';
  @override
  String get realtimePrefix => 'ACTIVITY_STOP_';
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
  Future<void> reloadRealtime() =>
      read.load(() => widget.api.journey(widget.activity));
  Future<void> reorder(Json j, int from, int to) async {
    if (busy || read.failure != null) return;
    final old = (j['stops'] as List)
        .map((s) => object(s)['id'] as String)
        .toList();
    final order = [...old];

    order.insert(to, order.removeAt(from));
    setState(() => busy = true);
    try {
      final result = await widget.api.order(widget.activity, old, order);
      if (mounted) read.accept(result);
    } on ApiException catch (e) {
      if (mounted) {
        memoryNotice(context, e);
        await reloadRealtime();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> create(Json j) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            StopComposer(api: widget.api, activity: widget.activity),
      ),
    );
    if (mounted) await reloadRealtime();
  }

  @override
  void dispose() {
    read.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lịch trình')),
    body: JourneyRead(
      read: read,
      retry: reloadRealtime,
      builder: (j, current) {
        final stops = (j['stops'] as List).map(object).toList();
        final done = stops.where((s) => s['status'] == 'COMPLETED').length;
        final active = stops.where((s) => s['status'] == 'IN_PROGRESS').toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    j['title'] as String,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text('$done / ${stops.length} điểm đã hoàn thành'),
                  for (final stop in active)
                    Padding(padding: const EdgeInsets.only(top: 8), child: Text('Đang diễn ra: ${stop['title']}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700))),
                  const SizedBox(height: 8),
                  Text('Giờ trong lịch trình là dự kiến. Bạn có thể bắt đầu và check-in sớm.', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: stops.isEmpty ? 0 : done / stops.length,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  if (j['canManage'] == true)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: current && !busy ? () => create(j) : null,
                        icon: const Icon(Icons.add),
                        label: const Text('Thêm điểm dừng'),
                      ),
                    ),
                ],
              ),
            ),
            if (stops.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'Một hành trình bắt đầu từ điểm hẹn.\nThêm lịch trình để cả nhóm cùng theo dõi.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  buildDefaultDragHandles: false,
                  itemCount: stops.length,
                  onReorderItem: (from, to) => reorder(j, from, to),
                  itemBuilder: (context, index) {
                    final s = stops[index];
                    return Padding(
                      key: ValueKey(s['id']),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 65,
                            child: Column(
                              children: [
                                Text(
                                  localTime(s['startsAt']).split(' · ').last,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 6),
                                Icon(
                                  _stopStatusIcon(s['status'] as String),
                                  size: 18,
                                  color: toneColor(context, _stopTone(s['status'] as String)),
                                ),
                                if (index < stops.length - 1)
                                  Container(
                                    width: 1,
                                    height: 60,
                                    color: Theme.of(context).dividerColor,
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              title: Text(
                                s['title'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              tileColor: s['status'] == 'IN_PROGRESS' ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4) : null,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: s['status'] == 'IN_PROGRESS' ? BorderSide(color: Theme.of(context).colorScheme.primary) : BorderSide.none),
                              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                if ((s['locationLabel'] as String).isNotEmpty) Text(s['locationLabel'] as String),
                                const SizedBox(height: 6),
                                _StopStatusBadge(s['status'] as String),
                                const SizedBox(height: 4),
                                Text('${s['checkInCount']} check-in'),
                              ]),
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => StopDetailScreen(
                                      api: widget.api,
                                      activity: widget.activity,
                                      stop: s['id'] as String,
                                      group: j['groupId'] as String,
                                    ),
                                  ),
                                );
                                if (mounted) await reloadRealtime();
                              },
                            ),
                          ),
                          if (j['canManage'] == true && current && !busy)
                            ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.all(12),
                                child: Icon(Icons.drag_handle),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    ),
  );
}

class StopComposer extends StatefulWidget {
  final JourneyApi api;
  final String activity;
  final Json? initial;
  const StopComposer({
    super.key,
    required this.api,
    required this.activity,
    this.initial,
  });
  @override
  State<StopComposer> createState() => _StopComposerState();
}

class _StopComposerState extends State<StopComposer>
    with RealtimeBinding<StopComposer> {
  List<Json> people = [];
  String? organizer;
  bool denied = false;
  int memberGeneration = 0;
  @override
  String get realtimeScope => 'activity:${widget.activity}';
  @override
  String get realtimePrefix => 'ACTIVITY_';
  @override
  void onRealtimeAccessLost() {
    memberGeneration++;
    denied = true;
    title.clear();
    notes.clear();
    location.clear();
    cost.clear();
    people = [];
    if (mounted) setState(() {});
  }

  @override
  Future<void> reloadRealtime() => loadPeople();
  Future<void> loadPeople() async {
    final generation = ++memberGeneration;
    try {
      final journey = await widget.api.journey(widget.activity);
      if (journey['canManage'] != true) {
        onRealtimeAccessLost();
        return;
      }
      final members = await GroupApi(widget.api.dio)
          .getMembers(journey['groupId'] as String);
      if (mounted && !denied && generation == memberGeneration) {
        setState(
          () => people = members
              .map((m) => {'id': m.userId, 'name': m.displayName})
              .toList(),
        );
      }
    } on ApiException catch (e) {
      if (mounted && generation == memberGeneration) {
        if ([401, 403, 404].contains(e.statusCode)) {
          onRealtimeAccessLost();
        } else {
          memoryNotice(context, e);
        }
      }
    }
  }

  final title = TextEditingController(),
      notes = TextEditingController(),
      location = TextEditingController(),
      cost = TextEditingController();
  late final String command;
  DateTime starts = DateTime.now().add(const Duration(hours: 1));
  DateTime? ends;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    command = widget.initial?['id'] as String? ?? MomentsApi.commandId();
    organizer = widget.initial?['organizerId'] as String?;
    loadPeople();
    final j = widget.initial;
    if (j != null) {
      title.text = j['title'] as String;
      notes.text = j['notes'] as String;
      location.text = j['locationLabel'] as String;
      cost.text = j['estimatedCost']?.toString() ?? '';
      starts = DateTime.parse(j['startsAt'] as String).toLocal();
      ends = j['endsAt'] == null
          ? null
          : DateTime.parse(j['endsAt'] as String).toLocal();
    }
  }

  Future<void> save() async {
    if (busy || denied || title.text.trim().isEmpty) return;
    if (cost.text.trim().isNotEmpty &&
        (double.tryParse(cost.text.trim()) == null ||
            double.parse(cost.text.trim()) < 0)) {
      memoryNotice(
        context,
        const ApiException(message: 'Nhập chi phí dự kiến hợp lệ, không âm.'),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await widget.api.saveStop(widget.activity, {
        'clientRequestId': command,
        'title': title.text.trim(),
        'notes': notes.text.trim(),
        'startsAt': starts.toUtc().toIso8601String(),
        'endsAt': ends?.toUtc().toIso8601String(),
        'locationLabel': location.text.trim(),
        'organizerId': organizer,
        'estimatedCost': cost.text.trim().isEmpty
            ? null
            : double.tryParse(cost.text.trim()),
        'expectedUpdatedAt': widget.initial?['updatedAt'],
      }, id: widget.initial?['id'] as String?);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) memoryNotice(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    memberGeneration++;
    title.dispose();
    notes.dispose();
    location.dispose();
    cost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.initial == null ? 'Điểm dừng mới' : 'Sửa điểm dừng'),
    ),
    body: denied
        ? const Center(child: Text('Bạn không còn quyền sửa lịch trình này.'))
        : SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                TextField(
                  controller: title,
                  maxLength: 255,
                  decoration: const InputDecoration(labelText: 'Tên điểm dừng'),
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: const Text('Bắt đầu'),
                  subtitle: Text(localTime(starts.toIso8601String())),
                  onTap: busy
                      ? null
                      : () async {
                          final t = await journeyDateTime(context, starts);
                          if (t != null && mounted) setState(() => starts = t);
                        },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.timelapse),
                  title: const Text('Kết thúc (tùy chọn)'),
                  subtitle: Text(localTime(ends?.toIso8601String())),
                  onTap: busy
                      ? null
                      : () async {
                          final t = await journeyDateTime(
                            context,
                            ends ?? starts.add(const Duration(hours: 1)),
                          );
                          if (t != null && mounted) setState(() => ends = t);
                        },
                  trailing: ends == null
                      ? null
                      : IconButton(
                          onPressed: busy
                              ? null
                              : () => setState(() => ends = null),
                          icon: const Icon(Icons.close),
                        ),
                ),
                TextField(
                  controller: location,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    labelText: 'Điểm hẹn / địa điểm hiển thị',
                  ),
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: organizer,
                  decoration: const InputDecoration(
                    labelText: 'Người điều phối (tùy chọn)',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      child: Text('Chưa phân công'),
                    ),
                    if (organizer != null &&
                        !people.any((p) => p['id'] == organizer))
                      DropdownMenuItem(
                        value: organizer,
                        child: Text(
                          widget.initial?['organizerName'] as String? ??
                              'Người điều phối hiện tại',
                        ),
                      ),
                    for (final p in people)
                      DropdownMenuItem(
                        value: p['id'] as String,
                        child: Text(p['name'] as String),
                      ),
                  ],
                  onChanged: busy ? null : (v) => setState(() => organizer = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notes,
                  maxLength: 5000,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Ghi chú'),
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                ),
                TextField(
                  controller: cost,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Chi phí dự kiến (không ghi sổ tài chính)',
                  ),
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy ? null : save,
                  child: Text(busy ? 'Đang lưu…' : 'Lưu điểm dừng'),
                ),
              ],
            ),
          ),
  );
}

class StopDetailScreen extends StatefulWidget {
  final JourneyApi api;
  final String activity, stop, group;
  const StopDetailScreen({
    super.key,
    required this.api,
    required this.activity,
    required this.stop,
    required this.group,
  });
  @override
  State<StopDetailScreen> createState() => _StopDetailState();
}

class _StopDetailState extends State<StopDetailScreen>
    with RealtimeBinding<StopDetailScreen> {
  final read = ReliableRead<Json>();
  final scroll = ScrollController();
  bool newCheckins = false, busy = false;
  int pages = 1;
  @override
  String get realtimeScope => 'activity:${widget.activity}';
  @override
  String get realtimePrefix => 'ACTIVITY_STOP_';
  @override
  String get realtimeAggregateId => widget.stop;
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
  Future<void> reloadRealtime() async {
    final events = takeRealtimeEventTypes();
    if (events.isNotEmpty &&
        events.every((t) => t == 'ACTIVITY_STOP_CHECKIN_CREATED') &&
        read.value.hasData &&
        scroll.hasClients &&
        scroll.offset > 80) {
      if (mounted) setState(() => newCheckins = true);
      return;
    }
    await read.load(() async {
      final stop = await widget.api.stop(widget.activity, widget.stop);
      final items = <dynamic>[];
      String? next;
      for (int page = 0; page < pages; page++) {
        final data = await widget.api.checkIns(
          widget.activity,
          widget.stop,
          before: next,
        );
        items.addAll(data['items'] as List);
        next = data['nextBefore'] as String?;
        if (next == null) break;
      }
      final tasks = await widget.api.list(
        '${widget.api.root(widget.activity)}/stops/${widget.stop}/tasks',
      );
      final sources = await widget.api.list(
        '/api/v1/journey/targets/STOP/${widget.stop}/sources',
      );
      return {
        'stop': stop,
        'items': items,
        'nextBefore': next,
        'tasks': tasks,
        'sources': sources,
      };
    });
    if (mounted && read.failure == null) setState(() => newCheckins = false);
  }

  Future<void> act(Future<void> Function() command) async {
    if (busy || read.failure != null) return;
    setState(() => busy = true);
    try {
      await command();
      if (mounted) await reloadRealtime();
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
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Điểm dừng')),
    body: JourneyRead(
      read: read,
      retry: reloadRealtime,
      builder: (j, current) {
        final s = object(j['stop']);
        return ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Align(alignment: Alignment.centerLeft, child: _StopStatusBadge(s['status'] as String)),
            const SizedBox(height: 8),
            Text(
              s['title'] as String,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Dự kiến: ${localTime(s['startsAt'])}${s['endsAt'] == null ? '' : ' → ${localTime(s['endsAt'])}'}',
            ),
            if ((s['locationLabel'] as String).isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place_outlined),
                title: Text(s['locationLabel'] as String),
              ),
            if (s['estimatedCost'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Chi phí dự kiến: ${s['estimatedCost']}'),
              ),
            if (s['organizerName'] != null)
              Text('Điều phối: ${s['organizerName']}'),
            if ((s['notes'] as String).isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(s['notes'] as String),
              ),
            Wrap(
              spacing: 8,
              children: [
                if (s['canManage'] == true)
                  TextButton.icon(
                    onPressed: current && !busy
                        ? () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => StopComposer(
                                  api: widget.api,
                                  activity: widget.activity,
                                  initial: s,
                                ),
                              ),
                            );
                            if (mounted) await reloadRealtime();
                          }
                        : null,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Sửa lịch trình'),
                  ),
                if (s['canManage'] == true)
                  TextButton(
                    onPressed: current && !busy
                        ? () async {
                            if (await memoryConfirm(
                                  context,
                                  'Xóa điểm dừng khỏi lịch trình? Check-in đã lưu vẫn giữ trong Khoảnh khắc.',
                                ) &&
                                context.mounted) {
                              await act(() async {
                                await widget.api.deleteStop(widget.activity, s);
                                if (context.mounted) Navigator.pop(context);
                              });
                            }
                          }
                        : null,
                    child: const Text('Xóa điểm dừng'),
                  ),
              ],
            ),
            if (s['canChangeStatus'] == true)
              Wrap(
                spacing: 8,
                children: [
                  for (final state in [
                    'IN_PROGRESS',
                    'COMPLETED',
                    'SKIPPED',
                    'CANCELLED',
                  ])
                    if (state != s['status'])
                      ActionChip(
                        label: Text(const {'IN_PROGRESS': 'Bắt đầu điểm này', 'COMPLETED': 'Đánh dấu hoàn thành', 'SKIPPED': 'Bỏ qua điểm này', 'CANCELLED': 'Hủy điểm này'}[state]!),
                        onPressed: current && !busy
                            ? () => act(() async {
                                await widget.api.state(
                                  widget.activity,
                                  s,
                                  state,
                                );
                              })
                            : null,
                      ),
                ],
              ),
            const SizedBox(height: 16),
            Text(
              'Công việc liên quan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final raw in j['tasks'] as List)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.task_alt),
                title: Text(object(raw)['title'] as String),
                subtitle: Text(
                  '${{'TODO': 'Chưa thực hiện', 'IN_PROGRESS': 'Đang làm', 'DONE': 'Hoàn thành'}[object(raw)['status']] ?? ''} · ${(object(raw)['assigneeUserIds'] as List).length} người được giao',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TaskDetailScreen(
                      taskId: object(raw)['id'] as String,
                      repository: TaskRepository(TaskApi(widget.api.dio)),
                      loadMembers: () =>
                          GroupApi(widget.api.dio).getMembers(widget.group),
                    ),
                  ),
                ),
              ),
            for (final raw in j['sources'] as List)
              Text(
                'Từ bình chọn: ${object(raw)['sourceQuestion']} · ${object(raw)['sourceOption']}',
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: current && s['canCheckIn'] == true && !busy
                  ? () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => JourneyCapture(
                            api: widget.api,
                            group: widget.group,
                            activity: widget.activity,
                            stop: widget.stop,
                          ),
                        ),
                      );
                      if (mounted) await reloadRealtime();
                    }
                  : null,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Chụp check-in'),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Thời gian hiển thị là lúc weDO nhận ảnh; không xác minh vị trí hay việc đã đến.',
              ),
            ),
            Text(
              'Check-in của nhóm',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (newCheckins)
              TextButton(
                onPressed: () {
                  setState(() => newCheckins = false);
                  reloadRealtime();
                },
                child: const Text('Có check-in mới · Xem cập nhật'),
              ),
            if ((j['items'] as List).isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Chưa có check-in. Cùng lưu lại khoảnh khắc đầu tiên.',
                ),
              ),
            for (final raw in j['items'] as List)
              Builder(
                builder: (context) {
                  final check = object(raw),
                      moment = MomentPost.fromJson(object(check['moment']));
                  return Padding(
                    key: ValueKey(moment.id),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            UserAvatar(
                              displayName: moment.author.name,
                              avatarStorageKey: moment.author.avatar,
                              radius: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(moment.author.name)),
                            Text(
                              localTime(check['receivedAt']),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        if (moment.caption.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(moment.caption),
                          ),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: moment.media.length == 1 ? 1 : 2,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                          children: [
                            for (final media in moment.media)
                              InkWell(
                                onTap: () => openMemoryMedia(
                                  context,
                                  media,
                                  widget.api,
                                  widget.group,
                                  items: moment.media,
                                  aggregateId: moment.id,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: MemoryMediaView(
                                    key: ValueKey(media.id),
                                    media: media,
                                    api: widget.api,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            if (j['nextBefore'] != null)
              TextButton(
                onPressed: () {
                  pages++;
                  reloadRealtime();
                },
                child: const Text('Check-in trước đó'),
              ),
          ],
        );
      },
    ),
  );
}

class JourneyCapture extends StatefulWidget {
  final JourneyApi api;
  final String group;
  final String? activity, stop, task;
  final Future<XFile?> Function()? capture;
  const JourneyCapture({
    super.key,
    required this.api,
    required this.group,
    this.activity,
    this.stop,
    this.task,
    this.capture,
  });
  @override
  State<JourneyCapture> createState() => _JourneyCaptureState();
}

class _JourneyCaptureState extends State<JourneyCapture>
    with RealtimeBinding<JourneyCapture> {
  final caption = TextEditingController();
  final picker = ImagePicker();
  final files = <XFile>[];
  final uploaded = <String>[];
  final command = MomentsApi.commandId();
  CameraDevice camera = CameraDevice.rear;
  bool busy = false, committing = false, attempted = false, denied = false;
  double progress = 0;
  String source = 'CAMERA_CLIENT_DECLARED';
  DateTime? captured;
  @override
  String get realtimeScope => 'group:${widget.group}';
  @override
  String get realtimePrefix => 'GROUP_';
  @override
  Set<String> get realtimeAdditionalScopes => {
    if (widget.activity != null) 'activity:${widget.activity}',
  };
  @override
  Set<String> get realtimeAdditionalPrefixes => {'TASK_', 'ACTIVITY_STOP_'};
  @override
  String? get realtimeAggregateId => widget.task ?? widget.stop;
  @override
  void onRealtimeAccessLost() {
    denied = true;
    files.clear();
    uploaded.clear();
    if (mounted) setState(() {});
  }

  @override
  Future<void> reloadRealtime() async {
    try {
      if (widget.task != null) {
        final state = await widget.api.execution(widget.task!);
        if (state['canSubmit'] != true) onRealtimeAccessLost();
      } else {
        await widget.api.stop(widget.activity!, widget.stop!);
      }
    } on ApiException catch (e) {
      if ([401, 403, 404].contains(e.statusCode)) onRealtimeAccessLost();
    }
  }

  Future<void> pick({bool gallery = false}) async {
    if (busy ||
        attempted ||
        denied ||
        files.length >= 4 ||
        (files.isNotEmpty && source == 'GALLERY_UPLOAD' && !gallery)) {
      return;
    }
    try {
      final file = gallery
          ? await picker.pickImage(
              source: ImageSource.gallery,
              maxWidth: 2560,
              maxHeight: 2560,
              imageQuality: 90,
            )
          : widget.capture != null
          ? await widget.capture!()
          : await picker.pickImage(
              source: ImageSource.camera,
              preferredCameraDevice: camera,
              maxWidth: 2560,
              maxHeight: 2560,
              imageQuality: 90,
            );
      if (file == null || !mounted || denied) return;
      setState(() {
        files.add(file);
        source = gallery ? 'GALLERY_UPLOAD' : 'CAMERA_CLIENT_DECLARED';
        captured = DateTime.now();
      });
    } on PlatformException catch (_) {
      if (mounted) {
        memoryNotice(
          context,
          const ApiException(
            message: 'Không mở được camera/ảnh. Hãy cho phép quyền trong Cài đặt rồi thử lại.',
          ),
        );
      }
    }
  }

  Future<void> submit() async {
    if (busy || files.isEmpty || denied) return;
    setState(() => busy = true);
    try {
      for (int i = uploaded.length; i < files.length; i++) {
        final key = await widget.api.upload(
          widget.group,
          files[i],
          progress: (sent, total) {
            if (mounted && !denied) {
              setState(() => progress = total <= 0 ? 0 : sent / total);
            }
          },
        );
        if (!mounted || denied) return;
        uploaded.add(key);
      }
      if (!mounted || denied) return;
      setState(() {
        committing = true;
        attempted = true;
      });
      final body = {
        'clientRequestId': command,
        'caption': caption.text.trim(),
        'mediaKeys': uploaded,
      };
      if (widget.task != null) {
        await widget.api.evidence(widget.task!, {...body, 'source': source});
      } else {
        await widget.api.checkIn(widget.activity!, widget.stop!, {
          ...body,
          'clientCapturedAt': captured?.toUtc().toIso8601String(),
        });
      }
      if (mounted && !denied) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        if ([400, 409, 422].contains(e.statusCode)) {
          setState(() => attempted = false);
        }
        if ([401, 403, 404].contains(e.statusCode)) onRealtimeAccessLost();
        memoryNotice(context, e);
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          committing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !committing,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.task == null ? 'Chụp check-in' : 'Minh chứng công việc',
        ),
        actions: [
          IconButton(
            tooltip: 'Đổi camera trước / sau',
            onPressed: busy || attempted
                ? null
                : () => setState(
                    () => camera = camera == CameraDevice.rear
                        ? CameraDevice.front
                        : CameraDevice.rear,
                  ),
            icon: const Icon(Icons.flip_camera_ios_outlined),
          ),
        ],
      ),
      body: denied
          ? const Center(child: Text('Bạn không còn quyền gửi ảnh tại đây.'))
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  if (files.isEmpty)
                    AspectRatio(
                      aspectRatio: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Center(
                          child: Icon(Icons.camera_alt_outlined, size: 64),
                        ),
                      ),
                    ),
                  for (final file in files)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.file(
                          File(file.path),
                          cacheWidth: 800,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  Text(
                    source == 'GALLERY_UPLOAD'
                        ? 'Ảnh chọn từ thư viện, không phải xác minh check-in trực tiếp.'
                        : 'Ảnh chụp trong ứng dụng; không xác minh vị trí hay việc đã đến.',
                  ),
                  const SizedBox(height: 12),
                  if (!attempted)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed:
                              busy ||
                                  (files.isNotEmpty &&
                                      source == 'GALLERY_UPLOAD')
                              ? null
                              : () => pick(),
                          icon: const Icon(Icons.camera_alt),
                          label: Text(
                            files.isEmpty ? 'Mở camera' : 'Thêm ảnh camera',
                          ),
                        ),
                        if (widget.task != null && files.isEmpty)
                          TextButton(
                            onPressed: busy ? null : () => pick(gallery: true),
                            child: const Text('Chọn ảnh thư viện (đính kèm)'),
                          ),
                        if (files.isNotEmpty)
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => setState(() {
                                    files.clear();
                                    uploaded.clear();
                                  }),
                            child: const Text('Chụp lại'),
                          ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: caption,
                    maxLength: widget.task == null ? 5000 : 2000,
                    minLines: 1,
                    maxLines: 4,
                    enabled: !busy && !attempted,
                    decoration: const InputDecoration(
                      labelText: 'Lời nhắn (tùy chọn)',
                    ),
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                  ),
                  if (busy)
                    LinearProgressIndicator(
                      value: committing ? null : progress,
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy || files.isEmpty ? null : submit,
                    child: Text(
                      busy
                          ? 'Đang gửi…'
                          : attempted
                          ? 'Thử gửi lại an toàn'
                          : 'Gửi xác nhận',
                    ),
                  ),
                  if (attempted)
                    const Text(
                      'Giữ nguyên ảnh và mã gửi khi thử lại để tránh tạo trùng.',
                    ),
                ],
              ),
            ),
    ),
  );
}

class TaskEvidenceScreen extends StatefulWidget {
  final JourneyApi api;
  final String task;
  const TaskEvidenceScreen({super.key, required this.api, required this.task});
  @override
  State<TaskEvidenceScreen> createState() => _TaskEvidenceState();
}

class _TaskEvidenceState extends State<TaskEvidenceScreen>
    with RealtimeBinding<TaskEvidenceScreen> {
  final read = ReliableRead<Json>();
  final feedback = TextEditingController();
  bool busy = false;
  int pages = 1;
  @override
  String? get realtimeScope => null;
  @override
  String get realtimePrefix => 'TASK_';
  @override
  String get realtimeAggregateId => widget.task;
  @override
  bool get realtimeReadNeedsRecovery => read.failure?.retainData == true;
  @override
  void onRealtimeAccessLost() {
    read.denyAccess();
    feedback.clear();
  }

  @override
  void initState() {
    super.initState();
    reloadRealtime();
  }

  @override
  Future<void> reloadRealtime() => read.load(() async {
    final first = await widget.api.execution(widget.task);
    final t = object(first['task']);
    final activity = t['activityId'] as String;
    final journey = await widget.api.journey(activity);
    final rows = [...first['evidence'] as List];
    String? next = first['nextBefore'] as String?;
    for (int page = 1; page < pages && next != null; page++) {
      final data = await widget.api.execution(widget.task, before: next);
      rows.addAll(data['evidence'] as List);
      next = data['nextBefore'] as String?;
    }
    if (mounted) bindRealtimeResource('activity:$activity');
    return {...first, 'evidence': rows, 'nextBefore': next, 'journey': journey};
  });
  Future<void> act(Future<void> Function() action) async {
    if (busy || read.failure != null) return;
    setState(() => busy = true);
    try {
      await action();
      if (mounted) await reloadRealtime();
    } on ApiException catch (e) {
      if (mounted) {
        if ([401, 403, 404].contains(e.statusCode)) onRealtimeAccessLost();
        memoryNotice(context, e);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  final reviewCommands = <String, String>{};
  Future<void> review(Json e, bool approve) async {
    if (!approve && feedback.text.trim().isEmpty) {
      memoryNotice(
        context,
        const ApiException(message: 'Nhập lý do cần chụp lại.'),
      );
      return;
    }
    final key = '${e['id']}:$approve:${feedback.text.trim()}';
    final id = reviewCommands.putIfAbsent(key, MomentsApi.commandId);
    await act(() async {
      await widget.api.review(widget.task, e['id'] as String, {
        'clientRequestId': id,
        'approve': approve,
        'reason': feedback.text.trim(),
      });
    });
  }

  @override
  void dispose() {
    read.dispose();
    feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Minh chứng & hoàn thành')),
    body: JourneyRead(
      read: read,
      retry: reloadRealtime,
      builder: (j, current) {
        final task = object(j['task']), journey = object(j['journey']);
        final mediaApi = EvidenceMediaApi(widget.api.dio, widget.task);
        return ListView(
          padding: const EdgeInsets.all(20),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Text(
              task['title'] as String,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              {
                    'TODO': 'Chưa thực hiện',
                    'IN_PROGRESS': 'Đang làm',
                    'DONE': 'Hoàn thành',
                  }[task['status']] ??
                  '',
            ),
            const SizedBox(height: 16),
            if (j['canConfigure'] != true)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(evidenceModes[j['mode']] ?? ''),
              ),
            if (j['canConfigure'] == true) ...[
              DropdownButtonFormField<String>(
                isExpanded: true,
                key: ValueKey('mode:${j['mode']}'),
                initialValue: j['mode'] as String,
                decoration: const InputDecoration(
                  labelText: 'Cách xác nhận hoàn thành',
                ),
                items: [
                  for (final entry in evidenceModes.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: current && !busy
                    ? (v) => act(() async {
                        await widget.api.configure(
                          widget.task,
                          v!,
                          j['stopId'] as String?,
                        );
                      })
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                key: ValueKey('stop:${j['stopId']}'),
                initialValue: j['stopId'] as String?,
                decoration: const InputDecoration(
                  labelText: 'Điểm dừng liên quan',
                ),
                items: [
                  const DropdownMenuItem<String>(child: Text('Toàn hoạt động')),
                  if (j['stopId'] != null &&
                      !(journey['stops'] as List).any(
                        (s) => object(s)['id'] == j['stopId'],
                      ))
                    DropdownMenuItem(
                      value: j['stopId'] as String,
                      enabled: false,
                      child: const Text('Điểm dừng đã xóa (liên kết lịch sử)'),
                    ),
                  for (final raw in journey['stops'] as List)
                    DropdownMenuItem(
                      value: object(raw)['id'] as String,
                      child: Text(object(raw)['title'] as String),
                    ),
                ],
                onChanged: current && !busy
                    ? (v) => act(() async {
                        await widget.api.configure(
                          widget.task,
                          j['mode'] as String,
                          v,
                        );
                      })
                    : null,
              ),
            ],
            if (j['mode'] == 'NONE')
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Công việc này giữ cách hoàn thành hiện có; chưa yêu cầu ảnh.',
                ),
              ),
            if (j['canSubmit'] == true)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: FilledButton.icon(
                  onPressed: current && !busy
                      ? () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => JourneyCapture(
                                api: widget.api,
                                group: journey['groupId'] as String,
                                activity: task['activityId'] as String,
                                task: widget.task,
                              ),
                            ),
                          );
                          if (mounted) await reloadRealtime();
                        }
                      : null,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Chụp minh chứng'),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Lịch sử minh chứng',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if ((j['evidence'] as List).isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Chưa có minh chứng. Ảnh gửi ở đây được giữ riêng trong công việc.',
                ),
              ),
            for (final raw in j['evidence'] as List)
              Builder(
                builder: (context) {
                  final e = object(raw);
                  final author = MemoryAuthor.fromJson(object(e['author']));
                  final media = (e['media'] as List)
                      .map((m) => MemoryMedia.fromJson(object(m)))
                      .toList();
                  return Padding(
                    key: ValueKey(e['id']),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: UserAvatar(
                            displayName: author.name,
                            avatarStorageKey: author.avatar,
                            radius: 18,
                          ),
                          title: Text(author.name),
                          subtitle: Text(
                            '${localTime(e['receivedAt'])} · ${e['source'] == 'GALLERY_UPLOAD' ? 'Ảnh thư viện' : 'Ảnh chụp trong ứng dụng'}',
                          ),
                        ),
                        Text(
                          evidenceStates[e['status']] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (e['current'] == false && e['status'] == 'PENDING')
                          const Text(
                            'Công việc đã thay đổi. Cần minh chứng mới trước khi duyệt.',
                          ),
                        if ((e['caption'] as String).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(e['caption'] as String),
                          ),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: media.length == 1 ? 1 : 2,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                          children: [
                            for (final m in media)
                              InkWell(
                                onTap: () => openMemoryMedia(
                                  context,
                                  m,
                                  mediaApi,
                                  journey['groupId'] as String,
                                  items: media,
                                  scope: 'activity:${task['activityId']}',
                                  prefix: 'TASK_',
                                  aggregateId: widget.task,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: MemoryMediaView(
                                    key: ValueKey(m.id),
                                    media: m,
                                    api: mediaApi,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (e['feedback'] != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              '${e['reviewerName'] ?? 'Người duyệt'}: ${e['feedback']}',
                            ),
                          ),
                        if (e['canReview'] == true) ...[
                          TextField(
                            controller: feedback,
                            maxLength: 1000,
                            onTapOutside: (_) =>
                                FocusManager.instance.primaryFocus?.unfocus(),
                            decoration: const InputDecoration(
                              labelText: 'Nhận xét / lý do cần chụp lại',
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              FilledButton(
                                onPressed:
                                    current && !busy && e['current'] == true
                                    ? () => review(e, true)
                                    : null,
                                child: const Text('Duyệt hoàn thành'),
                              ),
                              TextButton(
                                onPressed: current && !busy
                                    ? () => review(e, false)
                                    : null,
                                child: const Text('Yêu cầu chụp lại'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            if (j['nextBefore'] != null)
              TextButton(
                onPressed: () {
                  pages++;
                  reloadRealtime();
                },
                child: const Text('Minh chứng trước đó'),
              ),
          ],
        );
      },
    ),
  );
}

/// Compact overview data stays in one stable parent slot beside RSVP/Discussion.
class JourneyOverview extends StatefulWidget {
  final JourneyApi api;
  final String activity;
  final VoidCallback onOpen;
  const JourneyOverview({
    super.key,
    required this.api,
    required this.activity,
    required this.onOpen,
  });
  @override
  State<JourneyOverview> createState() => _JourneyOverviewState();
}

class _JourneyOverviewState extends State<JourneyOverview>
    with RealtimeBinding<JourneyOverview> {
  final read = ReliableRead<Json>();
  @override
  String get realtimeScope => 'activity:${widget.activity}';
  @override
  String get realtimePrefix => 'ACTIVITY_STOP_';
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
  Future<void> reloadRealtime() =>
      read.load(() => widget.api.journey(widget.activity));
  @override
  void dispose() {
    read.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: read,
    builder: (context, s, _) {
      if (!s.hasData) {
        return read.failure?.accessDenied == true
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: read.failure == null
                    ? const LinearProgressIndicator()
                    : TextButton(
                        onPressed: reloadRealtime,
                        child: const Text('Tải lại lịch trình'),
                      ),
              );
      }
      final stops = (s.requireData['stops'] as List).map(object).toList();
      final completed = stops.where((s) => s['status'] == 'COMPLETED').length;
      final active = stops.where((s) => s['status'] == 'IN_PROGRESS').toList();
      final upcoming = stops.where((s) => s['status'] == 'PLANNED').toList();
      final next = active.isNotEmpty
          ? active.first
          : upcoming.isNotEmpty
          ? upcoming.first
          : null;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.route_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Hành trình của nhóm',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text('$completed/${stops.length}'),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: stops.isEmpty ? 0 : completed / stops.length,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 10),
                Text(
                  next == null
                      ? (stops.isEmpty
                            ? 'Thêm các điểm hẹn cho hoạt động.'
                            : 'Không còn điểm dừng đang chờ.')
                      : active.isNotEmpty
                      ? 'Đang diễn ra: ${active.map((s) => s['title']).join(', ')}'
                      : 'Tiếp theo: ${next['title']} · ${localTime(next['startsAt'])}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (read.failure != null)
                  const Text('Đang hiển thị lịch trình đã tải.'),
              ],
            ),
          ),
        ),
      );
    },
  );
}
