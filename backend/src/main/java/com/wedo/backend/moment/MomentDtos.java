package com.wedo.backend.moment;

import jakarta.validation.constraints.*;
import java.time.Instant;
import java.util.*;

public final class MomentDtos {
 private MomentDtos() {}
 public record Author(UUID id,String displayName,String avatarStorageKey) {}
 public record Media(UUID id,String contentType,String fileName,long fileSize,int sortOrder) {}
 public record Permissions(boolean canEdit,boolean canDelete,boolean canInteract,boolean canManage) {}
 public record Moment(UUID id,UUID groupId,UUID activityId,String activityTitle,Author author,String caption,
   Instant createdAt,Instant updatedAt,List<Media> media,long reactionCount,String myReaction,long commentCount,Permissions permissions) {}
 public record Comment(UUID id,Author author,String content,Instant createdAt,boolean canDelete) {}
 public record Album(UUID id,UUID groupId,UUID activityId,String activityTitle,String name,String description,
   Author author,Instant createdAt,long itemCount,Media cover,Permissions permissions) {}
 public record Page<T>(List<T> items,UUID nextBefore,boolean hasMore,boolean canCreate) {
  public Page(List<T> items,UUID nextBefore,boolean hasMore){this(items,nextBefore,hasMore,false);}
 }
 public record CreateMoment(@NotNull UUID clientRequestId,UUID activityId,@NotNull @Size(max=5000) String caption,
   @NotNull @Size(max=8) List<@NotBlank String> mediaKeys) {}
 public record EditMoment(@NotNull @Size(max=5000) String caption,UUID activityId) {}
 public record React(String emoji) {}
 public record AddComment(@NotNull UUID clientRequestId,@NotBlank @Size(max=2000) String content) {}
 public record SaveAlbum(@NotNull UUID clientRequestId,UUID activityId,@NotBlank @Size(max=160) String name,@Size(max=2000) String description) {}
 public record AddItems(@NotEmpty @Size(max=50) List<@NotNull UUID> mediaIds) {}
}
