import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/paged_response.dart';
import 'package:mobile/features/groups/data/models/group_models.dart';

void main() {
  test('created group has only the create-response contract', () {
    final group = CreatedGroup.fromJson({
      'id': 'g',
      'name': 'Name',
      'description': null,
      'avatarStorageKey': null,
      'status': 'ACTIVE',
      'createdBy': 'creator',
      'createdAt': '2026-01-01T00:00:00Z',
      'updatedAt': '2026-01-01T00:00:00Z',
    });

    expect(group.createdBy, 'creator');
    expect(group.status, GroupStatus.active);
  });

  test(
    'GroupSummary decodes its exact contract including a nullable avatar',
    () {
      final summary = GroupSummary.fromJson({
        'id': 'g',
        'name': 'Name',
        'avatarStorageKey': null,
        'status': 'ARCHIVED',
        'callerRole': 'ADMIN',
        'updatedAt': '2026-01-02T00:00:00Z',
      });

      expect(summary.id, 'g');
      expect(summary.name, 'Name');
      expect(summary.avatarStorageKey, isNull);
      expect(summary.status, GroupStatus.archived);
      expect(summary.callerRole, GroupRole.admin);
      expect(summary.updatedAt, DateTime.utc(2026, 1, 2));
    },
  );

  test(
    'GroupDetail decodes its exact contract including nullable public fields',
    () {
      final detail = GroupDetail.fromJson({
        'id': 'g',
        'name': 'Name',
        'description': null,
        'avatarStorageKey': null,
        'status': 'ACTIVE',
        'ownerUserId': 'owner',
        'callerRole': 'OWNER',
        'createdAt': '2026-01-01T00:00:00Z',
        'updatedAt': '2026-01-02T00:00:00Z',
      });

      expect(detail.id, 'g');
      expect(detail.name, 'Name');
      expect(detail.description, isNull);
      expect(detail.avatarStorageKey, isNull);
      expect(detail.status, GroupStatus.active);
      expect(detail.ownerUserId, 'owner');
      expect(detail.callerRole, GroupRole.owner);
      expect(detail.createdAt, DateTime.utc(2026, 1, 1));
      expect(detail.updatedAt, DateTime.utc(2026, 1, 2));
    },
  );

  test('GroupMember and GroupSettings decode their exact contracts', () {
    final member = GroupMember.fromJson({
      'userId': 'u',
      'username': 'user',
      'displayName': 'User',
      'avatarStorageKey': null,
      'role': 'MEMBER',
      'joinedAt': '2026-01-01T00:00:00Z',
    });
    final settings = GroupSettings.fromJson({
      'groupId': 'g',
      'joinPolicy': 'APPROVAL_REQUIRED',
      'memberModifyInfoAllowed': false,
      'memberCreateActivityAllowed': true,
      'memberPinMessageAllowed': false,
      'chatHistoryPolicy': 'FROM_JOIN_TIME',
      'updatedAt': '2026-01-02T00:00:00Z',
    });

    expect(member.userId, 'u');
    expect(member.username, 'user');
    expect(member.displayName, 'User');
    expect(member.avatarStorageKey, isNull);
    expect(member.role, GroupRole.member);
    expect(member.joinedAt, DateTime.utc(2026, 1, 1));
    expect(settings.groupId, 'g');
    expect(settings.joinPolicy, GroupJoinPolicy.approvalRequired);
    expect(settings.memberModifyInfoAllowed, isFalse);
    expect(settings.memberCreateActivityAllowed, isTrue);
    expect(settings.memberPinMessageAllowed, isFalse);
    expect(settings.chatHistoryPolicy, ChatHistoryPolicy.fromJoinTime);
    expect(settings.updatedAt, DateTime.utc(2026, 1, 2));
  });

  test('PagedResponse decodes ordered GroupSummary items and metadata', () {
    final page = PagedResponse.fromJson({
      'items': [
        {
          'id': 'first',
          'name': 'First',
          'avatarStorageKey': null,
          'status': 'ACTIVE',
          'callerRole': 'MEMBER',
          'updatedAt': '2026-01-01T00:00:00Z',
        },
        {
          'id': 'second',
          'name': 'Second',
          'avatarStorageKey': 'avatars/second',
          'status': 'ARCHIVED',
          'callerRole': 'ADMIN',
          'updatedAt': '2026-01-02T00:00:00Z',
        },
      ],
      'page': 2,
      'size': 30,
      'totalElements': 91,
      'totalPages': 4,
      'hasNext': true,
    }, GroupSummary.fromJson);

    expect(page.items.map((item) => item.id), ['first', 'second']);
    expect(page.items[1].avatarStorageKey, 'avatars/second');
    expect(page.page, 2);
    expect(page.size, 30);
    expect(page.totalElements, 91);
    expect(page.totalPages, 4);
    expect(page.hasNext, isTrue);
  });

  test('wire enums reject unknown server values', () {
    expect(() => GroupStatus.fromWire('FUTURE'), throwsFormatException);
    expect(() => GroupRole.fromWire('FUTURE'), throwsFormatException);
    expect(() => GroupJoinPolicy.fromWire('FUTURE'), throwsFormatException);
    expect(() => ChatHistoryPolicy.fromWire('FUTURE'), throwsFormatException);
  });

  test('patch requests omit absent fields and settings preserve false', () {
    expect(const UpdateGroupRequest(name: 'Renamed').toJson(), {
      'name': 'Renamed',
    });
    expect(
      const UpdateGroupSettingsRequest(
        memberModifyInfoAllowed: false,
        memberCreateActivityAllowed: false,
        memberPinMessageAllowed: false,
      ).toJson(),
      {
        'memberModifyInfoAllowed': false,
        'memberCreateActivityAllowed': false,
        'memberPinMessageAllowed': false,
      },
    );
    expect(const TransferOwnershipRequest('new-owner').toJson(), {
      'newOwnerUserId': 'new-owner',
    });
  });
}
