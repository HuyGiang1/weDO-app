package com.wedo.backend.expense.service;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.expense.dto.ExpenseDtos.BalanceExpense;
import com.wedo.backend.expense.dto.ExpenseDtos.BalanceSettlement;
import com.wedo.backend.expense.dto.ExpenseDtos.Change;
import com.wedo.backend.expense.dto.ExpenseDtos.CreateSettlementRequest;
import com.wedo.backend.expense.dto.ExpenseDtos.ExpenseDetail;
import com.wedo.backend.expense.dto.ExpenseDtos.ExpenseRequest;
import com.wedo.backend.expense.dto.ExpenseDtos.ExpenseSummary;
import com.wedo.backend.expense.dto.ExpenseDtos.MyBalances;
import com.wedo.backend.expense.dto.ExpenseDtos.PairBalance;
import com.wedo.backend.expense.dto.ExpenseDtos.PermissionProjection;
import com.wedo.backend.expense.dto.ExpenseDtos.SettlementPermissionProjection;
import com.wedo.backend.expense.dto.ExpenseDtos.SettlementResponse;
import com.wedo.backend.expense.dto.ExpenseDtos.SettlementStatusChange;
import com.wedo.backend.expense.dto.ExpenseDtos.Share;
import com.wedo.backend.expense.dto.ExpenseDtos.ShareRequest;
import com.wedo.backend.expense.dto.ExpenseDtos.UserBalance;
import com.wedo.backend.expense.dto.ExpenseDtos.UserSummary;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupStatus;
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
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ExpenseService {
    private static final BigDecimal CENT = new BigDecimal("0.01");
    private static final BigDecimal ZERO = new BigDecimal("0.00");
    private static final RowMapper<ExpenseRow> EXPENSE_ROW = ExpenseService::mapExpenseRow;

    private final JdbcTemplate jdbc;
    private final GroupPermissionService groupPermissions;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private org.springframework.context.ApplicationEventPublisher eventPublisher;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private MediaReferenceService mediaReferences;

    public ExpenseService(JdbcTemplate jdbc, GroupPermissionService groupPermissions) {
        this.jdbc = jdbc;
        this.groupPermissions = groupPermissions;
    }

    @Transactional
    public ExpenseDetail create(UUID groupId, UUID actorId, ExpenseRequest request) {
        requireMutableGroup(groupId, actorId);
        ExpenseDraft draft = validateRequest(groupId, request);
        String receiptKey = normalizeStorageKey(request.receiptStorageKey());
        validateReceiptKey(receiptKey, groupId, actorId);
        Set<PairKey> affected = affectedPairs(draft.payerId(), draft.shares());
        Ledger ledger = loadLedger(groupId, null, null);
        addExpense(ledger, draft.payerId(), draft.shares());
        ensurePendingReservations(ledger, affected);

        UUID expenseId = UUID.randomUUID();
        Instant now = Instant.now();
        jdbc.update("""
                INSERT INTO expenses(id,group_id,activity_id,paid_by,created_by,title,total_amount,
                    split_type,occurred_at,note,receipt_storage_key,status,created_at,updated_at)
                VALUES (?,?,?,?,?,?,?,?,?,?,?, 'ACTIVE', ?, ?)
                """, expenseId, groupId, draft.activityId(), draft.payerId(), actorId, draft.title(),
                draft.amount(), draft.splitMethod(), draft.occurredAt(), draft.note(), receiptKey, Timestamp.from(now), Timestamp.from(now));
        insertShares(expenseId, draft.shares());
        if (eventPublisher != null) {
            List<UUID> recipients = draft.shares().stream()
                    .map(ShareFact::userId)
                    .filter(uid -> !uid.equals(actorId))
                    .toList();
            if (!recipients.isEmpty()) {
                eventPublisher.publishEvent(new com.wedo.backend.notification.event.NotificationDomainEvent(
                        "EXPENSE_CREATED:" + expenseId,
                        "EXPENSE_CREATED",
                        "FINANCE",
                        "NORMAL",
                        false,
                        actorId,
                        groupId,
                        recipients,
                        "Khoản chi mới: " + draft.title(),
                        "Khoản chi \"" + draft.title() + "\" (" + draft.amount().toPlainString() + " VND) đã được ghi nhận.",
                        "EXPENSE",
                        expenseId,
                        "/groups/expenses/detail",
                        Map.of("groupId", groupId.toString(), "expenseId", expenseId.toString()),
                        now
                ));
            }
        }
        return detail(expenseId, actorId);
    }

    @Transactional(readOnly = true)
    public List<ExpenseSummary> list(
            UUID groupId, UUID actorId, UUID activityId, Boolean involvingMe,
            Boolean createdByMe, OffsetDateTime from, OffsetDateTime to
    ) {
        ReadableGroupAccess access = groupPermissions.requireReadableMembership(groupId, actorId);
        StringBuilder sql = new StringBuilder("""
                SELECT e.*, p.display_name AS payer_name, p.username AS payer_username,
                       p.avatar_storage_key AS payer_avatar, c.display_name AS creator_name,
                       c.username AS creator_username, c.avatar_storage_key AS creator_avatar,
                       (SELECT count(*) FROM expense_shares s WHERE s.expense_id=e.id) AS participant_count
                FROM expenses e JOIN users p ON p.id=e.paid_by
                LEFT JOIN users c ON c.id=e.created_by
                WHERE e.group_id=?
                """);
        List<Object> args = new ArrayList<>();
        args.add(groupId);
        if (activityId != null) { sql.append(" AND e.activity_id=?"); args.add(activityId); }
        if (Boolean.TRUE.equals(involvingMe)) {
            sql.append(" AND (e.paid_by=? OR EXISTS(SELECT 1 FROM expense_shares s WHERE s.expense_id=e.id AND s.user_id=?))");
            args.add(actorId); args.add(actorId);
        }
        if (Boolean.TRUE.equals(createdByMe)) { sql.append(" AND e.created_by=?"); args.add(actorId); }
        if (from != null) { sql.append(" AND e.occurred_at>=?"); args.add(from); }
        if (to != null) { sql.append(" AND e.occurred_at<=?"); args.add(to); }
        sql.append(" ORDER BY e.occurred_at DESC,e.created_at DESC,e.id");

        return jdbc.query(sql.toString(), (rs, rowNum) -> {
            ExpenseRow row = mapExpenseRow(rs, rowNum);
            int participantCount = rs.getInt("participant_count");
            UserSummary payer = new UserSummary(row.payerId(), displayName(rs.getString("payer_name"), rs.getString("payer_username")), rs.getString("payer_avatar"));
            UUID creatorId = row.creatorId();
            UserSummary creator = creatorId == null ? null : new UserSummary(creatorId,
                    displayName(rs.getString("creator_name"), rs.getString("creator_username")), rs.getString("creator_avatar"));
            return summary(row, payer, creator, participantCount, actorId, access);
        }, args.toArray());
    }

    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    public ExpenseDetail detail(UUID expenseId, UUID actorId) {
        ExpenseRow row = findExpense(expenseId, false);
        ReadableGroupAccess access = groupPermissions.requireReadableMembership(row.groupId(), actorId);
        List<Share> shares = jdbc.query("""
                SELECT s.user_id,s.amount,u.display_name,u.username,u.avatar_storage_key
                FROM expense_shares s JOIN users u ON u.id=s.user_id
                WHERE s.expense_id=? ORDER BY s.user_id
                """, (rs, n) -> new Share(rs.getObject("user_id", UUID.class),
                displayName(rs.getString("display_name"), rs.getString("username")), rs.getString("avatar_storage_key"), rs.getBigDecimal("amount")), expenseId);
        List<Change> changes = jdbc.query("""
                SELECT actor_id,field_name,old_value,new_value,created_at
                FROM expense_change_logs WHERE expense_id=? ORDER BY created_at,id
                """, (rs, n) -> new Change(rs.getObject("actor_id", UUID.class), rs.getString("field_name"),
                rs.getString("old_value"), rs.getString("new_value"), rs.getTimestamp("created_at").toInstant()), expenseId);
        return new ExpenseDetail(row.id(), row.groupId(), row.activityId(), row.title(), row.amount(), row.splitType(),
                row.status(), row.occurredAt(), row.note(), user(row.payerId()), user(row.creatorId()), shares, changes,
                row.createdAt(), row.updatedAt(), permissions(row, actorId, access), row.receiptStorageKey());
    }

    @Transactional
    public ExpenseDetail update(UUID expenseId, UUID actorId, ExpenseRequest request) {
        ExpenseRow initial = findExpense(expenseId, false);
        requireMutableGroup(initial.groupId(), actorId);
        ExpenseRow current = findExpense(expenseId, true);
        requireCanModify(current, actorId);
        if (!"ACTIVE".equals(current.status())) throw new BusinessException(ErrorCode.EXPENSE_UPDATE_NOT_ALLOWED);
        ExpenseDraft draft = validateRequest(current.groupId(), request);
        String requestedReceiptKey = normalizeStorageKey(request.receiptStorageKey());
        validateReceiptKey(requestedReceiptKey, current.groupId(), actorId);
        String receiptKey = requestedReceiptKey == null ? current.receiptStorageKey() : requestedReceiptKey;
        List<Share> oldShares = sharesFor(expenseId);
        Set<PairKey> affected = affectedPairs(current.payerId(), oldShares.stream().map(s -> new ShareFact(s.userId(), s.amount())).toList());
        affected.addAll(affectedPairs(draft.payerId(), draft.shares()));
        Ledger ledger = loadLedger(current.groupId(), expenseId, null);
        addExpense(ledger, draft.payerId(), draft.shares());
        ensurePendingReservations(ledger, affected);

        Instant now = Instant.now();
        Map<String, String> before = expenseValues(current, oldShares);
        Map<String, String> after = draftValues(draft);
        after.put("receiptStorageKey", receiptKey);
        jdbc.update("""
                UPDATE expenses SET activity_id=?,paid_by=?,title=?,total_amount=?,split_type=?,occurred_at=?,note=?,receipt_storage_key=?,updated_at=?
                WHERE id=?
                """, draft.activityId(), draft.payerId(), draft.title(), draft.amount(), draft.splitMethod(),
                draft.occurredAt(), draft.note(), receiptKey, Timestamp.from(now), expenseId);
        jdbc.update("DELETE FROM expense_shares WHERE expense_id=?", expenseId);
        insertShares(expenseId, draft.shares());
        recordChanges(expenseId, actorId, before, after, now);
        if (requestedReceiptKey != null && !requestedReceiptKey.equals(current.receiptStorageKey())
                && mediaReferences != null) {
            mediaReferences.deleteAfterCommit(current.receiptStorageKey(), requestedReceiptKey);
        }
        return detail(expenseId, actorId);
    }

    @Transactional
    public ExpenseDetail cancel(UUID expenseId, UUID actorId) {
        ExpenseRow initial = findExpense(expenseId, false);
        requireMutableGroup(initial.groupId(), actorId);
        ExpenseRow current = findExpense(expenseId, true);
        requireCanModify(current, actorId);
        if ("CANCELLED".equals(current.status())) return detail(expenseId, actorId);
        List<Share> oldShares = sharesFor(expenseId);
        Set<PairKey> affected = affectedPairs(current.payerId(), oldShares.stream().map(s -> new ShareFact(s.userId(), s.amount())).toList());
        Ledger ledger = loadLedger(current.groupId(), expenseId, null);
        ensurePendingReservations(ledger, affected);
        Instant now = Instant.now();
        jdbc.update("UPDATE expenses SET status='CANCELLED',updated_at=? WHERE id=?", Timestamp.from(now), expenseId);
        jdbc.update("""
                INSERT INTO expense_change_logs(id,expense_id,actor_id,field_name,old_value,new_value,created_at)
                VALUES (?,?,?,?,?,?,?)
                """, UUID.randomUUID(), expenseId, actorId, "status", "ACTIVE", "CANCELLED", Timestamp.from(now));
        return detail(expenseId, actorId);
    }

    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    public MyBalances myBalances(UUID groupId, UUID actorId) {
        groupPermissions.requireReadableMembership(groupId, actorId);
        Ledger ledger = loadLedger(groupId, null, null);
        BigDecimal owedByMe = ZERO;
        BigDecimal owedToMe = ZERO;
        List<UserBalance> balances = new ArrayList<>();
        for (Map.Entry<PairKey, BigDecimal> entry : ledger.net.entrySet()) {
            PairKey pair = entry.getKey();
            BigDecimal amount = entry.getValue();
            if (amount.signum() == 0 || (!pair.first().equals(actorId) && !pair.second().equals(actorId))) continue;
            UUID peerId;
            String direction;
            if (pair.first().equals(actorId)) {
                peerId = pair.second();
                direction = amount.signum() > 0 ? "YOU_OWE" : "OWES_YOU";
            } else {
                peerId = pair.first();
                direction = amount.signum() > 0 ? "OWES_YOU" : "YOU_OWE";
            }
            BigDecimal absolute = amount.abs().setScale(2, RoundingMode.UNNECESSARY);
            if ("YOU_OWE".equals(direction)) owedByMe = owedByMe.add(absolute);
            else owedToMe = owedToMe.add(absolute);
            balances.add(new UserBalance(user(peerId), direction, absolute));
        }
        balances.sort(Comparator.comparing((UserBalance b) -> b.user().displayName(), String.CASE_INSENSITIVE_ORDER)
                .thenComparing(b -> b.user().id().toString()));
        return new MyBalances(owedByMe.setScale(2), owedToMe.setScale(2), balances);
    }

    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    public PairBalance pairBalance(UUID groupId, UUID actorId, UUID otherUserId) {
        groupPermissions.requireReadableMembership(groupId, actorId);
        if (actorId.equals(otherUserId)) throw new BusinessException(ErrorCode.EXPENSE_PARTICIPANT_INVALID);
        Ledger ledger = loadLedger(groupId, null, null);
        PairKey pair = PairKey.of(actorId, otherUserId);
        BigDecimal canonical = ledger.net.getOrDefault(pair, ZERO);
        BigDecimal amount = pair.first().equals(actorId) ? canonical.negate() : canonical;
        String direction = amount.signum() > 0 ? "OWES_YOU" : amount.signum() < 0 ? "YOU_OWE" : "SETTLED";
        List<BalanceExpense> sourceExpenses = jdbc.query("""
                SELECT DISTINCT e.id,e.title,e.total_amount,e.occurred_at
                FROM expenses e LEFT JOIN expense_shares s ON s.expense_id=e.id
                WHERE e.group_id=? AND e.status='ACTIVE'
                  AND ((e.paid_by=? AND s.user_id=?) OR (e.paid_by=? AND s.user_id=?))
                ORDER BY e.occurred_at DESC,e.id
                """, (rs, n) -> new BalanceExpense(rs.getObject("id", UUID.class), rs.getString("title"),
                rs.getBigDecimal("total_amount"), rs.getObject("occurred_at", OffsetDateTime.class)),
                groupId, actorId, otherUserId, otherUserId, actorId);
        List<BalanceSettlement> completed = settlements(groupId, actorId, otherUserId, "COMPLETED");
        List<BalanceSettlement> pending = settlements(groupId, actorId, otherUserId, "PENDING");
        return new PairBalance(groupId, otherUserId, amount.setScale(2), direction, sourceExpenses, completed, pending);
    }

    private ExpenseDraft validateRequest(UUID groupId, ExpenseRequest request) {
        BigDecimal amount = money(request.amount());
        if (amount.signum() <= 0) throw new BusinessException(ErrorCode.INVALID_EXPENSE_AMOUNT);
        if (request.occurredAt() == null) throw new BusinessException(ErrorCode.INVALID_EXPENSE_AMOUNT, "Expense date and time are required.");
        String title = request.title().trim();
        if (title.isEmpty() || title.length() > 255) throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        List<ShareFact> shares;
        String split = request.splitMethod();
        if ("EQUAL".equals(split)) {
            if (request.participantUserIds() == null || request.participantUserIds().isEmpty() || request.shares() != null) {
                throw new BusinessException(ErrorCode.EXPENSE_PARTICIPANT_INVALID);
            }
            List<UUID> participantIds = request.participantUserIds();
            requireUniqueIds(participantIds);
            if (amount.compareTo(CENT.multiply(BigDecimal.valueOf(participantIds.size()))) < 0) {
                throw new BusinessException(ErrorCode.INVALID_EXPENSE_AMOUNT);
            }
            shares = equalShares(amount, participantIds, request.payerUserId());
        } else if ("CUSTOM_AMOUNT".equals(split)) {
            if (request.shares() == null || request.shares().isEmpty() || request.participantUserIds() != null) {
                throw new BusinessException(ErrorCode.EXPENSE_PARTICIPANT_INVALID);
            }
            List<UUID> ids = request.shares().stream().map(ShareRequest::userId).toList();
            requireUniqueIds(ids);
            shares = request.shares().stream().map(share -> new ShareFact(share.userId(), money(share.amount()))).toList();
            if (shares.stream().anyMatch(share -> share.amount().signum() <= 0)) throw new BusinessException(ErrorCode.INVALID_EXPENSE_AMOUNT);
            BigDecimal sum = shares.stream().map(ShareFact::amount).reduce(ZERO, BigDecimal::add);
            if (sum.compareTo(amount) != 0) throw new BusinessException(ErrorCode.EXPENSE_SPLIT_TOTAL_MISMATCH);
        } else {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "Unsupported expense split method.");
        }
        validateActiveMembers(groupId, request.payerUserId(), shares);
        validateActivity(groupId, request.activityId());
        return new ExpenseDraft(title, amount, request.payerUserId(), split, shares, request.activityId(), request.occurredAt(), request.note());
    }

    private List<ShareFact> equalShares(BigDecimal total, List<UUID> participantIds, UUID payerId) {
        BigDecimal base = total.divide(BigDecimal.valueOf(participantIds.size()), 2, RoundingMode.DOWN);
        int remainderCents = total.subtract(base.multiply(BigDecimal.valueOf(participantIds.size())))
                .movePointRight(2).intValueExact();
        List<UUID> order = new ArrayList<>(participantIds);
        order.sort(Comparator.comparing(UUID::toString));
        if (order.remove(payerId)) order.add(0, payerId);
        Map<UUID, BigDecimal> values = new LinkedHashMap<>();
        for (UUID userId : order) values.put(userId, base);
        for (int i = 0; i < remainderCents; i++) values.compute(order.get(i), (id, value) -> value.add(CENT));
        return values.entrySet().stream().map(e -> new ShareFact(e.getKey(), e.getValue())).toList();
    }

    private BigDecimal money(BigDecimal value) {
        if (value == null) throw new BusinessException(ErrorCode.INVALID_EXPENSE_AMOUNT);
        try {
            BigDecimal scaled = value.setScale(2, RoundingMode.UNNECESSARY);
            if (scaled.precision() > 19) throw new BusinessException(ErrorCode.INVALID_EXPENSE_AMOUNT);
            return scaled;
        } catch (ArithmeticException ex) {
            throw new BusinessException(ErrorCode.INVALID_EXPENSE_AMOUNT);
        }
    }

    private void requireUniqueIds(List<UUID> ids) {
        if (ids.stream().anyMatch(id -> id == null) || new HashSet<>(ids).size() != ids.size()) {
            throw new BusinessException(ErrorCode.EXPENSE_PARTICIPANT_INVALID);
        }
    }

    private void validateActiveMembers(UUID groupId, UUID payerId, List<ShareFact> shares) {
        Set<UUID> users = new LinkedHashSet<>();
        users.add(payerId);
        shares.forEach(share -> users.add(share.userId()));
        List<UUID> sorted = users.stream().sorted(Comparator.comparing(UUID::toString)).toList();
        for (UUID userId : sorted) {
            Integer count = jdbc.queryForObject("""
                    SELECT count(*) FROM group_memberships m JOIN users u ON u.id=m.user_id
                    WHERE m.group_id=? AND m.user_id=? AND m.status='ACTIVE' AND u.status='ACTIVE'
                    """, Integer.class, groupId, userId);
            if (count == null || count != 1) throw new BusinessException(ErrorCode.EXPENSE_PARTICIPANT_INVALID);
        }
    }

    private void validateActivity(UUID groupId, UUID activityId) {
        if (activityId == null) return;
        Integer count = jdbc.queryForObject("SELECT count(*) FROM activities WHERE id=? AND group_id=?", Integer.class, activityId, groupId);
        if (count == null || count != 1) throw new BusinessException(ErrorCode.EXPENSE_PARTICIPANT_INVALID, "Activity must belong to the same group.");
    }

    private void requireMutableGroup(UUID groupId, UUID actorId) {
        groupPermissions.requireMutableMembership(groupId, actorId);
        jdbc.queryForObject("SELECT id FROM groups WHERE id=? FOR UPDATE", UUID.class, groupId);
        groupPermissions.requireMutableMembership(groupId, actorId);
    }

    @Transactional(readOnly = true)
    public void authorizeReceiptPresign(UUID groupId, UUID actorId) {
        groupPermissions.requireMutableMembership(groupId, actorId);
    }

    @Transactional(readOnly = true)
    public void requireReceiptReadable(String storageKey, UUID actorId, UUID expectedGroupId) {
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT id,group_id FROM expenses WHERE receipt_storage_key=? LIMIT 2", storageKey);
        if (rows.size() != 1 || !expectedGroupId.equals(rows.get(0).get("group_id"))) {
            throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
        }
        ExpenseDetail expense = detail((UUID) rows.get(0).get("id"), actorId);
        if (!storageKey.equals(expense.receiptStorageKey())) throw new BusinessException(ErrorCode.RESOURCE_NOT_FOUND);
    }

    private void validateReceiptKey(String storageKey, UUID groupId, UUID actorId) {
        if (storageKey == null) return;
        if (mediaReferences == null) throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        mediaReferences.validate(storageKey, UploadCategory.EXPENSE_RECEIPT, groupId, actorId);
    }

    private String normalizeStorageKey(String storageKey) {
        if (storageKey == null || storageKey.isBlank()) return null;
        String normalized = storageKey.trim();
        if (normalized.length() > 255) throw new BusinessException(ErrorCode.VALIDATION_FAILED);
        return normalized;
    }

    private ExpenseRow findExpense(UUID expenseId, boolean forUpdate) {
        String sql = expenseSql() + " WHERE e.id=?" + (forUpdate ? " FOR UPDATE OF e" : "");
        try {
            return jdbc.queryForObject(sql, EXPENSE_ROW, expenseId);
        } catch (EmptyResultDataAccessException ex) {
            throw new BusinessException(ErrorCode.EXPENSE_NOT_FOUND);
        }
    }

    private String expenseSql() {
        return """
                SELECT e.*,p.display_name AS payer_name,p.username AS payer_username,p.avatar_storage_key AS payer_avatar,
                       c.display_name AS creator_name,c.username AS creator_username,c.avatar_storage_key AS creator_avatar
                FROM expenses e JOIN users p ON p.id=e.paid_by LEFT JOIN users c ON c.id=e.created_by
                """;
    }

    private static ExpenseRow mapExpenseRow(ResultSet rs, int rowNum) throws SQLException {
        Timestamp created = rs.getTimestamp("created_at");
        Timestamp updated = rs.getTimestamp("updated_at");
        return new ExpenseRow(rs.getObject("id", UUID.class), rs.getObject("group_id", UUID.class),
                rs.getObject("activity_id", UUID.class), rs.getString("title"), rs.getBigDecimal("total_amount"),
                rs.getString("split_type"), rs.getString("status"), rs.getObject("occurred_at", OffsetDateTime.class),
                rs.getString("note"), rs.getString("receipt_storage_key"), rs.getObject("paid_by", UUID.class), rs.getObject("created_by", UUID.class),
                created.toInstant(), updated.toInstant());
    }

    private ExpenseSummary summary(ExpenseRow row, UserSummary payer, UserSummary creator, int count,
                                   UUID actorId, ReadableGroupAccess access) {
        return new ExpenseSummary(row.id(), row.groupId(), row.title(), row.amount(), row.splitType(), row.status(),
                row.occurredAt(), payer, creator, count, permissions(row, actorId, access));
    }

    private PermissionProjection permissions(ExpenseRow row, UUID actorId, ReadableGroupAccess access) {
        boolean manager = access.membership().getRole() == GroupRole.OWNER || access.membership().getRole() == GroupRole.ADMIN;
        boolean canEdit = access.group().getStatus() == GroupStatus.ACTIVE
                && "ACTIVE".equals(row.status()) && (manager || actorId.equals(row.creatorId()));
        return new PermissionProjection(canEdit, canEdit);
    }

    private UserSummary user(UUID userId) {
        if (userId == null) return null;
        return jdbc.queryForObject("""
                SELECT id,COALESCE(display_name,username::text,'Người dùng') AS name,avatar_storage_key
                FROM users WHERE id=?
                """, (rs, n) -> new UserSummary(rs.getObject("id", UUID.class), rs.getString("name"), rs.getString("avatar_storage_key")), userId);
    }

    private static String displayName(String displayName, String username) {
        return displayName != null ? displayName : username;
    }

    private List<Share> sharesFor(UUID expenseId) {
        return jdbc.query("""
                SELECT s.user_id,s.amount,u.display_name,u.username,u.avatar_storage_key
                FROM expense_shares s JOIN users u ON u.id=s.user_id WHERE s.expense_id=? ORDER BY s.user_id
                """, (rs, n) -> new Share(rs.getObject("user_id", UUID.class), displayName(rs.getString("display_name"), rs.getString("username")),
                rs.getString("avatar_storage_key"), rs.getBigDecimal("amount")), expenseId);
    }

    private void insertShares(UUID expenseId, List<ShareFact> shares) {
        for (ShareFact share : shares) {
            jdbc.update("INSERT INTO expense_shares(id,expense_id,user_id,amount) VALUES (?,?,?,?)",
                    UUID.randomUUID(), expenseId, share.userId(), share.amount());
        }
    }

    private void requireCanModify(ExpenseRow row, UUID actorId) {
        ReadableGroupAccess access = groupPermissions.requireMutableMembership(row.groupId(), actorId);
        boolean permitted = actorId.equals(row.creatorId()) || access.membership().getRole() == GroupRole.OWNER || access.membership().getRole() == GroupRole.ADMIN;
        if (!permitted) throw new BusinessException(ErrorCode.EXPENSE_UPDATE_NOT_ALLOWED);
    }

    private Map<String, String> expenseValues(ExpenseRow row, List<Share> shares) {
        Map<String, String> values = new LinkedHashMap<>();
        values.put("title", row.title()); values.put("amount", row.amount().toPlainString());
        values.put("payerUserId", row.payerId().toString()); values.put("splitMethod", row.splitType());
        values.put("activityId", row.activityId() == null ? null : row.activityId().toString());
        values.put("occurredAt", row.occurredAt().toString()); values.put("note", row.note());
        values.put("receiptStorageKey", row.receiptStorageKey());
        values.put("shares", shares.stream().map(s -> s.userId() + ":" + s.amount().toPlainString()).sorted().toList().toString());
        return values;
    }

    private Map<String, String> draftValues(ExpenseDraft draft) {
        Map<String, String> values = new LinkedHashMap<>();
        values.put("title", draft.title()); values.put("amount", draft.amount().toPlainString());
        values.put("payerUserId", draft.payerId().toString()); values.put("splitMethod", draft.splitMethod());
        values.put("activityId", draft.activityId() == null ? null : draft.activityId().toString());
        values.put("occurredAt", draft.occurredAt().toString()); values.put("note", draft.note());
        values.put("shares", draft.shares().stream().map(s -> s.userId() + ":" + s.amount().toPlainString()).sorted().toList().toString());
        return values;
    }

    private void recordChanges(UUID expenseId, UUID actorId, Map<String, String> before,
                               Map<String, String> after, Instant now) {
        for (String field : before.keySet()) {
            if (!java.util.Objects.equals(before.get(field), after.get(field))) {
                jdbc.update("""
                        INSERT INTO expense_change_logs(id,expense_id,actor_id,field_name,old_value,new_value,created_at)
                        VALUES (?,?,?,?,?,?,?)
                        """, UUID.randomUUID(), expenseId, actorId, field, before.get(field), after.get(field), Timestamp.from(now));
            }
        }
    }

    private List<BalanceSettlement> settlements(UUID groupId, UUID userA, UUID userB, String status) {
        return jdbc.query("""
                SELECT id,amount,status,created_at FROM settlements
                WHERE group_id=? AND status=? AND ((from_user_id=? AND to_user_id=?) OR (from_user_id=? AND to_user_id=?))
                ORDER BY created_at,id
                """, (rs, n) -> new BalanceSettlement(rs.getObject("id", UUID.class), rs.getBigDecimal("amount"),
                rs.getString("status"), rs.getTimestamp("created_at").toInstant()), groupId, status, userA, userB, userB, userA);
    }

    private Ledger loadLedger(UUID groupId, UUID excludedExpenseId, ExpenseDraft proposed) {
        Ledger ledger = new Ledger();
        jdbc.query("""
                SELECT e.id,e.paid_by,s.user_id,s.amount FROM expenses e
                JOIN expense_shares s ON s.expense_id=e.id
                WHERE e.group_id=? AND e.status='ACTIVE'
                """, rs -> {
            UUID expenseId = rs.getObject("id", UUID.class);
            if (expenseId.equals(excludedExpenseId)) return;
            applyObligation(ledger, rs.getObject("user_id", UUID.class), rs.getObject("paid_by", UUID.class), rs.getBigDecimal("amount"));
        }, groupId);
        if (proposed != null) addExpense(ledger, proposed.payerId(), proposed.shares());
        jdbc.query("""
                SELECT from_user_id,to_user_id,amount,status FROM settlements
                WHERE group_id=? AND status IN ('COMPLETED','PENDING')
                """, rs -> {
            UUID from = rs.getObject("from_user_id", UUID.class);
            UUID to = rs.getObject("to_user_id", UUID.class);
            BigDecimal amount = rs.getBigDecimal("amount");
            PairKey key = PairKey.of(from, to);
            if ("COMPLETED".equals(rs.getString("status"))) {
                ledger.net.merge(key, direction(from, to, amount).negate(), BigDecimal::add);
            } else {
                ledger.pending.merge(new DirectedPair(from, to), amount, BigDecimal::add);
            }
        }, groupId);
        return ledger;
    }

    private static void addExpense(Ledger ledger, UUID payerId, List<ShareFact> shares) {
        shares.forEach(share -> applyObligation(ledger, share.userId(), payerId, share.amount()));
    }

    private static void applyObligation(Ledger ledger, UUID debtor, UUID creditor, BigDecimal amount) {
        if (debtor.equals(creditor)) return;
        PairKey pair = PairKey.of(debtor, creditor);
        ledger.net.merge(pair, direction(debtor, creditor, amount), BigDecimal::add);
    }

    private static BigDecimal direction(UUID from, UUID to, BigDecimal amount) {
        PairKey pair = PairKey.of(from, to);
        return pair.first().equals(from) ? amount : amount.negate();
    }

    private void ensurePendingReservations(Ledger ledger, Set<PairKey> affected) {
        for (PairKey pair : affected) {
            BigDecimal net = ledger.net.getOrDefault(pair, ZERO);
            BigDecimal pendingFirstToSecond = ledger.pending.getOrDefault(new DirectedPair(pair.first(), pair.second()), ZERO);
            BigDecimal pendingSecondToFirst = ledger.pending.getOrDefault(new DirectedPair(pair.second(), pair.first()), ZERO);
            BigDecimal availableFirstToSecond = net.max(ZERO);
            BigDecimal availableSecondToFirst = net.negate().max(ZERO);
            if (pendingFirstToSecond.compareTo(availableFirstToSecond) > 0 || pendingSecondToFirst.compareTo(availableSecondToFirst) > 0) {
                throw new BusinessException(ErrorCode.EXPENSE_UPDATE_NOT_ALLOWED);
            }
        }
    }

    private Set<PairKey> affectedPairs(UUID payerId, List<ShareFact> shares) {
        Set<PairKey> result = new HashSet<>();
        for (ShareFact share : shares) if (!share.userId().equals(payerId)) result.add(PairKey.of(share.userId(), payerId));
        return result;
    }

    @Transactional
    public SettlementResponse createSettlement(UUID groupId, UUID actorId, CreateSettlementRequest request) {
        requireMutableGroup(groupId, actorId);
        if (request == null || request.otherUserId() == null || actorId.equals(request.otherUserId())) {
            throw new BusinessException(ErrorCode.EXPENSE_PARTICIPANT_INVALID);
        }
        requireGroupParticipantHistory(groupId, request.otherUserId());
        BigDecimal amount = money(request.amount());
        if (amount.signum() <= 0) {
            throw new BusinessException(ErrorCode.INVALID_EXPENSE_AMOUNT);
        }
        String declarationType = request.declarationType() == null ? "" : request.declarationType().trim();
        UUID fromUserId;
        UUID toUserId;
        if ("I_PAID".equals(declarationType)) {
            fromUserId = actorId;
            toUserId = request.otherUserId();
        } else if ("I_RECEIVED".equals(declarationType)) {
            fromUserId = request.otherUserId();
            toUserId = actorId;
        } else {
            throw new BusinessException(ErrorCode.VALIDATION_FAILED, "Unsupported settlement declaration type.");
        }

        Ledger ledger = loadLedger(groupId, null, null);
        BigDecimal currentDebt = currentDebtBetween(ledger, fromUserId, toUserId);
        if (currentDebt.signum() <= 0) {
            throw new BusinessException(ErrorCode.NO_OUTSTANDING_DEBT);
        }
        BigDecimal pendingReserved = ledger.pending.getOrDefault(new DirectedPair(fromUserId, toUserId), ZERO);
        BigDecimal remainingAvailable = currentDebt.subtract(pendingReserved);
        if (amount.compareTo(currentDebt) > 0 || amount.compareTo(remainingAvailable) > 0) {
            throw new BusinessException(ErrorCode.SETTLEMENT_AMOUNT_EXCEEDS_DEBT);
        }

        UUID settlementId = UUID.randomUUID();
        Instant now = Instant.now();
        jdbc.update("""
                INSERT INTO settlements(id,group_id,from_user_id,to_user_id,amount,status,created_by,
                    declaration_type,completed_at,created_at,updated_at)
                VALUES (?,?,?,?,?,'PENDING',?,?,NULL,?,?)
                """, settlementId, groupId, fromUserId, toUserId, amount, actorId,
                declarationType, Timestamp.from(now), Timestamp.from(now));
        recordSettlementStatusChange(settlementId, null, "PENDING", actorId, now);
        if (eventPublisher != null) {
            UUID counterparty = actorId.equals(fromUserId) ? toUserId : fromUserId;
            eventPublisher.publishEvent(new com.wedo.backend.notification.event.NotificationDomainEvent(
                    "SETTLEMENT_REQUESTED:" + settlementId,
                    "SETTLEMENT_REQUESTED",
                    "FINANCE",
                    "HIGH",
                    false,
                    actorId,
                    groupId,
                    List.of(counterparty),
                    "Yêu cầu xác nhận thanh toán",
                    "Bạn có một yêu cầu xác nhận thanh toán " + amount.toPlainString() + " VND.",
                    "SETTLEMENT",
                    settlementId,
                    "/groups/settlements/detail",
                    Map.of("groupId", groupId.toString(), "settlementId", settlementId.toString()),
                    now
            ));
        }
        return settlementDetail(settlementId, actorId);
    }

    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    public List<SettlementResponse> listSettlements(
            UUID groupId, UUID actorId, String status, Boolean involvingMe, UUID otherUserId
    ) {
        ReadableGroupAccess access = groupPermissions.requireReadableMembership(groupId, actorId);
        StringBuilder sql = new StringBuilder("SELECT * FROM settlements s WHERE s.group_id=?");
        List<Object> args = new ArrayList<>();
        args.add(groupId);
        if (status != null && !status.isBlank()) {
            sql.append(" AND s.status=?");
            args.add(status.trim());
        }
        if (Boolean.TRUE.equals(involvingMe)) {
            sql.append(" AND (s.from_user_id=? OR s.to_user_id=?)");
            args.add(actorId);
            args.add(actorId);
        }
        if (otherUserId != null) {
            sql.append(" AND ((s.from_user_id=? AND s.to_user_id=?) OR (s.from_user_id=? AND s.to_user_id=?))");
            args.add(actorId);
            args.add(otherUserId);
            args.add(otherUserId);
            args.add(actorId);
        }
        sql.append(" ORDER BY s.created_at DESC, s.id");
        List<SettlementRow> rows = jdbc.query(sql.toString(), ExpenseService::mapSettlementRow, args.toArray());
        return rows.stream().map(row -> toSettlementResponse(row, actorId, access)).toList();
    }

    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    public SettlementResponse settlementDetail(UUID settlementId, UUID actorId) {
        SettlementRow row = findSettlement(settlementId, false);
        ReadableGroupAccess access = groupPermissions.requireReadableMembership(row.groupId(), actorId);
        return toSettlementResponse(row, actorId, access);
    }

    @Transactional
    public SettlementResponse confirmSettlement(UUID settlementId, UUID actorId) {
        SettlementRow initial = findSettlement(settlementId, false);
        requireMutableGroup(initial.groupId(), actorId);
        SettlementRow current = findSettlement(settlementId, true);
        if (!"PENDING".equals(current.status())) {
            throw new BusinessException(ErrorCode.SETTLEMENT_ALREADY_RESOLVED);
        }
        if (!actorId.equals(expectedConfirmer(current))) {
            throw new BusinessException(ErrorCode.SETTLEMENT_CONFIRMATION_NOT_ALLOWED);
        }
        Ledger ledger = loadLedger(current.groupId(), null, null);
        BigDecimal currentDebt = currentDebtBetween(ledger, current.fromUserId(), current.toUserId());
        if (currentDebt.signum() <= 0) {
            throw new BusinessException(ErrorCode.NO_OUTSTANDING_DEBT);
        }
        if (current.amount().compareTo(currentDebt) > 0) {
            throw new BusinessException(ErrorCode.SETTLEMENT_AMOUNT_EXCEEDS_DEBT);
        }
        Instant now = Instant.now();
        jdbc.update("UPDATE settlements SET status='COMPLETED', completed_at=?, updated_at=? WHERE id=?",
                Timestamp.from(now), Timestamp.from(now), settlementId);
        recordSettlementStatusChange(settlementId, "PENDING", "COMPLETED", actorId, now);
        if (eventPublisher != null) {
            UUID notifyRecipient = actorId.equals(current.fromUserId()) ? current.toUserId() : current.fromUserId();
            eventPublisher.publishEvent(new com.wedo.backend.notification.event.NotificationDomainEvent(
                    "SETTLEMENT_CONFIRMED:" + settlementId,
                    "SETTLEMENT_CONFIRMED",
                    "FINANCE",
                    "HIGH",
                    true,
                    actorId,
                    current.groupId(),
                    List.of(notifyRecipient),
                    "Xác nhận thanh toán hoàn tất",
                    "Khoản thanh toán " + current.amount().toPlainString() + " VND đã được xác nhận.",
                    "SETTLEMENT",
                    settlementId,
                    "/groups/settlements/detail",
                    Map.of("groupId", current.groupId().toString(), "settlementId", settlementId.toString()),
                    now
            ));
        }
        return settlementDetail(settlementId, actorId);
    }

    @Transactional
    public SettlementResponse rejectSettlement(UUID settlementId, UUID actorId) {
        SettlementRow initial = findSettlement(settlementId, false);
        requireMutableGroup(initial.groupId(), actorId);
        SettlementRow current = findSettlement(settlementId, true);
        if (!"PENDING".equals(current.status())) {
            throw new BusinessException(ErrorCode.SETTLEMENT_ALREADY_RESOLVED);
        }
        if (!actorId.equals(expectedConfirmer(current))) {
            throw new BusinessException(ErrorCode.SETTLEMENT_CONFIRMATION_NOT_ALLOWED);
        }
        Instant now = Instant.now();
        jdbc.update("UPDATE settlements SET status='REJECTED', updated_at=? WHERE id=?",
                Timestamp.from(now), settlementId);
        recordSettlementStatusChange(settlementId, "PENDING", "REJECTED", actorId, now);
        return settlementDetail(settlementId, actorId);
    }

    @Transactional
    public SettlementResponse cancelSettlement(UUID settlementId, UUID actorId) {
        SettlementRow initial = findSettlement(settlementId, false);
        requireMutableGroup(initial.groupId(), actorId);
        SettlementRow current = findSettlement(settlementId, true);
        if (!"PENDING".equals(current.status())) {
            throw new BusinessException(ErrorCode.SETTLEMENT_ALREADY_RESOLVED);
        }
        if (!actorId.equals(current.createdBy())) {
            throw new BusinessException(ErrorCode.SETTLEMENT_CONFIRMATION_NOT_ALLOWED);
        }
        Instant now = Instant.now();
        jdbc.update("UPDATE settlements SET status='CANCELLED', updated_at=? WHERE id=?",
                Timestamp.from(now), settlementId);
        recordSettlementStatusChange(settlementId, "PENDING", "CANCELLED", actorId, now);
        return settlementDetail(settlementId, actorId);
    }

    private BigDecimal currentDebtBetween(Ledger ledger, UUID debtor, UUID creditor) {
        PairKey pair = PairKey.of(debtor, creditor);
        BigDecimal canonical = ledger.net.getOrDefault(pair, ZERO);
        BigDecimal signedDebt = pair.first().equals(debtor) ? canonical : canonical.negate();
        return signedDebt.max(ZERO).setScale(2, RoundingMode.UNNECESSARY);
    }

    private void requireGroupParticipantHistory(UUID groupId, UUID userId) {
        Integer count = jdbc.queryForObject("""
                SELECT count(*) FROM group_memberships m JOIN users u ON u.id=m.user_id
                WHERE m.group_id=? AND m.user_id=?
                """, Integer.class, groupId, userId);
        if (count == null || count < 1) {
            throw new BusinessException(ErrorCode.EXPENSE_PARTICIPANT_INVALID);
        }
    }

    private static UUID expectedConfirmer(SettlementRow row) {
        return "I_PAID".equals(row.declarationType()) ? row.toUserId() : row.fromUserId();
    }

    private SettlementRow findSettlement(UUID settlementId, boolean forUpdate) {
        String sql = "SELECT * FROM settlements WHERE id=?" + (forUpdate ? " FOR UPDATE" : "");
        try {
            return jdbc.queryForObject(sql, ExpenseService::mapSettlementRow, settlementId);
        } catch (EmptyResultDataAccessException ex) {
            throw new BusinessException(ErrorCode.SETTLEMENT_NOT_FOUND);
        }
    }

    private static SettlementRow mapSettlementRow(ResultSet rs, int rowNum) throws SQLException {
        Timestamp completed = rs.getTimestamp("completed_at");
        Timestamp created = rs.getTimestamp("created_at");
        Timestamp updated = rs.getTimestamp("updated_at");
        return new SettlementRow(
                rs.getObject("id", UUID.class),
                rs.getObject("group_id", UUID.class),
                rs.getObject("from_user_id", UUID.class),
                rs.getObject("to_user_id", UUID.class),
                rs.getObject("created_by", UUID.class),
                rs.getBigDecimal("amount"),
                rs.getString("status"),
                rs.getString("declaration_type"),
                completed == null ? null : completed.toInstant(),
                created.toInstant(),
                updated.toInstant()
        );
    }

    private void recordSettlementStatusChange(
            UUID settlementId, String fromStatus, String toStatus, UUID actorId, Instant now
    ) {
        jdbc.update("""
                INSERT INTO settlement_status_history(id,settlement_id,from_status,to_status,changed_by,created_at)
                VALUES (?,?,?,?,?,?)
                """, UUID.randomUUID(), settlementId, fromStatus, toStatus, actorId, Timestamp.from(now));
    }

    private SettlementResponse toSettlementResponse(
            SettlementRow row, UUID actorId, ReadableGroupAccess access
    ) {
        List<SettlementStatusChange> history = jdbc.query("""
                SELECT h.from_status,h.to_status,h.changed_by,h.created_at,
                       COALESCE(u.display_name,u.username::text,'Người dùng') AS actor_name,
                       u.avatar_storage_key AS actor_avatar
                FROM settlement_status_history h
                LEFT JOIN users u ON u.id=h.changed_by
                WHERE h.settlement_id=?
                ORDER BY h.created_at ASC, h.id ASC
                """, (rs, n) -> {
            UUID changedBy = rs.getObject("changed_by", UUID.class);
            UserSummary actor = changedBy == null
                    ? null
                    : new UserSummary(changedBy, rs.getString("actor_name"), rs.getString("actor_avatar"));
            return new SettlementStatusChange(
                    rs.getString("from_status"),
                    rs.getString("to_status"),
                    actor,
                    rs.getTimestamp("created_at").toInstant()
            );
        }, row.id());

        boolean mutable = access.group().getStatus() == GroupStatus.ACTIVE && "PENDING".equals(row.status());
        UUID confirmerId = expectedConfirmer(row);
        SettlementPermissionProjection permissions = new SettlementPermissionProjection(
                mutable && actorId.equals(confirmerId),
                mutable && actorId.equals(confirmerId),
                mutable && actorId.equals(row.createdBy())
        );

        return new SettlementResponse(
                row.id(),
                row.groupId(),
                user(row.fromUserId()),
                user(row.toUserId()),
                user(row.createdBy()),
                row.amount().setScale(2, RoundingMode.UNNECESSARY),
                row.status(),
                row.declarationType(),
                row.completedAt(),
                row.createdAt(),
                row.updatedAt(),
                history,
                permissions
        );
    }

    private record ExpenseRow(UUID id, UUID groupId, UUID activityId, String title, BigDecimal amount,
                              String splitType, String status, OffsetDateTime occurredAt, String note, String receiptStorageKey,
                              UUID payerId, UUID creatorId, Instant createdAt, Instant updatedAt) { }
    private record SettlementRow(UUID id, UUID groupId, UUID fromUserId, UUID toUserId, UUID createdBy,
                                 BigDecimal amount, String status, String declarationType,
                                 Instant completedAt, Instant createdAt, Instant updatedAt) { }
    private record ShareFact(UUID userId, BigDecimal amount) { }
    private record ExpenseDraft(String title, BigDecimal amount, UUID payerId, String splitMethod,
                                List<ShareFact> shares, UUID activityId, OffsetDateTime occurredAt, String note) { }
    private record DirectedPair(UUID from, UUID to) { }
    private record PairKey(UUID first, UUID second) {
        static PairKey of(UUID a, UUID b) {
            return a.toString().compareTo(b.toString()) <= 0 ? new PairKey(a, b) : new PairKey(b, a);
        }
    }
    private static final class Ledger {
        private final Map<PairKey, BigDecimal> net = new HashMap<>();
        private final Map<DirectedPair, BigDecimal> pending = new HashMap<>();
    }
}
