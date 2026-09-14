package com.wedo.backend.common.error;

import org.springframework.http.HttpStatus;

public enum ErrorCode {
    VALIDATION_FAILED(HttpStatus.BAD_REQUEST, "Request validation failed."),
    UNAUTHORIZED(HttpStatus.UNAUTHORIZED, "Authentication is required."),
    ACCESS_DENIED(HttpStatus.FORBIDDEN, "Access is denied."),
    RESOURCE_NOT_FOUND(HttpStatus.NOT_FOUND, "Resource was not found."),
    CONFLICT(HttpStatus.CONFLICT, "Request conflicts with the current state."),
    EMAIL_ALREADY_EXISTS(HttpStatus.CONFLICT, "An account with this email already exists."),
    VERIFICATION_CODE_INVALID(HttpStatus.BAD_REQUEST, "Invalid verification code."),
    VERIFICATION_CODE_EXPIRED(HttpStatus.BAD_REQUEST, "Verification code has expired."),
    VERIFICATION_ATTEMPTS_EXCEEDED(HttpStatus.TOO_MANY_REQUESTS, "Maximum verification attempts exceeded."),
    EMAIL_ALREADY_VERIFIED(HttpStatus.CONFLICT, "Email is already verified."),
    RESEND_COOLDOWN_ACTIVE(HttpStatus.TOO_MANY_REQUESTS, "Please wait before requesting another verification code."),
    PROFILE_ALREADY_COMPLETED(HttpStatus.CONFLICT, "Profile has already been completed."),
    USERNAME_ALREADY_EXISTS(HttpStatus.CONFLICT, "Username is already taken."),
    AUTH_INVALID_CREDENTIALS(HttpStatus.UNAUTHORIZED, "Invalid email or password."),
    EMAIL_NOT_VERIFIED(HttpStatus.FORBIDDEN, "Email address has not been verified."),
    ACCOUNT_SUSPENDED(HttpStatus.FORBIDDEN, "Account has been suspended."),
    ACCOUNT_DEACTIVATED(HttpStatus.FORBIDDEN, "Account has been deactivated."),
    ACCOUNT_LOCKED(HttpStatus.LOCKED, "Account is temporarily locked."),
    REFRESH_TOKEN_INVALID(HttpStatus.UNAUTHORIZED, "Invalid refresh token."),
    AUTH_TOKEN_EXPIRED(HttpStatus.UNAUTHORIZED, "Authentication token has expired."),
    AUTH_TOKEN_INVALID(HttpStatus.UNAUTHORIZED, "Invalid authentication token."),
    PASSWORD_RESET_CODE_INVALID(HttpStatus.BAD_REQUEST, "Invalid password reset code."),
    CANNOT_FRIEND_SELF(HttpStatus.BAD_REQUEST, "Cannot send friend request to yourself."),
    USER_BLOCKED(HttpStatus.FORBIDDEN, "User is blocked."),
    ALREADY_FRIENDS(HttpStatus.CONFLICT, "Users are already friends."),
    FRIEND_REQUEST_ALREADY_PENDING(HttpStatus.CONFLICT, "A friend request is already pending."),
    FRIEND_REQUEST_COOLDOWN_ACTIVE(HttpStatus.TOO_MANY_REQUESTS, "Please wait before sending another friend request."),
    FRIEND_REQUEST_NOT_ALLOWED(HttpStatus.FORBIDDEN, "User privacy settings do not allow friend requests."),
    FRIEND_REQUEST_NOT_FOUND(HttpStatus.NOT_FOUND, "Friend request was not found."),
    FRIENDSHIP_NOT_FOUND(HttpStatus.NOT_FOUND, "Friendship was not found."),
    CANNOT_BLOCK_SELF(HttpStatus.BAD_REQUEST, "Cannot block yourself."),
    GROUP_NOT_FOUND(HttpStatus.NOT_FOUND, "Group was not found."),
    GROUP_MEMBER_NOT_FOUND(HttpStatus.NOT_FOUND, "Group member was not found."),
    INTERNAL_SERVER_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, "An unexpected error occurred.");

    private final HttpStatus status;
    private final String defaultMessage;

    ErrorCode(HttpStatus status, String defaultMessage) {
        this.status = status;
        this.defaultMessage = defaultMessage;
    }

    public HttpStatus status() {
        return status;
    }

    public String defaultMessage() {
        return defaultMessage;
    }
}
