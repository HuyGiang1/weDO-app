package com.wedo.backend.auth.exception;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;

public class PasswordResetAttemptException extends BusinessException {

    public PasswordResetAttemptException(ErrorCode errorCode) {
        super(errorCode);
    }

    public PasswordResetAttemptException(ErrorCode errorCode, String message) {
        super(errorCode, message);
    }
}
