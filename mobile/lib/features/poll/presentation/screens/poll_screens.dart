// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import '../../../journey/data/journey_api.dart';
import '../../../journey/presentation/poll_action_screen.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/realtime/realtime_binding.dart';
import '../../../../core/realtime/reliable_read.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/date_time_formatter.dart';
import '../../data/poll_failure.dart';
import '../../data/poll_models.dart';
import '../../data/poll_repository.dart';
import '../poll_deadline.dart';
import '../../../social/presentation/widgets/user_avatar.dart';

class PollListScreen extends StatefulWidget {
  final String? activityId, groupId;
  final PollRepository repository;
  const PollListScreen({
    super.key,
    required this.activityId,
    required this.repository,
  }) : groupId = null;
  const PollListScreen.group({
    super.key,
    required this.groupId,
    required this.repository,
  }) : activityId = null;
  @override
  State<PollListScreen> createState() => _PollListScreenState();
}

class _PollListScreenState extends State<PollListScreen>
    with RealtimeBinding<PollListScreen> {
  @override
  bool get realtimeReadNeedsRecovery => _read.failure?.retainData == true;
  late final _deadlineRefresh = PollDeadlineRefresh(() {
    if (mounted) _refreshRealtime();
  });
  @override
  void dispose() {
    _read.dispose();
    _deadlineRefresh.dispose();
    super.dispose();
  }

  @override
  String? get realtimeScope => widget.groupId != null
      ? 'group:${widget.groupId}'
      : 'activity:${widget.activityId}';
  @override
  String get realtimePrefix => 'POLL_';
  @override
  Future<void> reloadRealtime() async {
    await _refreshRealtime();
  }

  Future<void> _refreshRealtime() => _read.load(
    () => widget.groupId != null
        ? widget.repository.listGroup(widget.groupId!)
        : widget.repository.list(widget.activityId!),
    onData: (data) {
      _deadlineRefresh.schedule(
        data
            .where((poll) => poll.status == PollStatus.open)
            .map((poll) => poll.deadlineAt),
      );
    },
  );
  final _read = ReliableRead<List<Poll>>();
  @override
  void onRealtimeAccessLost() => _read.denyAccess();
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    if (mounted) _refreshRealtime();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(
      title: const Text('Bình chọn'),
      centerTitle: true,
      actions: [
        IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
      ],
    ),
    floatingActionButton: widget.activityId == null
        ? null
        : FloatingActionButton(
            tooltip: 'Tạo bình chọn',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreatePollScreen(
                    activityId: widget.activityId!,
                    repository: widget.repository,
                  ),
                ),
              );
              _reload();
            },
            child: const Icon(Icons.add),
          ),
    body: ReliableReadBuilder<List<Poll>>(
      read: _read,
      onRetry: _reload,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return _Retry(onTap: _reload);
        final polls = snapshot.data ?? [];
        if (polls.isEmpty)
          return const _Empty(
            icon: Icons.poll_outlined,
            text: 'Chưa có bình chọn nào.',
          );
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            itemCount: polls.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) => _PollCard(
              poll: polls[index],
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PollDetailScreen(
                      pollId: polls[index].id,
                      repository: widget.repository,
                    ),
                  ),
                );
                _reload();
              },
            ),
          ),
        );
      },
    ),
  );
}

