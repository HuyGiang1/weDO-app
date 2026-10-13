package com.wedo.backend.notification.event;

import com.wedo.backend.chat.realtime.ChatRealtimeEvents;
import com.wedo.backend.common.event.PostCommitDelivery;
import com.wedo.backend.notification.service.NotificationService;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
public class NotificationDomainEventListener {

    private final NotificationService notificationService;
    private final PostCommitDelivery delivery;

    public NotificationDomainEventListener(NotificationService notificationService, PostCommitDelivery delivery) {
        this.notificationService = notificationService;
        this.delivery = delivery;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onNotificationDomainEvent(NotificationDomainEvent event) {
        delivery.submit("notification", event.targetId(), () -> notificationService.processDomainEvent(event));
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onChatDomainMutationEvent(ChatRealtimeEvents.DomainMutationEvent event) {
        if ("MESSAGE_CREATED".equals(event.type())) {
            delivery.submit("chat-inbox", event.messageId(), () -> notificationService.processChatMutationEvent(event));
        }
    }
}
