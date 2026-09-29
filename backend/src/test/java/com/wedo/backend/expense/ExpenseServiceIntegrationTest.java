package com.wedo.backend.expense;

import static org.junit.jupiter.api.Assertions.*;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.expense.dto.ExpenseDtos.ExpenseDetail;
import com.wedo.backend.expense.dto.ExpenseDtos.ExpenseRequest;
import com.wedo.backend.expense.dto.ExpenseDtos.CreateSettlementRequest;
import com.wedo.backend.expense.dto.ExpenseDtos.ShareRequest;
import com.wedo.backend.expense.service.ExpenseService;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupSettingsEntity;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.group.repository.GroupSettingsRepository;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.sql.Timestamp;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

class ExpenseServiceIntegrationTest extends AbstractPostgresIntegrationTest {
    @Autowired ExpenseService expenses;
    @Autowired UserRepository users;
    @Autowired GroupRepository groups;
    @Autowired GroupMembershipRepository memberships;
    @Autowired GroupSettingsRepository settings;
    @Autowired JdbcTemplate jdbc;

    @Test
    void equalSplitDistributesRemainderToPayerAndDerivesNoSelfDebt() {
        Fixture f = fixture();
        ExpenseDetail expense = expenses.create(f.groupId(), f.owner(), request("EQUAL", "1.00", f.owner(),
                List.of(f.owner(), f.member(), f.third()), null));

        assertEquals("ACTIVE", expense.status());
        assertEquals(new BigDecimal("1.00"), expense.amount());
        assertEquals(new BigDecimal("0.34"), share(expense, f.owner()));
        assertEquals(new BigDecimal("0.33"), share(expense, f.member()));
        assertEquals(new BigDecimal("0.33"), share(expense, f.third()));
        assertEquals(new BigDecimal("0.66"), expenses.myBalances(f.groupId(), f.owner()).totalOwedToMe());
        assertEquals(new BigDecimal("0.33"), expenses.myBalances(f.groupId(), f.member()).totalOwedByMe());
        assertEquals(new BigDecimal("0.00"), expenses.myBalances(f.groupId(), f.owner()).totalOwedByMe());
    }

    @Test
    void customSplitAndPayerOutsideParticipantSetAreSupported() {
        Fixture f = fixture();
        ExpenseRequest request = new ExpenseRequest("Dinner", new BigDecimal("12.50"), f.owner(), "CUSTOM_AMOUNT",
                null, List.of(new ShareRequest(f.member(), new BigDecimal("7.25")),
                new ShareRequest(f.third(), new BigDecimal("5.25"))), null, OffsetDateTime.now(), null);
        ExpenseDetail expense = expenses.create(f.groupId(), f.owner(), request);
        assertEquals(new BigDecimal("12.50"), expense.shares().stream().map(s -> s.amount()).reduce(BigDecimal.ZERO, BigDecimal::add));
        assertEquals(new BigDecimal("12.50"), expenses.myBalances(f.groupId(), f.owner()).totalOwedToMe());
    }

    @Test
    void rejectsDuplicateInvalidAndMismatchedAllocationsWithoutPartialRows() {
        Fixture f = fixture();
        assertEquals(ErrorCode.EXPENSE_PARTICIPANT_INVALID, assertThrows(BusinessException.class,
                () -> expenses.create(f.groupId(), f.owner(), request("EQUAL", "10.00", f.owner(),
                        List.of(f.member(), f.member()), null))).errorCode());
        ExpenseRequest mismatch = new ExpenseRequest("Dinner", new BigDecimal("10.00"), f.owner(), "CUSTOM_AMOUNT",
                null, List.of(new ShareRequest(f.member(), new BigDecimal("9.00"))), null, OffsetDateTime.now(), null);
        assertEquals(ErrorCode.EXPENSE_SPLIT_TOTAL_MISMATCH, assertThrows(BusinessException.class,
                () -> expenses.create(f.groupId(), f.owner(), mismatch)).errorCode());
        ExpenseRequest badAmount = request("EQUAL", "0.00", f.owner(), List.of(f.member()), null);
        assertEquals(ErrorCode.INVALID_EXPENSE_AMOUNT, assertThrows(BusinessException.class,
                () -> expenses.create(f.groupId(), f.owner(), badAmount)).errorCode());
        assertEquals(0, jdbc.queryForObject("SELECT count(*) FROM expenses WHERE group_id=?", Integer.class, f.groupId()));
    }

