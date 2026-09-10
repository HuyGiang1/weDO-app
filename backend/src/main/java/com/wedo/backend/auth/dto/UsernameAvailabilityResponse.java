package com.wedo.backend.auth.dto;

public record UsernameAvailabilityResponse(
        String username,
        boolean available
) {
    public static UsernameAvailabilityResponse of(String username, boolean available) {
        return new UsernameAvailabilityResponse(username, available);
    }
}
