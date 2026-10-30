package com.wedo.backend.community;
import jakarta.validation.constraints.*;
import java.time.Instant;
import java.util.*;
public final class RecruitmentDtos {
 public record Create(@NotNull UUID clientRequestId,@NotNull UUID groupId,UUID activityId,
   @NotBlank @Size(max=5000) String caption,@NotNull CommunityDtos.Visibility visibility,
   @Min(1) @Max(100) int requestedCount,@NotNull @Size(max=160) String broadLocation,
   @NotNull @Size(max=6) List<@NotBlank @Size(max=32) String> tags,Instant plannedAt,Instant expiresAt,
   @NotNull @Size(max=8) List<@NotBlank String> mediaKeys) {}
 public record View(UUID groupId,String groupName,UUID activityId,String activityTitle,Instant activityStart,
   int requestedCount,long approvedCount,int remainingSlots,String broadLocation,List<String> tags,
   Instant plannedAt,Instant expiresAt,String status,String requestState,UUID requestId,
   boolean canRequest,boolean canCancel,boolean canManage) {}
 public record Option(UUID groupId,String groupName) {}
 public record Filter(String keyword,String tag,String location,Instant from,Instant to,UUID before) {}
}