    @Test
    void deniesOutsiderAndArchivedGroupMutationWhileKeepingArchivedHistoryReadable() {
        Fixture f = fixture();
        ExpenseDetail expense = expenses.create(f.groupId(), f.owner(), request("EQUAL", "5.00", f.owner(), List.of(f.member()), null));
        assertEquals(ErrorCode.GROUP_NOT_FOUND, assertThrows(BusinessException.class,
                () -> expenses.list(f.groupId(), f.outsider(), null, null, null, null, null)).errorCode());
        f.group().archive(Instant.now());
        groups.save(f.group());
        assertEquals(1, expenses.list(f.groupId(), f.member(), null, null, null, null, null).size());
        assertFalse(expenses.list(f.groupId(), f.owner(), null, null, null, null, null).getFirst().permissions().canEdit());
        assertFalse(expenses.detail(expense.id(), f.owner()).permissions().canCancel());
        assertThrows(BusinessException.class, () -> expenses.cancel(expense.id(), f.owner()));
    }

    @Test
    void ownerCanEditAndCancelAtomicallyAndHistoryRemains() {
        Fixture f = fixture();
        ExpenseDetail expense = expenses.create(f.groupId(), f.owner(), request("EQUAL", "10.00", f.owner(), List.of(f.member()), null));
        ExpenseDetail changed = expenses.update(expense.id(), f.owner(), request("EQUAL", "16.00", f.owner(), List.of(f.member()), null));
        assertEquals(new BigDecimal("16.00"), changed.amount());
        assertEquals(new BigDecimal("16.00"), expenses.myBalances(f.groupId(), f.owner()).totalOwedToMe());
        assertFalse(changed.changeHistory().isEmpty());
        ExpenseDetail cancelled = expenses.cancel(expense.id(), f.owner());
        assertEquals("CANCELLED", cancelled.status());
        assertEquals(new BigDecimal("0.00"), expenses.myBalances(f.groupId(), f.owner()).totalOwedToMe());
        assertEquals(1, expenses.list(f.groupId(), f.owner(), null, null, null, null, null).size());
        assertEquals(1, jdbc.queryForObject("SELECT count(*) FROM expenses WHERE id=?", Integer.class, expense.id()));
    }

    @Test
    void completedSettlementReducesDerivedDebtAndFormerMemberDebtPersists() {
        Fixture f = fixture();
        expenses.create(f.groupId(), f.owner(), request("EQUAL", "20.00", f.owner(), List.of(f.member()), null));
        Instant now = Instant.now();
        jdbc.update("""
                INSERT INTO settlements(id,group_id,from_user_id,to_user_id,amount,status,created_by,declaration_type,completed_at,created_at,updated_at)
                VALUES (?,?,?,?,?,'COMPLETED',?,'I_PAID',?,?,?)
                """, UUID.randomUUID(), f.groupId(), f.member(), f.owner(), new BigDecimal("4.00"), f.member(),
                Timestamp.from(now), Timestamp.from(now), Timestamp.from(now));
        assertEquals(new BigDecimal("16.00"), expenses.myBalances(f.groupId(), f.owner()).totalOwedToMe());
        var membership = memberships.findFirstByGroupIdAndUserIdAndStatus(f.groupId(), f.member(), GroupMembershipStatus.ACTIVE).orElseThrow();
        membership.endAsLeft(Instant.now());
        memberships.save(membership);
        assertEquals(new BigDecimal("16.00"), expenses.myBalances(f.groupId(), f.owner()).totalOwedToMe());
    }