class _PollCard extends StatelessWidget {
  final Poll poll;
  final VoidCallback onTap;
  const _PollCard({required this.poll, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLowest,
    elevation: 1,
    shadowColor: Colors.transparent,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    poll.question,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(
                  poll.status == PollStatus.closed
                      ? Icons.lock_outline
                      : Icons.how_to_vote_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (poll.resultsVisible)
              ...poll.options.map(
                (option) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ResultBar(
                    option: option,
                    total: poll.options.fold(
                      0,
                      (total, item) => total + item.voteCount,
                    ),
                  ),
                ),
              )
            else
              Text(
                'Kết quả sẽ hiển thị theo thiết lập bình chọn.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            Text(
              poll.status == PollStatus.closed ? 'Đã đóng' : 'Đang mở',
              style: TextStyle(
                color: poll.status == PollStatus.closed
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : AppColors.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class CreatePollScreen extends StatefulWidget {
  final String activityId;
  final PollRepository repository;
  final Future<void> Function(CreatePollDraft)? onCreate;
  final bool allowMultipleChoiceControl;
  const CreatePollScreen({
    super.key,
    required this.activityId,
    required this.repository,
    this.onCreate,
    this.allowMultipleChoiceControl = false,
  });
  @override
  State<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends State<CreatePollScreen> {
  final _question = TextEditingController();
  final _options = [TextEditingController(), TextEditingController()];
  bool _allowAdd = false,
      _anonymous = false,
      _immediate = true,
      _saving = false;
  DateTime? _deadline;
  bool _multipleChoice = false;
  @override
  void dispose() {
    _question.dispose();
    for (final controller in _options) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final options = _options
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    if (_question.text.trim().isEmpty || options.length < 2) {
      _notice('Nhập câu hỏi và ít nhất hai lựa chọn.');
      return;
    }
    if (_deadline != null && !isFuturePollDeadline(_deadline!)) {
      _notice('Hạn bình chọn phải sau thời điểm hiện tại.');
      return;
    }
    setState(() => _saving = true);
    try {
      final draft = CreatePollDraft(
        question: _question.text.trim(),
        options: options,
        allowMemberAddOption: _allowAdd,
        anonymous: _anonymous,
        showResultsImmediately: _immediate,
        deadlineAt: _deadline,
        multipleChoice: _multipleChoice,
      );
      if (widget.onCreate != null) {
        await widget.onCreate!(draft);
      } else {
        await widget.repository.create(widget.activityId, draft);
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      _notice(createPollFailureMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final initial = _deadline ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted || time == null) return;
    setState(() {
      _deadline = combinePollDeadline(
        date,
        Duration(hours: time.hour, minutes: time.minute),
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(centerTitle: true, title: const Text('Tạo bình chọn')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
      children: [
        _Panel(
          child: TextField(
            controller: _question,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Câu hỏi',
              hintText: 'Bạn muốn làm gì vào cuối tuần này?',
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lựa chọn',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              ..._options.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: TextField(
                    controller: entry.value,
                    decoration: InputDecoration(
                      hintText: 'Lựa chọn ${entry.key + 1}',
                      suffixIcon: _options.length > 2
                          ? IconButton(
                              tooltip: 'Xóa lựa chọn',
                              onPressed: () => setState(() {
                                final controller = _options.removeAt(entry.key);
                                controller.dispose();
                              }),
                              icon: const Icon(Icons.close),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _options.add(TextEditingController())),
                icon: const Icon(Icons.add),
                label: const Text('Thêm lựa chọn'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.calendar_today_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Hạn bình chọn'),
                subtitle: Text(
                  _deadline == null
                      ? 'Không đặt hạn'
                      : AppDateTimeFormatter.formatDateTime(_deadline!),
                ),
                trailing: _deadline == null
                    ? const Icon(Icons.chevron_right)
                    : IconButton(
                        tooltip: 'Xóa hạn bình chọn',
                        onPressed: () => setState(() => _deadline = null),
                        icon: const Icon(Icons.close),
                      ),
                onTap: _pickDeadline,
              ),
              if (widget.allowMultipleChoiceControl)
                SwitchListTile(
                  value: _multipleChoice,
                  onChanged: (value) => setState(() => _multipleChoice = value),
                  title: const Text('Cho phép chọn nhiều đáp án'),
                ),
              SwitchListTile(
                value: _allowAdd,
                onChanged: (value) => setState(() => _allowAdd = value),
                title: const Text('Cho phép thành viên thêm lựa chọn'),
              ),
              SwitchListTile(
                value: _anonymous,
                onChanged: (value) => setState(() => _anonymous = value),
                title: const Text('Bình chọn ẩn danh'),
              ),
              SwitchListTile(
                value: _immediate,
                onChanged: (value) => setState(() => _immediate = value),
                title: const Text('Hiển thị kết quả ngay'),
              ),
            ],
          ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: FilledButton.icon(
        onPressed: _saving ? null : _save,
        icon: const Icon(Icons.arrow_forward),
        label: Text(_saving ? 'Đang tạo...' : 'Tạo bình chọn'),
      ),
    ),
  );
}

class PollDetailScreen extends StatefulWidget {
  final String pollId;
  final PollRepository repository;
  const PollDetailScreen({
    super.key,
    required this.pollId,
    required this.repository,
  });
  @override
  State<PollDetailScreen> createState() => _PollDetailScreenState();
}

class _PollDetailScreenState extends State<PollDetailScreen>
    with RealtimeBinding<PollDetailScreen> {
  @override
  bool get realtimeReadNeedsRecovery => _read.failure?.retainData == true;
  late final _deadlineRefresh = PollDeadlineRefresh(() {
    if (mounted) _refreshRealtime();
  });
  @override
  void dispose() {
    _read.dispose();
    _deadlineRefresh.dispose();
    super.dispose();
  }

  @override
  String? get realtimeAggregateId => widget.pollId;
  Future<void> _refreshRealtime() => _read.load(
    () => widget.repository.get(widget.pollId),
    onData: (data) {
      bindRealtimeResource(data.realtimeScope);
      _deadlineRefresh.schedule(
        data.status == PollStatus.open ? [data.deadlineAt] : [],
      );
    },
  );
  final _read = ReliableRead<Poll>();
  @override
  void onRealtimeAccessLost() => _read.denyAccess();
  @override
  String? get realtimeScope => null;
  @override
  String get realtimePrefix => 'POLL_';
  @override
  Future<void> reloadRealtime() async {
    await _refreshRealtime();
  }

  String? _selectedOptionId;
  bool _voting = false;
  int _loadRevision = 0;
  int _selectionRevision = -1;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    if (!mounted) return;
    _loadRevision++;
    _refreshRealtime();
  }

  Future<void> _vote(Poll poll) async {
    if (_voting || !poll.permissions.canVote || _read.failure != null) return;
    final selectedOptionId = _selectedOptionId;
    if (selectedOptionId == null) {
      _notice('Chọn ít nhất một lựa chọn.');
      return;
    }
    final generation = _read.generation;
    setState(() => _voting = true);
    try {
      await widget.repository.vote(poll.id, [selectedOptionId]);
      if (mounted) _reload();
    } on ApiException catch (error) {
      if (!mounted || !_read.isCurrent(generation)) return;
      if (error.statusCode == 401 ||
          error.statusCode == 403 ||
          error.statusCode == 404)
        _read.denyAccess();
      _notice(votePollFailureMessage(error));
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'Poll vote',
        ),
      );
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  Future<void> _close(Poll poll) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 44, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              const Text(
                'Đóng bình chọn?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bạn sẽ không thể nhận thêm bình chọn mới.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Đóng bình chọn'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Quay lại'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await widget.repository.close(poll.id);
      _reload();
    } catch (_) {
      _notice('Không thể đóng bình chọn.');
    }
  }

  Future<void> _add(Poll poll) async {
    final controller = TextEditingController();
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Tên lựa chọn'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Thêm lựa chọn'),
            ),
          ],
        ),
      ),
    );
    if (text == null || text.isEmpty) return;
    try {
      await widget.repository.addOption(poll.id, text);
      _reload();
    } catch (_) {
      _notice('Không thể thêm lựa chọn.');
    }
  }

  Future<void> _manageOption(Poll poll, PollOption option) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (option.canEdit)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Chỉnh sửa lựa chọn'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
            if (option.canDisable)
              ListTile(
                leading: const Icon(Icons.block_outlined),
                title: const Text('Vô hiệu hóa lựa chọn'),
                onTap: () => Navigator.pop(context, 'disable'),
              ),
            if (option.canDelete)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('Xóa lựa chọn'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (action == null) return;
    try {
      if (action == 'edit') {
        final text = await _editOption(option.text);
        if (text != null && text.isNotEmpty)
          await widget.repository.updateOption(poll.id, option.id, text);
      }
      if (action == 'disable')
        await widget.repository.disableOption(poll.id, option.id);
      if (action == 'delete')
        await widget.repository.deleteOption(poll.id, option.id);
      _reload();
    } catch (_) {
      _notice('Không thể cập nhật lựa chọn.');
    }
  }

  Future<String?> _editOption(String initial) async {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chỉnh sửa lựa chọn'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Chi tiết bình chọn'),
      centerTitle: true,
      actions: [
        IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
      ],
    ),
    body: ReliableReadBuilder<Poll>(
      read: _read,
      onRetry: _reload,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData) return _Retry(onTap: _reload);
        final poll = snapshot.data!;
        if (_selectionRevision != _loadRevision) {
          _selectedOptionId = poll.callerOptionIds.isEmpty
              ? null
              : poll.callerOptionIds.first;
          _selectionRevision = _loadRevision;
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              poll.question,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              poll.status == PollStatus.closed
                  ? 'Bình chọn đã đóng'
                  : 'Bình chọn đang mở',
              style: TextStyle(
                color: poll.status == PollStatus.closed
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : AppColors.secondary,
              ),
            ),
            if (poll.resultsVisible) TextButton.icon(onPressed:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>PollActionScreen(api:JourneyApi(widget.repository.api.dio),poll:poll.id))),icon:const Icon(Icons.playlist_add_check),label:const Text('Tạo công việc / lịch trình')),
            if (!poll.resultsVisible)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Kết quả sẽ hiển thị theo thiết lập của người tạo.',
                ),
              ),
            const SizedBox(height: 12),
            ...poll.options.map(
              (option) => _PollChoiceRow(
                option: option,
                selected: _selectedOptionId == option.id,
                enabled:
                    poll.permissions.canVote && !_voting && !option.disabled,
                showVoteCount: poll.resultsVisible,
                onSelect: () => setState(() => _selectedOptionId = option.id),
                onManage:
                    option.canEdit || option.canDisable || option.canDelete
                    ? () => _manageOption(poll, option)
                    : null,
              ),
            ),
            if (poll.permissions.canVote)
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                onPressed: _voting || _selectedOptionId == null
                    ? null
                    : () => _vote(poll),
                child: const Text('Gửi bình chọn'),
              ),
            if (poll.permissions.canAddOption)
              TextButton.icon(
                onPressed: () => _add(poll),
                icon: const Icon(Icons.add),
                label: const Text('Thêm lựa chọn'),
              ),
            if (poll.permissions.canViewVoters)
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PollVotersScreen(
                      poll: poll,
                      repository: widget.repository,
                    ),
                  ),
                ),
                child: const Text('Người đã bình chọn'),
              ),
            if (poll.resultsVisible)
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PollResultsScreen(
                      poll: poll,
                      repository: widget.repository,
                    ),
                  ),
                ),
                child: const Text('Kết quả bình chọn'),
              ),
            if (poll.permissions.canClose)
              OutlinedButton(
                onPressed: () => _close(poll),
                child: const Text('Đóng bình chọn'),
              ),
          ],
        );
      },
    ),
  );
}

