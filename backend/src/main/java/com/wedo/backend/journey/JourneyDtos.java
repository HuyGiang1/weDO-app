package com.wedo.backend.journey;
import jakarta.validation.constraints.*;
import java.time.Instant;
import java.math.BigDecimal;
import java.util.*;
import com.wedo.backend.moment.MomentDtos;
public final class JourneyDtos {
 public enum Status { PLANNED, IN_PROGRESS, COMPLETED, SKIPPED, CANCELLED }
 public record Save(@NotNull UUID clientRequestId,@NotBlank @Size(max=255) String title,@NotNull @Size(max=5000) String notes,@NotNull Instant startsAt,Instant endsAt,@NotNull @Size(max=160) String locationLabel,UUID organizerId,@DecimalMin("0.00") @Digits(integer=17,fraction=2) BigDecimal estimatedCost,Instant expectedUpdatedAt) {}
 public record State(@NotNull Status status,@NotNull Instant expectedUpdatedAt) {}
 public record Reorder(@NotNull @Size(max=200) List<@NotNull UUID> expectedOrder,@NotNull @Size(max=200) List<@NotNull UUID> orderedIds) {}
 public record Stop(UUID id,UUID activityId,String title,String notes,Instant startsAt,Instant endsAt,String locationLabel,UUID organizerId,String organizerName,BigDecimal estimatedCost,int sortOrder,Status status,Instant updatedAt,long checkInCount,boolean canManage,boolean canChangeStatus,boolean canCheckIn) {}
 public record Journey(UUID activityId,UUID groupId,String title,boolean canManage,List<Stop> stops) {}
 public record CheckIn(@NotNull UUID clientRequestId,@NotNull @Size(max=5000) String caption,@NotEmpty @Size(max=8) List<@NotBlank String> mediaKeys,Instant clientCapturedAt) {}
 public record CheckInView(UUID stopId,String source,Instant clientCapturedAt,Instant receivedAt,MomentDtos.Moment moment) {}
}
