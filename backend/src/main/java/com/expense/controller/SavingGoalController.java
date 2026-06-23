package com.expense.controller;

import com.expense.dto.common.ApiResponse;
import com.expense.dto.saving.SavingGoalDto;
import com.expense.dto.saving.SavingGoalRequest;
import com.expense.dto.saving.SavingSpendRequest;
import com.expense.dto.saving.SavingSpendResponse;
import com.expense.dto.saving.SavingTransactionDto;
import com.expense.dto.saving.SavingTransferRequest;
import com.expense.service.SavingGoalService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/saving-goals")
@RequiredArgsConstructor
public class SavingGoalController {

    private final SavingGoalService savingGoalService;

    @PostMapping
    public ResponseEntity<ApiResponse<SavingGoalDto>> create(@Valid @RequestBody SavingGoalRequest request) {
        SavingGoalDto goal = savingGoalService.create(request);
        return ResponseEntity.ok(ApiResponse.success("Saving goal created", goal));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<List<SavingGoalDto>>> getAll() {
        List<SavingGoalDto> goals = savingGoalService.getAll();
        return ResponseEntity.ok(ApiResponse.success(goals));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<SavingGoalDto>> getById(@PathVariable Long id) {
        SavingGoalDto goal = savingGoalService.getById(id);
        return ResponseEntity.ok(ApiResponse.success(goal));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<SavingGoalDto>> update(
            @PathVariable Long id,
            @Valid @RequestBody SavingGoalRequest request) {
        SavingGoalDto goal = savingGoalService.update(id, request);
        return ResponseEntity.ok(ApiResponse.success("Saving goal updated", goal));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable Long id) {
        savingGoalService.delete(id);
        return ResponseEntity.ok(ApiResponse.success("Saving goal deleted", null));
    }

    @PostMapping("/{id}/deposit")
    public ResponseEntity<ApiResponse<SavingGoalDto>> deposit(
            @PathVariable Long id,
            @Valid @RequestBody SavingTransferRequest request) {
        SavingGoalDto goal = savingGoalService.deposit(id, request);
        return ResponseEntity.ok(ApiResponse.success("Deposit successful", goal));
    }

    @PostMapping("/{id}/withdraw")
    public ResponseEntity<ApiResponse<SavingGoalDto>> withdraw(
            @PathVariable Long id,
            @Valid @RequestBody SavingTransferRequest request) {
        SavingGoalDto goal = savingGoalService.withdraw(id, request);
        return ResponseEntity.ok(ApiResponse.success("Withdraw successful", goal));
    }

    @PostMapping("/{id}/spend")
    public ResponseEntity<ApiResponse<SavingSpendResponse>> spendFromGoal(
            @PathVariable Long id,
            @Valid @RequestBody SavingSpendRequest request) {
        SavingSpendResponse result = savingGoalService.spendFromGoal(id, request);
        return ResponseEntity.ok(ApiResponse.success("Chi tiêu từ mục tiêu thành công", result));
    }

    @GetMapping("/{id}/transactions")
    public ResponseEntity<ApiResponse<List<SavingTransactionDto>>> getTransactions(@PathVariable Long id) {
        List<SavingTransactionDto> transactions = savingGoalService.getTransactions(id);
        return ResponseEntity.ok(ApiResponse.success(transactions));
    }
}
