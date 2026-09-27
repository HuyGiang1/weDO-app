package com.wedo.backend.discussion.dto;
public record CommentPermissions(boolean canComment,boolean canReply,boolean canEdit,boolean canDelete,boolean canModerate,boolean readOnly){ }
