package com.expense.controller;

import com.expense.dto.ai.OcrReceiptResponse;
import com.expense.dto.common.ApiResponse;
import com.expense.dto.common.PageResponse;
import com.expense.dto.transaction.AICategorizeBatchRequest;
import com.expense.dto.transaction.AICategorizeRequest;
import com.expense.dto.transaction.AICategorizeResponse;
import com.expense.dto.transaction.TransactionDto;
import com.expense.dto.transaction.TransactionRequest;
import com.expense.entity.enums.TransactionType;
import com.expense.service.AICategorizationService;
import com.expense.service.ReceiptOcrService;
import com.expense.service.TransactionService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/transactions")
@RequiredArgsConstructor
public class TransactionController {

    private final TransactionService transactionService;
    private final AICategorizationService aiCategorizationService;
    private final ReceiptOcrService receiptOcrService;

    @PostMapping
    public ResponseEntity<ApiResponse<TransactionDto>> create(@Valid @RequestBody TransactionRequest request) {
        TransactionDto transaction = transactionService.create(request);
        return ResponseEntity.ok(ApiResponse.success("Transaction created", transaction));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<TransactionDto>> getById(@PathVariable Long id) {
        TransactionDto transaction = transactionService.getById(id);
        return ResponseEntity.ok(ApiResponse.success(transaction));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<PageResponse<TransactionDto>>> getAll(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) TransactionType type,
            @RequestParam(required = false) Long categoryId,
            @RequestParam(required = false) Long walletId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate) {
        Pageable pageable = PageRequest.of(page, size, Sort.by("transactionDate").descending());
        PageResponse<TransactionDto> result = transactionService.getAll(pageable, type, categoryId, walletId, startDate, endDate);
        return ResponseEntity.ok(ApiResponse.success(result));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<TransactionDto>> update(
            @PathVariable Long id,
            @Valid @RequestBody TransactionRequest request) {
        TransactionDto transaction = transactionService.update(id, request);
        return ResponseEntity.ok(ApiResponse.success("Transaction updated", transaction));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable Long id) {
        transactionService.delete(id);
        return ResponseEntity.ok(ApiResponse.success("Transaction deleted", null));
    }

    @PostMapping("/ai/categorize")
    public ResponseEntity<ApiResponse<AICategorizeResponse>> aiCategorize(@Valid @RequestBody AICategorizeRequest request) {
        AICategorizeResponse response = aiCategorizationService.categorize(request.getText(), request.getPersonality());
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * Batch AI categorize: split one input into multiple items.
     * Example input: "đi ăn 30k, grab 45k, điện 50k"
     */
    @PostMapping("/ai/categorize/batch")
    public ResponseEntity<ApiResponse<List<AICategorizeResponse>>> aiCategorizeBatch(@Valid @RequestBody AICategorizeBatchRequest request) {
        List<AICategorizeResponse> responses = aiCategorizationService.categorizeBatch(request.getText(), request.getPersonality());
        return ResponseEntity.ok(ApiResponse.success(responses));
    }

    /**
     * Upload ảnh hóa đơn (multipart/form-data, field "file") để AI OCR trả về số tiền,
     * ngày, cửa hàng, danh mục đã map sang category của user — frontend pre-fill form.
     */
    @PostMapping(value = "/ai/ocr/receipt", consumes = "multipart/form-data")
    public ResponseEntity<ApiResponse<OcrReceiptResponse>> ocrReceipt(@RequestParam("file") MultipartFile file) {
        OcrReceiptResponse result = receiptOcrService.parseReceipt(file);
        return ResponseEntity.ok(ApiResponse.success(result));
    }
}
