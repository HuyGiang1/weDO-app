package com.wedo.backend.activity.listener;

import static org.mockito.Mockito.*;

import com.wedo.backend.activity.repository.ActivityParticipantRepository;
import com.wedo.backend.activity.service.ActivityMembershipLossProcessor;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.event.GroupMembershipEndedEvent;
import java.time.Instant;
import java.util.*;
import org.junit.jupiter.api.Test;

class GroupMembershipEndedActivityListenerTest {
    @Test void afterCommitListenerOnlyDelegatesEachOpenActivityToProcessor() {
        ActivityParticipantRepository participants=mock(ActivityParticipantRepository.class);
        ActivityMembershipLossProcessor processor=mock(ActivityMembershipLossProcessor.class);
        GroupMembershipEndedActivityListener listener=new GroupMembershipEndedActivityListener(participants,processor);
        UUID group=UUID.randomUUID(), user=UUID.randomUUID(), first=UUID.randomUUID(), second=UUID.randomUUID();
        GroupMembershipEndedEvent event=new GroupMembershipEndedEvent(UUID.randomUUID(),group,user,null,GroupMembershipStatus.KICKED,Instant.now());
        when(participants.findOpenActivityIdsByGroupIdAndUserId(group,user)).thenReturn(List.of(first,second));
        listener.onMembershipEnded(event);
        verify(processor).processOne(event,first); verify(processor).processOne(event,second);
        verifyNoMoreInteractions(processor);
    }
}
