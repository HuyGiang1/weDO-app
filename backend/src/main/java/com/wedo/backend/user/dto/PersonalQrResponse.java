package com.wedo.backend.user.dto;

/** Stable, stateless personal QR payload for an authenticated user. */
public record PersonalQrResponse(String deepLink) {
}
