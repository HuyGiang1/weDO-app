enum ActivityStatus { planning, confirmed, inProgress, completed, cancelled }

extension ActivityStatusWire on ActivityStatus {
  String get wire => switch (this) {
    ActivityStatus.planning => 'PLANNING',
    ActivityStatus.confirmed => 'CONFIRMED',
    ActivityStatus.inProgress => 'IN_PROGRESS',
    ActivityStatus.completed => 'COMPLETED',
    ActivityStatus.cancelled => 'CANCELLED',
  };
  static ActivityStatus parse(String value) => ActivityStatus.values.firstWhere(
    (v) => v.wire == value,
    orElse: () => throw FormatException('Unknown activity status: $value'),
  );
}

enum ActivityRsvpStatus { noResponse, going, maybe, notGoing, waitlist }

extension ActivityRsvpStatusWire on ActivityRsvpStatus {
  String get wire => switch (this) {
    ActivityRsvpStatus.noResponse => 'NO_RESPONSE',
    ActivityRsvpStatus.going => 'GOING',
    ActivityRsvpStatus.maybe => 'MAYBE',
    ActivityRsvpStatus.notGoing => 'NOT_GOING',
    ActivityRsvpStatus.waitlist => 'WAITLIST',
  };
  static ActivityRsvpStatus parse(String value) =>
      ActivityRsvpStatus.values.firstWhere(
        (v) => v.wire == value,
        orElse: () => throw FormatException('Unknown RSVP status: $value'),
      );
  bool get clientSelectable =>
      this != ActivityRsvpStatus.noResponse &&
      this != ActivityRsvpStatus.waitlist;
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('Expected string $key');
  return value;
}

DateTime _date(Map<String, dynamic> json, String key) =>
    DateTime.parse(_string(json, key));
int? _int(Map<String, dynamic> json, String key) =>
    json[key] == null ? null : (json[key] as num).toInt();
int _requiredInt(Map<String, dynamic> json, String key) =>
    (json[key] as num).toInt();

