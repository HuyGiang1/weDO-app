package com.wedo.backend.activity.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import com.wedo.backend.activity.dto.ChangeRsvpRequest;
import com.wedo.backend.activity.entity.*;
import com.wedo.backend.activity.repository.*;
import com.wedo.backend.group.service.GroupParticipationService;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.Test;

class ActivityRsvpServiceTest {
    final ActivityRepository activities=mock(ActivityRepository.class); final ActivityParticipantRepository participants=mock(ActivityParticipantRepository.class); final ActivityWaitlistSequenceRepository sequences=mock(ActivityWaitlistSequenceRepository.class); final ActivityRsvpHistoryRepository histories=mock(ActivityRsvpHistoryRepository.class); final GroupParticipationService access=mock(GroupParticipationService.class); final Instant now=Instant.parse("2026-09-15T10:00:00Z"); final ActivityRsvpService service=new ActivityRsvpService(activities,participants,sequences,histories,access,Clock.fixed(now,ZoneOffset.UTC));
    @Test void sameStatusIsNoOp(){ActivityEntity a=activity(2);ActivityParticipantEntity p=participant(a,ActivityRsvpStatus.GOING,null);when(activities.findById(a.getId())).thenReturn(Optional.of(a));when(activities.findByIdForUpdate(a.getId())).thenReturn(Optional.of(a));when(participants.findByActivityIdAndUserIdForUpdate(a.getId(),p.getUserId())).thenReturn(Optional.of(p));assertEquals(ActivityRsvpStatus.GOING,service.changeRsvp(a.getId(),p.getUserId(),new ChangeRsvpRequest(ActivityRsvpStatus.GOING)).status());verifyNoInteractions(histories);}
    @Test void fullGoingEntersWaitlistWithMonotonicSequence(){ActivityEntity a=activity(1);ActivityParticipantEntity p=participant(a,ActivityRsvpStatus.MAYBE,null);ActivityWaitlistSequenceEntity s=new ActivityWaitlistSequenceEntity(a.getId(),4,now);when(activities.findById(a.getId())).thenReturn(Optional.of(a));when(activities.findByIdForUpdate(a.getId())).thenReturn(Optional.of(a));when(participants.findByActivityIdAndUserIdForUpdate(a.getId(),p.getUserId())).thenReturn(Optional.of(p));when(participants.countByActivityIdAndRsvpStatus(a.getId(),ActivityRsvpStatus.GOING)).thenReturn(1L);when(sequences.findByActivityIdForUpdate(a.getId())).thenReturn(Optional.of(s));assertEquals(5,service.changeRsvp(a.getId(),p.getUserId(),new ChangeRsvpRequest(ActivityRsvpStatus.GOING)).waitlistSequence());verify(histories).save(any());}
    @Test void waitlistGoingPreservesQueueWhenFull(){ActivityEntity a=activity(1);ActivityParticipantEntity p=participant(a,ActivityRsvpStatus.WAITLIST,7L);when(activities.findById(a.getId())).thenReturn(Optional.of(a));when(activities.findByIdForUpdate(a.getId())).thenReturn(Optional.of(a));when(participants.findByActivityIdAndUserIdForUpdate(a.getId(),p.getUserId())).thenReturn(Optional.of(p));when(participants.countByActivityIdAndRsvpStatus(a.getId(),ActivityRsvpStatus.GOING)).thenReturn(1L);assertEquals(7,service.changeRsvp(a.getId(),p.getUserId(),new ChangeRsvpRequest(ActivityRsvpStatus.GOING)).waitlistSequence());verifyNoInteractions(histories);}
    @Test void noResponseTransitionsPersistParticipantAndOneHistoryForGoingMaybeAndNotGoing(){
        for(ActivityRsvpStatus requested:List.of(ActivityRsvpStatus.GOING,ActivityRsvpStatus.MAYBE,ActivityRsvpStatus.NOT_GOING)){
            ActivityEntity a=activity(2);ActivityParticipantEntity p=participant(a,ActivityRsvpStatus.NO_RESPONSE,null);arrange(a,p);when(participants.countByActivityIdAndRsvpStatus(a.getId(),ActivityRsvpStatus.GOING)).thenReturn(0L);
            service.changeRsvp(a.getId(),p.getUserId(),new ChangeRsvpRequest(requested));assertEquals(requested,p.getRsvpStatus());assertNull(p.getWaitlistSequence());verify(histories).save(argThat(h->h.getFromStatus()==ActivityRsvpStatus.NO_RESPONSE&&h.getToStatus()==requested));
            reset(activities,participants,sequences,histories,access);
        }
    }
    @Test void maybeAndNotGoingBecomeGoingWhenAvailableOrFifoWaitlistWhenFull(){
        for(ActivityRsvpStatus before:List.of(ActivityRsvpStatus.MAYBE,ActivityRsvpStatus.NOT_GOING)){
            ActivityEntity available=activity(2);ActivityParticipantEntity p=participant(available,before,null);arrange(available,p);when(participants.countByActivityIdAndRsvpStatus(available.getId(),ActivityRsvpStatus.GOING)).thenReturn(0L);
            service.changeRsvp(available.getId(),p.getUserId(),new ChangeRsvpRequest(ActivityRsvpStatus.GOING));assertEquals(ActivityRsvpStatus.GOING,p.getRsvpStatus());verify(histories).save(any());reset(activities,participants,sequences,histories,access);
            ActivityEntity full=activity(1);ActivityParticipantEntity queued=participant(full,before,null);ActivityWaitlistSequenceEntity seq=new ActivityWaitlistSequenceEntity(full.getId(),9,now);arrange(full,queued);when(participants.countByActivityIdAndRsvpStatus(full.getId(),ActivityRsvpStatus.GOING)).thenReturn(1L);when(sequences.findByActivityIdForUpdate(full.getId())).thenReturn(Optional.of(seq));
            service.changeRsvp(full.getId(),queued.getUserId(),new ChangeRsvpRequest(ActivityRsvpStatus.GOING));assertEquals(ActivityRsvpStatus.WAITLIST,queued.getRsvpStatus());assertEquals(10L,queued.getWaitlistSequence());reset(activities,participants,sequences,histories,access);
        }
    }
    @Test void goingExitPromotesFifoAndWaitlistExitClearsSequence(){
        ActivityEntity a=activity(1);ActivityParticipantEntity going=participant(a,ActivityRsvpStatus.GOING,null), waiter=participant(a,ActivityRsvpStatus.WAITLIST,4L);arrange(a,going);
        when(participants.countByActivityIdAndRsvpStatus(a.getId(),ActivityRsvpStatus.GOING)).thenReturn(1L,0L,1L);when(participants.findFirstByActivityIdAndRsvpStatusOrderByWaitlistSequenceAsc(a.getId(),ActivityRsvpStatus.WAITLIST)).thenReturn(Optional.of(waiter));
        service.changeRsvp(a.getId(),going.getUserId(),new ChangeRsvpRequest(ActivityRsvpStatus.MAYBE));assertEquals(ActivityRsvpStatus.MAYBE,going.getRsvpStatus());assertEquals(ActivityRsvpStatus.GOING,waiter.getRsvpStatus());assertNull(waiter.getWaitlistSequence());verify(histories,times(2)).save(any());
        reset(activities,participants,sequences,histories,access);ActivityParticipantEntity queued=participant(a,ActivityRsvpStatus.WAITLIST,7L);arrange(a,queued);when(participants.countByActivityIdAndRsvpStatus(a.getId(),ActivityRsvpStatus.GOING)).thenReturn(1L);
        service.changeRsvp(a.getId(),queued.getUserId(),new ChangeRsvpRequest(ActivityRsvpStatus.NOT_GOING));assertEquals(ActivityRsvpStatus.NOT_GOING,queued.getRsvpStatus());assertNull(queued.getWaitlistSequence());verify(histories).save(any());
    }
    @Test void unlimitedCapacityPromotesEveryFifoWaiterAndClientWaitlistIsRejected(){
        ActivityEntity unlimited=new ActivityEntity(UUID.randomUUID(),UUID.randomUUID(),UUID.randomUUID(),"a",null,ActivityStatus.CONFIRMED,now.plusSeconds(60),null,"UTC",null,null,now,now);ActivityParticipantEntity first=participant(unlimited,ActivityRsvpStatus.WAITLIST,1L), second=participant(unlimited,ActivityRsvpStatus.WAITLIST,2L);
        when(participants.findFirstByActivityIdAndRsvpStatusOrderByWaitlistSequenceAsc(unlimited.getId(),ActivityRsvpStatus.WAITLIST)).thenReturn(Optional.of(first),Optional.of(second),Optional.empty());
        service.promoteAll(unlimited,now);assertEquals(ActivityRsvpStatus.GOING,first.getRsvpStatus());assertEquals(ActivityRsvpStatus.GOING,second.getRsvpStatus());assertNull(first.getWaitlistSequence());assertNull(second.getWaitlistSequence());verify(histories,times(2)).save(any());
        assertFalse(new ChangeRsvpRequest(ActivityRsvpStatus.WAITLIST).isClientAllowed());
    }
    @Test void waitlistGoingWithVacancyPromotesSelfAndMaybeAndNotGoingSameStatusRemainNoOps(){
        ActivityEntity a=activity(2);ActivityParticipantEntity waiter=participant(a,ActivityRsvpStatus.WAITLIST,3L);arrange(a,waiter);when(participants.countByActivityIdAndRsvpStatus(a.getId(),ActivityRsvpStatus.GOING)).thenReturn(0L);
        service.changeRsvp(a.getId(),waiter.getUserId(),new ChangeRsvpRequest(ActivityRsvpStatus.GOING));assertEquals(ActivityRsvpStatus.GOING,waiter.getRsvpStatus());assertNull(waiter.getWaitlistSequence());verify(histories).save(any());
        reset(activities,participants,sequences,histories,access);for(ActivityRsvpStatus status:List.of(ActivityRsvpStatus.MAYBE,ActivityRsvpStatus.NOT_GOING)){ActivityParticipantEntity p=participant(a,status,null);arrange(a,p);assertEquals(status,service.changeRsvp(a.getId(),p.getUserId(),new ChangeRsvpRequest(status)).status());verifyNoInteractions(histories);reset(activities,participants,sequences,histories,access);}
    }
    private void arrange(ActivityEntity a,ActivityParticipantEntity p){when(activities.findById(a.getId())).thenReturn(Optional.of(a));when(activities.findByIdForUpdate(a.getId())).thenReturn(Optional.of(a));when(participants.findByActivityIdAndUserIdForUpdate(a.getId(),p.getUserId())).thenReturn(Optional.of(p));}
    private ActivityEntity activity(int capacity){return new ActivityEntity(UUID.randomUUID(),UUID.randomUUID(),UUID.randomUUID(),"a",null,ActivityStatus.CONFIRMED,now.plusSeconds(60),null,"UTC",null,capacity,now,now);} private ActivityParticipantEntity participant(ActivityEntity a,ActivityRsvpStatus s,Long q){return new ActivityParticipantEntity(UUID.randomUUID(),a.getId(),UUID.randomUUID(),s,q,now,now,now);}
}
