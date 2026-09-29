package com.wedo.backend.notification.event;

import com.wedo.backend.chat.realtime.ChatRealtimeEvents;
import com.wedo.backend.notification.service.NotificationService;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
public class NotificationDomainEventListener {

    private final NotificationService notificationService;

    public NotificationDomainEventListener(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onNotificationDomainEvent(NotificationDomainEvent event) {
        try {
            notificationService.processDomainEvent(event);
        } catch (RuntimeException ignored) {
            // Never propagate notification/push exceptions back to business transactions
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onChatDomainMutationEvent(ChatRealtimeEvents.DomainMutationEvent event) {
        try {
            notificationService.processChatMutationEvent(event);
        } catch (RuntimeException ignored) {
            // Never propagate notification/push exceptions back to chat mutations
        }
    }
}
