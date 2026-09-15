package com.wedo.backend.group.dto;

import jakarta.validation.constraints.NotNull;
import java.util.UUID;

public record CreateInvitationRequest(
        @NotNull(message = "inviteeUserId is required")
        UUID inviteeUserId
) {
}
