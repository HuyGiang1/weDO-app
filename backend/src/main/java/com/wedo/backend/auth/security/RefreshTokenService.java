package com.wedo.backend.auth.security;

import com.wedo.backend.auth.entity.RefreshSessionEntity;
import com.wedo.backend.auth.repository.RefreshSessionRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Clock;
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
    private final Clock clock;
    private final Duration refreshTokenTtl;
    private final SecureRandom secureRandom;

    public RefreshTokenService(
            RefreshSessionRepository refreshSessionRepository,
            Clock clock,
            @Value("${security.refresh-token.ttl:14d}") Duration refreshTokenTtl
    ) {
        if (refreshSessionRepository == null) {
            throw new IllegalArgumentException("RefreshSessionRepository must not be null");
        }
        if (clock == null) {
            throw new IllegalArgumentException("Clock must not be null");
        }
        if (refreshTokenTtl == null || refreshTokenTtl.isZero() || refreshTokenTtl.isNegative()) {
            throw new IllegalStateException("Refresh token TTL must be positive");
        }
        this.refreshSessionRepository = refreshSessionRepository;
        this.clock = clock;
        this.refreshTokenTtl = refreshTokenTtl;
        this.secureRandom = new SecureRandom();
    }

    public IssuedRefreshToken issue(UUID userId) {
        if (userId == null) {
            throw new IllegalArgumentException("userId must not be null");
        }

        byte[] randomBytes = new byte[32];
        secureRandom.nextBytes(randomBytes);
        String rawToken = Base64.getUrlEncoder().withoutPadding().encodeToString(randomBytes);

        String tokenHash = hashToken(rawToken);

        UUID sessionId = UUID.randomUUID();
        Instant now = clock.instant();
        Instant expiresAt = now.plus(refreshTokenTtl);

        RefreshSessionEntity session = new RefreshSessionEntity(
                sessionId,
                userId,
                tokenHash,
                expiresAt,
                null,
                null,
                null,
                null,
                now
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
