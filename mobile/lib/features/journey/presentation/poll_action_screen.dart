import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/realtime/realtime_binding.dart';
import '../../../core/realtime/reliable_read.dart';
import '../../moments/data/moment_models.dart';
import '../../moments/data/moments_api.dart';
import '../../moments/presentation/memories_screen.dart' show memoryNotice;
import '../../poll/data/poll_api.dart';
import '../../poll/data/poll_repository.dart';
import '../../activity/data/activity_api.dart';
import '../../community/data/recruitment_api.dart';
import '../../task/data/task_api.dart';
import '../../task/data/task_repository.dart';
import '../../task/presentation/screens/task_screens.dart';
import '../data/journey_api.dart';
import 'journey_screens.dart';

class PollActionScreen extends StatefulWidget {
  final JourneyApi api;
  final String poll;
  const PollActionScreen({super.key, required this.api, required this.poll});
  @override
  State<PollActionScreen> createState() => _PollActionState();
}

class _PollActionState extends State<PollActionScreen>
    with RealtimeBinding<PollActionScreen> {
  final read = ReliableRead<Json>();
  final notes = TextEditingController(), location = TextEditingController();
  final taskTitle = TextEditingController();
  final stopTitle = TextEditingController();
  bool titleInitialized = false;
  String? activity, option, group;
  String target = 'TASK';
  DateTime starts = DateTime.now().add(const Duration(hours: 1));
  DateTime? due, ends;
  bool busy = false, attempted = false;
  final commands = <String, String>{};
  final selected = <String>{};
  int choiceGeneration = 0;
  @override
  String? get realtimeScope => group == null ? null : 'group:$group';
  @override
  Set<String> get realtimeAdditionalScopes => {
    if (activity != null) 'activity:$activity',
  };
  @override
  String get realtimePrefix => 'POLL_';
  @override
  String get realtimeAggregateId => widget.poll;
  @override
  bool get realtimeReadNeedsRecovery => read.failure?.retainData == true;
  @override
  void onRealtimeAccessLost() {
    choiceGeneration++;
    read.denyAccess();
    selected.clear();
  }

  @override
  void initState() {
    super.initState();
    reloadRealtime();
  }

  @override
  Future<void> reloadRealtime() => read.load(() async {
    final p = await PollRepository(PollApi(widget.api.dio)).get(widget.poll);
    if (mounted && !titleInitialized) {
      taskTitle.text = p.question;
      titleInitialized = true;
    }
    final context = await widget.api.pollActions(widget.poll);
    final choices = p.activityId == null
        ? await RecruitmentApi(widget.api.dio)
              .activities(context['groupId'] as String)
        : [(p.activityId!, p.question)];
    activity ??= p.activityId;
    final selectedActivity = activity;
    Json? journey;
    List<Json> assignees = [];
    if (selectedActivity != null) {
      journey = await widget.api.journey(selectedActivity);
      assignees =
          (await TaskRepository(TaskApi(widget.api.dio))
                  .eligibleAssignees(selectedActivity))
              .map((m) => {'id': m.userId, 'name': m.displayName})
              .toList();
    }
    if (mounted) {
      group = context['groupId'] as String;
      bindRealtimeResource('group:$group');
    }
    return {
      ...context,
      'question': p.question,
      'resultsVisible': p.resultsVisible,
      'participantCount': p.participantCount,
      'options': [
        for (final o in p.options)
          if (!o.disabled) {'id': o.id, 'text': o.text},
      ],
      'activities': [
        for (final a in choices)
          {
            'id': a.$1,
            'name': p.activityId != null && journey != null
                ? journey['title']
                : a.$2,
          },
      ],
      'journey': journey,
      'assignees': assignees,
    };
  });
  Future<void> chooseActivity(String? id) async {
    if (busy || attempted) return;
    final generation = ++choiceGeneration;
    setState(() {
      activity = id;
      selected.clear();
      target = 'TASK';
    });
    read.reset();
    await reloadRealtime();
    if (!mounted || generation != choiceGeneration || id != activity) return;
    try {
      final a = await ActivityApi(widget.api.dio).detail(id!);
      if (mounted &&
          generation == choiceGeneration &&
          activity == id &&
          a.startAt != null) {
        setState(() => starts = a.startAt!.toLocal());
      }
    } on ApiException catch (e) {
      if (mounted) memoryNotice(context, e);
    }
  }

  Future<void> convert(Json j) async {
    if (busy || activity == null || option == null) return;
    final command = commands.putIfAbsent(
      '$activity:$option:$target',
      MomentsApi.commandId,
    );
    setState(() {
      busy = true;
      attempted = true;
    });
    try {
      final link = await widget.api.convert(widget.poll, {
        'clientRequestId': command,
        'optionId': option,
        'activityId': activity,
        'target': target,
        'taskTitle': target == 'TASK' ? taskTitle.text.trim() : null,
        'stopTitle': target == 'STOP' ? stopTitle.text.trim() : null,
        'notes': notes.text.trim(),
        'startsAt': target == 'STOP' ? starts.toUtc().toIso8601String() : null,
        'endsAt': target == 'STOP' ? ends?.toUtc().toIso8601String() : null,
        'locationLabel': location.text.trim(),
        'dueAt': target == 'TASK' ? due?.toUtc().toIso8601String() : null,
        'assigneeUserIds': selected.toList(),
      });
      if (mounted) {
        setState(() => attempted = false);
        final view = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: Icon(Icons.check_circle_outline,
                color: Theme.of(dialogContext).colorScheme.primary),
            title: const Text('Đã tạo thành công'),
            content: Text(link['target'] == 'STOP'
                ? 'Đã tạo điểm dừng từ bình chọn.'
                : 'Đã tạo công việc từ bình chọn.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Đóng')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Xem')),
            ],
          ),
        );
        if (!mounted) return;
        await reloadRealtime();
        if (view == true && mounted) await open(link, j, taskList: true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        if ([400, 409, 422].contains(e.statusCode)) {
          setState(() => attempted = false);
        }
        if ([401, 403, 404].contains(e.statusCode)) onRealtimeAccessLost();
        memoryNotice(context, e);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open(Json link, Json j, {bool taskList = false}) async {
    final id = link['target'] == 'TASK' ? link['taskId'] : link['stopId'];
    if (id == null) return;
    if (link['target'] == 'TASK') {
      final repo = TaskRepository(TaskApi(widget.api.dio));
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => taskList
              ? TaskListScreen(activityId: link['activityId'] as String,
                  repository: repo,
                  loadMembers: () => repo.eligibleAssignees(link['activityId'] as String))
              : TaskDetailScreen(
                  taskId: id as String,
                  repository: repo,
                  loadMembers: () => repo.eligibleAssignees(link['activityId'] as String),
                ),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StopDetailScreen(
            api: widget.api,
            activity: link['activityId'] as String,
            stop: id as String,
            group: j['groupId'] as String,
          ),
        ),
      );
    }
    if (mounted) await reloadRealtime();
  }

  @override
  void dispose() {
    choiceGeneration++;
    read.dispose();
    notes.dispose();
    taskTitle.dispose();
    stopTitle.dispose();
    location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Từ bình chọn đến hành động')),
    body: JourneyRead(
      read: read,
      retry: reloadRealtime,
      builder: (j, current) {
        final journey = j['journey'] == null ? null : object(j['journey']);
        final canStop = journey?['canManage'] == true;
        return ListView(
          padding: const EdgeInsets.all(20),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Text(
              j['question'] as String,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Bạn chọn phương án để thực hiện. weDO không tự tạo việc từ phương án nhiều phiếu nhất.',
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: option,
              decoration: const InputDecoration(
                labelText: 'Phương án muốn chuyển',
              ),
              items: [
                for (final raw in j['options'] as List)
                  DropdownMenuItem(
                    value: object(raw)['id'] as String,
                    child: Text(object(raw)['text'] as String),
                  ),
              ],
              onChanged: busy || attempted
                  ? null
                  : (v) => setState(() {
                      option = v;
                      stopTitle.text = (j['options'] as List).map(object).firstWhere((o) => o['id'] == v)['text'] as String;
                    }),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              key: ValueKey(activity),
              initialValue: activity,
              decoration: const InputDecoration(
                labelText: 'Hoạt động đích (cùng nhóm)',
              ),
              items: [
                for (final raw in j['activities'] as List)
                  DropdownMenuItem(
                    value: object(raw)['id'] as String,
                    child: Text(object(raw)['name'] as String),
                  ),
              ],
              onChanged: busy || attempted ? null : chooseActivity,
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: [
                const ButtonSegment(
                  value: 'TASK',
                  label: Text('Công việc'),
                  icon: Icon(Icons.task_alt),
                ),
                ButtonSegment(
                  value: 'STOP',
                  label: const Text('Điểm dừng'),
                  icon: const Icon(Icons.route_outlined),
                  enabled: canStop,
                ),
              ],
              selected: {target},
              onSelectionChanged: busy || attempted
                  ? null
                  : (v) => setState(() => target = v.first),
            ),
            const SizedBox(height: 16),
            if (target == 'TASK') ...[
              TextField(
                controller: taskTitle,
                maxLength: 255,
                enabled: !busy && !attempted,
                decoration: const InputDecoration(labelText: 'Tên công việc', helperText: 'Tên việc lấy từ câu hỏi; phương án đã chọn được giữ trong mô tả.'),
                onChanged: (_) => setState(() {}),
                onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              ),
              const SizedBox(height: 12),
            ],
            if (target == 'STOP') ...[
              TextField(
                controller: stopTitle,
                maxLength: 255,
                enabled: !busy && !attempted,
                decoration: const InputDecoration(labelText: 'Tên điểm dừng', helperText: 'Phương án đã chọn được giữ trong mô tả và nguồn.'),
                onChanged: (_) => setState(() {}),
                onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Bắt đầu'),
                subtitle: Text(localTime(starts.toIso8601String())),
                onTap: busy || attempted
                    ? null
                    : () async {
                        final value = await journeyDateTime(context, starts);
                        if (value != null && mounted) {
                          setState(() => starts = value);
                        }
                      },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Kết thúc (tùy chọn)'),
                subtitle: Text(localTime(ends?.toIso8601String())),
                onTap: busy || attempted
                    ? null
                    : () async {
                        final value = await journeyDateTime(
                          context,
                          ends ?? starts.add(const Duration(hours: 1)),
                        );
                        if (value != null && mounted) {
                          setState(() => ends = value);
                        }
                      },
              ),
              TextField(
                controller: location,
                maxLength: 160,
                enabled: !busy && !attempted,
                decoration: const InputDecoration(
                  labelText: 'Điểm hẹn / địa điểm',
                ),
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
              ),
            ] else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hạn công việc (tùy chọn)'),
                subtitle: Text(localTime(due?.toIso8601String())),
                onTap: busy || attempted
                    ? null
                    : () async {
                        final value = await journeyDateTime(
                          context,
                          due ?? starts,
                        );
                        if (value != null && mounted) {
                          setState(() => due = value);
                        }
                      },
              ),
              for (final raw in j['assignees'] as List)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(object(raw)['name'] as String),
                  subtitle: const Text('Đã RSVP Tham gia'),
                  value: selected.contains(object(raw)['id']),
                  onChanged: busy || attempted
                      ? null
                      : (v) => setState(() {
                          final id = object(raw)['id'] as String;
                          if (v == true) {
                            selected.add(id);
                          } else {
                            selected.remove(id);
                          }
                        }),
                ),
            ],
            TextField(
              controller: notes,
              maxLength: 5000,
              maxLines: 3,
              enabled: !busy && !attempted,
              decoration: const InputDecoration(
                labelText: 'Ghi chú / mô tả bổ sung',
              ),
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
            ),
            const SizedBox(height: 16),
            if (j['resultsVisible'] != true ||
                (j['participantCount'] as num) == 0)
              const Text(
                'Chuyển đổi khả dụng sau khi có phiếu và kết quả được phép hiển thị.',
              ),
            FilledButton(
              onPressed:
                  current &&
                      !busy &&
                      activity != null &&
                      option != null &&
                      (target == 'TASK' ? taskTitle.text.trim().isNotEmpty : stopTitle.text.trim().isNotEmpty) &&
                      j['resultsVisible'] == true &&
                      (j['participantCount'] as num) > 0
                  ? () => convert(j)
                  : null,
              child: Text(
                busy
                    ? 'Đang tạo…'
                    : attempted
                    ? 'Thử xác nhận lại an toàn'
                    : 'Xác nhận tạo',
              ),
            ),
            if (attempted)
              const Text(
                'Giữ nguyên yêu cầu khi thử lại để tránh trùng mục đã tạo.',
              ),
            const SizedBox(height: 24),
            Text(
              'Đã chuyển thành kế hoạch',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final raw in j['links'] as List)
              Builder(
                builder: (context) {
                  final link = object(raw);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      link['target'] == 'TASK'
                          ? Icons.task_alt
                          : Icons.route_outlined,
                    ),
                    title: Text(link['sourceOption'] as String),
                    subtitle: Text(
                      link['target'] == 'TASK'
                          ? 'Đã tạo công việc'
                          : 'Đã thêm vào lịch trình',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => open(link, j),
                  );
                },
              ),
          ],
        );
      },
    ),
  );
}
