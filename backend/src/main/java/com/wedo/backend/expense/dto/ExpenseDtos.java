package com.wedo.backend.expense.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public final class ExpenseDtos {
    private ExpenseDtos() { }

    public record ShareRequest(@NotNull UUID userId, @NotNull BigDecimal amount) { }

    public record ExpenseRequest(
            @NotBlank @Size(max = 255) String title,
            @NotNull BigDecimal amount,
            @NotNull UUID payerUserId,
            @NotBlank String splitMethod,
            List<UUID> participantUserIds,
            @Valid List<ShareRequest> shares,
            UUID activityId,
            @NotNull OffsetDateTime occurredAt,
            String note
    ) { }

    public record UserSummary(UUID id, String displayName, String avatarStorageKey) { }
    public record PermissionProjection(boolean canEdit, boolean canCancel) { }
    public record Share(UUID userId, String displayName, String avatarStorageKey,
                        @JsonFormat(shape = JsonFormat.Shape.STRING) BigDecimal amount) { }
    public record Change(UUID actorId, String fieldName, String oldValue, String newValue, Instant createdAt) { }
    public record ExpenseSummary(
            UUID id, UUID groupId, String title,
            @JsonFormat(shape = JsonFormat.Shape.STRING) BigDecimal amount, String splitMethod,
            String status, OffsetDateTime occurredAt, UserSummary payer, UserSummary creator,
            int participantCount, PermissionProjection permissions
    ) { }
    public record ExpenseDetail(
            UUID id, UUID groupId, UUID activityId, String title,
            @JsonFormat(shape = JsonFormat.Shape.STRING) BigDecimal amount,
            String splitMethod, String status, OffsetDateTime occurredAt, String note,
            UserSummary payer, UserSummary creator, List<Share> shares, List<Change> changeHistory,
            Instant createdAt, Instant updatedAt, PermissionProjection permissions
    ) { }
    public record UserBalance(UserSummary user, String direction,
                              @JsonFormat(shape = JsonFormat.Shape.STRING) BigDecimal amount) { }
    public record MyBalances(@JsonFormat(shape = JsonFormat.Shape.STRING) BigDecimal totalOwedByMe,
                             @JsonFormat(shape = JsonFormat.Shape.STRING) BigDecimal totalOwedToMe,
                             List<UserBalance> balances) { }
    public record BalanceExpense(UUID expenseId, String title,
                                 @JsonFormat(shape = JsonFormat.Shape.STRING) BigDecimal amount,
                                 OffsetDateTime occurredAt) { }
    public record BalanceSettlement(UUID settlementId,
                                    @JsonFormat(shape = JsonFormat.Shape.STRING) BigDecimal amount,
                                    String status, Instant createdAt) { }
    public record PairBalance(
            UUID groupId, UUID otherUserId,
            @JsonFormat(shape = JsonFormat.Shape.STRING) BigDecimal netAmount, String direction,
            List<BalanceExpense> expenses, List<BalanceSettlement> settlements,
            List<BalanceSettlement> pendingSettlements
    ) { }
}
