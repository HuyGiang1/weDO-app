package com.wedo.backend.activity.dto;

import com.wedo.backend.activity.entity.ActivityStatus;
import com.wedo.backend.activity.entity.ActivityRsvpStatus;
import java.time.Instant;
import java.util.UUID;

public record ActivitySummaryResponse(UUID id, String title, ActivityStatus status, Instant startAt, Instant endAt,
                                      String timezone, String locationName, Integer maxParticipants,
                                      long goingCount, long waitlistCount, ActivityRsvpStatus callerRsvpStatus) { }
