package com.expense.dto.budget;

import com.expense.entity.enums.PeriodType;
import com.expense.entity.enums.SpendingLimitStatus;
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
    private BigDecimal limitAmount;
    private LocalDate startDate;
    private LocalDate endDate;
    private CategoryDto category;
    private String note;
    private LocalDateTime createdAt;
    private PeriodType periodType;
    private Integer warningThresholdPercent;
    private Boolean isActive;
    private Boolean alertsEnabled;

    /** Tổng chi EXPENSE trong kỳ hạn mức */
    private BigDecimal spentAmount;
    private BigDecimal currentSpent;
    private BigDecimal remainingAmount;
    private BigDecimal usagePercent;
    private SpendingLimitStatus status;
    private String statusMessage;
}
