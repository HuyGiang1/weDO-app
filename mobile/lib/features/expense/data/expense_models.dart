class ExpenseMoney {
  final BigInt minorUnits;
  const ExpenseMoney._(this.minorUnits);
  static final zero = ExpenseMoney._(BigInt.zero);

  factory ExpenseMoney.fromJson(Object? value) {
    if (value == null) return zero;
    final parsed = _parseDecimal(value.toString());
    if (parsed == null) {
      throw FormatException('Invalid monetary amount: $value');
    }
    return ExpenseMoney._(parsed);
  }

  static ExpenseMoney? parseInput(String value) {
    final normalized = value.trim().replaceAll(' ', '').replaceAll(',', '.');
    final match = RegExp(r'^(\d+)(?:\.(\d{0,2}))?$').firstMatch(normalized);
    if (match == null) return null;
    final major = BigInt.tryParse(match.group(1)!);
    if (major == null) return null;
    final fractional = (match.group(2) ?? '').padRight(2, '0');
    return ExpenseMoney._(major * BigInt.from(100) + BigInt.parse(fractional));
  }

  static BigInt? _parseDecimal(String value) {
    final match = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(value);
    if (match == null) return null;
    final major = BigInt.tryParse(match.group(1)!);
    if (major == null) return null;
    final fraction = (match.group(2) ?? '').padRight(2, '0');
    if (fraction.length > 2 &&
        fraction.substring(2).split('').any((c) => c != '0')) {
      return null;
    }
    return major * BigInt.from(100) + BigInt.parse(fraction.substring(0, 2));
  }

  String get decimal =>
      '${minorUnits ~/ BigInt.from(100)}.${(minorUnits % BigInt.from(100)).toString().padLeft(2, '0')}';

  String get formatted {
    final major = (minorUnits ~/ BigInt.from(100)).toString();
    final grouped = major.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    final cents = (minorUnits % BigInt.from(100)).toInt();
    return '$grouped${cents == 0 ? '' : ',${cents.toString().padLeft(2, '0')}'} ₫';
  }

  bool get isPositive => minorUnits > BigInt.zero;
}

class ExpenseUser {
  final String id;
  final String displayName;
  final String? avatarStorageKey;
  const ExpenseUser({
    required this.id,
    required this.displayName,
    this.avatarStorageKey,
  });
  factory ExpenseUser.fromJson(Map<String, dynamic> json) => ExpenseUser(
    id: json['id'] as String,
    displayName: json['displayName'] as String? ?? 'Người dùng',
    avatarStorageKey: json['avatarStorageKey'] as String?,
  );
}

class ExpensePermissions {
  final bool canEdit;
  final bool canCancel;
  const ExpensePermissions({required this.canEdit, required this.canCancel});
  factory ExpensePermissions.fromJson(Map<String, dynamic>? json) =>
      ExpensePermissions(
        canEdit: json?['canEdit'] as bool? ?? false,
        canCancel: json?['canCancel'] as bool? ?? false,
      );
}

class ExpenseShare {
  final String userId;
  final String displayName;
  final String? avatarStorageKey;
  final ExpenseMoney amount;
  const ExpenseShare({
    required this.userId,
    required this.displayName,
    this.avatarStorageKey,
    required this.amount,
  });
  factory ExpenseShare.fromJson(Map<String, dynamic> json) => ExpenseShare(
    userId: json['userId'] as String,
    displayName: json['displayName'] as String? ?? 'Người dùng',
    avatarStorageKey: json['avatarStorageKey'] as String?,
    amount: ExpenseMoney.fromJson(json['amount']),
  );
}

