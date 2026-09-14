import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/groups/data/models/group_models.dart';

void main() {
  group('remaining M5 request contracts', () {
    test('edit sends only changed name', () {
      expect(const UpdateGroupRequest(name: 'N').toJson(), {'name': 'N'});
    });
    test('edit blank description deliberately clears it', () {
      expect(const UpdateGroupRequest(description: '').toJson(), {
        'description': '',
      });
    });
    test('edit blank avatar key deliberately clears it', () {
      expect(const UpdateGroupRequest(avatarStorageKey: '').toJson(), {
        'avatarStorageKey': '',
      });
    });
    test('permissions serialise explicit false', () {
      expect(
        const UpdateGroupSettingsRequest(memberModifyInfoAllowed: false)
            .toJson(),
        {'memberModifyInfoAllowed': false},
      );
    });
    test('permissions send join policy', () {
      expect(
        const UpdateGroupSettingsRequest(
          joinPolicy: GroupJoinPolicy.approvalRequired,
        ).toJson(),
        {'joinPolicy': 'APPROVAL_REQUIRED'},
      );
    });
    test('permissions send chat-history policy', () {
      expect(
        const UpdateGroupSettingsRequest(
          chatHistoryPolicy: ChatHistoryPolicy.fromJoinTime,
        ).toJson(),
        {'chatHistoryPolicy': 'FROM_JOIN_TIME'},
      );
    });
    test('transfer uses exact owner id body', () {
      expect(const TransferOwnershipRequest('member-id').toJson(), {
        'newOwnerUserId': 'member-id',
      });
    });
    test('roles have no manager role', () {
      expect(GroupRole.values.map((e) => e.wireValue), [
        'OWNER',
        'ADMIN',
        'MEMBER',
      ]);
    });
  });
}
