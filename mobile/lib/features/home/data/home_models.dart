import '../../expense/data/expense_models.dart';
import '../../notification/data/notification_models.dart';

Map<String, dynamic> _object(Object? value) {
  if (value is! Map) throw const FormatException('Expected object');
  return Map<String, dynamic>.from(value);
}

List<T> _items<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  if (value is! List) throw const FormatException('Expected list');
  return value.map((item) => parse(_object(item))).toList();
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) throw FormatException('Missing $key');
  return value;
}

class HomeGroup {
  final String id;
  final String name;
  final String? avatarStorageKey;
  const HomeGroup(this.id, this.name, this.avatarStorageKey);

  factory HomeGroup.fromJson(Map<String, dynamic> json) => HomeGroup(
    _string(json, 'id'),
    _string(json, 'name'),
    json['avatarStorageKey'] as String?,
  );
}

class HomeActivity {
  final String id;
  final String groupId;
  final String groupName;
  final String title;
  final DateTime startAt;
  const HomeActivity(
    this.id,
    this.groupId,
    this.groupName,
    this.title,
    this.startAt,
  );

  factory HomeActivity.fromJson(Map<String, dynamic> json) => HomeActivity(
    _string(json, 'id'),
    _string(json, 'groupId'),
    _string(json, 'groupName'),
    _string(json, 'title'),
    DateTime.parse(_string(json, 'startAt')),
  );
}

class HomeGroupBalance {
  final String groupId;
  final String groupName;
  final ExpenseMoney owedByMe;
  final ExpenseMoney owedToMe;
  const HomeGroupBalance(
    this.groupId,
    this.groupName,
    this.owedByMe,
    this.owedToMe,
  );

  factory HomeGroupBalance.fromJson(Map<String, dynamic> json) =>
      HomeGroupBalance(
        _string(json, 'groupId'),
        _string(json, 'groupName'),
        ExpenseMoney.fromJson(json['owedByMe']),
        ExpenseMoney.fromJson(json['owedToMe']),
      );
}

class HomeFinance {
  final ExpenseMoney owedByMe;
  final ExpenseMoney owedToMe;
  final List<HomeGroupBalance> groups;
  const HomeFinance(this.owedByMe, this.owedToMe, this.groups);

  factory HomeFinance.fromJson(Map<String, dynamic> json) => HomeFinance(
    ExpenseMoney.fromJson(json['totalOwedByMe']),
    ExpenseMoney.fromJson(json['totalOwedToMe']),
    _items(json['groups'], HomeGroupBalance.fromJson),
  );
}

enum HomeActionType {
  rsvpRequired('RSVP_REQUIRED'),
  pollVoteRequired('POLL_VOTE_REQUIRED'),
  taskDue('TASK_DUE'),
  settlementConfirmation('SETTLEMENT_CONFIRMATION');

  final String wire;
  const HomeActionType(this.wire);

  static HomeActionType fromWire(String value) => values.firstWhere(
    (type) => type.wire == value,
    orElse: () => throw FormatException('Unknown action type: $value'),
  );
}

class HomeAction {
  final HomeActionType type;
  final String targetId;
  final String groupId;
  final String? activityId;
  final String title;
  final DateTime? dueAt;
  const HomeAction(
    this.type,
    this.targetId,
    this.groupId,
    this.activityId,
    this.title,
    this.dueAt,
  );

  factory HomeAction.fromJson(Map<String, dynamic> json) => HomeAction(
    HomeActionType.fromWire(_string(json, 'type')),
    _string(json, 'targetId'),
    _string(json, 'groupId'),
    json['activityId'] as String?,
    _string(json, 'title'),
    json['dueAt'] == null ? null : DateTime.parse(_string(json, 'dueAt')),
  );
}

class HomeResponse {
  final List<HomeGroup> recentGroups;
  final List<HomeActivity> upcomingActivities;
  final HomeFinance financeSummary;
  final List<HomeAction> actionsRequired;
  final List<NotificationItemModel> recentUpdates;
  const HomeResponse(
    this.recentGroups,
    this.upcomingActivities,
    this.financeSummary,
    this.actionsRequired,
    this.recentUpdates,
  );

  factory HomeResponse.fromJson(Map<String, dynamic> json) => HomeResponse(
    _items(json['recentGroups'], HomeGroup.fromJson),
    _items(json['upcomingActivities'], HomeActivity.fromJson),
    HomeFinance.fromJson(_object(json['financeSummary'])),
    _items(json['actionsRequired'], HomeAction.fromJson),
    _items(json['recentUpdates'], NotificationItemModel.fromJson),
  );
}
