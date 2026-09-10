package com.wedo.backend.e2e;

import com.wedo.backend.auth.entity.AuthTokenEntity;
import com.wedo.backend.auth.entity.AuthTokenType;
import com.wedo.backend.auth.repository.AuthTokenRepository;
import com.wedo.backend.auth.security.AuthTokenHasher;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Test-scoped verification OTP resolver for live E2E testing.
 *
 * <p>Reads the authoritative EMAIL_VERIFICATION token hash from the real local
 * PostgreSQL database, evaluates the finite 6-digit candidate space using
 * the production {@link AuthTokenHasher}, and writes ONLY the resolved code
 * into the provided temporary IPC file.</p>
 *
 * <p>Never prints the code to stdout/stderr. Never mutates the auth_tokens row.</p>
 */
@SpringBootTest
@ActiveProfiles("local")
@EnabledIfSystemProperty(named = "wedo.e2e.user-id", matches = ".+")
class OtpResolverTest {

    @Autowired
    private AuthTokenRepository authTokenRepository;

    @Autowired
    private AuthTokenHasher authTokenHasher;

    @Test
    @DisplayName("Resolve 6-digit email verification code for live E2E user")
    void resolveEmailVerificationOtp() throws IOException {
        String userIdProp = System.getProperty("wedo.e2e.user-id");
        if (userIdProp == null || userIdProp.isBlank()) {
            userIdProp = System.getenv("WEDO_E2E_USER_ID");
        }
        assertThat(userIdProp)
                .as("wedo.e2e.user-id system property or WEDO_E2E_USER_ID environment variable must be provided")
                .isNotBlank();

        UUID userId = UUID.fromString(userIdProp.trim());

        String outputPath = System.getProperty("wedo.e2e.otp-output-file");
        if (outputPath == null || outputPath.isBlank()) {
            outputPath = System.getenv("WEDO_E2E_OTP_OUTPUT_FILE");
        }
        assertThat(outputPath)
                .as("wedo.e2e.otp-output-file system property or WEDO_E2E_OTP_OUTPUT_FILE environment variable must be provided")
                .isNotBlank();

        Optional<AuthTokenEntity> tokenOpt = authTokenRepository
                .findFirstByUserIdAndTokenTypeAndConsumedAtIsNullOrderByCreatedAtDesc(
                        userId,
                        AuthTokenType.EMAIL_VERIFICATION
                );

        assertThat(tokenOpt)
                .as("Active EMAIL_VERIFICATION token record must exist in auth_tokens for user")
                .isPresent();

        AuthTokenEntity token = tokenOpt.get();
        String storedHash = token.getTokenHash();
        assertThat(storedHash).isNotBlank();

        String matchedCode = null;
        for (int i = 0; i <= 999999; i++) {
            String candidate = String.format("%06d", i);
            if (authTokenHasher.matches(userId, AuthTokenType.EMAIL_VERIFICATION, candidate, storedHash)) {
                matchedCode = candidate;
                break;
            }
        }

        assertThat(matchedCode)
                .as("Verification code must match 6-digit candidate space")
                .isNotNull();

        Path path = Path.of(outputPath.trim());
        if (path.getParent() != null) {
            Files.createDirectories(path.getParent());
        }
        Files.writeString(path, matchedCode, StandardCharsets.UTF_8);
    }
}
