package com.wedo.backend.auth.security;

import com.wedo.backend.auth.dto.SessionClientMetadata;
import com.wedo.backend.auth.entity.RefreshSessionEntity;
import com.wedo.backend.auth.repository.RefreshSessionRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.UUID;

@Service
public class RefreshTokenService {

    public record IssuedRefreshToken(
            String rawToken,
            UUID sessionId,
            Instant expiresAt
    ) {}

    private final RefreshSessionRepository refreshSessionRepository;
    private final Duration refreshTokenTtl;
    private final Duration maxFamilyLifetime;
    private final SecureRandom secureRandom;

    public RefreshTokenService(
            RefreshSessionRepository refreshSessionRepository,
            @Value("${security.refresh-token.ttl:14d}") Duration refreshTokenTtl,
            @Value("${security.refresh-token.max-family-lifetime:30d}") Duration maxFamilyLifetime
    ) {
        if (refreshSessionRepository == null) {
            throw new IllegalArgumentException("RefreshSessionRepository must not be null");
        }
        if (refreshTokenTtl == null || refreshTokenTtl.isZero() || refreshTokenTtl.isNegative()) {
            throw new IllegalStateException("Refresh token TTL must be positive");
        }
        if (maxFamilyLifetime == null || maxFamilyLifetime.isZero() || maxFamilyLifetime.isNegative()) {
            throw new IllegalStateException("Max family lifetime must be positive");
        }
        this.refreshSessionRepository = refreshSessionRepository;
        this.refreshTokenTtl = refreshTokenTtl;
        this.maxFamilyLifetime = maxFamilyLifetime;
        this.secureRandom = new SecureRandom();
    }

    public Duration getRefreshTokenTtl() {
        return refreshTokenTtl;
    }

    public Duration getMaxFamilyLifetime() {
        return maxFamilyLifetime;
    }

    public IssuedRefreshToken issue(
            UUID userId,
            Instant createdAt,
            Instant expiresAt,
            Instant absoluteExpiresAt,
            SessionClientMetadata metadata
    ) {
        if (userId == null) {
            throw new IllegalArgumentException("userId must not be null");
        }
        if (createdAt == null) {
            throw new IllegalArgumentException("createdAt must not be null");
        }
        if (expiresAt == null) {
            throw new IllegalArgumentException("expiresAt must not be null");
        }
        if (absoluteExpiresAt == null) {
            throw new IllegalArgumentException("absoluteExpiresAt must not be null");
        }
        if (expiresAt.isAfter(absoluteExpiresAt)) {
            throw new IllegalArgumentException("expiresAt must not be after absoluteExpiresAt");
        }
        SessionClientMetadata safeMetadata = metadata != null ? metadata : SessionClientMetadata.empty();

        byte[] randomBytes = new byte[32];
        secureRandom.nextBytes(randomBytes);
        String rawToken = Base64.getUrlEncoder().withoutPadding().encodeToString(randomBytes);

        String tokenHash = hashToken(rawToken);
        UUID sessionId = UUID.randomUUID();

        RefreshSessionEntity session = new RefreshSessionEntity(
                sessionId,
                userId,
                tokenHash,
                expiresAt,
                null,
                null,
                safeMetadata.deviceName(),
                safeMetadata.ipAddress(),
                createdAt,
                absoluteExpiresAt
        );
        refreshSessionRepository.save(session);

        return new IssuedRefreshToken(rawToken, sessionId, expiresAt);
    }

    public static String hashToken(String rawToken) {
        if (rawToken == null || rawToken.isBlank()) {
            throw new IllegalArgumentException("rawToken must not be null or blank");
        }
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(rawToken.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 digest unavailable", e);
        }
    }
}
