package com.wedo.backend.fund;

import static org.junit.jupiter.api.Assertions.*;

import com.wedo.backend.common.error.BusinessException;
import com.wedo.backend.common.error.ErrorCode;
import com.wedo.backend.common.test.AbstractPostgresIntegrationTest;
import com.wedo.backend.fund.dto.FundDtos.AssignFundManagerRequest;
import com.wedo.backend.fund.dto.FundDtos.CollectionDetailResponse;
import com.wedo.backend.fund.dto.FundDtos.CollectionObligationResponse;
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
import com.wedo.backend.fund.dto.FundDtos.FundTransactionResponse;
import com.wedo.backend.fund.dto.FundDtos.ObligationInput;
import com.wedo.backend.fund.dto.FundDtos.ReimbursementResponse;
import com.wedo.backend.fund.dto.FundDtos.RejectRequest;
import com.wedo.backend.fund.dto.FundDtos.ReverseTransactionRequest;
import com.wedo.backend.fund.service.FundService;
import com.wedo.backend.group.entity.GroupEntity;
import com.wedo.backend.group.entity.GroupMembershipEntity;
import com.wedo.backend.group.entity.GroupMembershipStatus;
import com.wedo.backend.group.entity.GroupRole;
import com.wedo.backend.group.entity.GroupSettingsEntity;
import com.wedo.backend.group.entity.GroupStatus;
import com.wedo.backend.group.repository.GroupMembershipRepository;
import com.wedo.backend.group.repository.GroupRepository;
import com.wedo.backend.group.repository.GroupSettingsRepository;
import com.wedo.backend.group.service.GroupService;
import com.wedo.backend.group.service.GroupBanService;
import com.wedo.backend.media.storage.InMemoryObjectStorageService;
import com.wedo.backend.user.entity.UserEntity;
import com.wedo.backend.user.entity.UserStatus;
import com.wedo.backend.user.repository.UserRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

class FundServiceIntegrationTest extends AbstractPostgresIntegrationTest {
    @Autowired FundService fundService;
    @Autowired GroupService groupService;
    @Autowired GroupBanService groupBanService;
    @Autowired UserRepository users;
    @Autowired GroupRepository groups;
    @Autowired GroupMembershipRepository memberships;
    @Autowired GroupSettingsRepository settings;
    @Autowired JdbcTemplate jdbc;
    @Autowired InMemoryObjectStorageService objectStorage;

    @Test
    void ownerCreatesFundEnforcesSingleActiveFundAndDelegatesAdminManagersOnly() {
        Fixture f = fixture();

        assertEquals(ErrorCode.FUND_NOT_FOUND, assertThrows(BusinessException.class,
                () -> fundService.getGroupFund(f.groupId(), f.owner())).errorCode());

        assertEquals(ErrorCode.INSUFFICIENT_GROUP_PERMISSION, assertThrows(BusinessException.class,
                () -> fundService.createFund(f.groupId(), f.admin(), new CreateFundRequest("Quỹ chuyến đi"))).errorCode());

        assertEquals(ErrorCode.INSUFFICIENT_GROUP_PERMISSION, assertThrows(BusinessException.class,
                () -> fundService.createFund(f.groupId(), f.member(), new CreateFundRequest("Quỹ chuyến đi"))).errorCode());

        FundDetailResponse created = fundService.createFund(f.groupId(), f.owner(), new CreateFundRequest("Quỹ Đà Lạt"));
        assertEquals("ACTIVE", created.status());
        assertEquals("Quỹ Đà Lạt", created.name());
        assertEquals(new BigDecimal("0.00"), created.ledgerBalance());
        assertEquals(new BigDecimal("0.00"), created.availableBalance());
        assertTrue(created.permissions().isOwner());
        assertTrue(created.permissions().canManageFund());

        assertEquals(ErrorCode.FUND_ALREADY_EXISTS, assertThrows(BusinessException.class,
                () -> fundService.createFund(f.groupId(), f.owner(), new CreateFundRequest("Quỹ thứ 2"))).errorCode());

        // Unassigned ADMIN cannot manage fund
        FundDetailResponse adminViewBefore = fundService.getGroupFund(f.groupId(), f.admin());
        assertFalse(adminViewBefore.permissions().isFundManager());
        assertFalse(adminViewBefore.permissions().canManageFund());
        assertEquals(ErrorCode.FUND_ACCESS_DENIED, assertThrows(BusinessException.class,
                () -> fundService.createCollection(created.fundId(), f.admin(),
                        new CreateCollectionRequest("Đợt 1", null, null, "EQUAL_PER_MEMBER", new BigDecimal("100000.00"), null, null))).errorCode());

        // Non-ADMIN member cannot be assigned as Fund Manager
        assertEquals(ErrorCode.FUND_MANAGER_NOT_ELIGIBLE, assertThrows(BusinessException.class,
                () -> fundService.assignManager(created.fundId(), f.owner(), new AssignFundManagerRequest(f.member()))).errorCode());

        // Assign ADMIN as Fund Manager
        FundManagerResponse assigned = fundService.assignManager(created.fundId(), f.owner(), new AssignFundManagerRequest(f.admin()));
        assertEquals(f.admin(), assigned.user().userId());
        assertEquals(1, fundService.listManagers(created.fundId(), f.owner()).size());

        FundDetailResponse adminViewAfter = fundService.getGroupFund(f.groupId(), f.admin());
        assertTrue(adminViewAfter.permissions().isFundManager());
        assertTrue(adminViewAfter.permissions().canManageFund());

        // Demoting ADMIN to MEMBER automatically revokes Fund Manager authority
        groupService.demoteAdmin(f.groupId(), f.admin(), f.owner());
        FundDetailResponse demotedView = fundService.getGroupFund(f.groupId(), f.admin());
        assertFalse(demotedView.permissions().isFundManager());
        assertFalse(demotedView.permissions().canManageFund());
        assertEquals(0, fundService.listManagers(created.fundId(), f.owner()).size());
    }

