package com.wedo.backend.auth.controller;

import com.wedo.backend.auth.dto.CompleteProfileRequest;
import com.wedo.backend.auth.dto.LoginRequest;
import com.wedo.backend.auth.dto.LoginResponse;
import com.wedo.backend.auth.dto.RegisterRequest;
import com.wedo.backend.auth.dto.RegisterResponse;
import com.wedo.backend.auth.dto.VerifyEmailRequest;
import com.wedo.backend.auth.entity.AuthTokenEntity;
import com.wedo.backend.auth.entity.AuthTokenType;
import com.wedo.backend.auth.event.EmailVerificationRequestedEvent;
import com.wedo.backend.auth.repository.AuthTokenRepository;
import com.wedo.backend.auth.service.AuthService;
import com.wedo.backend.auth.security.ProfileCompletionTokenService;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.user.entity.UserCredentialEntity;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserCredentialRepository;
import com.wedo.backend.user.repository.UserRepository;
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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
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
    private ProfileCompletionTokenService profileCompletionTokenService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private UserCredentialRepository userCredentialRepository;

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
                .andExpect(jsonPath("$.profileCompletionToken").isNotEmpty())
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

    // ==========================================
    // M2.6 Username Availability Endpoint Tests
    // ==========================================

    @Test
    @DisplayName("GET /api/v1/auth/usernames/{username}/availability with unused username should return 200 available=true")
    void checkAvailability_unusedUsername_shouldReturn200AvailableTrue() throws Exception {
        mockMvc.perform(get("/api/v1/auth/usernames/fresh_user_99/availability"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username").value("fresh_user_99"))
                .andExpect(jsonPath("$.available").value(true));
    }

    @Test
    @DisplayName("GET /api/v1/auth/usernames/{username}/availability with taken username should return 200 available=false")
    void checkAvailability_takenUsername_shouldReturn200AvailableFalse() throws Exception {
        UUID userId = registerAndVerifyUser("taken.api@example.com");
        String token = profileCompletionTokenService.generate(userId);
        String completePayload = String.format("""
                {
                    "profileCompletionToken": "%s",
                    "username": "taken_api_user",
                    "displayName": "Taken User"
                }
                """, token);

        mockMvc.perform(post("/api/v1/auth/complete-profile")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(completePayload))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/auth/usernames/taken_api_user/availability"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username").value("taken_api_user"))
                .andExpect(jsonPath("$.available").value(false));

        // Case-insensitive check
        mockMvc.perform(get("/api/v1/auth/usernames/TAKEN_API_USER/availability"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username").value("taken_api_user"))
                .andExpect(jsonPath("$.available").value(false));
    }

    @Test
    @DisplayName("GET /api/v1/auth/usernames/{username}/availability invalid format should return 400 VALIDATION_FAILED")
    void checkAvailability_invalidFormat_shouldReturn400() throws Exception {
        // 1. Too short (2 characters)
        mockMvc.perform(get("/api/v1/auth/usernames/ab/availability"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.path").value("/api/v1/auth/usernames/ab/availability"));

        // 2. Special characters (@)
        mockMvc.perform(get("/api/v1/auth/usernames/bad@name/availability"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));

        // 3. Too long (> 30 characters)
        mockMvc.perform(get("/api/v1/auth/usernames/a1234567890123456789012345678901/availability"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));

        // 4. Space in username
        mockMvc.perform(get("/api/v1/auth/usernames/bad name/availability"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    // ==========================================
    // M2.6 Complete Profile Endpoint Tests
    // ==========================================

    @Test
    @DisplayName("POST /api/v1/auth/complete-profile with valid payload should return 200 OK and correct response shape")
    void completeProfile_validPayload_shouldReturn200() throws Exception {
        UUID userId = registerAndVerifyUser("complete.api@example.com");
        String token = profileCompletionTokenService.generate(userId);

        String payload = String.format("""
                {
                    "profileCompletionToken": "%s",
                    "username": "HuyGiang",
                    "displayName": "  Huy Giang  ",
                    "bio": "  Building awesome software  ",
                    "avatarStorageKey": "avatars/2026/09/user_profile.jpg"
                }
                """, token);

        mockMvc.perform(post("/api/v1/auth/complete-profile")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(userId.toString()))
                .andExpect(jsonPath("$.username").value("huygiang"))
                .andExpect(jsonPath("$.displayName").value("Huy Giang"))
                .andExpect(jsonPath("$.status").value("ACTIVE"))
                .andExpect(jsonPath("$.nextStep").value("LOGIN"))
                .andExpect(jsonPath("$.accessToken").doesNotExist())
                .andExpect(jsonPath("$.refreshToken").doesNotExist());
    }

    @Test
    @DisplayName("POST /api/v1/auth/complete-profile DTO validation errors should return 400 VALIDATION_FAILED")
    void completeProfile_validationErrors_shouldReturn400() throws Exception {
        UUID userId = registerAndVerifyUser("validation.api@example.com");
        String token = profileCompletionTokenService.generate(userId);

        // 1. Missing / blank token
        String missingToken = """
                {
                    "profileCompletionToken": "",
                    "username": "valid_user",
                    "displayName": "Valid User"
                }
                """;
        mockMvc.perform(post("/api/v1/auth/complete-profile")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(missingToken))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors.profileCompletionToken").isNotEmpty());

        // 2. Invalid username format (spaces)
        String spacesUsername = String.format("""
                {
                    "profileCompletionToken": "%s",
                    "username": " huygiang ",
                    "displayName": "Valid User"
                }
                """, token);
        mockMvc.perform(post("/api/v1/auth/complete-profile")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(spacesUsername))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors.username").isNotEmpty());

        // 3. Invalid username format (too short)
        String shortUsername = String.format("""
                {
                    "profileCompletionToken": "%s",
                    "username": "ab",
                    "displayName": "Valid User"
                }
                """, token);
        mockMvc.perform(post("/api/v1/auth/complete-profile")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(shortUsername))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors.username").isNotEmpty());

        // 4. Blank displayName
        String blankDisplayName = String.format("""
                {
                    "profileCompletionToken": "%s",
                    "username": "valid_user",
                    "displayName": "   "
                }
                """, token);
        mockMvc.perform(post("/api/v1/auth/complete-profile")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(blankDisplayName))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors.displayName").isNotEmpty());

        // 5. Bio > 500 characters
        String longBio = String.format("""
                {
                    "profileCompletionToken": "%s",
                    "username": "valid_user",
                    "displayName": "Valid User",
                    "bio": "%s"
                }
                """, token, "a".repeat(501));
        mockMvc.perform(post("/api/v1/auth/complete-profile")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(longBio))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors.bio").isNotEmpty());

        // 6. AvatarStorageKey > 255 characters
        String longAvatar = String.format("""
                {
                    "profileCompletionToken": "%s",
                    "username": "valid_user",
                    "displayName": "Valid User",
                    "avatarStorageKey": "%s"
                }
                """, token, "a".repeat(256));
        mockMvc.perform(post("/api/v1/auth/complete-profile")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(longAvatar))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors.avatarStorageKey").isNotEmpty());
    }

    @Test
    @DisplayName("POST /api/v1/auth/complete-profile with invalid or expired token should return 401 UNAUTHORIZED")
    void completeProfile_invalidToken_shouldReturn401() throws Exception {
        // 1. Malformed token
        String malformedPayload = """
                {
                    "profileCompletionToken": "not.a.valid.jwt.token",
                    "username": "valid_user",
                    "displayName": "Valid User"
                }
                """;
        mockMvc.perform(post("/api/v1/auth/complete-profile")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(malformedPayload))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"))
                .andExpect(jsonPath("$.message").value("Invalid or expired profile completion token"));

        // 2. Tampered token
        UUID userId = registerAndVerifyUser("tampered.token@example.com");
        String validToken = profileCompletionTokenService.generate(userId);
        String tamperedToken = validToken.substring(0, validToken.length() - 5) + "abcde";

        String tamperedPayload = String.format("""
                {
                    "profileCompletionToken": "%s",
                    "username": "valid_user",
                    "displayName": "Valid User"
                }
                """, tamperedToken);
        mockMvc.perform(post("/api/v1/auth/complete-profile")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(tamperedPayload))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/complete-profile sequential replay should return 409 PROFILE_ALREADY_COMPLETED")
    void completeProfile_sequentialReplay_shouldReturn409() throws Exception {
        UUID userId = registerAndVerifyUser("replay.api@example.com");
        String token = profileCompletionTokenService.generate(userId);

        String payload = String.format("""
                {
                    "profileCompletionToken": "%s",
                    "username": "replay_user",
                    "displayName": "Replay User"
                }
                """, token);

        mockMvc.perform(post("/api/v1/auth/complete-profile")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/v1/auth/complete-profile")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.status").value(409))
                .andExpect(jsonPath("$.code").value("PROFILE_ALREADY_COMPLETED"))
                .andExpect(jsonPath("$.message").value("Profile has already been completed."));
    }

    @Test
    @DisplayName("POST /api/v1/auth/complete-profile duplicate username should return 409 USERNAME_ALREADY_EXISTS")
    void completeProfile_duplicateUsername_shouldReturn409() throws Exception {
        UUID user1Id = registerAndVerifyUser("dup1.api@example.com");
        String token1 = profileCompletionTokenService.generate(user1Id);
        String payload1 = String.format("""
                {
                    "profileCompletionToken": "%s",
                    "username": "occupied_user",
                    "displayName": "Occupied User"
                }
                """, token1);
        mockMvc.perform(post("/api/v1/auth/complete-profile")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload1))
                .andExpect(status().isOk());

        UUID user2Id = registerAndVerifyUser("dup2.api@example.com");
        String token2 = profileCompletionTokenService.generate(user2Id);
        String payload2 = String.format("""
                {
                    "profileCompletionToken": "%s",
                    "username": "occupied_user",
                    "displayName": "Second User"
                }
                """, token2);
        mockMvc.perform(post("/api/v1/auth/complete-profile")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload2))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.status").value(409))
                .andExpect(jsonPath("$.code").value("USERNAME_ALREADY_EXISTS"))
                .andExpect(jsonPath("$.message").value("Username is already taken."));
    }

    @Test
    @DisplayName("POST /api/v1/auth/complete-profile for unverified user should return 403 ACCESS_DENIED")
    void completeProfile_unverifiedUser_shouldReturn403() throws Exception {
        RegisterResponse reg = authService.register(new RegisterRequest("unverified.api@example.com", "Password123!"));
        String token = profileCompletionTokenService.generate(reg.userId());

        String payload = String.format("""
                {
                    "profileCompletionToken": "%s",
                    "username": "unverified_user",
                    "displayName": "Unverified User"
                }
                """, token);

        mockMvc.perform(post("/api/v1/auth/complete-profile")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.status").value(403))
                .andExpect(jsonPath("$.code").value("ACCESS_DENIED"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/complete-profile with unknown userId token should return 404 RESOURCE_NOT_FOUND")
    void completeProfile_unknownUser_shouldReturn404() throws Exception {
        UUID unknownId = UUID.randomUUID();
        String token = profileCompletionTokenService.generate(unknownId);

        String payload = String.format("""
                {
                    "profileCompletionToken": "%s",
                    "username": "ghost_api_user",
                    "displayName": "Ghost User"
                }
                """, token);

        mockMvc.perform(post("/api/v1/auth/complete-profile")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.code").value("RESOURCE_NOT_FOUND"));
    }

    private UUID registerAndVerifyUser(String email) {
        RegisterResponse reg = authService.register(new RegisterRequest(email, "Password123!"));
        String code = getLatestVerificationCode(reg.userId());
        authService.verifyEmail(new VerifyEmailRequest(reg.userId(), code));
        return reg.userId();
    }

    // ==========================================
    // M2.7 Login Endpoint Tests
    // ==========================================

    @Test
    @DisplayName("POST /api/v1/auth/login with valid credentials fully onboarded should return 200 and auth payload")
    void login_fullyOnboarded_shouldReturn200() throws Exception {
        String email = "login.full@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "loginuser", "Login User", null, null));

        String payload = String.format("""
                {
                    "email": "%s",
                    "password": "Password123!"
                }
                """, email);

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(userId.toString()))
                .andExpect(jsonPath("$.status").value("ACTIVE"))
                .andExpect(jsonPath("$.nextStep").value("AUTHENTICATED"))
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty())
                .andExpect(jsonPath("$.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.accessTokenExpiresAt").isNotEmpty())
                .andExpect(jsonPath("$.user.id").value(userId.toString()))
                .andExpect(jsonPath("$.user.email").value(email))
                .andExpect(jsonPath("$.user.username").value("loginuser"))
                .andExpect(jsonPath("$.user.displayName").value("Login User"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/login with incomplete profile should return 200 and recovery payload")
    void login_incompleteProfile_shouldReturn200Recovery() throws Exception {
        String email = "login.incomplete@example.com";
        UUID userId = registerAndVerifyUser(email);

        String payload = String.format("""
                {
                    "email": "%s",
                    "password": "Password123!"
                }
                """, email);

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(userId.toString()))
                .andExpect(jsonPath("$.status").value("ACTIVE"))
                .andExpect(jsonPath("$.nextStep").value("COMPLETE_PROFILE"))
                .andExpect(jsonPath("$.profileCompletionToken").isNotEmpty())
                .andExpect(jsonPath("$.accessToken").doesNotExist())
                .andExpect(jsonPath("$.refreshToken").doesNotExist());
    }

    @Test
    @DisplayName("POST /api/v1/auth/login validation errors should return 400 VALIDATION_FAILED")
    void login_validationErrors_shouldReturn400() throws Exception {
        // Blank email
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                    "email": "",
                                    "password": "Password123!"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));

        // Invalid email
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                    "email": "not-an-email",
                                    "password": "Password123!"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));

        // Blank password
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                    "email": "valid@example.com",
                                    "password": "   "
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));

        // Password > 72 UTF-8 bytes
        String tooLongPassword = "a".repeat(73);
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(String.format("""
                                {
                                    "email": "valid@example.com",
                                    "password": "%s"
                                }
                                """, tooLongPassword)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors.passwordByteLengthValid").value("Password must not exceed 72 bytes in UTF-8 encoding"));

        // Exactly 72 UTF-8 bytes should NOT fail for byte length
        String exact72BytesPassword = "a".repeat(72);
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(String.format("""
                                {
                                    "email": "valid@example.com",
                                    "password": "%s"
                                }
                                """, exact72BytesPassword)))
                .andExpect(status().isUnauthorized()); // passes validation, fails authentication
    }

    @Test
    @DisplayName("POST /api/v1/auth/login with unknown email should return 401 AUTH_INVALID_CREDENTIALS")
    void login_unknownEmail_shouldReturn401() throws Exception {
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                    "email": "unknown@example.com",
                                    "password": "Password123!"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("AUTH_INVALID_CREDENTIALS"))
                .andExpect(jsonPath("$.message").value("Invalid email or password."));
    }

    @Test
    @DisplayName("POST /api/v1/auth/login with wrong password should return 401 AUTH_INVALID_CREDENTIALS")
    void login_wrongPassword_shouldReturn401() throws Exception {
        String email = "wrong.pwd@example.com";
        registerAndVerifyUser(email);

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(String.format("""
                                {
                                    "email": "%s",
                                    "password": "WrongPassword1!"
                                }
                                """, email)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("AUTH_INVALID_CREDENTIALS"))
                .andExpect(jsonPath("$.message").value("Invalid email or password."));
    }

    @Test
    @DisplayName("POST /api/v1/auth/login with non-ACTIVE status should return 403 status errors")
    void login_nonActiveStatus_shouldReturn403() throws Exception {
        // 1. PENDING_VERIFICATION
        String pendingEmail = "pending.login@example.com";
        authService.register(new RegisterRequest(pendingEmail, "Password123!"));

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(String.format("""
                                {
                                    "email": "%s",
                                    "password": "Password123!"
                                }
                                """, pendingEmail)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.status").value(403))
                .andExpect(jsonPath("$.code").value("EMAIL_NOT_VERIFIED"));

        // 2. SUSPENDED
        String suspendedEmail = "suspended.login@example.com";
        UUID suspendedId = registerAndVerifyUser(suspendedEmail);
        UserEntity suspendedUser = userRepository.findById(suspendedId).orElseThrow();
        suspendedUser.setStatus(UserStatus.SUSPENDED);
        userRepository.save(suspendedUser);

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(String.format("""
                                {
                                    "email": "%s",
                                    "password": "Password123!"
                                }
                                """, suspendedEmail)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.status").value(403))
                .andExpect(jsonPath("$.code").value("ACCOUNT_SUSPENDED"));

        // 3. DEACTIVATED
        String deactivatedEmail = "deactivated.login@example.com";
        UUID deactivatedId = registerAndVerifyUser(deactivatedEmail);
        UserEntity deactivatedUser = userRepository.findById(deactivatedId).orElseThrow();
        deactivatedUser.setStatus(UserStatus.DEACTIVATED);
        userRepository.save(deactivatedUser);

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(String.format("""
                                {
                                    "email": "%s",
                                    "password": "Password123!"
                                }
                                """, deactivatedEmail)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.status").value(403))
                .andExpect(jsonPath("$.code").value("ACCOUNT_DEACTIVATED"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/login when account locked and password correct should return 423 ACCOUNT_LOCKED")
    void login_lockedAccount_correctPassword_shouldReturn423() throws Exception {
        String email = "locked.login@example.com";
        UUID userId = registerAndVerifyUser(email);
        UserCredentialEntity cred = userCredentialRepository.findById(userId).orElseThrow();
        cred.setLockedUntil(Instant.now().plus(Duration.ofMinutes(15)));
        userCredentialRepository.save(cred);

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(String.format("""
                                {
                                    "email": "%s",
                                    "password": "Password123!"
                                }
                                """, email)))
                .andExpect(status().isLocked())
                .andExpect(jsonPath("$.status").value(423))
                .andExpect(jsonPath("$.code").value("ACCOUNT_LOCKED"))
                .andExpect(jsonPath("$.message").value("Account is temporarily locked."));
    }

    // ==========================================
    // M2.8 Refresh Token Rotation Tests
    // ==========================================

    @Test
    @DisplayName("POST /api/v1/auth/refresh with valid token should return 200 and new credentials")
    void refresh_validToken_shouldReturn200() throws Exception {
        String email = "refresh.api.valid@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "refreshuser", "Refresh User", null, null));

        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"));
        String rawRefresh = loginResp.refreshToken();

        String payload = String.format("""
                {
                    "refreshToken": "%s"
                }
                """, rawRefresh);

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty())
                .andExpect(jsonPath("$.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.accessTokenExpiresAt").isNotEmpty())
                .andExpect(jsonPath("$.refreshTokenExpiresAt").isNotEmpty());
    }

    @Test
    @DisplayName("POST /api/v1/auth/refresh with null token should return 400 VALIDATION_FAILED")
    void refresh_nullToken_shouldReturn400() throws Exception {
        String payload = """
                {
                    "refreshToken": null
                }
                """;

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors.refreshToken").isNotEmpty());
    }

    @Test
    @DisplayName("POST /api/v1/auth/refresh with empty token should return 400 VALIDATION_FAILED")
    void refresh_emptyToken_shouldReturn400() throws Exception {
        String payload = """
                {
                    "refreshToken": ""
                }
                """;

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors.refreshToken").isNotEmpty());
    }

    @Test
    @DisplayName("POST /api/v1/auth/refresh with whitespace token should return 400 VALIDATION_FAILED")
    void refresh_whitespaceToken_shouldReturn400() throws Exception {
        String payload = """
                {
                    "refreshToken": "   "
                }
                """;

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors.refreshToken").isNotEmpty());
    }

    @Test
    @DisplayName("POST /api/v1/auth/refresh with invalid token should return 401 REFRESH_TOKEN_INVALID")
    void refresh_invalidToken_shouldReturn401() throws Exception {
        String payload = """
                {
                    "refreshToken": "invalid-non-existent-refresh-token"
                }
                """;

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("REFRESH_TOKEN_INVALID"))
                .andExpect(jsonPath("$.message").value("Invalid refresh token."));
    }

    @Test
    @DisplayName("POST /api/v1/auth/refresh for suspended user should return 403 ACCOUNT_SUSPENDED")
    void refresh_suspendedUser_shouldReturn403() throws Exception {
        String email = "refresh.suspended@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "ref_susp", "Ref Susp", null, null));

        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"));
        String rawRefresh = loginResp.refreshToken();

        UserEntity user = userRepository.findById(userId).orElseThrow();
        user.setStatus(UserStatus.SUSPENDED);
        userRepository.save(user);

        String payload = String.format("""
                {
                    "refreshToken": "%s"
                }
                """, rawRefresh);

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.status").value(403))
                .andExpect(jsonPath("$.code").value("ACCOUNT_SUSPENDED"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/refresh for deactivated user should return 403 ACCOUNT_DEACTIVATED")
    void refresh_deactivatedUser_shouldReturn403() throws Exception {
        String email = "refresh.deact@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "ref_deact", "Ref Deact", null, null));

        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"));
        String rawRefresh = loginResp.refreshToken();

        UserEntity user = userRepository.findById(userId).orElseThrow();
        user.setStatus(UserStatus.DEACTIVATED);
        userRepository.save(user);

        String payload = String.format("""
                {
                    "refreshToken": "%s"
                }
                """, rawRefresh);

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.status").value(403))
                .andExpect(jsonPath("$.code").value("ACCOUNT_DEACTIVATED"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/logout with valid token should return 204 No Content and empty body")
    void logout_validToken_shouldReturn204() throws Exception {
        String email = "logout.valid@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "log_valid", "Log Valid", null, null));

        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"));
        String rawRefresh = loginResp.refreshToken();

        String payload = String.format("""
                {
                    "refreshToken": "%s"
                }
                """, rawRefresh);

        mockMvc.perform(post("/api/v1/auth/logout")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isNoContent())
                .andExpect(content().string(""));
    }

    @Test
    @DisplayName("POST /api/v1/auth/logout with already non-rotated revoked session should return 204 No Content idempotently")
    void logout_alreadyNonRotatedRevoked_shouldReturn204() throws Exception {
        String email = "logout.idemp@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "log_idemp", "Log Idemp", null, null));

        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"));
        String rawRefresh = loginResp.refreshToken();

        String payload = String.format("""
                {
                    "refreshToken": "%s"
                }
                """, rawRefresh);

        // First call
        mockMvc.perform(post("/api/v1/auth/logout")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isNoContent())
                .andExpect(content().string(""));

        // Second call (idempotent)
        mockMvc.perform(post("/api/v1/auth/logout")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isNoContent())
                .andExpect(content().string(""));
    }

    @Test
    @DisplayName("POST /api/v1/auth/logout with random unknown token should return 401 REFRESH_TOKEN_INVALID")
    void logout_invalidRandomToken_shouldReturn401() throws Exception {
        mockMvc.perform(post("/api/v1/auth/logout")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                    "refreshToken": "random-unknown-refresh-token"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("REFRESH_TOKEN_INVALID"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/logout with rotated old token should return 401 REFRESH_TOKEN_INVALID")
    void logout_rotatedOldToken_shouldReturn401() throws Exception {
        String email = "logout.rotated@example.com";
        UUID userId = registerAndVerifyUser(email);
        String token = profileCompletionTokenService.generate(userId);
        authService.completeProfile(new CompleteProfileRequest(token, "log_rotated", "Log Rotated", null, null));

        LoginResponse loginResp = authService.login(new LoginRequest(email, "Password123!"));
        String raw1 = loginResp.refreshToken();

        // Rotate raw1 -> raw2
        authService.refreshToken(new com.wedo.backend.auth.dto.RefreshTokenRequest(raw1));

        String payload = String.format("""
                {
                    "refreshToken": "%s"
                }
                """, raw1);

        mockMvc.perform(post("/api/v1/auth/logout")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("REFRESH_TOKEN_INVALID"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/logout with null refreshToken should return 400 VALIDATION_FAILED")
    void logout_nullRefreshToken_shouldReturn400() throws Exception {
        mockMvc.perform(post("/api/v1/auth/logout")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                    "refreshToken": null
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/logout with empty refreshToken should return 400 VALIDATION_FAILED")
    void logout_emptyRefreshToken_shouldReturn400() throws Exception {
        mockMvc.perform(post("/api/v1/auth/logout")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                    "refreshToken": ""
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/logout with whitespace refreshToken should return 400 VALIDATION_FAILED")
    void logout_whitespaceRefreshToken_shouldReturn400() throws Exception {
        mockMvc.perform(post("/api/v1/auth/logout")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                    "refreshToken": "   "
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }
}
