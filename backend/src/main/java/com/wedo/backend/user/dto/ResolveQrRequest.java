package com.wedo.backend.user.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ResolveQrRequest(
        @NotBlank @Size(max = 256) String deepLink
) {
}
