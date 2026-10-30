package com.wedo.backend.journey;
import jakarta.validation.constraints.*;
import java.time.Instant;
import java.util.*;
import com.wedo.backend.moment.MomentDtos;
import com.wedo.backend.task.dto.TaskResponse;
public final class ActionDtos {
 public enum Mode { NONE,DIRECT_COMPLETE,REQUIRE_REVIEW }
 public enum Source { CAMERA_CLIENT_DECLARED,GALLERY_UPLOAD }
 public record Configure(@NotNull Mode mode,UUID stopId) {}
 public record Submit(@NotNull UUID clientRequestId,@NotNull Source source,@NotNull @Size(max=2000) String caption,@NotEmpty @Size(max=4) List<@NotBlank String> mediaKeys) {}
 public record Review(@NotNull UUID clientRequestId,boolean approve,@NotNull @Size(max=1000) String reason) {}
 public record Evidence(UUID id,MomentDtos.Author author,Source source,String caption,String status,Instant receivedAt,boolean current,boolean canReview,List<MomentDtos.Media> media,String reviewerName,String feedback) {}
 public record Execution(TaskResponse task,Mode mode,UUID stopId,boolean canConfigure,boolean canSubmit,List<Evidence> evidence,UUID nextBefore) {}
 public enum Target { TASK,STOP }
 public record Convert(@NotNull UUID clientRequestId,@NotNull UUID optionId,@NotNull UUID activityId,@NotNull Target target,@NotNull @Size(max=5000) String notes,Instant startsAt,Instant endsAt,@NotNull @Size(max=160) String locationLabel,Instant dueAt,@NotNull @Size(max=100) List<@NotNull UUID> assigneeUserIds,@Size(max=255) String taskTitle,@Size(max=255) String stopTitle) {
  public Convert(UUID clientRequestId,UUID optionId,UUID activityId,Target target,String notes,Instant startsAt,Instant endsAt,String locationLabel,Instant dueAt,List<UUID> assigneeUserIds){this(clientRequestId,optionId,activityId,target,notes,startsAt,endsAt,locationLabel,dueAt,assigneeUserIds,null,null);}
  public Convert(UUID clientRequestId,UUID optionId,UUID activityId,Target target,String notes,Instant startsAt,Instant endsAt,String locationLabel,Instant dueAt,List<UUID> assigneeUserIds,String taskTitle){this(clientRequestId,optionId,activityId,target,notes,startsAt,endsAt,locationLabel,dueAt,assigneeUserIds,taskTitle,null);}
 }
 public record Link(UUID id,UUID pollId,UUID optionId,String sourceQuestion,String sourceOption,UUID activityId,Target target,UUID taskId,UUID stopId) {}
 public record ConversionContext(UUID groupId,UUID activityId,boolean canCreateStop,List<Link> links) {}
}
