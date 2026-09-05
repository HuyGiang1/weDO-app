package com.wedo.backend.security;

import com.wedo.backend.common.error.ApiErrorResponse;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.common.filter.RequestIdFilter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.MDC;
import org.springframework.http.MediaType;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import tools.jackson.databind.ObjectMapper;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

@Component
public class RestAuthenticationEntryPoint implements AuthenticationEntryPoint {

    private final ObjectMapper objectMapper;

    public RestAuthenticationEntryPoint(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @Override
    public void commence(
            HttpServletRequest request,
            HttpServletResponse response,
            AuthenticationException authException
    ) throws IOException {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());

        String requestId = MDC.get(RequestIdFilter.MDC_REQUEST_ID_KEY);
        if (!StringUtils.hasText(requestId)) {
            requestId = response.getHeader(RequestIdFilter.REQUEST_ID_HEADER);
        }

        ApiErrorResponse errorResponse = ApiErrorResponse.of(
                ErrorCode.UNAUTHORIZED,
                ErrorCode.UNAUTHORIZED.defaultMessage(),
                request.getRequestURI(),
                requestId
        );

        objectMapper.writeValue(response.getOutputStream(), errorResponse);
    }
}