    @Test
    void settlementRequestAndConfirmationPersistOneCorrectRecipientNotificationEach() {
        Fixture f = fixture();
        expenses.create(f.groupId(), f.owner(), request("EQUAL", "20.00", f.owner(), List.of(f.owner(), f.member()), null));

        var request = expenses.createSettlement(f.groupId(), f.member(),
                new CreateSettlementRequest(f.owner(), new BigDecimal("5.00"), "I_PAID"));
        assertNotification(f.owner(), "SETTLEMENT_REQUESTED", request.id(), false);
        assertNotificationCount(f.member(), "SETTLEMENT_REQUESTED", request.id(), 0);

        expenses.confirmSettlement(request.id(), f.owner());
        assertNotification(f.member(), "SETTLEMENT_CONFIRMED", request.id(), true);
        assertNotificationCount(f.owner(), "SETTLEMENT_CONFIRMED", request.id(), 0);
    }

    @Test
    void editCannotConsumePendingSettlementReservation() {
        Fixture f = fixture();
        ExpenseDetail expense = expenses.create(f.groupId(), f.owner(), request("EQUAL", "10.00", f.owner(), List.of(f.member()), null));
        Instant now = Instant.now();
        jdbc.update("""
                INSERT INTO settlements(id,group_id,from_user_id,to_user_id,amount,status,created_by,declaration_type,created_at,updated_at)
                VALUES (?,?,?,?,?,'PENDING',?,'I_PAID',?,?)
                """, UUID.randomUUID(), f.groupId(), f.member(), f.owner(), new BigDecimal("8.00"), f.member(),
                Timestamp.from(now), Timestamp.from(now));
        assertEquals(ErrorCode.EXPENSE_UPDATE_NOT_ALLOWED, assertThrows(BusinessException.class,
                () -> expenses.update(expense.id(), f.owner(), request("EQUAL", "5.00", f.owner(), List.of(f.member()), null))).errorCode());
        assertEquals(new BigDecimal("10.00"), expenses.detail(expense.id(), f.owner()).amount());
    }

    @Test
    void ownerAndCreatorPermissionsAreProjectedFromServer() {
        Fixture f = fixture();
        ExpenseDetail expense = expenses.create(f.groupId(), f.owner(), request("EQUAL", "5.00", f.owner(), List.of(f.member()), null));
        assertTrue(expense.permissions().canEdit());
        var memberRow = expenses.list(f.groupId(), f.member(), null, null, null, null, null).getFirst();
        assertFalse(memberRow.permissions().canEdit());
        assertEquals(ErrorCode.EXPENSE_UPDATE_NOT_ALLOWED, assertThrows(BusinessException.class,
                () -> expenses.cancel(expense.id(), f.member())).errorCode());
    }

    @Test
    void eligibleMemberSeesExpenseAndBothAccountsAgreeOnPairBalanceWhileOutsiderIsDenied() {
        Fixture f = fixture();
        ExpenseDetail expense = expenses.create(f.groupId(), f.member(), request("EQUAL", "10.00", f.member(), List.of(f.owner()), null));

        var peerView = expenses.list(f.groupId(), f.third(), null, null, null, null, null).getFirst();
        assertEquals(expense.id(), peerView.id());
        assertFalse(peerView.permissions().canEdit());
        assertTrue(expenses.detail(expense.id(), f.member()).permissions().canCancel());
        assertTrue(expenses.detail(expense.id(), f.owner()).permissions().canEdit());
        assertEquals(new BigDecimal("10.00"), expenses.myBalances(f.groupId(), f.member()).totalOwedToMe());
        assertEquals(new BigDecimal("10.00"), expenses.myBalances(f.groupId(), f.owner()).totalOwedByMe());

        var memberPair = expenses.pairBalance(f.groupId(), f.member(), f.owner());
        var ownerPair = expenses.pairBalance(f.groupId(), f.owner(), f.member());
        assertEquals(ownerPair.netAmount(), memberPair.netAmount().negate());
        assertEquals("YOU_OWE", ownerPair.direction());
        assertEquals("OWES_YOU", memberPair.direction());

        assertEquals(ErrorCode.GROUP_NOT_FOUND, assertThrows(BusinessException.class,
                () -> expenses.detail(expense.id(), f.outsider())).errorCode());
    }

