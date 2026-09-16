package com.wedo.backend.activity.dto;

import com.wedo.backend.activity.entity.ActivityRsvpStatus;
import jakarta.validation.constraints.NotNull;

public record ChangeRsvpRequest(@NotNull ActivityRsvpStatus status) {
    public boolean isClientAllowed() { return status == ActivityRsvpStatus.GOING || status == ActivityRsvpStatus.MAYBE || status == ActivityRsvpStatus.NOT_GOING; }
}
