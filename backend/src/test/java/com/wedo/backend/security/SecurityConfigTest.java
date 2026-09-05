package com.wedo.backend.security;

import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
class SecurityConfigTest extends AbstractPostgresIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Test
    @DisplayName("PasswordEncoder bean should exist in Spring context and be functional")
    void passwordEncoderBean_shouldExistAndBeFunctional() {
        assertThat(passwordEncoder).isNotNull();
        assertThat(passwordEncoder).isInstanceOf(BCryptPasswordEncoder.class);

        String raw = "samplePassword";
        String encoded = passwordEncoder.encode(raw);

        assertThat(passwordEncoder.matches(raw, encoded)).isTrue();
    }

    @Test
    @DisplayName("GET /api/v1/health should be permitted for all without authentication")
    void getHealth_shouldBePublic() throws Exception {
        mockMvc.perform(get("/api/v1/health"))
                .andExpect(status().isOk())
                .andExpect(header().doesNotExist("Set-Cookie"));
    }

    @Test
    @DisplayName("GET /actuator/health should be permitted for all without authentication")
    void getActuatorHealth_shouldBePublic() throws Exception {
        mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk())
                .andExpect(header().doesNotExist("Set-Cookie"));
    }

    @Test
    @DisplayName("GET /v3/api-docs should be permitted for all without authentication")
    void getSwaggerDocs_shouldBePublic() throws Exception {
        mockMvc.perform(get("/v3/api-docs"))
                .andExpect(status().isOk())
                .andExpect(header().doesNotExist("Set-Cookie"));
    }

    @Test
    @DisplayName("GET unauthenticated protected route should return exactly 401 Unauthorized JSON with matching X-Request-Id and no redirect")
    void getUnauthenticatedProtected_shouldReturn401UnauthorizedJsonWithMatchingRequestId() throws Exception {
        String testRequestId = "test-req-id-401";

        mockMvc.perform(get("/api/v1/non-existent-protected")
                        .header("X-Request-Id", testRequestId))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(header().string("X-Request-Id", testRequestId))
                .andExpect(header().doesNotExist("Location"))
                .andExpect(header().doesNotExist("WWW-Authenticate"))
                .andExpect(header().doesNotExist("Set-Cookie"))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"))
                .andExpect(jsonPath("$.message").value("Authentication is required."))
                .andExpect(jsonPath("$.path").value("/api/v1/non-existent-protected"))
                .andExpect(jsonPath("$.requestId").value(testRequestId))
                .andExpect(jsonPath("$.timestamp").isNotEmpty());
    }

    @Test
    @DisplayName("POST /api/v1/auth/register should be permitted without authentication")
    void postRegister_shouldBePublic() throws Exception {
        String payload = """
                {
                    "email": "security.public@example.com",
                    "password": "Password123!"
                }
                """;

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.userId").isNotEmpty())
                .andExpect(jsonPath("$.email").value("security.public@example.com"));
    }

    @Test
    @DisplayName("GET /api/v1/auth/register without authentication should return exactly 401 Unauthorized")
    void getRegister_unauthenticated_shouldReturn401() throws Exception {
        mockMvc.perform(get("/api/v1/auth/register"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/verify-email should be permitted without authentication (not 401)")
    void postVerifyEmail_shouldBePublic() throws Exception {
        mockMvc.perform(post("/api/v1/auth/verify-email")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    @Test
    @DisplayName("GET /api/v1/auth/verify-email without authentication should return exactly 401 Unauthorized")
    void getVerifyEmail_unauthenticated_shouldReturn401() throws Exception {
        mockMvc.perform(get("/api/v1/auth/verify-email"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/resend-verification should be permitted without authentication (not 401)")
    void postResendVerification_shouldBePublic() throws Exception {
        mockMvc.perform(post("/api/v1/auth/resend-verification")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    @Test
    @DisplayName("GET /api/v1/auth/resend-verification without authentication should return exactly 401 Unauthorized")
    void getResendVerification_unauthenticated_shouldReturn401() throws Exception {
        mockMvc.perform(get("/api/v1/auth/resend-verification"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    @DisplayName("GET /api/v1/auth/usernames/{username}/availability should be permitted without authentication (reaches endpoint)")
    void getUsernameAvailability_shouldBePublic() throws Exception {
        mockMvc.perform(get("/api/v1/auth/usernames/huygiang/availability"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username").value("huygiang"))
                .andExpect(jsonPath("$.available").isBoolean());
    }

    @Test
    @DisplayName("POST /api/v1/auth/usernames/{username}/availability without authentication should return 401 Unauthorized")
    void postUsernameAvailability_unauthenticated_shouldReturn401() throws Exception {
        mockMvc.perform(post("/api/v1/auth/usernames/huygiang/availability"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/complete-profile should be permitted without authentication (not 401)")
    void postCompleteProfile_shouldBePublic() throws Exception {
        mockMvc.perform(post("/api/v1/auth/complete-profile")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    @Test
    @DisplayName("GET /api/v1/auth/complete-profile without authentication should return exactly 401 Unauthorized")
    void getCompleteProfile_unauthenticated_shouldReturn401() throws Exception {
        mockMvc.perform(get("/api/v1/auth/complete-profile"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    @DisplayName("POST /api/v1/auth/login should be permitted without authentication (not 401)")
    void postLogin_shouldBePublic() throws Exception {
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    @Test
    @DisplayName("GET /api/v1/auth/login without authentication should return exactly 401 Unauthorized")
    void getLogin_unauthenticated_shouldReturn401() throws Exception {
        mockMvc.perform(get("/api/v1/auth/login"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }
}
