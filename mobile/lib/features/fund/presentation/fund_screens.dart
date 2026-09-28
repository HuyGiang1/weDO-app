import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../groups/data/models/group_models.dart';
import '../application/fund_controllers.dart';
import '../data/fund_models.dart';
import '../data/fund_repository.dart';

class GroupFundScreen extends StatefulWidget {
  final String groupId;
  final String? groupName;
  final FundRepository repository;
  final Future<List<GroupMember>> Function()? loadMembers;
  final GroupFundController? controller;

  const GroupFundScreen({
    super.key,
    required this.groupId,
    this.groupName,
    required this.repository,
    this.loadMembers,
    this.controller,
  });

  @override
  State<GroupFundScreen> createState() => _GroupFundScreenState();
}

class _GroupFundScreenState extends State<GroupFundScreen> {
  late final GroupFundController _controller;
  late final bool _ownsController;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? GroupFundController(widget.repository);
    _controller.load(widget.groupId);
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _showFailureSnackBar() {
    final failure = _controller.value.failure;
    if (failure != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _promptCreateFund() async {
    final nameCtrl = TextEditingController(text: 'Quỹ nhóm');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tạo quỹ nhóm'),
        content: TextField(
          key: const Key('create-fund-name-input'),
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Tên quỹ nhóm',
            hintText: 'Ví dụ: Quỹ hoạt động nhóm',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('confirm-create-fund-btn'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Khởi tạo quỹ'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final ok = await _controller.createFund(
        widget.groupId,
        name: nameCtrl.text,
      );
      if (!ok) _showFailureSnackBar();
    }
  }

  Future<void> _promptCloseFund(FundDetail fund) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đóng quỹ nhóm'),
        content: const Text(
          'Bạn có chắc chắn muốn đóng quỹ nhóm này? Sau khi đóng, lịch sử sổ quỹ vẫn được giữ nguyên.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('confirm-close-fund-btn'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Đóng quỹ'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final ok = await _controller.closeFund(widget.groupId, fund.fundId);
      if (!ok) _showFailureSnackBar();
    }
  }

  Future<void> _showManagersSheet(FundDetail fund) async {
    List<GroupMember> members = const [];
    if (widget.loadMembers != null) {
      try {
        members = await widget.loadMembers!();
      } catch (_) {}
    }
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return ValueListenableBuilder<GroupFundState>(
          valueListenable: _controller,
          builder: (context, state, _) {
            final currentFund = state.fund ?? fund;
            final managerIds = currentFund.managers
                .map((m) => m.user.userId)
                .toSet();
            final eligibleAdmins = members
                .where(
                  (m) =>
                      m.role == GroupRole.admin &&
                      !managerIds.contains(m.userId),
                )
                .toList();

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quản lý thủ quỹ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Trưởng nhóm (Owner) luôn có toàn quyền quản lý quỹ và có thể phân quyền Thủ quỹ cho Quản trị viên (Admin).',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (currentFund.managers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Chưa có Quản trị viên nào được phân quyền Thủ quỹ.',
                        ),
                      )
                    else
                      ...currentFund.managers.map(
                        (m) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.verified_user_outlined),
                          ),
                          title: Text(m.user.displayLabel),
                          subtitle: const Text('Thủ quỹ (Admin)'),
                          trailing: currentFund.permissions.canManageManagers
                              ? TextButton(
                                  onPressed: () async {
                                    final ok = await _controller.revokeManager(
                                      widget.groupId,
                                      currentFund.fundId,
                                      m.user.userId,
                                    );
                                    if (!ok) _showFailureSnackBar();
                                  },
                                  child: const Text('Thu hồi'),
                                )
                              : null,
                        ),
                      ),
                    if (currentFund.permissions.canManageManagers &&
                        eligibleAdmins.isNotEmpty) ...[
                      const Divider(height: 24),
                      const Text(
                        'Phân quyền cho Quản trị viên (Admin)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...eligibleAdmins.map(
                        (admin) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_outline),
                          ),
                          title: Text(admin.displayName),
                          subtitle: const Text('Quản trị viên (Admin)'),
                          trailing: FilledButton.tonal(
                            onPressed: () async {
                              final ok = await _controller.assignManager(
                                widget.groupId,
                                currentFund.fundId,
                                admin.userId,
                              );
                              if (!ok) _showFailureSnackBar();
                            },
                            child: const Text('Cấp quyền'),
                          ),
                        ),
                      ),
                    ],
                    if (currentFund.permissions.canCloseFund) ...[
                      const Divider(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const Key('sheet-close-fund-btn'),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _promptCloseFund(currentFund);
                          },
                          icon: const Icon(Icons.lock_outline),
                          label: const Text('Đóng quỹ nhóm'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _promptCreateCollection(FundDetail fund) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: '100000');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tạo đợt thu quỹ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('collection-title-input'),
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên đợt thu *',
                  hintText: 'Ví dụ: Thu quỹ tháng 10',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('collection-amount-input'),
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Mức đóng mỗi thành viên (VND) *',
                  hintText: '100000',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('collection-desc-input'),
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mô tả / Ghi chú',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('confirm-create-collection-btn'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Tạo đợt thu'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final parsedAmount = ExpenseMoney.parseInput(amountCtrl.text);
      if (titleCtrl.text.trim().isEmpty ||
          parsedAmount == null ||
          !parsedAmount.isPositive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng nhập tên đợt thu và số tiền hợp lệ.'),
          ),
        );
        return;
      }
      final ok = await _controller.createCollection(
        widget.groupId,
        fund.fundId,
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim(),
        allocationMode: 'EQUAL_PER_MEMBER',
        amountPerMember: parsedAmount.decimal,
      );
      if (!ok) {
        _showFailureSnackBar();
      } else {
        setState(() => _selectedTab = 0);
      }
    }
  }

  Future<void> _promptCreateFundExpense(FundDetail fund) async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ghi khoản chi từ quỹ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('fund-expense-title-input'),
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nội dung chi *',
                  hintText: 'Ví dụ: Mua nước suối sự kiện',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('fund-expense-amount-input'),
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Số tiền chi (VND) *',
                  helperText:
                      'Số dư khả dụng: ${fund.availableBalance.formatted}',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('fund-expense-note-input'),
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('confirm-create-fund-expense-btn'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ghi chi quỹ'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final parsedAmount = ExpenseMoney.parseInput(amountCtrl.text);
      if (titleCtrl.text.trim().isEmpty ||
          parsedAmount == null ||
          !parsedAmount.isPositive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng nhập nội dung chi và số tiền hợp lệ.'),
          ),
        );
        return;
      }
      final ok = await _controller.createFundExpense(
        widget.groupId,
        fund.fundId,
        title: titleCtrl.text.trim(),
        amount: parsedAmount.decimal,
        note: noteCtrl.text.trim(),
      );
      if (!ok) {
        _showFailureSnackBar();
      } else {
        setState(() => _selectedTab = 1);
      }
    }
  }

  Future<void> _promptCreateReimbursement(FundDetail fund) async {
    final reasonCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yêu cầu hoàn ứng từ quỹ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('reimbursement-reason-input'),
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Lý do hoàn ứng *',
                  hintText: 'Ví dụ: Ứng tiền mua đồ trang trí',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('reimbursement-amount-input'),
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Số tiền yêu cầu (VND) *',
                  helperText:
                      'Số dư khả dụng: ${fund.availableBalance.formatted}',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('confirm-create-reimbursement-btn'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Gửi yêu cầu'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final parsedAmount = ExpenseMoney.parseInput(amountCtrl.text);
      if (reasonCtrl.text.trim().isEmpty ||
          parsedAmount == null ||
          !parsedAmount.isPositive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng nhập lý do và số tiền hoàn ứng hợp lệ.'),
          ),
        );
        return;
      }
      final ok = await _controller.createReimbursement(
        widget.groupId,
        fund.fundId,
        amount: parsedAmount.decimal,
        reason: reasonCtrl.text.trim(),
      );
      if (!ok) {
        _showFailureSnackBar();
      } else {
        setState(() => _selectedTab = 2);
      }
    }
  }

  Future<void> _promptReverseTransaction(FundTransactionItem tx) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đảo bút toán giao dịch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Giao dịch: ${tx.typeLabel} (${tx.amount.formatted})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hệ thống sẽ tạo một giao dịch đảo đối ứng để điều chỉnh số dư sổ cái mà không xóa lịch sử.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('reverse-transaction-reason-input'),
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Lý do đảo bút toán *',
                hintText: 'Nhập lý do điều chỉnh',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('confirm-reverse-transaction-btn'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xác nhận đảo'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      if (reasonCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập lý do đảo bút toán.')),
        );
        return;
      }
      final ok = await _controller.reverseTransaction(
        widget.groupId,
        tx.transactionId,
        reason: reasonCtrl.text.trim(),
      );
      if (!ok) _showFailureSnackBar();
    }
  }

  Future<void> _showCollectionDetailSheet(String collectionId) async {
    await _controller.loadCollectionDetail(collectionId);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return ValueListenableBuilder<GroupFundState>(
          valueListenable: _controller,
          builder: (context, state, _) {
            final detail = state.activeCollectionDetail;
            if (detail == null || detail.collectionId != collectionId) {
              return const SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.82,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            detail.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _StatusBadge(label: detail.statusLabel),
                      ],
                    ),
                    if (detail.description?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text(
                        detail.description!,
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Đã xác nhận thu:'),
                              Text(
                                '${detail.totalConfirmedAmount.formatted} / ${detail.totalExpectedAmount.formatted}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Đang chờ duyệt:'),
                              Text(detail.totalPendingAmount.formatted),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Thành viên hoàn thành:'),
                              Text(
                                '${detail.paidMembersCount}/${detail.totalMembersCount} thành viên',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (detail.canContribute)
                          FilledButton.icon(
                            key: const Key('submit-contribution-btn'),
                            onPressed: () =>
                                _promptSubmitContribution(detail),
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Đóng quỹ'),
                          ),
                        if (detail.canManageCollection) ...[
                          OutlinedButton.icon(
                            key: const Key('close-collection-btn'),
                            onPressed: () async {
                              final ok = await _controller.closeCollection(
                                widget.groupId,
                                detail.collectionId,
                              );
                              if (!ok) _showFailureSnackBar();
                            },
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Đóng đợt thu'),
                          ),
                          OutlinedButton.icon(
                            key: const Key('cancel-collection-btn'),
                            onPressed: () async {
                              final ok = await _controller.cancelCollection(
                                widget.groupId,
                                detail.collectionId,
                              );
                              if (!ok) _showFailureSnackBar();
                            },
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Hủy đợt thu'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Nghĩa vụ đóng quỹ theo thành viên',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...detail.obligations.map(
                      (o) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            o.user.displayLabel,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Phải đóng: ${o.amountDue.formatted} • Đã duyệt: ${o.confirmedAmount.formatted}'
                            '${o.pendingAmount.isPositive ? ' • Chờ duyệt: ${o.pendingAmount.formatted}' : ''}'
                            ' • Còn lại: ${o.remainingAmount.formatted}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: _StatusBadge(label: o.statusLabel),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Các khoản đóng đã gửi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (detail.contributions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Chưa có khoản đóng quỹ nào được gửi.'),
                      )
                    else
                      ...detail.contributions.map(
                        (c) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${c.user.displayLabel} — ${c.amount.formatted}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    _StatusBadge(label: c.statusLabel),
                                  ],
                                ),
                                if (c.note?.trim().isNotEmpty == true) ...[
                                  const SizedBox(height: 4),
                                  Text('Ghi chú: ${c.note}'),
                                ],
                                if (c.rejectionReason?.trim().isNotEmpty ==
                                    true) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Lý do từ chối: ${c.rejectionReason}',
                                    style: const TextStyle(
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                                if (c.canConfirm ||
                                    c.canReject ||
                                    c.canCancel) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      if (c.canConfirm)
                                        FilledButton.tonal(
                                          key: Key(
                                            'confirm-contribution-${c.contributionId}',
                                          ),
                                          onPressed: () async {
                                            final ok = await _controller
                                                .confirmContribution(
                                                  widget.groupId,
                                                  detail.collectionId,
                                                  c.contributionId,
                                                );
                                            if (!ok) _showFailureSnackBar();
                                          },
                                          child: const Text('Xác nhận'),
                                        ),
                                      if (c.canReject)
                                        OutlinedButton(
                                          key: Key(
                                            'reject-contribution-${c.contributionId}',
                                          ),
                                          onPressed: () async {
                                            final ok = await _controller
                                                .rejectContribution(
                                                  widget.groupId,
                                                  detail.collectionId,
                                                  c.contributionId,
                                                  reason:
                                                      'Không khớp thông tin chuyển khoản',
                                                );
                                            if (!ok) _showFailureSnackBar();
                                          },
                                          child: const Text('Từ chối'),
                                        ),
                                      if (c.canCancel)
                                        TextButton(
                                          key: Key(
                                            'cancel-contribution-${c.contributionId}',
                                          ),
                                          onPressed: () async {
                                            final ok = await _controller
                                                .cancelContribution(
                                                  widget.groupId,
                                                  detail.collectionId,
                                                  c.contributionId,
                                                );
                                            if (!ok) _showFailureSnackBar();
                                          },
                                          child: const Text('Hủy'),
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _promptSubmitContribution(FundCollectionDetail detail) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Đóng quỹ: ${detail.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('contribution-amount-input'),
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Số tiền đóng (VND) *',
                hintText: 'Ví dụ: 100000',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('contribution-note-input'),
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Ghi chú chuyển khoản',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('confirm-submit-contribution-btn'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Gửi xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final parsedAmount = ExpenseMoney.parseInput(amountCtrl.text);
      if (parsedAmount == null || !parsedAmount.isPositive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập số tiền đóng hợp lệ.')),
        );
        return;
      }
      final ok = await _controller.submitContribution(
        widget.groupId,
        detail.collectionId,
        amount: parsedAmount.decimal,
        note: noteCtrl.text.trim(),
      );
      if (!ok) _showFailureSnackBar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.background,
        title: Text(
          widget.groupName?.trim().isNotEmpty == true
              ? 'Quỹ nhóm • ${widget.groupName}'
              : 'Quỹ nhóm',
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.load(widget.groupId),
          ),
        ],
      ),
      body: ValueListenableBuilder<GroupFundState>(
        valueListenable: _controller,
        builder: (context, state, _) {
          if (state.loading && state.fund == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.notCreatedYet && state.fund == null) {
            return _EmptyFundView(onCreateFund: _promptCreateFund);
          }
          final fund = state.fund;
          if (fund == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.failure?.message ??
                          'Không thể tải thông tin quỹ nhóm.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _controller.load(widget.groupId),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _controller.load(widget.groupId),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _FundHeroCard(
                  fund: fund,
                  onOpenManagers: () => _showManagersSheet(fund),
                  onCreateCollection: fund.permissions.canCreateCollection
                      ? () => _promptCreateCollection(fund)
                      : null,
                  onCreateExpense: fund.permissions.canRecordExpense
                      ? () => _promptCreateFundExpense(fund)
                      : null,
                  onCreateReimbursement:
                      fund.permissions.canRequestReimbursement
                      ? () => _promptCreateReimbursement(fund)
                      : null,
                  onCloseFund: fund.permissions.canCloseFund
                      ? () => _promptCloseFund(fund)
                      : null,
                  onReopenFund: !fund.isActive && fund.permissions.isOwner
                      ? _promptCreateFund
                      : null,
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _TabChip(
                        key: const Key('fund-tab-collections'),
                        label: 'Đợt thu (${state.collections.length})',
                        selected: _selectedTab == 0,
                        onTap: () => setState(() => _selectedTab = 0),
                      ),
                      const SizedBox(width: 8),
                      _TabChip(
                        key: const Key('fund-tab-expenses'),
                        label: 'Chi quỹ (${state.expenses.length})',
                        selected: _selectedTab == 1,
                        onTap: () => setState(() => _selectedTab = 1),
                      ),
                      const SizedBox(width: 8),
                      _TabChip(
                        key: const Key('fund-tab-reimbursements'),
                        label: 'Hoàn ứng (${state.reimbursements.length})',
                        selected: _selectedTab == 2,
                        onTap: () => setState(() => _selectedTab = 2),
                      ),
                      const SizedBox(width: 8),
                      _TabChip(
                        key: const Key('fund-tab-transactions'),
                        label: 'Sổ giao dịch (${state.transactions.length})',
                        selected: _selectedTab == 3,
                        onTap: () => setState(() => _selectedTab = 3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_selectedTab == 0) _buildCollectionsList(state.collections),
                if (_selectedTab == 1) _buildExpensesList(state.expenses),
                if (_selectedTab == 2)
                  _buildReimbursementsList(state.reimbursements),
                if (_selectedTab == 3)
                  _buildTransactionsList(state.transactions),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCollectionsList(List<FundCollectionSummary> items) {
    if (items.isEmpty) {
      return const _EmptySectionCard(
        icon: Icons.all_inbox_outlined,
        title: 'Chưa có đợt thu quỹ nào',
        subtitle:
            'Thủ quỹ hoặc Trưởng nhóm có thể tạo đợt thu để theo dõi nghĩa vụ đóng quỹ của từng thành viên.',
      );
    }
    return Column(
      children: items
          .map(
            (c) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _showCollectionDetailSheet(c.collectionId),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _StatusBadge(label: c.statusLabel),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Đã thu: ${c.totalConfirmedAmount.formatted} / ${c.totalExpectedAmount.formatted}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hoàn thành: ${c.paidMembersCount}/${c.totalMembersCount} thành viên'
                        '${c.pendingContributionsCount > 0 ? ' • ${c.pendingContributionsCount} khoản chờ duyệt' : ''}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      if (c.myObligationStatus != 'NONE') ...[
                        const SizedBox(height: 6),
                        Text(
                          'Phần của bạn: ${c.myConfirmedAmount.formatted}/${c.myAmountDue.formatted} (Còn lại: ${c.myRemainingAmount.formatted})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildExpensesList(List<FundExpenseItem> items) {
    if (items.isEmpty) {
      return const _EmptySectionCard(
        icon: Icons.receipt_long_outlined,
        title: 'Chưa có khoản chi trực tiếp từ quỹ',
        subtitle:
            'Các khoản chi trực tiếp từ quỹ sẽ tự động trừ vào số dư sổ cái.',
      );
    }
    return Column(
      children: items
          .map(
            (e) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.errorContainer,
                  child: const Icon(
                    Icons.call_made,
                    color: AppColors.error,
                  ),
                ),
                title: Text(
                  e.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    decoration: e.reversed ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Text(
                  'Người chi: ${e.createdBy.displayLabel}'
                  '${e.note?.trim().isNotEmpty == true ? ' • ${e.note}' : ''}'
                  '${e.reversed ? ' • [Đã đảo bút toán]' : ''}',
                ),
                trailing: Text(
                  '-${e.amount.formatted}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildReimbursementsList(List<FundReimbursementItem> items) {
    if (items.isEmpty) {
      return const _EmptySectionCard(
        icon: Icons.request_quote_outlined,
        title: 'Chưa có yêu cầu hoàn ứng nào',
        subtitle:
            'Thành viên ứng tiền chi cho nhóm có thể gửi yêu cầu hoàn ứng từ quỹ chung.',
      );
    }
    return Column(
      children: items
          .map(
            (r) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.reason,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _StatusBadge(label: r.statusLabel),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Người yêu cầu: ${r.user.displayLabel} • Số tiền: ${r.amount.formatted}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (r.rejectionReason?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Lý do từ chối: ${r.rejectionReason}',
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ],
                    if (r.canApprove || r.canReject || r.canCancel) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (r.canApprove)
                            FilledButton.tonal(
                              key: Key(
                                'approve-reimbursement-${r.reimbursementId}',
                              ),
                              onPressed: () async {
                                final ok = await _controller
                                    .approveReimbursement(
                                      widget.groupId,
                                      r.reimbursementId,
                                    );
                                if (!ok) _showFailureSnackBar();
                              },
                              child: const Text('Duyệt chi'),
                            ),
                          if (r.canReject)
                            OutlinedButton(
                              key: Key(
                                'reject-reimbursement-${r.reimbursementId}',
                              ),
                              onPressed: () async {
                                final ok = await _controller
                                    .rejectReimbursement(
                                      widget.groupId,
                                      r.reimbursementId,
                                      reason: 'Chưa đủ chứng từ hợp lệ',
                                    );
                                if (!ok) _showFailureSnackBar();
                              },
                              child: const Text('Từ chối'),
                            ),
                          if (r.canCancel)
                            TextButton(
                              key: Key(
                                'cancel-reimbursement-${r.reimbursementId}',
                              ),
                              onPressed: () async {
                                final ok = await _controller
                                    .cancelReimbursement(
                                      widget.groupId,
                                      r.reimbursementId,
                                    );
                                if (!ok) _showFailureSnackBar();
                              },
                              child: const Text('Hủy yêu cầu'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildTransactionsList(List<FundTransactionItem> items) {
    if (items.isEmpty) {
      return const _EmptySectionCard(
        icon: Icons.account_balance_outlined,
        title: 'Sổ giao dịch đang trống',
        subtitle:
            'Mọi bút toán thu quỹ, chi quỹ, hoàn ứng và đảo giao dịch đều được ghi nhận bất biến tại đây.',
      );
    }
    return Column(
      children: items
          .map(
            (tx) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          tx.isInflow
                              ? Icons.south_west_rounded
                              : Icons.north_east_rounded,
                          color: tx.isInflow ? Colors.green.shade700 : AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tx.typeLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              decoration: tx.reversed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        Text(
                          '${tx.isInflow ? '+' : '-'}${tx.amount.formatted}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: tx.isInflow
                                ? Colors.green.shade700
                                : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    if (tx.note?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text('Nội dung: ${tx.note}'),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Thực hiện bởi: ${tx.createdBy.displayLabel}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    if (tx.reversed) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Đã đảo bút toán${tx.reversalReason != null ? ': ${tx.reversalReason}' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (tx.canReverse) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          key: Key('reverse-tx-${tx.transactionId}'),
                          onPressed: () => _promptReverseTransaction(tx),
                          icon: const Icon(Icons.undo, size: 18),
                          label: const Text('Đảo bút toán'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _EmptyFundView extends StatelessWidget {
  final VoidCallback onCreateFund;

  const _EmptyFundView({required this.onCreateFund});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.savings_outlined,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nhóm chưa có quỹ chung',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Quỹ nhóm giúp quản lý các đợt thu tiền thành viên, chi trực tiếp từ quỹ, hoàn ứng và sổ cái giao dịch minh bạch.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('create-group-fund-btn'),
              onPressed: onCreateFund,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Tạo quỹ nhóm'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FundHeroCard extends StatelessWidget {
  final FundDetail fund;
  final VoidCallback onOpenManagers;
  final VoidCallback? onCreateCollection;
  final VoidCallback? onCreateExpense;
  final VoidCallback? onCreateReimbursement;
  final VoidCallback? onCloseFund;
  final VoidCallback? onReopenFund;

  const _FundHeroCard({
    required this.fund,
    required this.onOpenManagers,
    this.onCreateCollection,
    this.onCreateExpense,
    this.onCreateReimbursement,
    this.onCloseFund,
    this.onReopenFund,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: AppColors.softVioletShadow,
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  fund.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusBadge(label: fund.statusLabel),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'SỐ DƯ KHẢ DỤNG',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fund.availableBalance.formatted,
            key: const Key('fund-available-balance-text'),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Số dư sổ cái',
                  value: fund.ledgerBalance.formatted,
                ),
              ),
              Expanded(
                child: _MetricTile(
                  label: 'Tạm giữ hoàn ứng',
                  value: fund.pendingReimbursements.formatted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Tổng thu',
                  value: fund.totalInflow.formatted,
                ),
              ),
              Expanded(
                child: _MetricTile(
                  label: 'Tổng chi',
                  value: fund.totalOutflow.formatted,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onCreateCollection != null)
                FilledButton.tonalIcon(
                  key: const Key('open-create-collection-btn'),
                  onPressed: onCreateCollection,
                  icon: const Icon(Icons.campaign_outlined, size: 18),
                  label: const Text('Tạo đợt thu'),
                ),
              if (onCreateExpense != null)
                FilledButton.tonalIcon(
                  key: const Key('open-create-fund-expense-btn'),
                  onPressed: onCreateExpense,
                  icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                  label: const Text('Ghi chi quỹ'),
                ),
              if (onCreateReimbursement != null)
                FilledButton.tonalIcon(
                  key: const Key('open-create-reimbursement-btn'),
                  onPressed: onCreateReimbursement,
                  icon: const Icon(Icons.request_page_outlined, size: 18),
                  label: const Text('Hoàn ứng'),
                ),
              OutlinedButton.icon(
                key: const Key('open-fund-managers-btn'),
                onPressed: onOpenManagers,
                icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                label: Text('Thủ quỹ (${fund.managers.length})'),
              ),
              if (onCloseFund != null)
                OutlinedButton.icon(
                  key: const Key('hero-close-fund-btn'),
                  onPressed: onCloseFund,
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('Đóng quỹ'),
                ),
              if (onReopenFund != null)
                FilledButton.icon(
                  key: const Key('reopen-fund-btn'),
                  onPressed: onReopenFund,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Mở quỹ mới'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;

  const _StatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _EmptySectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptySectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