class PollVotersScreen extends StatelessWidget {
  final Poll poll;
  final PollRepository repository;
  const PollVotersScreen({
    super.key,
    required this.poll,
    required this.repository,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(centerTitle: true, title: const Text('Người đã bình chọn')),
    body: _LivePoll(
      initial: poll,
      repository: repository,
      includeVoters: true,
      builder: (context, current, voters) => _build(context, current, voters),
    ),
  );

  Widget _build(BuildContext context, Poll poll, List<PollVoters> voters) =>
      poll.voteVisibility == VoteVisibility.anonymous
      ? const _Empty(icon: Icons.visibility_off, text: 'Bình chọn này ẩn danh.')
      : ListView(
          padding: const EdgeInsets.all(20),
          children: voters
              .where(
                (voter) =>
                    poll.options.any((option) => option.id == voter.optionId),
              )
              .map((voter) {
                final option = poll.options.firstWhere(
                  (item) => item.id == voter.optionId,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.text,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('${voter.userIds.length} người đã bình chọn'),
                        for (final person in voter.participants)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: UserAvatar(
                              displayName: person.displayName,
                              avatarStorageKey: person.avatarStorageKey,
                              radius: 16,
                            ),
                            title: Text(person.displayName),
                          ),
                      ],
                    ),
                  ),
                );
              })
              .toList(),
        );
}

