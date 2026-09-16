package com.wedo.backend.activity.dto;

import com.wedo.backend.activity.entity.ActivityStatus;
import java.time.Instant;
import java.util.UUID;

public record ActivityStatusHistoryResponse(UUID id, ActivityStatus fromStatus, ActivityStatus toStatus, UUID changedBy,
                                            String reason, Instant createdAt) { }
