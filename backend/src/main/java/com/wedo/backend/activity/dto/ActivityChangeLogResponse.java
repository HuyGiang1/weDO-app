package com.wedo.backend.activity.dto;

import java.time.Instant;
import java.util.UUID;

public record ActivityChangeLogResponse(UUID id, UUID actorId, String fieldName, String oldValue, String newValue, Instant createdAt) { }
