package com.wedo.backend.activity.dto;

import com.wedo.backend.activity.entity.ActivityRsvpStatus;
import java.time.Instant;
import java.util.UUID;

public record ActivityParticipantResponse(UUID userId, String displayName, String username, String avatarStorageKey,
                                          ActivityRsvpStatus rsvpStatus, Long waitlistSequence, Instant statusUpdatedAt) { }
