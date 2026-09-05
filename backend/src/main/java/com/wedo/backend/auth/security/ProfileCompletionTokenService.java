package com.wedo.backend.auth.security;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Date;
import java.util.UUID;

@Service
public class ProfileCompletionTokenService {

    public static final String PURPOSE_CLAIM = "purpose";
    public static final String PURPOSE_COMPLETE_PROFILE = "COMPLETE_PROFILE";
    private static final int MIN_KEY_BYTES = 32;

    private final Clock clock;
    private final Duration ttl;
    private final SecretKey signingKey;

    public ProfileCompletionTokenService(
            Clock clock,
            @Value("${security.profile-completion-token.secret-base64}") String secretBase64,
            @Value("${security.profile-completion-token.ttl}") Duration ttl
    ) {
        if (clock == null) {
            throw new IllegalArgumentException("Clock must not be null");
        }
        if (secretBase64 == null || secretBase64.isBlank()) {
            throw new IllegalStateException("Profile completion token secret must not be null or blank");
        }
        if (ttl == null || ttl.isZero() || ttl.isNegative()) {
            throw new IllegalStateException("Profile completion token TTL must be positive");
        }

        byte[] keyBytes;
        try {
            keyBytes = Base64.getDecoder().decode(secretBase64);
        } catch (IllegalArgumentException ex) {
            throw new IllegalStateException("Profile completion token secret is not valid Base64", ex);
        }

        if (keyBytes.length < MIN_KEY_BYTES) {
            throw new IllegalStateException("Profile completion token secret must be at least 256 bits (32 bytes)");
        }

        this.clock = clock;
        this.ttl = ttl;
        this.signingKey = Keys.hmacShaKeyFor(keyBytes);
    }

    public String generate(UUID userId) {
        if (userId == null) {
            throw new IllegalArgumentException("userId must not be null");
        }

        Instant now = clock.instant();
        Instant exp = now.plus(ttl);

        return Jwts.builder()
                .subject(userId.toString())
                .claim(PURPOSE_CLAIM, PURPOSE_COMPLETE_PROFILE)
                .issuedAt(Date.from(now))
                .expiration(Date.from(exp))
                .signWith(signingKey, Jwts.SIG.HS256)
                .compact();
    }

    public UUID extractAndValidate(String token) {
        if (token == null || token.isBlank()) {
            throw new IllegalArgumentException("Profile completion token must not be null or blank");
        }

        try {
            Claims claims = Jwts.parser()
                    .verifyWith(signingKey)
                    .clock(() -> Date.from(clock.instant()))
                    .clockSkewSeconds(0)
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();

            String purpose = claims.get(PURPOSE_CLAIM, String.class);
            if (!PURPOSE_COMPLETE_PROFILE.equals(purpose)) {
                throw new BusinessException(ErrorCode.UNAUTHORIZED, "Invalid or expired profile completion token");
            }

            Date expiration = claims.getExpiration();
            Instant now = clock.instant();
            if (expiration == null || !now.isBefore(expiration.toInstant())) {
                throw new BusinessException(ErrorCode.UNAUTHORIZED, "Invalid or expired profile completion token");
            }

            String sub = claims.getSubject();
            if (sub == null || sub.isBlank()) {
                throw new BusinessException(ErrorCode.UNAUTHORIZED, "Invalid or expired profile completion token");
            }

            try {
                return UUID.fromString(sub);
            } catch (IllegalArgumentException ex) {
                throw new BusinessException(ErrorCode.UNAUTHORIZED, "Invalid or expired profile completion token");
            }
        } catch (JwtException ex) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, "Invalid or expired profile completion token");
        }
    }
}
