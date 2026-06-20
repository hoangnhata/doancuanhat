package com.expense.controller;

import com.expense.dto.budget.*;
import com.expense.dto.common.ApiResponse;
import com.expense.dto.common.PageResponse;
import com.expense.service.BudgetService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

/**
 * API hạn mức chi tiêu — alias chuyên nghiệp của /budgets (giữ nguyên entity Budget nội bộ).
 */
@RestController
@RequestMapping("/spending-limits")
@RequiredArgsConstructor
public class SpendingLimitController {

    private final BudgetService budgetService;

    @PostMapping
    public ResponseEntity<ApiResponse<BudgetDto>> create(@Valid @RequestBody BudgetRequest request) {
        BudgetDto limit = budgetService.create(request);
        return ResponseEntity.ok(ApiResponse.success("Đã tạo hạn mức chi tiêu", limit));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<BudgetDto>> getById(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.success(budgetService.getById(id)));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<PageResponse<BudgetDto>>> getAll(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, size);
        return ResponseEntity.ok(ApiResponse.success(budgetService.getAll(pageable)));
    }

    @GetMapping("/active")
    public ResponseEntity<ApiResponse<List<BudgetDto>>> getActive(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return ResponseEntity.ok(ApiResponse.success(budgetService.getActiveBudgets(date)));
    }

    @GetMapping("/alerts")
    public ResponseEntity<ApiResponse<List<SpendingLimitAlertDto>>> getAlerts(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return ResponseEntity.ok(ApiResponse.success(budgetService.getAlerts(date)));
    }

    @PostMapping("/check-transaction")
    public ResponseEntity<ApiResponse<CheckTransactionResponse>> checkTransaction(
            @Valid @RequestBody CheckTransactionRequest request) {
        return ResponseEntity.ok(ApiResponse.success(budgetService.checkTransaction(request)));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<BudgetDto>> update(
            @PathVariable Long id,
            @Valid @RequestBody BudgetRequest request) {
        BudgetDto limit = budgetService.update(id, request);
        return ResponseEntity.ok(ApiResponse.success("Đã cập nhật hạn mức chi tiêu", limit));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable Long id) {
        budgetService.delete(id);
        return ResponseEntity.ok(ApiResponse.success("Đã vô hiệu hóa hạn mức chi tiêu", null));
    }
}
