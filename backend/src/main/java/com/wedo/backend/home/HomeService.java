package com.wedo.backend.home;

import com.wedo.backend.expense.service.ExpenseService;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.service.GroupService;
import com.wedo.backend.home.HomeDtos.FinanceSummary;
import com.wedo.backend.home.HomeDtos.GroupBalance;
import com.wedo.backend.home.HomeDtos.RequiredAction;
import com.wedo.backend.notification.dto.NotificationDtos.NotificationItemResponse;
import com.wedo.backend.notification.service.NotificationService;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class HomeService {
    private final GroupService groups;
    private final HomeQueryRepository queries;
    private final ExpenseService expenses;
    private final NotificationService notifications;
    private final Clock clock;

    public HomeService(GroupService groups, HomeQueryRepository queries,
                       ExpenseService expenses, NotificationService notifications, Clock clock) {
        this.groups = groups;
        this.queries = queries;
        this.expenses = expenses;
        this.notifications = notifications;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public HomeDtos.Response get(UUID userId) {
        Instant now = clock.instant();
        var recent = groups.getGroups(userId, 0, 5, GroupStatus.ACTIVE).items();
        var balances = expenses.homeBalances(userId);
        BigDecimal owedByMe = balances.stream().map(ExpenseService.GroupBalanceTotal::owedByMe)
                .reduce(new BigDecimal("0.00"), BigDecimal::add);
        BigDecimal owedToMe = balances.stream().map(ExpenseService.GroupBalanceTotal::owedToMe)
                .reduce(new BigDecimal("0.00"), BigDecimal::add);
        List<GroupBalance> financeGroups = balances.stream()
                .filter(balance -> balance.owedByMe().signum() != 0 || balance.owedToMe().signum() != 0)
                .sorted(Comparator.comparing(ExpenseService.GroupBalanceTotal::groupName)
                        .thenComparing(balance -> balance.groupId().toString()))
                .limit(4)
                .map(balance -> new GroupBalance(balance.groupId(), balance.groupName(),
                        balance.owedByMe(), balance.owedToMe()))
                .toList();
        List<RequiredAction> actions = queries.actions(userId, now);
        List<NotificationItemResponse> updates = notifications.listNotifications(userId, 0, 30).items()
                .stream().filter(item -> item.target().actionable()).limit(5).toList();
        return new HomeDtos.Response(recent, queries.upcoming(userId, now),
                new FinanceSummary(owedByMe, owedToMe, financeGroups), actions, updates);
    }

    @Transactional(readOnly = true)
    public List<RequiredAction> actionsRequired(UUID userId) {
        groups.getGroups(userId, 0, 1, GroupStatus.ACTIVE);
        return queries.actions(userId, clock.instant());
    }
}
