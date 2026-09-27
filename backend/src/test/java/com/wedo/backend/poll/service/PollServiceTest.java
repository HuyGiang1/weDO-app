package com.wedo.backend.poll.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import com.wedo.backend.activity.entity.*;
import com.wedo.backend.activity.service.*;
import com.wedo.backend.common.error.*;
import com.wedo.backend.poll.dto.VotePollRequest;
import com.wedo.backend.poll.entity.*;
import com.wedo.backend.poll.repository.*;
import java.time.*; import java.util.*; import org.junit.jupiter.api.Test;
class PollServiceTest {
 @Test void expiredPollIsPersistedClosedAndRejectsLateVote(){M8ActivityAccessService access=mock(M8ActivityAccessService.class);PollRepository polls=mock(PollRepository.class);UUID activityId=UUID.randomUUID(),pollId=UUID.randomUUID(),actor=UUID.randomUUID();Instant now=Instant.parse("2026-01-01T00:00:00Z");PollEntity poll=new PollEntity(pollId,activityId,actor,"Q",PollType.SINGLE_CHOICE,false,null,VoteVisibility.PUBLIC,ResultVisibility.IMMEDIATE,now.minusSeconds(1),now.minusSeconds(2));when(polls.findByIdForUpdate(pollId)).thenReturn(Optional.of(poll));when(access.requireMutable(activityId,actor)).thenReturn(new M8ActivityAccess(activity(activityId),null));PollService service=new PollService(access,polls,mock(PollOptionRepository.class),mock(PollVoteRepository.class),mock(PollVoteChoiceRepository.class),Clock.fixed(now,ZoneOffset.UTC));BusinessException ex=assertThrows(BusinessException.class,()->service.vote(pollId,actor,new VotePollRequest(List.of(UUID.randomUUID()))));assertEquals(ErrorCode.POLL_DEADLINE_PASSED,ex.errorCode());assertEquals(PollStatus.CLOSED,poll.getStatus());verify(polls).save(poll);}
 private ActivityEntity activity(UUID id){return new ActivityEntity(id,UUID.randomUUID(),UUID.randomUUID(),"A",null,ActivityStatus.CONFIRMED,null,null,null,null,null,Instant.EPOCH,Instant.EPOCH);}
}
