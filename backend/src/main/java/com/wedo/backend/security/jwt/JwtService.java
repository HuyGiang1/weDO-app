package com.wedo.backend.security.jwt;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.UUID;

@Service
public class JwtService {

    private final Clock clock;
    private final Duration accessTokenTtl;
    private final SecretKey signingKey;

    public JwtService(
            Clock clock,
            @Value("${security.jwt.secret-base64}") String secretBase64,
            @Value("${security.jwt.access-token-ttl}") Duration accessTokenTtl
    ) {
        this.clock = clock;
        this.accessTokenTtl = accessTokenTtl;
        byte[] keyBytes = Decoders.BASE64.decode(secretBase64);
        this.signingKey = Keys.hmacShaKeyFor(keyBytes);
    }

    public String generateAccessToken(UUID userId) {
        if (userId == null) {
            throw new IllegalArgumentException("userId must not be null");
        }

        Instant now = clock.instant();
        Instant exp = now.plus(accessTokenTtl);

        return Jwts.builder()
                .subject(userId.toString())
                .issuedAt(Date.from(now))
                .expiration(Date.from(exp))
                .signWith(signingKey, Jwts.SIG.HS256)
                .compact();
    }

    public UUID extractUserId(String token) {
        Claims claims = parseClaims(token);
        String sub = claims.getSubject();
        if (sub == null || sub.isBlank()) {
            throw new IllegalArgumentException("JWT subject must not be null or blank");
        }
        return UUID.fromString(sub);
    }

    public Instant extractExpiration(String token) {
        Claims claims = parseClaims(token);
        Date exp = claims.getExpiration();
        if (exp == null) {
            throw new IllegalArgumentException("JWT expiration must not be null");
        }
        return exp.toInstant();
    }

    public boolean isTokenValid(String token) {
        if (token == null || token.isBlank()) {
            return false;
        }
        try {
            Claims claims = parseClaims(token);
            String sub = claims.getSubject();
            if (sub == null || sub.isBlank()) {
                return false;
            }
            UUID.fromString(sub);
            return true;
        } catch (JwtException | IllegalArgumentException ex) {
            return false;
        }
    }

    private Claims parseClaims(String token) {
        return Jwts.parser()
                .verifyWith(signingKey)
                .clock(() -> Date.from(clock.instant()))
                .clockSkewSeconds(0)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }
}