    @Test
    void rejectsInactivePayersParticipantsAndFormerMemberAccessWithoutErasingHistory() {
        Fixture f = fixture();
        ExpenseDetail expense = expenses.create(f.groupId(), f.member(), request("EQUAL", "10.00", f.member(), List.of(f.owner()), null));
        assertThrows(BusinessException.class, () -> expenses.create(f.groupId(), f.outsider(),
                request("EQUAL", "10.00", f.owner(), List.of(f.member()), null)));
        assertThrows(BusinessException.class, () -> expenses.update(expense.id(), f.third(),
                request("EQUAL", "11.00", f.member(), List.of(f.owner()), null)));
        var membership = memberships.findFirstByGroupIdAndUserIdAndStatus(f.groupId(), f.member(), GroupMembershipStatus.ACTIVE).orElseThrow();
        membership.endAsBanned(Instant.now());
        memberships.save(membership);
        assertThrows(BusinessException.class, () -> expenses.detail(expense.id(), f.member()));
        assertThrows(BusinessException.class, () -> expenses.cancel(expense.id(), f.member()));
        assertThrows(BusinessException.class, () -> expenses.create(f.groupId(), f.owner(),
                request("EQUAL", "10.00", f.member(), List.of(f.owner()), null)));
        assertThrows(BusinessException.class, () -> expenses.create(f.groupId(), f.owner(),
                request("EQUAL", "10.00", f.owner(), List.of(f.member()), null)));
        assertEquals(new BigDecimal("10.00"), expenses.myBalances(f.groupId(), f.owner()).totalOwedByMe());
        assertEquals(expense.id(), expenses.detail(expense.id(), f.owner()).id());
    }

    @Test
    void multipleExpensesNetAndEditingParticipantsReplacesOldAllocation() {
        Fixture f = fixture();
        ExpenseDetail first = expenses.create(f.groupId(), f.member(), request("EQUAL", "10.00", f.owner(), List.of(f.member()), null));
        expenses.create(f.groupId(), f.third(), request("EQUAL", "3.00", f.member(), List.of(f.owner()), null));
        assertEquals(new BigDecimal("7.00"), expenses.myBalances(f.groupId(), f.owner()).totalOwedToMe());
        var admin = memberships.findFirstByGroupIdAndUserIdAndStatus(f.groupId(), f.third(), GroupMembershipStatus.ACTIVE).orElseThrow();
        admin.promoteToAdmin();
        memberships.save(admin);
        assertTrue(expenses.detail(first.id(), f.third()).permissions().canEdit());
        expenses.update(first.id(), f.third(), request("EQUAL", "8.00", f.owner(), List.of(f.third()), null));
        assertEquals(new BigDecimal("3.00"), expenses.myBalances(f.groupId(), f.member()).totalOwedToMe());
        assertEquals(new BigDecimal("0.00"), expenses.myBalances(f.groupId(), f.member()).totalOwedByMe());
        assertEquals(new BigDecimal("8.00"), expenses.myBalances(f.groupId(), f.third()).totalOwedByMe());
    }

    @Test
    void moneyRoundTripsAtSchemaPrecisionAsJsonStringsAndRejectsExcessPrecision() {
        Fixture f = fixture();
        ExpenseDetail expense = expenses.create(f.groupId(), f.owner(), request("EQUAL", "99999999999999999.99", f.owner(), List.of(f.member()), null));
        var mapper = tools.jackson.databind.json.JsonMapper.builder().build();
        var json = mapper.readTree(mapper.writeValueAsString(expense));
        assertTrue(json.get("amount").isString());
        assertEquals("99999999999999999.99", json.get("amount").asString());
        assertEquals("99999999999999999.99", json.get("shares").get(0).get("amount").asString());
        var balances = mapper.readTree(mapper.writeValueAsString(expenses.myBalances(f.groupId(), f.member())));
        assertEquals("99999999999999999.99", balances.get("totalOwedByMe").asString());
        for (String invalid : List.of("-1.00", "0.001", "100000000000000000.00")) {
            assertThrows(BusinessException.class, () -> expenses.create(f.groupId(), f.owner(),
                    request("EQUAL", invalid, f.owner(), List.of(f.member()), null)));
        }
    }

