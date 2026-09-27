package com.wedo.backend.discussion.dto;
import java.util.List;
public record ActivityDiscussionResponse(DiscussionPermissions permissions,List<CommentResponse> comments){ }
