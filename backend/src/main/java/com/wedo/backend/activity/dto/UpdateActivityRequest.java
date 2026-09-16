package com.wedo.backend.activity.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import java.time.Instant;

/** Command DTO is intentionally unbound from an endpoint while M7 policy is incomplete. */
public record UpdateActivityRequest(
        @Size(max = 200) String title,
        String description,
        Instant startAt,
        Instant endAt,
        @Size(max = 50) String timezone,
        @Valid ActivityLocationDto location,
        @Positive Integer maxParticipants
) { }
