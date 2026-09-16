package com.wedo.backend.activity.dto;

import java.util.UUID;

/** Safe public profile subset; never serializes account or credential fields. */
public record ActivityCreatorResponse(UUID userId, String username, String displayName, String avatarStorageKey) { }
