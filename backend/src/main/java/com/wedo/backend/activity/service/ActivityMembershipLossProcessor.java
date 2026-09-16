package com.wedo.backend.activity.service;

import com.wedo.backend.activity.entity.*;
import com.wedo.backend.activity.repository.*;
import com.wedo.backend.group.event.GroupMembershipEndedEvent;
import com.wedo.backend.group.repository.GroupRepository;
import java.time.Instant;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.*;

@Service
public class ActivityMembershipLossProcessor {
    private final GroupRepository groups; private final ActivityRepository activities; private final ActivityParticipantRepository participants; private final ActivityRsvpHistoryRepository histories; private final ActivityRsvpService rsvps;
    public ActivityMembershipLossProcessor(GroupRepository groups,ActivityRepository activities,ActivityParticipantRepository participants,ActivityRsvpHistoryRepository histories,ActivityRsvpService rsvps){this.groups=groups;this.activities=activities;this.participants=participants;this.histories=histories;this.rsvps=rsvps;}
    @Transactional(propagation=Propagation.REQUIRES_NEW)
    public void processOne(GroupMembershipEndedEvent event,UUID activityId){groups.findByIdForUpdate(event.groupId());ActivityEntity activity=activities.findByIdForUpdate(activityId).orElse(null);if(activity==null)return;participants.findByActivityIdAndUserIdForUpdate(activityId,event.userId()).ifPresent(p->{if(p.getStatusUpdatedAt()!=null&&p.getStatusUpdatedAt().isAfter(event.occurredAt()))return;ActivityRsvpStatus from=p.getRsvpStatus();if(from==ActivityRsvpStatus.NO_RESPONSE||from==ActivityRsvpStatus.NOT_GOING)return;p.changeTo(ActivityRsvpStatus.NOT_GOING,null,event.occurredAt());histories.save(new ActivityRsvpHistoryEntity(UUID.randomUUID(),activityId,event.userId(),from,ActivityRsvpStatus.NOT_GOING,null,event.occurredAt()));if(from==ActivityRsvpStatus.GOING)rsvps.promote(activity,event.occurredAt());});}
}
