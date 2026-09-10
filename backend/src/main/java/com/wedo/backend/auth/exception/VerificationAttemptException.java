package com.wedo.backend.auth.exception;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;

public class VerificationAttemptException extends BusinessException {

    public VerificationAttemptException(ErrorCode errorCode) {
        super(errorCode);
    }

    public VerificationAttemptException(ErrorCode errorCode, String message) {
        super(errorCode, message);
    }
}
