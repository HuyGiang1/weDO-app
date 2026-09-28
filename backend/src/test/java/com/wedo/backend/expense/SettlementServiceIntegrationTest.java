package com.wedo.backend.expense;

import static org.junit.jupiter.api.Assertions.*;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.expense.dto.ExpenseDtos.CreateSettlementRequest;
import com.wedo.backend.expense.dto.ExpenseDtos.ExpenseRequest;
import com.wedo.backend.expense.dto.ExpenseDtos.PairBalance;
import com.wedo.backend.expense.dto.ExpenseDtos.SettlementResponse;
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
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

class SettlementServiceIntegrationTest extends AbstractPostgresIntegrationTest {
    @Autowired ExpenseService expenses;
    @Autowired UserRepository users;
    @Autowired GroupRepository groups;
    @Autowired GroupMembershipRepository memberships;
    @Autowired GroupSettingsRepository settings;

    @Test
    void partialAndFullRepaymentTwoSidedConfirmationUpdatesBalancesAndHistory() {
        Fixture f = fixture();
        // Owner pays 100.00 for Member -> Member owes Owner 100.00
        expenses.create(f.groupId(), f.owner(), expenseRequest("100.00", f.owner(), List.of(f.member())));

        // 1. Member declares I_PAID 40.00 to Owner (PENDING)
        SettlementResponse s1 = expenses.createSettlement(
                f.groupId(),
                f.member(),
                new CreateSettlementRequest(f.owner(), new BigDecimal("40.00"), "I_PAID")
        );
        assertEquals("PENDING", s1.status());
        assertEquals(f.member(), s1.fromUser().id());
        assertEquals(f.owner(), s1.toUser().id());
        assertEquals(new BigDecimal("40.00"), s1.amount());
        assertTrue(s1.permissions().canCancel());
        assertFalse(s1.permissions().canConfirm());

        // Pending settlement does not reduce completed debt yet
        assertEquals(new BigDecimal("100.00"), expenses.myBalances(f.groupId(), f.member()).totalOwedByMe());
        assertEquals(new BigDecimal("100.00"), expenses.myBalances(f.groupId(), f.owner()).totalOwedToMe());

        // Creator cannot confirm own I_PAID declaration; third member cannot confirm
        assertEquals(ErrorCode.SETTLEMENT_CONFIRMATION_NOT_ALLOWED, assertThrows(BusinessException.class,
                () -> expenses.confirmSettlement(s1.id(), f.member())).errorCode());
        assertEquals(ErrorCode.SETTLEMENT_CONFIRMATION_NOT_ALLOWED, assertThrows(BusinessException.class,
                () -> expenses.confirmSettlement(s1.id(), f.third())).errorCode());

        // Owner views s1 -> canConfirm and canReject are true, canCancel is false
        SettlementResponse ownerView = expenses.settlementDetail(s1.id(), f.owner());
        assertTrue(ownerView.permissions().canConfirm());
        assertTrue(ownerView.permissions().canReject());
        assertFalse(ownerView.permissions().canCancel());

        // 2. Owner confirms s1 -> COMPLETED, debt becomes 60.00
        SettlementResponse confirmed1 = expenses.confirmSettlement(s1.id(), f.owner());
        assertEquals("COMPLETED", confirmed1.status());
        assertNotNull(confirmed1.completedAt());
        assertEquals(2, confirmed1.statusHistory().size());
        assertEquals("COMPLETED", confirmed1.statusHistory().getLast().toStatus());

        assertEquals(new BigDecimal("60.00"), expenses.myBalances(f.groupId(), f.member()).totalOwedByMe());
        assertEquals(new BigDecimal("60.00"), expenses.myBalances(f.groupId(), f.owner()).totalOwedToMe());

        // 3. Owner declares I_RECEIVED for remaining 60.00 -> Member confirms -> debt becomes 0.00 (SETTLED)
        SettlementResponse s2 = expenses.createSettlement(
                f.groupId(),
                f.owner(),
                new CreateSettlementRequest(f.member(), new BigDecimal("60.00"), "I_RECEIVED")
        );
        assertEquals("PENDING", s2.status());
        assertEquals(f.member(), s2.fromUser().id());
        assertEquals(f.owner(), s2.toUser().id());
        assertEquals("I_RECEIVED", s2.declarationType());

        // Owner cannot confirm own I_RECEIVED; Member confirms
        assertEquals(ErrorCode.SETTLEMENT_CONFIRMATION_NOT_ALLOWED, assertThrows(BusinessException.class,
                () -> expenses.confirmSettlement(s2.id(), f.owner())).errorCode());

        SettlementResponse confirmed2 = expenses.confirmSettlement(s2.id(), f.member());
        assertEquals("COMPLETED", confirmed2.status());
        assertEquals(new BigDecimal("0.00"), expenses.myBalances(f.groupId(), f.member()).totalOwedByMe());
        assertEquals(new BigDecimal("0.00"), expenses.myBalances(f.groupId(), f.owner()).totalOwedToMe());

        PairBalance pair = expenses.pairBalance(f.groupId(), f.member(), f.owner());
        assertEquals("SETTLED", pair.direction());
        assertEquals(new BigDecimal("0.00"), pair.netAmount());
        assertEquals(2, pair.settlements().size());
    }

