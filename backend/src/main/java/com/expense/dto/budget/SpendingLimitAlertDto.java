package com.expense.dto.budget;

import com.expense.entity.enums.SpendingLimitStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SpendingLimitAlertDto {

    private Long limitId;
    private Long categoryId;
    private String categoryName;
    private BigDecimal limitAmount;
    private BigDecimal currentSpent;
    private BigDecimal remainingAmount;
    private BigDecimal usagePercent;
    private BigDecimal exceededAmount;
    private SpendingLimitStatus status;
    private String message;
}