    @Test
    void concurrentEditAndCancelLeaveCompleteCancelledExpenseAndZeroDebt() throws Exception {
        Fixture f = fixture();
        ExpenseDetail expense = expenses.create(f.groupId(), f.owner(), request("EQUAL", "10.00", f.owner(), List.of(f.member()), null));
        CountDownLatch start = new CountDownLatch(1);
        try (var executor = Executors.newFixedThreadPool(2)) {
            var edit = executor.submit(() -> {
                start.await();
                try {
                    expenses.update(expense.id(), f.owner(), request("EQUAL", "12.00", f.owner(), List.of(f.member(), f.third()), null));
                } catch (BusinessException ex) {
                    assertEquals(ErrorCode.EXPENSE_UPDATE_NOT_ALLOWED, ex.errorCode());
                }
                return null;
            });
            var cancel = executor.submit(() -> {
                start.await();
                return expenses.cancel(expense.id(), f.owner());
            });
            start.countDown();
            edit.get(20, TimeUnit.SECONDS);
            cancel.get(20, TimeUnit.SECONDS);
        }
        ExpenseDetail finalExpense = expenses.detail(expense.id(), f.owner());
        assertEquals("CANCELLED", finalExpense.status());
        assertEquals(finalExpense.amount(), finalExpense.shares().stream().map(s -> s.amount()).reduce(new BigDecimal("0.00"), BigDecimal::add));
        assertEquals(new BigDecimal("0.00"), expenses.myBalances(f.groupId(), f.owner()).totalOwedToMe());
    }

    private BigDecimal share(ExpenseDetail detail, UUID userId) {
        return detail.shares().stream().filter(s -> s.userId().equals(userId)).findFirst().orElseThrow().amount();
    }

    private void assertNotification(UUID recipient, String eventType, UUID targetId, boolean critical) {
        assertEquals(1, jdbc.queryForObject("""
                SELECT count(*) FROM notifications
                WHERE user_id = ? AND category = 'FINANCE' AND priority = 'HIGH'
                  AND data->>'eventType' = ? AND data->>'targetType' = 'SETTLEMENT'
                  AND data->>'targetId' = ? AND data->>'critical' = ?
                """, Integer.class, recipient, eventType, targetId.toString(), Boolean.toString(critical)));
    }

    private void assertNotificationCount(UUID recipient, String eventType, UUID targetId, int expected) {
        assertEquals(expected, jdbc.queryForObject("""
                SELECT count(*) FROM notifications
                WHERE user_id = ? AND data->>'eventType' = ? AND data->>'targetId' = ?
                """, Integer.class, recipient, eventType, targetId.toString()));
    }

    private ExpenseRequest request(String split, String amount, UUID payer, List<UUID> participants, List<ShareRequest> shares) {
        return new ExpenseRequest("Shared meal", new BigDecimal(amount), payer, split,
                "EQUAL".equals(split) ? participants : null, shares, null, OffsetDateTime.now(), "QA expense");
    }

    private Fixture fixture() {
        UUID owner = UUID.randomUUID(), member = UUID.randomUUID(), third = UUID.randomUUID(), outsider = UUID.randomUUID();
        Instant now = Instant.now();
        saveUser(owner, "OWNER", now); saveUser(member, "MEMBER", now); saveUser(third, "THIRD", now); saveUser(outsider, "OUTSIDER", now);
        UUID groupId = UUID.randomUUID();
        GroupEntity group = groups.save(new GroupEntity(groupId, "Expense test", null, null, GroupStatus.ACTIVE, owner, now, now));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, owner, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, now, null));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, member, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, now, null));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, third, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, now, null));
        settings.save(GroupSettingsEntity.createDefault(groupId, now));
        return new Fixture(groupId, owner, member, third, outsider, group);
    }

    private void saveUser(UUID id, String label, Instant now) {
        String suffix = id.toString().substring(0, 8);
        users.save(new UserEntity(id, label.toLowerCase() + "+" + suffix + "@expense.test", label.toLowerCase() + suffix,
                label, UserStatus.ACTIVE, now, now));
    }

    private record Fixture(UUID groupId, UUID owner, UUID member, UUID third, UUID outsider, GroupEntity group) { }
}
