package com.wedo.backend.auth.security;

import com.wedo.backend.auth.entity.RefreshSessionEntity;
import com.wedo.backend.auth.repository.RefreshSessionRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
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
    private final Clock clock = Clock.fixed(now, ZoneOffset.UTC);
    private final Duration ttl = Duration.ofDays(14);
    private final RefreshTokenService service = new RefreshTokenService(repository, clock, ttl);

    @Test
    @DisplayName("issue should generate 43-char URL-safe raw token, store SHA-256 hex, and persist session")
    void issueSuccess() throws Exception {
        UUID userId = UUID.randomUUID();

        RefreshTokenService.IssuedRefreshToken issued = service.issue(userId);

        assertThat(issued.rawToken()).isNotBlank();
        assertThat(issued.rawToken()).hasSize(43);
        assertThat(issued.rawToken()).doesNotContain("=", "+", "/");
        assertThat(issued.expiresAt()).isEqualTo(now.plus(ttl));
        assertThat(issued.sessionId()).isNotNull();

        ArgumentCaptor<RefreshSessionEntity> captor = ArgumentCaptor.forClass(RefreshSessionEntity.class);
        verify(repository).save(captor.capture());
        RefreshSessionEntity saved = captor.getValue();

        assertThat(saved.getId()).isEqualTo(issued.sessionId());
        assertThat(saved.getUserId()).isEqualTo(userId);
        assertThat(saved.getExpiresAt()).isEqualTo(now.plus(ttl));
        assertThat(saved.getCreatedAt()).isEqualTo(now);
        assertThat(saved.getRevokedAt()).isNull();
        assertThat(saved.getReplacedBySessionId()).isNull();
        assertThat(saved.getDeviceName()).isNull();
        assertThat(saved.getIpAddress()).isNull();

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

        RefreshTokenService.IssuedRefreshToken first = service.issue(userId);
        RefreshTokenService.IssuedRefreshToken second = service.issue(userId);

        assertThat(first.rawToken()).isNotEqualTo(second.rawToken());
        assertThat(first.sessionId()).isNotEqualTo(second.sessionId());

        String firstHash = RefreshTokenService.hashToken(first.rawToken());
        String secondHash = RefreshTokenService.hashToken(second.rawToken());
        assertThat(firstHash).isNotEqualTo(secondHash);
    }

    @Test
    @DisplayName("issue should reject null userId")
    void issueNullUserId() {
        assertThatThrownBy(() -> service.issue(null))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("userId must not be null");
    }

    @Test
    @DisplayName("constructor should reject zero or negative TTL")
    void constructorRejectsInvalidTtl() {
        assertThatThrownBy(() -> new RefreshTokenService(repository, clock, Duration.ZERO))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("Refresh token TTL must be positive");

        assertThatThrownBy(() -> new RefreshTokenService(repository, clock, Duration.ofDays(-1)))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("Refresh token TTL must be positive");
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