class PollResultsScreen extends StatelessWidget {
  final Poll poll;
  final PollRepository? repository;
  const PollResultsScreen({super.key, required this.poll, this.repository});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(centerTitle: true, title: const Text('Kết quả bình chọn')),
    body: repository == null
        ? _build(context, poll)
        : _LivePoll(
            initial: poll,
            repository: repository!,
            includeVoters: true,
            builder: (context, current, voters) =>
                _build(context, current, voters),
          ),
  );

  Widget _build(
    BuildContext context,
    Poll poll, [
    List<PollVoters> voters = const [],
  ]) => !poll.resultsVisible
      ? const _Empty(
          icon: Icons.lock_outline,
          text: 'Kết quả chưa được hiển thị.',
        )
      : ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if(repository!=null)TextButton.icon(onPressed:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>PollActionScreen(api:JourneyApi(repository!.api.dio),poll:poll.id))),icon:const Icon(Icons.playlist_add_check),label:const Text('Tạo công việc / lịch trình')),
            Text(
              poll.question,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            Text(
              poll.status == PollStatus.closed
                  ? 'Bình chọn đã đóng'
                  : 'Bình chọn đang mở',
            ),
            const SizedBox(height: 20),
            ...poll.options.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ResultBar(
                      option: option,
                      total: poll.options.fold(
                        0,
                        (total, item) => total + item.voteCount,
                      ),
                    ),
                    for (final entry in voters.where(
                      (v) => v.optionId == option.id,
                    ))
                      for (final person in entry.participants)
                        ListTile(
                          dense: true,
                          leading: UserAvatar(
                            displayName: person.displayName,
                            avatarStorageKey: person.avatarStorageKey,
                            radius: 14,
                          ),
                          title: Text(person.displayName),
                        ),
                  ],
                ),
              ),
            ),
          ],
        );
}

