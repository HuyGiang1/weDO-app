import 'package:flutter/material.dart';

/// Presentation-only M7 shapes. Runtime/API ownership intentionally remains
/// outside this frontend-first batch.
enum ActivityLifecycle { planning, confirmed, inProgress, completed, cancelled }

enum ActivityRsvp { noResponse, going, maybe, notGoing, waitlist }

extension ActivityLifecycleLabel on ActivityLifecycle {
  String get label => switch (this) {
    ActivityLifecycle.planning => 'PLANNING',
    ActivityLifecycle.confirmed => 'CONFIRMED',
    ActivityLifecycle.inProgress => 'IN PROGRESS',
    ActivityLifecycle.completed => 'COMPLETED',
    ActivityLifecycle.cancelled => 'CANCELLED',
  };
}

extension ActivityRsvpLabel on ActivityRsvp {
  String get label => switch (this) {
    ActivityRsvp.noResponse => 'NO RESPONSE',
    ActivityRsvp.going => 'GOING',
    ActivityRsvp.maybe => 'MAYBE',
    ActivityRsvp.notGoing => 'NOT GOING',
    ActivityRsvp.waitlist => 'WAITLIST',
  };
}

class ActivityCardData {
  final String id;
  final String title;
  final String scheduleLabel;
  final String? locationLabel;
  final ActivityLifecycle lifecycle;
  final ActivityRsvp callerRsvp;
  final String capacityLabel;

  const ActivityCardData({
    required this.id,
    required this.title,
    required this.scheduleLabel,
    required this.lifecycle,
    required this.callerRsvp,
    required this.capacityLabel,
    this.locationLabel,
  });
}

enum ActivityListVisualState { loading, error, empty, data }

class ActivityCreator {
  final String displayName;
  final String username;
  final String? avatarStorageKey;
  const ActivityCreator({
    required this.displayName,
    required this.username,
    this.avatarStorageKey,
  });
}

class ActivityLocation {
  final String type;
  final String? name;
  final String? address;
  final double? latitude;
  final double? longitude;
  const ActivityLocation({
    required this.type,
    this.name,
    this.address,
    this.latitude,
    this.longitude,
  });

  String get displayLabel => [name, address].whereType<String>().join('\n');
}

class ActivityDetailData {
  final String id;
  final String title;
  final String? description;
  final ActivityLifecycle lifecycle;
  final ActivityCreator? creator;
  final String dateLabel;
  final String timeLabel;
  final String timezone;
  final ActivityLocation? location;
  final String capacityLabel;
  final ActivityRsvp callerRsvp;
  final int participantPreviewCount;
  final int? waitlistPosition;
  const ActivityDetailData({
    required this.id,
    required this.title,
    required this.lifecycle,
    required this.dateLabel,
    required this.timeLabel,
    required this.timezone,
    required this.capacityLabel,
    required this.callerRsvp,
    required this.participantPreviewCount,
    this.description,
    this.creator,
    this.location,
    this.waitlistPosition,
  });
}

class ActivityManagementActions {
  final bool canEdit;
  final bool canConfirm;
  final bool canCancel;
  final bool canComplete;
  const ActivityManagementActions({
    this.canEdit = false,
    this.canConfirm = false,
    this.canCancel = false,
    this.canComplete = false,
  });
}

class ActivityDraft {
  final String title;
  final String? description;
  final DateTime? startAt;
  final DateTime? endAt;
  final String timezone;
  final ActivityLocation? location;
  final int? maxParticipants;
  const ActivityDraft({
    required this.title,
    required this.timezone,
    this.description,
    this.startAt,
    this.endAt,
    this.location,
    this.maxParticipants,
  });
}

enum ActivityEditState { editable, readOnly, lifecycleLocked }

class ActivityParticipantData {
  final String userId;
  final String displayName;
  final String username;
  final String? avatarStorageKey;
  final ActivityRsvp rsvp;
  final int? waitlistPosition;
  const ActivityParticipantData({
    required this.userId,
    required this.displayName,
    required this.username,
    required this.rsvp,
    this.avatarStorageKey,
    this.waitlistPosition,
  });
}

class ActivityWaitlistData {
  final String activityTitle;
  final int queuePosition;
  final String capacityLabel;
  const ActivityWaitlistData({
    required this.activityTitle,
    required this.queuePosition,
    required this.capacityLabel,
  });
}

Color activityRsvpColor(ActivityRsvp value) => switch (value) {
  ActivityRsvp.going => const Color(0xFFEADDFF),
  ActivityRsvp.maybe => const Color(0xFFFFF1DC),
  ActivityRsvp.notGoing || ActivityRsvp.noResponse => const Color(0xFFE8EEF0),
  ActivityRsvp.waitlist => const Color(0xFFEDE0FF),
};
