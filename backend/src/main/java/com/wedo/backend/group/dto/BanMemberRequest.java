package com.wedo.backend.group.dto;

import jakarta.validation.constraints.Size;

public record BanMemberRequest(
        @Size(max = 500, message = "reason must not exceed 500 characters")
        String reason
) {
}
