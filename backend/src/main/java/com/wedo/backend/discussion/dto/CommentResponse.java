package com.wedo.backend.discussion.dto;

import com.wedo.backend.user.dto.UserPublicProfileResponse;

import java.time.Instant;
import java.util.UUID;

public record CommentResponse(
        UUID id,
        UUID activityId,
        UUID authorId,
        UserPublicProfileResponse author,
        UUID parentCommentId,
        String content,
        boolean edited,
        Instant editedAt,
        boolean deleted,
        Instant deletedAt,
        UUID deletedBy,
        Instant createdAt,
        CommentPermissions permissions
) { }
