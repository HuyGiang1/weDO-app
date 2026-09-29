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
    required BuildContext context,
    required NotificationItemModel item,
    required GroupRepository? groupRepository,
  }) async {
    final NotificationTargetModel target = item.target;
    if (!target.actionable) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('KhÃ´ng thá»ƒ má»Ÿ liÃªn káº¿t'),
          content: Text(
            target.nonActionableReason ?? 'Má»¥c liÃªn káº¿t nÃ y khÃ´ng cÃ²n kháº£ dá»¥ng hoáº·c Ä‘Ã£ bá»‹ xÃ³a.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('ÄÃ£ hiá»ƒu'),
            ),
          ],
        ),
      );
      return;
    }

    final GroupRepository? groups = groupRepository;
    if (groups == null) return;
    final String? groupId = item.group?.groupId;
    final String groupName = item.group?.groupName ?? 'NhÃ³m WeDo';
    final String route = target.route.trim();
    final String type = target.targetType.toUpperCase();

    if (type == 'CONVERSATION' && (groupId == null || groupId.isEmpty)) {
      await Navigator.of(context).pushNamed(
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
      await Navigator.of(context).pushNamed(
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
      await Navigator.of(context).pushNamed(
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
      await Navigator.of(context).push<void>(
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
      await Navigator.of(context).push<void>(
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
      await Navigator.of(context).pushNamed(
        AppRoutes.groupInvitations,
        arguments: GroupsRouteArgs(repository: groups),
      );
      return;
    }
    if (type == 'CONVERSATION') {
      await Navigator.of(context).pushNamed(
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
        await Navigator.of(context).pushNamed(
          AppRoutes.activityDetail,
          arguments: ActivityDetailRouteArgs(
            repository: activities,
            activityId: activityId,
          ),
        );
      } else {
        await Navigator.of(context).pushNamed(
          AppRoutes.activities,
          arguments: ActivitiesRouteArgs(
            repository: activities,
            groupId: groupId,
          ),
        );
      }
      return;
    }
    await Navigator.of(context).pushNamed(
      AppRoutes.groupInfo,
      arguments: GroupInfoRouteArgs(repository: groups, groupId: groupId),
    );
  }

  static bool _hasTargetId(NotificationTargetModel target) =>
      target.targetId != null && target.targetId!.isNotEmpty;
}
