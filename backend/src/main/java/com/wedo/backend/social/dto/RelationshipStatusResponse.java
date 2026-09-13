package com.wedo.backend.social.dto;

import java.util.UUID;

public record RelationshipStatusResponse(
    UUID targetUserId,
    RelationshipState state
) {}
