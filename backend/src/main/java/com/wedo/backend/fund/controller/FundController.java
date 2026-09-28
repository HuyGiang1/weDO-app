package com.wedo.backend.fund.controller;

import com.wedo.backend.fund.dto.FundDtos.AssignFundManagerRequest;
import com.wedo.backend.fund.dto.FundDtos.CollectionDetailResponse;
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
import com.wedo.backend.fund.dto.FundDtos.FundTransactionResponse;
import com.wedo.backend.fund.dto.FundDtos.ReimbursementResponse;
import com.wedo.backend.fund.dto.FundDtos.RejectRequest;
import com.wedo.backend.fund.dto.FundDtos.ReverseTransactionRequest;
import com.wedo.backend.fund.service.FundService;
import com.wedo.backend.security.AuthenticatedUserPrincipal;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
@Validated
public class FundController {
    private final FundService fundService;

    public FundController(FundService fundService) {
        this.fundService = fundService;
    }

    @PostMapping("/groups/{groupId}/fund")
    @ResponseStatus(HttpStatus.CREATED)
    public FundDetailResponse createFund(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId,
            @Valid @RequestBody(required = false) CreateFundRequest request
    ) {
        return fundService.createFund(groupId, principal.userId(), request);
    }

    @GetMapping("/groups/{groupId}/fund")
    public FundDetailResponse getGroupFund(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID groupId
    ) {
        return fundService.getGroupFund(groupId, principal.userId());
    }

    @PostMapping("/funds/{fundId}/close")
    public FundDetailResponse closeFund(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID fundId
    ) {
        return fundService.closeFund(fundId, principal.userId());
    }

    @GetMapping("/funds/{fundId}/managers")
    public List<FundManagerResponse> listManagers(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID fundId
    ) {
        return fundService.listManagers(fundId, principal.userId());
    }

    @PostMapping("/funds/{fundId}/managers")
    @ResponseStatus(HttpStatus.CREATED)
    public FundManagerResponse assignManager(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID fundId,
            @Valid @RequestBody AssignFundManagerRequest request
    ) {
        return fundService.assignManager(fundId, principal.userId(), request);
    }

    @DeleteMapping("/funds/{fundId}/managers/{userId}")
    public List<FundManagerResponse> revokeManager(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID fundId,
            @PathVariable UUID userId
    ) {
        return fundService.revokeManager(fundId, userId, principal.userId());
    }

    @GetMapping("/funds/{fundId}/overview")
    public FundOverviewResponse getOverview(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID fundId
    ) {
        return fundService.getFundOverview(fundId, principal.userId());
    }

    @PostMapping("/funds/{fundId}/collections")
    @ResponseStatus(HttpStatus.CREATED)
    public CollectionDetailResponse createCollection(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID fundId,
            @Valid @RequestBody CreateCollectionRequest request
    ) {
        return fundService.createCollection(fundId, principal.userId(), request);
    }

    @GetMapping("/funds/{fundId}/collections")
    public List<CollectionSummaryResponse> listCollections(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID fundId,
            @RequestParam(required = false) String status
    ) {
        return fundService.listCollections(fundId, principal.userId(), status);
    }

    @GetMapping({"/collections/{collectionId}", "/funds/{fundId}/collections/{collectionId}"})
    public CollectionDetailResponse getCollectionDetail(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID collectionId
    ) {
        return fundService.getCollectionDetail(collectionId, principal.userId());
    }

    @PostMapping("/collections/{collectionId}/close")
    public CollectionDetailResponse closeCollection(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID collectionId
    ) {
        return fundService.closeCollection(collectionId, principal.userId());
    }

    @PostMapping("/collections/{collectionId}/cancel")
    public CollectionDetailResponse cancelCollection(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID collectionId
    ) {
        return fundService.cancelCollection(collectionId, principal.userId());
    }

    @PostMapping("/collections/{collectionId}/contributions")
    @ResponseStatus(HttpStatus.CREATED)
    public ContributionResponse submitContribution(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID collectionId,
            @Valid @RequestBody CreateContributionRequest request
    ) {
        return fundService.submitContribution(collectionId, principal.userId(), request);
    }

    @PostMapping("/contributions/{id}/confirm")
    public ContributionResponse confirmContribution(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID id
    ) {
        return fundService.confirmContribution(id, principal.userId());
    }

    @PostMapping("/contributions/{id}/reject")
    public ContributionResponse rejectContribution(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID id,
            @Valid @RequestBody(required = false) RejectRequest request
    ) {
        return fundService.rejectContribution(id, principal.userId(), request);
    }

    @PostMapping("/contributions/{id}/cancel")
    public ContributionResponse cancelContribution(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID id
    ) {
        return fundService.cancelContribution(id, principal.userId());
    }

    @PostMapping("/funds/{fundId}/expenses")
    @ResponseStatus(HttpStatus.CREATED)
    public FundExpenseResponse createFundExpense(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID fundId,
            @Valid @RequestBody CreateFundExpenseRequest request
    ) {
        return fundService.createFundExpense(fundId, principal.userId(), request);
    }

    @GetMapping("/funds/{fundId}/expenses")
    public List<FundExpenseResponse> listFundExpenses(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID fundId
    ) {
        return fundService.listFundExpenses(fundId, principal.userId());
    }

    @PostMapping("/funds/{fundId}/reimbursements")
    @ResponseStatus(HttpStatus.CREATED)
    public ReimbursementResponse createReimbursement(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID fundId,
            @Valid @RequestBody CreateReimbursementRequest request
    ) {
        return fundService.createReimbursement(fundId, principal.userId(), request);
    }

    @GetMapping("/funds/{fundId}/reimbursements")
    public List<ReimbursementResponse> listReimbursements(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID fundId,
            @RequestParam(required = false) String status
    ) {
        return fundService.listReimbursements(fundId, principal.userId(), status);
    }

    @PostMapping("/reimbursements/{id}/approve")
    public ReimbursementResponse approveReimbursement(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID id
    ) {
        return fundService.approveReimbursement(id, principal.userId());
    }

    @PostMapping("/reimbursements/{id}/reject")
    public ReimbursementResponse rejectReimbursement(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID id,
            @Valid @RequestBody(required = false) RejectRequest request
    ) {
        return fundService.rejectReimbursement(id, principal.userId(), request);
    }

    @PostMapping("/reimbursements/{id}/cancel")
    public ReimbursementResponse cancelReimbursement(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID id
    ) {
        return fundService.cancelReimbursement(id, principal.userId());
    }

    @GetMapping("/funds/{fundId}/transactions")
    public List<FundTransactionResponse> listTransactions(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID fundId,
            @RequestParam(required = false) String type,
            @RequestParam(required = false) String direction
    ) {
        return fundService.listTransactions(fundId, principal.userId(), type, direction);
    }

    @PostMapping({"/fund-transactions/{transactionId}/reverse", "/transactions/{transactionId}/reverse"})
    public FundTransactionResponse reverseTransaction(
            @AuthenticationPrincipal AuthenticatedUserPrincipal principal,
            @PathVariable UUID transactionId,
            @Valid @RequestBody ReverseTransactionRequest request
    ) {
        return fundService.reverseTransaction(transactionId, principal.userId(), request);
    }
}
