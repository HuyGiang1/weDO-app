package com.wedo.backend.group.event;

import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import java.time.Instant;
import java.util.UUID;

public record GroupMembershipEndedEvent(UUID membershipId, UUID groupId, UUID userId, GroupRole previousRole,
                                        GroupMembershipStatus terminalStatus, Instant occurredAt) { }
