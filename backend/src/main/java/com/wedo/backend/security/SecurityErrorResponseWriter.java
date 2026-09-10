package com.wedo.backend.security;

import com.wedo.backend.common.error.ApiErrorResponse;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.common.filter.RequestIdFilter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.MDC;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import tools.jackson.databind.ObjectMapper;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

@Component
public class SecurityErrorResponseWriter {

    private final ObjectMapper objectMapper;

    public SecurityErrorResponseWriter(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    public void writeError(
            HttpServletRequest request,
            HttpServletResponse response,
            ErrorCode errorCode
    ) throws IOException {
        writeError(request, response, errorCode, errorCode.defaultMessage());
    }

    public void writeError(
            HttpServletRequest request,
            HttpServletResponse response,
            ErrorCode errorCode,
            String customMessage
    ) throws IOException {
        response.setStatus(errorCode.status().value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());

        String requestId = MDC.get(RequestIdFilter.MDC_REQUEST_ID_KEY);
        if (!StringUtils.hasText(requestId)) {
            requestId = response.getHeader(RequestIdFilter.REQUEST_ID_HEADER);
        }
        if (!StringUtils.hasText(requestId)) {
            requestId = request.getHeader(RequestIdFilter.REQUEST_ID_HEADER);
        }
        if (StringUtils.hasText(requestId)) {
            response.setHeader(RequestIdFilter.REQUEST_ID_HEADER, requestId);
        }

        String message = (customMessage != null && !customMessage.isBlank())
                ? customMessage
                : errorCode.defaultMessage();

        ApiErrorResponse errorResponse = ApiErrorResponse.of(
                errorCode,
                message,
                request.getRequestURI(),
                requestId
        );

        objectMapper.writeValue(response.getOutputStream(), errorResponse);
    }
}
