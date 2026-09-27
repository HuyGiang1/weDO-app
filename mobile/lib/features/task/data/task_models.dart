enum ActivityTaskStatus { todo, inProgress, done }

extension ActivityTaskStatusWire on ActivityTaskStatus {
  String get wire => switch (this) {
    ActivityTaskStatus.todo => 'TODO',
    ActivityTaskStatus.inProgress => 'IN_PROGRESS',
    ActivityTaskStatus.done => 'DONE',
  };

  static ActivityTaskStatus parse(String value) => switch (value) {
    'IN_PROGRESS' => ActivityTaskStatus.inProgress,
    'TODO' => ActivityTaskStatus.todo,
    'DONE' => ActivityTaskStatus.done,
    _ => ActivityTaskStatus.todo,
  };
}

class ActivityTaskHistory {
  final ActivityTaskStatus? fromStatus;
  final ActivityTaskStatus toStatus;
  final String changedBy;
  final DateTime createdAt;

  const ActivityTaskHistory({
    required this.fromStatus,
    required this.toStatus,
    required this.changedBy,
    required this.createdAt,
  });

  factory ActivityTaskHistory.fromJson(Map<String, dynamic> json) =>
      ActivityTaskHistory(
        fromStatus: json['fromStatus'] == null
            ? null
            : ActivityTaskStatusWire.parse(json['fromStatus'] as String),
        toStatus: ActivityTaskStatusWire.parse(json['toStatus'] as String),
        changedBy: json['changedBy'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class ActivityTaskPermissions {
  final bool canEdit, canManageAssignees, canClaim, canChangeStatus, canDelete;
  const ActivityTaskPermissions({
    required this.canEdit,
    required this.canManageAssignees,
    required this.canClaim,
    required this.canChangeStatus,
    required this.canDelete,
  });
  factory ActivityTaskPermissions.fromJson(Map<String, dynamic>? json) =>
      ActivityTaskPermissions(
        canEdit: json?['canEdit'] as bool? ?? false,
        canManageAssignees: json?['canManageAssignees'] as bool? ?? false,
        canClaim: json?['canClaim'] as bool? ?? false,
        canChangeStatus: json?['canChangeStatus'] as bool? ?? false,
        canDelete: json?['canDelete'] as bool? ?? false,
      );
}

class ActivityTask {
  final String id;
  final String activityId;
  final String createdBy;
  final String title;
  final String? description;
  final ActivityTaskStatus status;
  final DateTime? dueAt;
  final List<String> assigneeUserIds;
  final List<ActivityTaskHistory> statusHistory;
  final ActivityTaskPermissions permissions;

  const ActivityTask({
    required this.id,
    required this.activityId,
    required this.createdBy,
    required this.title,
    required this.description,
    required this.status,
    required this.dueAt,
    required this.assigneeUserIds,
    required this.statusHistory,
    required this.permissions,
  });

  factory ActivityTask.fromJson(Map<String, dynamic> json) => ActivityTask(
    id: json['id'] as String,
    activityId: json['activityId'] as String,
    createdBy: json['createdBy'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    status: ActivityTaskStatusWire.parse(json['status'] as String),
    dueAt: json['dueAt'] == null
        ? null
        : DateTime.parse(json['dueAt'] as String),
    assigneeUserIds: (json['assigneeUserIds'] as List? ?? const [])
        .cast<String>(),
    statusHistory: (json['statusHistory'] as List? ?? const [])
        .map(
          (item) => ActivityTaskHistory.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(),
    permissions: ActivityTaskPermissions.fromJson(
      json['permissions'] is Map
          ? Map<String, dynamic>.from(json['permissions'] as Map)
          : null,
    ),
  );
}

class ActivityTaskDraft {
  final String title;
  final String? description;
  final List<String> assigneeUserIds;
  final DateTime? dueAt;

  const ActivityTaskDraft({
    required this.title,
    this.description,
    required this.assigneeUserIds,
    this.dueAt,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'assigneeUserIds': assigneeUserIds,
    'dueAt': dueAt?.toUtc().toIso8601String(),
  };
}
