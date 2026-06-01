package com.expense.controller;

import com.expense.dto.common.ApiResponse;
import com.expense.dto.recurring.RecurringTransactionDto;
import com.expense.dto.recurring.RecurringTransactionRequest;
import com.expense.service.RecurringTransactionService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/recurring-transactions")
@RequiredArgsConstructor
public class RecurringTransactionController {

    private final RecurringTransactionService recurringTransactionService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<RecurringTransactionDto>>> getAll() {
        List<RecurringTransactionDto> list = recurringTransactionService.getAll();
        return ResponseEntity.ok(ApiResponse.success(list));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<RecurringTransactionDto>> create(
            @Valid @RequestBody RecurringTransactionRequest request) {
        RecurringTransactionDto dto = recurringTransactionService.create(request);
        return ResponseEntity.ok(ApiResponse.success("Giao dịch định kỳ đã tạo", dto));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<RecurringTransactionDto>> update(
            @PathVariable Long id,
            @Valid @RequestBody RecurringTransactionRequest request) {
        RecurringTransactionDto dto = recurringTransactionService.update(id, request);
        return ResponseEntity.ok(ApiResponse.success("Giao dịch định kỳ đã cập nhật", dto));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable Long id) {
        recurringTransactionService.delete(id);
        return ResponseEntity.ok(ApiResponse.success("Giao dịch định kỳ đã xóa", null));
    }

    @PatchMapping("/{id}/toggle")
    public ResponseEntity<ApiResponse<RecurringTransactionDto>> toggleActive(@PathVariable Long id) {
        recurringTransactionService.toggleActive(id);
        RecurringTransactionDto dto = recurringTransactionService.getById(id);
        return ResponseEntity.ok(ApiResponse.success("Đã cập nhật trạng thái", dto));
    }
}
