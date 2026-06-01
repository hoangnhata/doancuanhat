package com.expense.controller;

import com.expense.dto.budget.BudgetDto;
import com.expense.dto.budget.BudgetRequest;
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

@RestController
@RequestMapping("/budgets")
@RequiredArgsConstructor
public class BudgetController {

    private final BudgetService budgetService;

    @PostMapping
    public ResponseEntity<ApiResponse<BudgetDto>> create(@Valid @RequestBody BudgetRequest request) {
        BudgetDto budget = budgetService.create(request);
        return ResponseEntity.ok(ApiResponse.success("Budget created", budget));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<BudgetDto>> getById(@PathVariable Long id) {
        BudgetDto budget = budgetService.getById(id);
        return ResponseEntity.ok(ApiResponse.success(budget));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<PageResponse<BudgetDto>>> getAll(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, size);
        PageResponse<BudgetDto> result = budgetService.getAll(pageable);
        return ResponseEntity.ok(ApiResponse.success(result));
    }

    @GetMapping("/active")
    public ResponseEntity<ApiResponse<List<BudgetDto>>> getActive(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        List<BudgetDto> budgets = budgetService.getActiveBudgets(date);
        return ResponseEntity.ok(ApiResponse.success(budgets));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<BudgetDto>> update(
            @PathVariable Long id,
            @Valid @RequestBody BudgetRequest request) {
        BudgetDto budget = budgetService.update(id, request);
        return ResponseEntity.ok(ApiResponse.success("Budget updated", budget));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable Long id) {
        budgetService.delete(id);
        return ResponseEntity.ok(ApiResponse.success("Budget deleted", null));
    }
}
