package com.wedo.backend.group.repository;

import java.time.Instant;
import java.util.UUID;

public interface GroupSummaryProjection {
    UUID getId();
    String getName();
    String getAvatarStorageKey();
    String getStatus();
    String getCallerRole();
    Instant getUpdatedAt();
}
