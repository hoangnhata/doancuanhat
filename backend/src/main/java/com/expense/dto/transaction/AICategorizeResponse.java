package com.expense.dto.transaction;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AICategorizeResponse {

    /** EXPENSE | INCOME */
    private String transactionType;
    private String categoryName;
    private Long categoryId;
    private BigDecimal amount;
    private String description;
    /** Ngày giao dịch (YYYY-MM-DD), có thể từ câu nhập tự nhiên */
    private LocalDate transactionDate;
    private String suggestedCategoryName;
    private String rollyResponse; // AI response based on bot personality
}