    @Test
    void rejectsWrongDirectionZeroDebtAndOverSettlementIncludingPendingReservations() {
        Fixture f = fixture();
        expenses.create(f.groupId(), f.owner(), expenseRequest("50.00", f.owner(), List.of(f.member())));

        // Owner does not owe Member -> Owner declaring I_PAID to Member must fail with NO_OUTSTANDING_DEBT
        assertEquals(ErrorCode.NO_OUTSTANDING_DEBT, assertThrows(BusinessException.class,
                () -> expenses.createSettlement(
                        f.groupId(),
                        f.owner(),
                        new CreateSettlementRequest(f.member(), new BigDecimal("10.00"), "I_PAID")
                )).errorCode());

        // Member declaring I_RECEIVED from Owner must also fail with NO_OUTSTANDING_DEBT
        assertEquals(ErrorCode.NO_OUTSTANDING_DEBT, assertThrows(BusinessException.class,
                () -> expenses.createSettlement(
                        f.groupId(),
                        f.member(),
                        new CreateSettlementRequest(f.owner(), new BigDecimal("10.00"), "I_RECEIVED")
                )).errorCode());

        // Over-settlement (> 50.00) rejected
        assertEquals(ErrorCode.SETTLEMENT_AMOUNT_EXCEEDS_DEBT, assertThrows(BusinessException.class,
                () -> expenses.createSettlement(
                        f.groupId(),
                        f.member(),
                        new CreateSettlementRequest(f.owner(), new BigDecimal("50.01"), "I_PAID")
                )).errorCode());

        // Pending 30.00 reserves 30.00 -> a second pending 25.00 exceeds remaining 20.00
        SettlementResponse pending30 = expenses.createSettlement(
                f.groupId(),
                f.member(),
                new CreateSettlementRequest(f.owner(), new BigDecimal("30.00"), "I_PAID")
        );
        assertEquals(ErrorCode.SETTLEMENT_AMOUNT_EXCEEDS_DEBT, assertThrows(BusinessException.class,
                () -> expenses.createSettlement(
                        f.groupId(),
                        f.member(),
                        new CreateSettlementRequest(f.owner(), new BigDecimal("25.00"), "I_PAID")
                )).errorCode());

        // Creator cancels pending30 -> reservation released, 50.00 is available again
        SettlementResponse cancelled = expenses.cancelSettlement(pending30.id(), f.member());
        assertEquals("CANCELLED", cancelled.status());

        // Counterparty rejects a pending settlement -> reservation released
        SettlementResponse pending40 = expenses.createSettlement(
                f.groupId(),
                f.member(),
                new CreateSettlementRequest(f.owner(), new BigDecimal("40.00"), "I_PAID")
        );
        SettlementResponse rejected = expenses.rejectSettlement(pending40.id(), f.owner());
        assertEquals("REJECTED", rejected.status());
        assertEquals(ErrorCode.SETTLEMENT_ALREADY_RESOLVED, assertThrows(BusinessException.class,
                () -> expenses.confirmSettlement(pending40.id(), f.owner())).errorCode());
    }

    @Test
    void enforcesOutsiderCrossGroupAndArchivedGroupRestrictions() {
        Fixture f = fixture();
        expenses.create(f.groupId(), f.owner(), expenseRequest("30.00", f.owner(), List.of(f.member())));
        SettlementResponse pending = expenses.createSettlement(
                f.groupId(),
                f.member(),
                new CreateSettlementRequest(f.owner(), new BigDecimal("15.00"), "I_PAID")
        );

        // Outsider cannot list, view, create, or confirm
        assertEquals(ErrorCode.GROUP_NOT_FOUND, assertThrows(BusinessException.class,
                () -> expenses.listSettlements(f.groupId(), f.outsider(), null, null, null)).errorCode());
        assertEquals(ErrorCode.GROUP_NOT_FOUND, assertThrows(BusinessException.class,
                () -> expenses.settlementDetail(pending.id(), f.outsider())).errorCode());
        assertEquals(ErrorCode.GROUP_NOT_FOUND, assertThrows(BusinessException.class,
                () -> expenses.confirmSettlement(pending.id(), f.outsider())).errorCode());

        // Archive group -> read remains allowed, permissions become false, mutations fail with GROUP_ARCHIVED
        f.group().archive(Instant.now());
        groups.save(f.group());

        List<SettlementResponse> archivedList = expenses.listSettlements(f.groupId(), f.owner(), null, null, null);
        assertEquals(1, archivedList.size());
        assertFalse(archivedList.getFirst().permissions().canConfirm());
        assertFalse(archivedList.getFirst().permissions().canReject());
        assertFalse(archivedList.getFirst().permissions().canCancel());

        assertEquals(ErrorCode.GROUP_ARCHIVED, assertThrows(BusinessException.class,
                () -> expenses.confirmSettlement(pending.id(), f.owner())).errorCode());
    }

