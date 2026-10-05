package com.wedo.backend.home;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.wedo.backend.group.dto.GroupSummaryResponse;
import com.wedo.backend.notification.dto.NotificationDtos.NotificationItemResponse;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class HomeDtos {
    private HomeDtos() { }

    public record Response(List<GroupSummaryResponse> recentGroups,
                           List<UpcomingActivity> upcomingActivities,
                           FinanceSummary financeSummary,
                           List<RequiredAction> actionsRequired,
                           List<NotificationItemResponse> recentUpdates) { }

    public record UpcomingActivity(UUID id, UUID groupId, String groupName,
                                   String title, String status, Instant startAt) { }

    public record FinanceSummary(
            @JsonFormat(shape = JsonFormat.Shape.STRING) BigDecimal totalOwedByMe,
            @JsonFormat(shape = JsonFormat.Shape.STRING) BigDecimal totalOwedToMe,
            List<GroupBalance> groups) { }

    public record GroupBalance(UUID groupId, String groupName,
                               @JsonFormat(shape = JsonFormat.Shape.STRING) BigDecimal owedByMe,
                               @JsonFormat(shape = JsonFormat.Shape.STRING) BigDecimal owedToMe) { }

    public record RequiredAction(String type, UUID targetId, UUID groupId,
                                 UUID activityId, String title, Instant dueAt) { }
}
