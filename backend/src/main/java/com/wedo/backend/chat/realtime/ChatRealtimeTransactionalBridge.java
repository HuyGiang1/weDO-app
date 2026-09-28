package com.wedo.backend.chat.realtime;

import com.wedo.backend.chat.realtime.ChatRealtimeEvents.DomainMutationEvent;
import com.wedo.backend.chat.realtime.ChatRealtimeEvents.DomainReadEvent;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
public class ChatRealtimeTransactionalBridge {
    private final ChatRealtimeCoordinator coordinator;

    public ChatRealtimeTransactionalBridge(ChatRealtimeCoordinator coordinator) {
        this.coordinator = coordinator;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onDomainMutationAfterCommit(DomainMutationEvent event) {
        coordinator.onAfterCommitMutation(event);
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onDomainReadAfterCommit(DomainReadEvent event) {
        coordinator.onAfterCommitRead(event);
    }
}
