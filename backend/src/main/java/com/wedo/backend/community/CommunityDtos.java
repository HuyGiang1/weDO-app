package com.wedo.backend.community;

import jakarta.validation.constraints.*;
import java.time.Instant;
import java.util.*;
import com.wedo.backend.moment.MomentDtos.Author;
import com.wedo.backend.moment.MomentDtos.Media;

public final class CommunityDtos {
    public enum Visibility { PUBLIC, FRIENDS_OF_FRIENDS, FRIENDS, GROUP_ONLY }
    public enum Feed { FOR_YOU, FRIENDS, PROFILE }
    public enum ReportReason { SPAM, HARASSMENT, INAPPROPRIATE, INAPPROPRIATE_CONTENT, SCAM, OTHER }
    public record Permissions(boolean canEdit,boolean canDelete,boolean canInteract) {}
    public record Post(UUID id,Author author,String postType,String caption,Visibility visibility,UUID groupId,
        Instant createdAt,Instant updatedAt,List<Media> media,long reactionCount,String myReaction,
        long commentCount,String moderationStatus,Permissions permissions,RecruitmentDtos.View recruitment) {}
    public record Comment(UUID id,Author author,String content,Instant createdAt,boolean canDelete) {}
    public record Page<T>(List<T> items,UUID nextBefore,boolean hasMore) {}
    public record Refresh(@NotNull Feed feed,UUID authorId,@NotNull @Size(max=100) List<@NotNull UUID> ids) {}
    public record Create(@NotNull UUID clientRequestId,@NotNull @Size(max=5000) String caption,
        @NotNull Visibility visibility,UUID groupId,@NotNull @Size(max=8) List<@NotBlank String> mediaKeys) {}
    public record Edit(@NotNull @Size(max=5000) String caption,@NotNull Visibility visibility,UUID groupId) {}
    public record Reaction(String emoji) {}
    public record AddComment(@NotNull UUID clientRequestId,@NotBlank @Size(max=2000) String content) {}
    public record Report(@NotNull ReportReason reason) {}
}
