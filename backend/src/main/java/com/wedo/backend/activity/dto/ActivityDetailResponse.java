package com.wedo.backend.activity.dto;

import com.wedo.backend.activity.entity.ActivityStatus;
import java.time.Instant;
import com.wedo.backend.activity.entity.ActivityRsvpStatus;
import java.util.UUID;

/** Authoritative activity read model. It deliberately projects only public creator data. */
public record ActivityDetailResponse(UUID id, UUID groupId, String title, String description,
                                     ActivityStatus status, Instant startAt, Instant endAt, String timezone,
                                     ActivityLocationDto location, Integer maxParticipants, Instant createdAt, Instant updatedAt,
                                     ActivityCreatorResponse creator, ActivityRsvpStatus callerRsvpStatus,
                                     Long callerWaitlistPosition, long goingCount, long maybeCount,
                                     long notGoingCount, long waitlistCount, ActivityPermissionFlags permissions) { }
