import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/date_time_formatter.dart';
import '../../groups/data/group_repository.dart';
import '../../groups/data/models/group_models.dart';
import '../../social/presentation/widgets/user_avatar.dart';
import '../application/expense_controllers.dart';
import '../data/expense_failure.dart';
import '../data/expense_models.dart';
import '../data/expense_repository.dart';

class ExpenseListScreen extends StatefulWidget {
  final String groupId;
  final ExpenseRepository repository;
  final GroupRepository groupRepository;
  const ExpenseListScreen({
    super.key,
    required this.groupId,
    required this.repository,
    required this.groupRepository,
  });

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  late final ExpenseListController _controller = ExpenseListController(
    widget.repository,
  );

  @override
  void initState() {
    super.initState();
    _controller.load(widget.groupId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ExpenseFormScreen(
          groupId: widget.groupId,
          repository: widget.repository,
          groupRepository: widget.groupRepository,
        ),
      ),
    );
    if (mounted) _controller.load(widget.groupId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Chi tiêu'),
      actions: [
        IconButton(
          tooltip: 'Số dư',
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => ExpenseBalanceScreen(
                groupId: widget.groupId,
                repository: widget.repository,
              ),
            ),
          ),
          icon: const Icon(Icons.account_balance_wallet_outlined),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _create,
      icon: const Icon(Icons.add),
      label: const Text('Thêm khoản chi'),
    ),
    body: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;
        if (state.loading && state.expenses.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.failure != null && state.expenses.isEmpty) {
          return _FailureState(
            message: state.failure!,
            onRetry: () => _controller.load(widget.groupId),
          );
        }
        return RefreshIndicator(
          onRefresh: () => _controller.load(widget.groupId),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              if (state.balances != null)
                _BalanceSummary(
                  balances: state.balances!,
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => ExpenseBalanceScreen(
                        groupId: widget.groupId,
                        repository: widget.repository,
                      ),
                    ),
                  ),
                ),
              if (state.failure != null)
                _InlineFailure(
                  message: state.failure!,
                  onRetry: () => _controller.load(widget.groupId),
                ),
              if (state.expenses.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 84),
                  child: _EmptyState(),
                )
              else
                ...state.expenses.map(
                  (expense) => _ExpenseRow(
                    expense: expense,
                    onTap: () => Navigator.of(context)
                        .push<void>(
                          MaterialPageRoute(
                            builder: (_) => ExpenseDetailScreen(
                              groupId: widget.groupId,
                              expenseId: expense.id,
                              repository: widget.repository,
                              groupRepository: widget.groupRepository,
                            ),
                          ),
                        )
                        .then((_) => _controller.load(widget.groupId)),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class ExpenseDetailScreen extends StatefulWidget {
  final String groupId, expenseId;
  final ExpenseRepository repository;
  final GroupRepository groupRepository;
  const ExpenseDetailScreen({
    super.key,
    required this.groupId,
    required this.expenseId,
    required this.repository,
    required this.groupRepository,
  });
  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  late Future<ExpenseDetail> _future = widget.repository.detail(
    widget.expenseId,
  );
  bool _working = false;

  Future<void> _reload() async {
    setState(() {
      _future = widget.repository.detail(widget.expenseId);
    });
  }

  Future<void> _cancel(ExpenseDetail expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy khoản chi?'),
        content: const Text(
          'Khoản chi sẽ được giữ trong lịch sử và không còn ảnh hưởng đến số dư.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hủy khoản chi'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    try {
      await widget.repository.cancel(expense.id);
      if (mounted) await _reload();
    } on ExpenseFailure catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Chi tiết khoản chi')),
    body: FutureBuilder<ExpenseDetail>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _FailureState(
            message: 'Chưa thể tải khoản chi.',
            onRetry: _reload,
          );
        }
        final expense = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              expense.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              expense.amount.formatted,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '${_dateTime(expense.occurredAt)} · ${expense.status == 'ACTIVE' ? 'Đang tính vào số dư' : 'Đã hủy'}',
            ),
            if (expense.note?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(expense.note!),
            ],
            const Divider(height: 32),
            Text(
              'Người thanh toán',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: UserAvatar(
                displayName: expense.payer.displayName,
                avatarStorageKey: expense.payer.avatarStorageKey,
              ),
              title: Text(expense.payer.displayName),
              subtitle: Text(
                expense.creator == null
                    ? 'Người tạo không còn khả dụng'
                    : 'Khoản chi do ${expense.creator!.displayName} ghi nhận',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Phần chia · ${expense.splitMethod == 'EQUAL' ? 'Chia đều' : 'Số tiền tùy chỉnh'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            ...expense.shares.map(
              (share) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: UserAvatar(
                  displayName: share.displayName,
                  avatarStorageKey: share.avatarStorageKey,
                  radius: 20,
                ),
                title: Text(share.displayName),
                trailing: Text(
                  share.amount.formatted,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            if (expense.changeHistory.isNotEmpty) ...[
              const Divider(height: 32),
              Text(
                'Lịch sử chỉnh sửa',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ...expense.changeHistory.map(
                (change) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_fieldLabel(change.fieldName)),
                  subtitle: Text(
                    '${_changeDescription(change)}\n${_dateTime(change.createdAt)}',
                  ),
                ),
              ),
            ],
            if (expense.permissions.canEdit && expense.status == 'ACTIVE') ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _working
                    ? null
                    : () async {
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => ExpenseFormScreen(
                              groupId: widget.groupId,
                              repository: widget.repository,
                              groupRepository: widget.groupRepository,
                              initial: expense,
                            ),
                          ),
                        );
                        if (mounted) _reload();
                      },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Chỉnh sửa khoản chi'),
              ),
            ],
            if (expense.permissions.canCancel && expense.status == 'ACTIVE')
              TextButton.icon(
                onPressed: _working ? null : () => _cancel(expense),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Hủy khoản chi'),
              ),
            if (_working)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class ExpenseFormScreen extends StatefulWidget {
  final String groupId;
  final ExpenseRepository repository;
  final GroupRepository groupRepository;
  final ExpenseDetail? initial;
  const ExpenseFormScreen({
    super.key,
    required this.groupId,
    required this.repository,
    required this.groupRepository,
    this.initial,
  });
  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _amount = TextEditingController(
    text: widget.initial?.amount.decimal ?? '',
  );
  late final _note = TextEditingController(text: widget.initial?.note ?? '');
  final Map<String, TextEditingController> _custom = {};
  late final ExpenseFormController _controller = ExpenseFormController(
    widget.repository,
  );
  late DateTime _occurredAt =
      widget.initial?.occurredAt.toLocal() ?? DateTime.now();
  late String _split = widget.initial?.splitMethod ?? 'EQUAL';
  late String? _payerId = widget.initial?.payer.id;
  late final Set<String> _participants =
      widget.initial?.shares.map((s) => s.userId).toSet() ?? {};
  late Future<List<GroupMember>> _members = widget.groupRepository.getMembers(
    widget.groupId,
  );

  @override
  void initState() {
    super.initState();
    for (final share in widget.initial?.shares ?? <ExpenseShare>[]) {
      _custom[share.userId] = TextEditingController(text: share.amount.decimal);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    for (final controller in _custom.values) {
      controller.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (time == null || !mounted) return;
    setState(
      () => _occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = ExpenseMoney.parseInput(_amount.text);
    if (amount == null ||
        !amount.isPositive ||
        _payerId == null ||
        _participants.isEmpty) {
      _show('Nhập số tiền, người thanh toán và ít nhất một người tham gia.');
      return;
    }
    final custom = <String, ExpenseMoney>{};
    if (_split == 'CUSTOM_AMOUNT') {
      for (final id in _participants) {
        final value = ExpenseMoney.parseInput(_custom[id]?.text ?? '');
        if (value == null || !value.isPositive) {
          _show('Nhập phần chia hợp lệ cho từng người.');
          return;
        }
        custom[id] = value;
      }
      final total = custom.values.fold(
        BigInt.zero,
        (sum, item) => sum + item.minorUnits,
      );
      if (total != amount.minorUnits) {
        _show('Tổng phần chia phải bằng tổng khoản chi.');
        return;
      }
    }
    final draft = ExpenseDraft(
      title: _title.text.trim(),
      amount: amount,
      payerUserId: _payerId!,
      splitMethod: _split,
      participantUserIds: _participants.toList(),
      customShares: custom,
      activityId: widget.initial?.activityId,
      occurredAt: _occurredAt,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    final result = await _controller.save(
      widget.groupId,
      draft,
      expenseId: widget.initial?.id,
    );
    if (!mounted) return;
    if (result != null) {
      Navigator.of(context).pop(result);
    } else if (_controller.failure != null) {
      _show(_controller.failure!);
    }
  }

  void _show(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: Text(
        widget.initial == null ? 'Thêm khoản chi' : 'Chỉnh sửa khoản chi',
      ),
    ),
    body: FutureBuilder<List<GroupMember>>(
      future: _members,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _FailureState(
            message: 'Chưa thể tải thành viên nhóm.',
            onRetry: () async {
              if (mounted) {
                setState(() {
                  _members = widget.groupRepository.getMembers(widget.groupId);
                });
              }
            },
          );
        }
        final members = snapshot.data!;
        if (_payerId == null && members.isNotEmpty) {
          _payerId = members.first.userId;
        }
        for (final member in members) {
          _custom.putIfAbsent(member.userId, () => TextEditingController());
        }
        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              TextFormField(
                controller: _title,
                maxLength: 255,
                decoration: const InputDecoration(labelText: 'Tên khoản chi'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Nhập tên khoản chi.'
                    : null,
              ),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Số tiền',
                  hintText: 'Ví dụ: 250000',
                ),
                validator: (v) =>
                    ExpenseMoney.parseInput(v ?? '')?.isPositive == true
                    ? null
                    : 'Nhập số tiền lớn hơn 0, tối đa 2 chữ số thập phân.',
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ngày và giờ'),
                subtitle: Text(_dateTime(_occurredAt)),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: _chooseDate,
              ),
              DropdownButtonFormField<String>(
                initialValue: members.any((m) => m.userId == _payerId)
                    ? _payerId
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Người thanh toán',
                ),
                items: members
                    .map(
                      (m) => DropdownMenuItem(
                        value: m.userId,
                        child: Text(
                          m.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                validator: (v) =>
                    v == null ? 'Chọn người thanh toán trong nhóm.' : null,
                onChanged: (v) => setState(() => _payerId = v),
              ),
              const SizedBox(height: 20),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'EQUAL', label: Text('Chia đều')),
                  ButtonSegment(
                    value: 'CUSTOM_AMOUNT',
                    label: Text('Tùy chỉnh'),
                  ),
                ],
                selected: {_split},
                onSelectionChanged: (value) =>
                    setState(() => _split = value.first),
              ),
              const SizedBox(height: 8),
              Text(
                'Người tham gia',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...members.map(
                (member) => Column(
                  children: [
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _participants.contains(member.userId),
                      title: Text(member.displayName),
                      secondary: UserAvatar(
                        displayName: member.displayName,
                        avatarStorageKey: member.avatarStorageKey,
                        radius: 20,
                      ),
                      onChanged: (selected) => setState(() {
                        if (selected == true) {
                          _participants.add(member.userId);
                        } else {
                          _participants.remove(member.userId);
                        }
                      }),
                    ),
                    if (_split == 'CUSTOM_AMOUNT' &&
                        _participants.contains(member.userId))
                      Padding(
                        padding: const EdgeInsets.only(left: 56),
                        child: TextField(
                          controller: _custom[member.userId],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Phần của ${member.displayName}',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ...?widget.initial?.shares
                  .where(
                    (share) => !members.any((m) => m.userId == share.userId),
                  )
                  .map(
                    (share) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _participants.contains(share.userId),
                      title: Text(share.displayName),
                      subtitle: const Text('Không còn trong nhóm'),
                      onChanged: (selected) => setState(() {
                        if (selected == true) {
                          _participants.add(share.userId);
                        } else {
                          _participants.remove(share.userId);
                        }
                      }),
                    ),
                  ),
              TextFormField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (không bắt buộc)',
                ),
              ),
              const SizedBox(height: 24),
              ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => FilledButton.icon(
                  onPressed: _controller.saving ? null : _submit,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    _controller.saving ? 'Đang lưu…' : 'Lưu khoản chi',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class ExpenseBalanceScreen extends StatelessWidget {
  final String groupId;
  final ExpenseRepository repository;
  const ExpenseBalanceScreen({
    super.key,
    required this.groupId,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Số dư nhóm')),
    body: FutureBuilder<MyExpenseBalances>(
      future: repository.myBalances(groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const Center(child: Text('Chưa thể tải số dư.'));
        }
        final value = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _BalanceSummary(balances: value),
            const SizedBox(height: 16),
            if (value.balances.isEmpty)
              const _EmptyState(text: 'Hiện không có khoản nợ trong nhóm.'),
            ...value.balances.map(
              (entry) => ListTile(
                leading: UserAvatar(
                  displayName: entry.user.displayName,
                  avatarStorageKey: entry.user.avatarStorageKey,
                ),
                title: Text(entry.user.displayName),
                subtitle: Text(
                  entry.direction == 'OWES_YOU'
                      ? 'Bạn được nhận'
                      : 'Bạn đang nợ',
                ),
                trailing: Text(
                  entry.amount.formatted,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _ExpenseRow extends StatelessWidget {
  final ExpenseSummary expense;
  final VoidCallback onTap;
  const _ExpenseRow({required this.expense, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
    onTap: onTap,
    leading: const CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
    title: Text(expense.title, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(
      '${expense.payer.displayName} · ${_dateTime(expense.occurredAt)}${expense.status == 'CANCELLED' ? ' · Đã hủy' : ''}',
    ),
    trailing: Text(
      expense.amount.formatted,
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
  );
}

class _BalanceSummary extends StatelessWidget {
  final MyExpenseBalances balances;
  final VoidCallback? onTap;
  const _BalanceSummary({required this.balances, this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Số dư của bạn',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _BalanceValue(
                      label: 'Bạn đang nợ',
                      value: balances.totalOwedByMe,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BalanceValue(
                      label: 'Bạn được nhận',
                      value: balances.totalOwedToMe,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BalanceValue extends StatelessWidget {
  final String label;
  final ExpenseMoney value;
  const _BalanceValue({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 4),
      Text(
        value.formatted,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({this.text = 'Chưa có khoản chi nào.'});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined, size: 40),
          const SizedBox(height: 8),
          Text(text),
        ],
      ),
    ),
  );
}

class _FailureState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _FailureState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Thử lại'),
        ),
      ],
    ),
  );
}

class _InlineFailure extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _InlineFailure({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(message),
    trailing: IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh)),
  );
}

String _dateTime(DateTime value) => AppDateTimeFormatter.formatDateTime(value);
String _changeDescription(ExpenseChange change) {
  String value(String? raw) {
    if (raw == null) return 'Không có';
    return switch (change.fieldName) {
      'status' => switch (raw) {
        'ACTIVE' => 'Đang tính vào số dư',
        'CANCELLED' => 'Đã hủy',
        _ => 'Đã cập nhật',
      },
      'splitMethod' => raw == 'EQUAL' ? 'Chia đều' : 'Số tiền tùy chỉnh',
      'amount' => ExpenseMoney.fromJson(raw).formatted,
      'occurredAt' =>
        DateTime.tryParse(raw) == null
            ? 'Đã cập nhật'
            : _dateTime(DateTime.parse(raw)),
      _ => raw,
    };
  }

  return switch (change.fieldName) {
    'title' ||
    'note' ||
    'status' ||
    'splitMethod' ||
    'amount' ||
    'occurredAt' => '${value(change.oldValue)} → ${value(change.newValue)}',
    _ => 'Đã cập nhật ${_fieldLabel(change.fieldName).toLowerCase()}.',
  };
}

String _fieldLabel(String field) => switch (field) {
  'title' => 'Tên khoản chi',
  'amount' => 'Số tiền',
  'payerUserId' => 'Người thanh toán',
  'splitMethod' => 'Cách chia',
  'activityId' => 'Hoạt động',
  'occurredAt' => 'Ngày chi',
  'note' => 'Ghi chú',
  'shares' => 'Phần chia',
  'status' => 'Trạng thái',
  _ => 'Khoản chi',
};
