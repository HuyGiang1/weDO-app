class FundMoney {
  final BigInt minorUnits;
  const FundMoney._(this.minorUnits);
  static final zero = FundMoney._(BigInt.zero);

  factory FundMoney.fromJson(Object? value) {
    if (value == null) return zero;
    final parsed = _parseDecimal(value.toString());
    if (parsed == null) {
      throw FormatException('Invalid monetary amount: $value');
    }
    return FundMoney._(parsed);
  }

  static FundMoney? parseInput(String value) {
    final normalized = value.trim().replaceAll(' ', '').replaceAll(',', '.');
    final match = RegExp(r'^(\d+)(?:\.(\d{0,2}))?$').firstMatch(normalized);
    if (match == null) return null;
    final major = BigInt.tryParse(match.group(1)!);
    if (major == null) return null;
    final fractional = (match.group(2) ?? '').padRight(2, '0');
    return FundMoney._(major * BigInt.from(100) + BigInt.parse(fractional));
  }

  static BigInt? _parseDecimal(String value) {
    final normalized = value.trim();
    final isNegative = normalized.startsWith('-');
    final unsigned = isNegative ? normalized.substring(1) : normalized;
    final match = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(unsigned);
    if (match == null) return null;
    final major = BigInt.tryParse(match.group(1)!);
    if (major == null) return null;
    final fraction = (match.group(2) ?? '').padRight(2, '0');
    if (fraction.length > 2 &&
        fraction.substring(2).split('').any((c) => c != '0')) {
      return null;
    }
    final absMinor =
        major * BigInt.from(100) + BigInt.parse(fraction.substring(0, 2));
    return isNegative ? -absMinor : absMinor;
  }

  String get decimal {
    final isNegative = minorUnits < BigInt.zero;
    final abs = isNegative ? -minorUnits : minorUnits;
    final sign = isNegative ? '-' : '';
    return '$sign${abs ~/ BigInt.from(100)}.${(abs % BigInt.from(100)).toString().padLeft(2, '0')}';
  }

  String get formatted {
    final isNegative = minorUnits < BigInt.zero;
    final abs = isNegative ? -minorUnits : minorUnits;
    final sign = isNegative ? '-' : '';
    final major = (abs ~/ BigInt.from(100)).toString();
    final grouped = major.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    final cents = (abs % BigInt.from(100)).toInt();
    return '$sign$grouped${cents == 0 ? '' : ',${cents.toString().padLeft(2, '0')}'} ₫';
  }

  bool get isPositive => minorUnits > BigInt.zero;
}

typedef ExpenseMoney = FundMoney;

class FundUserSummary {
  final String userId;
  final String displayName;
  final String? username;
  final String? avatarUrl;
  final String role;
  final bool activeMember;

  const FundUserSummary({
    required this.userId,
    required this.displayName,
    this.username,
    this.avatarUrl,
    this.role = 'MEMBER',
    this.activeMember = true,
  });

  factory FundUserSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const FundUserSummary(
        userId: '',
        displayName: 'Thành viên',
        activeMember: false,
      );
    }
    return FundUserSummary(
      userId: (json['userId'] ?? json['id'] ?? '').toString(),
      displayName: (json['displayName'] as String?)?.trim().isNotEmpty == true
          ? json['displayName'] as String
          : 'Thành viên',
      username: json['username'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      role: json['role'] as String? ?? 'MEMBER',
      activeMember: json['activeMember'] as bool? ?? true,
    );
  }

  String get displayLabel =>
      activeMember ? displayName : '$displayName (Cựu thành viên)';
}

class FundPermissionProjection {
  final bool isOwner;
  final bool isFundManager;
  final bool canManageFund;
  final bool canManageManagers;
  final bool canCloseFund;
  final bool canCreateCollection;
  final bool canRecordExpense;
  final bool canRequestReimbursement;
  final bool canSubmitContribution;

