package com.wedo.backend.security;

import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
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
    @DisplayName("GET non-existent protected route without authentication should return exactly 403 Forbidden with no redirect or Basic challenge")
    void getUnauthenticatedProtected_shouldReturn403ForbiddenWithoutRedirectOrBasicAuth() throws Exception {
        mockMvc.perform(get("/api/v1/non-existent-protected"))
                .andExpect(status().isForbidden())
                .andExpect(header().doesNotExist("Location"))
                .andExpect(header().doesNotExist("WWW-Authenticate"))
                .andExpect(header().doesNotExist("Set-Cookie"));
    }
}
