package com.wedo.backend.activity.dto;

import jakarta.validation.constraints.Size;

/** Structured API location; persistence remains JSONB and is never exposed raw. */
public record ActivityLocationDto(
        @Size(max = 30) String type,
        @Size(max = 200) String name,
        @Size(max = 500) String address,
        Double latitude,
        Double longitude
) {
}
