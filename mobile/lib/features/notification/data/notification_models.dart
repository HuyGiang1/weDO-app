class NotificationActorModel {
  const NotificationActorModel({
    required this.userId,
    required this.displayName,
    this.username,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final String? username;
  final String? avatarUrl;

  factory NotificationActorModel.fromJson(Map<String, dynamic> json) {
    return NotificationActorModel(
      userId: (json['userId'] ?? json['id'] ?? '').toString(),
      displayName: (json['displayName'] ?? 'Thành viên').toString(),
      username: json['username']?.toString(),
      avatarUrl: (json['avatarUrl'] ?? json['avatarStorageKey'])?.toString(),
    );
  }
}

class NotificationGroupSummaryModel {
  const NotificationGroupSummaryModel({
    required this.groupId,
    required this.groupName,
    this.groupStatus = 'ACTIVE',
  });

  final String groupId;
  final String groupName;
  final String groupStatus;

  factory NotificationGroupSummaryModel.fromJson(Map<String, dynamic> json) {
    return NotificationGroupSummaryModel(
      groupId: (json['groupId'] ?? json['id'] ?? '').toString(),
      groupName: (json['groupName'] ?? json['name'] ?? 'Nhóm WeDo').toString(),
      groupStatus: (json['groupStatus'] ?? json['status'] ?? 'ACTIVE')
          .toString(),
    );
  }
}

class NotificationTargetModel {
  const NotificationTargetModel({
    required this.targetType,
    this.targetId,
    required this.route,
    required this.actionable,
    this.nonActionableReason,
    this.params = const <String, dynamic>{},
  });

  final String targetType;
  final String? targetId;
  final String route;
  final bool actionable;
  final String? nonActionableReason;
  final Map<String, dynamic> params;

  factory NotificationTargetModel.fromJson(Map<String, dynamic> json) {
    final dynamic rawParams = json['params'];
    return NotificationTargetModel(
      targetType: (json['targetType'] ?? 'GROUP').toString(),
      targetId: json['targetId']?.toString(),
      route: (json['route'] ?? '/notifications').toString(),
      actionable: json['actionable'] != false,
      nonActionableReason: json['nonActionableReason']?.toString(),
      params: rawParams is Map
          ? Map<String, dynamic>.from(rawParams)
          : const <String, dynamic>{},
    );
  }
}

class NotificationItemModel {
  const NotificationItemModel({
    required this.notificationId,
    required this.userId,
    required this.category,
    required this.eventType,
    required this.priority,
    required this.critical,
    required this.title,
    required this.body,
    this.actor,
    this.group,
    required this.target,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  final String notificationId;
  final String userId;
  final String category;
  final String eventType;
  final String priority;
  final bool critical;
  final String title;
  final String body;
  final NotificationActorModel? actor;
  final NotificationGroupSummaryModel? group;
  final NotificationTargetModel target;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  factory NotificationItemModel.fromJson(Map<String, dynamic> json) {
    final dynamic rawActor = json['actor'];
    final dynamic rawGroup = json['group'];
    final dynamic rawTarget = json['target'];
    final String? readAtStr = json['readAt']?.toString();
    final String? createdAtStr = json['createdAt']?.toString();

    return NotificationItemModel(
      notificationId: (json['notificationId'] ?? json['id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      category: (json['category'] ?? 'GROUP').toString(),
      eventType: (json['eventType'] ?? 'SYSTEM').toString(),
      priority: (json['priority'] ?? 'NORMAL').toString(),
      critical: json['critical'] == true,
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      actor: rawActor is Map
          ? NotificationActorModel.fromJson(Map<String, dynamic>.from(rawActor))
          : null,
      group: rawGroup is Map
          ? NotificationGroupSummaryModel.fromJson(
              Map<String, dynamic>.from(rawGroup),
            )
          : null,
      target: rawTarget is Map
          ? NotificationTargetModel.fromJson(
              Map<String, dynamic>.from(rawTarget),
            )
          : const NotificationTargetModel(
              targetType: 'GROUP',
              route: '/notifications',
              actionable: true,
            ),
      isRead: json['isRead'] == true || json['read'] == true,
      readAt: readAtStr != null ? DateTime.tryParse(readAtStr) : null,
      createdAt:
          (createdAtStr != null ? DateTime.tryParse(createdAtStr) : null) ??
          DateTime.now(),
    );
  }

  NotificationItemModel copyWith({bool? isRead, DateTime? readAt}) {
    return NotificationItemModel(
      notificationId: notificationId,
      userId: userId,
      category: category,
      eventType: eventType,
      priority: priority,
      critical: critical,
      title: title,
      body: body,
      actor: actor,
      group: group,
      target: target,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }
}

class NotificationInboxPageModel {
  const NotificationInboxPageModel({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.hasNext,
  });

  final List<NotificationItemModel> items;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool hasNext;

  factory NotificationInboxPageModel.fromJson(Map<String, dynamic> json) {
    final dynamic rawItems = json['items'];
    final List<NotificationItemModel> parsedItems = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (Map<dynamic, dynamic> e) => NotificationItemModel.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList(growable: false)
        : const <NotificationItemModel>[];
    return NotificationInboxPageModel(
      items: parsedItems,
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 30,
      totalElements:
          (json['totalElements'] as num?)?.toInt() ?? parsedItems.length,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      hasNext: json['hasNext'] == true,
    );
  }

  NotificationInboxPageModel copyWith({List<NotificationItemModel>? items}) {
    return NotificationInboxPageModel(
      items: items ?? this.items,
      page: page,
      size: size,
      totalElements: totalElements,
      totalPages: totalPages,
      hasNext: hasNext,
    );
  }
}

class MarkNotificationReadResult {
  const MarkNotificationReadResult({
    required this.notificationId,
    required this.isRead,
    this.readAt,
  });

  final String notificationId;
  final bool isRead;
  final DateTime? readAt;

  factory MarkNotificationReadResult.fromJson(Map<String, dynamic> json) {
    final String? readAtStr = json['readAt']?.toString();
    return MarkNotificationReadResult(
      notificationId: (json['notificationId'] ?? json['id'] ?? '').toString(),
      isRead: json['isRead'] == true || json['read'] != false,
      readAt: readAtStr != null ? DateTime.tryParse(readAtStr) : null,
    );
  }
}

class UserNotificationSettingsModel {
  const UserNotificationSettingsModel({
    required this.userId,
    required this.pushEnabled,
    required this.socialEnabled,
    required this.groupEnabled,
    required this.chatEnabled,
    required this.activityEnabled,
    required this.pollEnabled,
    required this.taskEnabled,
    required this.financeEnabled,
    required this.fundEnabled,
    this.updatedAt,
  });

  factory UserNotificationSettingsModel.defaults() {
    return const UserNotificationSettingsModel(
      userId: '',
      pushEnabled: true,
      socialEnabled: true,
      groupEnabled: true,
      chatEnabled: true,
      activityEnabled: true,
      pollEnabled: true,
      taskEnabled: true,
      financeEnabled: true,
      fundEnabled: true,
    );
  }

  final String userId;
  final bool pushEnabled;
  final bool socialEnabled;
  final bool groupEnabled;
  final bool chatEnabled;
  final bool activityEnabled;
  final bool pollEnabled;
  final bool taskEnabled;
  final bool financeEnabled;
  final bool fundEnabled;
  final DateTime? updatedAt;

  factory UserNotificationSettingsModel.fromJson(Map<String, dynamic> json) {
    final String? updatedAtStr = json['updatedAt']?.toString();
    return UserNotificationSettingsModel(
      userId: (json['userId'] ?? '').toString(),
      pushEnabled: json['pushEnabled'] != false,
      socialEnabled: json['socialEnabled'] != false,
      groupEnabled: json['groupEnabled'] != false,
      chatEnabled: json['chatEnabled'] != false,
      activityEnabled: json['activityEnabled'] != false,
      pollEnabled: json['pollEnabled'] != false,
      taskEnabled: json['taskEnabled'] != false,
      financeEnabled: json['financeEnabled'] != false,
      fundEnabled: json['fundEnabled'] != false,
      updatedAt: updatedAtStr != null ? DateTime.tryParse(updatedAtStr) : null,
    );
  }

  UserNotificationSettingsModel copyWith({
    bool? pushEnabled,
    bool? socialEnabled,
    bool? groupEnabled,
    bool? chatEnabled,
    bool? activityEnabled,
    bool? pollEnabled,
    bool? taskEnabled,
    bool? financeEnabled,
    bool? fundEnabled,
  }) {
    return UserNotificationSettingsModel(
      userId: userId,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      socialEnabled: socialEnabled ?? this.socialEnabled,
      groupEnabled: groupEnabled ?? this.groupEnabled,
      chatEnabled: chatEnabled ?? this.chatEnabled,
      activityEnabled: activityEnabled ?? this.activityEnabled,
      pollEnabled: pollEnabled ?? this.pollEnabled,
      taskEnabled: taskEnabled ?? this.taskEnabled,
      financeEnabled: financeEnabled ?? this.financeEnabled,
      fundEnabled: fundEnabled ?? this.fundEnabled,
      updatedAt: updatedAt,
    );
  }
}

class GroupNotificationSettingsModel {
  const GroupNotificationSettingsModel({
    required this.groupId,
    required this.userId,
    required this.isMuted,
    this.muteDuration,
    this.muteUntil,
    this.updatedAt,
  });

  final String groupId;
  final String userId;
  final bool isMuted;
  final String? muteDuration;
  final DateTime? muteUntil;
  final DateTime? updatedAt;

  factory GroupNotificationSettingsModel.fromJson(Map<String, dynamic> json) {
    final String? muteUntilStr = (json['mutedUntil'] ?? json['muteUntil'])
        ?.toString();
    final String? updatedAtStr = json['updatedAt']?.toString();
    final dynamic effectiveMute = json['effectivelyMuted'];
    final dynamic muted = json['muted'] ?? json['isMuted'];
    return GroupNotificationSettingsModel(
      groupId: (json['groupId'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      isMuted: effectiveMute is bool ? effectiveMute : muted == true,
      muteDuration: (json['muteOption'] ?? json['muteDuration'])?.toString(),
      muteUntil: muteUntilStr != null ? DateTime.tryParse(muteUntilStr) : null,
      updatedAt: updatedAtStr != null ? DateTime.tryParse(updatedAtStr) : null,
    );
  }
}

class UserDeviceModel {
  const UserDeviceModel({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.platform,
    required this.pushToken,
    required this.active,
    this.lastSeenAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String deviceId;
  final String platform;
  final String pushToken;
  final bool active;
  final DateTime? lastSeenAt;
  final DateTime? updatedAt;

  factory UserDeviceModel.fromJson(Map<String, dynamic> json) {
    final String? lastSeenStr = json['lastSeenAt']?.toString();
    final String? updatedStr = json['updatedAt']?.toString();
    return UserDeviceModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      deviceId: (json['deviceId'] ?? '').toString(),
      platform: (json['platform'] ?? 'ANDROID').toString(),
      pushToken: (json['pushToken'] ?? '').toString(),
      active: json['active'] != false,
      lastSeenAt: lastSeenStr != null ? DateTime.tryParse(lastSeenStr) : null,
      updatedAt: updatedStr != null ? DateTime.tryParse(updatedStr) : null,
    );
  }
}
