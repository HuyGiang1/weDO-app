package com.wedo.backend.auth.controller;

import com.wedo.backend.auth.dto.RegisterRequest;
import com.wedo.backend.auth.dto.RegisterResponse;
import com.wedo.backend.auth.entity.AuthTokenEntity;
import com.wedo.backend.auth.entity.AuthTokenType;
import com.wedo.backend.auth.event.EmailVerificationRequestedEvent;
import com.wedo.backend.auth.repository.AuthTokenRepository;
import com.wedo.backend.auth.service.AuthService;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.event.ApplicationEvents;
import org.springframework.test.context.event.RecordApplicationEvents;
import org.springframework.test.web.servlet.MockMvc;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@RecordApplicationEvents
class AuthControllerTest extends AbstractPostgresIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private AuthService authService;

    @Autowired
    private AuthTokenRepository authTokenRepository;

    @Autowired
    private ApplicationEvents applicationEvents;

    private String getLatestVerificationCode(UUID userId) {
        return applicationEvents.stream(EmailVerificationRequestedEvent.class)
                .filter(e -> e.userId().equals(userId))
                .reduce((first, second) -> second)
                .orElseThrow(() -> new IllegalStateException("No verification event for user: " + userId))
                .rawCode();
    }

    @Test
    @DisplayName("POST /api/v1/auth/register with valid payload should return 201 Created and correct response body")
    void register_validPayload_shouldReturn201() throws Exception {
        String json = """
                {
                    "email": "Bob.Marley@Example.COM",
                    "password": "ValidPassword123!"
                }
                """;

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.userId").isNotEmpty())
                .andExpect(jsonPath("$.email").value("bob.marley@example.com"))
                .andExpect(jsonPath("$.status").value("PENDING_VERIFICATION"))
                .andExpect(jsonPath("$.nextStep").value("VERIFY_EMAIL"))
                .andExpect(jsonPath("$.accessToken").doesNotExist())
                .andExpect(jsonPath("$.refreshToken").doesNotExist())
                .andExpect(jsonPath("$.password").doesNotExist())
                .andExpect(jsonPath("$.passwordHash").doesNotExist())
                .andExpect(jsonPath("$.code").doesNotExist())
                .andExpect(jsonPath("$.rawCode").doesNotExist())
                .andExpect(header().doesNotExist("Set-Cookie"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/register with blank or invalid email should return 400 VALIDATION_FAILED")
    void register_invalidEmail_shouldReturn400() throws Exception {
        String blankEmail = """
                {
                    "email": "",
                    "password": "ValidPassword123!"
                }
                """;

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(blankEmail))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors.email").isNotEmpty());

        String malformedEmail = """
                {
                    "email": "not-an-email",
                    "password": "ValidPassword123!"
                }
                """;

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(malformedEmail))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors.email").isNotEmpty());
    }

    @Test
    @DisplayName("POST /api/v1/auth/register with short password (< 8 chars) should return 400 VALIDATION_FAILED")
    void register_shortPassword_shouldReturn400() throws Exception {
        String json = """
                {
                    "email": "short.pwd@example.com",
                    "password": "short"
                }
                """;

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors.password").isNotEmpty());
    }

    @Test
    @DisplayName("POST /api/v1/auth/register with long password (> 72 chars) should return 400 VALIDATION_FAILED")
    void register_longPassword_shouldReturn400() throws Exception {
        String longPassword = "a".repeat(73);
        String json = String.format("""
                {
                    "email": "long.pwd@example.com",
                    "password": "%s"
                }
                """, longPassword);

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors.password").isNotEmpty());
    }

    @Test
    @DisplayName("POST /api/v1/auth/register with password having <=72 chars but >72 UTF-8 bytes should return 400 VALIDATION_FAILED")
    void register_passwordExceeding72Utf8Bytes_shouldReturn400() throws Exception {
        String unicodePassword75Bytes = "\u1E7F".repeat(25);
        assertThat(unicodePassword75Bytes.length()).isEqualTo(25);
        assertThat(unicodePassword75Bytes.getBytes(StandardCharsets.UTF_8).length).isEqualTo(75);

        String payload = String.format("""
                {
                    "email": "user.unicode.invalid@example.com",
                    "password": "%s"
                }
                """, unicodePassword75Bytes);

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors.passwordByteLengthValid")
                        .value("Password must not exceed 72 bytes in UTF-8 encoding"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/register with unicode password <=72 UTF-8 bytes should succeed 201 Created")
    void register_passwordWithin72Utf8Bytes_shouldSucceed() throws Exception {
        String unicodePassword30Bytes = "\u1E7F".repeat(10);
        assertThat(unicodePassword30Bytes.length()).isEqualTo(10);
        assertThat(unicodePassword30Bytes.getBytes(StandardCharsets.UTF_8).length).isEqualTo(30);

        String payload = String.format("""
                {
                    "email": "user.unicode.valid@example.com",
                    "password": "%s"
                }
                """, unicodePassword30Bytes);

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.userId").isNotEmpty())
                .andExpect(jsonPath("$.email").value("user.unicode.valid@example.com"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/register with duplicate email should return 409 EMAIL_ALREADY_EXISTS")
    void register_duplicateEmail_shouldReturn409() throws Exception {
        String payload = """
                {
                    "email": "duplicate.api@example.com",
                    "password": "Password123!"
                }
                """;

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isCreated());

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.status").value(409))
                .andExpect(jsonPath("$.code").value("EMAIL_ALREADY_EXISTS"))
                .andExpect(jsonPath("$.message").value("An account with this email already exists."));
    }

    // ==========================================
    // M2.5 Verify Email Endpoint Tests
    // ==========================================

    @Test
    @DisplayName("POST /api/v1/auth/verify-email with valid payload should return 200 OK")
    void verifyEmail_validPayload_shouldReturn200() throws Exception {
        RegisterResponse reg = authService.register(new RegisterRequest("api.verify.success@example.com", "Password123!"));
        UUID userId = reg.userId();
        String code = getLatestVerificationCode(userId);

        String payload = String.format("""
                {
                    "userId": "%s",
                    "code": "%s"
                }
                """, userId, code);

        mockMvc.perform(post("/api/v1/auth/verify-email")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(userId.toString()))
                .andExpect(jsonPath("$.status").value("ACTIVE"))
                .andExpect(jsonPath("$.emailVerifiedAt").isNotEmpty())
                .andExpect(jsonPath("$.nextStep").value("COMPLETE_PROFILE"))
                .andExpect(jsonPath("$.accessToken").doesNotExist())
                .andExpect(jsonPath("$.refreshToken").doesNotExist());
    }

    @Test
    @DisplayName("POST /api/v1/auth/verify-email DTO validation errors should return 400 VALIDATION_FAILED")
    void verifyEmail_validationErrors_shouldReturn400() throws Exception {
        // 1. null userId
        String nullUser = """
                {
                    "userId": null,
                    "code": "123456"
                }
                """;
        mockMvc.perform(post("/api/v1/auth/verify-email")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(nullUser))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors.userId").isNotEmpty());

        // 2. blank code
        String blankCode = """
                {
                    "userId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
                    "code": ""
                }
                """;
        mockMvc.perform(post("/api/v1/auth/verify-email")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(blankCode))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors.code").isNotEmpty());

        // 3. 5 digits
        String fiveDigits = """
                {
                    "userId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
                    "code": "12345"
                }
                """;
        mockMvc.perform(post("/api/v1/auth/verify-email")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(fiveDigits))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors.code").isNotEmpty());

        // 4. 7 digits
        String sevenDigits = """
                {
                    "userId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
                    "code": "1234567"
                }
                """;
        mockMvc.perform(post("/api/v1/auth/verify-email")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(sevenDigits))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors.code").isNotEmpty());

        // 5. alphabetic code
        String alphaCode = """
                {
                    "userId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
                    "code": "abcdef"
                }
                """;
        mockMvc.perform(post("/api/v1/auth/verify-email")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(alphaCode))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors.code").isNotEmpty());

        // 6. whitespace-padded code (" 123456 ")
        String whitespaceCode = """
                {
                    "userId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
                    "code": " 123456 "
                }
                """;
        mockMvc.perform(post("/api/v1/auth/verify-email")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(whitespaceCode))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors.code").isNotEmpty());
    }

    @Test
    @DisplayName("POST /api/v1/auth/verify-email with invalid code should return 400 VERIFICATION_CODE_INVALID")
    void verifyEmail_invalidCode_shouldReturn400() throws Exception {
        RegisterResponse reg = authService.register(new RegisterRequest("api.verify.invalid@example.com", "Password123!"));
        UUID userId = reg.userId();

        String payload = String.format("""
                {
                    "userId": "%s",
                    "code": "999999"
                }
                """, userId);

        mockMvc.perform(post("/api/v1/auth/verify-email")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.code").value("VERIFICATION_CODE_INVALID"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/verify-email with already active user should return 409 EMAIL_ALREADY_VERIFIED")
    void verifyEmail_alreadyVerified_shouldReturn409() throws Exception {
        RegisterResponse reg = authService.register(new RegisterRequest("api.verify.already@example.com", "Password123!"));
        UUID userId = reg.userId();
        String code = getLatestVerificationCode(userId);

        authService.verifyEmail(new com.wedo.backend.auth.dto.VerifyEmailRequest(userId, code));

        String payload = String.format("""
                {
                    "userId": "%s",
                    "code": "%s"
                }
                """, userId, code);

        mockMvc.perform(post("/api/v1/auth/verify-email")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.status").value(409))
                .andExpect(jsonPath("$.code").value("EMAIL_ALREADY_VERIFIED"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/verify-email with unknown user should return 404 RESOURCE_NOT_FOUND")
    void verifyEmail_unknownUser_shouldReturn404() throws Exception {
        UUID unknownId = UUID.randomUUID();

        String payload = String.format("""
                {
                    "userId": "%s",
                    "code": "123456"
                }
                """, unknownId);

        mockMvc.perform(post("/api/v1/auth/verify-email")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.code").value("RESOURCE_NOT_FOUND"));
    }

    // ==========================================
    // M2.5 Resend Verification Endpoint Tests
    // ==========================================

    @Test
    @DisplayName("POST /api/v1/auth/resend-verification with valid payload after cooldown should return 200 OK")
    void resendVerification_validPayload_shouldReturn200() throws Exception {
        RegisterResponse reg = authService.register(new RegisterRequest("api.resend.valid@example.com", "Password123!"));
        UUID userId = reg.userId();

        // Simulate 65s passed by shifting token.createdAt
        AuthTokenEntity token = authTokenRepository
                .findFirstByUserIdAndTokenTypeOrderByCreatedAtDesc(userId, AuthTokenType.EMAIL_VERIFICATION)
                .orElseThrow();
        token.setCreatedAt(Instant.now().minus(Duration.ofSeconds(65)));
        authTokenRepository.save(token);

        String payload = String.format("""
                {
                    "userId": "%s"
                }
                """, userId);

        mockMvc.perform(post("/api/v1/auth/resend-verification")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(userId.toString()))
                .andExpect(jsonPath("$.cooldownSeconds").value(60));
    }

    @Test
    @DisplayName("POST /api/v1/auth/resend-verification with null userId should return 400 VALIDATION_FAILED")
    void resendVerification_nullUserId_shouldReturn400() throws Exception {
        String payload = """
                {
                    "userId": null
                }
                """;

        mockMvc.perform(post("/api/v1/auth/resend-verification")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors.userId").isNotEmpty());
    }

    @Test
    @DisplayName("POST /api/v1/auth/resend-verification within 60s cooldown should return 429 RESEND_COOLDOWN_ACTIVE")
    void resendVerification_cooldownActive_shouldReturn429() throws Exception {
        RegisterResponse reg = authService.register(new RegisterRequest("api.resend.cooldown@example.com", "Password123!"));
        UUID userId = reg.userId();

        String payload = String.format("""
                {
                    "userId": "%s"
                }
                """, userId);

        mockMvc.perform(post("/api/v1/auth/resend-verification")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.status").value(429))
                .andExpect(jsonPath("$.code").value("RESEND_COOLDOWN_ACTIVE"))
                .andExpect(jsonPath("$.message").value("Please wait before requesting another verification code."));
    }

    @Test
    @DisplayName("POST /api/v1/auth/resend-verification with unknown user should return 404 RESOURCE_NOT_FOUND")
    void resendVerification_unknownUser_shouldReturn404() throws Exception {
        UUID unknownId = UUID.randomUUID();

        String payload = String.format("""
                {
                    "userId": "%s"
                }
                """, unknownId);

        mockMvc.perform(post("/api/v1/auth/resend-verification")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.code").value("RESOURCE_NOT_FOUND"));
    }
}