    @Test
    void collectionContributionAndObligationLifecycleDerivesExactStatusesAndPreventsOverpayment() {
        Fixture f = fixture();
        FundDetailResponse fund = fundService.createFund(f.groupId(), f.owner(), new CreateFundRequest("Quỹ nhóm"));
        fundService.assignManager(fund.fundId(), f.owner(), new AssignFundManagerRequest(f.admin()));

        CollectionDetailResponse collection = fundService.createCollection(
                fund.fundId(),
                f.admin(),
                new CreateCollectionRequest(
                        "Đóng quỹ tháng 10",
                        "Mỗi người 200k",
                        OffsetDateTime.now(ZoneOffset.UTC).plusDays(7),
                        "CUSTOM",
                        null,
                        null,
                        List.of(
                                new ObligationInput(f.owner(), new BigDecimal("200000.00")),
                                new ObligationInput(f.admin(), new BigDecimal("200000.00")),
                                new ObligationInput(f.member(), new BigDecimal("200000.00"))
                        )
                )
        );
        assertEquals(new BigDecimal("600000.00"), collection.totalExpectedAmount());
        assertEquals(new BigDecimal("0.00"), collection.totalConfirmedAmount());
        assertEquals("UNPAID", obligationFor(collection, f.member()).status());

        // Overpayment rejected
        assertEquals(ErrorCode.FUND_CONTRIBUTION_EXCEEDS_OBLIGATION, assertThrows(BusinessException.class,
                () -> fundService.submitContribution(collection.collectionId(), f.member(),
                        new CreateContributionRequest(null, new BigDecimal("250000.00"), null, "Nộp dư", null))).errorCode());

        // Partial contribution (PENDING) does not change ledgerBalance yet
        ContributionResponse c1 = fundService.submitContribution(
                collection.collectionId(),
                f.member(),
                        new CreateContributionRequest(null, new BigDecimal("80000.00"), mediaKey("fund-contribution-proof", f.groupId(), f.member()), "Nộp đợt 1", null)
        );
        assertEquals("PENDING", c1.status());
        assertEquals(ErrorCode.FUND_ACCESS_DENIED, assertThrows(BusinessException.class,
                () -> fundService.confirmContribution(c1.contributionId(), f.member())).errorCode());
        assertEquals(new BigDecimal("0.00"), fundService.getGroupFund(f.groupId(), f.owner()).ledgerBalance());

        // Pending contribution reserves obligation room so member cannot submit > remaining 120,000
        assertEquals(ErrorCode.FUND_CONTRIBUTION_EXCEEDS_OBLIGATION, assertThrows(BusinessException.class,
                () -> fundService.submitContribution(collection.collectionId(), f.member(),
                        new CreateContributionRequest(null, new BigDecimal("150000.00"), null, "Vượt phần còn lại", null))).errorCode());

        // Confirm c1 -> obligation becomes PARTIAL, ledgerBalance becomes 80,000.00
        ContributionResponse confirmed1 = fundService.confirmContribution(c1.contributionId(), f.admin());
        assertEquals("CONFIRMED", confirmed1.status());
        assertEquals(new BigDecimal("80000.00"), fundService.getGroupFund(f.groupId(), f.owner()).ledgerBalance());

        CollectionDetailResponse afterPart1 = fundService.getCollectionDetail(collection.collectionId(), f.member());
        assertEquals("PARTIAL", obligationFor(afterPart1, f.member()).status());
        assertEquals(new BigDecimal("120000.00"), obligationFor(afterPart1, f.member()).remainingAmount());

        // Submit and cancel a pending contribution -> restores obligation room
        ContributionResponse toCancel = fundService.submitContribution(
                collection.collectionId(),
                f.member(),
                new CreateContributionRequest(null, new BigDecimal("120000.00"), null, "Nhầm số", null)
        );
        assertEquals("CANCELLED", fundService.cancelContribution(toCancel.contributionId(), f.member()).status());

        // Submit and reject a pending contribution -> restores obligation room
        ContributionResponse toReject = fundService.submitContribution(
                collection.collectionId(),
                f.member(),
                new CreateContributionRequest(null, new BigDecimal("120000.00"), null, "Chưa nhận được", null)
        );
        assertEquals("REJECTED", fundService.rejectContribution(toReject.contributionId(), f.admin(), new RejectRequest("Chưa thấy chuyển khoản")).status());

        // Submit and confirm remaining 120,000 -> obligation becomes PAID, ledgerBalance becomes 200,000.00
        ContributionResponse c2 = fundService.submitContribution(
                collection.collectionId(),
                f.member(),
                new CreateContributionRequest(null, new BigDecimal("120000.00"), mediaKey("fund-contribution-proof", f.groupId(), f.member()), "Nộp đủ", null)
        );
        fundService.confirmContribution(c2.contributionId(), f.owner());

        CollectionDetailResponse afterPaid = fundService.getCollectionDetail(collection.collectionId(), f.member());
        assertEquals("PAID", obligationFor(afterPaid, f.member()).status());
        assertEquals(new BigDecimal("200000.00"), obligationFor(afterPaid, f.member()).confirmedAmount());
        assertEquals(new BigDecimal("0.00"), obligationFor(afterPaid, f.member()).remainingAmount());
        assertEquals(new BigDecimal("200000.00"), fundService.getGroupFund(f.groupId(), f.owner()).ledgerBalance());

        // Overdue derivation when deadline is in the past and obligation is not PAID
        CollectionDetailResponse overdueCol = fundService.createCollection(
                fund.fundId(),
                f.owner(),
                new CreateCollectionRequest(
                        "Đợt quá hạn",
                        null,
                        OffsetDateTime.now(ZoneOffset.UTC).minusHours(2),
                        "EQUAL_PER_MEMBER",
                        new BigDecimal("50000.00"),
                        List.of(f.member()),
                        null
                )
        );
        assertEquals("OVERDUE", obligationFor(overdueCol, f.member()).status());
    }

