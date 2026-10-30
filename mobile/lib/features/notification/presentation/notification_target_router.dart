import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../activity/data/activity_api.dart';
import '../../activity/data/activity_repository.dart';
import '../../chat/data/chat_api.dart';
import '../../chat/data/chat_repository.dart';
import '../../expense/data/expense_api.dart';
import '../../expense/data/expense_repository.dart';
import '../../expense/presentation/expense_screens.dart';
import '../../fund/data/fund_api.dart';
import '../../fund/data/fund_repository.dart';
import '../../groups/data/group_repository.dart';
import '../data/notification_models.dart';

abstract final class NotificationTargetRouter {
  static Future<void> open({
    BuildContext? context,
    NavigatorState? navigator,
    required NotificationItemModel item,
    required GroupRepository? groupRepository,
  }) async {
    final NavigatorState? nav =
        navigator ?? (context != null ? Navigator.maybeOf(context) : null);
    if (nav == null) return;

    final NotificationTargetModel target = item.target;
    if (!target.actionable) {
      final BuildContext dialogContext = context ?? nav.context;
      await showDialog<void>(
        context: dialogContext,
        builder: (BuildContext dContext) => AlertDialog(
          title: const Text('Không thể mở liên kết'),
          content: Text(
            target.nonActionableReason ??
                'Mục liên kết này không còn khả dụng hoặc đã bị xóa.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dContext).pop(),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
      return;
    }

    final GroupRepository? groups = groupRepository;
    if (groups == null) return;
    final String? groupId = item.group?.groupId;
    final String groupName = item.group?.groupName ?? 'Nhóm weDO';
    final String route = target.route.trim();
    final String type = target.targetType.toUpperCase();

    if (type == 'SOCIAL') {
      await nav.pushNamed(
        AppRoutes.friends,
        arguments: GroupsRouteArgs(repository: groups),
      );
      return;
    }

    if (type == 'CONVERSATION' && (groupId == null || groupId.isEmpty)) {
      await nav.pushNamed(
        AppRoutes.chatHome,
        arguments: ChatHomeRouteArgs(
          ChatRepository(ChatApi(groups.api.dio)),
          groups,
        ),
      );
      return;
    }
    if (groupId == null) return;

    if (route == AppRoutes.groupFund) {
      await nav.pushNamed(
        AppRoutes.groupFund,
        arguments: FundRouteArgs(
          repository: FundRepository(FundApi(groups.api.dio)),
          groupRepository: groups,
          groupId: groupId,
          groupName: groupName,
        ),
      );
      return;
    }
    if (route == AppRoutes.groupExpenses) {
      await nav.pushNamed(
        AppRoutes.groupExpenses,
        arguments: ExpenseRouteArgs(
          repository: ExpenseRepository(ExpenseApi(groups.api.dio)),
          groupRepository: groups,
          groupId: groupId,
        ),
      );
      return;
    }
    if (type == 'EXPENSE' && _hasTargetId(target)) {
      await nav.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ExpenseDetailScreen(
            groupId: groupId,
            expenseId: target.targetId!,
            repository: ExpenseRepository(ExpenseApi(groups.api.dio)),
            groupRepository: groups,
          ),
        ),
      );
      return;
    }
    if (type == 'SETTLEMENT' && _hasTargetId(target)) {
      await nav.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SettlementDetailScreen(
            groupId: groupId,
            settlementId: target.targetId!,
            repository: ExpenseRepository(ExpenseApi(groups.api.dio)),
          ),
        ),
      );
      return;
    }
    if (route == AppRoutes.groupInvitations) {
      await nav.pushNamed(
        AppRoutes.groupInvitations,
        arguments: GroupsRouteArgs(repository: groups),
      );
      return;
    }
    if (type == 'CONVERSATION') {
      await nav.pushNamed(
        AppRoutes.groupChat,
        arguments: ChatRouteArgs(
          repository: ChatRepository(ChatApi(groups.api.dio)),
          groupId: groupId,
          groupRepository: groups,
        ),
      );
      return;
    }
    if (route == AppRoutes.activities || route == AppRoutes.activityDetail) {
      final ActivityRepository activities = ActivityRepository(
        api: ActivityApi(groups.api.dio),
      );
      final String? activityId = type == 'ACTIVITY'
          ? target.targetId
          : target.params['activityId']?.toString();
      if (activityId != null && activityId.isNotEmpty) {
        await nav.pushNamed(
          AppRoutes.activityDetail,
          arguments: ActivityDetailRouteArgs(
            repository: activities,
            activityId: activityId,
          ),
        );
      } else {
        await nav.pushNamed(
          AppRoutes.activities,
          arguments: ActivitiesRouteArgs(
            repository: activities,
            groupId: groupId,
          ),
        );
      }
      return;
    }
    await nav.pushNamed(
      AppRoutes.groupInfo,
      arguments: GroupInfoRouteArgs(repository: groups, groupId: groupId),
    );
  }

  static bool _hasTargetId(NotificationTargetModel target) =>
      target.targetId != null && target.targetId!.isNotEmpty;
}