class ExpenseChange {
  final String fieldName;
  final String? oldValue;
  final String? newValue;
  final DateTime createdAt;
  const ExpenseChange({
    required this.fieldName,
    this.oldValue,
    this.newValue,
    required this.createdAt,
  });
  factory ExpenseChange.fromJson(Map<String, dynamic> json) => ExpenseChange(
    fieldName: json['fieldName'] as String,
    oldValue: json['oldValue'] as String?,
    newValue: json['newValue'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class ExpenseSummary {
  final String id;
  final String groupId;
  final String title;
  final ExpenseMoney amount;
  final String splitMethod;
  final String status;
  final DateTime occurredAt;
  final ExpenseUser payer;
  final ExpenseUser? creator;
  final int participantCount;
  final ExpensePermissions permissions;
  const ExpenseSummary({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amount,
    required this.splitMethod,
    required this.status,
    required this.occurredAt,
    required this.payer,
    this.creator,
    required this.participantCount,
    required this.permissions,
  });
  factory ExpenseSummary.fromJson(Map<String, dynamic> json) => ExpenseSummary(
    id: json['id'] as String,
    groupId: json['groupId'] as String,
    title: json['title'] as String,
    amount: ExpenseMoney.fromJson(json['amount']),
    splitMethod: json['splitMethod'] as String,
    status: json['status'] as String,
    occurredAt: DateTime.parse(json['occurredAt'] as String),
    payer: ExpenseUser.fromJson(
      Map<String, dynamic>.from(json['payer'] as Map),
    ),
    creator: json['creator'] == null
        ? null
        : ExpenseUser.fromJson(
            Map<String, dynamic>.from(json['creator'] as Map),
          ),
    participantCount: json['participantCount'] as int,
    permissions: ExpensePermissions.fromJson(
      json['permissions'] is Map
          ? Map<String, dynamic>.from(json['permissions'] as Map)
          : null,
    ),
  );
}

class ExpenseDetail extends ExpenseSummary {
  final String? activityId;
  final String? note;
  final List<ExpenseShare> shares;
  final List<ExpenseChange> changeHistory;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ExpenseDetail({
    required super.id,
    required super.groupId,
    required super.title,
    required super.amount,
    required super.splitMethod,
    required super.status,
    required super.occurredAt,
    required super.payer,
    super.creator,
    required super.participantCount,
    required super.permissions,
    this.activityId,
    this.note,
    required this.shares,
    required this.changeHistory,
    required this.createdAt,
    required this.updatedAt,
  });
  factory ExpenseDetail.fromJson(Map<String, dynamic> json) => ExpenseDetail(
    id: json['id'] as String,
    groupId: json['groupId'] as String,
    title: json['title'] as String,
    amount: ExpenseMoney.fromJson(json['amount']),
    splitMethod: json['splitMethod'] as String,
    status: json['status'] as String,
    occurredAt: DateTime.parse(json['occurredAt'] as String),
    payer: ExpenseUser.fromJson(
      Map<String, dynamic>.from(json['payer'] as Map),
    ),
    creator: json['creator'] == null
        ? null
        : ExpenseUser.fromJson(
            Map<String, dynamic>.from(json['creator'] as Map),
          ),
    participantCount: (json['shares'] as List? ?? const []).length,
    permissions: ExpensePermissions.fromJson(
      json['permissions'] is Map
          ? Map<String, dynamic>.from(json['permissions'] as Map)
          : null,
    ),
    activityId: json['activityId'] as String?,
    note: json['note'] as String?,
    shares: (json['shares'] as List? ?? const [])
        .map((v) => ExpenseShare.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList(),
    changeHistory: (json['changeHistory'] as List? ?? const [])
        .map((v) => ExpenseChange.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}

class ExpenseBalanceEntry {
  final ExpenseUser user;
  final String direction;
  final ExpenseMoney amount;
  const ExpenseBalanceEntry({
    required this.user,
    required this.direction,
    required this.amount,
  });
  factory ExpenseBalanceEntry.fromJson(Map<String, dynamic> json) =>
      ExpenseBalanceEntry(
        user: ExpenseUser.fromJson(
          Map<String, dynamic>.from(json['user'] as Map),
        ),
        direction: json['direction'] as String,
        amount: ExpenseMoney.fromJson(json['amount']),
      );
}

class MyExpenseBalances {
  final ExpenseMoney totalOwedByMe;
  final ExpenseMoney totalOwedToMe;
  final List<ExpenseBalanceEntry> balances;
  const MyExpenseBalances({
    required this.totalOwedByMe,
    required this.totalOwedToMe,
    required this.balances,
  });
  factory MyExpenseBalances.fromJson(Map<String, dynamic> json) =>
      MyExpenseBalances(
        totalOwedByMe: ExpenseMoney.fromJson(json['totalOwedByMe']),
        totalOwedToMe: ExpenseMoney.fromJson(json['totalOwedToMe']),
        balances: (json['balances'] as List? ?? const [])
            .map(
              (v) => ExpenseBalanceEntry.fromJson(
                Map<String, dynamic>.from(v as Map),
              ),
            )
            .toList(),
      );
}

class ExpenseDraft {
  final String title;
  final ExpenseMoney amount;
  final String payerUserId;
  final String splitMethod;
  final List<String> participantUserIds;
  final Map<String, ExpenseMoney> customShares;
  final String? activityId;
  final DateTime occurredAt;
  final String? note;
  const ExpenseDraft({
    required this.title,
    required this.amount,
    required this.payerUserId,
    required this.splitMethod,
    required this.participantUserIds,
    required this.customShares,
    this.activityId,
    required this.occurredAt,
    this.note,
  });
  Map<String, dynamic> toJson() => {
    'title': title,
    'amount': amount.decimal,
    'payerUserId': payerUserId,
    'splitMethod': splitMethod,
    if (splitMethod == 'EQUAL') 'participantUserIds': participantUserIds,
    if (splitMethod == 'CUSTOM_AMOUNT')
      'shares': customShares.entries
          .map((e) => {'userId': e.key, 'amount': e.value.decimal})
          .toList(),
    'activityId': activityId,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'note': note,
  };
}

class SettlementPermissions {
  final bool canConfirm;
  final bool canReject;
  final bool canCancel;
  const SettlementPermissions({
    required this.canConfirm,
    required this.canReject,
    required this.canCancel,
  });
  factory SettlementPermissions.fromJson(Map<String, dynamic>? json) =>
      SettlementPermissions(
        canConfirm: json?['canConfirm'] as bool? ?? false,
        canReject: json?['canReject'] as bool? ?? false,
        canCancel: json?['canCancel'] as bool? ?? false,
      );
}

class SettlementStatusChange {
  final String? fromStatus;
  final String toStatus;
  final ExpenseUser? changedBy;
  final DateTime createdAt;
  const SettlementStatusChange({
    this.fromStatus,
    required this.toStatus,
    this.changedBy,
    required this.createdAt,
  });
  factory SettlementStatusChange.fromJson(Map<String, dynamic> json) =>
      SettlementStatusChange(
        fromStatus: json['fromStatus'] as String?,
        toStatus: json['toStatus'] as String,
        changedBy: json['changedBy'] is Map
            ? ExpenseUser.fromJson(
                Map<String, dynamic>.from(json['changedBy'] as Map),
              )
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class SettlementItem {
  final String id;
  final String groupId;
  final ExpenseUser fromUser;
  final ExpenseUser toUser;
  final ExpenseUser createdBy;
  final ExpenseMoney amount;
  final String status;
  final String declarationType;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SettlementStatusChange> statusHistory;
  final SettlementPermissions permissions;
  const SettlementItem({
    required this.id,
    required this.groupId,
    required this.fromUser,
    required this.toUser,
    required this.createdBy,
    required this.amount,
    required this.status,
    required this.declarationType,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.statusHistory,
    required this.permissions,
  });
  factory SettlementItem.fromJson(Map<String, dynamic> json) => SettlementItem(
    id: json['id'] as String,
    groupId: json['groupId'] as String,
    fromUser: ExpenseUser.fromJson(
      Map<String, dynamic>.from(json['fromUser'] as Map),
    ),
    toUser: ExpenseUser.fromJson(
      Map<String, dynamic>.from(json['toUser'] as Map),
    ),
    createdBy: ExpenseUser.fromJson(
      Map<String, dynamic>.from(json['createdBy'] as Map),
    ),
    amount: ExpenseMoney.fromJson(json['amount']),
    status: json['status'] as String,
    declarationType: json['declarationType'] as String,
    completedAt: json['completedAt'] == null
        ? null
        : DateTime.parse(json['completedAt'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    statusHistory: (json['statusHistory'] as List? ?? const [])
        .map(
          (v) => SettlementStatusChange.fromJson(
            Map<String, dynamic>.from(v as Map),
          ),
        )
        .toList(),
    permissions: SettlementPermissions.fromJson(
      json['permissions'] is Map
          ? Map<String, dynamic>.from(json['permissions'] as Map)
          : null,
    ),
  );
}

class CreateSettlementDraft {
  final String otherUserId;
  final ExpenseMoney amount;
  final String declarationType;
  const CreateSettlementDraft({
    required this.otherUserId,
    required this.amount,
    required this.declarationType,
  });
  Map<String, dynamic> toJson() => {
    'otherUserId': otherUserId,
    'amount': amount.decimal,
    'declarationType': declarationType,
  };
}