    @Test
    void fundExpenseReimbursementReservationAndReversalMaintainStrictLedgerInvariants() {
        Fixture f = fixture();
        FundDetailResponse fund = fundService.createFund(f.groupId(), f.owner(), new CreateFundRequest("Quỹ hoạt động"));

        // Seed 300,000 inflow via collection contribution
        CollectionDetailResponse col = fundService.createCollection(
                fund.fundId(),
                f.owner(),
                new CreateCollectionRequest("Thu đầu kỳ", null, null, "EQUAL_PER_MEMBER", new BigDecimal("300000.00"), List.of(f.owner()), null)
        );
        ContributionResponse contrib = fundService.submitContribution(
                col.collectionId(),
                f.owner(),
                new CreateContributionRequest(null, new BigDecimal("300000.00"), null, "Nộp quỹ", null)
        );
        fundService.confirmContribution(contrib.contributionId(), f.owner());

        FundDetailResponse afterInflow = fundService.getGroupFund(f.groupId(), f.owner());
        assertEquals(new BigDecimal("300000.00"), afterInflow.ledgerBalance());
        assertEquals(new BigDecimal("300000.00"), afterInflow.availableBalance());

        // Direct fund expense of 100,000 -> ledgerBalance = 200,000, availableBalance = 200,000
        FundExpenseResponse exp = fundService.createFundExpense(
                fund.fundId(),
                f.owner(),
                new CreateFundExpenseRequest("Mua nước uống", new BigDecimal("100000.00"), null, null, mediaKey("fund-expense-receipt", f.groupId(), f.owner()), "Chi sự kiện")
        );
        assertNotNull(exp.transactionId());
        FundDetailResponse afterExpense = fundService.getGroupFund(f.groupId(), f.owner());
        assertEquals(new BigDecimal("200000.00"), afterExpense.ledgerBalance());
        assertEquals(new BigDecimal("200000.00"), afterExpense.availableBalance());

        // Member requests reimbursement of 150,000 -> PENDING reserves availableBalance (200,000 -> 50,000) while ledgerBalance stays 200,000
        ReimbursementResponse reimb = fundService.createReimbursement(
                fund.fundId(),
                f.member(),
                new CreateReimbursementRequest(new BigDecimal("150000.00"), "Ứng tiền mua bánh", mediaKey("fund-reimbursement-receipt", f.groupId(), f.member()))
        );
        assertEquals("PENDING", reimb.status());
        assertEquals(ErrorCode.FUND_ACCESS_DENIED, assertThrows(BusinessException.class,
                () -> fundService.approveReimbursement(reimb.reimbursementId(), f.member())).errorCode());
        FundDetailResponse afterPendingReimb = fundService.getGroupFund(f.groupId(), f.owner());
        assertEquals(new BigDecimal("200000.00"), afterPendingReimb.ledgerBalance());
        assertEquals(new BigDecimal("150000.00"), afterPendingReimb.pendingReimbursements());
        assertEquals(new BigDecimal("50000.00"), afterPendingReimb.availableBalance());

        // Direct fund expense of 60,000 fails because availableBalance is only 50,000!
        assertEquals(ErrorCode.FUND_INSUFFICIENT_BALANCE, assertThrows(BusinessException.class,
                () -> fundService.createFundExpense(fund.fundId(), f.owner(),
                        new CreateFundExpenseRequest("Chi vượt số dư khả dụng", new BigDecimal("60000.00"), null, null, null, null))).errorCode());

        // Approve reimbursement -> status COMPLETED, ledgerBalance = 50,000, pendingReimbursements = 0, availableBalance = 50,000
        ReimbursementResponse approvedReimb = fundService.approveReimbursement(reimb.reimbursementId(), f.owner());
        assertEquals("COMPLETED", approvedReimb.status());
        assertNotNull(approvedReimb.transactionId());
        FundDetailResponse afterApprovedReimb = fundService.getGroupFund(f.groupId(), f.owner());
        assertEquals(new BigDecimal("50000.00"), afterApprovedReimb.ledgerBalance());
        assertEquals(new BigDecimal("0.00"), afterApprovedReimb.pendingReimbursements());
        assertEquals(new BigDecimal("50000.00"), afterApprovedReimb.availableBalance());

        // Reversing the 300,000 IN contribution fails right now because availableBalance is only 50,000 (< 300,000)
        FundTransactionResponse contribTx = fundService.listTransactions(fund.fundId(), f.owner(), "CONTRIBUTION", null).get(0);
        assertEquals(ErrorCode.FUND_INSUFFICIENT_BALANCE, assertThrows(BusinessException.class,
                () -> fundService.reverseTransaction(contribTx.transactionId(), f.owner(), new ReverseTransactionRequest("Đảo thu khi đã chi"))).errorCode());

        // Reverse the 100,000 OUT fund expense -> creates IN REVERSAL, ledgerBalance becomes 150,000
        FundTransactionResponse reversal1 = fundService.reverseTransaction(
                exp.transactionId(),
                f.owner(),
                new ReverseTransactionRequest("Nhập nhầm hóa đơn nước")
        );
        assertEquals("REVERSAL", reversal1.transactionType());
        assertEquals("IN", reversal1.direction());
        assertEquals(new BigDecimal("100000.00"), reversal1.amount());
        assertEquals(new BigDecimal("150000.00"), fundService.getGroupFund(f.groupId(), f.owner()).ledgerBalance());

        // Reversing a REVERSAL transaction or already-reversed transaction is rejected
        assertEquals(ErrorCode.FUND_REVERSAL_NOT_ALLOWED, assertThrows(BusinessException.class,
                () -> fundService.reverseTransaction(reversal1.transactionId(), f.owner(), new ReverseTransactionRequest("Đảo của đảo"))).errorCode());
        assertEquals(ErrorCode.FUND_TRANSACTION_ALREADY_REVERSED, assertThrows(BusinessException.class,
                () -> fundService.reverseTransaction(exp.transactionId(), f.owner(), new ReverseTransactionRequest("Đảo lần 2"))).errorCode());

        // Reverse the 150,000 OUT reimbursement -> creates IN REVERSAL, ledgerBalance returns to 300,000
        fundService.reverseTransaction(approvedReimb.transactionId(), f.owner(), new ReverseTransactionRequest("Đảo hoàn ứng"));
        assertEquals(new BigDecimal("300000.00"), fundService.getGroupFund(f.groupId(), f.owner()).ledgerBalance());

        // Reverse the 300,000 IN contribution -> creates OUT REVERSAL, ledgerBalance returns to 0.00
        fundService.reverseTransaction(contribTx.transactionId(), f.owner(), new ReverseTransactionRequest("Hoàn trả tiền đóng quỹ"));
        assertEquals(new BigDecimal("0.00"), fundService.getGroupFund(f.groupId(), f.owner()).ledgerBalance());

        // Closing fund fails while collection is still OPEN
        assertEquals(ErrorCode.FUND_CLOSE_PRECONDITION_FAILED, assertThrows(BusinessException.class,
                () -> fundService.closeFund(fund.fundId(), f.owner())).errorCode());

        // Close collection, then close fund succeeds!
        fundService.closeCollection(col.collectionId(), f.owner());
        FundDetailResponse closedFund = fundService.closeFund(fund.fundId(), f.owner());
        assertEquals("CLOSED", closedFund.status());
        assertNotNull(closedFund.closedAt());

        // Owner can create a new ACTIVE fund after closing the old one
        FundDetailResponse reopened = fundService.createFund(f.groupId(), f.owner(), new CreateFundRequest("Quỹ mới 2027"));
        assertEquals("ACTIVE", reopened.status());
        assertNotEquals(closedFund.fundId(), reopened.fundId());
    }

