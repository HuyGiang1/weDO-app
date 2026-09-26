import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/groups/application/group_management_controllers.dart';
import 'package:mobile/features/groups/data/group_api.dart';
import 'package:mobile/features/groups/data/group_repository.dart';
import 'package:mobile/features/groups/data/models/group_models.dart';
import 'package:mobile/features/groups/presentation/screens/group_management_screens.dart';
import 'package:mobile/features/groups/presentation/widgets/group_widgets.dart';

void main() {
  group('GroupAvatar widget', () {
    testWidgets('renders initials fallback when avatarStorageKey is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GroupAvatar(name: 'weDO Core Team', radius: 32),
          ),
        ),
      );

      expect(find.text('W'), findsOneWidget);
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('renders memory image when imageBytes is provided', (tester) async {
      // 1x1 transparent GIF bytes
      final bytes = Uint8List.fromList([
        0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00,
        0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0x21,
        0xf9, 0x04, 0x01, 0x00, 0x00, 0x00, 0x00, 0x2c, 0x00, 0x00,
        0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x02, 0x01, 0x44,
        0x00, 0x3b
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupAvatar(
              name: 'weDO Core Team',
              radius: 32,
              imageBytes: bytes,
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });

    test('resolvedUrl resolves full url correctly', () {
      const avatar = GroupAvatar(
        name: 'weDO',
        avatarStorageKey: 'avatars/test-key.jpg',
        baseUrl: 'https://api.wedo.local',
      );

      expect(avatar.resolvedUrl, 'https://api.wedo.local/api/v1/media/avatars/test-key.jpg');
    });

    test('resolvedUrl respects absolute URLs unchanged', () {
      const avatar = GroupAvatar(
        name: 'weDO',
        avatarStorageKey: 'https://cdn.wedo.local/images/avatar.png',
      );

      expect(avatar.resolvedUrl, 'https://cdn.wedo.local/images/avatar.png');
    });
  });

  group('EditGroupScreen avatar integration', () {
    testWidgets('displays Ảnh nhóm label and Chọn ảnh button when no avatar', (tester) async {
      final repo = _MockGroupRepo(avatarKey: null);
      final controller = EditGroupController(repo);

      await tester.pumpWidget(
        MaterialApp(
          home: EditGroupScreen(
            groupId: 'test-group',
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ảnh nhóm'), findsOneWidget);
      expect(find.text('Chọn ảnh'), findsOneWidget);
      expect(find.text('weDO Community'), findsOneWidget);
      expect(find.text('Lưu thay đổi'), findsOneWidget);
    });

    testWidgets('displays Đổi ảnh button when group already has avatar', (tester) async {
      final repo = _MockGroupRepo(avatarKey: 'avatars/existing.jpg');
      final controller = EditGroupController(repo);

      await tester.pumpWidget(
        MaterialApp(
          home: EditGroupScreen(
            groupId: 'test-group',
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ảnh nhóm'), findsOneWidget);
      expect(find.text('Đổi ảnh'), findsOneWidget);
    });

    testWidgets('saving form passes avatarStorageKey to updateGroup and pops result', (tester) async {
      final repo = _MockGroupRepo(avatarKey: 'avatars/saved-avatar.png');
      final controller = EditGroupController(repo);
      GroupDetail? poppedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final res = await Navigator.of(context).push<GroupDetail>(
                  MaterialPageRoute(
                    builder: (_) => EditGroupScreen(
                      groupId: 'test-group',
                      controller: controller,
                    ),
                  ),
                );
                poppedResult = res;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap 'Lưu thay đổi'
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();

      expect(repo.lastUpdateRequest, isNotNull);
      expect(repo.lastUpdateRequest?.avatarStorageKey, 'avatars/saved-avatar.png');
      expect(poppedResult, isNotNull);
      expect(poppedResult?.avatarStorageKey, 'avatars/saved-avatar.png');
    });
  });
}

class _MockGroupRepo extends GroupRepository {
  final String? avatarKey;
  UpdateGroupRequest? lastUpdateRequest;

  _MockGroupRepo({this.avatarKey}) : super(api: GroupApi(Dio()));

  @override
  Future<GroupDetail> getGroup(String id) async => GroupDetail(
    id: id,
    name: 'weDO Community',
    description: 'A community group',
    avatarStorageKey: avatarKey,
    status: GroupStatus.active,
    ownerUserId: 'user-owner',
    callerRole: GroupRole.owner,
    createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
    updatedAt: DateTime.parse('2026-01-02T00:00:00Z'),
  );

  @override
  Future<GroupDetail> updateGroup(String id, UpdateGroupRequest q) async {
    lastUpdateRequest = q;
    return GroupDetail(
      id: id,
      name: q.name ?? 'weDO Community',
      description: q.description,
      avatarStorageKey: q.avatarStorageKey ?? avatarKey,
      status: GroupStatus.active,
      ownerUserId: 'user-owner',
      callerRole: GroupRole.owner,
      createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
      updatedAt: DateTime.parse('2026-01-03T00:00:00Z'),
    );
  }

  @override
  Future<String> uploadGroupAvatar({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    return 'avatars/mock-uploaded.jpg';
  }
}
