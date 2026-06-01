package com.expense.dto.budget;

import com.expense.dto.category.CategoryDto;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BudgetDto {

    private Long id;
    private BigDecimal amount;
    private LocalDate startDate;
    private LocalDate endDate;
    private CategoryDto category;
    private String note;
    private LocalDateTime createdAt;

    /** Tổng đã chi (giao dịch EXPENSE) trong kỳ ngân sách, cùng danh mục */
    private BigDecimal spentAmount;
    /** Ngân sách − đã chi (âm nếu vượt) */
    private BigDecimal remainingAmount;
}