    @Test
    void archivedGroupAndFormerMemberRespectReadAndVisibilityRules() {
        Fixture f = fixture();
        FundDetailResponse fund = fundService.createFund(f.groupId(), f.owner(), new CreateFundRequest("Quỹ nhóm"));
        CollectionDetailResponse col = fundService.createCollection(
                fund.fundId(),
                f.owner(),
                new CreateCollectionRequest("Quỹ dã ngoại", null, null, "EQUAL_PER_MEMBER", new BigDecimal("100000.00"), List.of(f.owner(), f.member()), null)
        );
        ContributionResponse c = fundService.submitContribution(
                col.collectionId(),
                f.member(),
                new CreateContributionRequest(null, new BigDecimal("100000.00"), null, "Đã đóng", null)
        );
        fundService.confirmContribution(c.contributionId(), f.owner());

        // Member leaves the group
        groupService.leave(f.groupId(), f.member());

        // Former member cannot access group fund API
        assertEquals(ErrorCode.GROUP_NOT_FOUND, assertThrows(BusinessException.class,
                () -> fundService.getGroupFund(f.groupId(), f.member())).errorCode());

        // Historical contribution & obligation still display former member with activeMember = false
        CollectionDetailResponse detailForOwner = fundService.getCollectionDetail(col.collectionId(), f.owner());
        CollectionObligationResponse memberOb = obligationFor(detailForOwner, f.member());
        assertFalse(memberOb.user().activeMember());
        assertEquals("FORMER_MEMBER", memberOb.user().role());

        // Archive group -> reading fund overview/transactions works, mutating fails with GROUP_ARCHIVED
        jdbc.update("UPDATE groups SET status = 'ARCHIVED' WHERE id = ?", f.groupId());
        FundOverviewResponse archivedOverview = fundService.getFundOverview(fund.fundId(), f.owner());
        assertEquals(new BigDecimal("100000.00"), archivedOverview.fund().ledgerBalance());
        assertFalse(archivedOverview.fund().permissions().canManageFund());

        assertEquals(ErrorCode.GROUP_ARCHIVED, assertThrows(BusinessException.class,
                () -> fundService.createFundExpense(fund.fundId(), f.owner(),
                        new CreateFundExpenseRequest("Chi khi lưu trữ", new BigDecimal("10000.00"), null, null, null, null))).errorCode());
    }

