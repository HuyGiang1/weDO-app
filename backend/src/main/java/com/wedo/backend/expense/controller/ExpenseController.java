package com.wedo.backend.expense.controller;

import com.wedo.backend.expense.dto.ExpenseDtos.CreateSettlementRequest;
import com.wedo.backend.expense.dto.ExpenseDtos.ExpenseDetail;
import com.wedo.backend.expense.dto.ExpenseDtos.ExpenseRequest;
import com.wedo.backend.expense.dto.ExpenseDtos.ExpenseSummary;
import com.wedo.backend.expense.dto.ExpenseDtos.MyBalances;
import com.wedo.backend.expense.dto.ExpenseDtos.PairBalance;
import com.wedo.backend.expense.dto.ExpenseDtos.SettlementResponse;
import com.wedo.backend.expense.service.ExpenseService;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import jakarta.validation.Valid;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
@Validated
public class ExpenseController {
    private final ExpenseService expenses;

    public ExpenseController(ExpenseService expenses) {
        this.expenses = expenses;
    }

    @PostMapping("/groups/{groupId}/expenses")
    @ResponseStatus(HttpStatus.CREATED)
    public ExpenseDetail create(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId,
            @Valid @RequestBody ExpenseRequest request
    ) {
        return expenses.create(groupId, principal.userId(), request);
    }

    @GetMapping("/groups/{groupId}/expenses")
    public List<ExpenseSummary> list(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId,
            @RequestParam(required = false) UUID activityId,
            @RequestParam(required = false) Boolean involvingMe,
            @RequestParam(required = false) Boolean createdByMe,
            @RequestParam(required = false) OffsetDateTime from,
            @RequestParam(required = false) OffsetDateTime to
    ) {
        return expenses.list(groupId, principal.userId(), activityId, involvingMe, createdByMe, from, to);
    }

    @GetMapping("/expenses/{expenseId}")
    public ExpenseDetail detail(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID expenseId
    ) {
        return expenses.detail(expenseId, principal.userId());
    }

    @PatchMapping("/expenses/{expenseId}")
    public ExpenseDetail update(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID expenseId,
            @Valid @RequestBody ExpenseRequest request
    ) {
        return expenses.update(expenseId, principal.userId(), request);
    }

    @PostMapping("/expenses/{expenseId}/cancel")
    public ExpenseDetail cancel(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID expenseId
    ) {
        return expenses.cancel(expenseId, principal.userId());
    }

    @GetMapping("/groups/{groupId}/balances/me")
    public MyBalances myBalances(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId
    ) {
        return expenses.myBalances(groupId, principal.userId());
    }

    @GetMapping("/groups/{groupId}/balances/{userId}")
    public PairBalance pairBalance(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId,
            @PathVariable UUID userId
    ) {
        return expenses.pairBalance(groupId, principal.userId(), userId);
    }

    @PostMapping("/groups/{groupId}/settlements")
    @ResponseStatus(HttpStatus.CREATED)
    public SettlementResponse createSettlement(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId,
            @Valid @RequestBody CreateSettlementRequest request
    ) {
        return expenses.createSettlement(groupId, principal.userId(), request);
    }

    @GetMapping("/groups/{groupId}/settlements")
    public List<SettlementResponse> listSettlements(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) Boolean involvingMe,
            @RequestParam(required = false) UUID otherUserId
    ) {
        return expenses.listSettlements(groupId, principal.userId(), status, involvingMe, otherUserId);
    }

    @GetMapping("/settlements/{settlementId}")
    public SettlementResponse settlementDetail(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID settlementId
    ) {
        return expenses.settlementDetail(settlementId, principal.userId());
    }

    @PostMapping("/settlements/{settlementId}/confirm")
    public SettlementResponse confirmSettlement(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID settlementId
    ) {
        return expenses.confirmSettlement(settlementId, principal.userId());
    }

    @PostMapping("/settlements/{settlementId}/reject")
    public SettlementResponse rejectSettlement(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID settlementId
    ) {
        return expenses.rejectSettlement(settlementId, principal.userId());
    }

    @PostMapping("/settlements/{settlementId}/cancel")
    public SettlementResponse cancelSettlement(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID settlementId
    ) {
        return expenses.cancelSettlement(settlementId, principal.userId());
    }
}
