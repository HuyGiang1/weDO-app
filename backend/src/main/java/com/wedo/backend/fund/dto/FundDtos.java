package com.wedo.backend.fund.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public final class FundDtos {
    private FundDtos() {
    }

    public record FundUserSummary(
            UUID userId,
            String displayName,
            String username,
            String avatarUrl,
            String role,
            boolean activeMember
    ) {
    }

    public record FundPermissionProjection(
            boolean isOwner,
            boolean isFundManager,
            boolean canManageFund,
            boolean canManageManagers,
            boolean canCloseFund,
            boolean canCreateCollection,
            boolean canRecordExpense,
            boolean canRequestReimbursement,
            boolean canSubmitContribution
    ) {
    }

    public record CreateFundRequest(
            @Size(max = 160) String name
    ) {
    }

    public record AssignFundManagerRequest(
            @NotNull UUID userId
    ) {
    }

    public record FundManagerResponse(
            UUID id,
            UUID fundId,
            FundUserSummary user,
            FundUserSummary assignedBy,
            OffsetDateTime assignedAt
    ) {
    }

    public record FundDetailResponse(
            UUID fundId,
            UUID groupId,
            String name,
            String status,
            String currency,
            BigDecimal ledgerBalance,
            BigDecimal pendingReimbursements,
            BigDecimal availableBalance,
            BigDecimal totalInflow,
            BigDecimal totalOutflow,
            int openCollectionsCount,
            int pendingContributionsCount,
            int pendingReimbursementsCount,
            List<FundManagerResponse> managers,
            FundPermissionProjection permissions,
            FundUserSummary createdBy,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt,
            OffsetDateTime closedAt,
            FundUserSummary closedBy
    ) {
    }

    public record ObligationInput(
            @NotNull UUID userId,
            @NotNull @DecimalMin("0.01") BigDecimal amountDue
    ) {
    }

    public record CreateCollectionRequest(
            @NotBlank @Size(max = 160) String title,
            @Size(max = 1000) String description,
            OffsetDateTime deadlineAt,
            String allocationMode,
            @DecimalMin("0.01") BigDecimal amountPerMember,
            List<UUID> targetUserIds,
            @Valid List<ObligationInput> obligations
    ) {
    }

    public record CollectionObligationResponse(
            UUID obligationId,
            UUID collectionId,
            FundUserSummary user,
            BigDecimal amountDue,
            BigDecimal confirmedAmount,
            BigDecimal pendingAmount,
            BigDecimal remainingAmount,
            String status,
            OffsetDateTime createdAt
    ) {
    }

    public record ContributionResponse(
            UUID contributionId,
            UUID fundId,
            UUID collectionId,
            String collectionTitle,
            FundUserSummary user,
            BigDecimal amount,
            String status,
            String proofStorageKey,
            String note,
            OffsetDateTime paymentTime,
            FundUserSummary confirmedBy,
            OffsetDateTime confirmedAt,
            String rejectionReason,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt,
            boolean canConfirm,
            boolean canReject,
            boolean canCancel
    ) {
    }

    public record CollectionSummaryResponse(
            UUID collectionId,
            UUID fundId,
            String title,
            String description,
            OffsetDateTime deadlineAt,
            String status,
            BigDecimal totalExpectedAmount,
            BigDecimal totalConfirmedAmount,
            BigDecimal totalPendingAmount,
            BigDecimal totalRemainingAmount,
            int totalMembersCount,
            int paidMembersCount,
            int pendingContributionsCount,
            BigDecimal myAmountDue,
            BigDecimal myConfirmedAmount,
            BigDecimal myPendingAmount,
            BigDecimal myRemainingAmount,
            String myObligationStatus,
            FundUserSummary createdBy,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt
    ) {
    }

    public record CollectionDetailResponse(
            UUID collectionId,
            UUID fundId,
            String title,
            String description,
            OffsetDateTime deadlineAt,
            String status,
            BigDecimal totalExpectedAmount,
            BigDecimal totalConfirmedAmount,
            BigDecimal totalPendingAmount,
            BigDecimal totalRemainingAmount,
            int totalMembersCount,
            int paidMembersCount,
            int pendingContributionsCount,
            List<CollectionObligationResponse> obligations,
            List<ContributionResponse> contributions,
            FundUserSummary createdBy,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt,
            boolean canManageCollection,
            boolean canContribute
    ) {
    }

    public record CreateContributionRequest(
            UUID userId,
            @NotNull @DecimalMin("0.01") BigDecimal amount,
            @Size(max = 255) String proofStorageKey,
            @Size(max = 500) String note,
            OffsetDateTime paymentTime
    ) {
    }

    public record RejectRequest(
            @Size(max = 500) String reason
    ) {
    }

    public record CreateFundExpenseRequest(
            @NotBlank @Size(max = 160) String title,
            @NotNull @DecimalMin("0.01") BigDecimal amount,
            OffsetDateTime occurredAt,
            UUID activityId,
            @Size(max = 255) String receiptStorageKey,
            @Size(max = 1000) String note
    ) {
    }

    public record FundExpenseResponse(
            UUID expenseId,
            UUID fundId,
            UUID activityId,
            String activityTitle,
            String title,
            BigDecimal amount,
            OffsetDateTime occurredAt,
            String receiptStorageKey,
            String note,
            UUID transactionId,
            boolean reversed,
            FundUserSummary createdBy,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt
    ) {
    }

    public record CreateReimbursementRequest(
            @NotNull @DecimalMin("0.01") BigDecimal amount,
            @NotBlank @Size(max = 500) String reason,
            @Size(max = 255) String receiptStorageKey
    ) {
    }

    public record ReimbursementResponse(
            UUID reimbursementId,
            UUID fundId,
            FundUserSummary user,
            BigDecimal amount,
            String reason,
            String receiptStorageKey,
            String status,
            FundUserSummary resolvedBy,
            OffsetDateTime resolvedAt,
            String rejectionReason,
            UUID transactionId,
            boolean reversed,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt,
            boolean canApprove,
            boolean canReject,
            boolean canCancel
    ) {
    }

    public record ReverseTransactionRequest(
            @NotBlank @Size(max = 500) String reason
    ) {
    }

    public record FundTransactionResponse(
            UUID transactionId,
            UUID fundId,
            String transactionType,
            String direction,
            BigDecimal amount,
            String referenceType,
            UUID referenceId,
            String referenceTitle,
            String note,
            FundUserSummary createdBy,
            OffsetDateTime createdAt,
            boolean reversed,
            UUID reversalTransactionId,
            String reversalReason,
            FundUserSummary reversedBy,
            OffsetDateTime reversedAt,
            UUID originalTransactionId,
            boolean canReverse
    ) {
    }

    public record FundOverviewResponse(
            FundDetailResponse fund,
            List<CollectionSummaryResponse> openCollections,
            List<FundTransactionResponse> recentTransactions,
            List<ReimbursementResponse> pendingReimbursements,
            List<FundExpenseResponse> recentExpenses
    ) {
    }
}