    @Test
    void concurrentFundExpensesDuplicateConfirmAndDuplicateReversalAreSerializedByForUpdateLocks() throws Exception {
        Fixture f = fixture();
        FundDetailResponse fund = fundService.createFund(f.groupId(), f.owner(), new CreateFundRequest("Quỹ khóa đồng thời"));
        CollectionDetailResponse col = fundService.createCollection(
                fund.fundId(),
                f.owner(),
                new CreateCollectionRequest("Nạp 100k", null, null, "EQUAL_PER_MEMBER", new BigDecimal("100000.00"), List.of(f.member()), null)
        );
        ContributionResponse pendingContrib = fundService.submitContribution(
                col.collectionId(),
                f.member(),
                new CreateContributionRequest(null, new BigDecimal("100000.00"), null, "Nạp 1 lần", null)
        );

        // 1. Concurrent confirm of the same PENDING contribution
        CountDownLatch confirmStart = new CountDownLatch(1);
        AtomicInteger confirmSuccess = new AtomicInteger();
        AtomicInteger confirmConflict = new AtomicInteger();
        try (var pool = Executors.newFixedThreadPool(2)) {
            Runnable task = () -> {
                try {
                    confirmStart.await();
                    fundService.confirmContribution(pendingContrib.contributionId(), f.owner());
                    confirmSuccess.incrementAndGet();
                } catch (BusinessException ex) {
                    if (ex.errorCode() == ErrorCode.FUND_CONTRIBUTION_ALREADY_RESOLVED) {
                        confirmConflict.incrementAndGet();
                    }
                } catch (Exception ignored) {
                }
            };
            var f1 = pool.submit(task);
            var f2 = pool.submit(task);
            confirmStart.countDown();
            f1.get(20, TimeUnit.SECONDS);
            f2.get(20, TimeUnit.SECONDS);
        }
        assertEquals(1, confirmSuccess.get());
        assertEquals(1, confirmConflict.get());
        assertEquals(new BigDecimal("100000.00"), fundService.getGroupFund(f.groupId(), f.owner()).ledgerBalance());

        // 2. Concurrent competing fund expenses (both trying to spend 100,000 from 100,000 available balance)
        CountDownLatch expenseStart = new CountDownLatch(1);
        AtomicInteger expenseSuccess = new AtomicInteger();
        AtomicInteger expenseInsufficient = new AtomicInteger();
        try (var pool = Executors.newFixedThreadPool(2)) {
            Runnable task = () -> {
                try {
                    expenseStart.await();
                    fundService.createFundExpense(
                            fund.fundId(),
                            f.owner(),
                            new CreateFundExpenseRequest("Chi cạnh tranh", new BigDecimal("100000.00"), null, null, null, null)
                    );
                    expenseSuccess.incrementAndGet();
                } catch (BusinessException ex) {
                    if (ex.errorCode() == ErrorCode.FUND_INSUFFICIENT_BALANCE) {
                        expenseInsufficient.incrementAndGet();
                    }
                } catch (Exception ignored) {
                }
            };
            var e1 = pool.submit(task);
            var e2 = pool.submit(task);
            expenseStart.countDown();
            e1.get(20, TimeUnit.SECONDS);
            e2.get(20, TimeUnit.SECONDS);
        }
        assertEquals(1, expenseSuccess.get());
        assertEquals(1, expenseInsufficient.get());
        assertEquals(new BigDecimal("0.00"), fundService.getGroupFund(f.groupId(), f.owner()).ledgerBalance());

        // 3. Concurrent reversal of the same expense transaction
        FundTransactionResponse expenseTx = fundService.listTransactions(fund.fundId(), f.owner(), "FUND_EXPENSE", null).get(0);
        CountDownLatch reverseStart = new CountDownLatch(1);
        AtomicInteger reverseSuccess = new AtomicInteger();
        AtomicInteger reverseConflict = new AtomicInteger();
        try (var pool = Executors.newFixedThreadPool(2)) {
            Runnable task = () -> {
                try {
                    reverseStart.await();
                    fundService.reverseTransaction(expenseTx.transactionId(), f.owner(), new ReverseTransactionRequest("Đảo đồng thời"));
                    reverseSuccess.incrementAndGet();
                } catch (BusinessException ex) {
                    if (ex.errorCode() == ErrorCode.FUND_TRANSACTION_ALREADY_REVERSED) {
                        reverseConflict.incrementAndGet();
                    }
                } catch (Exception ignored) {
                }
            };
            var r1 = pool.submit(task);
            var r2 = pool.submit(task);
            reverseStart.countDown();
            r1.get(20, TimeUnit.SECONDS);
            r2.get(20, TimeUnit.SECONDS);
        }
        assertEquals(1, reverseSuccess.get());
        assertEquals(1, reverseConflict.get());
        assertEquals(new BigDecimal("100000.00"), fundService.getGroupFund(f.groupId(), f.owner()).ledgerBalance());
    }

