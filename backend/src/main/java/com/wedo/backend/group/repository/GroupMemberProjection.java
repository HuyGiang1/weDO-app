package com.wedo.backend.group.repository;

import java.time.Instant;
import java.util.UUID;

public interface GroupMemberProjection {
    UUID getUserId();
    String getUsername();
    String getDisplayName();
    String getAvatarStorageKey();
    String getRole();
    Instant getJoinedAt();
}
