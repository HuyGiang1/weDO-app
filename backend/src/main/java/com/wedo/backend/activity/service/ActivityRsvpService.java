package com.wedo.backend.activity.service;

import com.wedo.backend.activity.dto.ActivityRsvpResponse;
import com.wedo.backend.activity.dto.ChangeRsvpRequest;
import com.wedo.backend.activity.entity.*;
import com.wedo.backend.activity.repository.*;
import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.group.service.GroupParticipationService;
import java.time.Clock;
import java.time.Instant;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ActivityRsvpService {
    private final ActivityRepository activities; private final ActivityParticipantRepository participants;
    private final ActivityWaitlistSequenceRepository sequences; private final ActivityRsvpHistoryRepository histories;
    private final GroupParticipationService participation; private final Clock clock;
    public ActivityRsvpService(ActivityRepository activities, ActivityParticipantRepository participants, ActivityWaitlistSequenceRepository sequences, ActivityRsvpHistoryRepository histories, GroupParticipationService participation, Clock clock) {
        this.activities=activities;this.participants=participants;this.sequences=sequences;this.histories=histories;this.participation=participation;this.clock=clock;
    }
    @Transactional
    public ActivityRsvpResponse changeRsvp(UUID activityId, UUID userId, ChangeRsvpRequest request) {
        if (!request.isClientAllowed()) throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        ActivityEntity identity=activities.findById(activityId).orElseThrow(()->new BusinessException(ErrorCode.ACTIVITY_NOT_FOUND));
        participation.lockActiveUnbannedMutableParticipation(identity.getGroupId(),userId);
        ActivityEntity activity=activities.findByIdForUpdate(activityId).orElseThrow(()->new BusinessException(ErrorCode.ACTIVITY_NOT_FOUND));
        Instant now=clock.instant(); ActivityStatus effective=effectiveStatus(activity,now);
        if(effective==ActivityStatus.COMPLETED || effective==ActivityStatus.CANCELLED) throw new BusinessException(ErrorCode.RSVP_LOCKED);
        ActivityParticipantEntity participant=participants.findByActivityIdAndUserIdForUpdate(activityId,userId).orElseGet(()->participants.save(new ActivityParticipantEntity(UUID.randomUUID(),activityId,userId,ActivityRsvpStatus.NO_RESPONSE,null,null,now,now)));
        ActivityRsvpStatus before=participant.getRsvpStatus(); ActivityRsvpStatus target=request.status();
        if(before==target) return response(participant);
        boolean full=activity.getCapacity()!=null && participants.countByActivityIdAndRsvpStatus(activityId,ActivityRsvpStatus.GOING)>=activity.getCapacity();
        ActivityRsvpStatus after=target; Long sequence=null;
        if(target==ActivityRsvpStatus.GOING && full) { after=ActivityRsvpStatus.WAITLIST; sequence=before==ActivityRsvpStatus.WAITLIST?participant.getWaitlistSequence():nextSequence(activityId,now); }
        if(before==ActivityRsvpStatus.WAITLIST && target==ActivityRsvpStatus.GOING && !full) after=ActivityRsvpStatus.GOING;
        if(after==before && (after!=ActivityRsvpStatus.WAITLIST || sequence.equals(participant.getWaitlistSequence()))) return response(participant);
        participant.changeTo(after,after==ActivityRsvpStatus.WAITLIST?sequence:null,now); history(activityId,userId,before,after,userId,now);
        if(before==ActivityRsvpStatus.GOING && after!=ActivityRsvpStatus.GOING) promoteAll(activity,now);
        return response(participant);
    }
    /** Caller holds the canonical group/activity locks; promote FIFO until capacity is exhausted. */
    void promoteAll(ActivityEntity activity, Instant now) {
        while (activity.getCapacity() == null || participants.countByActivityIdAndRsvpStatus(activity.getId(), ActivityRsvpStatus.GOING) < activity.getCapacity()) {
            var next = participants.findFirstByActivityIdAndRsvpStatusOrderByWaitlistSequenceAsc(activity.getId(), ActivityRsvpStatus.WAITLIST);
            if (next.isEmpty()) return;
            ActivityParticipantEntity participant = next.get();
            participant.changeTo(ActivityRsvpStatus.GOING, null, now);
            history(activity.getId(), participant.getUserId(), ActivityRsvpStatus.WAITLIST, ActivityRsvpStatus.GOING, null, now);
        }
    }

    /** Compatibility seam used by membership-loss processing; promotes all currently available places. */
    void promote(ActivityEntity activity, Instant now) { promoteAll(activity, now); }
    private long nextSequence(UUID activityId,Instant now){ActivityWaitlistSequenceEntity s=sequences.findByActivityIdForUpdate(activityId).orElseGet(()->sequences.save(new ActivityWaitlistSequenceEntity(activityId,0,now)));return s.next(now);}
    private void history(UUID a,UUID u,ActivityRsvpStatus from,ActivityRsvpStatus to,UUID actor,Instant now){histories.save(new ActivityRsvpHistoryEntity(UUID.randomUUID(),a,u,from,to,actor,now));}
    private ActivityStatus effectiveStatus(ActivityEntity a,Instant now){if(a.getStatus()==ActivityStatus.CANCELLED)return ActivityStatus.CANCELLED;if(a.getEndAt()!=null&&!now.isBefore(a.getEndAt()))return ActivityStatus.COMPLETED;return a.getStatus();}
    private ActivityRsvpResponse response(ActivityParticipantEntity p){return new ActivityRsvpResponse(p.getRsvpStatus(),p.getWaitlistSequence(),p.getStatusUpdatedAt());}
}
