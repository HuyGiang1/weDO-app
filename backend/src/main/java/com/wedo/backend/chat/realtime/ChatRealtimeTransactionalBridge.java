package com.wedo.backend.chat.realtime;

import com.wedo.backend.chat.realtime.ChatRealtimeEvents.DomainMutationEvent;
import com.wedo.backend.chat.realtime.ChatRealtimeEvents.DomainReadEvent;
import com.wedo.backend.common.event.PostCommitDelivery;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
public class ChatRealtimeTransactionalBridge {
    private final ChatRealtimeCoordinator coordinator;
    private final PostCommitDelivery delivery;

    public ChatRealtimeTransactionalBridge(ChatRealtimeCoordinator coordinator, PostCommitDelivery delivery) {
        this.coordinator = coordinator;
        this.delivery = delivery;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onDomainMutationAfterCommit(DomainMutationEvent event) {
        delivery.submit("chat-realtime", event.messageId(), () -> coordinator.onAfterCommitMutation(event));
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onDomainReadAfterCommit(DomainReadEvent event) {
        delivery.submit("chat-read", event.conversationId(), () -> coordinator.onAfterCommitRead(event));
    }
}