    @Test
    void closedCollectionAllowsConfirmingExistingPendingContributionsWhileCancelledCollectionCancelsPending() {
        Fixture f = fixture();
        FundDetailResponse fund = fundService.createFund(f.groupId(), f.owner(), new CreateFundRequest("Quỹ đóng/hủy đợt thu"));

        CollectionDetailResponse colClose = fundService.createCollection(
                fund.fundId(),
                f.owner(),
                new CreateCollectionRequest("Đợt đóng", null, null, "EQUAL_PER_MEMBER", new BigDecimal("100000.00"), List.of(f.member()), null)
        );
        ContributionResponse pendingBeforeClose = fundService.submitContribution(
                colClose.collectionId(),
                f.member(),
                new CreateContributionRequest(null, new BigDecimal("60000.00"), null, "Đóng trước khi khóa đợt", null)
        );
        CollectionDetailResponse closedCol = fundService.closeCollection(colClose.collectionId(), f.owner());
        assertEquals("CLOSED", closedCol.status());
        assertEquals(ErrorCode.FUND_COLLECTION_NOT_OPEN, assertThrows(BusinessException.class,
                () -> fundService.submitContribution(colClose.collectionId(), f.member(),
                        new CreateContributionRequest(null, new BigDecimal("40000.00"), null, "Nộp sau khi đóng", null))).errorCode());

        ContributionResponse confirmedAfterClose = fundService.confirmContribution(pendingBeforeClose.contributionId(), f.owner());
        assertEquals("CONFIRMED", confirmedAfterClose.status());
        assertEquals(new BigDecimal("60000.00"), fundService.getGroupFund(f.groupId(), f.owner()).ledgerBalance());

        CollectionDetailResponse colCancel = fundService.createCollection(
                fund.fundId(),
                f.owner(),
                new CreateCollectionRequest("Đợt hủy", null, null, "EQUAL_PER_MEMBER", new BigDecimal("100000.00"), List.of(f.member()), null)
        );
        ContributionResponse pendingBeforeCancel = fundService.submitContribution(
                colCancel.collectionId(),
                f.member(),
                new CreateContributionRequest(null, new BigDecimal("50000.00"), null, "Đóng trước khi hủy đợt", null)
        );
        CollectionDetailResponse cancelledCol = fundService.cancelCollection(colCancel.collectionId(), f.owner());
        assertEquals("CANCELLED", cancelledCol.status());
        assertEquals("CANCELLED", cancelledCol.contributions().get(0).status());
        assertEquals(ErrorCode.FUND_CONTRIBUTION_ALREADY_RESOLVED, assertThrows(BusinessException.class,
                () -> fundService.confirmContribution(pendingBeforeCancel.contributionId(), f.owner())).errorCode());
        assertEquals(new BigDecimal("60000.00"), fundService.getGroupFund(f.groupId(), f.owner()).ledgerBalance());
    }

