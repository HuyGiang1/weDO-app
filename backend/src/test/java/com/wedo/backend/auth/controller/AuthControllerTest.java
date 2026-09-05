package com.wedo.backend.auth.controller;

import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.nio.charset.StandardCharsets;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
class AuthControllerTest extends AbstractPostgresIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

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
    @DisplayName("POST /api/v1/auth/register with blank password should return 400 VALIDATION_FAILED")
    void register_blankPassword_shouldReturn400() throws Exception {
        String blankPassword = """
                {
                    "email": "user@example.com",
                    "password": ""
                }
                """;

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(blankPassword))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors.password").isNotEmpty());
    }

    @Test
    @DisplayName("POST /api/v1/auth/register with password shorter than 8 characters should return 400")
    void register_shortPassword_shouldReturn400() throws Exception {
        String shortPassword = """
                {
                    "email": "user.short@example.com",
                    "password": "1234567"
                }
                """;

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(shortPassword))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.errors.password").isNotEmpty());
    }

    @Test
    @DisplayName("POST /api/v1/auth/register with password longer than 72 characters should return 400")
    void register_tooLongPassword_shouldReturn400() throws Exception {
        String longPassword = "a".repeat(73);
        String payload = String.format("""
                {
                    "email": "user.long@example.com",
                    "password": "%s"
                }
                """, longPassword);

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/register with Unicode password exceeding 72 UTF-8 bytes should return 400")
    void register_unicodePasswordExceeding72Bytes_shouldReturn400() throws Exception {
        // 30 characters of 'ế' (\u1E7F, each 3 bytes in UTF-8) = 90 bytes
        String unicodePassword90Bytes = "\u1E7F".repeat(30);
        assertThat(unicodePassword90Bytes.length()).isEqualTo(30);
        assertThat(unicodePassword90Bytes.getBytes(StandardCharsets.UTF_8).length).isEqualTo(90);

        String payload = String.format("""
                {
                    "email": "user.unicode.long@example.com",
                    "password": "%s"
                }
                """, unicodePassword90Bytes);

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/register with Unicode password within 72 UTF-8 bytes should succeed with 201")
    void register_unicodePasswordWithin72Bytes_shouldSucceed() throws Exception {
        // 10 characters of 'ế' = 30 bytes in UTF-8, length = 10 chars (>= 8 and <= 72)
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

        // First registration succeeds
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isCreated());

        // Second registration fails with 409 CONFLICT
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.status").value(409))
                .andExpect(jsonPath("$.code").value("EMAIL_ALREADY_EXISTS"))
                .andExpect(jsonPath("$.message").value("An account with this email already exists."));
    }
}