    @Test
    void concurrentSettlementCreationAndConfirmationPreventsOverSettlementAndDoubleConfirmation() throws Exception {
        Fixture f = fixture();
        expenses.create(f.groupId(), f.owner(), expenseRequest("80.00", f.owner(), List.of(f.member())));

        // Concurrent creation of two 60.00 settlements against 80.00 debt -> only one succeeds
        var pool = Executors.newFixedThreadPool(2);
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);
        AtomicInteger createdSuccess = new AtomicInteger(0);
        AtomicInteger exceededErrors = new AtomicInteger(0);

        for (int i = 0; i < 2; i++) {
            pool.submit(() -> {
                ready.countDown();
                try {
                    start.await();
                    expenses.createSettlement(
                            f.groupId(),
                            f.member(),
                            new CreateSettlementRequest(f.owner(), new BigDecimal("60.00"), "I_PAID")
                    );
                    createdSuccess.incrementAndGet();
                } catch (BusinessException ex) {
                    if (ex.errorCode() == ErrorCode.SETTLEMENT_AMOUNT_EXCEEDS_DEBT) {
                        exceededErrors.incrementAndGet();
                    }
                } catch (InterruptedException ignored) {
                    Thread.currentThread().interrupt();
                }
            });
        }
        assertTrue(ready.await(5, TimeUnit.SECONDS));
        start.countDown();
        pool.shutdown();
        assertTrue(pool.awaitTermination(10, TimeUnit.SECONDS));
        assertEquals(1, createdSuccess.get());
        assertEquals(1, exceededErrors.get());

        // Double confirmation of the single pending settlement -> one succeeds, one gets SETTLEMENT_ALREADY_RESOLVED
        SettlementResponse pending = expenses.listSettlements(f.groupId(), f.owner(), "PENDING", null, null).getFirst();
        var confirmPool = Executors.newFixedThreadPool(2);
        CountDownLatch confirmReady = new CountDownLatch(2);
        CountDownLatch confirmStart = new CountDownLatch(1);
        AtomicInteger confirmSuccess = new AtomicInteger(0);
        AtomicInteger alreadyResolved = new AtomicInteger(0);

        for (int i = 0; i < 2; i++) {
            confirmPool.submit(() -> {
                confirmReady.countDown();
                try {
                    confirmStart.await();
                    expenses.confirmSettlement(pending.id(), f.owner());
                    confirmSuccess.incrementAndGet();
                } catch (BusinessException ex) {
                    if (ex.errorCode() == ErrorCode.SETTLEMENT_ALREADY_RESOLVED) {
                        alreadyResolved.incrementAndGet();
                    }
                } catch (InterruptedException ignored) {
                    Thread.currentThread().interrupt();
                }
            });
        }
        assertTrue(confirmReady.await(5, TimeUnit.SECONDS));
        confirmStart.countDown();
        confirmPool.shutdown();
        assertTrue(confirmPool.awaitTermination(10, TimeUnit.SECONDS));
        assertEquals(1, confirmSuccess.get());
        assertEquals(1, alreadyResolved.get());
        assertEquals(new BigDecimal("20.00"), expenses.myBalances(f.groupId(), f.member()).totalOwedByMe());
    }

    private ExpenseRequest expenseRequest(String amount, UUID payer, List<UUID> participants) {
        return new ExpenseRequest("Test Expense", new BigDecimal(amount), payer, "EQUAL",
                participants, null, null, OffsetDateTime.now(), null);
    }

    private Fixture fixture() {
        UUID owner = saveUser("owner");
        UUID member = saveUser("member");
        UUID third = saveUser("third");
        UUID outsider = saveUser("outsider");
        GroupEntity group = groups.save(new GroupEntity(UUID.randomUUID(), "Settlement Group", "Desc", null,
                GroupStatus.ACTIVE, owner, Instant.now(), Instant.now()));
        settings.save(GroupSettingsEntity.createDefault(group.getId(), Instant.now()));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), group.getId(), owner, GroupRole.OWNER,
                GroupMembershipStatus.ACTIVE, Instant.now(), null));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), group.getId(), member, GroupRole.MEMBER,
                GroupMembershipStatus.ACTIVE, Instant.now(), null));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), group.getId(), third, GroupRole.MEMBER,
                GroupMembershipStatus.ACTIVE, Instant.now(), null));
        return new Fixture(group, group.getId(), owner, member, third, outsider);
    }

    private UUID saveUser(String prefix) {
        UUID id = UUID.randomUUID();
        String suffix = id.toString().substring(0, 8);
        users.save(new UserEntity(id, prefix + "_" + suffix + "@wedo.local", prefix + "_" + suffix,
                prefix.toUpperCase() + " " + suffix, UserStatus.ACTIVE, Instant.now(), Instant.now()));
        return id;
    }

    private record Fixture(GroupEntity group, UUID groupId, UUID owner, UUID member, UUID third, UUID outsider) { }
}