  const FundPermissionProjection({
    this.isOwner = false,
    this.isFundManager = false,
    this.canManageFund = false,
    this.canManageManagers = false,
    this.canCloseFund = false,
    this.canCreateCollection = false,
    this.canRecordExpense = false,
    this.canRequestReimbursement = false,
    this.canSubmitContribution = false,
  });

  factory FundPermissionProjection.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FundPermissionProjection();
    return FundPermissionProjection(
      isOwner: json['isOwner'] as bool? ?? false,
      isFundManager: json['isFundManager'] as bool? ?? false,
      canManageFund: json['canManageFund'] as bool? ?? false,
      canManageManagers: json['canManageManagers'] as bool? ?? false,
      canCloseFund: json['canCloseFund'] as bool? ?? false,
      canCreateCollection: json['canCreateCollection'] as bool? ?? false,
      canRecordExpense: json['canRecordExpense'] as bool? ?? false,
      canRequestReimbursement: json['canRequestReimbursement'] as bool? ?? false,
      canSubmitContribution: json['canSubmitContribution'] as bool? ?? false,
    );
  }
}

class FundManagerItem {
  final String id;
  final String fundId;
  final FundUserSummary user;
  final FundUserSummary assignedBy;
  final DateTime assignedAt;

  const FundManagerItem({
    required this.id,
    required this.fundId,
    required this.user,
    required this.assignedBy,
    required this.assignedAt,
  });

