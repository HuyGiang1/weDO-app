package com.wedo.backend.activity.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import java.time.Instant;

public record CreateActivityRequest(
        @NotBlank @Size(max = 200) String title,
        String description,
        @NotNull Instant startAt,
        Instant endAt,
        @NotBlank @Size(max = 50) String timezone,
        @Valid ActivityLocationDto location,
        @Positive Integer maxParticipants
) { }
