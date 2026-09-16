package com.wedo.backend.activity.listener;

import com.wedo.backend.activity.repository.ActivityParticipantRepository;
import com.wedo.backend.activity.service.ActivityMembershipLossProcessor;
import com.wedo.backend.group.event.GroupMembershipEndedEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
public class GroupMembershipEndedActivityListener {
    private final ActivityParticipantRepository participants; private final ActivityMembershipLossProcessor processor;
    public GroupMembershipEndedActivityListener(ActivityParticipantRepository participants,ActivityMembershipLossProcessor processor){this.participants=participants;this.processor=processor;}
    @TransactionalEventListener(phase=TransactionPhase.AFTER_COMMIT)
    public void onMembershipEnded(GroupMembershipEndedEvent event){participants.findOpenActivityIdsByGroupIdAndUserId(event.groupId(),event.userId()).forEach(id->processor.processOne(event,id));}
}
