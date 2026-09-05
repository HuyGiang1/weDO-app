package com.wedo.backend.security.jwt;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.MalformedJwtException;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;
import io.jsonwebtoken.security.SignatureException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import javax.crypto.SecretKey;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Date;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JwtServiceTest {

    // 256-bit Base64-encoded secret keys
    private static final String SECRET_A = "HtYDoxLoUE6DB2ghGul6hVTMTMpg0ysFkJPvuDWf8aU=";
    private static final String SECRET_B = "1WZTYD0Q6/LbmgH08YrpYg+Xwsn19ZXp2M3WObbPl/4=";
    private static final Duration TTL_15M = Duration.ofMinutes(15);

    private Instant t0;
    private Clock clockAtT0;
    private JwtService jwtService;

    @BeforeEach
    void setUp() {
        t0 = Instant.parse("2026-09-05T12:00:00Z");
        clockAtT0 = Clock.fixed(t0, ZoneOffset.UTC);
        jwtService = new JwtService(clockAtT0, SECRET_A, TTL_15M);
    }

    @Test
    @DisplayName("generateAccessToken should produce a non-blank token containing 3 parts")
    void generateAccessToken_shouldProduceThreePartToken() {
        UUID userId = UUID.randomUUID();

        String token = jwtService.generateAccessToken(userId);

        assertThat(token).isNotBlank();
        assertThat(token.split("\\.")).hasSize(3);
    }

    @Test
    @DisplayName("extractUserId should correctly decode the user UUID embedded in token")
    void extractUserId_shouldReturnExactUserId() {
        UUID expectedUserId = UUID.randomUUID();
        String token = jwtService.generateAccessToken(expectedUserId);

        UUID extractedUserId = jwtService.extractUserId(token);

        assertThat(extractedUserId).isEqualTo(expectedUserId);
    }

    @Test
    @DisplayName("extractExpiration should return exact expiration timestamp based on clock and TTL")
    void extractExpiration_shouldMatchIssuedAtPlusTtl() {
        UUID userId = UUID.randomUUID();
        String token = jwtService.generateAccessToken(userId);

        Instant expiration = jwtService.extractExpiration(token);

        assertThat(expiration).isEqualTo(t0.plus(TTL_15M));
    }

    @Test
    @DisplayName("isTokenValid should return true for a newly generated valid token")
    void isTokenValid_shouldReturnTrueForValidToken() {
        UUID userId = UUID.randomUUID();
        String token = jwtService.generateAccessToken(userId);

        assertThat(jwtService.isTokenValid(token)).isTrue();
    }

    @Test
    @DisplayName("deterministic expiration test: token evaluated at T0 + 16m must be expired without Thread.sleep")
    void deterministicExpiration_shouldRejectExpiredToken() {
        UUID userId = UUID.randomUUID();
        String token = jwtService.generateAccessToken(userId);

        // Second JwtService instance configured at T0 + 16 minutes with the SAME secret and TTL
        Clock clockAtT16 = Clock.fixed(t0.plus(Duration.ofMinutes(16)), ZoneOffset.UTC);
        JwtService serviceAtT16 = new JwtService(clockAtT16, SECRET_A, TTL_15M);

        assertThat(serviceAtT16.isTokenValid(token)).isFalse();
        assertThatThrownBy(() -> serviceAtT16.extractUserId(token))
                .isInstanceOf(ExpiredJwtException.class);
    }

    @Test
    @DisplayName("token signed with different secret key must be rejected with SignatureException")
    void wrongSecretKey_shouldBeRejected() {
        UUID userId = UUID.randomUUID();
        String token = jwtService.generateAccessToken(userId);

        // Second JwtService instance configured with SECRET_B
        JwtService serviceWithSecretB = new JwtService(clockAtT0, SECRET_B, TTL_15M);

        assertThat(serviceWithSecretB.isTokenValid(token)).isFalse();
        assertThatThrownBy(() -> serviceWithSecretB.extractUserId(token))
                .isInstanceOf(SignatureException.class);
    }

    @Test
    @DisplayName("malformed token string should be rejected with MalformedJwtException")
    void malformedToken_shouldBeRejected() {
        String malformedToken = "this.is.not.a.valid.jwt";

        assertThat(jwtService.isTokenValid(malformedToken)).isFalse();
        assertThatThrownBy(() -> jwtService.extractUserId(malformedToken))
                .isInstanceOf(MalformedJwtException.class);
    }

    @Test
    @DisplayName("null or blank token string should be rejected by isTokenValid")
    void nullOrBlankToken_shouldReturnFalse() {
        assertThat(jwtService.isTokenValid(null)).isFalse();
        assertThat(jwtService.isTokenValid("")).isFalse();
        assertThat(jwtService.isTokenValid("   ")).isFalse();
    }

    @Test
    @DisplayName("generateAccessToken with null userId should throw IllegalArgumentException")
    void generateAccessToken_nullUserId_shouldThrowException() {
        assertThatThrownBy(() -> jwtService.generateAccessToken(null))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("userId must not be null");
    }

    @Test
    @DisplayName("token should contain exact sub, iat, and exp claims matching T0 and TTL")
    void tokenClaims_shouldContainExpectedSubIatAndExp() {
        UUID userId = UUID.randomUUID();
        String token = jwtService.generateAccessToken(userId);

        byte[] keyBytes = Decoders.BASE64.decode(SECRET_A);
        SecretKey key = Keys.hmacShaKeyFor(keyBytes);

        Claims claims = Jwts.parser()
                .verifyWith(key)
                .clock(() -> Date.from(t0))
                .clockSkewSeconds(0)
                .build()
                .parseSignedClaims(token)
                .getPayload();

        assertThat(claims.getSubject()).isEqualTo(userId.toString());
        assertThat(claims.getIssuedAt().toInstant()).isEqualTo(t0);
        assertThat(claims.getExpiration().toInstant()).isEqualTo(t0.plus(TTL_15M));
    }

    @Test
    @DisplayName("token with valid signature but non-UUID subject should be rejected by isTokenValid and extractUserId")
    void invalidUuidSubject_shouldBeRejected() {
        byte[] keyBytes = Decoders.BASE64.decode(SECRET_A);
        SecretKey key = Keys.hmacShaKeyFor(keyBytes);

        String tokenWithNonUuidSubject = Jwts.builder()
                .subject("not-a-uuid")
                .issuedAt(Date.from(t0))
                .expiration(Date.from(t0.plus(TTL_15M)))
                .signWith(key, Jwts.SIG.HS256)
                .compact();

        assertThat(jwtService.isTokenValid(tokenWithNonUuidSubject)).isFalse();
        assertThatThrownBy(() -> jwtService.extractUserId(tokenWithNonUuidSubject))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