    @ParameterizedTest
    @ValueSource(strings = {"LEAVE", "KICK", "BAN"})
    void formerMemberFinancialHistoryPersistsInLedgerAndAttributionWhileRevokingManagerAndMutationRights(String exit) {
        Fixture f = fixture();
        FundDetailResponse fund = fundService.createFund(f.groupId(), f.owner(), new CreateFundRequest("Quỹ lịch sử cựu thành viên"));
        fundService.assignManager(fund.fundId(), f.owner(), new AssignFundManagerRequest(f.admin()));

        CollectionDetailResponse col = fundService.createCollection(
                fund.fundId(),
                f.admin(),
                new CreateCollectionRequest("Thu quỹ cựu thành viên", null, null, "EQUAL_PER_MEMBER", new BigDecimal("150000.00"), List.of(f.admin(), f.member()), null)
        );
        ContributionResponse adminContrib = fundService.submitContribution(
                col.collectionId(),
                f.admin(),
                new CreateContributionRequest(null, new BigDecimal("150000.00"), null, "Admin đóng quỹ", null)
        );
        fundService.confirmContribution(adminContrib.contributionId(), f.owner());

        assertEquals(new BigDecimal("150000.00"), fundService.getGroupFund(f.groupId(), f.owner()).ledgerBalance());
        assertEquals(1, fundService.listManagers(fund.fundId(), f.owner()).size());

        switch (exit) {
            case "LEAVE" -> groupService.leave(f.groupId(), f.admin());
            case "KICK" -> groupService.kick(f.groupId(), f.admin(), f.owner());
            case "BAN" -> groupBanService.banMember(f.groupId(), f.admin(), f.owner(), "Fund history test");
            default -> throw new IllegalArgumentException(exit);
        }

        assertEquals(0, fundService.listManagers(fund.fundId(), f.owner()).size());
        assertEquals(ErrorCode.GROUP_NOT_FOUND, assertThrows(BusinessException.class,
                () -> fundService.getGroupFund(f.groupId(), f.admin())).errorCode());
        assertEquals(ErrorCode.GROUP_NOT_FOUND, assertThrows(BusinessException.class,
                () -> fundService.createFundExpense(fund.fundId(), f.admin(),
                        new CreateFundExpenseRequest("Chi trái phép", new BigDecimal("10000.00"), null, null, null, null))).errorCode());

        FundDetailResponse afterLeave = fundService.getGroupFund(f.groupId(), f.owner());
        assertEquals(new BigDecimal("150000.00"), afterLeave.ledgerBalance());
        assertEquals(new BigDecimal("150000.00"), afterLeave.availableBalance());

        CollectionDetailResponse detailAfterLeave = fundService.getCollectionDetail(col.collectionId(), f.member());
        CollectionObligationResponse adminOb = obligationFor(detailAfterLeave, f.admin());
        assertEquals("ADMIN", adminOb.user().displayName());
        assertEquals("FORMER_MEMBER", adminOb.user().role());
        assertFalse(adminOb.user().activeMember());
        assertEquals(new BigDecimal("150000.00"), adminOb.confirmedAmount());

        List<FundTransactionResponse> txs = fundService.listTransactions(fund.fundId(), f.member(), null, null);
        assertEquals(1, txs.size());
        assertEquals(new BigDecimal("150000.00"), txs.get(0).amount());
    }

