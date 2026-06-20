package com.expense.dto.ai;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

/** Trả về kết quả OCR hóa đơn đã map sang category của user (nếu có). */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OcrReceiptResponse {
    /** EXPENSE | INCOME */
    private String transactionType;
    private BigDecimal amount;
    private LocalDate transactionDate;
    private String merchant;
    private String description;
    private String categoryName;
    /** id của category đang có sẵn của user (null nếu không khớp). */
    private Long categoryId;
    /** Confidence trung bình của OCR (0-1). */
    private Double confidence;
    /** true nếu các field quan trọng (amount/category) thiếu hoặc confidence thấp → cần user review. */
    private boolean needsReview;
    private String ocrEngine;
    /** Bill chuyển khoản (app ngân hàng / ví). */
    private boolean bankTransfer;
    /** Người chuyển (nếu đọc được). */
    private String senderName;
    /** Người nhận (nếu đọc được). */
    private String recipientName;
}
