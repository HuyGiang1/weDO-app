package com.wedo.backend.auth.dto;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class LoginRequestLogSafetyTest {
    @Test
    void diagnosticRepresentationNeverDisclosesCredentials() {
        String password = "Synthetic!" + java.util.UUID.randomUUID();
        LoginRequest request = new LoginRequest("synthetic@example.invalid", password);
        assertThat(request.toString()).doesNotContain(password, "synthetic@example.invalid");
    }

    @Test
    void loginResponseDiagnosticsDoNotExposeAnyToken() {
        String token = "synthetic-" + java.util.UUID.randomUUID();
        LoginResponse response = new LoginResponse(java.util.UUID.randomUUID(),
                com.wedo.backend.user.entity.UserStatus.ACTIVE, "AUTHENTICATED",
                token + "-profile", token + "-access", token + "-refresh", "Bearer",
                java.time.Instant.now(), null);
        assertThat(response.toString()).doesNotContain(token);
    }

    @Test
    void refreshRequestDiagnosticsDoNotExposeTheCredential() {
        String token = "synthetic-" + java.util.UUID.randomUUID();
        assertThat(new RefreshTokenRequest(token).toString()).doesNotContain(token);
    }
}
