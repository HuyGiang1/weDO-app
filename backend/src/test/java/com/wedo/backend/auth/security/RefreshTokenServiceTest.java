package com.wedo.backend.auth.security;

import com.wedo.backend.auth.dto.SessionClientMetadata;
import com.wedo.backend.auth.entity.RefreshSessionEntity;
import com.wedo.backend.auth.repository.RefreshSessionRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

@DisplayName("RefreshTokenService Unit Tests")
class RefreshTokenServiceTest {

    private final RefreshSessionRepository repository = mock(RefreshSessionRepository.class);
    private final Instant now = Instant.parse("2026-09-05T10:00:00Z");
    private final Duration ttl = Duration.ofDays(14);
    private final Duration maxFamilyLifetime = Duration.ofDays(30);
    private final RefreshTokenService service = new RefreshTokenService(repository, ttl, maxFamilyLifetime);

    @Test
    @DisplayName("issue should generate 43-char URL-safe raw token, store SHA-256 hex, and persist session with metadata and family deadline")
    void issueSuccess() throws Exception {
        UUID userId = UUID.randomUUID();
        Instant expiresAt = now.plus(ttl);
        Instant absoluteExpiresAt = now.plus(maxFamilyLifetime);
        SessionClientMetadata metadata = SessionClientMetadata.of("TestDevice", "127.0.0.1");

        RefreshTokenService.IssuedRefreshToken issued = service.issue(userId, now, expiresAt, absoluteExpiresAt, metadata);

        assertThat(issued.rawToken()).isNotBlank();
        assertThat(issued.rawToken()).hasSize(43);
        assertThat(issued.rawToken()).doesNotContain("=", "+", "/");
        assertThat(issued.expiresAt()).isEqualTo(expiresAt);
        assertThat(issued.sessionId()).isNotNull();

        ArgumentCaptor<RefreshSessionEntity> captor = ArgumentCaptor.forClass(RefreshSessionEntity.class);
        verify(repository).save(captor.capture());
        RefreshSessionEntity saved = captor.getValue();

        assertThat(saved.getId()).isEqualTo(issued.sessionId());
        assertThat(saved.getUserId()).isEqualTo(userId);
        assertThat(saved.getExpiresAt()).isEqualTo(expiresAt);
        assertThat(saved.getAbsoluteExpiresAt()).isEqualTo(absoluteExpiresAt);
        assertThat(saved.getCreatedAt()).isEqualTo(now);
        assertThat(saved.getRevokedAt()).isNull();
        assertThat(saved.getReplacedBySessionId()).isNull();
        assertThat(saved.getDeviceName()).isEqualTo("TestDevice");
        assertThat(saved.getIpAddress()).isEqualTo("127.0.0.1");

        // Hash verification
        assertThat(saved.getTokenHash()).isNotEqualTo(issued.rawToken());
        assertThat(saved.getTokenHash()).hasSize(64);
        assertThat(saved.getTokenHash()).matches("^[0-9a-f]{64}$");

        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        byte[] expectedHashBytes = digest.digest(issued.rawToken().getBytes(StandardCharsets.UTF_8));
        String expectedHex = HexFormat.of().formatHex(expectedHashBytes);
        assertThat(saved.getTokenHash()).isEqualTo(expectedHex);
        assertThat(RefreshTokenService.hashToken(issued.rawToken())).isEqualTo(expectedHex);
    }

    @Test
    @DisplayName("two consecutive issues should produce distinct tokens, hashes, and session IDs")
    void twoIssuesAreDistinct() {
        UUID userId = UUID.randomUUID();
        Instant expiresAt = now.plus(ttl);
        Instant absoluteExpiresAt = now.plus(maxFamilyLifetime);

        RefreshTokenService.IssuedRefreshToken first = service.issue(userId, now, expiresAt, absoluteExpiresAt, SessionClientMetadata.empty());
        RefreshTokenService.IssuedRefreshToken second = service.issue(userId, now, expiresAt, absoluteExpiresAt, SessionClientMetadata.empty());

        assertThat(first.rawToken()).isNotEqualTo(second.rawToken());
        assertThat(first.sessionId()).isNotEqualTo(second.sessionId());

        String firstHash = RefreshTokenService.hashToken(first.rawToken());
        String secondHash = RefreshTokenService.hashToken(second.rawToken());
        assertThat(firstHash).isNotEqualTo(secondHash);
    }

    @Test
    @DisplayName("issue should reject invalid lifecycle and programming invariant arguments")
    void issueRejectsInvalidArguments() {
        UUID userId = UUID.randomUUID();
        Instant expiresAt = now.plus(ttl);
        Instant absoluteExpiresAt = now.plus(maxFamilyLifetime);

        assertThatThrownBy(() -> service.issue(null, now, expiresAt, absoluteExpiresAt, SessionClientMetadata.empty()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("userId must not be null");

        assertThatThrownBy(() -> service.issue(userId, null, expiresAt, absoluteExpiresAt, SessionClientMetadata.empty()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("createdAt must not be null");

        assertThatThrownBy(() -> service.issue(userId, now, null, absoluteExpiresAt, SessionClientMetadata.empty()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("expiresAt must not be null");

        assertThatThrownBy(() -> service.issue(userId, now, expiresAt, null, SessionClientMetadata.empty()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("absoluteExpiresAt must not be null");

        // expiresAt > absoluteExpiresAt invariant
        Instant invalidExpiresAt = absoluteExpiresAt.plusSeconds(1);
        assertThatThrownBy(() -> service.issue(userId, now, invalidExpiresAt, absoluteExpiresAt, SessionClientMetadata.empty()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("expiresAt must not be after absoluteExpiresAt");
    }

    @Test
    @DisplayName("constructor should reject invalid configuration durations and null repository")
    void constructorRejectsInvalidDurations() {
        assertThatThrownBy(() -> new RefreshTokenService(null, ttl, maxFamilyLifetime))
                .isInstanceOf(IllegalArgumentException.class);

        assertThatThrownBy(() -> new RefreshTokenService(repository, null, maxFamilyLifetime))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("Refresh token TTL must be positive");

        assertThatThrownBy(() -> new RefreshTokenService(repository, Duration.ZERO, maxFamilyLifetime))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("Refresh token TTL must be positive");

        assertThatThrownBy(() -> new RefreshTokenService(repository, Duration.ofDays(-1), maxFamilyLifetime))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("Refresh token TTL must be positive");

        assertThatThrownBy(() -> new RefreshTokenService(repository, ttl, null))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("Max family lifetime must be positive");

        assertThatThrownBy(() -> new RefreshTokenService(repository, ttl, Duration.ZERO))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("Max family lifetime must be positive");

        assertThatThrownBy(() -> new RefreshTokenService(repository, ttl, Duration.ofDays(-1)))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("Max family lifetime must be positive");
    }

    @Test
    @DisplayName("getters should return configured duration values")
    void gettersReturnConfiguredValues() {
        assertThat(service.getRefreshTokenTtl()).isEqualTo(ttl);
        assertThat(service.getMaxFamilyLifetime()).isEqualTo(maxFamilyLifetime);
    }

    @Test
    @DisplayName("hashToken should reject null or blank raw token")
    void hashTokenRejectsBlank() {
        assertThatThrownBy(() -> RefreshTokenService.hashToken(null))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> RefreshTokenService.hashToken("   "))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