    @Test
    void maxTwoFundManagersOutsiderAccessDenialAndExactJsonDecimalStringSerialization() throws Exception {
        Fixture f = fixture();
        UUID admin2 = UUID.randomUUID();
        UUID admin3 = UUID.randomUUID();
        Instant now = Instant.now();
        saveUser(admin2, "ADMIN2", now);
        saveUser(admin3, "ADMIN3", now);
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), f.groupId(), admin2, GroupRole.ADMIN, GroupMembershipStatus.ACTIVE, now, null));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), f.groupId(), admin3, GroupRole.ADMIN, GroupMembershipStatus.ACTIVE, now, null));

        FundDetailResponse fund = fundService.createFund(f.groupId(), f.owner(), new CreateFundRequest("Quỹ kiểm tra giới hạn"));

        assertEquals(ErrorCode.GROUP_NOT_FOUND, assertThrows(BusinessException.class,
                () -> fundService.getGroupFund(f.groupId(), f.outsider())).errorCode());
        assertEquals(ErrorCode.GROUP_NOT_FOUND, assertThrows(BusinessException.class,
                () -> fundService.getFundOverview(fund.fundId(), f.outsider())).errorCode());

        fundService.assignManager(fund.fundId(), f.owner(), new AssignFundManagerRequest(f.admin()));
        fundService.assignManager(fund.fundId(), f.owner(), new AssignFundManagerRequest(admin2));
        assertEquals(2, fundService.listManagers(fund.fundId(), f.owner()).size());
        assertEquals(ErrorCode.FUND_MANAGER_NOT_ELIGIBLE, assertThrows(BusinessException.class,
                () -> fundService.assignManager(fund.fundId(), f.owner(), new AssignFundManagerRequest(admin3))).errorCode());

        com.fasterxml.jackson.databind.ObjectMapper mapper = new com.fasterxml.jackson.databind.ObjectMapper().findAndRegisterModules();
        String json = mapper.writeValueAsString(fundService.getGroupFund(f.groupId(), f.owner()));
        assertTrue(json.contains("\"ledgerBalance\":\"0.00\""));
        assertTrue(json.contains("\"availableBalance\":\"0.00\""));
    }

    @Test
    void fundAuthorizationMatrixRejectsOrdinaryAdminMemberAndCrossFundAccess() {
        Fixture f = fixture();
        FundDetailResponse fund = fundService.createFund(f.groupId(), f.owner(), new CreateFundRequest("Quỹ ma trận"));
        CollectionDetailResponse collection = fundService.createCollection(
                fund.fundId(), f.owner(), new CreateCollectionRequest("Đợt thu", null, null,
                        "EQUAL_PER_MEMBER", new BigDecimal("100.00"), List.of(f.member()), null));
        ContributionResponse contribution = fundService.submitContribution(collection.collectionId(), f.member(),
                new CreateContributionRequest(null, new BigDecimal("100.00"), null, null, null));
        fundService.confirmContribution(contribution.contributionId(), f.owner());
        ReimbursementResponse reimbursement = fundService.createReimbursement(fund.fundId(), f.member(),
                new CreateReimbursementRequest(new BigDecimal("1.00"), "Chi hộ", null));

        assertEquals(ErrorCode.FUND_ACCESS_DENIED, assertThrows(BusinessException.class,
                () -> fundService.closeCollection(collection.collectionId(), f.member())).errorCode());
        assertEquals(ErrorCode.FUND_ACCESS_DENIED, assertThrows(BusinessException.class,
                () -> fundService.confirmContribution(contribution.contributionId(), f.member())).errorCode());
        assertEquals(ErrorCode.FUND_ACCESS_DENIED, assertThrows(BusinessException.class,
                () -> fundService.rejectContribution(contribution.contributionId(), f.member(), new RejectRequest("No"))).errorCode());
        assertEquals(ErrorCode.FUND_ACCESS_DENIED, assertThrows(BusinessException.class,
                () -> fundService.rejectReimbursement(reimbursement.reimbursementId(), f.member(), new RejectRequest("No"))).errorCode());

        Fixture other = fixture();
        assertEquals(ErrorCode.GROUP_NOT_FOUND, assertThrows(BusinessException.class,
                () -> fundService.getFundOverview(fund.fundId(), other.member())).errorCode());
        assertEquals(ErrorCode.GROUP_NOT_FOUND, assertThrows(BusinessException.class,
                () -> fundService.listTransactions(fund.fundId(), other.member(), null, null)).errorCode());

        fundService.cancelCollection(collection.collectionId(), f.owner());
        assertEquals("CANCELLED", fundService.getCollectionDetail(collection.collectionId(), f.owner()).status());
    }

    @Test
    void closedFundRejectsWritesButKeepsOwnerHistoryReadable() {
        Fixture f = fixture();
        FundDetailResponse fund = fundService.createFund(f.groupId(), f.owner(), new CreateFundRequest("Quỹ đã đóng"));
        fundService.closeFund(fund.fundId(), f.owner());
        assertEquals("CLOSED", fundService.getGroupFund(f.groupId(), f.owner()).status());
        assertEquals(ErrorCode.FUND_CLOSED, assertThrows(BusinessException.class,
                () -> fundService.createFundExpense(fund.fundId(), f.owner(),
                        new CreateFundExpenseRequest("Không được ghi", new BigDecimal("1.00"), null, null, null, null))).errorCode());
        assertEquals(ErrorCode.FUND_CLOSED, assertThrows(BusinessException.class,
                () -> fundService.createCollection(fund.fundId(), f.owner(), new CreateCollectionRequest(
                        "Không được tạo", null, null, "EQUAL_PER_MEMBER", new BigDecimal("1.00"), List.of(f.owner()), null))).errorCode());
    }

    private CollectionObligationResponse obligationFor(CollectionDetailResponse detail, UUID userId) {
        return detail.obligations().stream()
                .filter(o -> o.user().userId().equals(userId))
                .findFirst()
                .orElseThrow();
    }

    private Fixture fixture() {
        UUID owner = UUID.randomUUID();
        UUID admin = UUID.randomUUID();
        UUID member = UUID.randomUUID();
        UUID outsider = UUID.randomUUID();
        Instant now = Instant.now();
        saveUser(owner, "OWNER", now);
        saveUser(admin, "ADMIN", now);
        saveUser(member, "MEMBER", now);
        saveUser(outsider, "OUTSIDER", now);

        UUID groupId = UUID.randomUUID();
        GroupEntity group = groups.save(new GroupEntity(groupId, "Group Fund Test", null, null, GroupStatus.ACTIVE, owner, now, now));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, owner, GroupRole.OWNER, GroupMembershipStatus.ACTIVE, now, null));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, admin, GroupRole.ADMIN, GroupMembershipStatus.ACTIVE, now, null));
        memberships.save(new GroupMembershipEntity(UUID.randomUUID(), groupId, member, GroupRole.MEMBER, GroupMembershipStatus.ACTIVE, now, null));
        settings.save(GroupSettingsEntity.createDefault(groupId, now));
        return new Fixture(groupId, owner, admin, member, outsider, group);
    }

    private String mediaKey(String namespace, UUID groupId, UUID uploaderId) {
        String key = namespace + "/" + groupId + "/" + uploaderId + "/" + UUID.randomUUID();
        objectStorage.putForTest(key, "image/jpeg", 128);
        return key;
    }

    private void saveUser(UUID id, String label, Instant now) {
        String suffix = id.toString().substring(0, 8);
        users.save(new UserEntity(
                id,
                label.toLowerCase() + "+" + suffix + "@fund.test",
                label.toLowerCase() + suffix,
                label,
                UserStatus.ACTIVE,
                now,
                now
        ));
    }

    private record Fixture(UUID groupId, UUID owner, UUID admin, UUID member, UUID outsider, GroupEntity group) {
    }
}
