package com.wedo.backend.common.filter;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import jakarta.servlet.ServletException;
import java.io.IOException;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.slf4j.MDC;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

class RequestIdFilterTest {

    private RequestIdFilter filter;

    @BeforeEach
    void setUp() {
        filter = new RequestIdFilter();
        MDC.clear();
    }

    @Test
    @DisplayName("Should preserve existing X-Request-Id header from client and populate MDC")
    void shouldPreserveExistingRequestIdFromClient() throws ServletException, IOException {
        MockHttpServletRequest request = new MockHttpServletRequest();
        String clientRequestId = "client-req-12345";
        request.addHeader(RequestIdFilter.REQUEST_ID_HEADER, clientRequestId);

        MockHttpServletResponse response = new MockHttpServletResponse();
        AtomicReference<String> mdcValueDuringExecution = new AtomicReference<>();

        MockFilterChain filterChain = new MockFilterChain() {
            @Override
            public void doFilter(jakarta.servlet.ServletRequest req, jakarta.servlet.ServletResponse res) {
                mdcValueDuringExecution.set(MDC.get(RequestIdFilter.MDC_REQUEST_ID_KEY));
            }
        };

        filter.doFilter(request, response, filterChain);

        assertThat(mdcValueDuringExecution.get()).isEqualTo(clientRequestId);
        assertThat(response.getHeader(RequestIdFilter.REQUEST_ID_HEADER)).isEqualTo(clientRequestId);
        assertThat(MDC.get(RequestIdFilter.MDC_REQUEST_ID_KEY)).isNull();
    }

    @Test
    @DisplayName("Should generate UUID X-Request-Id when client header is missing and populate MDC")
    void shouldGenerateNewRequestIdWhenHeaderMissing() throws ServletException, IOException {
        MockHttpServletRequest request = new MockHttpServletRequest();
        MockHttpServletResponse response = new MockHttpServletResponse();
        AtomicReference<String> mdcValueDuringExecution = new AtomicReference<>();

        MockFilterChain filterChain = new MockFilterChain() {
            @Override
            public void doFilter(jakarta.servlet.ServletRequest req, jakarta.servlet.ServletResponse res) {
                mdcValueDuringExecution.set(MDC.get(RequestIdFilter.MDC_REQUEST_ID_KEY));
            }
        };

        filter.doFilter(request, response, filterChain);

        String generatedHeader = response.getHeader(RequestIdFilter.REQUEST_ID_HEADER);
        assertThat(generatedHeader).isNotBlank();
        assertThat(mdcValueDuringExecution.get()).isEqualTo(generatedHeader);
        assertThat(MDC.get(RequestIdFilter.MDC_REQUEST_ID_KEY)).isNull();
    }

    @Test
    @DisplayName("Should clear MDC even when filter chain throws an exception")
    void shouldClearMdcEvenWhenExceptionOccurs() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        MockHttpServletResponse response = new MockHttpServletResponse();

        MockFilterChain failingChain = new MockFilterChain() {
            @Override
            public void doFilter(jakarta.servlet.ServletRequest req, jakarta.servlet.ServletResponse res)
                    throws ServletException {
                assertThat(MDC.get(RequestIdFilter.MDC_REQUEST_ID_KEY)).isNotNull();
                throw new ServletException("Simulated error in downstream filter");
            }
        };

        assertThatThrownBy(() -> filter.doFilter(request, response, failingChain))
                .isInstanceOf(ServletException.class)
                .hasMessageContaining("Simulated error");

        assertThat(MDC.get(RequestIdFilter.MDC_REQUEST_ID_KEY)).isNull();
    }
}
