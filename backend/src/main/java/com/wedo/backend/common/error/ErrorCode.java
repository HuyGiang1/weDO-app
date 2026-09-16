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
    GROUP_ARCHIVED(HttpStatus.CONFLICT, "Group is archived."),
    INSUFFICIENT_GROUP_PERMISSION(HttpStatus.FORBIDDEN, "Insufficient group permission."),
    TRANSFER_OWNERSHIP_REQUIRED(HttpStatus.CONFLICT, "Ownership transfer is required."),
    INVALID_OWNERSHIP_TARGET(HttpStatus.CONFLICT, "Invalid ownership transfer target."),
    INVALID_GROUP_ROLE_TRANSITION(HttpStatus.CONFLICT, "Invalid group role transition."),
    GROUP_DELETED(HttpStatus.GONE, "Group has been deleted."),
    GROUP_MEMBER_LIMIT_REACHED(HttpStatus.CONFLICT, "The group has reached its maximum capacity."),
    USER_BANNED_FROM_GROUP(HttpStatus.FORBIDDEN, "User is banned from this group."),
    GROUP_INVITATION_NOT_FOUND(HttpStatus.NOT_FOUND, "Group invitation was not found."),
    GROUP_INVITATION_EXPIRED(HttpStatus.BAD_REQUEST, "Group invitation has expired."),
    INVITATION_ALREADY_RESOLVED(HttpStatus.CONFLICT, "Group invitation is already resolved."),
    INVITE_LINK_NOT_FOUND(HttpStatus.NOT_FOUND, "Invite link was not found."),
    INVITE_LINK_EXPIRED(HttpStatus.BAD_REQUEST, "Invite link has expired."),
    INVITE_LINK_REVOKED(HttpStatus.CONFLICT, "Invite link has been revoked."),
    INVITE_LINK_LIMIT_REACHED(HttpStatus.CONFLICT, "Invite link usage limit reached."),
    JOIN_REQUEST_NOT_FOUND(HttpStatus.NOT_FOUND, "Join request was not found."),
    JOIN_REQUEST_ALREADY_PENDING(HttpStatus.CONFLICT, "A join request is already pending."),
    JOIN_REQUEST_ALREADY_RESOLVED(HttpStatus.CONFLICT, "Join request is already resolved."),
    ALREADY_GROUP_MEMBER(HttpStatus.CONFLICT, "User is already an active member of this group."),
    CANNOT_INVITE_SELF(HttpStatus.BAD_REQUEST, "Cannot invite yourself."),
    CANNOT_BAN_SELF(HttpStatus.BAD_REQUEST, "Cannot ban yourself."),
    CANNOT_BAN_OWNER(HttpStatus.FORBIDDEN, "Cannot ban group owner."),
    CANNOT_BAN_ADMIN(HttpStatus.FORBIDDEN, "Admins cannot ban other admins."),
    USER_ALREADY_BANNED(HttpStatus.CONFLICT, "User is already banned from this group."),
    USER_NOT_BANNED(HttpStatus.NOT_FOUND, "User is not banned from this group."),
    ACTIVITY_NOT_FOUND(HttpStatus.NOT_FOUND, "Activity was not found."),
    ACTIVITY_CLOSED(HttpStatus.CONFLICT, "Activity is closed."),
    ACTIVITY_ALREADY_STARTED(HttpStatus.CONFLICT, "Activity has already started."),
    ACTIVITY_ALREADY_COMPLETED(HttpStatus.CONFLICT, "Activity has already completed."),
    INVALID_ACTIVITY_TIME(HttpStatus.BAD_REQUEST, "Activity time or timezone is invalid."),
    ACTIVITY_CAPACITY_INVALID(HttpStatus.BAD_REQUEST, "Activity capacity is invalid."),
    RSVP_LOCKED(HttpStatus.CONFLICT, "RSVP is locked."),
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