  factory FundManagerItem.fromJson(Map<String, dynamic> json) => FundManagerItem(
    id: json['id'] as String? ?? '',
    fundId: json['fundId'] as String? ?? '',
    user: FundUserSummary.fromJson(
      json['user'] is Map ? Map<String, dynamic>.from(json['user'] as Map) : null,
    ),
    assignedBy: FundUserSummary.fromJson(
      json['assignedBy'] is Map
          ? Map<String, dynamic>.from(json['assignedBy'] as Map)
          : null,
    ),
    assignedAt:
        DateTime.tryParse(json['assignedAt'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
  );
}

class FundDetail {
  final String fundId;
  final String groupId;
  final String name;
  final String status;
  final String currency;
  final ExpenseMoney ledgerBalance;
  final ExpenseMoney pendingReimbursements;
  final ExpenseMoney availableBalance;
  final ExpenseMoney totalInflow;
  final ExpenseMoney totalOutflow;
  final int openCollectionsCount;
  final int pendingContributionsCount;
  final int pendingReimbursementsCount;
  final List<FundManagerItem> managers;
  final FundPermissionProjection permissions;
  final FundUserSummary createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? closedAt;
  final FundUserSummary? closedBy;

  const FundDetail({
    required this.fundId,
    required this.groupId,
    required this.name,
    required this.status,
    this.currency = 'VND',
    required this.ledgerBalance,
    required this.pendingReimbursements,
    required this.availableBalance,
    required this.totalInflow,
    required this.totalOutflow,
    this.openCollectionsCount = 0,
    this.pendingContributionsCount = 0,
    this.pendingReimbursementsCount = 0,
    this.managers = const [],
    this.permissions = const FundPermissionProjection(),
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.closedAt,
    this.closedBy,
  });

  bool get isActive => status == 'ACTIVE';

  String get statusLabel => isActive ? 'Đang hoạt động' : 'Đã đóng';

  factory FundDetail.fromJson(Map<String, dynamic> json) => FundDetail(
    fundId: json['fundId'] as String? ?? '',
    groupId: json['groupId'] as String? ?? '',
    name: json['name'] as String? ?? 'Quỹ nhóm',
    status: json['status'] as String? ?? 'ACTIVE',
    currency: json['currency'] as String? ?? 'VND',
    ledgerBalance: ExpenseMoney.fromJson(json['ledgerBalance']),
    pendingReimbursements: ExpenseMoney.fromJson(json['pendingReimbursements']),
    availableBalance: ExpenseMoney.fromJson(json['availableBalance']),
    totalInflow: ExpenseMoney.fromJson(json['totalInflow']),
    totalOutflow: ExpenseMoney.fromJson(json['totalOutflow']),
    openCollectionsCount: (json['openCollectionsCount'] as num?)?.toInt() ?? 0,
    pendingContributionsCount:
        (json['pendingContributionsCount'] as num?)?.toInt() ?? 0,
    pendingReimbursementsCount:
        (json['pendingReimbursementsCount'] as num?)?.toInt() ?? 0,
    managers: ((json['managers'] as List?) ?? const [])
        .map((e) => FundManagerItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    permissions: FundPermissionProjection.fromJson(
      json['permissions'] is Map
          ? Map<String, dynamic>.from(json['permissions'] as Map)
          : null,
    ),
    createdBy: FundUserSummary.fromJson(
      json['createdBy'] is Map
          ? Map<String, dynamic>.from(json['createdBy'] as Map)
          : null,
    ),
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
    closedAt: json['closedAt'] == null
        ? null
        : DateTime.tryParse(json['closedAt'] as String)?.toLocal(),
    closedBy: json['closedBy'] is Map
        ? FundUserSummary.fromJson(
            Map<String, dynamic>.from(json['closedBy'] as Map),
          )
        : null,
  );
}

class CollectionObligationItem {
  final String obligationId;
  final String collectionId;
  final FundUserSummary user;
  final ExpenseMoney amountDue;
  final ExpenseMoney confirmedAmount;
  final ExpenseMoney pendingAmount;
  final ExpenseMoney remainingAmount;
  final String status;
  final DateTime createdAt;

  const CollectionObligationItem({
    required this.obligationId,
    required this.collectionId,
    required this.user,
    required this.amountDue,
    required this.confirmedAmount,
    required this.pendingAmount,
    required this.remainingAmount,
    required this.status,
    required this.createdAt,
  });

  String get statusLabel {
    switch (status) {
      case 'PAID':
        return 'Đã đóng đủ';
      case 'PARTIAL':
        return 'Đóng một phần';
      case 'OVERDUE':
        return 'Quá hạn';
      default:
        return 'Chưa đóng';
    }
  }

  factory CollectionObligationItem.fromJson(Map<String, dynamic> json) =>
      CollectionObligationItem(
        obligationId: json['obligationId'] as String? ?? '',
        collectionId: json['collectionId'] as String? ?? '',
        user: FundUserSummary.fromJson(
          json['user'] is Map
              ? Map<String, dynamic>.from(json['user'] as Map)
              : null,
        ),
        amountDue: ExpenseMoney.fromJson(json['amountDue']),
        confirmedAmount: ExpenseMoney.fromJson(json['confirmedAmount']),
        pendingAmount: ExpenseMoney.fromJson(json['pendingAmount']),
        remainingAmount: ExpenseMoney.fromJson(json['remainingAmount']),
        status: json['status'] as String? ?? 'UNPAID',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      );
}

class FundContributionItem {
  final String contributionId;
  final String fundId;
  final String collectionId;
  final String collectionTitle;
  final FundUserSummary user;
  final ExpenseMoney amount;
  final String status;
  final String? proofStorageKey;
  final String? note;
  final DateTime paymentTime;
  final FundUserSummary? confirmedBy;
  final DateTime? confirmedAt;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool canConfirm;
  final bool canReject;
  final bool canCancel;

  const FundContributionItem({
    required this.contributionId,
    required this.fundId,
    required this.collectionId,
    required this.collectionTitle,
    required this.user,
    required this.amount,
    required this.status,
    this.proofStorageKey,
    this.note,
    required this.paymentTime,
    this.confirmedBy,
    this.confirmedAt,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
    this.canConfirm = false,
    this.canReject = false,
    this.canCancel = false,
  });

  String get statusLabel {
    switch (status) {
      case 'CONFIRMED':
        return 'Đã xác nhận';
      case 'REJECTED':
        return 'Đã từ chối';
      case 'CANCELLED':
        return 'Đã hủy';
      default:
        return 'Chờ xác nhận';
    }
  }

  factory FundContributionItem.fromJson(Map<String, dynamic> json) =>
      FundContributionItem(
        contributionId: json['contributionId'] as String? ?? '',
        fundId: json['fundId'] as String? ?? '',
        collectionId: json['collectionId'] as String? ?? '',
        collectionTitle: json['collectionTitle'] as String? ?? '',
        user: FundUserSummary.fromJson(
          json['user'] is Map
              ? Map<String, dynamic>.from(json['user'] as Map)
              : null,
        ),
        amount: ExpenseMoney.fromJson(json['amount']),
        status: json['status'] as String? ?? 'PENDING',
        proofStorageKey: json['proofStorageKey'] as String?,
        note: json['note'] as String?,
        paymentTime:
            DateTime.tryParse(json['paymentTime'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        confirmedBy: json['confirmedBy'] is Map
            ? FundUserSummary.fromJson(
                Map<String, dynamic>.from(json['confirmedBy'] as Map),
              )
            : null,
        confirmedAt: json['confirmedAt'] == null
            ? null
            : DateTime.tryParse(json['confirmedAt'] as String)?.toLocal(),
        rejectionReason: json['rejectionReason'] as String?,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        updatedAt:
            DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        canConfirm: json['canConfirm'] as bool? ?? false,
        canReject: json['canReject'] as bool? ?? false,
        canCancel: json['canCancel'] as bool? ?? false,
      );
}

class FundCollectionSummary {
  final String collectionId;
  final String fundId;
  final String title;
  final String? description;
  final DateTime? deadlineAt;
  final String status;
  final ExpenseMoney totalExpectedAmount;
  final ExpenseMoney totalConfirmedAmount;
  final ExpenseMoney totalPendingAmount;
  final ExpenseMoney totalRemainingAmount;
  final int totalMembersCount;
  final int paidMembersCount;
  final int pendingContributionsCount;
  final ExpenseMoney myAmountDue;
  final ExpenseMoney myConfirmedAmount;
  final ExpenseMoney myPendingAmount;
  final ExpenseMoney myRemainingAmount;
  final String myObligationStatus;
  final FundUserSummary createdBy;
  final DateTime createdAt;

  const FundCollectionSummary({
    required this.collectionId,
    required this.fundId,
    required this.title,
    this.description,
    this.deadlineAt,
    required this.status,
    required this.totalExpectedAmount,
    required this.totalConfirmedAmount,
    required this.totalPendingAmount,
    required this.totalRemainingAmount,
    this.totalMembersCount = 0,
    this.paidMembersCount = 0,
    this.pendingContributionsCount = 0,
    required this.myAmountDue,
    required this.myConfirmedAmount,
    required this.myPendingAmount,
    required this.myRemainingAmount,
    this.myObligationStatus = 'NONE',
    required this.createdBy,
    required this.createdAt,
  });

  String get statusLabel {
    switch (status) {
      case 'CLOSED':
        return 'Đã đóng';
      case 'CANCELLED':
        return 'Đã hủy';
      default:
        return 'Đang mở';
    }
  }

  factory FundCollectionSummary.fromJson(Map<String, dynamic> json) =>
      FundCollectionSummary(
        collectionId: json['collectionId'] as String? ?? '',
        fundId: json['fundId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        deadlineAt: json['deadlineAt'] == null
            ? null
            : DateTime.tryParse(json['deadlineAt'] as String)?.toLocal(),
        status: json['status'] as String? ?? 'OPEN',
        totalExpectedAmount: ExpenseMoney.fromJson(json['totalExpectedAmount']),
        totalConfirmedAmount: ExpenseMoney.fromJson(
          json['totalConfirmedAmount'],
        ),
        totalPendingAmount: ExpenseMoney.fromJson(json['totalPendingAmount']),
        totalRemainingAmount: ExpenseMoney.fromJson(
          json['totalRemainingAmount'],
        ),
        totalMembersCount: (json['totalMembersCount'] as num?)?.toInt() ?? 0,
        paidMembersCount: (json['paidMembersCount'] as num?)?.toInt() ?? 0,
        pendingContributionsCount:
            (json['pendingContributionsCount'] as num?)?.toInt() ?? 0,
        myAmountDue: ExpenseMoney.fromJson(json['myAmountDue']),
        myConfirmedAmount: ExpenseMoney.fromJson(json['myConfirmedAmount']),
        myPendingAmount: ExpenseMoney.fromJson(json['myPendingAmount']),
        myRemainingAmount: ExpenseMoney.fromJson(json['myRemainingAmount']),
        myObligationStatus: json['myObligationStatus'] as String? ?? 'NONE',
        createdBy: FundUserSummary.fromJson(
          json['createdBy'] is Map
              ? Map<String, dynamic>.from(json['createdBy'] as Map)
              : null,
        ),
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      );
}

class FundCollectionDetail {
  final String collectionId;
  final String fundId;
  final String title;
  final String? description;
  final DateTime? deadlineAt;
  final String status;
  final ExpenseMoney totalExpectedAmount;
  final ExpenseMoney totalConfirmedAmount;
  final ExpenseMoney totalPendingAmount;
  final ExpenseMoney totalRemainingAmount;
  final int totalMembersCount;
  final int paidMembersCount;
  final int pendingContributionsCount;
  final List<CollectionObligationItem> obligations;
  final List<FundContributionItem> contributions;
  final FundUserSummary createdBy;
  final DateTime createdAt;
  final bool canManageCollection;
  final bool canContribute;

  const FundCollectionDetail({
    required this.collectionId,
    required this.fundId,
    required this.title,
    this.description,
    this.deadlineAt,
    required this.status,
    required this.totalExpectedAmount,
    required this.totalConfirmedAmount,
    required this.totalPendingAmount,
    required this.totalRemainingAmount,
    this.totalMembersCount = 0,
    this.paidMembersCount = 0,
    this.pendingContributionsCount = 0,
    this.obligations = const [],
    this.contributions = const [],
    required this.createdBy,
    required this.createdAt,
    this.canManageCollection = false,
    this.canContribute = false,
  });

  String get statusLabel {
    switch (status) {
      case 'CLOSED':
        return 'Đã đóng';
      case 'CANCELLED':
        return 'Đã hủy';
      default:
        return 'Đang mở';
    }
  }

  factory FundCollectionDetail.fromJson(Map<String, dynamic> json) =>
      FundCollectionDetail(
        collectionId: json['collectionId'] as String? ?? '',
        fundId: json['fundId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        deadlineAt: json['deadlineAt'] == null
            ? null
            : DateTime.tryParse(json['deadlineAt'] as String)?.toLocal(),
        status: json['status'] as String? ?? 'OPEN',
        totalExpectedAmount: ExpenseMoney.fromJson(json['totalExpectedAmount']),
        totalConfirmedAmount: ExpenseMoney.fromJson(
          json['totalConfirmedAmount'],
        ),
        totalPendingAmount: ExpenseMoney.fromJson(json['totalPendingAmount']),
        totalRemainingAmount: ExpenseMoney.fromJson(
          json['totalRemainingAmount'],
        ),
        totalMembersCount: (json['totalMembersCount'] as num?)?.toInt() ?? 0,
        paidMembersCount: (json['paidMembersCount'] as num?)?.toInt() ?? 0,
        pendingContributionsCount:
            (json['pendingContributionsCount'] as num?)?.toInt() ?? 0,
        obligations: ((json['obligations'] as List?) ?? const [])
            .map(
              (e) => CollectionObligationItem.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
        contributions: ((json['contributions'] as List?) ?? const [])
            .map(
              (e) => FundContributionItem.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
        createdBy: FundUserSummary.fromJson(
          json['createdBy'] is Map
              ? Map<String, dynamic>.from(json['createdBy'] as Map)
              : null,
        ),
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        canManageCollection: json['canManageCollection'] as bool? ?? false,
        canContribute: json['canContribute'] as bool? ?? false,
      );
}

class FundExpenseItem {
  final String expenseId;
  final String fundId;
  final String? activityId;
  final String? activityTitle;
  final String title;
  final ExpenseMoney amount;
  final DateTime occurredAt;
  final String? receiptStorageKey;
  final String? note;
  final String? transactionId;
  final bool reversed;
  final FundUserSummary createdBy;
  final DateTime createdAt;

  const FundExpenseItem({
    required this.expenseId,
    required this.fundId,
    this.activityId,
    this.activityTitle,
    required this.title,
    required this.amount,
    required this.occurredAt,
    this.receiptStorageKey,
    this.note,
    this.transactionId,
    this.reversed = false,
    required this.createdBy,
    required this.createdAt,
  });

  factory FundExpenseItem.fromJson(Map<String, dynamic> json) => FundExpenseItem(
    expenseId: json['expenseId'] as String? ?? '',
    fundId: json['fundId'] as String? ?? '',
    activityId: json['activityId'] as String?,
    activityTitle: json['activityTitle'] as String?,
    title: json['title'] as String? ?? '',
    amount: ExpenseMoney.fromJson(json['amount']),
    occurredAt:
        DateTime.tryParse(json['occurredAt'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
    receiptStorageKey: json['receiptStorageKey'] as String?,
    note: json['note'] as String?,
    transactionId: json['transactionId'] as String?,
    reversed: json['reversed'] as bool? ?? false,
    createdBy: FundUserSummary.fromJson(
      json['createdBy'] is Map
          ? Map<String, dynamic>.from(json['createdBy'] as Map)
          : null,
    ),
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
  );
}

class FundReimbursementItem {
  final String reimbursementId;
  final String fundId;
  final FundUserSummary user;
  final ExpenseMoney amount;
  final String reason;
  final String? receiptStorageKey;
  final String status;
  final FundUserSummary? resolvedBy;
  final DateTime? resolvedAt;
  final String? rejectionReason;
  final String? transactionId;
  final bool reversed;
  final DateTime createdAt;
  final bool canApprove;
  final bool canReject;
  final bool canCancel;

  const FundReimbursementItem({
    required this.reimbursementId,
    required this.fundId,
    required this.user,
    required this.amount,
    required this.reason,
    this.receiptStorageKey,
    required this.status,
    this.resolvedBy,
    this.resolvedAt,
    this.rejectionReason,
    this.transactionId,
    this.reversed = false,
    required this.createdAt,
    this.canApprove = false,
    this.canReject = false,
    this.canCancel = false,
  });

  String get statusLabel {
    switch (status) {
      case 'COMPLETED':
        return 'Đã hoàn ứng';
      case 'REJECTED':
        return 'Đã từ chối';
      case 'CANCELLED':
        return 'Đã hủy';
      default:
        return 'Chờ duyệt';
    }
  }

  factory FundReimbursementItem.fromJson(Map<String, dynamic> json) =>
      FundReimbursementItem(
        reimbursementId: json['reimbursementId'] as String? ?? '',
        fundId: json['fundId'] as String? ?? '',
        user: FundUserSummary.fromJson(
          json['user'] is Map
              ? Map<String, dynamic>.from(json['user'] as Map)
              : null,
        ),
        amount: ExpenseMoney.fromJson(json['amount']),
        reason: json['reason'] as String? ?? '',
        receiptStorageKey: json['receiptStorageKey'] as String?,
        status: json['status'] as String? ?? 'PENDING',
        resolvedBy: json['resolvedBy'] is Map
            ? FundUserSummary.fromJson(
                Map<String, dynamic>.from(json['resolvedBy'] as Map),
              )
            : null,
        resolvedAt: json['resolvedAt'] == null
            ? null
            : DateTime.tryParse(json['resolvedAt'] as String)?.toLocal(),
        rejectionReason: json['rejectionReason'] as String?,
        transactionId: json['transactionId'] as String?,
        reversed: json['reversed'] as bool? ?? false,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        canApprove: json['canApprove'] as bool? ?? false,
        canReject: json['canReject'] as bool? ?? false,
        canCancel: json['canCancel'] as bool? ?? false,
      );
}

class FundTransactionItem {
  final String transactionId;
  final String fundId;
  final String transactionType;
  final String direction;
  final ExpenseMoney amount;
  final String? referenceType;
  final String? referenceId;
  final String referenceTitle;
  final String? note;
  final FundUserSummary createdBy;
  final DateTime createdAt;
  final bool reversed;
  final String? reversalTransactionId;
  final String? reversalReason;
  final FundUserSummary? reversedBy;
  final DateTime? reversedAt;
  final String? originalTransactionId;
  final bool canReverse;

  const FundTransactionItem({
    required this.transactionId,
    required this.fundId,
    required this.transactionType,
    required this.direction,
    required this.amount,
    this.referenceType,
    this.referenceId,
    required this.referenceTitle,
    this.note,
    required this.createdBy,
    required this.createdAt,
    this.reversed = false,
    this.reversalTransactionId,
    this.reversalReason,
    this.reversedBy,
    this.reversedAt,
    this.originalTransactionId,
    this.canReverse = false,
  });

  bool get isInflow => direction == 'IN';

  String get typeLabel {
    switch (transactionType) {
      case 'CONTRIBUTION':
        return 'Thu quỹ thành viên';
      case 'FUND_EXPENSE':
        return 'Chi trực tiếp từ quỹ';
      case 'REIMBURSEMENT':
        return 'Hoàn ứng từ quỹ';
      case 'REVERSAL':
        return 'Giao dịch đảo bút toán';
      default:
        return referenceTitle;
    }
  }

  factory FundTransactionItem.fromJson(Map<String, dynamic> json) =>
      FundTransactionItem(
        transactionId: json['transactionId'] as String? ?? '',
        fundId: json['fundId'] as String? ?? '',
        transactionType: json['transactionType'] as String? ?? '',
        direction: json['direction'] as String? ?? 'IN',
        amount: ExpenseMoney.fromJson(json['amount']),
        referenceType: json['referenceType'] as String?,
        referenceId: json['referenceId'] as String?,
        referenceTitle: json['referenceTitle'] as String? ?? '',
        note: json['note'] as String?,
        createdBy: FundUserSummary.fromJson(
          json['createdBy'] is Map
              ? Map<String, dynamic>.from(json['createdBy'] as Map)
              : null,
        ),
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        reversed: json['reversed'] as bool? ?? false,
        reversalTransactionId: json['reversalTransactionId'] as String?,
        reversalReason: json['reversalReason'] as String?,
        reversedBy: json['reversedBy'] is Map
            ? FundUserSummary.fromJson(
                Map<String, dynamic>.from(json['reversedBy'] as Map),
              )
            : null,
        reversedAt: json['reversedAt'] == null
            ? null
            : DateTime.tryParse(json['reversedAt'] as String)?.toLocal(),
        originalTransactionId: json['originalTransactionId'] as String?,
        canReverse: json['canReverse'] as bool? ?? false,
      );
}

class FundOverview {
  final FundDetail fund;
  final List<FundCollectionSummary> openCollections;
  final List<FundTransactionItem> recentTransactions;
  final List<FundReimbursementItem> pendingReimbursements;
  final List<FundExpenseItem> recentExpenses;

  const FundOverview({
    required this.fund,
    this.openCollections = const [],
    this.recentTransactions = const [],
    this.pendingReimbursements = const [],
    this.recentExpenses = const [],
  });

  factory FundOverview.fromJson(Map<String, dynamic> json) => FundOverview(
    fund: FundDetail.fromJson(Map<String, dynamic>.from(json['fund'] as Map)),
    openCollections: ((json['openCollections'] as List?) ?? const [])
        .map(
          (e) => FundCollectionSummary.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList(),
    recentTransactions: ((json['recentTransactions'] as List?) ?? const [])
        .map(
          (e) => FundTransactionItem.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList(),
    pendingReimbursements:
        ((json['pendingReimbursements'] as List?) ?? const [])
            .map(
              (e) => FundReimbursementItem.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
    recentExpenses: ((json['recentExpenses'] as List?) ?? const [])
        .map(
          (e) => FundExpenseItem.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
  );
}
