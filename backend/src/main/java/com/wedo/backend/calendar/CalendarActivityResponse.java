package com.wedo.backend.calendar;

import com.wedo.backend.activity.entity.ActivityRsvpStatus;
import com.wedo.backend.activity.entity.ActivityStatus;
import java.time.Instant;
import java.util.UUID;

public record CalendarActivityResponse(
        UUID id,
        UUID groupId,
        String groupName,
        String title,
        ActivityStatus status,
        Instant startAt,
        Instant endAt,
        String timezone,
        String locationName,
        long goingCount,
        long waitlistCount,
        ActivityRsvpStatus callerRsvpStatus,
        boolean reminderEnabled,
        Instant reminderAt
) { }
