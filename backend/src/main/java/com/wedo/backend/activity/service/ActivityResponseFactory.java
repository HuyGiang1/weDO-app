package com.wedo.backend.activity.service;

import com.wedo.backend.activity.dto.*;
import com.wedo.backend.activity.entity.*;
import com.wedo.backend.activity.repository.ActivityParticipantRepository;
import com.wedo.backend.group.service.ReadableGroupAccess;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.repository.UserRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Component;

/** Builds safe, caller-specific read DTOs without exposing JPA entities. */
@Component
public class ActivityResponseFactory {
    private final ActivityParticipantRepository participants;
    private final UserRepository users;
    private final Clock clock;

    public ActivityResponseFactory(ActivityParticipantRepository participants, UserRepository users, Clock clock) {
        this.participants = participants; this.users = users; this.clock = clock;
    }

    public ActivityDetailResponse detail(ActivityEntity activity, UUID callerId, ReadableGroupAccess access) {
        Instant now = clock.instant();
        ActivityStatus status = effectiveStatus(activity, now);
        Optional<ActivityParticipantEntity> caller = participants.findByActivityIdAndUserId(activity.getId(), callerId);
        long going = participants.countByActivityIdAndRsvpStatus(activity.getId(), ActivityRsvpStatus.GOING);
        long maybe = participants.countByActivityIdAndRsvpStatus(activity.getId(), ActivityRsvpStatus.MAYBE);
        long notGoing = participants.countByActivityIdAndRsvpStatus(activity.getId(), ActivityRsvpStatus.NOT_GOING);
        long waitlist = participants.countByActivityIdAndRsvpStatus(activity.getId(), ActivityRsvpStatus.WAITLIST);
        return new ActivityDetailResponse(activity.getId(), activity.getGroupId(), activity.getTitle(), activity.getDescription(),
                status, activity.getStartAt(), activity.getEndAt(), activity.getTimezone(),
                activity.getLocation() == null ? null : activity.getLocation().toDto(), activity.getCapacity(),
                activity.getCreatedAt(), activity.getUpdatedAt(), creator(activity.getCreatedBy()),
                caller.map(ActivityParticipantEntity::getRsvpStatus).orElse(ActivityRsvpStatus.NO_RESPONSE),
                caller.filter(p -> p.getRsvpStatus() == ActivityRsvpStatus.WAITLIST)
                        .map(ActivityParticipantEntity::getWaitlistSequence).orElse(null),
                going, maybe, notGoing, waitlist,
                ActivityPermissionPolicy.forCaller(activity, access, callerId, status));
    }

    public ActivitySummaryResponse summary(ActivityEntity activity, UUID callerId) {
        ActivityStatus status = effectiveStatus(activity, clock.instant());
        ActivityRsvpStatus caller = participants.findByActivityIdAndUserId(activity.getId(), callerId)
                .map(ActivityParticipantEntity::getRsvpStatus).orElse(ActivityRsvpStatus.NO_RESPONSE);
        return new ActivitySummaryResponse(activity.getId(), activity.getTitle(), status, activity.getStartAt(), activity.getEndAt(),
                activity.getTimezone(), activity.getLocation() == null ? null : activity.getLocation().name(), activity.getCapacity(),
                participants.countByActivityIdAndRsvpStatus(activity.getId(), ActivityRsvpStatus.GOING),
                participants.countByActivityIdAndRsvpStatus(activity.getId(), ActivityRsvpStatus.WAITLIST), caller);
    }

    public ActivityStatus effectiveStatus(ActivityEntity activity, Instant now) {
        if (activity.getStatus() == ActivityStatus.CANCELLED || activity.getStatus() == ActivityStatus.COMPLETED) return activity.getStatus();
        if (activity.getEndAt() != null && !now.isBefore(activity.getEndAt())) return ActivityStatus.COMPLETED;
        if (activity.getStatus() == ActivityStatus.CONFIRMED && !now.isBefore(activity.getStartAt())) return ActivityStatus.IN_PROGRESS;
        return activity.getStatus();
    }

    private ActivityCreatorResponse creator(UUID userId) {
        UserEntity user = users.findById(userId).orElse(null);
        return new ActivityCreatorResponse(userId, user == null ? null : user.getUsername(),
                user == null ? null : user.getDisplayName(), user == null ? null : user.getAvatarStorageKey());
    }
}
