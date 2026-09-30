package com.wedo.backend.media.dto;

import java.time.Instant;

public record MediaAccessResponse(String url, Instant expiresAt) {}