class ActivityLocation {
  final String? type, name, address;
  final double? latitude, longitude;
  const ActivityLocation({
    this.type,
    this.name,
    this.address,
    this.latitude,
    this.longitude,
  });
  factory ActivityLocation.fromJson(Map<String, dynamic> j) => ActivityLocation(
    type: j['type'] as String?,
    name: j['name'] as String?,
    address: j['address'] as String?,
    latitude: (j['latitude'] as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
  );
  Map<String, dynamic> toJson() => {
    if (type != null) 'type': type,
    if (name != null) 'name': name,
    if (address != null) 'address': address,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };
}

class ActivityPermissions {
  final bool canEdit, canConfirm, canCancel, canComplete, canRsvp;
  const ActivityPermissions({
    required this.canEdit,
    required this.canConfirm,
    required this.canCancel,
    required this.canComplete,
    required this.canRsvp,
  });
  factory ActivityPermissions.fromJson(Map<String, dynamic> j) =>
      ActivityPermissions(
        canEdit: j['canEdit'] as bool? ?? false,
        canConfirm: j['canConfirm'] as bool? ?? false,
        canCancel: j['canCancel'] as bool? ?? false,
        canComplete: j['canComplete'] as bool? ?? false,
        canRsvp: j['canRsvp'] as bool? ?? false,
      );
}

class ActivityCreator {
  final String userId;
  final String? username, displayName, avatarStorageKey;
  const ActivityCreator({
    required this.userId,
    this.username,
    this.displayName,
    this.avatarStorageKey,
  });
  factory ActivityCreator.fromJson(Map<String, dynamic> j) => ActivityCreator(
    userId: _string(j, 'userId'),
    username: j['username'] as String?,
    displayName: j['displayName'] as String?,
    avatarStorageKey: j['avatarStorageKey'] as String?,
  );
}

class ActivitySummary {
  final String id, title;
  final String? timezone;
  final ActivityStatus status;
  final DateTime? startAt;
  final DateTime? endAt;
  final String? locationName;
  final int? maxParticipants;
  final int goingCount, waitlistCount;
  final ActivityRsvpStatus callerRsvpStatus;
  const ActivitySummary({
    required this.id,
    required this.title,
    required this.status,
    this.startAt,
    this.endAt,
    this.timezone,
    this.locationName,
    this.maxParticipants,
    required this.goingCount,
    required this.waitlistCount,
    required this.callerRsvpStatus,
  });
  factory ActivitySummary.fromJson(Map<String, dynamic> j) => ActivitySummary(
    id: _string(j, 'id'),
    title: _string(j, 'title'),
    status: ActivityStatusWire.parse(_string(j, 'status')),
    startAt: j['startAt'] == null ? null : _date(j, 'startAt'),
    endAt: j['endAt'] == null ? null : _date(j, 'endAt'),
    timezone: j['timezone'] as String?,
    locationName: j['locationName'] as String?,
    maxParticipants: _int(j, 'maxParticipants'),
    goingCount: _requiredInt(j, 'goingCount'),
    waitlistCount: _requiredInt(j, 'waitlistCount'),
    callerRsvpStatus: ActivityRsvpStatusWire.parse(
      _string(j, 'callerRsvpStatus'),
    ),
  );
}

class ActivityDetail {
  final String id, groupId, title;
  final String? timezone;
  final String? description;
  final ActivityStatus status;
  final DateTime? startAt;
  final DateTime? endAt;
  final ActivityLocation? location;
  final int? maxParticipants, callerWaitlistPosition;
  final DateTime createdAt, updatedAt;
  final ActivityCreator creator;
  final ActivityRsvpStatus callerRsvpStatus;
  final int goingCount, maybeCount, notGoingCount, waitlistCount;
  final ActivityPermissions permissions;
  const ActivityDetail({
    required this.id,
    required this.groupId,
    required this.title,
    this.description,
    required this.status,
    this.startAt,
    this.endAt,
    this.timezone,
    this.location,
    this.maxParticipants,
    required this.createdAt,
    required this.updatedAt,
    required this.creator,
    required this.callerRsvpStatus,
    this.callerWaitlistPosition,
    required this.goingCount,
    required this.maybeCount,
    required this.notGoingCount,
    required this.waitlistCount,
    required this.permissions,
  });
  factory ActivityDetail.fromJson(Map<String, dynamic> j) => ActivityDetail(
    id: _string(j, 'id'),
    groupId: _string(j, 'groupId'),
    title: _string(j, 'title'),
    description: j['description'] as String?,
    status: ActivityStatusWire.parse(_string(j, 'status')),
    startAt: j['startAt'] == null ? null : _date(j, 'startAt'),
    endAt: j['endAt'] == null ? null : _date(j, 'endAt'),
    timezone: j['timezone'] as String?,
    location: j['location'] is Map
        ? ActivityLocation.fromJson(
            Map<String, dynamic>.from(j['location'] as Map),
          )
        : null,
    maxParticipants: _int(j, 'maxParticipants'),
    createdAt: _date(j, 'createdAt'),
    updatedAt: _date(j, 'updatedAt'),
    creator: ActivityCreator.fromJson(
      Map<String, dynamic>.from(j['creator'] as Map),
    ),
    callerRsvpStatus: ActivityRsvpStatusWire.parse(
      _string(j, 'callerRsvpStatus'),
    ),
    callerWaitlistPosition: _int(j, 'callerWaitlistPosition'),
    goingCount: _requiredInt(j, 'goingCount'),
    maybeCount: _requiredInt(j, 'maybeCount'),
    notGoingCount: _requiredInt(j, 'notGoingCount'),
    waitlistCount: _requiredInt(j, 'waitlistCount'),
    permissions: ActivityPermissions.fromJson(
      Map<String, dynamic>.from(j['permissions'] as Map),
    ),
  );
}

class ActivityParticipant {
  final String userId;
  final String? displayName, username, avatarStorageKey;
  final ActivityRsvpStatus rsvpStatus;
  final int? waitlistSequence;
  final DateTime? statusUpdatedAt;
  const ActivityParticipant({
    required this.userId,
    this.displayName,
    this.username,
    this.avatarStorageKey,
    required this.rsvpStatus,
    this.waitlistSequence,
    this.statusUpdatedAt,
  });
  factory ActivityParticipant.fromJson(Map<String, dynamic> j) =>
      ActivityParticipant(
        userId: _string(j, 'userId'),
        displayName: j['displayName'] as String?,
        username: j['username'] as String?,
        avatarStorageKey: j['avatarStorageKey'] as String?,
        rsvpStatus: ActivityRsvpStatusWire.parse(
          j['rsvpStatus'] != null ? _string(j, 'rsvpStatus') : _string(j, 'status'),
        ),
        waitlistSequence: _int(j, 'waitlistSequence'),
        statusUpdatedAt: j['statusUpdatedAt'] == null
            ? null
            : _date(j, 'statusUpdatedAt'),
      );
}

class ActivityRsvp {
  final ActivityRsvpStatus status;
  final int? waitlistSequence;
  final DateTime? statusUpdatedAt;
  const ActivityRsvp({
    required this.status,
    this.waitlistSequence,
    this.statusUpdatedAt,
  });
  factory ActivityRsvp.fromJson(Map<String, dynamic> j) => ActivityRsvp(
    status: ActivityRsvpStatusWire.parse(_string(j, 'status')),
    waitlistSequence: _int(j, 'waitlistSequence'),
    statusUpdatedAt: j['statusUpdatedAt'] == null
        ? null
        : _date(j, 'statusUpdatedAt'),
  );
}

class ActivityDraft {
  final String title;
  final String? timezone;
  final String? description;
  final DateTime? startAt;
  final DateTime? endAt;
  final ActivityLocation? location;
  final int? maxParticipants;
  const ActivityDraft({
    required this.title,
    this.timezone,
    this.description,
    this.startAt,
    this.endAt,
    this.location,
    this.maxParticipants,
  });
  Map<String, dynamic> toCreateJson() => {
    'title': title,
    'description': description,
    'startAt': startAt?.toUtc().toIso8601String(),
    'endAt': endAt?.toUtc().toIso8601String(),
    'timezone': timezone,
    'location': location?.toJson(),
    'maxParticipants': maxParticipants,
  }..removeWhere((_, v) => v == null);
  Map<String, dynamic> toPatchJson() => toCreateJson();
}

/// Form boundary helpers keep partial-update intent explicit. The backend DTO
/// uses nullable fields for omission, so the mobile client never sends a field
/// merely because an edit form rendered it.
Map<String, dynamic> activityPatchFor({
  required ActivityDetail original,
  required String title,
  required String description,
  DateTime? startAt,
  DateTime? endAt,
  String? timezone,
  ActivityLocation? location,
  int? maxParticipants,
}) {
  final patch = <String, dynamic>{};
  final trimmedTitle = title.trim();
  final trimmedDescription = description.trim();
  final trimmedTimezone = timezone?.trim();
  if (trimmedTitle != original.title) patch['title'] = trimmedTitle;
  // An empty description is intentionally omitted: UpdateActivityRequest
  // cannot distinguish an omitted nullable field from a JSON null clear.
  if (trimmedDescription.isNotEmpty && trimmedDescription != original.description) {
    patch['description'] = trimmedDescription;
  }
  if (startAt?.toUtc() != original.startAt?.toUtc()) {
    if (startAt != null) {
      patch['startAt'] = startAt.toUtc().toIso8601String();
    }
  }
  if (endAt?.toUtc() != original.endAt?.toUtc()) {
    if (endAt != null) patch['endAt'] = endAt.toUtc().toIso8601String();
  }
  if (trimmedTimezone != null && trimmedTimezone.isNotEmpty && trimmedTimezone != original.timezone) {
    patch['timezone'] = trimmedTimezone;
  }
  if (location != null &&
      (location.type != original.location?.type ||
          location.name != original.location?.name ||
          location.address != original.location?.address ||
          location.latitude != original.location?.latitude ||
          location.longitude != original.location?.longitude)) {
    patch['location'] = location.toJson();
  }
  if (maxParticipants != null && maxParticipants != original.maxParticipants) {
    patch['maxParticipants'] = maxParticipants;
  }
  return patch;
}

bool isIanaTimezoneSyntax(String value) => RegExp(
  r'^[A-Za-z]+(?:[+_-][A-Za-z]+)*(?:/[A-Za-z]+(?:[+_-][A-Za-z]+)*)+$',
).hasMatch(value);
