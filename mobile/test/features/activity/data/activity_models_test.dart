import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/activity/data/activity_models.dart';

void main() {
  group('ActivityDetail DTO', () {
    test('full decode with structured location and all fields', () {
      final json = {
        'id': 'act-123',
        'groupId': 'grp-456',
        'title': 'Saturday Morning Run',
        'description': 'Running 5km around the lake.',
        'status': 'CONFIRMED',
        'startAt': '2030-06-15T08:00:00Z',
        'endAt': '2030-06-15T10:00:00Z',
        'timezone': 'Asia/Ho_Chi_Minh',
        'location': {
          'type': 'PHYSICAL',
          'name': 'Hoan Kiem Lake',
          'address': 'Dinh Tien Hoang, Hanoi',
          'latitude': 21.0285,
          'longitude': 105.8542,
        },
        'maxParticipants': 20,
        'createdAt': '2030-06-01T00:00:00Z',
        'updatedAt': '2030-06-02T00:00:00Z',
        'creator': {
          'userId': 'usr-789',
          'username': 'runner_john',
          'displayName': 'John Runner',
          'avatarStorageKey': 'avatars/john.jpg',
        },
        'callerRsvpStatus': 'GOING',
        'callerWaitlistPosition': null,
        'goingCount': 12,
        'maybeCount': 3,
        'notGoingCount': 1,
        'waitlistCount': 0,
        'permissions': {
          'canEdit': true,
          'canConfirm': false,
          'canCancel': true,
          'canComplete': false,
          'canRsvp': true,
        },
      };

      final detail = ActivityDetail.fromJson(json);

      expect(detail.id, 'act-123');
      expect(detail.groupId, 'grp-456');
      expect(detail.title, 'Saturday Morning Run');
      expect(detail.description, 'Running 5km around the lake.');
      expect(detail.status, ActivityStatus.confirmed);
      expect(detail.startAt, DateTime.parse('2030-06-15T08:00:00Z'));
      expect(detail.endAt, DateTime.parse('2030-06-15T10:00:00Z'));
      expect(detail.timezone, 'Asia/Ho_Chi_Minh');
      expect(detail.location, isNotNull);
      expect(detail.location!.type, 'PHYSICAL');
      expect(detail.location!.name, 'Hoan Kiem Lake');
      expect(detail.location!.address, 'Dinh Tien Hoang, Hanoi');
      expect(detail.location!.latitude, 21.0285);
      expect(detail.location!.longitude, 105.8542);
      expect(detail.maxParticipants, 20);
      expect(detail.creator.userId, 'usr-789');
      expect(detail.creator.username, 'runner_john');
      expect(detail.creator.displayName, 'John Runner');
      expect(detail.creator.avatarStorageKey, 'avatars/john.jpg');
      expect(detail.callerRsvpStatus, ActivityRsvpStatus.going);
      expect(detail.callerWaitlistPosition, isNull);
      expect(detail.goingCount, 12);
      expect(detail.maybeCount, 3);
      expect(detail.notGoingCount, 1);
      expect(detail.waitlistCount, 0);
      expect(detail.permissions.canEdit, isTrue);
      expect(detail.permissions.canConfirm, isFalse);
      expect(detail.permissions.canCancel, isTrue);
      expect(detail.permissions.canComplete, isFalse);
      expect(detail.permissions.canRsvp, isTrue);
    });

    test('parses authoritative permissions and waitlist position', () {
      final detail = ActivityDetail.fromJson({
        'id': 'a',
        'groupId': 'g',
        'title': 'Run',
        'status': 'CONFIRMED',
        'startAt': '2030-01-01T10:00:00Z',
        'endAt': null,
        'timezone': 'Asia/Ho_Chi_Minh',
        'location': null,
        'maxParticipants': 2,
        'createdAt': '2030-01-01T00:00:00Z',
        'updatedAt': '2030-01-01T00:00:00Z',
        'creator': {
          'userId': 'u',
          'username': 'safe',
          'displayName': 'Safe',
          'avatarStorageKey': null,
        },
        'callerRsvpStatus': 'WAITLIST',
        'callerWaitlistPosition': 3,
        'goingCount': 2,
        'maybeCount': 0,
        'notGoingCount': 0,
        'waitlistCount': 1,
        'permissions': {
          'canEdit': false,
          'canConfirm': false,
          'canCancel': false,
          'canComplete': false,
          'canRsvp': true,
        },
      });
      expect(detail.callerRsvpStatus, ActivityRsvpStatus.waitlist);
      expect(detail.callerWaitlistPosition, 3);
      expect(detail.permissions.canEdit, isFalse);
    });

    test('nullable fields decode gracefully when missing or null', () {
      final detail = ActivityDetail.fromJson({
        'id': 'act-min',
        'groupId': 'grp-1',
        'title': 'Minimal Activity',
        'status': 'PLANNING',
        'startAt': '2030-01-01T10:00:00Z',
        'timezone': 'UTC',
        'createdAt': '2030-01-01T00:00:00Z',
        'updatedAt': '2030-01-01T00:00:00Z',
        'creator': {'userId': 'u1'},
        'callerRsvpStatus': 'NO_RESPONSE',
        'goingCount': 0,
        'maybeCount': 0,
        'notGoingCount': 0,
        'waitlistCount': 0,
        'permissions': {},
      });

      expect(detail.description, isNull);
      expect(detail.endAt, isNull);
      expect(detail.location, isNull);
      expect(detail.maxParticipants, isNull);
      expect(detail.creator.username, isNull);
      expect(detail.creator.displayName, isNull);
      expect(detail.creator.avatarStorageKey, isNull);
      expect(detail.callerRsvpStatus, ActivityRsvpStatus.noResponse);
      expect(detail.callerWaitlistPosition, isNull);
      expect(detail.goingCount, 0);
      expect(detail.permissions.canEdit, isFalse);
      expect(detail.permissions.canRsvp, isFalse);
    });
  });

  group('ActivityDraft creation serialization', () {
    test('create draft omits nullable fields and serializes UTC timestamps', () {
      final json = ActivityDraft(
        title: 'Run',
        timezone: 'Asia/Ho_Chi_Minh',
        startAt: DateTime.utc(2030, 1, 1, 10),
      ).toCreateJson();
      expect(json, containsPair('title', 'Run'));
      expect(json, containsPair('startAt', '2030-01-01T10:00:00.000Z'));
      expect(json.containsKey('maxParticipants'), isFalse);
      expect(json.containsKey('endAt'), isFalse);
      expect(json.containsKey('location'), isFalse);
    });

    test('create draft serializes full structured location and endAt when provided', () {
      final draft = ActivityDraft(
        title: 'Workshop',
        description: 'Tech workshop',
        timezone: 'Asia/Ho_Chi_Minh',
        startAt: DateTime.utc(2030, 2, 1, 9, 0),
        endAt: DateTime.utc(2030, 2, 1, 17, 0),
        maxParticipants: 30,
        location: const ActivityLocation(
          type: 'ONLINE',
          name: 'Zoom Room 1',
          address: 'https://zoom.us/j/123456',
          latitude: 10.7769,
          longitude: 106.7009,
        ),
      );

      final json = draft.toCreateJson();
      expect(json['title'], 'Workshop');
      expect(json['description'], 'Tech workshop');
      expect(json['timezone'], 'Asia/Ho_Chi_Minh');
      expect(json['startAt'], '2030-02-01T09:00:00.000Z');
      expect(json['endAt'], '2030-02-01T17:00:00.000Z');
      expect(json['maxParticipants'], 30);
      expect(json['location'], {
        'type': 'ONLINE',
        'name': 'Zoom Room 1',
        'address': 'https://zoom.us/j/123456',
        'latitude': 10.7769,
        'longitude': 106.7009,
      });
    });
  });

  group('PATCH omission semantics (activityPatchFor)', () {
    final existing = ActivityDetail(
      id: 'act-1',
      groupId: 'grp-1',
      title: 'Original Title',
      description: 'Original Description',
      status: ActivityStatus.planning,
      startAt: DateTime.utc(2030, 3, 1, 10),
      endAt: DateTime.utc(2030, 3, 1, 12),
      timezone: 'Asia/Ho_Chi_Minh',
      location: const ActivityLocation(type: 'PHYSICAL', name: 'Original Park'),
      maxParticipants: 15,
      createdAt: DateTime.utc(2030, 1, 1),
      updatedAt: DateTime.utc(2030, 1, 1),
      creator: const ActivityCreator(userId: 'u1'),
      callerRsvpStatus: ActivityRsvpStatus.going,
      goingCount: 1,
      maybeCount: 0,
      notGoingCount: 0,
      waitlistCount: 0,
      permissions: const ActivityPermissions(
        canEdit: true,
        canConfirm: false,
        canCancel: false,
        canComplete: false,
        canRsvp: true,
      ),
    );

    test('omits unchanged fields when draft matches original', () {
      final patch = activityPatchFor(
        original: existing,
        title: 'Original Title',
        description: 'Original Description',
        startAt: DateTime.utc(2030, 3, 1, 10),
        endAt: DateTime.utc(2030, 3, 1, 12),
        timezone: 'Asia/Ho_Chi_Minh',
        location: const ActivityLocation(type: 'PHYSICAL', name: 'Original Park'),
        maxParticipants: 15,
      );
      expect(patch, isEmpty);
    });

    test('includes only modified fields in patch', () {
      final patch = activityPatchFor(
        original: existing,
        title: 'Updated Title',
        description: 'Original Description',
        startAt: DateTime.utc(2030, 3, 1, 10),
        endAt: DateTime.utc(2030, 3, 1, 12),
        timezone: 'Asia/Ho_Chi_Minh',
        location: const ActivityLocation(type: 'PHYSICAL', name: 'Original Park'),
        maxParticipants: 25,
      );
      expect(patch.keys, unorderedEquals(['title', 'maxParticipants']));
      expect(patch['title'], 'Updated Title');
      expect(patch['maxParticipants'], 25);
      expect(patch.containsKey('description'), isFalse);
      expect(patch.containsKey('startAt'), isFalse);
      expect(patch.containsKey('location'), isFalse);
    });

    test('serializes modified location when fields change', () {
      final patch = activityPatchFor(
        original: existing,
        title: 'Original Title',
        description: 'Original Description',
        startAt: DateTime.utc(2030, 3, 1, 10),
        endAt: DateTime.utc(2030, 3, 1, 12),
        timezone: 'Asia/Ho_Chi_Minh',
        location: const ActivityLocation(type: 'ONLINE', name: 'Zoom Link'),
        maxParticipants: 15,
      );
      expect(patch.containsKey('location'), isTrue);
      expect(patch['location']['type'], 'ONLINE');
      expect(patch['location']['name'], 'Zoom Link');
      expect(patch.containsKey('title'), isFalse);
    });
  });

  group('RSVP client rules', () {
    test('client cannot select server-only waitlist status', () {
      expect(ActivityRsvpStatus.waitlist.clientSelectable, isFalse);
      expect(ActivityRsvpStatus.going.clientSelectable, isTrue);
      expect(ActivityRsvpStatus.maybe.clientSelectable, isTrue);
      expect(ActivityRsvpStatus.notGoing.clientSelectable, isTrue);
      expect(ActivityRsvpStatus.noResponse.clientSelectable, isFalse);
    });

    test('wire mapping matches backend contract', () {
      expect(ActivityRsvpStatus.going.wire, 'GOING');
      expect(ActivityRsvpStatus.maybe.wire, 'MAYBE');
      expect(ActivityRsvpStatus.notGoing.wire, 'NOT_GOING');
      expect(ActivityRsvpStatus.waitlist.wire, 'WAITLIST');
      expect(ActivityRsvpStatus.noResponse.wire, 'NO_RESPONSE');

      expect(ActivityRsvpStatusWire.parse('GOING'), ActivityRsvpStatus.going);
      expect(ActivityRsvpStatusWire.parse('MAYBE'), ActivityRsvpStatus.maybe);
      expect(ActivityRsvpStatusWire.parse('NOT_GOING'), ActivityRsvpStatus.notGoing);
      expect(ActivityRsvpStatusWire.parse('WAITLIST'), ActivityRsvpStatus.waitlist);
      expect(() => ActivityRsvpStatusWire.parse('UNKNOWN'), throwsFormatException);
    });
  });

  group('ActivityParticipant DTO', () {
    test('decodes public-safe fields and waitlist sequence without private fields', () {
      final json = {
        'userId': 'usr-safe-1',
        'username': 'alice_w',
        'displayName': 'Alice Wonderland',
        'avatarStorageKey': 'avatars/alice.png',
        'rsvpStatus': 'WAITLIST',
        'waitlistSequence': 2,
        'createdAt': '2030-05-01T12:00:00Z',
      };

      final participant = ActivityParticipant.fromJson(json);

      expect(participant.userId, 'usr-safe-1');
      expect(participant.username, 'alice_w');
      expect(participant.displayName, 'Alice Wonderland');
      expect(participant.avatarStorageKey, 'avatars/alice.png');
      expect(participant.rsvpStatus, ActivityRsvpStatus.waitlist);
      expect(participant.waitlistSequence, 2);
    });
  });

  group('Multi-Day and Unscheduled Serialization', () {
    test('same-day activity preserves correct UTC/offset semantics', () {
      final start = DateTime.utc(2026, 3, 31, 7, 0); // 14:00 +07
      final end = DateTime.utc(2026, 3, 31, 10, 0); // 17:00 +07
      final draft = ActivityDraft(
        title: 'Same Day Run',
        startAt: start,
        endAt: end,
        timezone: 'Asia/Ho_Chi_Minh',
      );
      final json = draft.toCreateJson();
      expect(json['startAt'], '2026-03-31T07:00:00.000Z');
      expect(json['endAt'], '2026-03-31T10:00:00.000Z');
      expect(json['timezone'], 'Asia/Ho_Chi_Minh');

      final parsedStart = DateTime.parse(json['startAt'] as String);
      final parsedEnd = DateTime.parse(json['endAt'] as String);
      expect(parsedStart.isUtc, isTrue);
      expect(parsedEnd.isUtc, isTrue);
      expect(parsedEnd.isAfter(parsedStart), isTrue);
    });

    test('multi-day activity preserves correct UTC/offset across date boundaries', () {
      final start = DateTime.utc(2026, 3, 31, 7, 0); // 31-03 14:00 +07
      final end = DateTime.utc(2026, 4, 2, 3, 0); // 02-04 10:00 +07
      final draft = ActivityDraft(
        title: 'Multi-Day Trek',
        startAt: start,
        endAt: end,
        timezone: 'Asia/Ho_Chi_Minh',
      );
      final json = draft.toCreateJson();
      expect(json['startAt'], '2026-03-31T07:00:00.000Z');
      expect(json['endAt'], '2026-04-02T03:00:00.000Z');

      final parsedStart = DateTime.parse(json['startAt'] as String);
      final parsedEnd = DateTime.parse(json['endAt'] as String);
      expect(parsedEnd.difference(parsedStart).inHours, 44);
    });

    test('unscheduled activity serializes null startAt, endAt, timezone', () {
      final draft = ActivityDraft(title: 'Spontaneous Gathering');
      final json = draft.toCreateJson();
      expect(json['title'], 'Spontaneous Gathering');
      expect(json.containsKey('startAt'), isFalse);
      expect(json.containsKey('endAt'), isFalse);
      expect(json.containsKey('timezone'), isFalse);
    });
  });
}
