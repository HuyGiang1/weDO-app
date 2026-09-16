package com.wedo.backend.activity.dto;

import com.wedo.backend.activity.entity.ActivityRsvpStatus;
import java.time.Instant;

public record ActivityRsvpResponse(ActivityRsvpStatus status, Long waitlistSequence, Instant statusUpdatedAt) { }
