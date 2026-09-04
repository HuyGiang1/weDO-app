package com.wedo.backend.common.error;

import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.LinkedHashMap;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);
    private static final String REQUEST_ID_KEY = "requestId";

    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ApiErrorResponse> handleBusinessException(
            BusinessException exception,
            HttpServletRequest request
    ) {
        ErrorCode errorCode = exception.errorCode();
        String requestId = MDC.get(REQUEST_ID_KEY);
        ApiErrorResponse response = ApiErrorResponse.of(errorCode, exception.getMessage(), request.getRequestURI(), requestId);

        return ResponseEntity.status(errorCode.status()).body(response);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiErrorResponse> handleValidationException(
            MethodArgumentNotValidException exception,
            HttpServletRequest request
    ) {
        Map<String, String> errors = new LinkedHashMap<>();
        exception.getBindingResult().getFieldErrors().forEach(error ->
                errors.putIfAbsent(error.getField(), error.getDefaultMessage())
        );

        ErrorCode errorCode = ErrorCode.VALIDATION_FAILED;
        String requestId = MDC.get(REQUEST_ID_KEY);
        ApiErrorResponse response = ApiErrorResponse.validation(errorCode, request.getRequestURI(), errors, requestId);

        return ResponseEntity.status(errorCode.status()).body(response);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiErrorResponse> handleUnexpectedException(
            Exception exception,
            HttpServletRequest request
    ) {
        log.error("Unexpected request failure", exception);

        ErrorCode errorCode = ErrorCode.INTERNAL_SERVER_ERROR;
        String requestId = MDC.get(REQUEST_ID_KEY);
        ApiErrorResponse response = ApiErrorResponse.of(
                errorCode,
                errorCode.defaultMessage(),
                request.getRequestURI(),
                requestId
        );

        return ResponseEntity.status(errorCode.status()).body(response);
    }
}
