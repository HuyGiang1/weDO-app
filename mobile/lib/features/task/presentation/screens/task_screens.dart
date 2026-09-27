// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../groups/data/models/group_models.dart';
import '../../data/task_models.dart';
import '../../data/task_failure.dart';
import '../../data/task_repository.dart';
import '../task_deadline.dart';

typedef GroupMembersLoader = Future<List<GroupMember>> Function();

class TaskListScreen extends StatefulWidget {
  final String activityId;
  final TaskRepository repository;
  final GroupMembersLoader loadMembers;
  const TaskListScreen({
    super.key,
    required this.activityId,
    required this.repository,
    required this.loadMembers,
  });

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  late Future<List<ActivityTask>> _future;
  ActivityTaskStatus? _filter;
  bool _mine = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() {
    _future = widget.repository.list(
      widget.activityId,
      status: _filter,
      assignedToMe: _mine ? true : null,
    );
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Công việc'),
      centerTitle: true,
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
    ),
    floatingActionButton: FloatingActionButton(
      tooltip: 'Tạo công việc',
      onPressed: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CreateTaskScreen(
              activityId: widget.activityId,
              repository: widget.repository,
              loadMembers: widget.loadMembers,
            ),
          ),
        );
        _load();
      },
      child: const Icon(Icons.add_task),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Tìm công việc',
            ),
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Của tôi'),
                selected: _mine,
                onSelected: (value) {
                  setState(() => _mine = value);
                  _load();
                },
              ),
              const SizedBox(width: 8),
              ...ActivityTaskStatus.values.map(
                (status) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_taskStatusText(status)),
                    selected: _filter == status,
                    onSelected: (_) {
                      setState(
                        () => _filter = _filter == status ? null : status,
                      );
                      _load();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<List<ActivityTask>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return _Failure(onRetry: _load);
              final tasks = (snapshot.data ?? [])
                  .where((task) => task.title.toLowerCase().contains(_query))
                  .toList();
              if (tasks.isEmpty)
                return const _Empty(
                  icon: Icons.task_alt,
                  text: 'Chưa có công việc phù hợp.',
                );
              return RefreshIndicator(
                onRefresh: () async => _load(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                  itemCount: tasks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, index) => _TaskCard(
                    task: tasks[index],
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TaskDetailScreen(
                            taskId: tasks[index].id,
                            repository: widget.repository,
                            loadMembers: widget.loadMembers,
                          ),
                        ),
                      );
                      _load();
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class CreateTaskScreen extends StatefulWidget {
  final String activityId;
  final TaskRepository repository;
  final GroupMembersLoader loadMembers;
  const CreateTaskScreen({
    super.key,
    required this.activityId,
    required this.repository,
    required this.loadMembers,
  });
  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  List<GroupMember> _members = const [];
  final Set<String> _assignees = {};
  DateTime? _dueAt;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    widget.loadMembers().then((value) {
      if (mounted) setState(() => _members = value);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      _message('Nhập tiêu đề công việc.');
      return;
    }
    if (_dueAt != null && !isFutureTaskDueAt(_dueAt!)) {
      _message('Hạn hoàn thành phải sau thời điểm hiện tại.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repository.create(
        widget.activityId,
        ActivityTaskDraft(
          title: _title.text.trim(),
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          assigneeUserIds: _assignees.toList(),
          dueAt: _dueAt,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      _message(createTaskFailureMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(centerTitle: true, title: const Text('Tạo công việc')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Tiêu đề'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _description,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Mô tả (không bắt buộc)',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          child: ListTile(
            leading: const Icon(Icons.people_outline, color: AppColors.primary),
            title: const Text('Phân công'),
            subtitle: Text(
              _assignees.isEmpty
                  ? 'Chưa phân công'
                  : '${_assignees.length} thành viên',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final selected = await _selectMembers(
                context,
                _members,
                _assignees,
              );
              if (selected != null)
                setState(() {
                  _assignees
                    ..clear()
                    ..addAll(selected);
                });
            },
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: ListTile(
            leading: const Icon(Icons.event_outlined, color: AppColors.primary),
            title: const Text('Hạn hoàn thành'),
            subtitle: Text(
              _dueAt == null ? 'Không đặt hạn' : _dateText(_dueAt!),
            ),
            trailing: _dueAt == null
                ? const Icon(Icons.chevron_right)
                : IconButton(
                    tooltip: 'Xóa hạn',
                    onPressed: () => setState(() => _dueAt = null),
                    icon: const Icon(Icons.close),
                  ),
            onTap: () async {
              final now = DateTime.now();
              final initial = _dueAt ?? now.add(const Duration(hours: 1));
              final day = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(now.year, now.month, now.day),
                lastDate: now.add(const Duration(days: 3650)),
              );
              if (!context.mounted || day == null) return;
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(initial),
              );
              if (!context.mounted || time == null) return;
              setState(() {
                _dueAt = combineTaskDueAt(
                  day,
                  Duration(hours: time.hour, minutes: time.minute),
                );
              });
            },
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Đang tạo...' : 'Tạo công việc'),
        ),
      ],
    ),
  );
}

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  final TaskRepository repository;
  final GroupMembersLoader loadMembers;
  const TaskDetailScreen({
    super.key,
    required this.taskId,
    required this.repository,
    required this.loadMembers,
  });
  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Future<ActivityTask> _future;
  List<GroupMember> _members = const [];
  @override
  void initState() {
    super.initState();
    _reload();
    widget.loadMembers().then((value) {
      if (mounted) setState(() => _members = value);
    });
  }

  void _reload() => setState(() {
    _future = widget.repository.get(widget.taskId);
  });
  Future<void> _status(ActivityTask task) async {
    final status = await showModalBottomSheet<ActivityTaskStatus>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.onSurfaceVariant.withValues(alpha: .25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Cập nhật trạng thái',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              ...ActivityTaskStatus.values.map(
                (value) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  selected: value == task.status,
                  selectedTileColor: AppColors.primary.withValues(alpha: .10),
                  leading: Icon(
                    _statusIcon(value),
                    color: value == task.status
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                  ),
                  title: Text(
                    _taskStatusText(value),
                    style: TextStyle(
                      color: value == task.status ? AppColors.primary : null,
                      fontWeight: value == task.status
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  trailing: value == task.status
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.pop(context, value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (status == null || status == task.status) return;
    try {
      await widget.repository.updateStatus(task.id, status);
      _reload();
    } catch (_) {
      _message('Không thể cập nhật trạng thái.');
    }
  }

  Future<void> _edit(ActivityTask task) async {
    final chosen = await _selectMembers(
      context,
      _members,
      task.assigneeUserIds.toSet(),
    );
    if (chosen == null) return;
    try {
      await widget.repository.update(
        task.id,
        ActivityTaskDraft(
          title: task.title,
          description: task.description,
          assigneeUserIds: chosen.toList(),
          dueAt: task.dueAt,
        ),
      );
      _reload();
    } catch (_) {
      _message('Không thể cập nhật người được giao.');
    }
  }

  Future<void> _delete(ActivityTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa công việc'),
        content: const Text('Bạn có chắc muốn xóa công việc này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await widget.repository.delete(task.id);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      _message('Không thể xóa công việc.');
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Chi tiết công việc'),
      centerTitle: true,
      actions: [
        IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
      ],
    ),
    body: FutureBuilder<ActivityTask>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError || !snapshot.hasData)
          return _Failure(onRetry: _reload);
        final task = snapshot.data!;
        final assignees = _members
            .where((member) => task.assigneeUserIds.contains(member.userId))
            .toList();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              task.title,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            const Text(
              'Trạng thái',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _TaskStatusSection(
              status: task.status,
              onTap: task.permissions.canChangeStatus
                  ? () => _status(task)
                  : null,
            ),
            const SizedBox(height: 20),
            if (task.description != null) ...[
              Text(task.description!, style: const TextStyle(height: 1.5)),
            ],
            const SizedBox(height: 20),
            _Panel(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.people_outline,
                      color: AppColors.primary,
                    ),
                    title: const Text('Người được giao'),
                    subtitle: Text(
                      assignees.isEmpty
                          ? 'Chưa phân công'
                          : assignees
                                .map((member) => member.displayName)
                                .join(', '),
                    ),
                    trailing: task.permissions.canManageAssignees
                        ? const Icon(Icons.edit_outlined)
                        : null,
                    onTap: task.permissions.canManageAssignees
                        ? () => _edit(task)
                        : null,
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.event_outlined,
                      color: AppColors.primary,
                    ),
                    title: const Text('Hạn hoàn thành'),
                    subtitle: Text(
                      task.dueAt == null
                          ? 'Không đặt hạn'
                          : _dateText(task.dueAt!),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (task.permissions.canClaim) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () async {
                  try {
                    await widget.repository.claim(task.id);
                    _reload();
                  } catch (_) {
                    _message('Không thể nhận công việc này.');
                  }
                },
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Nhận công việc'),
              ),
            ],
            if (task.permissions.canDelete) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => _delete(task),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text(
                  'Xóa công việc',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
            if (task.statusHistory.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Lịch sử trạng thái',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              ...task.statusHistory.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history, size: 20),
                  title: Text(
                    '${item.fromStatus == null ? 'Đã tạo' : _taskStatusText(item.fromStatus!)} → ${_taskStatusText(item.toStatus)}',
                  ),
                  subtitle: Text(_dateText(item.createdAt)),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}

Future<Set<String>?> _selectMembers(
  BuildContext context,
  List<GroupMember> members,
  Set<String> initial,
) async {
  final selected = {...initial};
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .72,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Chọn thành viên',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              Expanded(
                child: members.isEmpty
                    ? const _Empty(
                        icon: Icons.people_outline,
                        text: 'Không tải được thành viên nhóm.',
                      )
                    : ListView(
                        children: members
                            .map(
                              (member) => CheckboxListTile(
                                value: selected.contains(member.userId),
                                title: Text(member.displayName),
                                subtitle: Text('@${member.username}'),
                                onChanged: (value) => setSheetState(() {
                                  if (value == true)
                                    selected.add(member.userId);
                                  else
                                    selected.remove(member.userId);
                                }),
                              ),
                            )
                            .toList(),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, selected),
                  child: const Text('Xong'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _taskStatusText(ActivityTaskStatus status) => switch (status) {
  ActivityTaskStatus.todo => 'Cần làm',
  ActivityTaskStatus.inProgress => 'Đang thực hiện',
  ActivityTaskStatus.done => 'Hoàn thành',
};
IconData _statusIcon(ActivityTaskStatus status) => switch (status) {
  ActivityTaskStatus.todo => Icons.radio_button_unchecked,
  ActivityTaskStatus.inProgress => Icons.schedule,
  ActivityTaskStatus.done => Icons.check_circle,
};
String _dateText(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

class _TaskCard extends StatelessWidget {
  final ActivityTask task;
  final VoidCallback onTap;
  const _TaskCard({required this.task, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceContainerLowest,
    elevation: 1,
    shadowColor: AppColors.softShadow,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    task.dueAt == null
                        ? 'Không đặt hạn'
                        : 'Hạn: ${_dateText(task.dueAt!)}',
                    style: const TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            _StatusPill(status: task.status),
          ],
        ),
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  final ActivityTaskStatus status;
  const _StatusPill({required this.status});
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _taskStatusText(status),
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

class _TaskStatusSection extends StatelessWidget {
  final ActivityTaskStatus status;
  final VoidCallback? onTap;
  const _TaskStatusSection({required this.status, this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceContainerLowest,
    elevation: 1,
    shadowColor: AppColors.softShadow,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 76),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Icon(_statusIcon(status), color: AppColors.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _taskStatusText(status),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceContainerLowest,
    elevation: 1,
    shadowColor: AppColors.softShadow,
    borderRadius: BorderRadius.circular(12),
    child: child,
  );
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _Failure extends StatelessWidget {
  final VoidCallback onRetry;
  const _Failure({required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
  );
}
