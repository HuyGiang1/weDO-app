// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/date_time_formatter.dart';
import '../../data/poll_failure.dart';
import '../../data/poll_models.dart';
import '../../data/poll_repository.dart';
import '../poll_deadline.dart';

class PollListScreen extends StatefulWidget {
  final String activityId;
  final PollRepository repository;
  const PollListScreen({
    super.key,
    required this.activityId,
    required this.repository,
  });
  @override
  State<PollListScreen> createState() => _PollListScreenState();
}

class _PollListScreenState extends State<PollListScreen> {
  late Future<List<Poll>> _future;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() {
    _future = widget.repository.list(widget.activityId);
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Bình chọn'),
      centerTitle: true,
      actions: [
        IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      tooltip: 'Tạo bình chọn',
      onPressed: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CreatePollScreen(
              activityId: widget.activityId,
              repository: widget.repository,
            ),
          ),
        );
        _reload();
      },
      child: const Icon(Icons.add),
    ),
    body: FutureBuilder<List<Poll>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
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
    color: Colors.white,
    elevation: 1,
    shadowColor: AppColors.softShadow,
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
                  color: AppColors.primary,
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
              const Text(
                'Kết quả sẽ hiển thị theo thiết lập bình chọn.',
                style: TextStyle(color: AppColors.onSurfaceVariant),
              ),
            Text(
              poll.status == PollStatus.closed ? 'Đã đóng' : 'Đang mở',
              style: TextStyle(
                color: poll.status == PollStatus.closed
                    ? AppColors.onSurfaceVariant
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
  const CreatePollScreen({
    super.key,
    required this.activityId,
    required this.repository,
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
  @override
  void dispose() {
    _question.dispose();
    for (final controller in _options) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
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
      await widget.repository.create(
        widget.activityId,
        CreatePollDraft(
          question: _question.text.trim(),
          options: options,
          allowMemberAddOption: _allowAdd,
          anonymous: _anonymous,
          showResultsImmediately: _immediate,
          deadlineAt: _deadline,
        ),
      );
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
    backgroundColor: AppColors.background,
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
                leading: const Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.primary,
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

class _PollDetailScreenState extends State<PollDetailScreen> {
  late Future<Poll> _future;
  String? _selectedOptionId;
  int _loadRevision = 0;
  int _selectionRevision = -1;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() {
    _loadRevision++;
    _future = widget.repository.get(widget.pollId);
  });
  Future<void> _vote(Poll poll) async {
    final selectedOptionId = _selectedOptionId;
    if (selectedOptionId == null) {
      _notice('Chọn ít nhất một lựa chọn.');
      return;
    }
    try {
      await widget.repository.vote(poll.id, [selectedOptionId]);
      _reload();
    } catch (_) {
      _notice('Không thể cập nhật bình chọn.');
    }
  }

  Future<void> _close(Poll poll) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 44, color: AppColors.error),
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
      backgroundColor: AppColors.surfaceContainerLowest,
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
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
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
    body: FutureBuilder<Poll>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
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
                    ? AppColors.onSurfaceVariant
                    : AppColors.secondary,
              ),
            ),
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
                enabled: poll.permissions.canVote && !option.disabled,
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
                onPressed: _selectedOptionId == null ? null : () => _vote(poll),
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
                    builder: (_) => PollResultsScreen(poll: poll),
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
    backgroundColor: AppColors.background,
    appBar: AppBar(centerTitle: true, title: const Text('Người đã bình chọn')),
    body: poll.voteVisibility == VoteVisibility.anonymous
        ? const _Empty(
            icon: Icons.visibility_off,
            text: 'Bình chọn này ẩn danh.',
          )
        : FutureBuilder<List<PollVoters>>(
            future: repository.voters(poll.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData)
                return const _Empty(
                  icon: Icons.error_outline,
                  text: 'Không thể tải người đã bình chọn.',
                );
              return ListView(
                padding: const EdgeInsets.all(20),
                children: snapshot.data!.map((voter) {
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
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
  );
}

class PollResultsScreen extends StatelessWidget {
  final Poll poll;
  const PollResultsScreen({super.key, required this.poll});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(centerTitle: true, title: const Text('Kết quả bình chọn')),
    body: !poll.resultsVisible
        ? const _Empty(
            icon: Icons.lock_outline,
            text: 'Kết quả chưa được hiển thị.',
          )
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                poll.question,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              ...poll.options.map(
                (option) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ResultBar(
                    option: option,
                    total: poll.options.fold(
                      0,
                      (total, item) => total + item.voteCount,
                    ),
                  ),
                ),
              ),
            ],
          ),
  );
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
              ? AppColors.primaryFixed
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: enabled ? AppColors.primary : AppColors.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.text,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? AppColors.onSurface
                      : AppColors.onSurfaceVariant,
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
        color: AppColors.surfaceContainerLow,
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
            color: AppColors.primary,
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
    color: AppColors.surfaceContainerLowest,
    elevation: 1,
    shadowColor: AppColors.softShadow,
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
          Icon(icon, size: 48, color: AppColors.primary),
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
