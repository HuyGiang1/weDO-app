package com.wedo.backend.auth.security;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import javax.crypto.SecretKey;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Base64;
import java.util.Date;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ProfileCompletionTokenServiceTest {

    // 256-bit Base64-encoded secret keys (32 bytes)
    private static final String SECRET_A = "q9W8eR7tY6uI5oP4aD3fG2hJ1kL0zX9cV8bN7mQ6wE5=";
    private static final String SECRET_B = "s4A8wY0D2eE6vK1L5oP9tQ3rF7mN8xZ2cT4vB6nI8uM=";
    private static final Duration TTL_15M = Duration.ofMinutes(15);

    private Instant t0;
    private Clock clockAtT0;
    private ProfileCompletionTokenService tokenService;

    @BeforeEach
    void setUp() {
        t0 = Instant.parse("2026-09-05T12:00:00Z");
        clockAtT0 = Clock.fixed(t0, ZoneOffset.UTC);
        tokenService = new ProfileCompletionTokenService(clockAtT0, SECRET_A, TTL_15M);
    }

    @Test
    @DisplayName("generate and extract should return the same userId")
    void generateAndExtract_shouldReturnSameUserId() {
        UUID userId = UUID.randomUUID();
        String token = tokenService.generate(userId);

        assertThat(token).isNotBlank();
        UUID extracted = tokenService.extractAndValidate(token);
        assertThat(extracted).isEqualTo(userId);
    }

    @Test
    @DisplayName("token should contain exact sub, purpose, iat, and exp claims")
    void token_shouldContainExactClaims() {
        UUID userId = UUID.randomUUID();
        String token = tokenService.generate(userId);

        byte[] keyBytes = Decoders.BASE64.decode(SECRET_A);
        SecretKey key = Keys.hmacShaKeyFor(keyBytes);
        Claims claims = Jwts.parser()
                .verifyWith(key)
                .clock(() -> Date.from(t0))
                .build()
                .parseSignedClaims(token)
                .getPayload();

        assertThat(claims.getSubject()).isEqualTo(userId.toString());
        assertThat(claims.get("purpose", String.class)).isEqualTo("COMPLETE_PROFILE");
        assertThat(claims.getIssuedAt().toInstant()).isEqualTo(t0);
        assertThat(claims.getExpiration().toInstant()).isEqualTo(t0.plus(TTL_15M));
    }

    @Test
    @DisplayName("token is valid immediately before expiry boundary (T0 + 15m - 1s)")
    void token_shouldBeValidBeforeExpiry() {
        UUID userId = UUID.randomUUID();
        String token = tokenService.generate(userId);

        Clock clockBeforeExp = Clock.fixed(t0.plus(TTL_15M).minusSeconds(1), ZoneOffset.UTC);
        ProfileCompletionTokenService serviceBeforeExp = new ProfileCompletionTokenService(clockBeforeExp, SECRET_A, TTL_15M);

        UUID extracted = serviceBeforeExp.extractAndValidate(token);
        assertThat(extracted).isEqualTo(userId);
    }

    @Test
    @DisplayName("EXACT expiry boundary (T0 + 15m) must be rejected as expired")
    void token_shouldBeExpiredAtExactBoundary() {
        UUID userId = UUID.randomUUID();
        String token = tokenService.generate(userId);

        Clock clockAtBoundary = Clock.fixed(t0.plus(TTL_15M), ZoneOffset.UTC);
        ProfileCompletionTokenService serviceAtBoundary = new ProfileCompletionTokenService(clockAtBoundary, SECRET_A, TTL_15M);

        assertThatThrownBy(() -> serviceAtBoundary.extractAndValidate(token))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.UNAUTHORIZED));
    }

    @Test
    @DisplayName("token evaluated well after expiry must be rejected")
    void token_shouldBeRejectedAfterExpiry() {
        UUID userId = UUID.randomUUID();
        String token = tokenService.generate(userId);

        Clock clockAfterExp = Clock.fixed(t0.plus(Duration.ofMinutes(16)), ZoneOffset.UTC);
        ProfileCompletionTokenService serviceAfterExp = new ProfileCompletionTokenService(clockAfterExp, SECRET_A, TTL_15M);

        assertThatThrownBy(() -> serviceAfterExp.extractAndValidate(token))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.UNAUTHORIZED));
    }

    @Test
    @DisplayName("token signed with wrong key must be rejected")
    void token_shouldBeRejectedWithWrongKey() {
        UUID userId = UUID.randomUUID();
        String token = tokenService.generate(userId);

        ProfileCompletionTokenService serviceOtherKey = new ProfileCompletionTokenService(clockAtT0, SECRET_B, TTL_15M);

        assertThatThrownBy(() -> serviceOtherKey.extractAndValidate(token))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.UNAUTHORIZED));
    }

    @Test
    @DisplayName("tampered token payload must be rejected")
    void token_shouldBeRejectedWhenTampered() {
        UUID userId = UUID.randomUUID();
        String token = tokenService.generate(userId);
        String[] parts = token.split("\\.");
        String tamperedPayload = Base64.getUrlEncoder().withoutPadding().encodeToString("{\"sub\":\"tampered\"}".getBytes());
        String tamperedToken = parts[0] + "." + tamperedPayload + "." + parts[2];

        assertThatThrownBy(() -> tokenService.extractAndValidate(tamperedToken))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.UNAUTHORIZED));
    }

    @Test
    @DisplayName("malformed token string must be rejected")
    void token_shouldBeRejectedWhenMalformed() {
        assertThatThrownBy(() -> tokenService.extractAndValidate("not-a-valid-jwt-token"))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.UNAUTHORIZED));
    }

    @Test
    @DisplayName("token with wrong purpose must be rejected")
    void token_shouldBeRejectedWithWrongPurpose() {
        UUID userId = UUID.randomUUID();
        byte[] keyBytes = Decoders.BASE64.decode(SECRET_A);
        SecretKey key = Keys.hmacShaKeyFor(keyBytes);

        String wrongPurposeToken = Jwts.builder()
                .subject(userId.toString())
                .claim("purpose", "ACCESS_TOKEN")
                .issuedAt(Date.from(t0))
                .expiration(Date.from(t0.plus(TTL_15M)))
                .signWith(key, Jwts.SIG.HS256)
                .compact();

        assertThatThrownBy(() -> tokenService.extractAndValidate(wrongPurposeToken))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.UNAUTHORIZED));
    }

    @Test
    @DisplayName("token with missing subject must be rejected")
    void token_shouldBeRejectedWithMissingSubject() {
        byte[] keyBytes = Decoders.BASE64.decode(SECRET_A);
        SecretKey key = Keys.hmacShaKeyFor(keyBytes);

        String missingSubToken = Jwts.builder()
                .claim("purpose", "COMPLETE_PROFILE")
                .issuedAt(Date.from(t0))
                .expiration(Date.from(t0.plus(TTL_15M)))
                .signWith(key, Jwts.SIG.HS256)
                .compact();

        assertThatThrownBy(() -> tokenService.extractAndValidate(missingSubToken))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.UNAUTHORIZED));
    }

    @Test
    @DisplayName("token with invalid UUID subject must be rejected")
    void token_shouldBeRejectedWithInvalidUuidSubject() {
        byte[] keyBytes = Decoders.BASE64.decode(SECRET_A);
        SecretKey key = Keys.hmacShaKeyFor(keyBytes);

        String invalidUuidToken = Jwts.builder()
                .subject("not-a-uuid")
                .claim("purpose", "COMPLETE_PROFILE")
                .issuedAt(Date.from(t0))
                .expiration(Date.from(t0.plus(TTL_15M)))
                .signWith(key, Jwts.SIG.HS256)
                .compact();

        assertThatThrownBy(() -> tokenService.extractAndValidate(invalidUuidToken))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).errorCode()).isEqualTo(ErrorCode.UNAUTHORIZED));
    }

    @Test
    @DisplayName("direct service invocation with null or blank token throws IllegalArgumentException")
    void directInvocation_nullOrBlankToken_throwsIllegalArgumentException() {
        assertThatThrownBy(() -> tokenService.extractAndValidate(null))
                .isInstanceOf(IllegalArgumentException.class);

        assertThatThrownBy(() -> tokenService.extractAndValidate(""))
                .isInstanceOf(IllegalArgumentException.class);

        assertThatThrownBy(() -> tokenService.extractAndValidate("   "))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    @DisplayName("generate with null userId throws IllegalArgumentException")
    void generate_nullUserId_throwsIllegalArgumentException() {
        assertThatThrownBy(() -> tokenService.generate(null))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    @DisplayName("exactly 32-byte key is accepted")
    void config_exactly32ByteKey_accepted() {
        byte[] exactly32Bytes = new byte[32];
        for (int i = 0; i < 32; i++) exactly32Bytes[i] = (byte) (i + 1);
        String base64Key = Base64.getEncoder().encodeToString(exactly32Bytes);

        ProfileCompletionTokenService service = new ProfileCompletionTokenService(clockAtT0, base64Key, TTL_15M);
        assertThat(service).isNotNull();
    }

    @Test
    @DisplayName("31-byte key is rejected with IllegalStateException")
    void config_31ByteKey_rejected() {
        byte[] key31Bytes = new byte[31];
        String base64Key = Base64.getEncoder().encodeToString(key31Bytes);

        assertThatThrownBy(() -> new ProfileCompletionTokenService(clockAtT0, base64Key, TTL_15M))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("at least 256 bits (32 bytes)");
    }

    @Test
    @DisplayName("invalid Base64 secret is rejected with IllegalStateException")
    void config_invalidBase64_rejected() {
        assertThatThrownBy(() -> new ProfileCompletionTokenService(clockAtT0, "!!!not-valid-base64!!!", TTL_15M))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    @DisplayName("null or blank secret is rejected with IllegalStateException")
    void config_nullOrBlankSecret_rejected() {
        assertThatThrownBy(() -> new ProfileCompletionTokenService(clockAtT0, null, TTL_15M))
                .isInstanceOf(IllegalStateException.class);

        assertThatThrownBy(() -> new ProfileCompletionTokenService(clockAtT0, "   ", TTL_15M))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    @DisplayName("zero or negative TTL is rejected with IllegalStateException")
    void config_zeroOrNegativeTtl_rejected() {
        assertThatThrownBy(() -> new ProfileCompletionTokenService(clockAtT0, SECRET_A, Duration.ZERO))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("TTL must be positive");

        assertThatThrownBy(() -> new ProfileCompletionTokenService(clockAtT0, SECRET_A, Duration.ofMinutes(-5)))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("TTL must be positive");

        assertThatThrownBy(() -> new ProfileCompletionTokenService(clockAtT0, SECRET_A, null))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("TTL must be positive");
    }
}
