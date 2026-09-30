package com.wedo.backend.activity.reminder;

import jakarta.validation.constraints.NotNull;
import java.time.Instant;
import java.util.UUID;

public final class ActivityReminderDtos {
    private ActivityReminderDtos() { }

    public record Request(@NotNull Boolean enabled, Integer offsetMinutes) { }

    public record Response(UUID activityId, boolean configured, boolean enabled,
                           Integer offsetMinutes, Instant remindAt, Instant sentAt,
                           boolean canConfigure, String unavailableReason) { }
}
