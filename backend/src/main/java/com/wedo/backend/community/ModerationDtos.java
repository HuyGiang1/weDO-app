package com.wedo.backend.community;

import jakarta.validation.constraints.*;
import java.time.Instant;
import java.util.*;

public final class ModerationDtos {
    public enum Target { POST, COMMENT, USER }
    public enum Action { DISMISS, RESOLVE, REMOVE, RESTORE }
    public record Submit(@NotNull CommunityDtos.ReportReason reason) {}
    public record Command(@NotNull UUID clientRequestId,@NotNull Action action,
                          @NotBlank @Size(max=1000) String reason) {}
    public record Access(boolean globalModerator,boolean canReview) {}
    public record Item(UUID id,Target targetType,UUID targetId,UUID postId,String reason,
                       String status,Instant createdAt,String evidence,String contentStatus,
                       List<Action> allowedActions) {}
    public record Audit(UUID id,UUID moderatorId,Action action,String reason,String beforeStatus,
                        String afterStatus,Instant createdAt) {}
    public record Detail(Item report,List<Audit> history,List<com.wedo.backend.moment.MomentDtos.Media> media) {}
    public record Hidden(UUID id,String caption) {}
}