class _LivePoll extends StatefulWidget {
  final Poll initial;
  final PollRepository repository;
  final bool includeVoters;
  final Widget Function(BuildContext, Poll, List<PollVoters>) builder;
  const _LivePoll({
    required this.initial,
    required this.repository,
    required this.builder,
    this.includeVoters = false,
  });
  @override
  State<_LivePoll> createState() => _LivePollState();
}

class _LivePollState extends State<_LivePoll> with RealtimeBinding<_LivePoll> {
  @override
  bool get realtimeReadNeedsRecovery => _read.failure?.retainData == true;
  late final _deadlineRefresh = PollDeadlineRefresh(() {
    if (mounted) reloadRealtime();
  });
  @override
  void initState() {
    super.initState();
    // A route argument is a previous valid projection, not current authority.
    if (!widget.includeVoters)
      _read.accept(_PollLiveData(widget.initial, const []));
    reloadRealtime();
  }

  @override
  void dispose() {
    _read.dispose();
    _deadlineRefresh.dispose();
    super.dispose();
  }

  final _read = ReliableRead<_PollLiveData>();
  @override
  void onRealtimeAccessLost() => _read.denyAccess();
  @override
  String get realtimeScope => widget.initial.realtimeScope;
  @override
  String get realtimePrefix => 'POLL_';
  @override
  String get realtimeAggregateId => widget.initial.id;
  @override
  Future<void> reloadRealtime() => _read.load(
    () async {
      final poll = await widget.repository.get(widget.initial.id);
      // Never request/expose voter identities for an anonymous Poll.
      final voters =
          widget.includeVoters &&
              poll.voteVisibility == VoteVisibility.public &&
              poll.permissions.canViewVoters
          ? await widget.repository.voters(poll.id)
          : <PollVoters>[];
      return _PollLiveData(poll, voters);
    },
    onData: (data) => _deadlineRefresh.schedule(
      data.poll.status == PollStatus.open ? [data.poll.deadlineAt] : [],
    ),
  );
  @override
  Widget build(BuildContext context) => ReliableReadBuilder<_PollLiveData>(
    read: _read,
    onRetry: reloadRealtime,
    builder: (context, snapshot) => snapshot.hasData
        ? widget.builder(
            context,
            snapshot.requireData.poll,
            snapshot.requireData.voters,
          )
        : const Center(child: CircularProgressIndicator()),
  );
}

class _PollLiveData {
  final Poll poll;
  final List<PollVoters> voters;
  const _PollLiveData(this.poll, this.voters);
}

class _PollChoiceRow extends StatelessWidget {
  final PollOption option;
  final bool selected, enabled;
  final bool showVoteCount;
  final VoidCallback onSelect;
  final VoidCallback? onManage;

  const _PollChoiceRow({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.onSelect,
    this.showVoteCount = false,
    this.onManage,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: enabled,
    child: InkWell(
      onTap: enabled ? onSelect : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: enabled ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.text,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (option.disabled)
              const Text('Đã vô hiệu hóa', style: TextStyle(fontSize: 12)),
            if (showVoteCount && !option.disabled)
              Text(
                '${option.voteCount} phiếu',
                style: const TextStyle(fontSize: 12),
              ),
            if (onManage != null)
              IconButton(
                tooltip: 'Quản lý lựa chọn',
                icon: const Icon(Icons.more_horiz),
                onPressed: onManage,
              ),
          ],
        ),
      ),
    ),
  );
}

class _ResultBar extends StatelessWidget {
  final PollOption option;
  final int total;
  const _ResultBar({required this.option, required this.total});
  @override
  Widget build(BuildContext context) {
    final value = total == 0 ? 0.0 : option.voteCount / total;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  option.text,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text('${(value * 100).round()}%'),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: value,
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLowest,
    elevation: 1,
    shadowColor: Colors.transparent,
    borderRadius: BorderRadius.circular(12),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
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
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _Retry extends StatelessWidget {
  final VoidCallback onTap;
  const _Retry({required this.onTap});
  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton(onPressed: onTap, child: const Text('Thử lại')),
  );
}
