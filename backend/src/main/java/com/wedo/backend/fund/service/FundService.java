package com.wedo.backend.fund.service;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.fund.dto.FundDtos.AssignFundManagerRequest;
import com.wedo.backend.fund.dto.FundDtos.CollectionDetailResponse;
import com.wedo.backend.fund.dto.FundDtos.CollectionObligationResponse;
import com.wedo.backend.fund.dto.FundDtos.CollectionSummaryResponse;
import com.wedo.backend.fund.dto.FundDtos.ContributionResponse;
import com.wedo.backend.fund.dto.FundDtos.CreateCollectionRequest;
import com.wedo.backend.fund.dto.FundDtos.CreateContributionRequest;
import com.wedo.backend.fund.dto.FundDtos.CreateFundExpenseRequest;
import com.wedo.backend.fund.dto.FundDtos.CreateFundRequest;
import com.wedo.backend.fund.dto.FundDtos.CreateReimbursementRequest;
import com.wedo.backend.fund.dto.FundDtos.FundDetailResponse;
import com.wedo.backend.fund.dto.FundDtos.FundExpenseResponse;
import com.wedo.backend.fund.dto.FundDtos.FundManagerResponse;
import com.wedo.backend.fund.dto.FundDtos.FundOverviewResponse;
import com.wedo.backend.fund.dto.FundDtos.FundPermissionProjection;
import com.wedo.backend.fund.dto.FundDtos.FundTransactionResponse;
import com.wedo.backend.fund.dto.FundDtos.FundUserSummary;
import com.wedo.backend.fund.dto.FundDtos.ObligationInput;
import com.wedo.backend.fund.dto.FundDtos.ReimbursementResponse;
import com.wedo.backend.fund.dto.FundDtos.RejectRequest;
import com.wedo.backend.fund.dto.FundDtos.ReverseTransactionRequest;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.event.GroupMembershipEndedEvent;
import com.wedo.backend.group.service.GroupPermissionService;
import com.wedo.backend.group.service.ReadableGroupAccess;
import com.wedo.backend.media.dto.UploadCategory;
import com.wedo.backend.media.service.MediaReferenceService;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.context.event.EventListener;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class FundService {
    private static final BigDecimal ZERO = new BigDecimal("0.00");
    private static final BigDecimal CENT = new BigDecimal("0.01");
    private static final String DEFAULT_FUND_NAME = "Quỹ nhóm";

    private static final RowMapper<FundRow> FUND_ROW = FundService::mapFundRow;
    private static final RowMapper<CollectionRow> COLLECTION_ROW = FundService::mapCollectionRow;
    private static final RowMapper<ObligationRow> OBLIGATION_ROW = FundService::mapObligationRow;
    private static final RowMapper<ContributionRow> CONTRIBUTION_ROW = FundService::mapContributionRow;
    private static final RowMapper<FundExpenseRow> EXPENSE_ROW = FundService::mapExpenseRow;
    private static final RowMapper<ReimbursementRow> REIMBURSEMENT_ROW = FundService::mapReimbursementRow;
    private static final RowMapper<TransactionRow> TRANSACTION_ROW = FundService::mapTransactionRow;

    private final JdbcTemplate jdbc;
    private final GroupPermissionService groupPermissions;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private MediaReferenceService mediaReferences;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private org.springframework.context.ApplicationEventPublisher eventPublisher;

    public FundService(JdbcTemplate jdbc, GroupPermissionService groupPermissions) {
        this.jdbc = jdbc;
        this.groupPermissions = groupPermissions;
    }

    @EventListener
    @Transactional
    public void onGroupMembershipEnded(GroupMembershipEndedEvent event) {
        jdbc.update("""
                DELETE FROM fund_managers fm
                USING group_funds gf
                WHERE fm.fund_id = gf.id
                  AND gf.group_id = ?
                  AND fm.user_id = ?
                """, event.groupId(), event.userId());
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public FundDetailResponse createFund(UUID groupId, UUID callerUserId, CreateFundRequest request) {
        groupPermissions.requireOwner(groupId, callerUserId);
        List<FundRow> activeFunds = jdbc.query(
                "SELECT * FROM group_funds WHERE group_id = ? AND status = 'ACTIVE' FOR UPDATE",
                FUND_ROW,
                groupId
        );
        if (!activeFunds.isEmpty()) {
            throw new BusinessException(ErrorCode.FUND_ALREADY_EXISTS);
        }

        String fundName = DEFAULT_FUND_NAME;
        if (request != null && request.name() != null && !request.name().trim().isEmpty()) {
            fundName = request.name().trim();
            if (fundName.length() > 160) {
                throw new BusinessException(ErrorCode.VALIDATION_FAILED, "Fund name must be at most 160 characters.");
            }
        }

        UUID fundId = UUID.randomUUID();
        Timestamp now = Timestamp.from(Instant.now());
        try {
            jdbc.update("""
                    INSERT INTO group_funds (
                        id, group_id, name, status, created_by, created_at, updated_at
                    ) VALUES (?, ?, ?, 'ACTIVE', ?, ?, ?)
                    """,
                    fundId, groupId, fundName, callerUserId, now, now
            );
        } catch (DataIntegrityViolationException ex) {
            throw new BusinessException(ErrorCode.FUND_ALREADY_EXISTS);
        }

        return getFundByIdInternal(fundId, callerUserId);
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public FundDetailResponse getGroupFund(UUID groupId, UUID callerUserId) {
        ReadableGroupAccess access = groupPermissions.requireReadableMembership(groupId, callerUserId);
        List<FundRow> funds = jdbc.query("""
                SELECT * FROM group_funds
                WHERE group_id = ?
                ORDER BY CASE WHEN status = 'ACTIVE' THEN 0 ELSE 1 END, created_at DESC
                LIMIT 1
                """,
                FUND_ROW,
                groupId
        );
        if (funds.isEmpty()) {
            throw new BusinessException(ErrorCode.FUND_NOT_FOUND);
        }
        FundRow fund = funds.get(0);
        cleanupStaleManagers(fund.id(), fund.groupId());
        return buildFundDetailResponse(fund, access, callerUserId);
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public FundOverviewResponse getFundOverview(UUID fundId, UUID callerUserId) {
        FundRow fund = requireFundRow(fundId);
        ReadableGroupAccess access = groupPermissions.requireReadableMembership(fund.groupId(), callerUserId);
        cleanupStaleManagers(fund.id(), fund.groupId());

        FundDetailResponse detail = buildFundDetailResponse(fund, access, callerUserId);
        List<CollectionSummaryResponse> openCollections = listCollectionsInternal(fund, access, callerUserId, "OPEN");
        List<FundTransactionResponse> recentTransactions = listTransactionsInternal(fund, access, callerUserId, null, null)
                .stream()
                .limit(10)
                .toList();
        List<ReimbursementResponse> pendingReimbursements = listReimbursementsInternal(fund, access, callerUserId, "PENDING");
        List<FundExpenseResponse> recentExpenses = listExpensesInternal(fund, access, callerUserId)
                .stream()
                .limit(10)
                .toList();

        return new FundOverviewResponse(
                detail,
                openCollections,
                recentTransactions,
                pendingReimbursements,
                recentExpenses
        );
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public FundDetailResponse closeFund(UUID fundId, UUID callerUserId) {
        FundRow fund = lockFundRow(fundId);
        ReadableGroupAccess access = groupPermissions.requireOwner(fund.groupId(), callerUserId);
        if (!"ACTIVE".equals(fund.status())) {
            throw new BusinessException(ErrorCode.FUND_CLOSED);
        }
        cleanupStaleManagers(fund.id(), fund.groupId());

        BalanceSnapshot balances = computeBalanceSnapshot(fund.id(), null);
        int openCollections = countOpenCollections(fund.id());
        int pendingContributions = countPendingContributions(fund.id());
        int pendingReimbursements = countPendingReimbursements(fund.id());

        if (balances.ledgerBalance().compareTo(ZERO) != 0
                || balances.availableBalance().compareTo(ZERO) != 0
                || balances.pendingReimbursements().compareTo(ZERO) != 0
                || openCollections > 0
                || pendingContributions > 0
                || pendingReimbursements > 0) {
            throw new BusinessException(ErrorCode.FUND_CLOSE_PRECONDITION_FAILED);
        }

        Timestamp now = Timestamp.from(Instant.now());
        jdbc.update("""
                UPDATE group_funds
                SET status = 'CLOSED',
                    closed_at = ?,
                    closed_by = ?,
                    updated_at = ?
                WHERE id = ?
                """,
                now, callerUserId, now, fund.id()
        );

        FundRow updated = requireFundRow(fund.id());
        return buildFundDetailResponse(updated, access, callerUserId);
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public List<FundManagerResponse> listManagers(UUID fundId, UUID callerUserId) {
        FundRow fund = requireFundRow(fundId);
        groupPermissions.requireReadableMembership(fund.groupId(), callerUserId);
        cleanupStaleManagers(fund.id(), fund.groupId());
        return loadManagers(fund.id(), fund.groupId());
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public FundManagerResponse assignManager(UUID fundId, UUID callerUserId, AssignFundManagerRequest request) {
        FundRow fund = lockFundRow(fundId);
        groupPermissions.requireOwner(fund.groupId(), callerUserId);
        requireActiveFund(fund);
        cleanupStaleManagers(fund.id(), fund.groupId());

        UUID targetUserId = request.userId();
        List<String> targetRoles = jdbc.query(
                "SELECT role FROM group_memberships WHERE group_id = ? AND user_id = ? AND status = 'ACTIVE'",
                (rs, i) -> rs.getString("role"),
                fund.groupId(),
                targetUserId
        );
        if (targetRoles.isEmpty() || !"ADMIN".equals(targetRoles.get(0))) {
            throw new BusinessException(ErrorCode.FUND_MANAGER_NOT_ELIGIBLE);
        }

        List<UUID> existing = jdbc.query(
                "SELECT id FROM fund_managers WHERE fund_id = ? AND user_id = ?",
                (rs, i) -> rs.getObject("id", UUID.class),
                fund.id(),
                targetUserId
        );
        if (existing.isEmpty()) {
            if (loadManagers(fund.id(), fund.groupId()).size() >= 2) {
                throw new BusinessException(ErrorCode.FUND_MANAGER_NOT_ELIGIBLE, "A group fund can have at most 2 assigned Fund Managers.");
            }
            Timestamp now = Timestamp.from(Instant.now());
            jdbc.update("""
                    INSERT INTO fund_managers (id, fund_id, user_id, assigned_by, assigned_at)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                    UUID.randomUUID(), fund.id(), targetUserId, callerUserId, now
            );
            jdbc.update("UPDATE group_funds SET updated_at = ? WHERE id = ?", now, fund.id());
        }

        return loadManagers(fund.id(), fund.groupId()).stream()
                .filter(m -> m.user().userId().equals(targetUserId))
                .findFirst()
                .orElseThrow(() -> new BusinessException(ErrorCode.FUND_MANAGER_NOT_ELIGIBLE));
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public List<FundManagerResponse> revokeManager(UUID fundId, UUID targetUserId, UUID callerUserId) {
        FundRow fund = lockFundRow(fundId);
        groupPermissions.requireOwner(fund.groupId(), callerUserId);
        requireActiveFund(fund);
        cleanupStaleManagers(fund.id(), fund.groupId());

        Timestamp now = Timestamp.from(Instant.now());
        jdbc.update("DELETE FROM fund_managers WHERE fund_id = ? AND user_id = ?", fund.id(), targetUserId);
        jdbc.update("UPDATE group_funds SET updated_at = ? WHERE id = ?", now, fund.id());
        return loadManagers(fund.id(), fund.groupId());
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public CollectionDetailResponse createCollection(UUID fundId, UUID callerUserId, CreateCollectionRequest request) {
        FundRow fund = lockFundRow(fundId);
        ReadableGroupAccess access = requireFundManagerOrOwner(fund, callerUserId);
        requireActiveFund(fund);

        String title = normalizeRequiredText(request.title(), 160, "Collection title is required.");
        String description = normalizeOptionalText(request.description(), 1000);

        Map<UUID, BigDecimal> obligationsMap = resolveCollectionObligations(fund.groupId(), request);
        if (obligationsMap.isEmpty()) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "At least one member obligation is required.");
        }

        UUID collectionId = UUID.randomUUID();
        Timestamp now = Timestamp.from(Instant.now());
        Timestamp deadlineTs = request.deadlineAt() == null ? null : Timestamp.from(request.deadlineAt().toInstant());

        jdbc.update("""
                INSERT INTO fund_collections (
                    id, fund_id, title, description, deadline_at, status, created_by, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, 'OPEN', ?, ?, ?)
                """,
                collectionId, fund.id(), title, description, deadlineTs, callerUserId, now, now
        );

        for (Map.Entry<UUID, BigDecimal> entry : obligationsMap.entrySet()) {
            jdbc.update("""
                    INSERT INTO fund_collection_obligations (
                        id, collection_id, user_id, amount_due, created_at
                    ) VALUES (?, ?, ?, ?, ?)
                    """,
                    UUID.randomUUID(), collectionId, entry.getKey(), scaleMoney(entry.getValue()), now
            );
        }

        jdbc.update("UPDATE group_funds SET updated_at = ? WHERE id = ?", now, fund.id());
        if (eventPublisher != null) {
            List<UUID> recipients = obligationsMap.keySet().stream()
                    .filter(uid -> !uid.equals(callerUserId))
                    .toList();
            if (!recipients.isEmpty()) {
                eventPublisher.publishEvent(new com.wedo.backend.notification.event.NotificationDomainEvent(
                        "FUND_COLLECTION_CREATED:" + collectionId,
                        "FUND_COLLECTION_CREATED",
                        "FUND",
                        "NORMAL",
                        false,
                        callerUserId,
                        fund.groupId(),
                        recipients,
                        "Đợt thu quỹ mới: " + title,
                        "Nhóm có đợt thu quỹ mới \"" + title + "\".",
                        "FUND",
                        fund.id(),
                        "/groups/fund",
                        Map.of("groupId", fund.groupId().toString(), "fundId", fund.id().toString(), "collectionId", collectionId.toString()),
                        now.toInstant()
                ));
            }
        }
        CollectionRow created = requireCollectionRow(collectionId);
        return buildCollectionDetailResponse(fund, created, access, callerUserId);
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public List<CollectionSummaryResponse> listCollections(UUID fundId, UUID callerUserId, String statusFilter) {
        FundRow fund = requireFundRow(fundId);
        ReadableGroupAccess access = groupPermissions.requireReadableMembership(fund.groupId(), callerUserId);
        cleanupStaleManagers(fund.id(), fund.groupId());
        return listCollectionsInternal(fund, access, callerUserId, statusFilter);
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public CollectionDetailResponse getCollectionDetail(UUID collectionId, UUID callerUserId) {
        CollectionRow collection = requireCollectionRow(collectionId);
        FundRow fund = requireFundRow(collection.fundId());
        ReadableGroupAccess access = groupPermissions.requireReadableMembership(fund.groupId(), callerUserId);
        cleanupStaleManagers(fund.id(), fund.groupId());
        return buildCollectionDetailResponse(fund, collection, access, callerUserId);
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public CollectionDetailResponse closeCollection(UUID collectionId, UUID callerUserId) {
        FundRow fund = lockFundRow(requireCollectionRow(collectionId).fundId());
        CollectionRow collection = lockCollectionRow(collectionId);
        ReadableGroupAccess access = requireFundManagerOrOwner(fund, callerUserId);
        requireActiveFund(fund);

        if (!"OPEN".equals(collection.status())) {
            throw new BusinessException(ErrorCode.FUND_COLLECTION_NOT_OPEN);
        }

        Timestamp now = Timestamp.from(Instant.now());
        jdbc.update("""
                UPDATE fund_collections
                SET status = 'CLOSED', updated_at = ?
                WHERE id = ?
                """,
                now, collection.id()
        );
        jdbc.update("UPDATE group_funds SET updated_at = ? WHERE id = ?", now, fund.id());

        return buildCollectionDetailResponse(fund, requireCollectionRow(collectionId), access, callerUserId);
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public CollectionDetailResponse cancelCollection(UUID collectionId, UUID callerUserId) {
        FundRow fund = lockFundRow(requireCollectionRow(collectionId).fundId());
        CollectionRow collection = lockCollectionRow(collectionId);
        ReadableGroupAccess access = requireFundManagerOrOwner(fund, callerUserId);
        requireActiveFund(fund);

        if (!"OPEN".equals(collection.status())) {
            throw new BusinessException(ErrorCode.FUND_COLLECTION_NOT_OPEN);
        }

        Timestamp now = Timestamp.from(Instant.now());
        jdbc.update("""
                UPDATE fund_contributions
                SET status = 'CANCELLED', updated_at = ?
                WHERE collection_id = ? AND status = 'PENDING'
                """,
                now, collection.id()
        );
        jdbc.update("""
                UPDATE fund_collections
                SET status = 'CANCELLED', updated_at = ?
                WHERE id = ?
                """,
                now, collection.id()
        );
        jdbc.update("UPDATE group_funds SET updated_at = ? WHERE id = ?", now, fund.id());

        return buildCollectionDetailResponse(fund, requireCollectionRow(collectionId), access, callerUserId);
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public ContributionResponse submitContribution(
            UUID collectionId,
            UUID callerUserId,
            CreateContributionRequest request
    ) {
        FundRow fund = lockFundRow(requireCollectionRow(collectionId).fundId());
        CollectionRow collection = lockCollectionRow(collectionId);
        ReadableGroupAccess access = groupPermissions.requireMutableMembership(fund.groupId(), callerUserId);
        requireActiveFund(fund);
        cleanupStaleManagers(fund.id(), fund.groupId());

        if (!"OPEN".equals(collection.status())) {
            throw new BusinessException(ErrorCode.FUND_COLLECTION_NOT_OPEN);
        }

        UUID contributorUserId = request.userId() == null ? callerUserId : request.userId();
        boolean callerCanManage = canManageFund(fund.id(), access, callerUserId);
        if (!contributorUserId.equals(callerUserId) && !callerCanManage) {
            throw new BusinessException(ErrorCode.FUND_ACCESS_DENIED);
        }

        List<ObligationRow> obligations = jdbc.query("""
                SELECT * FROM fund_collection_obligations
                WHERE collection_id = ? AND user_id = ?
                FOR UPDATE
                """,
                OBLIGATION_ROW,
                collection.id(),
                contributorUserId
        );
        if (obligations.isEmpty()) {
            throw new BusinessException(ErrorCode.FUND_ACCESS_DENIED, "Member does not have an obligation in this collection.");
        }
        ObligationRow obligation = obligations.get(0);

        BigDecimal amount = validatePositiveAmount(request.amount());
        BigDecimal confirmed = queryNetConfirmedContributionAmount(collection.id(), contributorUserId);
        BigDecimal pending = queryPendingContributionAmount(collection.id(), contributorUserId);
        BigDecimal remaining = obligation.amountDue().subtract(confirmed).subtract(pending);

        if (amount.compareTo(remaining) > 0) {
            throw new BusinessException(ErrorCode.FUND_CONTRIBUTION_EXCEEDS_OBLIGATION);
        }

        UUID contributionId = UUID.randomUUID();
        Timestamp now = Timestamp.from(Instant.now());
        Timestamp paymentTs = request.paymentTime() == null ? now : Timestamp.from(request.paymentTime().toInstant());
        String proofKey = normalizeOptionalText(request.proofStorageKey(), 255);
        validateMediaKey(proofKey, UploadCategory.FUND_CONTRIBUTION_PROOF, fund.groupId(), callerUserId);
        String note = normalizeOptionalText(request.note(), 500);

        jdbc.update("""
                INSERT INTO fund_contributions (
                    id, fund_id, collection_id, user_id, amount, status,
                    proof_storage_key, note, payment_time, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, 'PENDING', ?, ?, ?, ?, ?)
                """,
                contributionId, fund.id(), collection.id(), contributorUserId, amount,
                proofKey, note, paymentTs, now, now
        );

        ContributionRow created = requireContributionRow(contributionId);
        Map<UUID, FundUserSummary> userMap = loadUserSummaries(fund.groupId(), Set.of(contributorUserId));
        return toContributionResponse(created, collection.title(), userMap, callerUserId, callerCanManage, fund.status(), access.group().getStatus());
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public ContributionResponse confirmContribution(UUID contributionId, UUID callerUserId) {
        // Serialize on the fund before taking child locks, including collection cancellation.
        FundRow fund = lockFundRow(requireContributionRow(contributionId).fundId());
        ContributionRow contribution = lockContributionRow(contributionId);
        CollectionRow collection = lockCollectionRow(contribution.collectionId());
        ReadableGroupAccess access = requireFundManagerOrOwner(fund, callerUserId);
        requireActiveFund(fund);

        if (!"PENDING".equals(contribution.status())) {
            throw new BusinessException(ErrorCode.FUND_CONTRIBUTION_ALREADY_RESOLVED);
        }
        if ("CANCELLED".equals(collection.status())) {
            throw new BusinessException(ErrorCode.FUND_COLLECTION_NOT_OPEN);
        }

        List<ObligationRow> obligations = jdbc.query("""
                SELECT * FROM fund_collection_obligations
                WHERE collection_id = ? AND user_id = ?
                FOR UPDATE
                """,
                OBLIGATION_ROW,
                collection.id(),
                contribution.userId()
        );
        if (obligations.isEmpty()) {
            throw new BusinessException(ErrorCode.FUND_CONTRIBUTION_NOT_FOUND);
        }
        BigDecimal confirmedSoFar = queryNetConfirmedContributionAmount(collection.id(), contribution.userId());
        if (confirmedSoFar.add(contribution.amount()).compareTo(obligations.get(0).amountDue()) > 0) {
            throw new BusinessException(ErrorCode.FUND_CONTRIBUTION_EXCEEDS_OBLIGATION);
        }

        Timestamp now = Timestamp.from(Instant.now());
        jdbc.update("""
                UPDATE fund_contributions
                SET status = 'CONFIRMED',
                    confirmed_by = ?,
                    confirmed_at = ?,
                    updated_at = ?
                WHERE id = ?
                """,
                callerUserId, now, now, contribution.id()
        );

        UUID txId = UUID.randomUUID();
        String txNote = contribution.note() != null ? contribution.note() : ("Đóng quỹ: " + collection.title());
        jdbc.update("""
                INSERT INTO fund_transactions (
                    id, fund_id, transaction_type, direction, amount,
                    reference_type, reference_id, note, created_by, created_at
                ) VALUES (?, ?, 'CONTRIBUTION', 'IN', ?, 'FUND_CONTRIBUTION', ?, ?, ?, ?)
                """,
                txId, fund.id(), contribution.amount(), contribution.id(), txNote, callerUserId, now
        );
        jdbc.update("UPDATE group_funds SET updated_at = ? WHERE id = ?", now, fund.id());
        if (eventPublisher != null && !callerUserId.equals(contribution.userId())) {
            eventPublisher.publishEvent(new com.wedo.backend.notification.event.NotificationDomainEvent(
                    "FUND_CONTRIBUTION_CONFIRMED:" + contribution.id(),
                    "FUND_CONTRIBUTION_CONFIRMED",
                    "FUND",
                    "HIGH",
                    true,
                    callerUserId,
                    fund.groupId(),
                    List.of(contribution.userId()),
                    "Đóng góp quỹ đã được xác nhận",
                    "Khoản đóng góp " + contribution.amount().toPlainString() + " VND cho đợt thu \"" + collection.title() + "\" đã được xác nhận.",
                    "FUND",
                    fund.id(),
                    "/groups/fund",
                    Map.of("groupId", fund.groupId().toString(), "fundId", fund.id().toString(), "contributionId", contribution.id().toString()),
                    now.toInstant()
            ));
        }

        ContributionRow updated = requireContributionRow(contribution.id());
        Map<UUID, FundUserSummary> userMap = loadUserSummaries(fund.groupId(), List.of(updated.userId(), callerUserId));
        return toContributionResponse(updated, collection.title(), userMap, callerUserId, true, fund.status(), access.group().getStatus());
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public ContributionResponse rejectContribution(UUID contributionId, UUID callerUserId, RejectRequest request) {
        FundRow fund = lockFundRow(requireContributionRow(contributionId).fundId());
        ContributionRow contribution = lockContributionRow(contributionId);
        CollectionRow collection = requireCollectionRow(contribution.collectionId());
        ReadableGroupAccess access = requireFundManagerOrOwner(fund, callerUserId);
        requireActiveFund(fund);

        if (!"PENDING".equals(contribution.status())) {
            throw new BusinessException(ErrorCode.FUND_CONTRIBUTION_ALREADY_RESOLVED);
        }

        String reason = request == null ? null : normalizeOptionalText(request.reason(), 500);
        Timestamp now = Timestamp.from(Instant.now());
        jdbc.update("""
                UPDATE fund_contributions
                SET status = 'REJECTED',
                    rejection_reason = ?,
                    updated_at = ?
                WHERE id = ?
                """,
                reason, now, contribution.id()
        );

        ContributionRow updated = requireContributionRow(contribution.id());
        Map<UUID, FundUserSummary> userMap = loadUserSummaries(fund.groupId(), List.of(updated.userId(), callerUserId));
        return toContributionResponse(updated, collection.title(), userMap, callerUserId, true, fund.status(), access.group().getStatus());
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public ContributionResponse cancelContribution(UUID contributionId, UUID callerUserId) {
        FundRow fund = lockFundRow(requireContributionRow(contributionId).fundId());
        ContributionRow contribution = lockContributionRow(contributionId);
        CollectionRow collection = requireCollectionRow(contribution.collectionId());
        ReadableGroupAccess access = groupPermissions.requireMutableMembership(fund.groupId(), callerUserId);
        requireActiveFund(fund);
        cleanupStaleManagers(fund.id(), fund.groupId());

        boolean callerCanManage = canManageFund(fund.id(), access, callerUserId);
        if (!contribution.userId().equals(callerUserId) && !callerCanManage) {
            throw new BusinessException(ErrorCode.FUND_ACCESS_DENIED);
        }
        if (!"PENDING".equals(contribution.status())) {
            throw new BusinessException(ErrorCode.FUND_CONTRIBUTION_ALREADY_RESOLVED);
        }

        Timestamp now = Timestamp.from(Instant.now());
        jdbc.update("""
                UPDATE fund_contributions
                SET status = 'CANCELLED',
                    updated_at = ?
                WHERE id = ?
                """,
                now, contribution.id()
        );

        ContributionRow updated = requireContributionRow(contribution.id());
        Map<UUID, FundUserSummary> userMap = loadUserSummaries(fund.groupId(), List.of(updated.userId(), callerUserId));
        return toContributionResponse(updated, collection.title(), userMap, callerUserId, callerCanManage, fund.status(), access.group().getStatus());
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public FundExpenseResponse createFundExpense(UUID fundId, UUID callerUserId, CreateFundExpenseRequest request) {
        FundRow fund = lockFundRow(fundId);
        ReadableGroupAccess access = requireFundManagerOrOwner(fund, callerUserId);
        requireActiveFund(fund);

        String title = normalizeRequiredText(request.title(), 160, "Expense title is required.");
        BigDecimal amount = validatePositiveAmount(request.amount());
        String receiptKey = normalizeOptionalText(request.receiptStorageKey(), 255);
        validateMediaKey(receiptKey, UploadCategory.FUND_EXPENSE_RECEIPT, fund.groupId(), callerUserId);
        String note = normalizeOptionalText(request.note(), 1000);

        if (request.activityId() != null) {
            Integer count = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM activities WHERE id = ? AND group_id = ?",
                    Integer.class,
                    request.activityId(),
                    fund.groupId()
            );
            if (count == null || count == 0) {
                throw new BusinessException(ErrorCode.ACTIVITY_NOT_FOUND);
            }
        }

        BalanceSnapshot balances = computeBalanceSnapshot(fund.id(), null);
        if (amount.compareTo(balances.availableBalance()) > 0) {
            throw new BusinessException(ErrorCode.FUND_INSUFFICIENT_BALANCE);
        }

        UUID expenseId = UUID.randomUUID();
        UUID txId = UUID.randomUUID();
        Timestamp now = Timestamp.from(Instant.now());
        Timestamp occurredTs = request.occurredAt() == null ? now : Timestamp.from(request.occurredAt().toInstant());

        jdbc.update("""
                INSERT INTO fund_expenses (
                    id, fund_id, activity_id, title, amount, occurred_at,
                    receipt_storage_key, note, created_by, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                expenseId, fund.id(), request.activityId(), title, amount, occurredTs,
                receiptKey, note, callerUserId, now, now
        );

        String txNote = note != null ? note : ("Chi quỹ: " + title);
        jdbc.update("""
                INSERT INTO fund_transactions (
                    id, fund_id, transaction_type, direction, amount,
                    reference_type, reference_id, note, created_by, created_at
                ) VALUES (?, ?, 'FUND_EXPENSE', 'OUT', ?, 'FUND_EXPENSE', ?, ?, ?, ?)
                """,
                txId, fund.id(), amount, expenseId, txNote, callerUserId, now
        );
        jdbc.update("UPDATE group_funds SET updated_at = ? WHERE id = ?", now, fund.id());

        return listExpensesInternal(fund, access, callerUserId).stream()
                .filter(e -> e.expenseId().equals(expenseId))
                .findFirst()
                .orElseThrow(() -> new BusinessException(ErrorCode.FUND_EXPENSE_NOT_FOUND));
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public List<FundExpenseResponse> listFundExpenses(UUID fundId, UUID callerUserId) {
        FundRow fund = requireFundRow(fundId);
        ReadableGroupAccess access = groupPermissions.requireReadableMembership(fund.groupId(), callerUserId);
        cleanupStaleManagers(fund.id(), fund.groupId());
        return listExpensesInternal(fund, access, callerUserId);
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public ReimbursementResponse createReimbursement(
            UUID fundId,
            UUID callerUserId,
            CreateReimbursementRequest request
    ) {
        FundRow fund = lockFundRow(fundId);
        ReadableGroupAccess access = groupPermissions.requireMutableMembership(fund.groupId(), callerUserId);
        requireActiveFund(fund);
        cleanupStaleManagers(fund.id(), fund.groupId());

        BigDecimal amount = validatePositiveAmount(request.amount());
        String reason = normalizeRequiredText(request.reason(), 500, "Reimbursement reason is required.");
        String receiptKey = normalizeOptionalText(request.receiptStorageKey(), 255);
        validateMediaKey(receiptKey, UploadCategory.FUND_REIMBURSEMENT_RECEIPT, fund.groupId(), callerUserId);

        BalanceSnapshot balances = computeBalanceSnapshot(fund.id(), null);
        if (amount.compareTo(balances.availableBalance()) > 0) {
            throw new BusinessException(ErrorCode.FUND_INSUFFICIENT_BALANCE);
        }

        UUID reimbursementId = UUID.randomUUID();
        Timestamp now = Timestamp.from(Instant.now());
        jdbc.update("""
                INSERT INTO fund_reimbursements (
                    id, fund_id, user_id, amount, reason, receipt_storage_key,
                    status, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, 'PENDING', ?, ?)
                """,
                reimbursementId, fund.id(), callerUserId, amount, reason, receiptKey, now, now
        );
        jdbc.update("UPDATE group_funds SET updated_at = ? WHERE id = ?", now, fund.id());

        return listReimbursementsInternal(fund, access, callerUserId, null).stream()
                .filter(r -> r.reimbursementId().equals(reimbursementId))
                .findFirst()
                .orElseThrow(() -> new BusinessException(ErrorCode.FUND_REIMBURSEMENT_NOT_FOUND));
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public List<ReimbursementResponse> listReimbursements(UUID fundId, UUID callerUserId, String statusFilter) {
        FundRow fund = requireFundRow(fundId);
        ReadableGroupAccess access = groupPermissions.requireReadableMembership(fund.groupId(), callerUserId);
        cleanupStaleManagers(fund.id(), fund.groupId());
        return listReimbursementsInternal(fund, access, callerUserId, statusFilter);
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public ReimbursementResponse approveReimbursement(UUID reimbursementId, UUID callerUserId) {
        ReimbursementRow reimbursement = lockReimbursementRow(reimbursementId);
        FundRow fund = lockFundRow(reimbursement.fundId());
        ReadableGroupAccess access = requireFundManagerOrOwner(fund, callerUserId);
        requireActiveFund(fund);

        if (!"PENDING".equals(reimbursement.status())) {
            throw new BusinessException(ErrorCode.FUND_REIMBURSEMENT_ALREADY_RESOLVED);
        }

        BalanceSnapshot balancesExcludingThis = computeBalanceSnapshot(fund.id(), reimbursement.id());
        if (reimbursement.amount().compareTo(balancesExcludingThis.availableBalance()) > 0) {
            throw new BusinessException(ErrorCode.FUND_INSUFFICIENT_BALANCE);
        }

        Timestamp now = Timestamp.from(Instant.now());
        jdbc.update("""
                UPDATE fund_reimbursements
                SET status = 'COMPLETED',
                    resolved_by = ?,
                    resolved_at = ?,
                    updated_at = ?
                WHERE id = ?
                """,
                callerUserId, now, now, reimbursement.id()
        );

        UUID txId = UUID.randomUUID();
        jdbc.update("""
                INSERT INTO fund_transactions (
                    id, fund_id, transaction_type, direction, amount,
                    reference_type, reference_id, note, created_by, created_at
                ) VALUES (?, ?, 'REIMBURSEMENT', 'OUT', ?, 'FUND_REIMBURSEMENT', ?, ?, ?, ?)
                """,
                txId, fund.id(), reimbursement.amount(), reimbursement.id(), reimbursement.reason(), callerUserId, now
        );
        jdbc.update("UPDATE group_funds SET updated_at = ? WHERE id = ?", now, fund.id());
        if (eventPublisher != null && !callerUserId.equals(reimbursement.userId())) {
            eventPublisher.publishEvent(new com.wedo.backend.notification.event.NotificationDomainEvent(
                    "FUND_REIMBURSEMENT_APPROVED:" + reimbursement.id(),
                    "FUND_REIMBURSEMENT_APPROVED",
                    "FUND",
                    "HIGH",
                    true,
                    callerUserId,
                    fund.groupId(),
                    List.of(reimbursement.userId()),
                    "Yêu cầu hoàn tiền quỹ được duyệt",
                    "Yêu cầu hoàn tiền " + reimbursement.amount().toPlainString() + " VND của bạn đã được chấp thuận.",
                    "FUND",
                    fund.id(),
                    "/groups/fund",
                    Map.of("groupId", fund.groupId().toString(), "fundId", fund.id().toString(), "reimbursementId", reimbursement.id().toString()),
                    now.toInstant()
            ));
        }

        return listReimbursementsInternal(fund, access, callerUserId, null).stream()
                .filter(r -> r.reimbursementId().equals(reimbursement.id()))
                .findFirst()
                .orElseThrow(() -> new BusinessException(ErrorCode.FUND_REIMBURSEMENT_NOT_FOUND));
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public ReimbursementResponse rejectReimbursement(UUID reimbursementId, UUID callerUserId, RejectRequest request) {
        ReimbursementRow reimbursement = lockReimbursementRow(reimbursementId);
        FundRow fund = lockFundRow(reimbursement.fundId());
        ReadableGroupAccess access = requireFundManagerOrOwner(fund, callerUserId);
        requireActiveFund(fund);

        if (!"PENDING".equals(reimbursement.status())) {
            throw new BusinessException(ErrorCode.FUND_REIMBURSEMENT_ALREADY_RESOLVED);
        }

        String reason = request == null ? null : normalizeOptionalText(request.reason(), 500);
        Timestamp now = Timestamp.from(Instant.now());
        jdbc.update("""
                UPDATE fund_reimbursements
                SET status = 'REJECTED',
                    resolved_by = ?,
                    resolved_at = ?,
                    rejection_reason = ?,
                    updated_at = ?
                WHERE id = ?
                """,
                callerUserId, now, reason, now, reimbursement.id()
        );
        jdbc.update("UPDATE group_funds SET updated_at = ? WHERE id = ?", now, fund.id());

        return listReimbursementsInternal(fund, access, callerUserId, null).stream()
                .filter(r -> r.reimbursementId().equals(reimbursement.id()))
                .findFirst()
                .orElseThrow(() -> new BusinessException(ErrorCode.FUND_REIMBURSEMENT_NOT_FOUND));
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public ReimbursementResponse cancelReimbursement(UUID reimbursementId, UUID callerUserId) {
        ReimbursementRow reimbursement = lockReimbursementRow(reimbursementId);
        FundRow fund = lockFundRow(reimbursement.fundId());
        ReadableGroupAccess access = groupPermissions.requireMutableMembership(fund.groupId(), callerUserId);
        requireActiveFund(fund);
        cleanupStaleManagers(fund.id(), fund.groupId());

        boolean callerCanManage = canManageFund(fund.id(), access, callerUserId);
        if (!reimbursement.userId().equals(callerUserId) && !callerCanManage) {
            throw new BusinessException(ErrorCode.FUND_ACCESS_DENIED);
        }
        if (!"PENDING".equals(reimbursement.status())) {
            throw new BusinessException(ErrorCode.FUND_REIMBURSEMENT_ALREADY_RESOLVED);
        }

        Timestamp now = Timestamp.from(Instant.now());
        jdbc.update("""
                UPDATE fund_reimbursements
                SET status = 'CANCELLED',
                    resolved_by = ?,
                    resolved_at = ?,
                    updated_at = ?
                WHERE id = ?
                """,
                callerUserId, now, now, reimbursement.id()
        );
        jdbc.update("UPDATE group_funds SET updated_at = ? WHERE id = ?", now, fund.id());

        return listReimbursementsInternal(fund, access, callerUserId, null).stream()
                .filter(r -> r.reimbursementId().equals(reimbursement.id()))
                .findFirst()
                .orElseThrow(() -> new BusinessException(ErrorCode.FUND_REIMBURSEMENT_NOT_FOUND));
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public List<FundTransactionResponse> listTransactions(
            UUID fundId,
            UUID callerUserId,
            String typeFilter,
            String directionFilter
    ) {
        FundRow fund = requireFundRow(fundId);
        ReadableGroupAccess access = groupPermissions.requireReadableMembership(fund.groupId(), callerUserId);
        cleanupStaleManagers(fund.id(), fund.groupId());
        return listTransactionsInternal(fund, access, callerUserId, typeFilter, directionFilter);
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public FundTransactionResponse reverseTransaction(
            UUID transactionId,
            UUID callerUserId,
            ReverseTransactionRequest request
    ) {
        TransactionRow original = lockTransactionRow(transactionId);
        FundRow fund = lockFundRow(original.fundId());
        ReadableGroupAccess access = requireFundManagerOrOwner(fund, callerUserId);
        requireActiveFund(fund);

        String reason = normalizeRequiredText(request == null ? null : request.reason(), 500, "Reversal reason is required.");

        if ("REVERSAL".equals(original.transactionType())) {
            throw new BusinessException(ErrorCode.FUND_REVERSAL_NOT_ALLOWED);
        }

        Integer alreadyReversed = jdbc.queryForObject(
                "SELECT COUNT(*) FROM fund_transaction_reversals WHERE original_transaction_id = ?",
                Integer.class,
                original.id()
        );
        if (alreadyReversed != null && alreadyReversed > 0) {
            throw new BusinessException(ErrorCode.FUND_TRANSACTION_ALREADY_REVERSED);
        }

        if ("IN".equals(original.direction())) {
            BalanceSnapshot balances = computeBalanceSnapshot(fund.id(), null);
            if (balances.availableBalance().compareTo(original.amount()) < 0) {
                throw new BusinessException(ErrorCode.FUND_INSUFFICIENT_BALANCE);
            }
        }

        String reversalDirection = "IN".equals(original.direction()) ? "OUT" : "IN";
        UUID reversalTxId = UUID.randomUUID();
        Timestamp now = Timestamp.from(Instant.now());

        jdbc.update("""
                INSERT INTO fund_transactions (
                    id, fund_id, transaction_type, direction, amount,
                    reference_type, reference_id, note, created_by, created_at
                ) VALUES (?, ?, 'REVERSAL', ?, ?, NULL, NULL, ?, ?, ?)
                """,
                reversalTxId, fund.id(), reversalDirection, original.amount(), reason, callerUserId, now
        );

        jdbc.update("""
                INSERT INTO fund_transaction_reversals (
                    id, fund_id, original_transaction_id, reversal_transaction_id, reason, reversed_by, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                UUID.randomUUID(), fund.id(), original.id(), reversalTxId, reason, callerUserId, now
        );
        jdbc.update("UPDATE group_funds SET updated_at = ? WHERE id = ?", now, fund.id());

        return listTransactionsInternal(fund, access, callerUserId, null, null).stream()
                .filter(tx -> tx.transactionId().equals(reversalTxId))
                .findFirst()
                .orElseThrow(() -> new BusinessException(ErrorCode.FUND_TRANSACTION_NOT_FOUND));
    }

    private FundDetailResponse getFundByIdInternal(UUID fundId, UUID callerUserId) {
        FundRow fund = requireFundRow(fundId);
        ReadableGroupAccess access = groupPermissions.requireReadableMembership(fund.groupId(), callerUserId);
        cleanupStaleManagers(fund.id(), fund.groupId());
        return buildFundDetailResponse(fund, access, callerUserId);
    }

    private FundDetailResponse buildFundDetailResponse(
            FundRow fund,
            ReadableGroupAccess access,
            UUID callerUserId
    ) {
        List<FundManagerResponse> managers = loadManagers(fund.id(), fund.groupId());
        BalanceSnapshot balances = computeBalanceSnapshot(fund.id(), null);
        int openCollections = countOpenCollections(fund.id());
        int pendingContributions = countPendingContributions(fund.id());
        int pendingReimbursements = countPendingReimbursements(fund.id());

        boolean isOwner = access.membership().getRole() == GroupRole.OWNER;
        boolean isDelegatedManager = managers.stream().anyMatch(m -> m.user().userId().equals(callerUserId));
        boolean isFundManager = isOwner || isDelegatedManager;
        boolean mutable = access.group().getStatus() == GroupStatus.ACTIVE && "ACTIVE".equals(fund.status());
        boolean canClose = isOwner && mutable
                && balances.ledgerBalance().compareTo(ZERO) == 0
                && balances.availableBalance().compareTo(ZERO) == 0
                && balances.pendingReimbursements().compareTo(ZERO) == 0
                && openCollections == 0
                && pendingContributions == 0
                && pendingReimbursements == 0;

        FundPermissionProjection permissions = new FundPermissionProjection(
                isOwner,
                isFundManager,
                isFundManager && mutable,
                isOwner && mutable,
                canClose,
                isFundManager && mutable,
                isFundManager && mutable,
                mutable,
                mutable
        );

        Set<UUID> userIds = new LinkedHashSet<>();
        userIds.add(fund.createdBy());
        if (fund.closedBy() != null) {
            userIds.add(fund.closedBy());
        }
        Map<UUID, FundUserSummary> userMap = loadUserSummaries(fund.groupId(), userIds);

        return new FundDetailResponse(
                fund.id(),
                fund.groupId(),
                fund.name(),
                fund.status(),
                "VND",
                balances.ledgerBalance(),
                balances.pendingReimbursements(),
                balances.availableBalance(),
                balances.totalInflow(),
                balances.totalOutflow(),
                openCollections,
                pendingContributions,
                pendingReimbursements,
                managers,
                permissions,
                userMap.get(fund.createdBy()),
                fund.createdAt(),
                fund.updatedAt(),
                fund.closedAt(),
                fund.closedBy() == null ? null : userMap.get(fund.closedBy())
        );
    }

    private List<CollectionSummaryResponse> listCollectionsInternal(
            FundRow fund,
            ReadableGroupAccess access,
            UUID callerUserId,
            String statusFilter
    ) {
        List<CollectionRow> rows;
        if (statusFilter != null && !statusFilter.isBlank()) {
            String normalized = statusFilter.trim().toUpperCase(Locale.ROOT);
            rows = jdbc.query("""
                    SELECT * FROM fund_collections
                    WHERE fund_id = ? AND status = ?
                    ORDER BY created_at DESC, id DESC
                    """,
                    COLLECTION_ROW,
                    fund.id(),
                    normalized
            );
        } else {
            rows = jdbc.query("""
                    SELECT * FROM fund_collections
                    WHERE fund_id = ?
                    ORDER BY created_at DESC, id DESC
                    """,
                    COLLECTION_ROW,
                    fund.id()
            );
        }
        if (rows.isEmpty()) {
            return List.of();
        }

        List<CollectionSummaryResponse> result = new ArrayList<>(rows.size());
        for (CollectionRow row : rows) {
            CollectionDetailResponse detail = buildCollectionDetailResponse(fund, row, access, callerUserId);
            CollectionObligationResponse myOb = detail.obligations().stream()
                    .filter(o -> o.user().userId().equals(callerUserId))
                    .findFirst()
                    .orElse(null);
            result.add(new CollectionSummaryResponse(
                    detail.collectionId(),
                    detail.fundId(),
                    detail.title(),
                    detail.description(),
                    detail.deadlineAt(),
                    detail.status(),
                    detail.totalExpectedAmount(),
                    detail.totalConfirmedAmount(),
                    detail.totalPendingAmount(),
                    detail.totalRemainingAmount(),
                    detail.totalMembersCount(),
                    detail.paidMembersCount(),
                    detail.pendingContributionsCount(),
                    myOb == null ? ZERO : myOb.amountDue(),
                    myOb == null ? ZERO : myOb.confirmedAmount(),
                    myOb == null ? ZERO : myOb.pendingAmount(),
                    myOb == null ? ZERO : myOb.remainingAmount(),
                    myOb == null ? "NONE" : myOb.status(),
                    detail.createdBy(),
                    detail.createdAt(),
                    detail.updatedAt()
            ));
        }
        return result;
    }

    private CollectionDetailResponse buildCollectionDetailResponse(
            FundRow fund,
            CollectionRow collection,
            ReadableGroupAccess access,
            UUID callerUserId
    ) {
        List<ObligationRow> obligationRows = jdbc.query("""
                SELECT * FROM fund_collection_obligations
                WHERE collection_id = ?
                ORDER BY created_at ASC, id ASC
                """,
                OBLIGATION_ROW,
                collection.id()
        );
        List<ContributionRow> contributionRows = jdbc.query("""
                SELECT * FROM fund_contributions
                WHERE collection_id = ?
                ORDER BY created_at DESC, id DESC
                """,
                CONTRIBUTION_ROW,
                collection.id()
        );

        Set<UUID> reversedContributionIds = loadReversedContributionIds(fund.id());

        Set<UUID> userIds = new LinkedHashSet<>();
        userIds.add(collection.createdBy());
        for (ObligationRow o : obligationRows) {
            userIds.add(o.userId());
        }
        for (ContributionRow c : contributionRows) {
            userIds.add(c.userId());
            if (c.confirmedBy() != null) {
                userIds.add(c.confirmedBy());
            }
        }
        Map<UUID, FundUserSummary> userMap = loadUserSummaries(fund.groupId(), userIds);

        Map<UUID, BigDecimal> confirmedByUser = new HashMap<>();
        Map<UUID, BigDecimal> pendingByUser = new HashMap<>();
        int pendingCount = 0;
        for (ContributionRow c : contributionRows) {
            if ("CONFIRMED".equals(c.status()) && !reversedContributionIds.contains(c.id())) {
                confirmedByUser.merge(c.userId(), c.amount(), BigDecimal::add);
            } else if ("PENDING".equals(c.status())) {
                pendingByUser.merge(c.userId(), c.amount(), BigDecimal::add);
                pendingCount++;
            }
        }

        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        List<CollectionObligationResponse> obligations = new ArrayList<>(obligationRows.size());
        BigDecimal totalExpected = ZERO;
        BigDecimal totalConfirmed = ZERO;
        BigDecimal totalPending = ZERO;
        BigDecimal totalRemaining = ZERO;
        int paidMembersCount = 0;

        for (ObligationRow o : obligationRows) {
            BigDecimal confirmed = scaleMoney(confirmedByUser.getOrDefault(o.userId(), ZERO));
            BigDecimal pending = scaleMoney(pendingByUser.getOrDefault(o.userId(), ZERO));
            BigDecimal remaining = o.amountDue().subtract(confirmed).subtract(pending);
            if (remaining.compareTo(ZERO) < 0) {
                remaining = ZERO;
            }
            remaining = scaleMoney(remaining);

            String derivedStatus;
            if (confirmed.compareTo(o.amountDue()) >= 0) {
                derivedStatus = "PAID";
                paidMembersCount++;
            } else if (collection.deadlineAt() != null && now.isAfter(collection.deadlineAt())) {
                derivedStatus = "OVERDUE";
            } else if (confirmed.compareTo(ZERO) > 0) {
                derivedStatus = "PARTIAL";
            } else {
                derivedStatus = "UNPAID";
            }

            obligations.add(new CollectionObligationResponse(
                    o.id(),
                    o.collectionId(),
                    userMap.get(o.userId()),
                    o.amountDue(),
                    confirmed,
                    pending,
                    remaining,
                    derivedStatus,
                    o.createdAt()
            ));

            totalExpected = totalExpected.add(o.amountDue());
            totalConfirmed = totalConfirmed.add(confirmed);
            totalPending = totalPending.add(pending);
            totalRemaining = totalRemaining.add(remaining);
        }

        boolean callerCanManage = canManageFund(fund.id(), access, callerUserId);
        boolean mutable = access.group().getStatus() == GroupStatus.ACTIVE && "ACTIVE".equals(fund.status());
        boolean collectionOpen = "OPEN".equals(collection.status());
        boolean canManageCollection = callerCanManage && mutable && collectionOpen;

        CollectionObligationResponse myObligation = obligations.stream()
                .filter(o -> o.user().userId().equals(callerUserId))
                .findFirst()
                .orElse(null);
        boolean canContribute = mutable && collectionOpen
                && ((myObligation != null && myObligation.remainingAmount().compareTo(ZERO) > 0) || callerCanManage);

        List<ContributionResponse> contributions = contributionRows.stream()
                .map(c -> toContributionResponse(
                        c,
                        collection.title(),
                        userMap,
                        callerUserId,
                        callerCanManage,
                        fund.status(),
                        access.group().getStatus()
                ))
                .toList();

        return new CollectionDetailResponse(
                collection.id(),
                collection.fundId(),
                collection.title(),
                collection.description(),
                collection.deadlineAt(),
                collection.status(),
                scaleMoney(totalExpected),
                scaleMoney(totalConfirmed),
                scaleMoney(totalPending),
                scaleMoney(totalRemaining),
                obligations.size(),
                paidMembersCount,
                pendingCount,
                obligations,
                contributions,
                userMap.get(collection.createdBy()),
                collection.createdAt(),
                collection.updatedAt(),
                canManageCollection,
                canContribute
        );
    }

    private ContributionResponse toContributionResponse(
            ContributionRow c,
            String collectionTitle,
            Map<UUID, FundUserSummary> userMap,
            UUID callerUserId,
            boolean callerCanManage,
            String fundStatus,
            GroupStatus groupStatus
    ) {
        boolean mutable = groupStatus == GroupStatus.ACTIVE && "ACTIVE".equals(fundStatus);
        boolean pending = "PENDING".equals(c.status());
        return new ContributionResponse(
                c.id(),
                c.fundId(),
                c.collectionId(),
                collectionTitle,
                userMap.get(c.userId()),
                c.amount(),
                c.status(),
                c.proofStorageKey(),
                c.note(),
                c.paymentTime(),
                c.confirmedBy() == null ? null : userMap.get(c.confirmedBy()),
                c.confirmedAt(),
                c.rejectionReason(),
                c.createdAt(),
                c.updatedAt(),
                mutable && pending && callerCanManage,
                mutable && pending && callerCanManage,
                mutable && pending && (c.userId().equals(callerUserId) || callerCanManage)
        );
    }

    private List<FundExpenseResponse> listExpensesInternal(
            FundRow fund,
            ReadableGroupAccess access,
            UUID callerUserId
    ) {
        List<FundExpenseRow> rows = jdbc.query("""
                SELECT fe.*, ga.title AS activity_title,
                       ft.id AS tx_id,
                       CASE WHEN ftr.id IS NOT NULL THEN TRUE ELSE FALSE END AS is_reversed
                FROM fund_expenses fe
                LEFT JOIN activities ga ON ga.id = fe.activity_id
                LEFT JOIN fund_transactions ft
                       ON ft.reference_type = 'FUND_EXPENSE' AND ft.reference_id = fe.id
                LEFT JOIN fund_transaction_reversals ftr
                       ON ftr.original_transaction_id = ft.id
                WHERE fe.fund_id = ?
                ORDER BY fe.occurred_at DESC, fe.created_at DESC, fe.id DESC
                """,
                EXPENSE_ROW,
                fund.id()
        );
        if (rows.isEmpty()) {
            return List.of();
        }

        Set<UUID> userIds = new LinkedHashSet<>();
        for (FundExpenseRow r : rows) {
            userIds.add(r.createdBy());
        }
        Map<UUID, FundUserSummary> userMap = loadUserSummaries(fund.groupId(), userIds);

        return rows.stream()
                .map(r -> new FundExpenseResponse(
                        r.id(),
                        r.fundId(),
                        r.activityId(),
                        r.activityTitle(),
                        r.title(),
                        r.amount(),
                        r.occurredAt(),
                        r.receiptStorageKey(),
                        r.note(),
                        r.transactionId(),
                        r.reversed(),
                        userMap.get(r.createdBy()),
                        r.createdAt(),
                        r.updatedAt()
                ))
                .toList();
    }

    private List<ReimbursementResponse> listReimbursementsInternal(
            FundRow fund,
            ReadableGroupAccess access,
            UUID callerUserId,
            String statusFilter
    ) {
        List<ReimbursementRow> rows;
        if (statusFilter != null && !statusFilter.isBlank()) {
            String normalized = statusFilter.trim().toUpperCase(Locale.ROOT);
            rows = jdbc.query("""
                    SELECT fr.*, ft.id AS tx_id,
                           CASE WHEN ftr.id IS NOT NULL THEN TRUE ELSE FALSE END AS is_reversed
                    FROM fund_reimbursements fr
                    LEFT JOIN fund_transactions ft
                           ON ft.reference_type = 'FUND_REIMBURSEMENT' AND ft.reference_id = fr.id
                    LEFT JOIN fund_transaction_reversals ftr
                           ON ftr.original_transaction_id = ft.id
                    WHERE fr.fund_id = ? AND fr.status = ?
                    ORDER BY fr.created_at DESC, fr.id DESC
                    """,
                    REIMBURSEMENT_ROW,
                    fund.id(),
                    normalized
            );
        } else {
            rows = jdbc.query("""
                    SELECT fr.*, ft.id AS tx_id,
                           CASE WHEN ftr.id IS NOT NULL THEN TRUE ELSE FALSE END AS is_reversed
                    FROM fund_reimbursements fr
                    LEFT JOIN fund_transactions ft
                           ON ft.reference_type = 'FUND_REIMBURSEMENT' AND ft.reference_id = fr.id
                    LEFT JOIN fund_transaction_reversals ftr
                           ON ftr.original_transaction_id = ft.id
                    WHERE fr.fund_id = ?
                    ORDER BY fr.created_at DESC, fr.id DESC
                    """,
                    REIMBURSEMENT_ROW,
                    fund.id()
            );
        }
        if (rows.isEmpty()) {
            return List.of();
        }

        Set<UUID> userIds = new LinkedHashSet<>();
        for (ReimbursementRow r : rows) {
            userIds.add(r.userId());
            if (r.resolvedBy() != null) {
                userIds.add(r.resolvedBy());
            }
        }
        Map<UUID, FundUserSummary> userMap = loadUserSummaries(fund.groupId(), userIds);

        boolean callerCanManage = canManageFund(fund.id(), access, callerUserId);
        boolean mutable = access.group().getStatus() == GroupStatus.ACTIVE && "ACTIVE".equals(fund.status());

        return rows.stream()
                .map(r -> {
                    boolean pending = "PENDING".equals(r.status());
                    return new ReimbursementResponse(
                            r.id(),
                            r.fundId(),
                            userMap.get(r.userId()),
                            r.amount(),
                            r.reason(),
                            r.receiptStorageKey(),
                            r.status(),
                            r.resolvedBy() == null ? null : userMap.get(r.resolvedBy()),
                            r.resolvedAt(),
                            r.rejectionReason(),
                            r.transactionId(),
                            r.reversed(),
                            r.createdAt(),
                            r.updatedAt(),
                            mutable && pending && callerCanManage,
                            mutable && pending && callerCanManage,
                            mutable && pending && (r.userId().equals(callerUserId) || callerCanManage)
                    );
                })
                .toList();
    }

    private List<FundTransactionResponse> listTransactionsInternal(
            FundRow fund,
            ReadableGroupAccess access,
            UUID callerUserId,
            String typeFilter,
            String directionFilter
    ) {
        StringBuilder sql = new StringBuilder("""
                SELECT ft.*,
                       ftr_orig.reversal_transaction_id AS rev_tx_id,
                       ftr_orig.reason AS rev_reason,
                       ftr_orig.reversed_by AS rev_by,
                       ftr_orig.created_at AS rev_at,
                       ftr_rev.original_transaction_id AS orig_tx_id
                FROM fund_transactions ft
                LEFT JOIN fund_transaction_reversals ftr_orig
                       ON ftr_orig.original_transaction_id = ft.id
                LEFT JOIN fund_transaction_reversals ftr_rev
                       ON ftr_rev.reversal_transaction_id = ft.id
                WHERE ft.fund_id = ?
                """);
        List<Object> params = new ArrayList<>();
        params.add(fund.id());

        if (typeFilter != null && !typeFilter.isBlank()) {
            sql.append(" AND ft.transaction_type = ?");
            params.add(typeFilter.trim().toUpperCase(Locale.ROOT));
        }
        if (directionFilter != null && !directionFilter.isBlank()) {
            sql.append(" AND ft.direction = ?");
            params.add(directionFilter.trim().toUpperCase(Locale.ROOT));
        }
        sql.append(" ORDER BY ft.created_at DESC, ft.id DESC");

        List<TransactionRow> rows = jdbc.query(sql.toString(), TRANSACTION_ROW, params.toArray());
        if (rows.isEmpty()) {
            return List.of();
        }

        Set<UUID> userIds = new LinkedHashSet<>();
        for (TransactionRow r : rows) {
            userIds.add(r.createdBy());
            if (r.reversedBy() != null) {
                userIds.add(r.reversedBy());
            }
        }
        Map<UUID, FundUserSummary> userMap = loadUserSummaries(fund.groupId(), userIds);

        boolean callerCanManage = canManageFund(fund.id(), access, callerUserId);
        boolean mutable = access.group().getStatus() == GroupStatus.ACTIVE && "ACTIVE".equals(fund.status());

        return rows.stream()
                .map(r -> {
                    boolean reversed = r.reversalTransactionId() != null;
                    boolean isReversal = "REVERSAL".equals(r.transactionType()) || r.originalTransactionId() != null;
                    String refTitle = switch (r.transactionType()) {
                        case "CONTRIBUTION" -> "Thu quỹ thành viên";
                        case "FUND_EXPENSE" -> "Chi trực tiếp từ quỹ";
                        case "REIMBURSEMENT" -> "Hoàn ứng từ quỹ";
                        case "REVERSAL" -> "Giao dịch đảo bút toán";
                        default -> r.transactionType();
                    };
                    return new FundTransactionResponse(
                            r.id(),
                            r.fundId(),
                            r.transactionType(),
                            r.direction(),
                            r.amount(),
                            r.referenceType(),
                            r.referenceId(),
                            refTitle,
                            r.note(),
                            userMap.get(r.createdBy()),
                            r.createdAt(),
                            reversed,
                            r.reversalTransactionId(),
                            r.reversalReason(),
                            r.reversedBy() == null ? null : userMap.get(r.reversedBy()),
                            r.reversedAt(),
                            r.originalTransactionId(),
                            mutable && callerCanManage && !reversed && !isReversal
                    );
                })
                .toList();
    }

    private BalanceSnapshot computeBalanceSnapshot(UUID fundId, UUID excludePendingReimbursementId) {
        BigDecimal inflow = jdbc.queryForObject("""
                SELECT COALESCE(SUM(amount), 0.00)
                FROM fund_transactions
                WHERE fund_id = ? AND direction = 'IN'
                """,
                BigDecimal.class,
                fundId
        );
        BigDecimal outflow = jdbc.queryForObject("""
                SELECT COALESCE(SUM(amount), 0.00)
                FROM fund_transactions
                WHERE fund_id = ? AND direction = 'OUT'
                """,
                BigDecimal.class,
                fundId
        );
        BigDecimal pendingReimbursements;
        if (excludePendingReimbursementId == null) {
            pendingReimbursements = jdbc.queryForObject("""
                    SELECT COALESCE(SUM(amount), 0.00)
                    FROM fund_reimbursements
                    WHERE fund_id = ? AND status = 'PENDING'
                    """,
                    BigDecimal.class,
                    fundId
            );
        } else {
            pendingReimbursements = jdbc.queryForObject("""
                    SELECT COALESCE(SUM(amount), 0.00)
                    FROM fund_reimbursements
                    WHERE fund_id = ? AND status = 'PENDING' AND id <> ?
                    """,
                    BigDecimal.class,
                    fundId,
                    excludePendingReimbursementId
            );
        }

        BigDecimal scaledIn = scaleMoney(inflow == null ? ZERO : inflow);
        BigDecimal scaledOut = scaleMoney(outflow == null ? ZERO : outflow);
        BigDecimal scaledPending = scaleMoney(pendingReimbursements == null ? ZERO : pendingReimbursements);
        BigDecimal ledgerBalance = scaleMoney(scaledIn.subtract(scaledOut));
        BigDecimal availableBalance = scaleMoney(ledgerBalance.subtract(scaledPending));

        return new BalanceSnapshot(scaledIn, scaledOut, ledgerBalance, scaledPending, availableBalance);
    }

    private int countOpenCollections(UUID fundId) {
        Integer count = jdbc.queryForObject(
                "SELECT COUNT(*) FROM fund_collections WHERE fund_id = ? AND status = 'OPEN'",
                Integer.class,
                fundId
        );
        return count == null ? 0 : count;
    }

    private int countPendingContributions(UUID fundId) {
        Integer count = jdbc.queryForObject(
                "SELECT COUNT(*) FROM fund_contributions WHERE fund_id = ? AND status = 'PENDING'",
                Integer.class,
                fundId
        );
        return count == null ? 0 : count;
    }

    private int countPendingReimbursements(UUID fundId) {
        Integer count = jdbc.queryForObject(
                "SELECT COUNT(*) FROM fund_reimbursements WHERE fund_id = ? AND status = 'PENDING'",
                Integer.class,
                fundId
        );
        return count == null ? 0 : count;
    }

    private BigDecimal queryNetConfirmedContributionAmount(UUID collectionId, UUID userId) {
        BigDecimal total = jdbc.queryForObject("""
                SELECT COALESCE(SUM(fc.amount), 0.00)
                FROM fund_contributions fc
                WHERE fc.collection_id = ?
                  AND fc.user_id = ?
                  AND fc.status = 'CONFIRMED'
                  AND NOT EXISTS (
                      SELECT 1
                      FROM fund_transactions ft
                      JOIN fund_transaction_reversals ftr ON ftr.original_transaction_id = ft.id
                      WHERE ft.reference_type = 'FUND_CONTRIBUTION'
                        AND ft.reference_id = fc.id
                  )
                """,
                BigDecimal.class,
                collectionId,
                userId
        );
        return scaleMoney(total == null ? ZERO : total);
    }

    private BigDecimal queryPendingContributionAmount(UUID collectionId, UUID userId) {
        BigDecimal total = jdbc.queryForObject("""
                SELECT COALESCE(SUM(amount), 0.00)
                FROM fund_contributions
                WHERE collection_id = ? AND user_id = ? AND status = 'PENDING'
                """,
                BigDecimal.class,
                collectionId,
                userId
        );
        return scaleMoney(total == null ? ZERO : total);
    }

    private Set<UUID> loadReversedContributionIds(UUID fundId) {
        List<UUID> ids = jdbc.query("""
                SELECT ft.reference_id
                FROM fund_transactions ft
                JOIN fund_transaction_reversals ftr ON ftr.original_transaction_id = ft.id
                WHERE ft.fund_id = ?
                  AND ft.reference_type = 'FUND_CONTRIBUTION'
                  AND ft.reference_id IS NOT NULL
                """,
                (rs, i) -> rs.getObject("reference_id", UUID.class),
                fundId
        );
        return new LinkedHashSet<>(ids);
    }

    private Map<UUID, BigDecimal> resolveCollectionObligations(UUID groupId, CreateCollectionRequest request) {
        Set<UUID> activeMemberIds = new LinkedHashSet<>(jdbc.query(
                "SELECT user_id FROM group_memberships WHERE group_id = ? AND status = 'ACTIVE' ORDER BY id ASC",
                (rs, i) -> rs.getObject("user_id", UUID.class),
                groupId
        ));

        Map<UUID, BigDecimal> resolved = new LinkedHashMap<>();
        if (request.obligations() != null && !request.obligations().isEmpty()) {
            for (ObligationInput item : request.obligations()) {
                if (item.userId() == null || !activeMemberIds.contains(item.userId())) {
                    throw new BusinessException(ErrorCode.VALIDATION_FAILED, "Target obligation user must be an active group member.");
                }
                BigDecimal amount = validatePositiveAmount(item.amountDue());
                if (resolved.putIfAbsent(item.userId(), amount) != null) {
                    throw new BusinessException(ErrorCode.VALIDATION_FAILED, "Duplicate obligation for user.");
                }
            }
            return resolved;
        }

        if (request.amountPerMember() != null) {
            BigDecimal amount = validatePositiveAmount(request.amountPerMember());
            List<UUID> targets = (request.targetUserIds() == null || request.targetUserIds().isEmpty())
                    ? new ArrayList<>(activeMemberIds)
                    : request.targetUserIds();
            for (UUID userId : targets) {
                if (!activeMemberIds.contains(userId)) {
                    throw new BusinessException(ErrorCode.VALIDATION_FAILED, "Target obligation user must be an active group member.");
                }
                resolved.put(userId, amount);
            }
            return resolved;
        }

        throw new BusinessException(ErrorCode.VALIDATION_FAILED, "Either obligations or amountPerMember must be provided.");
    }

    private void cleanupStaleManagers(UUID fundId, UUID groupId) {
        jdbc.update("""
                DELETE FROM fund_managers fm
                WHERE fm.fund_id = ?
                  AND NOT EXISTS (
                      SELECT 1 FROM group_memberships gm
                      WHERE gm.group_id = ?
                        AND gm.user_id = fm.user_id
                        AND gm.status = 'ACTIVE'
                        AND gm.role = 'ADMIN'
                  )
                """,
                fundId, groupId
        );
    }

    private List<FundManagerResponse> loadManagers(UUID fundId, UUID groupId) {
        List<ManagerRow> rows = jdbc.query("""
                SELECT fm.id, fm.fund_id, fm.user_id, fm.assigned_by, fm.assigned_at
                FROM fund_managers fm
                JOIN group_memberships gm
                  ON gm.group_id = ?
                 AND gm.user_id = fm.user_id
                 AND gm.status = 'ACTIVE'
                 AND gm.role = 'ADMIN'
                WHERE fm.fund_id = ?
                ORDER BY fm.assigned_at ASC, fm.id ASC
                """,
                (rs, i) -> new ManagerRow(
                        rs.getObject("id", UUID.class),
                        rs.getObject("fund_id", UUID.class),
                        rs.getObject("user_id", UUID.class),
                        rs.getObject("assigned_by", UUID.class),
                        toOffsetDateTime(rs.getTimestamp("assigned_at"))
                ),
                groupId,
                fundId
        );
        if (rows.isEmpty()) {
            return List.of();
        }
        Set<UUID> userIds = new LinkedHashSet<>();
        for (ManagerRow r : rows) {
            userIds.add(r.userId());
            userIds.add(r.assignedBy());
        }
        Map<UUID, FundUserSummary> userMap = loadUserSummaries(groupId, userIds);
        return rows.stream()
                .map(r -> new FundManagerResponse(
                        r.id(),
                        r.fundId(),
                        userMap.get(r.userId()),
                        userMap.get(r.assignedBy()),
                        r.assignedAt()
                ))
                .toList();
    }

    private boolean canManageFund(UUID fundId, ReadableGroupAccess access, UUID callerUserId) {
        if (access.membership().getRole() == GroupRole.OWNER) {
            return true;
        }
        if (access.membership().getRole() != GroupRole.ADMIN) {
            return false;
        }
        Integer count = jdbc.queryForObject("""
                SELECT COUNT(*)
                FROM fund_managers fm
                JOIN group_memberships gm
                  ON gm.group_id = ?
                 AND gm.user_id = fm.user_id
                 AND gm.status = 'ACTIVE'
                 AND gm.role = 'ADMIN'
                WHERE fm.fund_id = ? AND fm.user_id = ?
                """,
                Integer.class,
                access.group().getId(),
                fundId,
                callerUserId
        );
        return count != null && count > 0;
    }

    private ReadableGroupAccess requireFundManagerOrOwner(FundRow fund, UUID callerUserId) {
        ReadableGroupAccess access = groupPermissions.requireMutableMembership(fund.groupId(), callerUserId);
        cleanupStaleManagers(fund.id(), fund.groupId());
        if (!canManageFund(fund.id(), access, callerUserId)) {
            throw new BusinessException(ErrorCode.FUND_ACCESS_DENIED);
        }
        return access;
    }

    private void requireActiveFund(FundRow fund) {
        if (!"ACTIVE".equals(fund.status())) {
            throw new BusinessException(ErrorCode.FUND_CLOSED);
        }
    }

    @Transactional(readOnly = true)
    public void authorizeMediaPresign(UploadCategory category, UUID groupId, UUID callerUserId) {
        switch (category) {
            case FUND_CONTRIBUTION_PROOF -> {
                ReadableGroupAccess access = groupPermissions.requireMutableMembership(groupId, callerUserId);
                FundRow fund = activeFundForGroup(groupId);
                requireActiveFund(fund);
                boolean manager = canManageFund(fund.id(), access, callerUserId);
                Boolean eligible = jdbc.queryForObject("""
                        SELECT EXISTS (
                            SELECT 1 FROM fund_collections fc
                            JOIN fund_collection_obligations o ON o.collection_id=fc.id
                            WHERE fc.fund_id=? AND fc.status='OPEN' AND (? OR o.user_id=?)
                              AND o.amount_due >
                                COALESCE((SELECT SUM(c.amount) FROM fund_contributions c
                                          WHERE c.collection_id=fc.id AND c.user_id=o.user_id AND c.status='CONFIRMED'),0)
                                + COALESCE((SELECT SUM(c.amount) FROM fund_contributions c
                                            WHERE c.collection_id=fc.id AND c.user_id=o.user_id AND c.status='PENDING'),0)
                        )
                        """, Boolean.class, fund.id(), manager, callerUserId);
                if (!Boolean.TRUE.equals(eligible)) throw new BusinessException(ErrorCode.FUND_ACCESS_DENIED);
                if (access.group().getStatus() != GroupStatus.ACTIVE) throw new BusinessException(ErrorCode.GROUP_ARCHIVED);
            }
            case FUND_EXPENSE_RECEIPT -> {
                FundRow fund = activeFundForGroup(groupId);
                requireActiveFund(fund);
                ReadableGroupAccess access = groupPermissions.requireMutableMembership(groupId, callerUserId);
                if (!canManageFund(fund.id(), access, callerUserId)) {
                    throw new BusinessException(ErrorCode.FUND_ACCESS_DENIED);
                }
            }
            case FUND_REIMBURSEMENT_RECEIPT -> {
                groupPermissions.requireMutableMembership(groupId, callerUserId);
                FundRow fund = activeFundForGroup(groupId);
                if (computeBalanceSnapshot(fund.id(), null).availableBalance().compareTo(CENT) < 0) {
                    throw new BusinessException(ErrorCode.FUND_INSUFFICIENT_BALANCE);
                }
            }
            default -> throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        }
    }

    @Transactional(readOnly = true)
    public void requireMediaReadable(UploadCategory category, String storageKey, UUID expectedGroupId, UUID callerUserId) {
        String table = switch (category) {
            case FUND_CONTRIBUTION_PROOF -> "fund_contributions";
            case FUND_EXPENSE_RECEIPT -> "fund_expenses";
            case FUND_REIMBURSEMENT_RECEIPT -> "fund_reimbursements";
            default -> throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
        };
        String column = category == UploadCategory.FUND_CONTRIBUTION_PROOF
                ? "proof_storage_key" : "receipt_storage_key";
        List<UUID> groups = jdbc.query("SELECT gf.group_id FROM " + table
                        + " x JOIN group_funds gf ON gf.id=x.fund_id WHERE x." + column + "=? LIMIT 2",
                (rs, n) -> rs.getObject(1, UUID.class), storageKey);
        if (groups.size() != 1 || !expectedGroupId.equals(groups.get(0))) {
            throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
        }
        groupPermissions.requireReadableMembership(groups.get(0), callerUserId);
    }

    private FundRow activeFundForGroup(UUID groupId) {
        List<FundRow> funds = jdbc.query("SELECT * FROM group_funds WHERE group_id=? AND status='ACTIVE' LIMIT 1",
                FUND_ROW, groupId);
        if (funds.isEmpty()) throw new BusinessException(ErrorCode.FUND_NOT_FOUND);
        return funds.get(0);
    }

    private void validateMediaKey(String storageKey, UploadCategory category, UUID groupId, UUID uploaderId) {
        if (storageKey == null) return;
        if (mediaReferences == null) throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        mediaReferences.validate(storageKey, category, groupId, uploaderId);
    }

    private Map<UUID, FundUserSummary> loadUserSummaries(UUID groupId, Collection<UUID> userIds) {
        if (userIds == null || userIds.isEmpty()) {
            return Map.of();
        }
        Map<UUID, FundUserSummary> result = new LinkedHashMap<>();
        for (UUID userId : userIds) {
            if (userId == null || result.containsKey(userId)) {
                continue;
            }
            List<FundUserSummary> rows = jdbc.query("""
                    SELECT u.id,
                           COALESCE(NULLIF(TRIM(u.display_name), ''), u.username::text, u.email::text, 'Người dùng') AS display_name,
                           u.username::text AS username,
                           u.avatar_storage_key,
                           gm.role AS active_role
                    FROM users u
                    LEFT JOIN group_memberships gm
                           ON gm.group_id = ? AND gm.user_id = u.id AND gm.status = 'ACTIVE'
                    WHERE u.id = ?
                    """,
                    (rs, i) -> {
                        String activeRole = rs.getString("active_role");
                        return new FundUserSummary(
                                rs.getObject("id", UUID.class),
                                rs.getString("display_name"),
                                rs.getString("username"),
                                rs.getString("avatar_storage_key"),
                                activeRole != null ? activeRole : "FORMER_MEMBER",
                                activeRole != null
                        );
                    },
                    groupId,
                    userId
            );
            if (!rows.isEmpty()) {
                result.put(userId, rows.get(0));
            } else {
                result.put(userId, new FundUserSummary(userId, "Thành viên", null, null, "FORMER_MEMBER", false));
            }
        }
        return result;
    }

    private FundRow requireFundRow(UUID fundId) {
        try {
            return jdbc.queryForObject("SELECT * FROM group_funds WHERE id = ?", FUND_ROW, fundId);
        } catch (EmptyResultDataAccessException ex) {
            throw new BusinessException(ErrorCode.FUND_NOT_FOUND);
        }
    }

    private FundRow lockFundRow(UUID fundId) {
        try {
            return jdbc.queryForObject("SELECT * FROM group_funds WHERE id = ? FOR UPDATE", FUND_ROW, fundId);
        } catch (EmptyResultDataAccessException ex) {
            throw new BusinessException(ErrorCode.FUND_NOT_FOUND);
        }
    }

    private CollectionRow requireCollectionRow(UUID collectionId) {
        try {
            return jdbc.queryForObject("SELECT * FROM fund_collections WHERE id = ?", COLLECTION_ROW, collectionId);
        } catch (EmptyResultDataAccessException ex) {
            throw new BusinessException(ErrorCode.FUND_COLLECTION_NOT_FOUND);
        }
    }

    private CollectionRow lockCollectionRow(UUID collectionId) {
        try {
            return jdbc.queryForObject("SELECT * FROM fund_collections WHERE id = ? FOR UPDATE", COLLECTION_ROW, collectionId);
        } catch (EmptyResultDataAccessException ex) {
            throw new BusinessException(ErrorCode.FUND_COLLECTION_NOT_FOUND);
        }
    }

    private ContributionRow requireContributionRow(UUID contributionId) {
        try {
            return jdbc.queryForObject("SELECT * FROM fund_contributions WHERE id = ?", CONTRIBUTION_ROW, contributionId);
        } catch (EmptyResultDataAccessException ex) {
            throw new BusinessException(ErrorCode.FUND_CONTRIBUTION_NOT_FOUND);
        }
    }

    private ContributionRow lockContributionRow(UUID contributionId) {
        try {
            return jdbc.queryForObject("SELECT * FROM fund_contributions WHERE id = ? FOR UPDATE", CONTRIBUTION_ROW, contributionId);
        } catch (EmptyResultDataAccessException ex) {
            throw new BusinessException(ErrorCode.FUND_CONTRIBUTION_NOT_FOUND);
        }
    }

    private ReimbursementRow lockReimbursementRow(UUID reimbursementId) {
        try {
            return jdbc.queryForObject("""
                    SELECT fr.*, NULL AS tx_id, FALSE AS is_reversed
                    FROM fund_reimbursements fr
                    WHERE fr.id = ?
                    FOR UPDATE
                    """,
                    REIMBURSEMENT_ROW,
                    reimbursementId
            );
        } catch (EmptyResultDataAccessException ex) {
            throw new BusinessException(ErrorCode.FUND_REIMBURSEMENT_NOT_FOUND);
        }
    }

    private TransactionRow lockTransactionRow(UUID transactionId) {
        try {
            return jdbc.queryForObject("""
                    SELECT ft.*,
                           NULL AS rev_tx_id,
                           NULL AS rev_reason,
                           NULL AS rev_by,
                           NULL AS rev_at,
                           NULL AS orig_tx_id
                    FROM fund_transactions ft
                    WHERE ft.id = ?
                    FOR UPDATE
                    """,
                    TRANSACTION_ROW,
                    transactionId
            );
        } catch (EmptyResultDataAccessException ex) {
            throw new BusinessException(ErrorCode.FUND_TRANSACTION_NOT_FOUND);
        }
    }

    private static BigDecimal validatePositiveAmount(BigDecimal amount) {
        if (amount == null) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "Amount is required.");
        }
        BigDecimal scaled;
        try {
            scaled = amount.setScale(2, RoundingMode.UNNECESSARY);
        } catch (ArithmeticException ex) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "Amount must have at most 2 decimal places.");
        }
        if (scaled.compareTo(CENT) < 0) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "Amount must be greater than zero.");
        }
        return scaled;
    }

    private static BigDecimal scaleMoney(BigDecimal value) {
        return value.setScale(2, RoundingMode.HALF_UP);
    }

    private static String normalizeRequiredText(String raw, int maxLen, String message) {
        if (raw == null || raw.trim().isEmpty()) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, message);
        }
        String trimmed = raw.trim();
        if (trimmed.length() > maxLen) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "Field exceeds maximum length of " + maxLen);
        }
        return trimmed;
    }

    private static String normalizeOptionalText(String raw, int maxLen) {
        if (raw == null || raw.trim().isEmpty()) {
            return null;
        }
        String trimmed = raw.trim();
        if (trimmed.length() > maxLen) {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "Field exceeds maximum length of " + maxLen);
        }
        return trimmed;
    }

    private static OffsetDateTime toOffsetDateTime(Timestamp ts) {
        return ts == null ? null : ts.toInstant().atOffset(ZoneOffset.UTC);
    }

    private static FundRow mapFundRow(ResultSet rs, int rowNum) throws SQLException {
        return new FundRow(
                rs.getObject("id", UUID.class),
                rs.getObject("group_id", UUID.class),
                rs.getString("name"),
                rs.getString("status"),
                rs.getObject("created_by", UUID.class),
                toOffsetDateTime(rs.getTimestamp("created_at")),
                toOffsetDateTime(rs.getTimestamp("updated_at")),
                toOffsetDateTime(rs.getTimestamp("closed_at")),
                rs.getObject("closed_by", UUID.class)
        );
    }

    private static CollectionRow mapCollectionRow(ResultSet rs, int rowNum) throws SQLException {
        return new CollectionRow(
                rs.getObject("id", UUID.class),
                rs.getObject("fund_id", UUID.class),
                rs.getString("title"),
                rs.getString("description"),
                toOffsetDateTime(rs.getTimestamp("deadline_at")),
                rs.getString("status"),
                rs.getObject("created_by", UUID.class),
                toOffsetDateTime(rs.getTimestamp("created_at")),
                toOffsetDateTime(rs.getTimestamp("updated_at"))
        );
    }

    private static ObligationRow mapObligationRow(ResultSet rs, int rowNum) throws SQLException {
        return new ObligationRow(
                rs.getObject("id", UUID.class),
                rs.getObject("collection_id", UUID.class),
                rs.getObject("user_id", UUID.class),
                scaleMoney(rs.getBigDecimal("amount_due")),
                toOffsetDateTime(rs.getTimestamp("created_at"))
        );
    }

    private static ContributionRow mapContributionRow(ResultSet rs, int rowNum) throws SQLException {
        return new ContributionRow(
                rs.getObject("id", UUID.class),
                rs.getObject("fund_id", UUID.class),
                rs.getObject("collection_id", UUID.class),
                rs.getObject("user_id", UUID.class),
                scaleMoney(rs.getBigDecimal("amount")),
                rs.getString("status"),
                rs.getString("proof_storage_key"),
                rs.getString("note"),
                toOffsetDateTime(rs.getTimestamp("payment_time")),
                rs.getObject("confirmed_by", UUID.class),
                toOffsetDateTime(rs.getTimestamp("confirmed_at")),
                rs.getString("rejection_reason"),
                toOffsetDateTime(rs.getTimestamp("created_at")),
                toOffsetDateTime(rs.getTimestamp("updated_at"))
        );
    }

    private static FundExpenseRow mapExpenseRow(ResultSet rs, int rowNum) throws SQLException {
        return new FundExpenseRow(
                rs.getObject("id", UUID.class),
                rs.getObject("fund_id", UUID.class),
                rs.getObject("activity_id", UUID.class),
                rs.getString("activity_title"),
                rs.getString("title"),
                scaleMoney(rs.getBigDecimal("amount")),
                toOffsetDateTime(rs.getTimestamp("occurred_at")),
                rs.getString("receipt_storage_key"),
                rs.getString("note"),
                rs.getObject("tx_id", UUID.class),
                rs.getBoolean("is_reversed"),
                rs.getObject("created_by", UUID.class),
                toOffsetDateTime(rs.getTimestamp("created_at")),
                toOffsetDateTime(rs.getTimestamp("updated_at"))
        );
    }

    private static ReimbursementRow mapReimbursementRow(ResultSet rs, int rowNum) throws SQLException {
        return new ReimbursementRow(
                rs.getObject("id", UUID.class),
                rs.getObject("fund_id", UUID.class),
                rs.getObject("user_id", UUID.class),
                scaleMoney(rs.getBigDecimal("amount")),
                rs.getString("reason"),
                rs.getString("receipt_storage_key"),
                rs.getString("status"),
                rs.getObject("resolved_by", UUID.class),
                toOffsetDateTime(rs.getTimestamp("resolved_at")),
                rs.getString("rejection_reason"),
                rs.getObject("tx_id", UUID.class),
                rs.getBoolean("is_reversed"),
                toOffsetDateTime(rs.getTimestamp("created_at")),
                toOffsetDateTime(rs.getTimestamp("updated_at"))
        );
    }

    private static TransactionRow mapTransactionRow(ResultSet rs, int rowNum) throws SQLException {
        return new TransactionRow(
                rs.getObject("id", UUID.class),
                rs.getObject("fund_id", UUID.class),
                rs.getString("transaction_type"),
                rs.getString("direction"),
                scaleMoney(rs.getBigDecimal("amount")),
                rs.getString("reference_type"),
                rs.getObject("reference_id", UUID.class),
                rs.getString("note"),
                rs.getObject("created_by", UUID.class),
                toOffsetDateTime(rs.getTimestamp("created_at")),
                rs.getObject("rev_tx_id", UUID.class),
                rs.getString("rev_reason"),
                rs.getObject("rev_by", UUID.class),
                toOffsetDateTime(rs.getTimestamp("rev_at")),
                rs.getObject("orig_tx_id", UUID.class)
        );
    }

    private record BalanceSnapshot(
            BigDecimal totalInflow,
            BigDecimal totalOutflow,
            BigDecimal ledgerBalance,
            BigDecimal pendingReimbursements,
            BigDecimal availableBalance
    ) {
    }

    private record FundRow(
            UUID id,
            UUID groupId,
            String name,
            String status,
            UUID createdBy,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt,
            OffsetDateTime closedAt,
            UUID closedBy
    ) {
    }

    private record ManagerRow(
            UUID id,
            UUID fundId,
            UUID userId,
            UUID assignedBy,
            OffsetDateTime assignedAt
    ) {
    }

    private record CollectionRow(
            UUID id,
            UUID fundId,
            String title,
            String description,
            OffsetDateTime deadlineAt,
            String status,
            UUID createdBy,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt
    ) {
    }

    private record ObligationRow(
            UUID id,
            UUID collectionId,
            UUID userId,
            BigDecimal amountDue,
            OffsetDateTime createdAt
    ) {
    }

    private record ContributionRow(
            UUID id,
            UUID fundId,
            UUID collectionId,
            UUID userId,
            BigDecimal amount,
            String status,
            String proofStorageKey,
            String note,
            OffsetDateTime paymentTime,
            UUID confirmedBy,
            OffsetDateTime confirmedAt,
            String rejectionReason,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt
    ) {
    }

    private record FundExpenseRow(
            UUID id,
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
            UUID createdBy,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt
    ) {
    }

    private record ReimbursementRow(
            UUID id,
            UUID fundId,
            UUID userId,
            BigDecimal amount,
            String reason,
            String receiptStorageKey,
            String status,
            UUID resolvedBy,
            OffsetDateTime resolvedAt,
            String rejectionReason,
            UUID transactionId,
            boolean reversed,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt
    ) {
    }

    private record TransactionRow(
            UUID id,
            UUID fundId,
            String transactionType,
            String direction,
            BigDecimal amount,
            String referenceType,
            UUID referenceId,
            String note,
            UUID createdBy,
            OffsetDateTime createdAt,
            UUID reversalTransactionId,
            String reversalReason,
            UUID reversedBy,
            OffsetDateTime reversedAt,
            UUID originalTransactionId
    ) {
    }
}
