package com.wedo.backend.group.dto;

import jakarta.validation.constraints.Min;
import java.time.Instant;

public record CreateInviteLinkRequest(
        Instant expiresAt,
        @Min(value = 1, message = "maxUses must be greater than 0")
        Integer maxUses
) {
}
