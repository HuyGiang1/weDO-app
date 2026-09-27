package com.wedo.backend.discussion.dto; import jakarta.validation.constraints.*; public record CreateCommentRequest(@NotBlank @Size(max=10000) String content) { }
