package com.wedo.backend.realtime;

import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionSynchronizationManager;

@Component
public class RealtimePublisher {
    private final ApplicationEventPublisher events;

    public RealtimePublisher(ApplicationEventPublisher events) { this.events = events; }

    public void activity(String type, UUID activityId, UUID groupId, UUID actorId) {
        publish(DomainRealtimeEvent.changed(type, "ACTIVITY", activityId, groupId,
                actorId, "activity:" + activityId));
    }

    public void group(String type, UUID groupId, UUID actorId) {
        publish(DomainRealtimeEvent.changed(type, "GROUP", groupId, groupId,
                actorId, "group:" + groupId));
    }

    public void activityResource(String type, String aggregateType, UUID resourceId,
            UUID activityId, UUID groupId, UUID actorId) {
        resource(type, aggregateType, resourceId, "activity:" + activityId, groupId, actorId);
    }

    public void resource(String type, String aggregateType, UUID id, String scope, UUID groupId, UUID actorId) {
        publish(DomainRealtimeEvent.changed(type, aggregateType, id, groupId, actorId, scope));
    }

    public void user(String type, UUID userId) {
        publish(DomainRealtimeEvent.changed(type, "USER", userId, null,
                null, "user:" + userId));
    }

    /** A privacy change that cannot alter anyone else's Community eligibility graph. */
    public void userRecipientPolicy(String type, UUID userId) {
        var event=DomainRealtimeEvent.changed(type,"USER",userId,null,null,"user:"+userId);
        publish(new DomainRealtimeEvent(event.eventId(),event.type(),event.eventType(),event.aggregateType(),
            event.aggregateId(),null,null,event.scope(),event.occurredAt(),
            java.util.Map.of("communityPolicyScope","RECIPIENT_ONLY")));
    }

    @org.springframework.context.event.EventListener
    public void membershipEnded(com.wedo.backend.group.event.GroupMembershipEndedEvent event) {
        group("GROUP_MEMBER_LEFT", event.groupId(), null);
        user("GROUP_MEMBERSHIP_CHANGED", event.userId());
    }

    public void publish(DomainRealtimeEvent event) {
        // Fail closed: a caller outside a real write transaction must never broadcast.
        if (!TransactionSynchronizationManager.isActualTransactionActive()
                || TransactionSynchronizationManager.isCurrentTransactionReadOnly()) {
            throw new IllegalStateException("Realtime changes require a write transaction");
        }
        events.publishEvent(event);
    }
}
