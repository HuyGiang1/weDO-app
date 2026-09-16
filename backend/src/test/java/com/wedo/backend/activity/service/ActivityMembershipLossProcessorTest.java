package com.wedo.backend.activity.service;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.wedo.backend.activity.entity.*;
import com.wedo.backend.activity.repository.*;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.event.GroupMembershipEndedEvent;
import com.wedo.backend.group.repository.GroupRepository;
import java.time.Instant;
import java.util.*;
import org.junit.jupiter.api.Test;

class ActivityMembershipLossProcessorTest {
    private final GroupRepository groups=mock(GroupRepository.class);
    private final ActivityRepository activities=mock(ActivityRepository.class);
    private final ActivityParticipantRepository participants=mock(ActivityParticipantRepository.class);
    private final ActivityRsvpHistoryRepository histories=mock(ActivityRsvpHistoryRepository.class);
    private final ActivityRsvpService rsvps=mock(ActivityRsvpService.class);
    private final ActivityMembershipLossProcessor processor=new ActivityMembershipLossProcessor(groups,activities,participants,histories,rsvps);
    private final Instant now=Instant.parse("2026-09-15T10:00:00Z");

    @Test void goingMembershipLossBecomesNotGoingWritesHistoryAndPromotes() {
        UUID group=UUID.randomUUID(), user=UUID.randomUUID(), activityId=UUID.randomUUID();
        ActivityEntity activity=activity(group,activityId);
        ActivityParticipantEntity participant=participant(activityId,user,ActivityRsvpStatus.GOING,1L,now.minusSeconds(1));
        when(activities.findByIdForUpdate(activityId)).thenReturn(Optional.of(activity));
        when(participants.findByActivityIdAndUserIdForUpdate(activityId,user)).thenReturn(Optional.of(participant));
        processor.processOne(event(group,user),activityId);
        org.junit.jupiter.api.Assertions.assertEquals(ActivityRsvpStatus.NOT_GOING,participant.getRsvpStatus());
        verify(histories).save(argThat(h->h.getFromStatus()==ActivityRsvpStatus.GOING&&h.getToStatus()==ActivityRsvpStatus.NOT_GOING));
        verify(rsvps).promote(activity,now);
    }

    @Test void waitlistMaybeAndNoOpStatesAreIdempotentAndStaleEventsDoNotOverwrite() {
        UUID group=UUID.randomUUID(), user=UUID.randomUUID(), activityId=UUID.randomUUID(); ActivityEntity activity=activity(group,activityId);
        when(activities.findByIdForUpdate(activityId)).thenReturn(Optional.of(activity));
        for(ActivityRsvpStatus status: List.of(ActivityRsvpStatus.WAITLIST,ActivityRsvpStatus.MAYBE)) {
            ActivityParticipantEntity participant=participant(activityId,user,status,5L,now.minusSeconds(1));
            when(participants.findByActivityIdAndUserIdForUpdate(activityId,user)).thenReturn(Optional.of(participant));
            processor.processOne(event(group,user),activityId);
            org.junit.jupiter.api.Assertions.assertEquals(ActivityRsvpStatus.NOT_GOING,participant.getRsvpStatus());
        }
        ActivityParticipantEntity stale=participant(activityId,user,ActivityRsvpStatus.GOING, null, now.plusSeconds(1));
        when(participants.findByActivityIdAndUserIdForUpdate(activityId,user)).thenReturn(Optional.of(stale));
        processor.processOne(event(group,user),activityId);
        org.junit.jupiter.api.Assertions.assertEquals(ActivityRsvpStatus.GOING,stale.getRsvpStatus());
    }

    private GroupMembershipEndedEvent event(UUID group,UUID user){return new GroupMembershipEndedEvent(UUID.randomUUID(),group,user,null,GroupMembershipStatus.LEFT,now);}
    private ActivityEntity activity(UUID group,UUID id){return new ActivityEntity(id,group,UUID.randomUUID(),"t",null,ActivityStatus.CONFIRMED,now.plusSeconds(60),null,"UTC",null,2,now,now);}
    private ActivityParticipantEntity participant(UUID activity,UUID user,ActivityRsvpStatus status,Long sequence,Instant changed){return new ActivityParticipantEntity(UUID.randomUUID(),activity,user,status,sequence,changed,now,now);}
}
