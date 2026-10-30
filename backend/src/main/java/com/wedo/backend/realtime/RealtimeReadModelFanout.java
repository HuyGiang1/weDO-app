package com.wedo.backend.realtime;

import com.wedo.backend.common.event.PostCommitDelivery;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/** Invalidates bounded personal read models even when a changed group is not on screen. */
@Component
@org.springframework.boot.autoconfigure.condition.ConditionalOnProperty(
        name = "wedo.realtime.read-model-fanout-enabled", havingValue = "true", matchIfMissing = true)
public class RealtimeReadModelFanout {
    private final JdbcTemplate jdbc;
    private final DomainRealtimeCoordinator coordinator;
    private final PostCommitDelivery delivery;

    public RealtimeReadModelFanout(JdbcTemplate jdbc, DomainRealtimeCoordinator coordinator, PostCommitDelivery delivery) {
        this.jdbc = jdbc; this.coordinator = coordinator; this.delivery = delivery;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void afterCommit(DomainRealtimeEvent event) {
        if (event.scope().startsWith("user:")) return;
        String type = event.eventType();
        boolean group = type.startsWith("GROUP_");
        boolean activity = type.startsWith("ACTIVITY_") && !type.startsWith("ACTIVITY_STOP_");
        boolean home = group || activity || type.startsWith("POLL_") || type.startsWith("TASK_")
                || type.startsWith("EXPENSE_") || type.startsWith("SETTLEMENT_");
        if (!home) return;
        delivery.submit("realtime-read-models", event.aggregateId(), () -> {
            UUID groupId = event.groupId();
            if (groupId == null && event.scope().startsWith("activity:")) {
                var groups = jdbc.queryForList("SELECT group_id FROM activities WHERE id=?", UUID.class,
                        UUID.fromString(event.scope().substring("activity:".length())));
                if (groups.isEmpty()) return;
                groupId = groups.getFirst();
            }
            if (groupId == null) return;
            List<UUID> members = jdbc.queryForList("SELECT user_id FROM group_memberships WHERE group_id=? AND status='ACTIVE'", UUID.class, groupId);
            for (UUID member : members) {
                boolean accessChanged = group && !type.equals("GROUP_UPDATED")
                        && !type.startsWith("GROUP_JOIN_") && !type.equals("GROUP_MEMBER_JOINED");
                emit(event, member, accessChanged ? "HOME_ACCESS_CHANGED" : "HOME_CHANGED");
                if (group || activity) emit(event, member, accessChanged ? "CALENDAR_ACCESS_CHANGED" : "CALENDAR_CHANGED");
                if (group) emit(event, member, "GROUP_LIST_CHANGED");
            }
        });
    }

    private void emit(DomainRealtimeEvent original, UUID member, String type) {
        UUID id = UUID.nameUUIDFromBytes((original.eventId() + ":" + member + ":" + type).getBytes(StandardCharsets.UTF_8));
        // No group ID, actor, business contents, or existence information is disclosed.
        // A membership race only causes a harmless REST reload of the user's own read model.
        coordinator.publish(new DomainRealtimeEvent(id, "DOMAIN_CHANGED", type, "USER", member,
                null, null, "user:" + member, original.occurredAt(), Map.of()));
    }
}
