package com.wedo.backend.security;

import com.wedo.backend.common.filter.RequestIdFilter;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.slf4j.MDC;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.access.AccessDeniedException;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.json.JsonMapper;

import static org.assertj.core.api.Assertions.assertThat;

class RestAccessDeniedHandlerTest {

    private RestAccessDeniedHandler handler;
    private ObjectMapper objectMapper;

    @BeforeEach
    void setUp() {
        objectMapper = JsonMapper.builder().build();
        handler = new RestAccessDeniedHandler(objectMapper);
        MDC.clear();
    }

    @Test
    @DisplayName("handle should return 403 Forbidden with ApiErrorResponse JSON body")
    void handle_shouldReturn403WithApiErrorResponse() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/admin-only");
        MockHttpServletResponse response = new MockHttpServletResponse();
        String testRequestId = "req-access-denied-123";
        MDC.put(RequestIdFilter.MDC_REQUEST_ID_KEY, testRequestId);

        AccessDeniedException exception = new AccessDeniedException("Access is denied.");

        handler.handle(request, response, exception);

        assertThat(response.getStatus()).isEqualTo(403);
        assertThat(response.getContentType()).contains("application/json");

        String content = response.getContentAsString();
        assertThat(content).contains("\"status\":403");
        assertThat(content).contains("\"code\":\"ACCESS_DENIED\"");
        assertThat(content).contains("\"message\":\"Access is denied.\"");
        assertThat(content).contains("\"path\":\"/api/v1/admin-only\"");
        assertThat(content).contains("\"requestId\":\"" + testRequestId + "\"");
    }
}
