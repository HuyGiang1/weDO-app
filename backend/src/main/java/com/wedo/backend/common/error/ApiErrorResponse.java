package com.wedo.backend.common.error;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.time.Instant;
import java.util.Map;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record ApiErrorResponse(
        Instant timestamp,
        int status,
        String code,
        String message,
        String path,
        Map<String, String> errors
) {

    public ApiErrorResponse {
        errors = errors == null ? Map.of() : Map.copyOf(errors);
    }

    public static ApiErrorResponse of(ErrorCode errorCode, String message, String path) {
        return new ApiErrorResponse(
                Instant.now(),
                errorCode.status().value(),
                errorCode.name(),
                message,
                path,
                Map.of()
        );
    }

    public static ApiErrorResponse validation(ErrorCode errorCode, String path, Map<String, String> errors) {
        return new ApiErrorResponse(
                Instant.now(),
                errorCode.status().value(),
                errorCode.name(),
                errorCode.defaultMessage(),
                path,
                errors
        );
    }
}
