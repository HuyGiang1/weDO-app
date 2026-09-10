package com.wedo.backend.auth.exception;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;

public class LoginAttemptException extends BusinessException {

    public LoginAttemptException(ErrorCode errorCode) {
        super(errorCode);
    }

    public LoginAttemptException(ErrorCode errorCode, String message) {
        super(errorCode, message);
    }
}
