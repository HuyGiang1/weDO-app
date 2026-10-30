import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/groups/application/group_admission_controllers.dart';
import 'package:mobile/features/groups/data/group_api.dart';
import 'package:mobile/features/groups/data/group_repository.dart';
import 'package:mobile/features/groups/data/group_failure.dart';
import 'package:mobile/features/groups/data/models/group_models.dart';
import 'package:mobile/features/groups/presentation/screens/group_admission_screens.dart';

GroupInviteSummaryResponse summary({bool member = false, bool pending = false}) => GroupInviteSummaryResponse(
  groupId: 'g', groupName: 'QA Group', activeMemberCount: 2,
  joinPolicy: GroupJoinPolicy.approvalRequired, alreadyMember: member, requestPending: pending);

class Repo extends GroupRepository {
  bool member = false, pending = false;
  int joins = 0, reads = 0;
  GroupFailureType? race;
  final queue = <Completer<GroupInviteSummaryResponse>>[];
  Repo() : super(api: GroupApi(Dio()));
  @override
  Future<GroupInviteSummaryResponse> resolveInviteCode(String code) async {
    reads++;
    if (queue.isNotEmpty) return queue.removeAt(0).future;
    return summary(member: member, pending: pending);
  }
  @override
  Future<void> joinViaInviteCode(String code) async {
    joins++;
    if (race != null) {
      member = race == GroupFailureType.alreadyGroupMember;
      pending = race == GroupFailureType.joinRequestAlreadyPending;
      throw GroupException(GroupFailure(race!));
    }
    pending = true;
  }
}

void main() {
  for (final member in [true, false]) {
    testWidgets('invite shows existing ${member ? 'member' : 'pending'} state without join', (t) async {
      await t.binding.setSurfaceSize(const Size(800, 1100));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final repo = Repo()..member = member..pending = !member;
      String? opened;
      await t.pumpWidget(MaterialApp(home: JoinByInviteCodeScreen(
        controller: JoinByCodeController(repo), initialCode: 'QaX7Mix1', onOpenGroup: (id) => opened = id)));
      await t.pumpAndSettle();
      expect(find.text(member ? 'Bạn đã ở trong nhóm này.' : 'Yêu cầu của bạn đang chờ duyệt.'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Yêu cầu tham gia'), findsNothing);
      if (member) {
        await t.ensureVisible(find.text('Vào nhóm'));
        await t.tap(find.text('Vào nhóm'));
        expect(opened, 'g');
      }
      expect(repo.joins, 0);
    });
  }
  for (final race in [GroupFailureType.alreadyGroupMember, GroupFailureType.joinRequestAlreadyPending]) {
    test('concurrent $race refreshes state once and does not replay admission', () async {
      final repo = Repo()..race = race;
      final c = JoinByCodeController(repo);
      await c.resolve('code');
      expect(await c.join('code'), isFalse);
      expect(c.value.failure, isNull);
      expect(c.value.data!.alreadyMember, race == GroupFailureType.alreadyGroupMember);
      expect(c.value.data!.requestPending, race == GroupFailureType.joinRequestAlreadyPending);
      expect(repo.reads, 2);
      expect(repo.joins, 1);
      expect(await c.join('code'), isFalse);
      expect(repo.joins, 1);
      c.dispose();
    });
  }
  test('eligible applicant submits once and later resolves as pending', () async {
    final repo = Repo(); final c = JoinByCodeController(repo);
    await c.resolve('code'); expect(await c.join('code'), isTrue);
    await c.resolve('code'); expect(c.value.data!.requestPending, isTrue);
    expect(await c.join('code'), isFalse); expect(repo.joins, 1); c.dispose();
  });
  test('late and disposed previews do not replace newer state', () async {
    final first = Completer<GroupInviteSummaryResponse>(), second = Completer<GroupInviteSummaryResponse>();
    final repo = Repo()..queue.addAll([first, second]); final c = JoinByCodeController(repo);
    final old = c.resolve('old'), newer = c.resolve('new');
    second.complete(summary(member: true)); await newer;
    first.complete(summary()); await old;
    expect(c.value.data!.alreadyMember, isTrue);
    final last = Completer<GroupInviteSummaryResponse>(); repo.queue.add(last);
    final request = c.resolve('last'); c.dispose(); last.complete(summary());
    expect(await request, isNull);
  });
}
