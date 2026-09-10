package com.wedo.backend.auth.exception;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;

public class RefreshSessionStatusException extends BusinessException {

    public RefreshSessionStatusException(ErrorCode errorCode) {
        super(errorCode);
    }
}
